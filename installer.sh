#!/bin/bash
set -e

# Tinta4Plus Installer
# Installs either PyInstaller binaries or Python scripts into the system

APP_NAME="tinta4plus"
INSTALL_DIR="/opt/tinta4plus"
BIN_DIR="/usr/local/bin"
DESKTOP_DIR="/usr/share/applications"
AUTOSTART_DIR="/etc/xdg/autostart"
POLKIT_DIR="/usr/share/polkit-1/actions"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_MODE=""  # "binary" or "script"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
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

# ─── Choose install mode ────────────────────────────────────────────────────

choose_mode() {
    local has_binary=false
    if [ -f "${SCRIPT_DIR}/dist/tinta4plus/tinta4plus" ] && \
       [ -f "${SCRIPT_DIR}/dist/tinta4plus-helper/tinta4plus-helper" ]; then
        has_binary=true
    fi

    local has_script=false
    if [ -f "${SCRIPT_DIR}/Tinta4Plus.py" ] && \
       [ -f "${SCRIPT_DIR}/HelperDaemon.py" ]; then
        has_script=true
    fi

    if [ "$has_binary" = false ] && [ "$has_script" = false ]; then
        error "No installable files found."
        error "Either run 'bash build.sh' first (for binary mode) or ensure .py files are present."
        exit 1
    fi

    echo ""
    echo -e "${CYAN}─── Installation Mode ───${NC}"
    echo ""
    if [ "$has_binary" = true ]; then
        echo "  1) Compiled binary (PyInstaller)"
        echo "     Standalone executables, no Python needed at runtime."
    else
        echo -e "  1) Compiled binary ${YELLOW}[not available — run 'bash build.sh' first]${NC}"
    fi
    echo ""
    if [ "$has_script" = true ]; then
        echo "  2) Python scripts"
        echo "     Installs .py files directly. Requires Python 3 + dependencies at runtime."
        echo "     Easier to debug and modify."
    else
        echo -e "  2) Python scripts ${YELLOW}[not available — .py files not found]${NC}"
    fi
    echo ""

    while true; do
        read -rp "Choose installation mode [1/2]: " choice
        case "$choice" in
            1)
                if [ "$has_binary" = true ]; then
                    INSTALL_MODE="binary"
                    break
                else
                    error "Binaries not built. Run 'bash build.sh' first."
                fi
                ;;
            2)
                if [ "$has_script" = true ]; then
                    INSTALL_MODE="script"
                    break
                else
                    error "Python scripts not found."
                fi
                ;;
            *) error "Please enter 1 or 2." ;;
        esac
    done

    info "Installation mode: ${INSTALL_MODE}"
}

# ─── Check prerequisites ────────────────────────────────────────────────────

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "This installer must be run as root (sudo bash installer.sh)"
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
    local pkgs="libusb-1.0-0"

    # Python scripts need the full Python stack
    if [ "$INSTALL_MODE" = "script" ]; then
        pkgs="$pkgs python3 python3-tk python3-usb"
    else
        pkgs="$pkgs python3-tk"
    fi

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
    info "APT dependencies installed."

    # Script mode: install pip packages not available in apt
    if [ "$INSTALL_MODE" = "script" ]; then
        info "Installing Python pip packages..."
        local pip_cmd="pip3"
        if ! command -v pip3 &>/dev/null; then
            apt-get install -y -qq python3-pip
        fi
        # Install as system-wide (running as root)
        $pip_cmd install --break-system-packages portio pyusb 2>/dev/null \
            || $pip_cmd install portio pyusb 2>/dev/null \
            || warn "pip install failed — you may need to run: pip3 install portio pyusb"
    fi
}

# ─── Verify dependencies ────────────────────────────────────────────────────

