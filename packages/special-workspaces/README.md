# Special Workspaces for Ambxst

[![Ambxst Compatibility](https://img.shields.io/badge/Ambxst-1.3.0%2B-blue.svg)](https://github.com/Axenide/Ambxst)
[![Version](https://img.shields.io/badge/Version-3.0.0-brightgreen.svg)](ambxst.mod.json)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> **Requires [`drpezzer.roadie`](https://github.com/drpezzer/ambxst-mods/tree/main/packages/roadie)** for the dock/fullscreen side of special-workspace awareness — see below. If you don't use roadie, install [v1.x](https://github.com/POSiTiiiV/ambxst-mods/tree/af33803/packages/special-workspaces) instead.

A single hidden **group** of special workspaces — slot 1, 2, 3, ... — rather than separate single special workspaces each needing their own keybind. One toggle keybind opens/closes the whole group (always landing on slot 1); once inside, you navigate between slots exactly like regular workspaces: `SUPER+Z/X`, scrolling on the bar, or clicking a workspace button directly.

## What this mod provides

1. **A hidden group, not separate workspaces**: `inSpecialWorkspace`/`specialSlotNumber`/`specialOccupiedSlots` derived from `/tmp/ambxst_special_ws.txt` (written by Hyprland-side Lua — see "Required Hyprland config" below).
2. **Full navigation inside the group**: the workspace bar's existing numbering/occupancy/click machinery is reused as-is for special slots (whatever display style you already have configured — numbers, dots, icons — applies here too). `SUPER+Z/X`, scroll, and clicking a slot button all move between slots; swipe is left alone (see "Why not swipe" below).
3. **A "you're in the special group" marker**: the active-workspace highlight pill switches to a dimmed `"focus"` variant instead of `"primary"` while inside the group — the only visual difference from regular workspaces.
4. **Configurable from Ambxst Settings → Mods**: toggle keybind, unlimited vs. fixed slot count, and the group's transition animation (fade by default, slide as an alternative). Changing any of these runs `hyprctl reload` automatically.

This mod does **not** render an app-name/icon badge — that's owned by [`positive.workspace-app-indicator`](https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/workspace-app-indicator), which reads this mod's state to show the currently focused app whether you're on a regular or a special workspace.

## Why not swipe

Hyprland's 3-finger touchpad swipe is a built-in gesture hardcoded to move between regular, numbered workspaces — there's no hook to point it at arbitrary Lua logic or named special workspaces (checked directly against this Hyprland build's own C++ headers). Swipe is left untouched; it simply doesn't do anything special-group-specific. Everything else (keybind, scroll, click) works the same as regular workspaces.

## Unlimited vs. fixed slot count

By default the group is **unlimited**: `SUPER+Z/X` and scrolling can always go one slot further than the last occupied one, creating it on demand — mirroring how Ambxst's own dynamic regular-workspace mode behaves. Switch to a **fixed count** in Settings if you want wraparound (last slot back to slot 1, and vice versa, like a fixed regular-workspace count does).

## Required Hyprland config (not part of this mod)

Ambxst mods can only patch Ambxst's own QML source — they can't touch your Hyprland config or install scripts outside it. Three things live in your own `~/.config/hypr/` and aren't installable through the mod system:

**1. The navigation script** — [`special-workspace-nav.sh`](special-workspace-nav.sh) in this mod's repo. Copy it to `~/.config/hypr/scripts/special-workspace-nav.sh` and `chmod +x` it. It implements slot switching (`toggle`/`next`/`prev`/`goto N`) via `hyprctl`, shared by both the Hyprland keybinds below and the bar's own scroll/click handlers (which call it through `Quickshell.execDetached`). Needs `jq`.

   If your Hyprland build uses a Lua config parser (like this one), plain `hyprctl dispatch workspace 1`-style CLI calls don't work — dispatches have to be given as a Lua expression instead, e.g. `hyprctl dispatch 'hl.dsp.focus({workspace="1"})'`. The script already does this; if you're adapting it for a different Hyprland build, check whether yours needs the same.

**2. `~/.config/hypr/lua/custom/custom_binds.lua`** — the toggle keybind (default `SUPER+SHIFT+V`, configurable from Settings), `SUPER+Z/X` slot-cycling redirection while inside the group, and `SUPER+ALT+V` to move the active window into/out of slot 1. Full working version: see [`hyprland-special-workspaces.lua`](hyprland-special-workspaces.lua) in this mod's repo — copy its contents into your `custom_binds.lua`.

**3. `~/.config/hypr/lua/custom/custom_rules.lua`** — window rules that auto-assign an app to a slot the moment it launches, e.g.:

```lua
-- Vesktop / Discord -> slot 1 by default
hl.window_rule({
    name      = "vesktop-glass",
    match     = { class = "^(vesktop|discord|discord-canary|WebCord)$" },
    workspace = "special:1",
    opacity   = "0.90 0.84 1.0",
})

-- Spotify / Sonora -> slot 2 by default
hl.window_rule({
    name      = "spotify-glass",
    match     = { class = "^([sS]potify)$" },
    workspace = "special:2",
    opacity   = "0.90 0.84 1.0",
})
hl.window_rule({
    name      = "sonora-glass",
    match     = { class = "^(sonora)$" },
    workspace = "special:2",
    opacity   = "0.90 0.84 1.0",
})
```

Add a similar rule for any other app you want auto-assigned, matching its window `class` and picking `workspace = "special:<N>"` for whichever slot number you want it to land in.

Reload with `hyprctl reload` after editing any of the three.

## Installation

Requires `drpezzer.roadie` enabled first (see its own conflicts list — `drpezzer.clean-load`, `drpezzer.multi-monitor-fixes`, `drpezzer.mod-updater`, `drpezzer.settings-float`):

```bash
ambxst mods install https://github.com/drpezzer/ambxst-mods/tree/main/packages/roadie
ambxst mods enable drpezzer.roadie

ambxst mods install https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/special-workspaces
ambxst mods enable positive.special-workspaces
ambxst reload
```

Or via the GUI: **Ambxst Settings → Mods → Package source**, paste each URL, **Install**, then enable both (roadie first). Don't forget the Hyprland config steps above.

## License

MIT © [POSiTiiiV](https://github.com/POSiTiiiV)
