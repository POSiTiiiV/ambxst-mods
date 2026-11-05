# Kpopping Online Wallpapers for Ambxst

Online wallpapers in Ambxst's Wallpapers tab:

- **kpopping.com photos:** search an idol or group, filter by orientation and resolution, try a photo on your real desktop, and keep the ones you like. Kept photos go into your wallpaper library like any other wallpaper.
- **YouTube videos as a live wallpaper:** search or paste a link, build your own playlist, loop, shuffle or autoplay related videos. See [YouTube wallpapers](#youtube-wallpapers).

Requires [`drpezzer.ambxst-skwd-wall`](https://github.com/drpezzer/ambxst-mods/tree/main/packages/ambxst-skwd-wall). This mod's patch is written on top of skwd-wall's changes to the Wallpapers tab.

## Install

```bash
ambxst mods install https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/ambxst-kpopping
ambxst mods enable positive.ambxst-kpopping
ambxst reload
```

Needs `python3` (standard library only), `curl` and `sh`. Nothing to configure, and no login. YouTube mode also needs `mpv`, `yt-dlp` and [`mpvpaper`](https://github.com/GhostNaN/mpvpaper). Without them, only that mode fails to play.

## Using it

| | |
|---|---|
| **Globe button** (end of the top row) | Switches the grid between your local library and kpopping.com. The **▶** next to it does the same for YouTube. |
| **Search box** | Finds an idol or group: `Karina`, `aespa`, `Chaewon`, `ITZY`, ... The best match is picked (a group with exactly that name, else the most popular idol whose name contains it). The last search, its results and the filters stay until the shell restarts. |
| **Chips under the box** | **Empty box:** your recent searches, one click to search again. **Several matches** (nine idols are called Chaewon): one chip per match, like `Kim Chaewon · IZ*ONE` / `ChaeWon · tripleS`. Click one to switch. **Order:** Hot (default) / Newest / Most liked (all time). These are the only orders kpopping's API has; it has no view counts. **Filters:** Landscape / Portrait / Square, SD / HD / FHD / 2K / 4K / 8K, and for idols **+ Tagged**. |
| **Scrolling** | The next 30 posts load as you reach the bottom, so you can go through every post an idol has (Karina has ~1,200). A strict filter loads a few more pages on its own. |
| **Click / Enter** | **Preview**: the dashboard closes, you're moved to an empty workspace and the photo becomes your wallpaper (colours and transition included). The notch shows `Preview · 2592×1944` with **✓** (save it) and **✗** (back to your wallpaper, your workspace and the picker). Ctrl+R in the picker also drops it. |
| **Shift+click / Shift+Enter** | Saves and sets the photo straight away. |
| **Label** under the highlighted photo | `width×height · 26 likes · title`, so low-resolution shots are easy to spot. |

**+ Tagged:** kpopping lists a post under every idol tagged in it. Ryujin's feed includes "Yuna Instagram Update with Ryujin & Lia", for example. By default, an idol search only shows posts where that idol is the main one. Turn on **+ Tagged** to include the rest. Those photos are saved under their main idol (`ITZY/Yuna/`).

## YouTube wallpapers

Press **▶** at the end of the top row, then search, or paste a YouTube video or playlist link.

| | |
|---|---|
| **Click / Enter** | Plays the video as your wallpaper and closes the dashboard. What comes after it is described below. |
| **Shift+click / Shift+Enter** | Adds the video to **My playlist** (kept for good), or removes it there. |
| **Ctrl+click / Ctrl+P** | Adds the video to **Up next**: it plays after the current video, ahead of everything else. With nothing playing, it plays now. |
| **⏵ Resume: …** chip | After **stop** (or choosing another wallpaper): continues the same video, a couple of seconds before where it stopped, with the same list and Up next. Survives `ambxst reload`; a new session (log out / reboot) forgets it. |
| **▶ Play My playlist** chip | Plays your playlist, and only it, from the top (Shuffle: from a random video). |
| **My playlist (N)** chip | Shows your playlist in the grid. Click a video to play the playlist from there. Typing a search goes back to results. Saved in `~/.config/ambxst/kpopping-youtube.json`. |
| **Up next (N + M autoplay)** chip | Your queue first, then (dimmed) the next videos the list will play: Autoplay's Mix or the playlist. With Shuffle, only the next pick; with Loop video, none. Reorder the whole thing by **dragging a card** to its new place (any YouTube layout; hold it near the top or bottom edge to scroll), with **◀ ▶** on the selected card (**▲ ▼** in list view), or Ctrl+↑ / Ctrl+↓; remove with **✕**. Queued videos always stay ahead of the autoplay ones; moving the first autoplay video up queues it. With Shuffle, autoplay videos can only be removed. **Click:** a queued video plays now; an autoplay video jumps there (the list carries on after it). Ctrl+click an autoplay video to queue it, Shift+click for My playlist. |
| **Loop video** | Repeats the current video instead of moving on. Also applies to the video that's playing. |
| **Shuffle** | Shuffles the playlist. Also applies to the one that's playing. |
| **Autoplay** (on by default) | After a search result, keeps going with YouTube's Mix of related videos, like YouTube's own autoplay. Off: that one video loops. |
| **Notch** | While a video plays: its title (scrolling when it's long), over the video's thumbnail, blurred, the same backdrop Ambxst's media player uses for album art. **Hover** the notch for **⏮ previous**, **⏪ −5 s**, **⏯ pause/play**, **⏩ +5 s**, **⏭ next**, **mute/unmute** and **stop**: they take the title's place, or sit beside it, with the notch sized to fit, when *expand notch on hover* is on. Mute and volume are the same setting as skwd-wall's video wallpapers (Wallpaper settings), both ways. |
| **Media keys / media widgets** | The wallpaper is an MPRIS player called *YouTube wallpaper* (needs PyGObject): play/pause, next, previous, seek and stop work from your keyboard's media keys, `playerctl`, and Ambxst's media controls, with title, channel and thumbnail. |

- **Quality** (Settings → Mods → Kpopping): *Auto* (default) fetches at most your screen's resolution. *Best available*, or a cap at 2160p / 1440p / 1080p / 720p. At that size VP9, then H.264, are preferred over AV1, because most GPUs decode them in hardware. Motion is smoothed for 60 fps video on high-refresh screens.
- **Pause YouTube wallpaper when covered** (off by default): pause while a fullscreen window covers the screen, and in game mode. This is the same rule skwd-wall uses for video wallpapers.
**Seek keys:** mods can't add Hyprland keybinds, so bind these yourself (in Lua config, e.g. `custom_binds.lua`):

```lua
hl.bind("SUPER + CTRL + Left",  hl.dsp.exec_cmd("playerctl -p ambxst_kpopping position 5-"), { repeating = true })
hl.bind("SUPER + CTRL + Right", hl.dsp.exec_cmd("playerctl -p ambxst_kpopping position 5+"), { repeating = true })
```

`-p ambxst_kpopping` targets the wallpaper, even while Spotify or a browser is the "active" player.

**What plays after the current video (and on next ⏭):**

1. **Up next** comes first.
2. Then **Loop video** replays the current one.
3. Otherwise the list goes on:
   - **My playlist** (▶ Play My playlist, or a click in its view): the next video in it.
   - **A pasted playlist link:** its next video.
   - **A search result:** with **Autoplay** on, YouTube's Mix of related videos (like YouTube's own autoplay). It keeps going: near the end of the list, more recommendations for the video playing then are added (no repeats). Off, it repeats.

Lists loop when they reach the end.
- Videos are downloaded with yt-dlp into **`~/.cache/ambxst/kpopping/yt/`** and played from there by mpvpaper, on the layer just above skwd-wall. YouTube refuses mpv's own stream fetches (HTTP 403). A new video takes ~5–15 s to start (the notch says *Loading…*). While one plays, the next ones (Up next, then the list, including Autoplay's Mix) download ahead, and recently played ones stay cached, so skipping, going back, resuming and seeking are instant and exact.
- **YouTube cache size** (Settings → Mods → Kpopping): 2 GB by default (1 / 5 / 10 GB). The least recently played videos are deleted first; the playing and upcoming ones never are.
- The player runs on its own, so `ambxst reload` doesn't stop it.
- **Stop** in the notch (or a media-key stop, or choosing any other wallpaper) *hides* the video and remembers where it was. Use **⏵ Resume** to pick it back up. That and Up next live in `$XDG_RUNTIME_DIR`, so they survive `ambxst reload` and a new session starts fresh.
- In per-screen mode it plays on that screen, otherwise on all of them.
- With Ambxst's desktop icons on, the video covers them (they share its layer).
- Colours stay those of your wallpaper underneath.

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
| Thumbnails (~15 KB each, via kpopping's own resizer; full-size originals it hands back for older photos are shrunk with ffmpeg) | until unused for 30 days |
| Full-size previews | 7 days, never while still your wallpaper; saving a previewed photo just copies it |

## Grid layout and card size (Settings → Mods → Kpopping Online Wallpapers)

| Setting | |
|---|---|
| **Picture layout** (your wallpapers, kpopping) | **Classic squares** (Ambxst's own, the default) · **Rows**: equal-height rows, every picture in its own shape · **Masonry**: Pinterest-style columns, every picture in its own shape |
| **YouTube layout** | **Squares** (default) · **Tiles**: 16:9 thumbnails, title / channel / length underneath · **List**: like YouTube's search results, thumbnail left, details right |
| **Wallpaper card size** | **Compact** (Ambxst's 7 a row) · **Comfortable** · **Large**. The YouTube list: 3 / 2 / 1 columns of rows, bigger thumbnails. |
| **YouTube card size** | **Same as pictures** (default), or its own Compact / Comfortable / Large. |

Classic + Squares + Compact is exactly Ambxst's grid. For bigger cards and the collage, the mod makes 480 px thumbnails of your library that keep each picture's shape, once, in the background ("Making thumbnails…"; ~5 min for ~6,000 wallpapers, ~25 KB each, in `~/.cache/ambxst/kpopping/local-thumbs`; with Pillow installed, otherwise ffmpeg, which is slower). Arrow keys: in Rows, ↑/↓ go to the nearest card in the next row; in Masonry, ↑/↓ stay in the column and ←/→ go to the card at the same height next door.

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
- `patches/kpopping-tab.patch` adds the globe / ▶ buttons, chips, infinite scroll and download spinners (`WallpapersTab.qml`, `FilterBar.qml`), the ✓/✗ preview strip and YouTube controls in the notch (`DefaultView.qml`), and the fit step before skwd-wall's applies (`SkwdWall.qml`).
- YouTube: `kpopping_bridge.py yt` lists videos with `yt-dlp --flat-playlist` (search words go after `--`, so they can't become options). Playback: `setsid mpvpaper -l bottom` reads the named pipe `$XDG_RUNTIME_DIR/ambxst-kpopping-stream`, and `kpopping_bridge.py yt-player` feeds it one video at a time with `yt-dlp -o -` (Next = SIGUSR1). Both are controlled and followed through mpv's IPC socket `$XDG_RUNTIME_DIR/ambxst-kpopping-mpv.sock` (`kpopping_bridge.py mpv` / `mpv-watch`).

## License

MIT. Photos belong to their owners and uploaders on kpopping.com; videos to theirs on YouTube.
