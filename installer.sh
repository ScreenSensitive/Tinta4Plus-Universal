#!/bin/bash
set -e

# Tinta4Plus Installer
# Installs pre-built PyInstaller binaries into the system

APP_NAME="tinta4plus"
INSTALL_DIR="/opt/tinta4plus"
BIN_DIR="/usr/local/bin"
DESKTOP_DIR="/usr/share/applications"
AUTOSTART_DIR="/etc/xdg/autostart"
POLKIT_DIR="/usr/share/polkit-1/actions"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── Uninstall ───────────────────────────────────────────────────────────────

do_uninstall() {
    info "Uninstalling Tinta4Plus..."

    rm -f  "${BIN_DIR}/tinta4plus"
    rm -f  "${BIN_DIR}/tinta4plus-helper"
    rm -rf "${INSTALL_DIR}"
    rm -f  "${DESKTOP_DIR}/tinta4plus.desktop"
    rm -f  "${AUTOSTART_DIR}/tinta4plus-autostart.desktop"
    rm -f  "${POLKIT_DIR}/org.tinta4plus.helper.policy"

    info "Tinta4Plus has been uninstalled."
    exit 0
}

# ─── Check prerequisites ────────────────────────────────────────────────────

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "This installer must be run as root (sudo bash installer.sh)"
        exit 1
    fi
}

check_build() {
    if [ ! -f "${SCRIPT_DIR}/dist/tinta4plus/tinta4plus" ]; then
        error "GUI binary not found at dist/tinta4plus/tinta4plus"
        error "Run 'bash build.sh' first."
        exit 1
    fi
    if [ ! -f "${SCRIPT_DIR}/dist/tinta4plus-helper/tinta4plus-helper" ]; then
        error "Helper binary not found at dist/tinta4plus-helper/tinta4plus-helper"
        error "Run 'bash build.sh' first."
        exit 1
    fi
}

# ─── Detect desktop environment ─────────────────────────────────────────────

detect_de() {
    DE="unknown"

    # 1. Try env vars (work when using sudo -E, or running as normal user)
    local xdg="${XDG_CURRENT_DESKTOP:-}"
    local session="${DESKTOP_SESSION:-}"

    # 2. If empty (sudo strips env), read from the invoking user's session
    if [ -z "$xdg" ] && [ -n "$SUDO_USER" ]; then
        # Get the invoking user's active session via loginctl
        local uid
        uid=$(id -u "$SUDO_USER" 2>/dev/null) || true
        if [ -n "$uid" ]; then
            local sess_id
            sess_id=$(loginctl list-sessions --no-legend 2>/dev/null \
                      | awk -v u="$uid" '$2 == u {print $1; exit}') || true
            if [ -n "$sess_id" ]; then
                xdg=$(loginctl show-session "$sess_id" -p Desktop --value 2>/dev/null) || true
            fi
        fi
    fi

    # 3. Fallback: detect from running processes
    if [ -z "$xdg" ]; then
        if pgrep -x gnome-shell &>/dev/null; then
            xdg="GNOME"
        elif pgrep -x xfce4-session &>/dev/null; then
            xdg="XFCE"
        elif pgrep -x plasmashell &>/dev/null; then
            xdg="KDE"
        fi
    fi

    # 4. Map to our labels
    case "${xdg}${session}" in
        *GNOME*|*gnome*|*Unity*|*Budgie*|*ubuntu*) DE="gnome" ;;
        *XFCE*|*xfce*)                              DE="xfce" ;;
        *KDE*|*plasma*)                              DE="kde" ;;
    esac

    info "Detected desktop environment: ${DE}"
}

# ─── Install system dependencies ────────────────────────────────────────────

install_deps() {
    info "Installing system dependencies..."

    # Common packages
    local pkgs="python3-tk libusb-1.0-0"

    case "$DE" in
        gnome)
            pkgs="$pkgs gnome-themes-extra"
            ;;
        xfce)
            pkgs="$pkgs xfce4-settings"
            ;;
    esac

    apt-get update -qq
    apt-get install -y -qq $pkgs
    info "Dependencies installed."
}

# ─── Install binaries ───────────────────────────────────────────────────────

install_binaries() {
    info "Installing binaries to ${INSTALL_DIR}..."

    mkdir -p "${INSTALL_DIR}"

    # Copy onedir bundles
    cp -r "${SCRIPT_DIR}/dist/tinta4plus"        "${INSTALL_DIR}/"
    cp -r "${SCRIPT_DIR}/dist/tinta4plus-helper"  "${INSTALL_DIR}/"

    # Copy image asset (also bundled inside, but keep a top-level copy)
    if [ -f "${SCRIPT_DIR}/eink-disable.jpg" ]; then
        cp "${SCRIPT_DIR}/eink-disable.jpg" "${INSTALL_DIR}/"
    fi

    # Set permissions
    chmod 755 "${INSTALL_DIR}/tinta4plus/tinta4plus"
    chmod 755 "${INSTALL_DIR}/tinta4plus-helper/tinta4plus-helper"

    # Create symlinks in /usr/local/bin
    ln -sf "${INSTALL_DIR}/tinta4plus/tinta4plus"              "${BIN_DIR}/tinta4plus"
    ln -sf "${INSTALL_DIR}/tinta4plus-helper/tinta4plus-helper" "${BIN_DIR}/tinta4plus-helper"

    info "Binaries installed."
}

# ─── Install desktop entries ────────────────────────────────────────────────

install_desktop() {
    info "Installing desktop entries..."

    cp "${SCRIPT_DIR}/tinta4plus.desktop"           "${DESKTOP_DIR}/"
    cp "${SCRIPT_DIR}/tinta4plus-autostart.desktop"  "${AUTOSTART_DIR}/"

    # Validate desktop files if desktop-file-validate is available
    if command -v desktop-file-validate &>/dev/null; then
        desktop-file-validate "${DESKTOP_DIR}/tinta4plus.desktop" 2>/dev/null || true
    fi

    # Update desktop database
    if command -v update-desktop-database &>/dev/null; then
        update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
    fi

    info "Desktop entries installed."
}

# ─── PolicyKit (optional) ───────────────────────────────────────────────────

install_polkit() {
    echo ""
    echo "─── PolicyKit Configuration ───"
    echo "Install a PolicyKit policy to avoid re-entering your password"
    echo "every time the helper daemon starts?"
    echo "(The first launch will still require authentication)"
    echo ""
    read -rp "Install PolicyKit policy? [y/N] " answer

    if [[ "$answer" =~ ^[Yy]$ ]]; then
        mkdir -p "${POLKIT_DIR}"
        cp "${SCRIPT_DIR}/org.tinta4plus.helper.policy" "${POLKIT_DIR}/"
        info "PolicyKit policy installed."
    else
        info "Skipping PolicyKit policy."
    fi
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║      Tinta4Plus Installer            ║"
    echo "║  eInk Control for ThinkBook Plus G4  ║"
    echo "╚══════════════════════════════════════╝"
    echo ""

    # Handle --uninstall
    if [ "${1}" = "--uninstall" ]; then
        check_root
        do_uninstall
    fi

    check_root
    check_build
    detect_de
    install_deps
    install_binaries
    install_desktop
    install_polkit

    echo ""
    info "════════════════════════════════════════"
    info " Installation complete!"
    info ""
    info " Launch from terminal:  tinta4plus"
    info " Or find 'Tinta4Plus' in your application menu."
    info " It will also autostart on next login."
    info ""
    info " To uninstall:  sudo bash installer.sh --uninstall"
    info "════════════════════════════════════════"
    echo ""
}

main "$@"
