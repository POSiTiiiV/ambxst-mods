# Special Workspaces for Ambxst

[![Ambxst Compatibility](https://img.shields.io/badge/Ambxst-1.3.0%2B-blue.svg)](https://github.com/Axenide/Ambxst)
[![Version](https://img.shields.io/badge/Version-2.0.0-brightgreen.svg)](ambxst.mod.json)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> **v2.0.0 requires [`drpezzer.roadie`](https://github.com/drpezzer/ambxst-mods/tree/main/packages/roadie)** for the dock/fullscreen side of special-workspace awareness — see below. If you don't use roadie, install [v1.x](https://github.com/POSiTiiiV/ambxst-mods/tree/af33803/packages/special-workspaces) instead.

Extracted from `positive.dock-enhancements` so isolated-special-workspace behavior and generic dock behavior can evolve independently.

Provides, purely on the workspace bar (none of this touches the dock — see below):
1. **Isolated special-workspace state**: watches `/tmp/ambxst_special_ws.txt` (written by Hyprland-side keybind Lua — see "Required Hyprland config" below) and derives `inSpecialWorkspace`/`effectiveActiveWorkspaceId`, so the workspace row keeps showing your saved regular workspace as active while an isolated special workspace is open.
2. **Blocked navigation while isolated**: wheel-scroll and workspace-button clicks are no-ops while a special workspace is open.
3. **Dimmed active-workspace highlight**: the highlight pill switches to a dimmed "focus" variant while isolated, since it no longer represents your real focus.
4. **Per-button special indicator**: each workspace button shows a dot (empty) or pill (occupied), with the anchor workspace dimmed, while in special-workspace mode.

This mod does **not** render an app-name/icon badge — that's owned by [`positive.workspace-app-indicator`](https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/workspace-app-indicator), which reads `inSpecialWorkspace`/`specialWsData` from this mod to show the currently focused app whether you're on a regular or a special workspace.

## Why the dock/fullscreen pieces moved to roadie

v1.x also extended `DockContent.qml` (counting special-workspace windows for dock auto-hide) and `CompositorData.qml` (fixing exclusive-fullscreen detection inside a special workspace), both layered on top of `positive.dock-enhancements`. [`drpezzer.roadie`](https://github.com/drpezzer/ambxst-mods/tree/main/packages/roadie) rewrites those same `DockContent.qml` properties for its own boot/reload choreography, with a **more capable, monitor-scoped** version of exactly this (`openSpecialWorkspaceId` + `screenFullscreen`, both set per-output by `UnifiedShellPanel` from Hyprland's own window state) — the two rewrites collide if both are enabled. v2.0.0 drops the now-redundant `DockContent.qml`/`CompositorData.qml` pieces entirely and keeps only the workspace-bar visuals, which roadie doesn't touch at all.

## Required Hyprland config (not part of this mod)

Ambxst mods can only patch Ambxst's own QML source — they can't touch your Hyprland config. The actual keybinds that **open/close** an isolated special workspace, and the window rules that **auto-assign** apps into one, live in your own `~/.config/hypr/lua/` and aren't installable through the mod system. Without them, this mod has state to *watch* but nothing writes it, so nothing will ever look "special."

**1. In `~/.config/hypr/lua/custom/custom_binds.lua`** — the isolation toggle logic and `SUPER+SHIFT+G` (Discord) / `SUPER+SHIFT+V` (Music) keybinds. This also intercepts all workspace-navigation binds (`SUPER+1-10`, `SUPER+X/Z/Y`, mouse wheel) so they no-op while a special workspace is open, and requires an `isolated` empty workspace to exist so nothing bleeds through behind the special one. Full working version: see [`hyprland-special-workspaces.lua`](hyprland-special-workspaces.lua) in this mod's repo — copy its contents into your `custom_binds.lua`.

**2. In `~/.config/hypr/lua/custom/custom_rules.lua`** — window rules that place an app into a special workspace the moment it launches, e.g.:

```lua
-- Vesktop / Discord -> dedicated Discord special workspace
hl.window_rule({
    name      = "vesktop-glass",
    match     = { class = "^(vesktop|discord|discord-canary|WebCord)$" },
    workspace = "special:discord",
    opacity   = "0.90 0.84 1.0",
})

-- Spotify / Sonora -> shared music special workspace
hl.window_rule({
    name      = "spotify-glass",
    match     = { class = "^([sS]potify)$" },
    workspace = "special",
    opacity   = "0.90 0.84 1.0",
})
hl.window_rule({
    name      = "sonora-glass",
    match     = { class = "^(sonora)$" },
    workspace = "special",
    opacity   = "0.90 0.84 1.0",
})
```

Add a similar rule for any other app you want auto-isolated, matching its window `class` and picking a `workspace = "special:<name>"` (or the shared `"special"`) to match whichever keybind you wired it to in step 1.

Reload with `hyprctl reload` after editing either file.

## Installation

Requires `drpezzer.roadie` enabled first (see its own conflicts list — `drpezzer.clean-load`, `drpezzer.multi-monitor-fixes`, `drpezzer.mod-updater`, `drpezzer.settings-float`):

```bash
ambxst mods install https://github.com/drpezzer/ambxst-mods/tree/main/packages/roadie
ambxst mods enable drpezzer.roadie

ambxst mods install https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/special-workspaces
ambxst mods enable positive.special-workspaces
ambxst reload
```

Or via the GUI: **Ambxst Settings → Mods → Package source**, paste each URL, **Install**, then enable both (roadie first). Don't forget the Hyprland config step above.

## License

MIT © [POSiTiiiV](https://github.com/POSiTiiiV)
