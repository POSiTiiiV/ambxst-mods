# Workspace App Indicator for Ambxst

Shows the focused app's icon and name in a small badge next to the workspace row — as a **separate element**, never fused into the workspace number pill itself (the pill stays the same size/shape regardless of what's focused).

Works for both regular workspaces and [`positive.special-workspaces`](https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/special-workspaces)' hidden group alike — since v4.0.0 those are just real regular workspaces reserved above a threshold, so the badge's focused-window lookup needs no special-casing at all.

Falls back to a generic "Special N" label/icon when a hidden-group slot is open but empty — slot numbers don't carry app identity on their own (that's just a default window-rule assignment you can change), so it doesn't try to guess an app name from the slot number.

Requires [`positive.special-workspaces`](https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/special-workspaces) (for `inSpecialWorkspace`/`specialSlotNumber` state).

## Screenshot

![Workspace app indicator badge](screenshot.png)
