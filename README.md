# Ambxst Mods by POSiTiiiV

A curated collection of declarative modifications, performance optimizations, and shell enhancements for the [Ambxst Desktop Environment](https://github.com/Axenide/Ambxst), powered by Ambxst's native mod manager.

---

## Available Packages

| Package | Name | Version | Ambxst | Description | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [`wallpaper-transitions`](packages/wallpaper-transitions) | **Wallpaper Transitions** | `v1.3.2` | `>=1.3.0` | Animated transitions (10 styles, 6 easing curves), GIF/video support, random shuffle, custom directory pools, automated rotation, keyboard navigation, and fast browsing. | Active (`v1.3.2`) |

---

## Featured Mod: Wallpaper Transitions (`v1.3.2`)

> Full documentation and IPC reference available in [`packages/wallpaper-transitions/README.md`](packages/wallpaper-transitions/README.md).

### Features
* **10 Transition Styles**: Crossfade, Circle Expand (Iris Out), Circle Shrink (Iris In), Slide (Left, Right, Up, Down), Zoom & Fade, Ambxst Pulse, and Instant Swap.
* **6 Easing Curves & Speeds**: Cubic, Ease In-Out, Exponential, Elastic Back, Quadratic, and Linear with duration presets from Fast (200ms) to Cinematic (1200ms).
* **Smooth & Stutter-Free**: Fluid animations with zero black frames, decoder stalls, or compositor pauses.
* **Full Media Support**: Seamless transitions across static images, animated GIFs, and live videos.
* **Randomization & Automation**:
  * **Top-Bar Shuffle**: Change to a random wallpaper with a single click in the wallpaper picker.
  * **Custom Directory & Category Pools**: Choose which categories (Images, GIFs, Videos) or specific subfolders your random and periodic wallpapers are picked from.
  * **Fair Shuffle Deck**: Ensures every wallpaper in your active pool plays before repeating.
  * **Periodic Rotation**: Automatically cycle wallpapers at configurable intervals (1m to 2h).
  * **Compositor Shortcut Support**: Can be bound to any shortcut in your compositor configuration via `ambxst run wallpaper-random`.
* **Full Keyboard Navigation**:
  * Arrow keys navigate settings and wallpaper grid cleanly.
  * <kbd>Tab</kbd> / <kbd>Shift + Tab</kbd> jumps between section headers.
  * <kbd>Space</kbd> / <kbd>Enter</kbd> toggles options.
  * <kbd>Esc</kbd> returns directly to wallpaper search.
* **Fast & Responsive Browsing**:
  * On-demand settings loading keeps the wallpaper picker fast to open.
  * Smooth scrolling with optimized virtualization and caching.

---

## Quick Install

### Install via Ambxst CLI

```bash
# Install Wallpaper Transitions directly from this repository:
ambxst mods install https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/wallpaper-transitions

# Enable and reload:
ambxst mods enable positive.wallpaper-transitions
ambxst reload
```

### Install via Ambxst GUI

1. Open **Ambxst Settings** (`SUPER + S` or via Dashboard).
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

## Keybinding Setup (Optional)

To trigger a random wallpaper transition with a keyboard shortcut, bind `ambxst run wallpaper-random` in your compositor configuration:

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

## CLI & IPC API Reference

Automate actions directly from terminal scripts, status bars, or keybindings:

```bash
# Open wallpaper picker (always returns to the wallpaper grid)
ambxst run wallpapers

# Shuffle to a random wallpaper
ambxst run wallpaper-random

# Set transition style via IPC
ambxst ipc call GlobalStates.setWallpaperTransitionStyle '["circleOut"]'

# Set transition duration in milliseconds
ambxst ipc call GlobalStates.setWallpaperTransitionDuration '[400]'

# Toggle automated periodic background rotation
ambxst ipc call GlobalStates.setWallpaperPeriodicEnabled '[true]'

# Set rotation interval in minutes (e.g. 15 minutes)
ambxst ipc call GlobalStates.setWallpaperPeriodicInterval '[15]'

# Filter random and periodic pool by categories or subfolders (empty array = all wallpapers)
ambxst ipc call GlobalStates.setWallpaperRandomSourceFilters '["video", "subfolder_nature"]'
```

---

## Repository Structure

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

## License

All packages in this repository are licensed under the [MIT License](LICENSE) unless explicitly specified otherwise within a package directory.
