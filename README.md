# Ambxst Mods by POSiTiiiV

A curated collection of declarative modifications, performance optimizations, and shell enhancements for the [Ambxst Desktop Environment](https://github.com/Axenide/Ambxst), powered by Ambxst's native mod manager.

Each package has its own README with full details, screenshots, and install instructions — this file just lists what's here.

---

## Available Packages

| Package | Name | Version | Description |
| :--- | :--- | :--- | :--- |
| [`wallpaper-transitions`](packages/wallpaper-transitions) | Wallpaper Transitions | `v1.4.0` | Animated wallpaper transitions (10 styles, 6 easing curves), GIF/video support with smart fullscreen pausing, random shuffle, custom rotation timer, solar time-of-day sync. |
| [`dock-enhancements`](packages/dock-enhancements) | Dock Enhancements | `v1.0.0` | Keeps the bar/dock visible during regular window maximize (only true exclusive fullscreen hides it), plus a toggle for whether floating windows hide the dock. |
| [`special-workspaces`](packages/special-workspaces) | Special Workspaces | `v1.0.0` | Isolated special-workspace state, dimmed highlight, per-button dot/pill indicator, and dock auto-hide awareness for isolated workspaces (e.g. a dedicated Discord or Music workspace). Depends on `dock-enhancements`. |
| [`workspace-app-indicator`](packages/workspace-app-indicator) | Workspace App Indicator | `v1.0.0` | Shows the focused app's icon + name in a separate badge beside the workspace row — works for both regular and special workspaces. Depends on `special-workspaces`. |
| [`theme-sync`](packages/theme-sync) | Theme Sync | `v1.0.0` | Live-syncs the wallpaper's Material You palette to Kitty, btop, Starship, Fastfetch, Spicetify, Fuzzel, Sonora and Dolphin, with per-app toggles and configurable Dolphin opacity/blur. Needs one companion script — see its README. |

---

## Quick Install

Every package installs the same way — swap the URL for the one you want:

```bash
ambxst mods install https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/<package-name>
ambxst mods enable positive.<package-id>
ambxst reload
```

Or via the GUI: **Ambxst Settings → Mods → Package source**, paste the package URL, click **Install**, then enable it in the list.

Packages with dependencies (`special-workspaces`, `workspace-app-indicator`) will ask Ambxst to also install those — see each package's own README for the exact chain and any extra manual steps (Hyprland config snippets, companion scripts) they need.

---

## Repository Structure

Following the official Ambxst declarative mod manager specification:

```text
ambxst-mods/
├── README.md
├── LICENSE
└── packages/
    ├── wallpaper-transitions/
    ├── dock-enhancements/
    ├── special-workspaces/
    ├── workspace-app-indicator/
    └── theme-sync/
        ├── ambxst.mod.json
        ├── README.md
        ├── LICENSE
        ├── payload/            (QML source patched/overlaid into Ambxst)
        ├── patches/
        └── scripts/            (companion pieces outside Ambxst's mod system, if any)
```

---

## License

All packages in this repository are licensed under the [MIT License](LICENSE) unless explicitly specified otherwise within a package directory.
