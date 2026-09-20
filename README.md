# Ambxst Mods by POSiTiiiV

A curated collection of declarative modifications, performance optimizations, and shell enhancements for the [Ambxst Desktop Environment](https://github.com/Axenide/Ambxst), powered by Ambxst's native mod manager.

---

## 📦 Available Packages

| Package | Name | Version | Ambxst | Description | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [`wallpaper-transitions`](packages/wallpaper-transitions) | **Wallpaper Transitions** | `v1.3.2` | `>=1.3.0` | Animated transitions (10 styles, 6 easing curves), stutter-free rendering, GIF/video support, instant shuffle (`ambxst run wallpaper-random`), custom directory pools, automated rotation, 2D keyboard navigation, and cold-start optimizations. | ✅ Active (`v1.3.2`) |

---

## 🌟 Featured Mod: Wallpaper Transitions (`v1.3.2`)

> Full documentation, architecture breakdown, and IPC reference available in [`packages/wallpaper-transitions/README.md`](packages/wallpaper-transitions/README.md).

### ✨ Highlights & Capabilities
* **🎬 10 Cinematic Transition Styles**: Crossfade, Circle Expand (Iris Out), Circle Shrink (Iris In), Slide Left / Right / Up / Down, Zoom & Fade, Ambxst Pulse, and Instant Swap.
* **📐 6 Precision Easing Curves & Speeds**: Cubic, Ease In-Out, Exponential, Elastic Back, Quadratic, and Linear with duration presets from `200ms` (Fast) up to `1.2s` (Cinematic).
* **⚡ 100% Stutter-Free Animation Engine**:
  * **Deferred Matugen & Lockwall Extraction**: Defers palette generation and ffmpeg lockscreen extraction until the transition finishes (`finishTransition()`), completely eliminating `hyprctl reload` compositor freezes mid-flight.
  * **FBO Boundary Clipping**: Circular mask textures are clipped to viewport bounds (`clip: true`) to prevent offscreen texture reallocation churn during large-diameter iris transitions.
* **🎞️ Unified Multi-Format Media Support**: Seamless crossfades between **Static Images**, **Animated GIFs**, and **Live Videos** (`.mp4`, `.webm`, `.mov`, `.mkv`) with zero black frames or decoding stalls.
* **🎲 Randomization, Directory Pools & Periodic Rotation**:
  * **Compositor Keybinding (`SUPER + SHIFT + W`)**: Trigger instant random wallpaper transitions respecting your chosen directory pool.
  * **Top-Bar Shuffle Button (``)**: Pick a random wallpaper on demand directly from the UI or via CLI/IPC:
    ```bash
    ambxst run wallpaper-random
    ```
  * **Customizable Directory & Category Pool Filtering**: Choose one or multiple directories and categories (`Images`, `GIFs`, `Videos`, or custom subfolders like `cool`, `extra`, etc.) for random shuffle and periodic rotation with real-time pool matching badges.
  * **Fair Fisher-Yates Shuffle Deck**: True zero-repetition permutation shuffle deck. Every wallpaper in your active pool plays exactly once before any repeat can occur.
  * **Automated Periodic Rotation**: Cycle wallpapers automatically in the background at configurable intervals (`1m`, `5m`, `15m`, `30m`, `1h`, `2h`), persisting across reboots.
* **⌨️ Full 2D Spatial Keyboard Navigation**:
  * Arrow keys (<kbd>↑</kbd> <kbd>↓</kbd> <kbd>←</kbd> <kbd>→</kbd>) navigate across all sub-settings without forcing premature changes.
  * Press <kbd>Space</kbd> or <kbd>Enter</kbd> to toggle periodic rotation, intervals, and directory pool chips.
  * <kbd>Tab</kbd> / <kbd>Shift + Tab</kbd> jumps between section headers; <kbd>Esc</kbd> returns smoothly to wallpaper search.
  * Smooth row-by-row auto-scrolling with Wayland touchpad and mouse wheel support.
* **⚡ Wallpaper Library Optimizations (5,000+ Wallpapers)**:
  * Lazy-loads settings view dynamically on demand, completely bypassing instantiation when browsing wallpapers.
  * Eliminates redundant recursive disk sweeps on opening/closing dashboard.
  * Resolves upstream cold-start blank screen issue when invoking `SUPER + ,`.

---

## 🚀 Quick Install

### Install via Ambxst CLI

```bash
# Install Wallpaper Transitions directly from this repository:
ambxst mods install https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/wallpaper-transitions

# Enable and reload:
ambxst mods enable positive.wallpaper-transitions
ambxst reload
```

### Install via Ambxst GUI (Settings)

1. Open **Ambxst Settings** (<kbd>SUPER + S</kbd> or via Dashboard).
2. Navigate to **Mods** in the left sidebar.
3. Paste the package URL into the **Package source** field:
   ```text
   https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/wallpaper-transitions
   ```
4. Click **Install**, then select **Wallpaper Transitions** in the list and click **Enable**.

### Local Clone & Development

```bash
git clone https://github.com/POSiTiiiV/ambxst-mods.git
ambxst mods install ./ambxst-mods/packages/wallpaper-transitions
ambxst mods enable positive.wallpaper-transitions
ambxst reload
```

---

## ⌨️ Custom Keybindings

Bind a shortcut in your compositor configuration to trigger an instant random wallpaper transition:

### Hyprland (Lua Config — `~/.config/hypr/lua/custom/custom_binds.lua`)
```lua
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("ambxst run wallpaper-random"))
```

### Hyprland (Standard Config — `~/.config/hypr/hyprland.conf`)
```ini
bind = SUPER SHIFT, W, exec, ambxst run wallpaper-random
```

### Niri (`~/.config/niri/config.kdl`)
```kdl
Mod+Shift+W { spawn "ambxst" "run" "wallpaper-random"; }
```

---

## 🛠️ CLI & IPC API Reference

Automate wallpaper actions directly from terminal, scripts, or status bars:

```bash
# Open wallpaper picker (always resets directly to wallpaper selector grid)
ambxst run wallpapers

# Shuffle to a random wallpaper immediately with transition
ambxst run wallpaper-random

# Set transition style via IPC
ambxst ipc call GlobalStates.setWallpaperTransitionStyle '["circleOut"]'

# Set transition duration in milliseconds
ambxst ipc call GlobalStates.setWallpaperTransitionDuration '[500]'

# Toggle automated periodic background rotation
ambxst ipc call GlobalStates.setWallpaperPeriodicEnabled '[true]'

# Set rotation interval in minutes (e.g. 15 minutes)
ambxst ipc call GlobalStates.setWallpaperPeriodicInterval '[15]'

# Filter random shuffle & periodic pool by categories or subfolders (empty array = all wallpapers)
ambxst ipc call GlobalStates.setWallpaperRandomSourceFilters '["video", "subfolder_cool"]'
```

---

## 📁 Repository Structure

Following the official Ambxst declarative mod manager specification:

```text
ambxst-mods/
├── README.md
├── LICENSE
└── packages/
    └── wallpaper-transitions/
        ├── ambxst.mod.json
        ├── README.md
        ├── LICENSE
        ├── payload/
        │   ├── TransitionWallpaper.qml
        │   └── WallpaperSettingsView.qml
        └── patches/
            └── wallpaper-transitions.patch
```

---

## 📜 License

All packages in this repository are licensed under the [MIT License](LICENSE) unless explicitly specified otherwise within a package directory.
