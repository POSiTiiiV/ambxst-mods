# Dock Enhancements for Ambxst

[![Ambxst Compatibility](https://img.shields.io/badge/Ambxst-1.3.0%2B-blue.svg)](https://github.com/Axenide/Ambxst)
[![Version](https://img.shields.io/badge/Version-2.0.0-brightgreen.svg)](ambxst.mod.json)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> **v2.0.0 requires [`drpezzer.roadie`](https://github.com/drpezzer/ambxst-mods/tree/main/packages/roadie).** If you don't use roadie, install [v1.x](https://github.com/POSiTiiiV/ambxst-mods/tree/af33803/packages/dock-enhancements) instead — see "Why this depends on roadie now" below.

This mod enhances the Ambxst Dock/bar with:
1. **Exclusive Fullscreen Guard**: Only true exclusive fullscreen (F11 / SUPER+SHIFT+F) hides the bar, notch, and dock. Regular window maximize (SUPER+F) keeps them visible.
2. **Floating Windows Dock Visibility Toggle**: Configurable setting in Ambxst Settings (under Mods) to toggle whether floating windows cause the dock to hide or allow it to remain visible.

Special-workspace-aware dock behavior now lives in [`drpezzer.roadie`](https://github.com/drpezzer/ambxst-mods/tree/main/packages/roadie) directly (see below) rather than a separate mod.

## Why this depends on roadie now

Roadie's own `DockContent.qml` rewrite (for its boot/reload/monitor-hotplug choreography) already implements a **more capable** version of "count special-workspace windows" and "hide for fullscreen" — monitor-scoped, reading Hyprland's window state directly instead of through axctl's polling (which this mod's original v1.x special-workspace-aware auto-hide relied on, via a single global flag file). Running both mods' independent rewrites of the same `DockContent.qml` properties (`toplevels`, `hasWindows`, `activeWindowFullscreen`, `reveal`) side by side isn't possible — they collide.

v2.0.0 drops the now-redundant parts and keeps only what roadie doesn't provide: the floating-window toggle, layered on top of roadie's own `toplevels`/`openSpecialWorkspaceId`. It also fixes a bug in **roadie itself**: roadie's `fullscreenHidden = activeWindowFullscreen || screenFullscreen` inherits `activeWindowFullscreen`'s stock, imprecise definition (`fullscreen == true`, which is also true for a plain maximize, not just exclusive fullscreen) — so a mere `SUPER+F` maximize would incorrectly hide the bar via that OR, even though roadie's own `screenFullscreen` signal is exclusive-only. This mod's `CompositorData.qml` patch (unchanged from v1.x) still provides the precise exclusive-only check, and v2.0.0 feeds it into `activeWindowFullscreen` so roadie's OR-condition is correct on both sides. **This is worth reporting upstream to roadie's author** — if it gets fixed there, this mod's `CompositorData.qml`/`DockContent.qml` pieces become unnecessary.

## Installation

Install `drpezzer.roadie` first (and enable it — it conflicts with `drpezzer.clean-load`, `drpezzer.multi-monitor-fixes`, `drpezzer.mod-updater`, `drpezzer.settings-float`, so disable any of those first):

```bash
ambxst mods install https://github.com/drpezzer/ambxst-mods/tree/main/packages/roadie
ambxst mods enable drpezzer.roadie

ambxst mods install https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/dock-enhancements
ambxst mods enable positive.dock-enhancements
ambxst reload
```

Or via the GUI: **Ambxst Settings → Mods → Package source**, paste each URL, **Install**, then enable both in the list (roadie first).

## License

MIT © [POSiTiiiV](https://github.com/POSiTiiiV)
