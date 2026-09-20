# Wallpaper Transitions for Ambxst

[![Ambxst Compatibility](https://img.shields.io/badge/Ambxst-1.3.6%2B-blue.svg)](https://github.com/Axenide/Ambxst)
[![Version](https://img.shields.io/badge/Version-1.3.2-brightgreen.svg)](ambxst.mod.json)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Wayland%20%7C%20Hyprland%20%7C%20Niri-purple.svg)]()

A premier, high-performance modification package for the [Ambxst Desktop Environment](https://github.com/Axenide/Ambxst). Introduces cinematic animated transitions across all media formats (images, GIFs, and videos), instant random wallpaper shuffle actions, automated background wallpaper rotation, an in-tab Advanced Configuration panel with full 2D spatial keyboard navigation, and deep performance optimizations for massive wallpaper libraries.

---

## ✨ Features & Architecture

### 🎬 Dual-Buffer Transition Engine
- **10 Animated Transition Styles**:
  - **Crossfade (Default)**: Butter-smooth opacity dissolve with zero black frames or flickering.
  - **Circle Expand (Iris Out)**: Expanding circular mask radiating outward from the screen center.
  - **Circle Shrink (Iris In)**: Contracting circular mask focusing inward towards the screen center.
  - **Slide Left / Right / Up / Down**: Directional pushes sliding the incoming wallpaper while pushing the outgoing wallpaper off-screen.
  - **Zoom & Fade**: Cinematic scale-up and depth dissolve.
  - **Ambxst Pulse**: Subtle scale pulsation combined with a soft dissolve.
  - **Instant**: Zero-delay instant swap with pre-cached texture (no flicker).
- **6 Precision Easing Curves**:
  - **Cubic (Default)**: Natural deceleration curve (fast takeoff, soft landing).
  - **Ease In-Out**: Symmetric S-curve (gradual start, fast mid-flight, gentle settle).
  - **Exponential**: High-velocity snap with an elongated deceleration tail.
  - **Elastic Back**: Dynamic spring physics with subtle overshoot.
  - **Quadratic**: Soft, progressive deceleration.
  - **Linear**: Uniform velocity across the entire duration.
- **Speed Presets**: Fast (`200ms`), Normal (`400ms`), Smooth (`700ms`), Cinematic (`1200ms`).
- **Unified Multi-Format Media Support**:
  - Supports transitions between **Static Images** (`.png`, `.jpg`, `.jpeg`, `.webp`, `.bmp`), **Animated GIFs** (hardware-accelerated looping `AnimatedImage`), and **Live Videos** (`.mp4`, `.webm`, `.mov`, `.mkv`).
  - Seamless transitions between any combination: `Image ↔ Image`, `Image ↔ GIF`, `GIF ↔ GIF`, `Image ↔ Video`, `GIF ↔ Video`, and `Video ↔ Video`.
- **⚡ 100% Stutter-Free Performance Architecture**:
  - **Deferred Matugen & Lockscreen Extraction**: In stock Ambxst, Matugen palette generation triggers a compositor reload (`hyprctl reload`) and ffmpeg lockscreen extraction when a wallpaper change begins. The transition engine defers Matugen and ffmpeg execution until the animation finishes (`finishTransition()`), completely eliminating mid-flight compositor hitches and frame drops.
  - **Zero Black Flash**: Dual-slot renderer detects video frame readiness (`positionMs > 0` with timer fallback) before starting the transition, preventing black frames or decoding stalls.
  - **FBO Boundary Clipping**: Circular mask textures are clipped to viewport bounds (`clip: true`) to eliminate offscreen texture reallocation churn during iris transitions.

### 🎲 Randomization & Background Automation
- **Compositor Keybinding (`SUPER + SHIFT + W`)**: Trigger instant random wallpaper transitions respecting your chosen directory pool.
- **Top-Bar Shuffle Button (``)**: Instant single-click random wallpaper trigger directly in the wallpaper picker top bar.
- **Fair Shuffle Deck Engine (Fisher-Yates)**: True zero-repetition permutation shuffle deck. Every wallpaper in your active pool (e.g. 85 videos) plays exactly once before any repeat can occur, with seamless reshuffle boundary protection.
- **Customizable Directory & Category Pool Filtering**: Choose one or multiple directories and categories (`Images`, `GIFs`, `Videos`, or custom subfolders like `cool`, `extra`, etc.) for both random shuffle and periodic rotation. If no categories are chosen, it defaults to your full library.
- **Live Pool Matching Badge**: Real-time counter displays how many wallpapers match your active rotation pool (e.g. `Pool: 85 wallpapers`).
- **Background Periodic Rotation**: Automated periodic wallpaper rotation with persistent intervals (`1m`, `5m`, `15m`, `30m`, `1h`, `2h`), saved to Ambxst configuration and preserved across desktop reboots.

### ⚙️ Dedicated In-Tab Advanced Settings Panel
- **Seamless Modal Experience**: Replaces the wallpaper grid in-place within the dashboard tab without opening a separate popup or disruptive window.
- **Live Visual Feedback**:
  - Active section headers illuminate with your theme accent color without layout shift or jitter.
  - Focused cards feature a crisp 2px primary focus border for clear keyboard navigation.
  - Real-time previews: clicking or applying an option updates configuration immediately.
- **Integrated Theming Controls**:
  - **Material You Color Schemes**: Select between 8 M3 palette schemes (`Tonal Spot`, `Content`, `Expressive`, `Fruit Salad`, `Monochrome`, `Neutral`, `Rainbow`, `Vibrant`).
  - **Color Presets**: Live selection across custom and built-in palettes (`Catppuccin`, `Everforest`, `Gruvbox`, `Nord`, `Rose Pine`, `Tokyonight`, etc.).
- **OLED & Shader Tint Streamlining**: OLED Pitch-Black mode and dynamic wallpaper tinting are preserved on the main wallpaper bar for single-click access, keeping the Advanced Settings panel uncluttered.
- **Pixel-Perfect Viewport Geometry**:
  - Smooth, balanced auto-scrolling that maintains clean 12px bottom padding without empty space voids or clipped preset cards.

### ⚡ Massive Library Performance Optimizations (5,000+ Wallpapers)
- **Zero-Lag Opening & Closing**:
  - **Lazy-Loaded Settings**: The settings view is loaded dynamically via `Loader` only when requested, completely bypassing instantiation and computation when browsing wallpapers.
  - **Eliminated Redundant Disk Sweeps**: Stock Ambxst triggered a blocking `find -L` sweep via `scanSubfolders()` every time the wallpaper tab was opened. The mod guards this so scans only run on initial cold start or when explicitly required, eliminating tab open lag.
  - **Singleton Active Path Matching**: Replaced per-delegate recursive dictionary lookups across thousands of grid items with a singleton `activeWallpaperPath` property, drastically reducing CPU overhead.
  - **Expanded Virtualization Buffers**: Increased `cacheBuffer` and display margins to eliminate delegate creation churn during rapid scrolling.
  - **Power-Efficient Loader Spinners**: Rotating spinner animations automatically halt when items are loaded or hidden from the viewport.
- **Guaranteed Cold-Start Loading (`SUPER + ,`)**:
  - Fixes an upstream Ambxst LRU cache bug where opening directly to the Wallpapers tab via shortcut rendered an empty blank dashboard until manually clicked. Active tabs now load immediately on open.
  - Pressing `SUPER + ,` always takes you directly to the wallpaper selector, automatically resetting the view even if you were previously in the Advanced Settings panel.

---

## 🚀 Installation

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
5. Ambxst automatically builds a new generation and reloads.

---

## ⌨️ Shortcuts & Navigation

### Compositor Keybinding Setup

You can configure a custom shortcut in your compositor configuration to trigger an instant random wallpaper transition:

#### Hyprland (Lua Config — `~/.config/hypr/lua/custom/custom_binds.lua`)
```lua
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("ambxst run wallpaper-random"))
```

#### Hyprland (Standard Config — `~/.config/hypr/hyprland.conf`)
```ini
bind = SUPER SHIFT, W, exec, ambxst run wallpaper-random
```

#### Niri (`~/.config/niri/config.kdl`)
```kdl
Mod+Shift+W { spawn "ambxst" "run" "wallpaper-random"; }
```

### Wallpaper Picker Controls

| Control / Key | Action |
| :--- | :--- |
| <kbd>Tab</kbd> | Cycle forwards: `Search` → `Monitor (eDP-1)` → `OLED` → `Tint` → `Day/Night` → `Shuffle ()` → `Settings (⚙)` → `Filters` |
| <kbd>Shift + Tab</kbd> | Cycle backwards through all header controls |
| <kbd>↑</kbd> <kbd>↓</kbd> <kbd>←</kbd> <kbd>→</kbd> | Navigate wallpaper grid items (or arrow keys directly when focused in search) |
| <kbd>Enter</kbd> / <kbd>Space</kbd> | Apply selected wallpaper / trigger focused button |
| <kbd>Esc</kbd> | Return to search bar / close dashboard |

### Advanced Settings Panel Controls

| Control / Key | Action |
| :--- | :--- |
| <kbd>Tab</kbd> / <kbd>Shift + Tab</kbd> | Jump between major section headers (`Transition Style` ↔ `Easing Curve` ↔ `Duration` ↔ `Automation & Rotation` ↔ `Material You Schemes` ↔ `Presets` ↔ `Back Button`) |
| <kbd>↑</kbd> <kbd>↓</kbd> | **2D Vertical Navigation**: Traverses seamlessly between items and across sections without premature application |
| <kbd>←</kbd> <kbd>→</kbd> | **2D Horizontal Navigation**: Moves between cards, interval pills, and pool chips |
| <kbd>Space</kbd> / <kbd>Enter</kbd> | Toggle periodic rotation switch, interval pills, or random pool source chips |
| <kbd>Esc</kbd> | Return directly to the wallpaper picker and focus the search bar |

---

## 🛠️ CLI & IPC API Reference

You can trigger actions directly from shell scripts, Waybar, or custom keybindings:

```bash
# Open or toggle wallpaper picker (always returns to wallpaper grid)
ambxst run wallpapers

# Transition to a random wallpaper immediately
ambxst run wallpaper-random

# Set a specific transition style via IPC
ambxst ipc call GlobalStates.setWallpaperTransitionStyle '["circleOut"]'

# Set transition duration in milliseconds
ambxst ipc call GlobalStates.setWallpaperTransitionDuration '[500]'

# Toggle automated periodic wallpaper rotation
ambxst ipc call GlobalStates.setWallpaperPeriodicEnabled '[true]'

# Set rotation interval in minutes (e.g. 15 minutes)
ambxst ipc call GlobalStates.setWallpaperPeriodicInterval '[15]'

# Filter random shuffle & periodic pool by categories/subfolders (e.g. videos and subfolder 'cool')
ambxst ipc call GlobalStates.setWallpaperRandomSourceFilters '["video", "subfolder_cool"]'

# Reset pool filter to all wallpapers in library
ambxst ipc call GlobalStates.setWallpaperRandomSourceFilters '[]'
```

---

## 📜 License

MIT © [POSiTiiiV](https://github.com/POSiTiiiV)
