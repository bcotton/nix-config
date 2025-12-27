# Hyprland Configuration - Implementation Plan

> A modular, per-user configurable Hyprland setup for NixOS with home-manager integration.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Completed Work](#completed-work)
- [Upcoming Phases](#upcoming-phases)
- [Ideas for an Exceptional Setup](#ideas-for-an-exceptional-setup)
- [Configuration Reference](#configuration-reference)
- [Troubleshooting](#troubleshooting)

---

## Architecture Overview

This Hyprland implementation uses a **two-layer architecture**:

```
┌─────────────────────────────────────────────────────────────────┐
│                     NixOS System Level                          │
│  clubcotton/services/hyprland/default.nix                       │
│  ├── programs.hyprland.enable                                   │
│  ├── GDM display manager                                        │
│  ├── XDG portals (screen sharing, file dialogs)                 │
│  ├── PipeWire audio                                             │
│  └── System packages (polkit, brightnessctl, etc.)              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Home-Manager User Level                        │
│  home/modules/hyprland/                                         │
│  ├── default.nix    (core config, keybinds, options)            │
│  ├── rofi.nix       (application launcher)                      │
│  ├── waybar.nix     (status bar)                                │
│  └── [future modules...]                                        │
└─────────────────────────────────────────────────────────────────┘
```

### Key Design Decisions

1. **Per-user configuration** - Each user can have different Hyprland settings
2. **Modular files** - Easy to enable/disable features (rofi, waybar, etc.)
3. **Sensible defaults** - Works out of the box, customizable via options
4. **Catppuccin Mocha theme** - Modern, consistent color scheme (upgradeable to Stylix)

---

## Completed Work

### ✅ Phase 1: Minimal Working Setup

**NixOS Module** (`clubcotton/services/hyprland/default.nix`):
- [x] `programs.hyprland.enable` with XWayland
- [x] GDM display manager with Wayland support
- [x] XDG portals for Hyprland and GTK
- [x] PipeWire audio (ALSA, PulseAudio compat)
- [x] Polkit for authentication dialogs
- [x] Essential packages (brightnessctl, playerctl, pamixer)

**Home-Manager Module** (`home/modules/hyprland/default.nix`):
- [x] Per-user options: `terminal`, `browser`, `modifier`, `monitors`, gaps, colors
- [x] Wayland environment variables (Electron, Firefox, QT, GTK)
- [x] Essential keybindings:
  - Window focus (HJKL + arrows)
  - Window movement
  - Workspace switching (1-10)
  - Fullscreen, floating, pseudo-tile
  - Media keys (volume, brightness, play/pause)
  - Screenshot to clipboard
  - Config reload (`SUPER+SHIFT+R`)
- [x] Basic window rules (float PiP, pavucontrol, etc.)
- [x] Dwindle layout with sane defaults
- [x] Clipboard history with cliphist
- [x] Blur and shadow decorations
- [x] Simple animations

### ✅ Phase 2: Launcher & Status Bar

**Rofi** (`home/modules/hyprland/rofi.nix`):
- [x] rofi-wayland package
- [x] drun, run, filebrowser modes
- [x] Catppuccin Mocha themed
- [x] Rounded corners, modern styling
- [x] Keybindings: `SUPER+D` (apps), `SUPER+R` (run)

**Keybindings Menu** (`home/modules/hyprland/keybindings-menu.nix`):
- [x] Displays all keybindings in searchable rofi menu
- [x] Uses `hyprctl binds` to fetch descriptions from `bindd` directives
- [x] Human-readable modifier names (SUPER, CTRL, ALT, SHIFT)
- [x] Priority-sorted for common actions
- [x] Keybinding: `SUPER+/` (inspired by omarchy)

**Waybar** (`home/modules/hyprland/waybar.nix`):
- [x] Systemd integration (auto-start)
- [x] Modules: workspaces, window title, clock, CPU, memory, battery, network, audio, tray
- [x] Catppuccin Mocha themed
- [x] Click actions (pavucontrol, nm-connection-editor)
- [x] Workspace scroll navigation
- [x] JetBrainsMono Nerd Font icons

### Current Keybindings

| Key | Action |
|-----|--------|
| `SUPER + Return` | Open terminal (Ghostty) |
| `SUPER + D` | App launcher (Rofi) |
| `SUPER + R` | Run command |
| `SUPER + W` | Open browser |
| `SUPER + Q` | Kill window |
| `SUPER + HJKL` | Focus window |
| `SUPER + SHIFT + HJKL` | Move window |
| `SUPER + 1-0` | Switch workspace |
| `SUPER + SHIFT + 1-0` | Move to workspace |
| `SUPER + F` | Fullscreen |
| `SUPER + SHIFT + F` | Toggle floating |
| `SUPER + V` | Clipboard history |
| `SUPER + SHIFT + R` | Reload config |
| `SUPER + /` | Show keybindings menu |
| `Print` | Screenshot region |
| `SHIFT + Print` | Screenshot full screen |
| `SUPER + SHIFT + E` | Exit Hyprland |

---

## Upcoming Phases

### 🔲 Phase 3: Window Rules & Polish

**File:** `home/modules/hyprland/windowrules.nix`

- [ ] Tag-based window rules (browsers, terminals, editors, games)
- [ ] Smart floating for dialogs, file pickers, settings apps
- [ ] Opacity rules by application class
- [ ] Workspace assignments for specific apps
- [ ] Picture-in-Picture: always on top, pinned, corner placement
- [ ] Idle inhibition for fullscreen apps

### 🔲 Phase 4: Notifications & Idle Management

**Files:** `hypridle.nix`, `hyprlock.nix`, `notifications.nix`

- [ ] **Hypridle** - Screen timeout, DPMS control
  - Lock after 15 minutes
  - Screen off after 20 minutes
  - Resume on mouse/keyboard
- [ ] **Hyprlock** - Beautiful lock screen
  - User avatar
  - Clock display
  - Blur background
  - Password input styling
- [ ] **Notifications** - SwayNC or Mako
  - Do Not Disturb mode
  - Notification history
  - Waybar integration

### 🔲 Phase 5: Wallpaper & Theming

**Files:** `wallpaper.nix`, `theme.nix`

- [ ] **SWWW** - Animated wallpaper daemon
  - Transition effects
  - Wallpaper randomizer script
  - Per-workspace wallpapers (optional)
- [ ] **Stylix Integration** - Unified theming
  - Auto-generate colors from wallpaper
  - Theme Waybar, Rofi, terminals, GTK, QT
  - Multiple theme presets

### 🔲 Phase 6: Advanced Features

**Files:** Various

- [ ] **Pyprland** - Dropdown terminals, scratchpads
  - Quake-style dropdown terminal
  - Floating scratchpad workspaces
- [ ] **Hyprshot** - Advanced screenshots
  - Window, region, output modes
  - Auto-save to Pictures
  - Edit with Swappy
- [ ] **Workspace Overview** - Quick workspace switcher
  - Visual workspace preview
  - Window thumbnails
- [ ] **Gesture Support** - Touchpad gestures
  - 3-finger swipe for workspaces
  - Pinch to zoom

---

## Ideas for an Exceptional Setup

### 🎨 Visual Excellence

1. **Dynamic Color Theming**
   - Use `matugen` or `pywal` to generate themes from wallpaper
   - Hot-reload Waybar/Rofi colors without restart
   - Time-of-day themes (light during day, dark at night)

2. **Stunning Animations**
   - Custom bezier curves for window open/close
   - Workspace slide transitions
   - Fade effects for focus changes
   - Consider `hyprspace` for macOS-style Mission Control

3. **Glass Morphism**
   - Frosted glass effect on Waybar
   - Semi-transparent terminal backgrounds
   - Blur behind floating windows

4. **Custom Cursors & Icons**
   - Bibata or Catppuccin cursors
   - Papirus icon theme
   - Consistent styling everywhere

### ⚡ Productivity Boosters

1. **Smart Workspace Management**
   - Named workspaces (🌐 Web, 💻 Code, 📧 Mail, 🎵 Music)
   - Auto-move apps to designated workspaces
   - Persistent workspace layouts

2. **Scratchpad Power User**
   - `SUPER+\`` for dropdown terminal
   - `SUPER+N` for quick notes (floating Obsidian/Notion)
   - `SUPER+M` for music player scratchpad
   - `SUPER+C` for calculator

3. **Window Grouping**
   - Tab groups like browser tabs for windows
   - Master-stack layout for coding
   - Easy resize with `SUPER+mouse`

4. **Quick Actions Menu**
   - `SUPER+X` for power menu (logout, reboot, shutdown, lock)
   - `SUPER+P` for display configuration
   - `SUPER+B` for Bluetooth quick connect

### 🔧 Developer Experience

1. **IDE Integration**
   - Auto-tile for code + terminal layout
   - Focus follows mouse in editor workspaces
   - Quick project switcher via Rofi

2. **Terminal Workflow**
   - Ghostty with ligatures and Nerd Fonts
   - Tmux integration (optional)
   - Zoxide for directory jumping

3. **Git Integration**
   - Lazygit keybind from anywhere
   - Git status in Waybar
   - Commit notification sounds

### 🎮 Gaming & Media

1. **Game Mode**
   - Disable animations
   - Disable blur
   - Max performance settings
   - Auto-detect Steam/Lutris games

2. **Media Controls**
   - MPRIS integration in Waybar
   - Album art in notifications
   - Global play/pause overlay

### 🔒 Security & Privacy

1. **Screen Lock**
   - Fingerprint support
   - Auto-lock on lid close
   - USB disconnect lock

2. **Privacy Indicators**
   - Camera/mic in-use indicator in Waybar
   - Screen share indicator

### 📱 Multi-Monitor Mastery

1. **Per-Monitor Workspaces**
   - Independent workspace sets per monitor
   - Easy window throw between monitors

2. **Hot-Plug Support**
   - Auto-configure new displays
   - Save monitor profiles
   - Laptop lid behavior

### 🤖 Automation & Scripts

1. **Useful Scripts**
   - `hypr-gamemode` - Toggle gaming optimizations
   - `hypr-record` - Screen recording with wf-recorder
   - `hypr-color-picker` - Pick color anywhere on screen
   - `hypr-ocr` - Screenshot to text with Tesseract
   - `hypr-wifi` - Quick WiFi switcher via Rofi

2. **System Integration**
   - Auto-start apps on specific workspaces
   - Restore session after reboot
   - Sync clipboard with phone (KDE Connect)

---

## Configuration Reference

### Enabling Hyprland

**In host configuration** (e.g., `hosts/nixos/nix-02/default.nix`):
```nix
services.clubcotton.hyprland.enable = true;
```

**In user configuration** (e.g., `home/bcotton.nix`):
```nix
imports = [
  ./modules/hyprland
];

programs.hyprland-config = {
  enable = true;
  terminal = "ghostty";
  browser = "firefox";
  modifier = "SUPER";
  
  # Optional customizations
  enableRofi = true;
  enableWaybar = true;
  gapsIn = 5;
  gapsOut = 10;
  borderSize = 2;
  activeBorderColor = "rgb(89b4fa)";
  inactiveBorderColor = "rgb(313244)";
  
  # Monitor configuration
  monitors = [
    "DP-1,2560x1440@144,0x0,1"
    "HDMI-A-1,1920x1080@60,2560x0,1"
  ];
  
  # Extra settings (merged into hyprland config)
  extraSettings = {
    decoration.rounding = 12;
  };
  
  # Raw config lines
  extraConfig = ''
    # Custom binds or settings
  '';
};
```

### Available Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable Hyprland config |
| `enableRofi` | bool | true | Enable Rofi launcher |
| `enableWaybar` | bool | true | Enable Waybar |
| `enableKeybindingsMenu` | bool | true | Enable keybindings menu (SUPER+/) |
| `terminal` | string | "ghostty" | Default terminal |
| `browser` | string | "firefox" | Default browser |
| `modifier` | string | "SUPER" | Main modifier key |
| `monitors` | list | auto | Monitor configs |
| `gapsIn` | int | 5 | Gap between windows |
| `gapsOut` | int | 10 | Gap to screen edge |
| `borderSize` | int | 2 | Window border size |
| `activeBorderColor` | string | Catppuccin blue | Active border |
| `inactiveBorderColor` | string | Catppuccin surface | Inactive border |
| `extraSettings` | attrs | {} | Merge into settings |
| `extraConfig` | lines | "" | Raw config lines |

---

## Troubleshooting

### Common Issues

**Black screen after login:**
```bash
# Check Hyprland logs
cat ~/.local/share/hyprland/hyprland.log

# Try starting manually
Hyprland
```

**Waybar not appearing:**
```bash
# Check if running
pgrep waybar

# Start manually
waybar

# Check systemd status
systemctl --user status waybar
```

**Rofi not launching:**
```bash
# Test directly
rofi -show drun

# Check if rofi-wayland is installed
which rofi
```

**Screen sharing not working:**
```bash
# Verify portals are running
systemctl --user status xdg-desktop-portal-hyprland

# Check portal configuration
ls -la /run/current-system/sw/share/xdg-desktop-portal/portals/
```

### Useful Commands

```bash
# Reload config
hyprctl reload

# List keybindings
hyprctl binds

# Monitor info
hyprctl monitors

# Window info
hyprctl clients

# Active window
hyprctl activewindow

# Hyprland version
hyprctl version
```

---

## File Structure

```
nix-config/
├── clubcotton/
│   └── services/
│       └── hyprland/
│           └── default.nix          # NixOS system module
│
└── home/
    └── modules/
        └── hyprland/
            ├── default.nix           # Main module, options, core config
            ├── rofi.nix              # Application launcher
            ├── waybar.nix            # Status bar
            ├── keybindings-menu.nix  # Keybindings help menu
            ├── windowrules.nix       # (Phase 3) Window rules
            ├── hypridle.nix          # (Phase 4) Idle management
            ├── hyprlock.nix          # (Phase 4) Lock screen
            ├── notifications.nix     # (Phase 4) Notification daemon
            ├── wallpaper.nix         # (Phase 5) Wallpaper management
            └── scripts/              # (Phase 6) Helper scripts
                ├── gamemode.sh
                ├── screenshot.sh
                └── ...
```

---

## Resources

- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Hyprland GitHub](https://github.com/hyprwm/Hyprland)
- [ZaneyOS Hyprland Config](https://github.com/zaney/zaneyos) - Inspiration source
- [Catppuccin Theme](https://github.com/catppuccin/catppuccin)
- [r/unixporn](https://reddit.com/r/unixporn) - Rice inspiration
- [Hyprland Dots](https://github.com/topics/hyprland-dotfiles) - Community configs

---

## Changelog

### 2025-12-19
- **Keybindings Menu**: Added searchable keybindings menu (SUPER+/) inspired by omarchy

### 2025-06-17
- **Phase 1 Complete**: Basic Hyprland setup with GDM, keybindings, clipboard
- **Phase 2 Complete**: Rofi launcher and Waybar status bar with Catppuccin theme

---

*Last updated: 2025-12-19*

