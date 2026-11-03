# Kpopping Online Wallpapers for Ambxst

Browse [kpopping.com](https://kpopping.com) from Ambxst's Wallpapers tab. Search an idol or group, filter by orientation and resolution, try a photo on your real desktop, and keep the ones you like. Kept photos go into your wallpaper library like any other wallpaper.

Requires [`drpezzer.ambxst-skwd-wall`](https://github.com/drpezzer/ambxst-mods/tree/main/packages/ambxst-skwd-wall). This mod's patch is written on top of skwd-wall's changes to the Wallpapers tab.

## Install

```bash
ambxst mods install https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/ambxst-kpopping
ambxst mods enable positive.ambxst-kpopping
ambxst reload
```

Needs `python3` (standard library only), `curl` and `sh`. Nothing to configure, and no login.

## Using it

| | |
|---|---|
| **Globe button** (end of the top row) | Switches the grid between your local library and kpopping.com. |
| **Search box** | In kpopping mode, finds an idol or group: `Karina`, `aespa`, `Wonyoung`, `ITZY`, ... The last search, its results and the filters stay until the shell restarts. |
| **Filter chips** (under the search box) | **Landscape / Portrait / Square** and **SD / HD / FHD / 2K / 4K / 8K**. Chips in a group are OR'd, the two groups AND'd, none = any. Default: Landscape. |
| **Label** under the highlighted photo | `width×height · title`, so low-resolution shots are easy to spot. |
| **Expand button** on the selected photo, or **Shift+Enter** | **Preview on desktop**: sets the photo as your wallpaper (colours and transition included) without adding it to your library. A bar in the tab then offers **✓ Save** and **✕ Discard** (Ctrl+R), which returns to the wallpaper you had. |
| **Click / Enter** | Saves the photo into your library and sets it. |

Each post's whole album is checked, so landscape shots behind a portrait cover still show up. A first search reads every album and shows its progress (`12/30 albums`). After that, the search comes from the cache.

## Where photos go

Inside your Ambxst wallpaper folder:

```
kpopping/<Group>/<Idol>/<Idol>_<photo date>_<id>.jpg     e.g. kpopping/aespa/Karina/Karina_2026-10-26_8g362k-6.jpg
kpopping/<Group>/mix/<Group>_<photo date>_<id>.jpg       group shots
kpopping/<Soloist>/<Soloist>_<photo date>_<id>.jpg
```

Because they're in your wallpaper folder, they appear in the local grid as well, and the `kpopping` folder becomes a subfolder filter there.

## Resolution chips

They go by the photo's **longer edge**, so they work for portrait shots too:

| Chip | Longer edge |
|---|---|
| SD | < 1280 px |
| HD | ≥ 1280 |
| FHD | ≥ 1920 |
| 2K | ≥ 2560 |
| 4K | ≥ 3840 |
| 8K | ≥ 7680 |

## Caching (`~/.cache/ambxst/kpopping`)

kpopping's API takes 0.5–3 s per request, and a search needs about 30 of them. The cache keeps that to the first time:

| What | Kept |
|---|---|
| Search results | 6 hours; changing filters reuses them |
| Album sizes | per post, until the album gets new photos |
| Thumbnails (~15 KB each, via kpopping's own resizer) | until unused for 30 days |
| Full-size previews | 7 days, never while still your wallpaper; saving a previewed photo just copies it |

## Also in this mod: faster picker opening

Stock Ambxst unloads every thumbnail in the Wallpapers grid when the dashboard closes and decodes them all again on the next open. This mod keeps the ones in view loaded (about 10 MB), so reopening is instant. Turn on **Settings → Performance → Persist dashboard tabs** (`dashboardPersistTabs`) too, so the tab itself isn't rebuilt on every open.

## How it works

- `payload/scripts/kpopping_bridge.py` uses kpopping's public JSON API (`/api/search/entities`, `/api/photos`, `/api/kpics/<id>`) with a plain, honest user agent. It sends no cookies and doesn't log in. It prints one JSON line per event (progress, results, each thumbnail) so the grid fills in as things arrive. You can also run it yourself:
  `python3 kpopping_bridge.py search Karina --orient landscape --res 4k,8k`
- `payload/modules/services/KpoppingService.qml` runs the bridge, keeps state across dashboard opens, and downloads full-size photos with `curl`. It saves and applies them through Ambxst's normal `setWallpaper`, so matugen colours and skwd-wall transitions work as usual.
- `patches/kpopping-tab.patch` adds the globe button, chips, preview bar and download spinners to `WallpapersTab.qml` and `FilterBar.qml`.

## License

MIT. Photos belong to their owners and uploaders on kpopping.com.
