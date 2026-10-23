# Dock Enhancements for Ambxst

[![Ambxst Compatibility](https://img.shields.io/badge/Ambxst-1.3.12%2B-blue.svg)](https://github.com/Axenide/Ambxst)
[![Version](https://img.shields.io/badge/Version-2.1.0-brightgreen.svg)](ambxst.mod.json)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> **Requires [`drpezzer.roadie`](https://github.com/drpezzer/ambxst-mods/tree/main/packages/roadie).** The patch is written against roadie's `DockContent.qml`.

Adds one setting to the dock: **Hide dock for floating windows** (Ambxst Settings → Mods, and the Shell → Dock panel). Turn it off and floating windows no longer count as "a window is open", so they don't make the dock hide.

## History

v1.x and v2.0.x also carried an exclusive-fullscreen guard (bar/notch/dock stay visible on a maximize, hide only on true fullscreen). Ambxst 1.3.13 split maximize and fullscreen into separate actions and roadie handles the cover/maximize distinction itself, so v2.1.0 drops that part and keeps only the floating-window toggle.

## Installation

```bash
ambxst mods install https://github.com/drpezzer/ambxst-mods/tree/main/packages/roadie
ambxst mods enable drpezzer.roadie

ambxst mods install https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/dock-enhancements
ambxst mods enable positive.dock-enhancements
ambxst reload
```

## Notes

`DockEnhanceService` only talks to `ModsService` after a 3 second delay. Touching it while the shell is still building its panels crashed Quickshell (Qt 6.12, `QV4::Runtime::IteratorNext`).

## License

MIT © [POSiTiiiV](https://github.com/POSiTiiiV)
