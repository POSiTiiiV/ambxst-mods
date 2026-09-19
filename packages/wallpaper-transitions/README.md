# Wallpaper Transitions

A native modification package for [Ambxst](https://github.com/Axenide/Ambxst) introducing smooth, configurable animated transitions when switching wallpapers, random wallpaper shuffle actions, and automated periodic wallpaper rotation, complete with an in-tab Advanced Settings panel.

---

## ✨ Features

- **Clean Top Bar with Instant Toggles**:
  - **Search Bar**: Instant filtering across images, gifs, and video wallpapers.
  - **Per-Screen Monitor Selector**: Target a specific monitor (`eDP-1`, `HDMI-A-1`) or apply globally.
  - **OLED Mode Toggle**: True pitch-black mode for OLED displays kept accessible right on the bar.
  - **Tint Mode Toggle**: Dynamic shader tinting kept accessible right on the bar.
  - **Day / Night Toggle**: Instant switch between Light and Dark themes directly from the wallpaper picker.
  - **Random Shuffle Button (``)**: Click to immediately transition to a random wallpaper from your collection.
  - **Advanced Settings Button (`⚙`)**: Opens the dedicated in-tab configuration panel.
- **Randomizer & Automation**:
  - **Instant Wallpaper Shuffle**: Shuffle button in both the top bar and Advanced Settings.
  - **CLI / IPC Command**: Trigger a random wallpaper anytime via `ambxst run wallpaper-random`.
  - **Hyprland / Compositor Keybind Ready**: Bind any key to switch wallpapers randomly.
  - **Periodic Wallpaper Rotation**: Automatic background rotation with configurable intervals (`1m`, `5m`, `15m`, `30m`, `1h`, `2h`), persisted across restarts.
- **10 Animated Transition Styles**:
  - **Crossfade (Default)**: Smooth, continuous opacity dissolve between wallpapers without black flashes.
  - **Circle Expand (Iris Out)**: Circular iris expands smoothly outward from screen center to the corners.
  - **Circle Shrink (Iris In)**: Circular iris contracts inward toward the screen center, revealing the incoming wallpaper.
  - **Slide Left**: Pushes outgoing wallpaper off to the left as incoming slides in.
  - **Slide Right**: Pushes outgoing wallpaper off to the right as incoming slides in.
  - **Slide Up**: Pushes outgoing wallpaper upwards as incoming slides in.
  - **Slide Down**: Pushes outgoing wallpaper downwards as incoming slides in.
  - **Zoom & Fade**: Cinematic scale & depth dissolve.
  - **Ambxst Pulse**: Subtle zoom and opacity pulse.
  - **Instant**: Seamless instantaneous swap with preloaded texture (zero black flash).
- **6 Distinct Easing Curves**:
  - **Cubic (Default)**: Natural ease-out deceleration (starts briskly, settles gently).
  - **Ease In-Out**: Dynamic S-curve (gradual start, fast mid-flight, gentle settle).
  - **Exponential**: High-velocity cinematic snap with an elongated, gentle deceleration tail.
  - **Elastic Back**: Dynamic spring physics with subtle overshoot.
  - **Quadratic**: Soft, gentle deceleration curve.
  - **Linear**: Constant, unvaried speed from start to end.
- **Quick Duration Presets**: Fast (`200ms`), Normal (`400ms`), Smooth (`700ms`), Cinematic (`1200ms`).
- **Unified Multimedia Transitions**:
  - Full animated transition support across all media formats: **Static Images** (`.png`, `.jpg`, `.webp`), **Animated GIFs** (native looping `AnimatedImage`), and **Live Videos** (`.mp4`, `.webm`, etc.).
  - Smooth concurrent video decoding during transitions with automatic frame readiness detection (`positionMs > 0`) to guarantee **zero black frames**.
  - Works between any combination: Image ↔ Image, Image ↔ GIF, GIF ↔ GIF, Image ↔ Video, GIF ↔ Video, and Video ↔ Video.
- **Ambxst 1.3.6+ Modern Stack Compatibility**:
  - Lockscreen video synchronization (`activeVideo.positionMs`) preserved.
  - Native Niri overview blur pass support across all media types.
  - High-quality image downscaling with `mipmap: true`.
- **High-Performance Large-Library Wallpaper Picker**:
  - Eliminates blocking disk scans on tab opening for instantaneous opening and closing.
  - Optimized delegate caching and singleton active wallpaper path matching ensuring 60fps buttery scrolling across massive libraries (5,000+ wallpapers).
  - Power-efficient spinner animation that halts when invisible or loaded.
- **VRAM & Memory Efficient**: Dual-buffer transition engine unloads previous wallpaper textures and stops inactive video decoders immediately once transitions finish, preventing memory or GPU VRAM leaks.

---

## 🚀 Installation

### Via Ambxst CLI (Recommended)

```bash
ambxst mods install https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/wallpaper-transitions
ambxst mods enable positive.wallpaper-transitions
ambxst reload
```

Or install from a local clone:

```bash
git clone https://github.com/POSiTiiiV/ambxst-mods.git
ambxst mods install ./ambxst-mods/packages/wallpaper-transitions
ambxst mods enable positive.wallpaper-transitions
ambxst reload
```

### Via Ambxst GUI

1. Open Ambxst Settings (`SUPER + S` or open Dashboard → Settings tab).
2. Navigate to the **Mods** section in the left sidebar.
3. Paste `https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/wallpaper-transitions` into the **Package source** input field and click **Install**.
4. Select **Wallpaper Transitions** in the list and click **Enable**.
5. Ambxst builds a clean generation and reloads automatically.

---

## ⌨️ Shortcuts & Commands

### Random Wallpaper Keybind

To change to a random wallpaper anytime using a keybinding, add this to your `~/.config/hypr/hyprland.conf`:

```ini
bind = $mainMod, W, exec, ambxst run wallpaper-random
```

Or run directly in your terminal:

```bash
ambxst run wallpaper-random
```

### Keyboard Navigation

#### 1. In the Wallpaper Picker (`SUPER + ,`)

- **<kbd>Tab</kbd> (Forward Cycle)**:
  `Search Bar` → `Monitor Toggle (eDP-1)` → `OLED Mode` → `Tint Mode` → `Day/Night Toggle` → `Shuffle Button ()` → `Settings Button (⚙)` → `Filter Bar` → `Search Bar`
- **<kbd>Shift + Tab</kbd> (Reverse Cycle)**:
  Traverses backwards through all controls.
- **On Search Bar**:
  - Typing filters wallpapers instantly.
  - Arrow keys (<kbd>↑</kbd> <kbd>↓</kbd> <kbd>←</kbd> <kbd>→</kbd>) navigate the grid.
  - <kbd>Enter</kbd> applies the selected wallpaper.
- **On Day/Night Toggle**:
  - <kbd>Enter</kbd> or <kbd>Space</kbd> flips light / dark mode.
- **On Shuffle Button ()**:
  - <kbd>Enter</kbd> or <kbd>Space</kbd> picks a random wallpaper.
- **On Settings Button (⚙)**:
  - <kbd>Enter</kbd> or <kbd>Space</kbd> opens Advanced Settings.

#### 2. In Advanced Settings Panel

- **Arrow Keys (<kbd>←</kbd> <kbd>→</kbd> <kbd>↑</kbd> <kbd>↓</kbd>)**:
  Fluid **2D spatial navigation** across all settings and sub-panels:
  - <kbd>↑</kbd> and <kbd>↓</kbd> move seamlessly across items and navigate between sections (`Transition Style` ↔ `Easing & Duration` ↔ `Automation` ↔ `Color Schemes` ↔ `Presets` ↔ `Back Button`).
  - <kbd>←</kbd> and <kbd>→</kbd> move across items, and cross over horizontally between the `Easing Curve` and `Animation Duration` columns.
- **<kbd>Tab</kbd> / <kbd>Shift + Tab</kbd>**:
  Quickly jumps between major section headers.
- **<kbd>Space</kbd> / <kbd>Enter</kbd>**:
  Applies selected setting, triggers random shuffle, or toggles auto-rotation (arrow keys only navigate without forcing immediate changes).
- **<kbd>Esc</kbd>**:
  Instantly returns to the wallpaper picker and refocuses the search bar.

---

## 📜 License

MIT © [POSiTiiiV](https://github.com/POSiTiiiV)
