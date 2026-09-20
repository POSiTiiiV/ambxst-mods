# Wallpaper Transitions for Ambxst

[![Ambxst Compatibility](https://img.shields.io/badge/Ambxst-1.3.6%2B-blue.svg)](https://github.com/Axenide/Ambxst)
[![Version](https://img.shields.io/badge/Version-1.3.2-brightgreen.svg)](ambxst.mod.json)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Wayland%20%7C%20Hyprland%20%7C%20Niri-purple.svg)]()

A premier modification package for the [Ambxst Desktop Environment](https://github.com/Axenide/Ambxst). Adds fluid animated transitions across images, GIFs, and videos, random wallpaper shuffle, automated background rotation, an in-tab settings panel with full keyboard navigation, and fast library browsing.

---

## Features

### Smooth Animated Transitions
- **10 Transition Styles**: Crossfade, Circle Expand (Iris Out), Circle Shrink (Iris In), Slide (Left, Right, Up, Down), Zoom & Fade, Ambxst Pulse, and Instant Swap.
- **6 Easing Curves**: Cubic, Ease In-Out, Exponential, Elastic Back, Quadratic, and Linear.
- **Speed Presets**: Fast (200ms), Normal (400ms), Smooth (700ms), and Cinematic (1200ms).
- **Multi-Format Support**: Seamless transitions between static images, animated GIFs, and live videos (`.mp4`, `.webm`, `.mov`, `.mkv`).
- **Fluid & Stutter-Free**: Engineered to eliminate mid-transition pauses, black frames, or compositor freezing during wallpaper changes.

### Randomization & Automation
- **Top-Bar Shuffle Button**: Quickly change to a random wallpaper with a single click in the wallpaper picker.
- **Fair Shuffle Deck**: Permutation-based shuffle ensures every wallpaper in your rotation pool plays before repeating.
- **Customizable Directory & Category Pools**: Choose which categories (Images, GIFs, Videos) or specific subfolders you want your random and periodic wallpapers picked from.
- **Live Pool Counter**: Shows how many wallpapers match your active rotation pool in real time.
- **Periodic Background Rotation**: Automatically rotate wallpapers at configurable intervals (1 minute up to 2 hours), persisting across reboots.
- **Compositor Shortcut Support**: Can be bound to any key combination in your compositor configuration via `ambxst run wallpaper-random`.

### In-Tab Settings Panel
- **Integrated Dashboard View**: Open settings directly inside the wallpapers tab without disruptive popups or separate windows.
- **Full Keyboard Navigation**:
  - Navigate settings cards and options using arrow keys.
  - Jump between major sections using <kbd>Tab</kbd> and <kbd>Shift + Tab</kbd>.
  - Toggle options and directory filters with <kbd>Space</kbd> or <kbd>Enter</kbd>.
  - Press <kbd>Esc</kbd> to return directly to the wallpaper picker with the search bar automatically focused.
- **Theming Controls**: Switch between Material You color schemes and presets on the fly.

### Fast & Responsive Browsing
- **Snappy Tab Opening**: Settings and background tasks load on demand, keeping the wallpaper picker fast to open and close.
- **Smooth Grid Scrolling**: Optimized thumbnail caching and virtualization for a seamless browsing experience.
- **Reliable Direct Launch**: Opening directly to the wallpapers tab from a shortcut reliably renders the grid without blank states.

---

## Installation

### Option 1: Via Ambxst CLI (Recommended)

```bash
ambxst mods install https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/wallpaper-transitions
ambxst mods enable positive.wallpaper-transitions
ambxst reload
```

### Option 2: From Local Source

```bash
git clone https://github.com/POSiTiiiV/ambxst-mods.git
ambxst mods install ./ambxst-mods/packages/wallpaper-transitions
ambxst mods enable positive.wallpaper-transitions
ambxst reload
```

### Option 3: Via Ambxst GUI

1. Open Ambxst Settings (`SUPER + S` or open Dashboard → Settings tab).
2. Go to **Mods** in the left sidebar.
3. Paste `https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/wallpaper-transitions` into **Package source** and click **Install**.
4. Select **Wallpaper Transitions** in the list and click **Enable**.

---

## Keybinding Setup (Optional)

To trigger a random wallpaper transition with a keyboard shortcut, bind `ambxst run wallpaper-random` in your compositor configuration:

### Hyprland

Using Hyprland Lua configuration (`~/.config/hypr/lua/custom/custom_binds.lua`):
```lua
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("ambxst run wallpaper-random"))
```

Or in standard `~/.config/hypr/hyprland.conf`:
```ini
bind = SUPER SHIFT, W, exec, ambxst run wallpaper-random
```

### Niri

In `~/.config/niri/config.kdl`:
```kdl
Mod+Shift+W { spawn "ambxst" "run" "wallpaper-random"; }
```

---

## Navigation & Controls

### Wallpaper Picker

| Key | Action |
| :--- | :--- |
| <kbd>Tab</kbd> | Cycle forwards through header controls: Search → Screen → OLED → Tint → Day/Night → Shuffle → Settings → Filters |
| <kbd>Shift + Tab</kbd> | Cycle backwards through header controls |
| <kbd>↑</kbd> <kbd>↓</kbd> <kbd>←</kbd> <kbd>→</kbd> | Navigate wallpaper grid items (works directly while typing in search) |
| <kbd>Enter</kbd> / <kbd>Space</kbd> | Apply selected wallpaper / trigger focused control |
| <kbd>Esc</kbd> | Focus search bar / close dashboard |

### Settings Panel

| Key | Action |
| :--- | :--- |
| <kbd>Tab</kbd> / <kbd>Shift + Tab</kbd> | Jump between section headers (Styles ↔ Curves ↔ Speed ↔ Automation ↔ Schemes ↔ Presets ↔ Back) |
| <kbd>↑</kbd> <kbd>↓</kbd> | 2D vertical navigation across options |
| <kbd>←</kbd> <kbd>→</kbd> | 2D horizontal navigation between cards and chips |
| <kbd>Space</kbd> / <kbd>Enter</kbd> | Toggle periodic rotation, interval pills, or pool filter chips |
| <kbd>Esc</kbd> | Return to the wallpaper picker and focus search |

---

## CLI & IPC API Reference

Automate actions from terminal scripts, status bars, or keybindings:

```bash
# Open wallpaper picker (always returns to the wallpaper grid)
ambxst run wallpapers

# Shuffle to a random wallpaper
ambxst run wallpaper-random

# Set transition style via IPC
ambxst ipc call GlobalStates.setWallpaperTransitionStyle '["circleOut"]'

# Set transition duration in milliseconds
ambxst ipc call GlobalStates.setWallpaperTransitionDuration '[400]'

# Toggle periodic background rotation
ambxst ipc call GlobalStates.setWallpaperPeriodicEnabled '[true]'

# Set rotation interval in minutes (e.g. 15 minutes)
ambxst ipc call GlobalStates.setWallpaperPeriodicInterval '[15]'

# Filter random and periodic pool by categories or subfolders (empty array = all wallpapers)
ambxst ipc call GlobalStates.setWallpaperRandomSourceFilters '["video", "subfolder_nature"]'
```

---

## License

MIT © [POSiTiiiV](https://github.com/POSiTiiiV)
