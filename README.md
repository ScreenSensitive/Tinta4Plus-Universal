# Tinta4PlusU (Universal)

Linux GUI for controlling the **color eInk display** on the **Lenovo ThinkBook Plus Gen 4 IRU**.

This is a universal fork of [Tinta4Plus](https://github.com/joncox123/Tinta4Plus) by Jon Cox, with broader desktop environment support and a system installer.

[![Buy Me A Coffee](https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&slug=joncox&button_colour=FFDD00&font_colour=000000&font_family=Inter&outline_colour=000000&coffee_colour=ffffff)](https://www.buymeacoffee.com/joncox)

<img src="eink-disable.jpg" alt="ThinkBook Plus Gen 4 eInk" width="60%"/>

## Supported configurations

| Desktop | Session | Status |
|---------|---------|--------|
| GNOME | X11 | Tested |
| GNOME | Wayland | Tested (Mutter D-Bus) |
| Cinnamon | X11 | Supported |
| XFCE | X11 | Tested |
| KDE Plasma | X11 | Supported |
| KDE Plasma | Wayland | Supported (kscreen) |

Base OS: **Ubuntu 24.04 LTS** or later (including Xubuntu, Kubuntu, Linux Mint).

## Hardware

- OLED: 2880x1800 on eDP-1
- eInk: 2560x1600 color on eDP-2
- eInk T-CON controller: USB (VID `048d`, PID `8957`)
- Embedded Controller: I/O ports `0x66`/`0x62` (frontlight, brightness)

## Quick start

### 1. Clone the repository

```bash
git clone https://github.com/Tinta4Plus-Universal/Tinta4Plus-Universal.git
cd Tinta4Plus-Universal
```

### 2. Disable Secure Boot

Frontlight control requires EC access, which needs Secure Boot disabled:

1. Reboot and press **Enter** repeatedly right after power-on to get the boot menu.
2. Press the appropriate F-key to enter BIOS settings.
3. Navigate to **Security** > **Secure Boot** > set to **Disabled**.
4. Save and reboot.

### 3. Install

There are two ways to install: **compiled binaries** (recommended) or **Python scripts** (easier to debug/modify).

#### Option A: Compiled binaries (recommended)

Build first, then install:

```bash
# Install build dependency
pip install pyinstaller

# Build the binaries
bash build.sh

# Install system-wide
sudo bash installer.sh
# Choose option 1 (compiled binary) when prompted
```

#### Option B: Python scripts (development)

```bash
sudo bash installer.sh
# Choose option 2 (Python scripts) when prompted
```

Or run directly without installing:

```bash
# Install dependencies manually
sudo apt install python3-tk python3-usb libusb-1.0-0 feh policykit-1-gnome
pip install portio pyusb sv-ttk

# Run
./Tinta4Plus.py
```

### What the installer does

1. Asks you to choose between compiled binary or Python script mode.
2. Detects your desktop environment (GNOME, Cinnamon, XFCE, KDE) using three fallback methods: environment variables, loginctl session query, and process detection.
3. Installs apt dependencies:
   - **Common**: `libusb-1.0-0`, `python3-tk`
   - **Script mode** adds: `python3`, `python3-usb`
   - **GNOME/Cinnamon** adds: `gnome-themes-extra`, `policykit-1-gnome` (required for pkexec password dialog)
   - **KDE** adds: `kscreen`, `plasma-workspace`
   - **XFCE** adds: `xfce4-settings`
4. In script mode, installs pip packages: `portio`, `pyusb`, `sv-ttk`.
5. Copies binaries/scripts to `/opt/tinta4plusu/` and creates symlinks in `/usr/local/bin/`.
6. Installs `tinta4plusu.desktop` to `/usr/share/applications/` and `tinta4plusu-autostart.desktop` to `/etc/xdg/autostart/`.
7. Optionally installs a PolicyKit policy (`org.tinta4plusu.helper.policy`) to cache authentication so you don't re-enter your password every time the helper starts.

Errors during installation are trapped and logged to `/tmp/tinta4plusu-install.log`.

### 4. Launch

After installation, launch from the terminal or application menu:

```bash
tinta4plusu
```

The app also autostarts on login (via `/etc/xdg/autostart/`). In autostart mode, the helper daemon is **not** launched automatically to avoid a password prompt at login — click **Connect to Helper** when you need eInk control.

## Usage

### Switching displays

Click the **eInk Enabled/Disabled** toggle button to switch between OLED and eInk. The switching sequence:

- **To eInk**: enables eDP-2, powers on the T-CON, enables frontlight, sets reading mode, then disables eDP-1. On Wayland, the eInk is placed at the same position as the OLED (mirror-like) to avoid a visible extended-desktop state during the transition.
- **To OLED**: switches to dynamic mode, shows a privacy image on eInk (to clear sensitive content), powers off the T-CON, re-enables eDP-1, unlocks the session, then disables eDP-2.

### eInk display modes

- **Reading mode**: optimized for text, slower refresh, less ghosting.
- **Dynamic mode**: faster refresh for scrolling/interaction, more ghosting.

### Refreshing the display (clearing ghosts)

eInk panels accumulate ghosting (afterimages) from partial updates. You can clear it with:

- **Refresh button**: click "Refresh eInk (Clear Ghosts)" in the GUI.
- **Keyboard shortcuts**: press **F5** or **F9** (media key) while the app is focused.
- **Periodic auto-refresh**: adjust the "Refresh period" slider (0 = off, up to 60 seconds). Defaults to off.

### Frontlight

Use the brightness slider (0-8) to control the eInk frontlight. The frontlight turns on automatically when switching to eInk and off when switching back to OLED.

**Keyboard shortcuts**: brightness Up/Down media keys (`XF86MonBrightnessUp` / `XF86MonBrightnessDown`) adjust the frontlight when in eInk mode.

### Display scaling

The "Display Scale" slider controls the UI scale on the eInk display (default: 1.75x). On X11 this sets the xrandr scale and panning dimensions. On Wayland (Mutter), it uses the closest supported fractional scale.

### Theme auto-switching

When "Auto-switch theme" is checked (default), the app switches to a high-contrast theme on eInk and back to Adwaita-dark on OLED. The GUI itself uses a dark theme (sv-ttk).

### Settings persistence

Settings (display scale, refresh period, theme auto-switch) are saved to `~/.config/Tinta4PlusU/settings.json` and restored on next launch.

### Touch diagnostic tool

A standalone diagnostic tool (`touch_diagnostic.py`) is included to test touchscreen mapping accuracy on the eInk display. Run it while in eInk mode:

```bash
python3 touch_diagnostic.py
```

It shows targets on screen and reports the offset between expected and actual touch positions.

## Uninstalling

```bash
sudo bash installer.sh --uninstall
```

This removes binaries/scripts from `/opt/tinta4plusu`, symlinks from `/usr/local/bin`, desktop entries, and the PolicyKit policy.

## Architecture

Two-process model communicating via Unix socket (`/tmp/tinta4plusu.sock`):

- **Tinta4Plus.py** — unprivileged tkinter GUI, launched as the user.
- **HelperDaemon.py** — privileged daemon (root via `pkexec`), controls EC and USB hardware.

| Module | Role | Runs as |
|--------|------|---------|
| `Tinta4Plus.py` | Main GUI | User |
| `HelperDaemon.py` | Privileged daemon | Root |
| `DisplayManager.py` | Display switching (xrandr / Mutter D-Bus / kscreen) | User |
| `ThemeManager.py` | GTK/desktop theme switching (GNOME, Cinnamon, XFCE, KDE) | User |
| `HelperClient.py` | Socket IPC client | User |
| `ECController.py` | Embedded Controller I/O | Root |
| `EInkUSBController.py` | USB T-CON controller | Root |
| `WatchdogTimer.py` | Daemon watchdog (20s timeout) | Root |
| `touch_diagnostic.py` | Touchscreen mapping diagnostic | User |

## PolicyKit

During installation you can optionally install a PolicyKit policy (`org.tinta4plusu.helper.policy`) that caches authentication so you don't need to re-enter your password every time the helper starts. The first launch still requires authentication.

On GNOME and Cinnamon, the `policykit-1-gnome` package is required for `pkexec` to show a password dialog. The installer installs this automatically.

## Troubleshooting

### "Failed to launch helper — password cancelled or pkexec failed"

The polkit authentication agent is not running. On GNOME/Cinnamon, install `policykit-1-gnome`:

```bash
sudo apt install policykit-1-gnome
```

Then log out and back in, or start it manually:

```bash
/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 &
```

### Black screen after switching back to OLED

The app forces DPMS on and unlocks the session after re-enabling eDP-1, but if the OLED stays black, close and reopen the laptop lid to wake it.

### Frontlight error on enable

Sometimes the EC register readback differs from the written value. The frontlight is usually enabled despite the error — check visually.

### EC reset procedure

If the laptop becomes unresponsive or the eInk/EC behaves erratically:

1. Power off and disconnect the AC adapter.
2. Press and **hold** the EC reset pinhole (bottom of laptop, near the fan vent) for **60 seconds**.
3. Press and **hold** the power button for **60 seconds**.
4. Press the power button normally to boot (may take up to 60 seconds to show anything on screen).
5. Re-check BIOS to ensure Secure Boot is still disabled.

## Warning and disclaimer

This software was independently developed without any input, support, or documentation from eInk or Lenovo. It writes to low-level hardware (Embedded Controller, USB T-CON) and can potentially cause temporary or permanent hardware damage. It has been tested on a limited number of systems.

**Do not modify `ECController.py` or `EInkUSBController.py`** unless you understand the hardware implications.

Use at your own risk. See the full [EULA](README_EULA_INSTRUCTIONS_WARNINGS.txt) for details.

## Credits

Original project by [Jon Cox](https://github.com/joncox123) — [Buy him a coffee](https://www.buymeacoffee.com/joncox)
