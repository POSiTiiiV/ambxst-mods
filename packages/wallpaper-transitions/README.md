# Wallpaper Transitions

A native modification package for [Ambxst](https://github.com/Axenide/Ambxst) introducing smooth, configurable animated transitions when switching wallpapers, complete with a dedicated in-tab configuration panel.

---

## ✨ Features

- **Dedicated Wallpaper & Transition Settings View**:
  - Accessible via the `[ ⚙ ]` gear button in the Wallpaper Picker top bar (`SUPER + ,`).
  - Replaces cramped dropdowns with a dedicated, spacious, and scrollable configuration panel.
  - Consolidates all wallpaper controls: Transition style, easing curve, animation speed, Material You dynamic schemes, color palette presets, OLED pitch-black mode, live wallpaper tint shader, and light/dark theme toggle.
  - Smooth navigation with a prominent **"Back to Wallpapers"** button and keyboard <kbd>Esc</kbd> support.
- **10 Transition Styles**:
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
- **Native GUI Settings**: Interactive launcher button in **Ambxst Settings → Mods → Wallpaper Transitions**.
- **Live Hot-Reload**: Settings update in real-time without restarting the Ambxst shell.
- **VRAM & Memory Efficient**: Dual-buffer transition engine unloads previous wallpaper textures once transitions finish, preventing memory leaks on high-resolution setups.

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

## 🛠️ Usage

### In Dashboard Wallpaper Tab (`SUPER + ,`)
Click the **Settings** button (`⚙` gear icon) in the top-bar next to the search input. The view switches to the dedicated **Wallpaper & Transition Settings** panel where you can choose transition animations, speed, Material You schemes, display shaders, and color presets.

Navigate using mouse scroll, touchpad, the vertical scrollbar, or keyboard:
- <kbd>↑</kbd> / <kbd>↓</kbd>: Scroll view
- <kbd>←</kbd> / <kbd>→</kbd>: Cycle transition styles
- <kbd>PageUp</kbd> / <kbd>PageDown</kbd>: Fast scroll
- <kbd>Esc</kbd>: Return to wallpaper picker

### In Ambxst Settings (`SUPER + S` → Mods → Wallpaper Transitions)
Click the **`[ ⚙ Open Wallpaper & Transition Settings ]`** button to open the configuration panel directly.

---

## 📜 License

MIT © [POSiTiiiV](https://github.com/POSiTiiiV)
