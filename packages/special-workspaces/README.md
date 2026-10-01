# Special Workspaces for Ambxst

[![Ambxst Compatibility](https://img.shields.io/badge/Ambxst-1.3.0%2B-blue.svg)](https://github.com/Axenide/Ambxst)
[![Version](https://img.shields.io/badge/Version-4.0.0-brightgreen.svg)](ambxst.mod.json)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A single hidden **group** of real, regular workspaces — slot 1, 2, 3, ... reserved above a configurable threshold (default 50, so slot 1 = workspace 51, slot 2 = workspace 52, etc). One toggle keybind opens/closes the whole group (always landing on slot 1); once inside, you navigate between slots **exactly** like regular workspaces, because they *are* regular workspaces: `SUPER+Z/X`, scrolling the bar, clicking a workspace button, and even 3-finger touchpad swipe all just work, with zero custom dispatch logic.

## Why not Hyprland's native "special workspace" feature

Earlier versions of this mod used Hyprland's built-in special-workspace overlay (`togglespecialworkspace`), which gives "hidden until toggled" for free -- but that feature is architecturally outside the regular-workspace sequence, and touchpad swipe is hardcoded to that sequence with no hook to reach it. There is no API to point swipe at a named special workspace (checked directly against this Hyprland build's own C++ headers).

v4.0.0 drops that feature entirely in favor of a reserved block of **real** workspace numbers. The tradeoff is that "hidden until toggled" is no longer free -- it's enforced by a reactive guard instead (see below) -- but in exchange you get full native navigation, including swipe, inside the group.

## How hiding is enforced

Since slot workspaces are ordinary workspaces, nothing stops Hyprland itself from wandering into them (e.g. scrolling or swiping past your last regular workspace). This mod's Hyprland-side Lua watches every workspace change and, if you land past the threshold **any way other than the toggle keybind**, immediately bounces you back to your last regular workspace. The reverse direction (leaving the hidden group back to regular territory) isn't guarded -- that's not something worth blocking.

This means crossing the boundary by accident causes a brief visual flash (you'll see the hidden workspace for a split second before being bounced back) rather than being silently prevented outright -- there's no lower-level hook available to stop the transition before it happens.

## What this mod provides

1. **A hidden group of real workspaces**: `inSpecialWorkspace`/`specialSlotNumber`/`specialThreshold` derived directly from the active workspace id -- no state files, no id/name lookups.
2. **Full native navigation inside the group**: the workspace bar's existing numbering/occupancy/click machinery is reused as-is for hidden slots (whatever display style you already have configured -- numbers, dots, icons -- applies here too). `SUPER+1-10` jumps to slot N, `SUPER+Z/X`/scroll/swipe/click all move between slots.
3. **A "you're in the group" marker**: the active-workspace highlight pill switches to a dimmed `"focus"` variant instead of `"primary"` while inside the group -- the only visual difference from regular workspaces.
4. **Configurable from Ambxst Settings → Mods**: toggle keybind, the hidden-group threshold, unlimited vs. fixed slot count, and the group's entry/exit animation (fade by default, slide as an alternative). Changing any of these runs `hyprctl reload` automatically.

This mod does **not** render an app-name/icon badge — that's owned by [`positive.workspace-app-indicator`](https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/workspace-app-indicator), which reads this mod's state to show the currently focused app whether you're on a regular or hidden-group workspace.

## Unlimited vs. fixed slot count

By default the group is **unlimited**: `SUPER+Z/X` and scrolling can always go one slot further than the last occupied one, creating it on demand — mirroring how Ambxst's own dynamic regular-workspace mode behaves. Switch to a **fixed count** in Settings if you want wraparound (last slot back to slot 1, and vice versa) -- this is also the only mode where custom (non-native) wraparound logic kicks in for `SUPER+Z/X`, since Hyprland's own relative dispatch has no concept of your custom upper bound.

## Required Hyprland config (not part of this mod)

Ambxst mods can only patch Ambxst's own QML source — they can't touch your Hyprland config. Two things live in your own `~/.config/hypr/` and aren't installable through the mod system:

**1. `~/.config/hypr/lua/custom/custom_binds.lua`** — the toggle keybind (default `SUPER+SHIFT+V`, configurable from Settings), the boundary guard, `SUPER+1-10`/`SUPER+Z/X` slot-aware redirection, and `SUPER+ALT+V` to move the active window into/out of slot 1. Full working version: see [`hyprland-special-workspaces.lua`](hyprland-special-workspaces.lua) in this mod's repo — copy its contents into your `custom_binds.lua`.

   If your Hyprland build uses a Lua config parser (like this one), dispatches have to be given as a Lua expression rather than plain `hyprctl dispatch <name> <args>` CLI syntax, e.g. `hl.dispatch(hl.dsp.focus({workspace="51"}))` from within Lua. The snippet already does this throughout.

**2. `~/.config/hypr/lua/custom/custom_rules.lua`** — window rules that auto-assign an app to a slot the moment it launches, e.g.:

```lua
-- Vesktop / Discord -> slot 1 (workspace 51 with the default threshold)
hl.window_rule({
    name      = "vesktop-glass",
    match     = { class = "^(vesktop|discord|discord-canary|WebCord)$" },
    workspace = "51",
    opacity   = "0.90 0.84 1.0",
})

-- Spotify / Sonora -> slot 2 (workspace 52)
hl.window_rule({
    name      = "spotify-glass",
    match     = { class = "^([sS]potify)$" },
    workspace = "52",
    opacity   = "0.90 0.84 1.0",
})
hl.window_rule({
    name      = "sonora-glass",
    match     = { class = "^(sonora)$" },
    workspace = "52",
    opacity   = "0.90 0.84 1.0",
})
```

Add a similar rule for any other app you want auto-assigned, matching its window `class` and picking `workspace = "<threshold+N>"` for whichever slot number you want it to land in. If you change the threshold from the default 50, update these numbers to match.

Reload with `hyprctl reload` after editing either file.

## Installation

```bash
ambxst mods install https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/special-workspaces
ambxst mods enable positive.special-workspaces
ambxst reload
```

Or via the GUI: **Ambxst Settings → Mods → Package source**, paste the URL, **Install**, then enable it. Don't forget the Hyprland config steps above.

## License

MIT © [POSiTiiiV](https://github.com/POSiTiiiV)
