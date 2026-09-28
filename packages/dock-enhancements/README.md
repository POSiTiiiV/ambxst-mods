# Dock Enhancements for Ambxst

[![Ambxst Compatibility](https://img.shields.io/badge/Ambxst-1.3.0%2B-blue.svg)](https://github.com/Axenide/Ambxst)
[![Version](https://img.shields.io/badge/Version-1.0.0-brightgreen.svg)](ambxst.mod.json)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

This mod enhances the Ambxst Dock/bar with:
1. **Exclusive Fullscreen Guard**: Only true exclusive fullscreen (F11 / SUPER+SHIFT+F) hides the bar, notch, and dock. Regular window maximize (SUPER+F) keeps them visible.
2. **Floating Windows Dock Visibility Toggle**: Configurable setting in Ambxst Settings (under Mods) to toggle whether floating windows cause the dock to hide or allow it to remain visible.

Special-workspace-aware dock behavior (accounting for windows on isolated special workspaces) now lives in the separate [`positive.special-workspaces`](https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/special-workspaces) mod, which depends on this one.

## Installation

```bash
ambxst mods install https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/dock-enhancements
ambxst mods enable positive.dock-enhancements
ambxst reload
```

Or via the GUI: **Ambxst Settings → Mods → Package source**, paste the URL above, **Install**, then enable it in the list.

## License

MIT © [POSiTiiiV](https://github.com/POSiTiiiV)