check_deps() {
    info "Verifying dependencies..."
    local missing=()

    # Check system commands/libs
    if ! ldconfig -p 2>/dev/null | grep -q libusb-1.0; then
        missing+=("libusb-1.0-0 (apt)")
    fi

    # Both modes need tkinter at runtime
    if ! python3 -c "import tkinter" 2>/dev/null; then
        missing+=("python3-tk (apt)")
    fi

    # Script mode needs Python modules
    if [ "$INSTALL_MODE" = "script" ]; then
        if ! command -v python3 &>/dev/null; then
            missing+=("python3 (apt)")
        else
            for mod in usb portio; do
                if ! python3 -c "import $mod" 2>/dev/null; then
                    case "$mod" in
                        usb)    missing+=("pyusb (pip3 install pyusb)") ;;
                        portio) missing+=("portio (pip3 install portio)") ;;
                    esac
                fi
            done
        fi
    fi

    # Check display tools
    if ! command -v feh &>/dev/null && ! command -v imv &>/dev/null; then
        warn "Neither 'feh' nor 'imv' found — privacy image display may not work."
        warn "Install one with: apt install feh"
    fi

    if [ ${#missing[@]} -eq 0 ]; then
        info "All dependencies OK."
    else
        echo ""
        error "Missing dependencies:"
        for dep in "${missing[@]}"; do
            echo -e "  ${RED}✗${NC} ${dep}"
        done
        echo ""
        warn "The application may not work correctly until these are installed."
    fi
}

# ─── Install: binary mode ───────────────────────────────────────────────────

install_binary() {
    info "Installing compiled binaries to ${INSTALL_DIR}..."

    mkdir -p "${INSTALL_DIR}"

    # Copy onedir bundles
    cp -r "${SCRIPT_DIR}/dist/tinta4plus"        "${INSTALL_DIR}/"
    cp -r "${SCRIPT_DIR}/dist/tinta4plus-helper"  "${INSTALL_DIR}/"

    # Set permissions
    chmod 755 "${INSTALL_DIR}/tinta4plus/tinta4plus"
    chmod 755 "${INSTALL_DIR}/tinta4plus-helper/tinta4plus-helper"

    # Create symlinks in /usr/local/bin
    ln -sf "${INSTALL_DIR}/tinta4plus/tinta4plus"              "${BIN_DIR}/tinta4plus"
    ln -sf "${INSTALL_DIR}/tinta4plus-helper/tinta4plus-helper" "${BIN_DIR}/tinta4plus-helper"

    info "Binaries installed."
}

# ─── Install: script mode ───────────────────────────────────────────────────

install_script() {
    info "Installing Python scripts to ${INSTALL_DIR}..."

    mkdir -p "${INSTALL_DIR}"

    # Copy all Python source files
    local py_files=(
        Tinta4Plus.py
        HelperDaemon.py
        DisplayManager.py
        ThemeManager.py
        HelperClient.py
        ECController.py
        EInkUSBController.py
        WatchdogTimer.py
    )

    for f in "${py_files[@]}"; do
        cp "${SCRIPT_DIR}/${f}" "${INSTALL_DIR}/"
    done

    # Copy privacy images
    for img in "${SCRIPT_DIR}"/eink-disable*.jpg; do
        [ -f "$img" ] && cp "$img" "${INSTALL_DIR}/"
    done

    # Set permissions
    chmod 755 "${INSTALL_DIR}/Tinta4Plus.py"
    chmod 755 "${INSTALL_DIR}/HelperDaemon.py"

    # Create launcher wrappers in /usr/local/bin
    cat > "${BIN_DIR}/tinta4plus" << 'WRAPPER'
#!/bin/bash
exec python3 /opt/tinta4plus/Tinta4Plus.py "$@"
WRAPPER
    chmod 755 "${BIN_DIR}/tinta4plus"

    cat > "${BIN_DIR}/tinta4plus-helper" << 'WRAPPER'
#!/bin/bash
exec python3 /opt/tinta4plus/HelperDaemon.py "$@"
WRAPPER
    chmod 755 "${BIN_DIR}/tinta4plus-helper"

    info "Python scripts installed."
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
    echo -e "${CYAN}─── PolicyKit Configuration ───${NC}"
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
    choose_mode
    detect_de
    install_deps

    if [ "$INSTALL_MODE" = "binary" ]; then
        install_binary
    else
        install_script
    fi

    install_desktop
    install_polkit
    check_deps

    echo ""
    info "════════════════════════════════════════"
    info " Installation complete! (mode: ${INSTALL_MODE})"
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
