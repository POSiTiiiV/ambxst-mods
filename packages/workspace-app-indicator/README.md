# Workspace App Indicator for Ambxst

Shows the focused app's icon and name in a small badge next to the workspace row — as a **separate element**, never fused into the workspace number pill itself (the pill stays the same size/shape regardless of what's focused).

Works for both regular and special (isolated) workspaces: when a [`positive.special-workspaces`](https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/special-workspaces) workspace is open, the badge follows whatever's actually focused inside it live — e.g. switching focus between Discord and a terminal both open in the same special workspace updates the badge instantly, using Quickshell's native toplevel tracking rather than the compositor's own window-list snapshot (which can lag a pure focus-only change).

Falls back to a generic "Special N" label/icon when a special-group slot is open but empty — slot numbers don't carry app identity on their own (that's just a default window-rule assignment you can change), so it doesn't try to guess an app name from the slot number.

Requires [`positive.special-workspaces`](https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/special-workspaces) (for special-workspace state), which in turn requires [`drpezzer.roadie`](https://github.com/drpezzer/ambxst-mods/tree/main/packages/roadie).

## Screenshot

![Workspace app indicator badge](screenshot.png)
