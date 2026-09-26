# Wallpaper Transitions for Ambxst

[![Ambxst Compatibility](https://img.shields.io/badge/Ambxst-1.3.6%2B-blue.svg)](https://github.com/Axenide/Ambxst)
[![Version](https://img.shields.io/badge/Version-1.4.0-brightgreen.svg)](ambxst.mod.json)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Wayland%20%7C%20Hyprland%20%7C%20Niri-purple.svg)]()

A premier modification package for the [Ambxst Desktop Environment](https://github.com/Axenide/Ambxst). Adds fluid animated transitions across images, GIFs, and videos, random wallpaper shuffle, automated background rotation with custom intervals and Time of Day (Solar) schedules, an in-tab settings panel with full keyboard navigation, and fast library browsing.

---

## Features

### Smooth Animated Transitions
- **10 Transition Styles**: Crossfade, Circle Expand (Iris Out), Circle Shrink (Iris In), Slide (Left, Right, Up, Down), Zoom & Fade, Ambxst Pulse, and Instant Swap.
- **6 Easing Curves**: Cubic, Ease In-Out, Exponential, Elastic Back, Quadratic, and Linear with marquee text previews.
- **Speed Presets**: Fast (200ms), Normal (400ms), Smooth (700ms), and Cinematic (1200ms).
- **Multi-Format Support**: Seamless transitions between static images, animated GIFs, and live videos (`.mp4`, `.webm`, `.mov`, `.mkv`).
- **Fluid & Stutter-Free**: Engineered to eliminate mid-transition pauses, black frames, or compositor freezing during wallpaper changes.

### Live Wallpaper Playback & Power Saving
- **Intelligent Playback Pausing**: Automatically pauses video and GIF wallpapers when apps enter exclusive fullscreen mode or cover the screen to conserve GPU/CPU and VRAM.
- **Configurable Modes**: Choose between *Fullscreen only (Default)*, *Maximized & Fullscreen*, or *Never pause*.
- **Per-Monitor Scope Control**: Select whether pausing applies to *Current monitor only (Default)* so other screens keep playing, or across *All monitors*.
- **Marquee Descriptions**: Overflowing option subtitles and easing descriptions smoothly scroll when hovered or active.
- **Zero Overhead**: One-shot video sink detection and coalesced window-state debouncing maintain 60fps dashboard animations.

### Automation, Custom Timer & Match Time of Day
- **Automatic Wallpaper Rotation**: Choose from standard interval presets (`30s`, `1m`, `5m`, `15m`, `30m`, `1h`, `2h`) or click the dedicated **Custom Timer** button for full control.
- **Precision Custom Timer Steppers**:
  - Direct keyboard input into **HOURS**, **MINUTES**, and **SECONDS** fields with continuous two-way reactive synchronization.
  - Tactile physical stepper buttons (`[ − ]` and `[ + ]`) with clear borders, glowing hover effects, and pointer cursor states.
  - Per-second adjustment precision on the seconds stepper.
  - Live preview button (`Set Timer (Xh Ym Zs)`) to confirm and apply intervals.
- **Match Time of Day (Independent Toggle)**: A dedicated toggle switch that synchronizes randomly selected wallpapers with the current time of day without locking you out of your custom interval schedule:
  - 🌅 **Morning** (06:00 – 11:00): Soft morning light & bright daylight tones.
  - ☀️ **Afternoon** (11:00 – 17:00): Warm, vibrant, high-luminance daylight.
  - 🌇 **Sunset** (17:00 – 21:00): Golden hour, warm amber & dusk palettes.
  - 🌙 **Night** (21:00 – 06:00): Deep dark, starry, midnight aesthetics.
- **Blazing Fast Solar Indexing**: Automatically classifies thousands of wallpapers by luminance and color warmth in under 2 seconds, caching results for instant O(1) matching.
- **Day/Night Boundary Auto-Switching**: Automatically rotates to a matching wallpaper whenever system time crosses between solar phases (e.g. at sunset or morning).
- **Live Active Phase Badge**: Displays real-time phase status and matching wallpaper counters directly on the settings card.
- **Top-Bar Shuffle Button**: Quickly trigger a random wallpaper transition with one click directly inside the wallpaper picker.
- **Fair Shuffle Deck**: Permutation-based shuffle ensures every wallpaper in your rotation pool plays before repeating.
- **Customizable Directory & Category Pools**: Filter rotation candidates by category (Images, GIFs, Videos) or specific directory subfolders.
- **Live Pool Counter**: Shows the exact number of wallpapers matching your active filters.
- **Compositor Shortcut Support**: Bind `ambxst run wallpaper-random` to any keybinding in your compositor.

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

# Set rotation interval in seconds (e.g. 900 for 15 minutes, 30 for 30s)
ambxst ipc call GlobalStates.setWallpaperPeriodicSeconds '[900]'

# Toggle Match Time of Day (Solar Sync)
ambxst ipc call GlobalStates.setWallpaperSolarSyncEnabled '[true]'

# Set live video/GIF pause mode ("fullscreen", "maximized", or "never")
ambxst ipc call GlobalStates.setWallpaperPauseMode '["fullscreen"]'

# Set live video/GIF pause scope ("perScreen" or "allScreens")
ambxst ipc call GlobalStates.setWallpaperPauseScope '["perScreen"]'

# Filter random and periodic pool by categories or subfolders (empty array = all wallpapers)
ambxst ipc call GlobalStates.setWallpaperRandomSourceFilters '["video", "subfolder_nature"]'
```

---

## License

MIT © [POSiTiiiV](https://github.com/POSiTiiiV)
