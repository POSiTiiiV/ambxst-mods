# Special Workspaces for Ambxst

[![Ambxst Compatibility](https://img.shields.io/badge/Ambxst-1.3.0%2B-blue.svg)](https://github.com/Axenide/Ambxst)
[![Version](https://img.shields.io/badge/Version-1.0.1-brightgreen.svg)](ambxst.mod.json)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Extracted from `positive.dock-enhancements` so isolated-special-workspace behavior and generic dock behavior can evolve independently.

Provides:
1. **Isolated special-workspace state**: watches `/tmp/ambxst_special_ws.txt` (written by Hyprland-side keybind Lua — see "Required Hyprland config" below) and derives `inSpecialWorkspace`/`effectiveActiveWorkspaceId`, so the workspace row keeps showing your saved regular workspace as active while an isolated special workspace is open.
2. **Blocked navigation while isolated**: wheel-scroll and workspace-button clicks are no-ops while a special workspace is open.
3. **Dimmed active-workspace highlight**: the highlight pill switches to a dimmed "focus" variant while isolated, since it no longer represents your real focus.
4. **Per-button special indicator**: each workspace button shows a dot (empty) or pill (occupied), with the anchor workspace dimmed, while in special-workspace mode.
5. **Dock awareness**: the dock includes special-workspace windows when deciding whether to auto-hide.
6. **Exclusive-fullscreen fix inside special workspaces** (`v1.0.1`): the bar/dock now correctly hide for a truly-fullscreen window inside an isolated special workspace. `positive.dock-enhancements`' fullscreen guard checks whether a fullscreen window's workspace matches the monitor's *regular* active workspace — but isolating a special workspace keeps the monitor's reported active workspace on the hidden background "isolated" workspace, so a fullscreen window inside the special workspace itself never matched. This mod extends that check to also match the currently-open special workspace.

This mod does **not** render an app-name/icon badge — that's owned by [`positive.workspace-app-indicator`](https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/workspace-app-indicator), which reads `inSpecialWorkspace`/`specialWsData` from this mod to show the currently focused app whether you're on a regular or a special workspace.

Depends on [`positive.dock-enhancements`](https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/dock-enhancements) (for `hideForFloating`/`effectiveWindows` in `DockContent.qml`, which this mod extends to also fold in special-workspace windows).

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

```bash
ambxst mods install-dependencies positive.special-workspaces  # pulls in dock-enhancements first
ambxst mods install https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/special-workspaces
ambxst mods enable positive.special-workspaces
ambxst reload
```

Or via the GUI: **Ambxst Settings → Mods → Package source**, paste the package URL, **Install**, then enable it (and its `dock-enhancements` dependency) in the list. Don't forget the Hyprland config step above.

## License

MIT © [POSiTiiiV](https://github.com/POSiTiiiV)
