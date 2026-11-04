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
| **Search box** | Finds an idol or group: `Karina`, `aespa`, `Chaewon`, `ITZY`, ... The best match is picked (a group with exactly that name, else the most popular idol whose name contains it). The last search, its results and the filters stay until the shell restarts. |
| **Chips under the box** | **Empty box:** your recent searches, one click to search again. **Several matches** (nine idols are called Chaewon): one chip per match, like `Kim Chaewon · IZ*ONE` / `ChaeWon · tripleS`. Click one to switch. **Order:** Hot (default) / Newest / Most liked (all time). These are the only orders kpopping's API has; it has no view counts. **Filters:** Landscape / Portrait / Square, SD / HD / FHD / 2K / 4K / 8K, and for idols **+ Tagged**. |
| **Scrolling** | The next 30 posts load as you reach the bottom, so you can go through every post an idol has (Karina has ~1,200). A strict filter loads a few more pages on its own. |
| **Click / Enter** | **Preview**: the dashboard closes, you're moved to an empty workspace and the photo becomes your wallpaper (colours and transition included). The notch shows `Preview · 2592×1944` with **✓** (save it) and **✗** (back to your wallpaper, your workspace and the picker). Ctrl+R in the picker also drops it. |
| **Shift+click / Shift+Enter** | Saves and sets the photo straight away. |
| **Label** under the highlighted photo | `width×height · 26 likes · title`, so low-resolution shots are easy to spot. |

**+ Tagged:** kpopping lists a post under every idol tagged in it. Ryujin's feed includes "Yuna Instagram Update with Ryujin & Lia", for example. By default, an idol search only shows posts where that idol is the main one. Turn on **+ Tagged** to include the rest. Those photos are saved under their main idol (`ITZY/Yuna/`).

## Where photos go

Inside your Ambxst wallpaper folder:

```
kpopping/<Group>/<Idol>/<Idol>_<photo date>_<id>.jpg     e.g. kpopping/aespa/Karina/Karina_2026-10-26_8g362k-6.jpg
kpopping/<Group>/mix/<Group>_<photo date>_<id>.jpg       group shots
kpopping/<Soloist>/<Soloist>_<photo date>_<id>.jpg
```

The group is the one kpopping lists for the idol, which is sometimes a former group. Kim Chaewon is listed under IZ*ONE, so she saves to `IZ*ONE/Kim Chaewon/`.

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
| Name lookups and pages of posts | 6 hours; changing filters reuses them |
| Idols' groups, recent searches | kept |
| Album sizes | per post, until the album gets new photos |
| Thumbnails (~15 KB each, via kpopping's own resizer) | until unused for 30 days |
| Full-size previews | 7 days, never while still your wallpaper; saving a previewed photo just copies it |

## Wallpaper fit (Settings → Mods → Kpopping Online Wallpapers)

skwd-wall crops every wallpaper to fill the screen, so portrait photos get zoomed in. This mod sets skwd-wall's fill mode before **every** wallpaper change, local ones too:

| Wallpaper fit | |
|---|---|
| **Auto** (default) | Landscape images fill the screen. Portrait and square ones are shown whole. |
| Fill / Fit / Stretch / Center / Tile | The same for every wallpaper. |
| Leave it to skwd-wall | This mod doesn't touch the fill mode. |

**Around a fitted image:** a blurred copy of the image (default) or skwd-wall's solid fill colour. Changing either setting re-applies the current wallpaper right away. The image size comes from the file header (PNG, JPEG, WebP, GIF). Videos always fill.

## Also in this mod: faster picker opening

Stock Ambxst unloads every thumbnail in the Wallpapers grid when the dashboard closes and decodes them all again on the next open. This mod keeps the ones in view loaded (about 10 MB), so reopening is instant. Turn on **Settings → Performance → Persist dashboard tabs** (`dashboardPersistTabs`) too, so the tab itself isn't rebuilt on every open.

## How it works

- `payload/scripts/kpopping_bridge.py` uses kpopping's public JSON API (`/api/search/entities`, `/api/photos`, `/api/kpics/<id>`) with a plain, honest user agent. It sends no cookies and doesn't log in. It prints one JSON line per event (progress, results, each thumbnail) so the grid fills in as things arrive. You can also run it yourself:
  `python3 kpopping_bridge.py search Karina --orient landscape --res 4k,8k --pages 2`
- `payload/modules/services/KpoppingService.qml` runs the bridge, keeps state across dashboard opens, and downloads full-size photos with `curl`. It saves and applies them through Ambxst's normal `setWallpaper`, so matugen colours and skwd-wall transitions work as usual.
- `patches/kpopping-tab.patch` adds the globe button, chips, infinite scroll and download spinners (`WallpapersTab.qml`, `FilterBar.qml`), the ✓/✗ preview strip in the notch (`DefaultView.qml`), and the fit step before skwd-wall's applies (`SkwdWall.qml`).

## License

MIT. Photos belong to their owners and uploaders on kpopping.com.
