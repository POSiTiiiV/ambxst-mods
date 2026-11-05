#!/usr/bin/env python3
"""kpopping.com search for the Ambxst wallpaper tab, plus skwd-wall fit modes.

usage:
  kpopping_bridge.py search <query> [--orient landscape,portrait,square] [--res sd,hd,fhd,2k,4k,8k]
                                    [--pages N] [--entity idol:<id>|group:<id>] [--tagged] [--sort hot|new|top]
  kpopping_bridge.py fit <image> <auto|fill|fit|stretch|center|tile> <blur|color>
  kpopping_bridge.py yt <search words | youtube video/playlist link> [--pages N]
  kpopping_bridge.py mpv <json command array>        e.g. mpv '["cycle","mute"]'
  kpopping_bridge.py mpv-watch                       stream the player's title/mute/pause as JSON lines
  kpopping_bridge.py yt-player <queue.json>          play a YouTube queue as the wallpaper (see below)
  kpopping_bridge.py local-thumbs <paths.txt>        shape-keeping thumbnails + sizes for local wallpapers

search: --orient / --res chips are OR'd within a group, the groups AND'd; empty = any.
  Resolution buckets go by the longer edge: hd >= 1280, fhd >= 1920, 2k >= 2560, 4k >= 3840, 8k >= 7680.
  --pages N loads the first N pages of 30 posts. For an idol, only posts where they are the main
  idol are kept unless --tagged. --entity picks one of the "candidates" of an ambiguous name.
  --sort is kpopping's own order (the only three its API has): hot (default), new, top (most liked ever).
  stdout, one JSON object per line:
    0. {"progress": done, "total": n, "query": ...} while uncached albums load
    1. {"status": "ok", "entity": {...}, "candidates": [...], "photos": [...], "more": bool,
        "query": ..., "key": ..., "pages": N}   (or {"status": "error", "message": ...});
       a photo's "thumb" is set when already cached
    2. then {"thumb": <src>, "url": <file:// or remote>} as missing thumbnails finish

yt: lists videos through yt-dlp (search: 30 per page; a link: every video in it), same result line
  as search ("photos" with src = watch URL, thumb = i.ytimg.com URL), "list": true for a link.
  mpv / mpv-watch talk to the YouTube wallpaper player's IPC socket ($XDG_RUNTIME_DIR/ambxst-kpopping-mpv.sock).

yt-player: plays a queue as the wallpaper. YouTube refuses mpv's own stream fetches (403 since late
  2026), so yt-dlp downloads each video into ~/.cache/ambxst/kpopping/yt/<id>.<format key>.mkv (an LRU
  cache, "cache_gb"), and the feeder starts mpvpaper on the first one, then loadfile's the next. While a
  video plays, the next ones (Up next, then the list) download ahead. Cached videos start instantly and
  seek exactly. queue.json: {"format", "queue": [{"url", "title", "channel"}], "start", "mix": bool,
  "options": <json with loop/shuffle>, "upnext": <json list>, "state": <file>, "mpv_opts", "output",
  "cache_gb", "first_item", "from_list", "seek"}. Up next plays first, ahead of Loop; then the list.
  "coming": the feeder keeps this file listing what the list plays next (Autoplay's Mix / playlist),
  for the shell's Up next view. "jump": {"i": n} there + SIGUSR1 = continue the list at index n.
  "topup": keep an Autoplay list going like YouTube: with fewer than 5 unplayed videos ahead, fetch the
  Mix of the video playing now and append what hasn't been in the list or played yet.
  "commands": JSON lines the shell appends to edit the list: {"move": n, "delta": ±1} swaps list entry n
  with its neighbour in play order, {"remove": n} drops it. Applied within half a second.
  SIGUSR1 = next, SIGUSR2 = previous, SIGHUP = hide (save {queue, i, from_list, item, output, seek,
  hidden} to "state", quit the player, exit). With PyGObject it is also the MPRIS player "YouTube
  wallpaper": play/pause, next, previous, seek, stop, title and thumbnail.

local-thumbs: for each path (one per line), a 480 px (long edge) JPEG that keeps the image's shape, in
  ~/.cache/ambxst/kpopping/local-thumbs/ (Ambxst's own are 140 px squares: too small for big cards and
  useless for a collage), made once with Pillow if installed (else ffmpeg; videos: ffmpeg, a frame at
  1 s), up to 8 at a time. Prints
  {"path", "w", "h", "thumb"} per file (cached ones first, at once) and {"progress": n, "total": t}.
  Thumbnails of files that are gone are pruned.

fit: writes skwd-wall's display.fillMode / display.backgroundMode before an apply.
  auto = landscape images fill the screen, portrait and square ones are shown whole.

Caches in ~/.cache/ambxst/kpopping: name lookups and post pages (6 h), album sizes (per post,
until the album grows), idols' groups, and thumbnails (384 px, shrunk with ffmpeg when kpopping's
resizer hands back a full-size original; pruned after 30 days unused). The shell
puts full-size previews in full/ (pruned after 7 days unless one is still your wallpaper).
Stdlib only, public API, no cookies.
"""
import errno
import fcntl
import hashlib
import json
import os
import random
import re
import signal
import socket
import struct
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

API = "https://kpopping.com/api"
UA = "ambxst-kpopping/1.0 (+https://github.com/POSiTiiiV/ambxst-mods)"
MIN_RATIO = 1.2
PAGE = 30
RES_BUCKETS = [("sd", 0), ("hd", 1280), ("fhd", 1920), ("2k", 2560), ("4k", 3840), ("8k", 7680)]
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "ambxst" / "kpopping"
TTL = 6 * 3600
WALL_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".tif", ".tiff", ".gif"}  # what Ambxst's scan picks up
SKWD_CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "skwd-wall-v2" / "config.json"


def fetch(endpoint, **params):
    endpoint += ("?" + urllib.parse.urlencode(params)) if params else ""
    req = urllib.request.Request(endpoint, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.read()


def get(path, **params):
    return json.loads(fetch(f"{API}/{path}", **params))


def load(path, default):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return default


def save(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(json.dumps(obj))
    tmp.replace(path)  # atomic: a killed search never leaves half a file


def cached(path, compute, ttl=TTL):
    hit = load(path, None)
    if hit and time.time() - hit["time"] < ttl:
        return hit["value"]
    value = compute()
    save(path, {"time": time.time(), "value": value})
    return value


def emit(obj):
    print(json.dumps(obj), flush=True)


def in_use():
    """Files Ambxst currently shows (a desktop preview left as the wallpaper must survive the prune)."""
    conf = load(Path.home() / ".cache" / "ambxst" / "wallpapers.json", {})
    return {conf.get("currentWall")} | set((conf.get("perScreenWallpapers") or {}).values())


def prune(folder, days, keep=()):
    cutoff = time.time() - days * 86400
    for f in folder.glob("*") if folder.is_dir() else []:
        try:
            if str(f) not in keep and f.stat().st_mtime < cutoff:
                f.unlink()
        except OSError:
            pass


# ── names ────────────────────────────────────────────────────────────────

def candidates(query):
    """Idols and groups matching the query, best first: a group with exactly that name, then names
    containing the query, most popular first (kpopping's bias count), then alias hits. Upstream
    ranks alias hits first ("Wonyoung" -> "Ever") and lists nine idols called Chaewon with
    LE SSERAFIM's (listed as "Kim Chaewon") last."""
    def compute():
        found = get("search/entities", q=query)
        pool = found.get("idols", []) + found.get("groups", [])
        q = query.strip().lower()
        tier = lambda e: (0 if e["type"] == "group" and e["name"].lower() == q
                          else 1 if q in e["name"].lower() or q in e.get("slug", "").lower() else 2)
        top = min((tier(e) for e in pool), default=None)
        tied = [e for e in pool if e["type"] == "idol" and tier(e) == top]
        bias = {}
        if len(tied) > 1:  # only ask for popularity when the name alone can't decide
            def count(e):
                try:
                    return e["id"], get(f"idols/{e['slug']}").get("biasCount") or 0
                except Exception:
                    return e["id"], 0
            with ThreadPoolExecutor(max_workers=8) as ex:
                bias = dict(ex.map(count, tied))
        pool.sort(key=lambda e: (tier(e), -bias.get(e["id"], 0)))
        return [{"key": f"{e['type']}:{e['id']}", "id": e["id"], "type": e["type"], "name": e["name"],
                 "group": e.get("groupName")} for e in pool]
    return cached(CACHE / "names" / (hashlib.sha1(query.strip().lower().encode()).hexdigest() + ".json"), compute)


def idol_group(idol_id, name):
    """The group kpopping lists for an idol (posts carry it rarely), cached for good."""
    groups_file = CACHE / "idol-groups.json"
    groups = load(groups_file, {})
    if idol_id not in groups:
        try:
            match = [e for e in get("search/entities", q=name).get("idols", []) if e["id"] == idol_id]
            groups[idol_id] = (match[0].get("groupName") or "") if match else ""
            save(groups_file, groups)
        except Exception:
            return ""
    return groups[idol_id]


def clean(part):
    # names come from the network: one path segment each, but keep "IZ*ONE" / "(G)I-DLE" as written
    part = "".join(c for c in part if c != "/" and c.isprintable()).strip().lstrip(".")
    return part or "misc"


def save_path(post, entity, src, group_of=lambda idol_id, name: ""):
    """<Group>/<Idol>/<Idol>_<date>_<id>.jpg, shots with several idols in <Group>/mix, soloists in <Idol>/.

    The idol is the post's main idol (posts tagging the searched idol can be someone else's,
    e.g. "Yuna Instagram Update with Ryujin & Lia" in Ryujin's feed). Its group comes from the
    post, else from the searched entity, else from kpopping's idol lookup."""
    names = [n.strip() for n in (post.get("idolName") or "").split(",") if n.strip()]
    main = names[0] if names else None
    if entity["type"] == "group":
        group = post.get("groupName") or entity["name"]
        idol = main if len(names) == 1 else None
    elif post.get("idolId") in (None, entity["id"]) or main == entity["name"]:
        group = post.get("groupName") or entity.get("groupName")
        idol = entity["name"]
    else:
        idol = main
        group = post.get("groupName") or (group_of(post["idolId"], main) if main else "") or None
    dirs = [group, idol] if group and idol else [group, "mix"] if group else [idol or entity["name"]]
    stem, ext = os.path.splitext(src.rsplit("/", 1)[-1])  # "1791601951723-8g362k-6", ".jpg"
    ext = ext.lower() if ext.lower() in WALL_EXTS else ".jpg"
    uid = stem.split("-", 1)[-1]  # drop the upload timestamp, keep the unique part
    name = f"{idol or group or entity['name']}_{post.get('photoDate') or 'undated'}_{uid}{ext}"
    return "/".join(clean(p) for p in dirs + [name])


# ── photos ───────────────────────────────────────────────────────────────

def orientation(w, h):
    return "landscape" if w / h >= MIN_RATIO else "portrait" if h / w >= MIN_RATIO else "square"


def resolution(w, h):
    return [name for name, edge in RES_BUCKETS if max(w, h) >= edge][-1]


def page_posts(entity, page, sort):
    key = "idolId" if entity["type"] == "idol" else "groupId"
    return cached(CACHE / "pages" / f"{entity['type']}-{entity['id']}-{sort}-{page}.json",
                  lambda: get("photos", **{key: entity["id"], "limit": PAGE, "offset": page * PAGE, "sort": sort}))


def search(query, pages, entity_key, tagged, sort="hot"):
    """Every album image of the entity's first `pages` pages of posts, any orientation (filtered later)."""
    cands = candidates(query)
    if not cands:
        return {"status": "error", "message": f"No idol or group found for '{query}'"}
    entity = next((c for c in cands if c["key"] == entity_key), cands[0])
    entity = {**entity, "groupName": entity["group"]}

    posts, more = [], False
    for page in range(pages):
        batch = page_posts(entity, page, sort)
        posts += batch
        more = len(batch) == PAGE
        if not more:
            break
    if entity["type"] == "idol" and not tagged:
        posts = [p for p in posts if p.get("idolId") in (None, entity["id"])]

    albums_file = CACHE / "albums.json"
    albums = load(albums_file, {})

    def album(post):
        hit = albums.get(post["id"])
        if hit and hit[0] == post.get("albumCount"):
            return post, hit[1]
        try:
            images = [{k: i.get(k) for k in ("src", "width", "height")}
                      for i in get(f"kpics/{post['id']}").get("albumImages") or []]
        except Exception:
            return post, []  # one broken album shouldn't sink the search
        albums[post["id"]] = [post.get("albumCount"), images]
        return post, images

    photos, seen = [], set()
    todo = sum(1 for p in posts if (albums.get(p["id"]) or [None])[0] != p.get("albumCount"))
    with ThreadPoolExecutor(max_workers=8) as pool:
        for done, (post, images) in enumerate(pool.map(album, posts), 1):
            if todo:
                emit({"progress": done, "total": len(posts), "query": query})
            for img in images:
                w, h, src = img.get("width") or 0, img.get("height") or 0, img.get("src")
                if src and w and h and src not in seen:
                    seen.add(src)
                    photos.append({"src": src, "title": post.get("title", ""), "width": w, "height": h,
                                   "likes": post.get("likes") or 0,
                                   "save": save_path(post, entity, src, idol_group)})
    save(albums_file, albums)

    label = lambda c: c["name"] + (" · " + c["group"] if c.get("group") else "")
    return {"status": "ok", "photos": photos, "more": more,
            "entity": {"key": entity["key"], "name": entity["name"], "group": entity["group"], "type": entity["type"]},
            "candidates": [{"key": c["key"], "label": label(c)} for c in cands] if len(cands) > 1 else []}


def thumb_file(src):
    return CACHE / "thumbs" / src.rsplit("/", 1)[-1]


THUMB_MAX = 200_000  # resized thumbnails are ~15 KB


def fetch_thumb(src):
    f = thumb_file(src)
    try:
        data = fetch("https://kpopping.com/_next/image", url=src, w=384, q=75)
        f.parent.mkdir(parents=True, exist_ok=True)
        tmp = f.with_name(f.name + ".part")
        tmp.write_bytes(data)
        # older photos (kpopping.com/documents/...) get redirected to the full-size original,
        # up to several MB: shrink those, never cache them as they are
        if len(data) > THUMB_MAX:
            small = f.with_name(f.name + ".small.jpg")
            run = subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(tmp), "-vf", "scale=384:-2", "-q:v", "5", str(small)],
                                 capture_output=True, timeout=30)
            tmp.unlink(missing_ok=True)
            if run.returncode != 0 or not small.exists() or small.stat().st_size > THUMB_MAX:
                small.unlink(missing_ok=True)
                return src, src
            tmp = small
        tmp.replace(f)
        return src, f.as_uri()
    except Exception:
        return src, src  # resizer failed: let the shell load the full image instead


# ── fit ──────────────────────────────────────────────────────────────────

def image_size(path):
    """(width, height) from the file header for PNG, GIF, WebP and JPEG; None otherwise (videos, ...)."""
    try:
        with open(path, "rb") as f:
            head = f.read(32)
            if head.startswith(b"\x89PNG\r\n\x1a\n"):
                return struct.unpack(">II", head[16:24])
            if head[:6] in (b"GIF87a", b"GIF89a"):
                return struct.unpack("<HH", head[6:10])
            if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
                kind = head[12:16]
                if kind == b"VP8X":
                    return int.from_bytes(head[24:27], "little") + 1, int.from_bytes(head[27:30], "little") + 1
                if kind == b"VP8L":
                    bits = int.from_bytes(head[21:25], "little")
                    return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
                if kind == b"VP8 ":
                    w, h = struct.unpack("<HH", head[26:30])
                    return w & 0x3FFF, h & 0x3FFF
            if head[:2] == b"\xff\xd8":
                f.seek(2)
                while True:
                    byte = f.read(1)
                    while byte and byte != b"\xff":
                        byte = f.read(1)
                    while byte == b"\xff":
                        byte = f.read(1)
                    if not byte:
                        return None
                    marker = byte[0]
                    if marker in (0xD8, 0x01) or 0xD0 <= marker <= 0xD7:
                        continue  # markers without a length
                    length = struct.unpack(">H", f.read(2))[0]
                    if 0xC0 <= marker <= 0xCF and marker not in (0xC4, 0xC8, 0xCC):  # start of frame
                        h, w = struct.unpack(">xHH", f.read(5))
                        return w, h
                    f.seek(length - 2, 1)
    except (OSError, struct.error):
        return None
    return None


def fit(image, mode, background):
    if mode == "auto":
        size = image_size(image)
        mode = "fit" if size and all(size) and orientation(*size) != "landscape" else "fill"
    cfg = load(SKWD_CONFIG, None)
    if cfg is None:
        return 0  # skwd-wall not set up yet (or a config it can't read either): leave it alone
    display = cfg.setdefault("display", {})
    if display.get("fillMode") == mode and display.get("backgroundMode") == background:
        return 0
    display["fillMode"], display["backgroundMode"] = mode, background
    tmp = SKWD_CONFIG.with_name(SKWD_CONFIG.name + ".kpopping.tmp")
    tmp.write_text(json.dumps(cfg, indent=2) + "\n")
    tmp.replace(SKWD_CONFIG)
    return 0


# ── youtube ──────────────────────────────────────────────────────────────

MPV_SOCKET = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp") / "ambxst-kpopping-mpv.sock"
YT_LINK = re.compile(r"^https?://((www|m|music)\.)?(youtube\.com|youtu\.be)/\S+$")


def yt(query, pages):
    query = query.strip()
    link = bool(YT_LINK.match(query))
    target = query if link else f"ytsearch{PAGE * pages}:{query}"
    # "--" ends options: a search/link can't smuggle yt-dlp flags in
    run = subprocess.run(["yt-dlp", "--flat-playlist", "-J", "--no-warnings", "--", target],
                         capture_output=True, text=True, timeout=90)
    if run.returncode != 0:
        msg = (run.stderr.strip().splitlines() or ["yt-dlp failed"])[-1]
        return {"status": "error", "message": msg.replace("ERROR: ", "")}
    data = json.loads(run.stdout)
    entries = data.get("entries") if data.get("_type") == "playlist" else [data]
    photos = []
    for e in entries or []:
        vid = e.get("id")
        if not vid or len(vid) != 11:  # channels/shorts shelves in search results
            continue
        photos.append({"src": f"https://www.youtube.com/watch?v={vid}", "id": vid, "title": e.get("title") or vid,
                       "channel": e.get("channel") or e.get("uploader") or "", "duration": int(e.get("duration") or 0),
                       "thumb": f"https://i.ytimg.com/vi/{vid}/mqdefault.jpg"})
    return {"status": "ok" if photos else "error", "message": "" if photos else "No videos found",
            "photos": photos, "list": link and len(photos) > 1, "more": not link and len(entries or []) >= PAGE * pages}


def mpv(command):
    with socket.socket(socket.AF_UNIX) as s:
        s.settimeout(3)
        s.connect(str(MPV_SOCKET))
        s.sendall(json.dumps({"command": command}).encode() + b"\n")
        return s.makefile().readline().strip()


def mpv_watch():
    """Follows the player until it quits: one JSON line per change of the watched properties."""
    for _ in range(720):  # the player starts once its first video is downloaded: wait up to 3 min
        try:
            s = socket.socket(socket.AF_UNIX)
            s.connect(str(MPV_SOCKET))
            break
        except OSError:
            s.close()
            time.sleep(0.25)
    else:
        return 1
    with s:
        for i, prop in enumerate(("media-title", "mute", "pause", "user-data/kpopping/count", "user-data/kpopping/loading",
                                  "user-data/kpopping/id"), 1):
            s.sendall(json.dumps({"command": ["observe_property", i, prop]}).encode() + b"\n")
        for line in s.makefile():
            try:
                ev = json.loads(line)
            except ValueError:
                continue
            if ev.get("event") == "property-change":
                emit({"prop": ev.get("name"), "value": ev.get("data")})
    return 0


def _mpv_alive():
    try:
        mpv(["get_property", "pid"])
        return True
    except OSError:
        return False


MPRIS_XML = """<node>
 <interface name="org.mpris.MediaPlayer2">
  <method name="Raise"/><method name="Quit"/>
  <property name="CanQuit" type="b" access="read"/><property name="CanRaise" type="b" access="read"/>
  <property name="HasTrackList" type="b" access="read"/><property name="Identity" type="s" access="read"/>
  <property name="SupportedUriSchemes" type="as" access="read"/><property name="SupportedMimeTypes" type="as" access="read"/>
 </interface>
 <interface name="org.mpris.MediaPlayer2.Player">
  <method name="Next"/><method name="Previous"/><method name="Pause"/><method name="PlayPause"/>
  <method name="Stop"/><method name="Play"/>
  <method name="Seek"><arg direction="in" type="x"/></method>
  <method name="SetPosition"><arg direction="in" type="o"/><arg direction="in" type="x"/></method>
  <method name="OpenUri"><arg direction="in" type="s"/></method>
  <property name="PlaybackStatus" type="s" access="read"/><property name="Metadata" type="a{sv}" access="read"/>
  <property name="Position" type="x" access="read"/><property name="Rate" type="d" access="read"/>
  <property name="MinimumRate" type="d" access="read"/><property name="MaximumRate" type="d" access="read"/>
  <property name="Volume" type="d" access="read"/>
  <property name="CanGoNext" type="b" access="read"/><property name="CanGoPrevious" type="b" access="read"/>
  <property name="CanPlay" type="b" access="read"/><property name="CanPause" type="b" access="read"/>
  <property name="CanSeek" type="b" access="read"/><property name="CanControl" type="b" access="read"/>
  <signal name="Seeked"><arg name="Position" type="x"/></signal>
 </interface>
</node>"""


def _mpris(state):
    """Media keys / Ambxst's media widgets control the wallpaper. Optional: needs PyGObject."""
    try:
        import threading
        import gi
        gi.require_version("Gio", "2.0")
        from gi.repository import Gio, GLib
    except Exception:
        return
    node = Gio.DBusNodeInfo.new_for_xml(MPRIS_XML)
    shown = {"status": None, "meta": None}

    def prop(name):
        status, position, length = "Playing", 0, 0
        try:
            status = "Paused" if json.loads(mpv(["get_property", "pause"])).get("data") else "Playing"
            position = int((json.loads(mpv(["get_property", "time-pos"])).get("data") or 0) * 1e6)
            length = int((json.loads(mpv(["get_property", "duration"])).get("data") or 0) * 1e6)
        except (OSError, ValueError, TypeError):
            pass
        item = state.get("item") or {}
        vid = item.get("url", "").rsplit("v=", 1)[-1][:11]
        meta = {"mpris:trackid": GLib.Variant("o", "/org/ambxst/kpopping/track/" + (re.sub(r"\W", "_", vid) or "none")),
                "xesam:title": GLib.Variant("s", item.get("title", "")),
                "xesam:artist": GLib.Variant("as", [item.get("channel") or "YouTube"])}
        if vid:
            meta["mpris:artUrl"] = GLib.Variant("s", f"https://i.ytimg.com/vi/{vid}/hqdefault.jpg")
        if length:
            meta["mpris:length"] = GLib.Variant("x", length)
        values = {"CanQuit": GLib.Variant("b", False), "CanRaise": GLib.Variant("b", False),
                  "HasTrackList": GLib.Variant("b", False), "Identity": GLib.Variant("s", "YouTube wallpaper"),
                  "SupportedUriSchemes": GLib.Variant("as", []), "SupportedMimeTypes": GLib.Variant("as", []),
                  "PlaybackStatus": GLib.Variant("s", status), "Metadata": GLib.Variant("a{sv}", meta),
                  "Position": GLib.Variant("x", position), "Rate": GLib.Variant("d", 1.0), "MinimumRate": GLib.Variant("d", 1.0),
                  "MaximumRate": GLib.Variant("d", 1.0), "Volume": GLib.Variant("d", 1.0),
                  "CanGoNext": GLib.Variant("b", True), "CanGoPrevious": GLib.Variant("b", True),
                  "CanPlay": GLib.Variant("b", True), "CanPause": GLib.Variant("b", True),
                  "CanSeek": GLib.Variant("b", True), "CanControl": GLib.Variant("b", True)}
        return values.get(name) if name else values

    def call(conn, sender, path, iface, method, params, invocation):
        try:
            if method == "PlayPause":
                mpv(["cycle", "pause"])
            elif method == "Play":
                mpv(["set_property", "pause", False])
            elif method == "Pause":
                mpv(["set_property", "pause", True])
            elif method == "Next":
                os.kill(os.getpid(), signal.SIGUSR1)
            elif method == "Previous":
                os.kill(os.getpid(), signal.SIGUSR2)
            elif method == "Seek":
                mpv(["seek", params.unpack()[0] / 1e6, "relative+exact"])
            elif method == "SetPosition":
                mpv(["seek", params.unpack()[1] / 1e6, "absolute+exact"])
            elif method in ("Stop", "Quit"):
                os.kill(os.getpid(), signal.SIGHUP)  # hide, remembering where it was
        except OSError:
            pass
        invocation.return_value(None)

    def get(conn, sender, path, iface, name):
        return prop(name)

    def bus_acquired(conn, name):
        for iface in node.interfaces:
            conn.register_object("/org/mpris/MediaPlayer2", iface, call, get, None)

        def tick():  # tell listeners about a new video or play/pause
            values = prop(None)
            status, meta = values["PlaybackStatus"].unpack(), values["Metadata"].unpack().get("xesam:title")
            if (status, meta) != (shown["status"], shown["meta"]):
                shown["status"], shown["meta"] = status, meta
                conn.emit_signal(None, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "PropertiesChanged",
                                 GLib.Variant("(sa{sv}as)", ("org.mpris.MediaPlayer2.Player",
                                                             {"PlaybackStatus": values["PlaybackStatus"], "Metadata": values["Metadata"]}, [])))
            return True
        GLib.timeout_add(700, tick)

    Gio.bus_own_name(Gio.BusType.SESSION, "org.mpris.MediaPlayer2.ambxst_kpopping",
                     Gio.BusNameOwnerFlags.REPLACE | Gio.BusNameOwnerFlags.ALLOW_REPLACEMENT, bus_acquired, None, None)
    threading.Thread(target=GLib.MainLoop().run, daemon=True).start()


def _pop_upnext(path):
    """First video of the up-next queue (the shell's Ctrl+click), removed from the file."""
    if not path:
        return None
    items = load(Path(path), [])
    if not items:
        return None
    save(Path(path), items[1:])
    return items[0]


YT_CACHE = CACHE / "yt"


def yt_player(queue_file):
    cfg = json.loads(Path(queue_file).read_text())
    fmt, queue, upnext = cfg["format"], cfg["queue"], cfg.get("upnext")
    fkey = hashlib.sha1(fmt.encode()).hexdigest()[:8]
    cap = int(float(cfg.get("cache_gb") or 2) * 1024 ** 3)
    YT_CACHE.mkdir(parents=True, exist_ok=True)

    import threading
    topup = bool(cfg.get("mix") or cfg.get("topup"))  # an Autoplay list: keeps growing, like YouTube
    played = set()  # video ids played this session (top-ups skip them)
    mixing = {"busy": False, "seeds": set()}

    def expand_mix(mix_url):
        """Append YouTube's Mix for a video (Autoplay), in the background (~5 s): what plays meanwhile
        isn't held up, and new entries are prefetched like any list's once they're known."""
        try:
            out = subprocess.run(["yt-dlp", "--flat-playlist", "-J", "--playlist-end", "50", "--no-warnings", "--", mix_url],
                                 capture_output=True, text=True, timeout=90)
            known = {re.search(r"v=([\w-]{11})", q["url"]).group(1) for q in queue if re.search(r"v=([\w-]{11})", q["url"])} | played
            for e in (json.loads(out.stdout).get("entries") or []):
                if e.get("id") and len(e["id"]) == 11 and e["id"] not in known:
                    known.add(e["id"])
                    queue.append({"url": f"https://www.youtube.com/watch?v={e['id']}", "title": e.get("title") or e["id"],
                                  "channel": e.get("channel") or e.get("uploader") or ""})
        except Exception:
            pass  # the list plays on (and loops) as it is
        finally:
            mixing["busy"] = False

    def start_mix(vid):
        if mixing["busy"] or not vid or vid in mixing["seeds"]:
            return
        mixing["busy"] = True
        mixing["seeds"].add(vid)
        threading.Thread(target=expand_mix, args=(f"https://www.youtube.com/watch?v={vid}&list=RD{vid}",), daemon=True).start()

    if cfg.get("mix") and queue:
        m = re.search(r"v=([\w-]{11})", queue[0]["url"])
        start_mix(m.group(1) if m else None)

    def key(it):
        m = re.search(r"v=([\w-]{11})", it.get("url", ""))
        return (m.group(1) if m else hashlib.sha1(it["url"].encode()).hexdigest()[:11]) + "." + fkey

    def cached(it):
        """The finished file (<id>.<fkey>.<ext>; partial ones have more dots or .part)."""
        for f in YT_CACHE.glob(key(it) + ".*"):
            if f.name.count(".") == 2 and not f.name.endswith((".part", ".ytdl")):
                return f
        return None

    downloads, failed = {}, {}  # key -> Popen; key -> time it failed

    def download(it):
        k = key(it)
        if k in downloads or cached(it) or time.time() - failed.get(k, 0) < 60:
            return
        downloads[k] = subprocess.Popen(["yt-dlp", "-q", "--no-warnings", "--no-playlist", "-f", fmt, "--merge-output-format", "mkv",
                                         "--no-mtime", "-o", str(YT_CACHE / (k + ".%(ext)s")), "--", it["url"]],
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

    def reap():
        for k, proc in list(downloads.items()):
            if proc.poll() is not None:
                del downloads[k]
                if proc.returncode != 0:
                    failed[k] = time.time()

    def stop_download(it):
        proc = downloads.pop(key(it), None)
        if proc:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except OSError:
                pass

    def prune(keep):
        """Keep the cache under the cap: oldest-used first, never what's playing or coming up."""
        files = [f for f in YT_CACHE.iterdir() if f.is_file()]
        total = sum(f.stat().st_size for f in files)
        for f in sorted(files, key=lambda f: f.stat().st_mtime):
            if total <= cap:
                break
            if f.name.split(".")[0] in keep or any(f.name.startswith(k) for k in downloads):
                continue
            total -= f.stat().st_size
            f.unlink(missing_ok=True)

    state = {"skip": False, "back": False, "item": None, "cur": None, "next_i": None, "qlen": len(queue)}
    signal.signal(signal.SIGUSR1, lambda *_: state.update(skip=True))
    signal.signal(signal.SIGUSR2, lambda *_: state.update(back=True, skip=True))
    state_file = Path(cfg["state"]) if cfg.get("state") else None

    def save_state(seek=0.0, hidden=False):
        if state_file and state.get("cur"):
            item_, from_list_, i_ = state["cur"]
            save(state_file, {"queue": queue, "i": i_, "from_list": from_list_, "item": item_, "output": cfg.get("output", ""), "topup": topup,
                              "seek": max(0, int(seek)), "hidden": hidden, "time": time.time()})

    def hide(*_):
        """Stop, remembering the video, its position and the list (Ambxst offers to resume)."""
        pos = 0.0
        try:
            pos = json.loads(mpv(["get_property", "time-pos"])).get("data") or 0.0
        except (OSError, ValueError):
            pass
        save_state(pos - 2, hidden=True)  # a little before, for context
        write_coming([])  # nothing plays now (⏵ Resume brings the list back)
        try:
            mpv(["quit"])
        except OSError:
            pass
        for k in list(downloads):
            try:
                os.killpg(downloads[k].pid, signal.SIGKILL)
            except OSError:
                pass
        os._exit(0)
    signal.signal(signal.SIGHUP, hide)
    _mpris(state)

    def call(command, tries=8):
        for n in range(tries):
            try:
                return mpv(command)
            except OSError:
                if n == tries - 1:
                    raise
                time.sleep(0.25)

    def options():
        return load(Path(cfg["options"]), {})

    def plan_next(i):
        """Index the list continues with (shuffle decides now, so it can be prefetched)."""
        if not queue:
            return None
        if options().get("shuffle") and len(queue) > 1:
            return random.choice([n for n in range(len(queue)) if n != i])
        return (i + 1) % len(queue)

    def upcoming(i, item):
        out = (load(Path(upnext), []) if upnext else [])[:2]
        if options().get("loop"):
            out.append(item)
        if state["next_i"] is not None:
            out.append(queue[state["next_i"]])
            if len(queue) > 2 and not options().get("shuffle"):
                out.append(queue[(state["next_i"] + 1) % len(queue)])
        return out

    coming_file = Path(cfg["coming"]) if cfg.get("coming") else None
    shown_coming = {"list": None}

    def write_coming(entries):
        """What the list plays after the current video, for the shell's Up next view (Loop: nothing,
        Shuffle: only the next pick, which is already decided)."""
        if coming_file and entries != shown_coming["list"]:
            shown_coming["list"] = entries
            save(coming_file, entries)

    def coming():
        nxt = state["next_i"]
        if nxt is None or not queue or options().get("loop"):
            return []
        count = 1 if options().get("shuffle") else min(10, len(queue))
        playing = state["cur"][2] if state["cur"] and state["cur"][1] else None  # the list video playing now
        out, n = [], nxt
        for _ in range(count):
            if n == playing:
                break  # wrapped around to the video that's playing: not "coming up"
            out.append({**queue[n], "i": n})
            n = (n + 1) % len(queue)
            if n == nxt:
                break
        return out

    cmd_file = Path(cfg["commands"]) if cfg.get("commands") else None

    def process_commands(i):
        """Reorder / remove list entries from the shell's Up next view; returns the adjusted index."""
        if not cmd_file or not cmd_file.exists():
            return i
        work = cmd_file.with_name(cmd_file.name + ".work")
        try:
            cmd_file.replace(work)  # take the batch atomically; new commands start a fresh file
            lines = work.read_text().splitlines()
            work.unlink(missing_ok=True)
        except OSError:
            return i
        shuffle = options().get("shuffle")
        playing = i if state["cur"] and state["cur"][1] else None  # list index on screen now
        for line in lines:
            try:
                c = json.loads(line)
            except ValueError:
                continue
            n = c.get("move", c.get("remove"))
            if not isinstance(n, int) or not 0 <= n < len(queue) or n == playing:
                continue
            if "move" in c:
                if shuffle:
                    continue  # no fixed order to edit
                m = (n + (1 if c.get("delta", 0) > 0 else -1)) % len(queue)
                if m != playing:
                    queue[n], queue[m] = queue[m], queue[n]
            else:
                del queue[n]
                if not queue:
                    break
                if n < i:
                    i -= 1
                    if playing is not None:
                        playing -= 1
                i %= len(queue)
        if queue:
            if playing is not None:
                nxt = state["next_i"]
                state["next_i"] = plan_next(i) if not shuffle or nxt is None or nxt >= len(queue) or nxt == i else nxt
            else:
                state["next_i"] = i  # an Up next video plays; the list resumes here
            state["cur"] = (state["cur"][0], state["cur"][1], i) if state["cur"] else None
        state["qlen"] = len(queue)
        write_coming(coming())
        return i

    def ahead(i):
        """Unplayed list videos still to come (shuffle: any not played yet)."""
        if options().get("shuffle"):
            return sum(1 for q in queue if key(q).split(".")[0] not in played)
        return len(queue) - 1 - i

    def prefetch(i, item):
        reap()
        i = process_commands(i)
        if topup and queue and ahead(i) < 5:  # nearly through the Mix: fetch more for what's playing now
            start_mix(key(item).split(".")[0])
        write_coming(coming())
        if len(queue) != state["qlen"]:  # the Mix arrived: plan the list's next video again
            state["qlen"] = len(queue)
            if state["cur"] and state["cur"][1]:
                state["next_i"] = plan_next(i)
            try:
                mpv(["set_property", "user-data/kpopping/count", len(queue) + len(load(Path(upnext), []) if upnext else [])])
            except OSError:
                pass
        if not downloads:  # one at a time, so the current video never competes for long
            for it in upcoming(i, item):
                if not cached(it) and time.time() - failed.get(key(it), 0) >= 60:
                    download(it)
                    break
        return i

    player_started = False
    seek = float(cfg.get("seek") or 0)  # resuming: the first video starts here
    i = max(0, min(cfg.get("start", 0), len(queue) - 1))
    item, from_list = (queue[i] if queue else _pop_upnext(upnext)), True
    if cfg.get("first_item"):  # resuming an Up next video that isn't in the list
        item, from_list = cfg["first_item"], bool(cfg.get("from_list"))
    history = []  # (item, from_list, i) played before the current one, for Previous
    try:
        while item:
            state["skip"], state["back"], state["item"] = False, False, item
            state["cur"] = (item, from_list, i)
            played.add(key(item).split(".")[0])
            # the list continues after a list video; after an Up next video it resumes at i itself
            state["next_i"] = (plan_next(i) if from_list else i) if queue else None
            save_state(seek)
            # 1. the file (cached: instant; otherwise download it, the player shows "Loading")
            path = cached(item)
            if not path:
                if player_started:
                    call(["set_property", "user-data/kpopping/loading", True])
                download(item)
                while not path and not state["skip"]:
                    reap()
                    i = process_commands(i)
                    path = cached(item)
                    if not path and key(item) not in downloads:
                        break  # the download failed
                    time.sleep(0.3)
                if state["skip"] and not path:
                    stop_download(item)
            if path:
                os.utime(path)  # most recently used: last to be pruned
                # 2. play it
                if not player_started:
                    subprocess.Popen(["mpvpaper", "-l", "bottom", "-o", cfg["mpv_opts"],
                                      cfg.get("output") or "ALL", str(path)],
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
                    for _ in range(60):
                        if _mpv_alive():
                            break
                        time.sleep(0.25)
                    else:
                        return 0
                    player_started = True
                    if seek:
                        # Resume: mpvpaper reloads the file itself while it sets up its surface ("Restoring
                        # previous time"), which undid a start= option (videos resumed from 0). So: watch the
                        # position and seek whenever it's behind, until it has held for ~2 s (max ~12 s).
                        held = 0
                        for _ in range(40):
                            try:
                                pos = json.loads(mpv(["get_property", "time-pos"])).get("data")
                            except (OSError, ValueError):
                                pos = None
                            if isinstance(pos, (int, float)):
                                if pos < seek - 3:
                                    held = 0
                                    try:
                                        mpv(["seek", int(seek), "absolute+exact"])
                                    except OSError:
                                        pass
                                else:
                                    held += 1
                                    if held >= 7:
                                        break
                            time.sleep(0.3)
                else:
                    call(["loadfile", str(path), "replace", -1, f"start={int(seek)}" if seek else "start=none"])
                seek = 0
                call(["set_property", "force-media-title", item["title"]])
                call(["set_property", "user-data/kpopping/id", key(item).split(".")[0]])  # the notch's thumbnail
                call(["set_property", "user-data/kpopping/count", len(queue) + len(load(Path(upnext), []) if upnext else [])])
                call(["set_property", "user-data/kpopping/loading", False])
                prune({key(it).split(".")[0] for it in [item] + upcoming(i, item)})
                # 3. wait for the end (or Next / Previous), downloading what comes next meanwhile
                time.sleep(0.5)
                while not state["skip"]:
                    try:
                        if json.loads(mpv(["get_property", "eof-reached"])).get("data"):
                            break
                    except (OSError, ValueError):
                        if not _mpv_alive():
                            return 0
                    i = prefetch(i, item)
                    time.sleep(0.4)
            elif not state["skip"]:
                time.sleep(3)  # couldn't download it (gone, region-locked, offline): move on
            # 4. what's next
            jump = load(Path(cfg["jump"]), None) if cfg.get("jump") else None
            if jump is not None:  # an autoplay video picked in Up next: continue the list from it
                Path(cfg["jump"]).unlink(missing_ok=True)
                if isinstance(jump.get("i"), int) and 0 <= jump["i"] < len(queue):
                    history = (history + [(item, from_list, i)])[-50:]
                    i, item, from_list = jump["i"], queue[jump["i"]], True
                    continue
            if state["back"]:  # Previous: the video before this one (or this one again from the start)
                if history:
                    item, from_list, i = history.pop()
                continue
            history = (history + [(item, from_list, i)])[-50:]
            repeat = options().get("loop") and not state["skip"] and path
            queued = _pop_upnext(upnext)  # Up next comes first, ahead of Loop
            if from_list and not repeat and state["next_i"] is not None:
                i = state["next_i"]  # leaving a list video: move on in the list
            if queued:
                item, from_list = queued, False
            elif repeat:
                pass  # same video again
            else:
                item, from_list = (queue[i] if queue else None), True
        return 0
    finally:
        write_coming([])
        for proc in downloads.values():
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except OSError:
                pass
        if player_started:
            try:
                mpv(["quit"])
            except OSError:
                pass


# ── local wallpaper thumbnails (collage / big cards) ──────────────────────

LOCAL_THUMBS = CACHE / "local-thumbs"
VIDEO_EXTS = {".mp4", ".webm", ".mov", ".avi", ".mkv"}


def _local_key(path, st):
    return hashlib.sha1(f"{path}|{st.st_mtime_ns}|{st.st_size}".encode()).hexdigest()[:20]


def _make_local_thumb(path, out):
    video = Path(path).suffix.lower() in VIDEO_EXTS
    if not video:  # Pillow, if there: decodes JPEGs at reduced size (~10x faster than ffmpeg)
        try:
            from PIL import Image, ImageOps
            tmp = Path(str(out) + ".tmp.jpg")
            with Image.open(path) as im:
                im.draft("RGB", (480, 480))
                im = ImageOps.exif_transpose(im).convert("RGB")  # phone photos stay upright
                im.thumbnail((480, 480))
                im.save(tmp, "JPEG", quality=82)
            tmp.replace(out)
            return True
        except Exception:
            pass  # no Pillow, or a format it can't read: ffmpeg below
    cmd = ["ffmpeg", "-v", "error", "-y"] + (["-ss", "1"] if video else []) + ["-i", path, "-frames:v", "1",
           "-vf", "scale='if(gt(iw,ih),min(480,iw),-2)':'if(gt(iw,ih),-2,min(480,ih))'", "-q:v", "4", str(out) + ".tmp.jpg"]
    run = subprocess.run(cmd, capture_output=True, timeout=60)
    tmp = Path(str(out) + ".tmp.jpg")
    if run.returncode != 0 or not tmp.exists():
        tmp.unlink(missing_ok=True)
        if video:  # shorter than a second
            run = subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", path, "-frames:v", "1", "-vf",
                                  "scale='if(gt(iw,ih),min(480,iw),-2)':'if(gt(iw,ih),-2,min(480,ih))'", "-q:v", "4", str(tmp)],
                                 capture_output=True, timeout=60)
        if run.returncode != 0 or not tmp.exists():
            return False
    tmp.replace(out)
    return True


def local_thumbs(list_file):
    paths = [l for l in Path(list_file).read_text().splitlines() if l.strip()]
    LOCAL_THUMBS.mkdir(parents=True, exist_ok=True)
    index_file = LOCAL_THUMBS / "index.json"
    index = load(index_file, {})  # key -> [w, h]
    todo, keep = [], set()
    for path in paths:
        try:
            st = os.stat(path)
        except OSError:
            continue
        key = _local_key(path, st)
        keep.add(key)
        thumb = LOCAL_THUMBS / (key + ".jpg")
        if thumb.exists() and key in index:
            w, h = index[key]
            emit({"path": path, "w": w, "h": h, "thumb": thumb.as_uri()})
        else:
            todo.append((path, key, thumb))

    def work(job):
        path, key, thumb = job
        ok = thumb.exists() or _make_local_thumb(path, thumb)
        size = image_size(thumb) if ok else None  # the thumbnail keeps the shape: its size is the ratio
        return path, key, thumb, ok, size

    done = 0
    with ThreadPoolExecutor(max_workers=min(8, os.cpu_count() or 4)) as pool:
        for path, key, thumb, ok, size in pool.map(work, todo):
            done += 1
            if ok and size and all(size):
                index[key] = list(size)
                emit({"path": path, "w": size[0], "h": size[1], "thumb": thumb.as_uri()})
            if done % 25 == 0 or done == len(todo):
                emit({"progress": done, "total": len(todo)})
                save(index_file, index)
    # drop thumbnails of wallpapers that were deleted, moved or changed
    for f in LOCAL_THUMBS.glob("*.jpg"):
        if f.stem not in keep:
            f.unlink(missing_ok=True)
    save(index_file, {k: v for k, v in index.items() if k in keep})
    emit({"done": True})
    return 0


# ── cli ──────────────────────────────────────────────────────────────────

def main(argv):
    if len(argv) == 4 and argv[0] == "fit":
        return fit(*argv[1:])
    if argv[:1] == ["mpv-watch"]:
        return mpv_watch()
    if len(argv) == 2 and argv[0] == "yt-player":
        return yt_player(argv[1])
    if len(argv) == 2 and argv[0] == "local-thumbs":
        return local_thumbs(argv[1])
    if len(argv) == 2 and argv[0] == "mpv":
        try:
            print(mpv(json.loads(argv[1])))
            return 0
        except (OSError, ValueError) as e:
            print(json.dumps({"error": str(e)}))
            return 1
    if len(argv) >= 2 and argv[0] == "yt":
        pages = max(1, int(argv[argv.index("--pages") + 1])) if "--pages" in argv[:-1] else 1
        try:
            out = yt(argv[1], pages)
        except Exception as e:
            out = {"status": "error", "message": str(e)}
        emit({**out, "totalFound": len(out.get("photos", [])), "query": argv[1], "pages": pages, "key": "yt|"})
        return 0
    if len(argv) < 2 or argv[0] != "search":
        print(__doc__, file=sys.stderr)
        return 2
    arg = lambda name, default: argv[argv.index(name) + 1] if name in argv[:-1] else default
    orient = set(filter(None, arg("--orient", "").split(",")))
    res = set(filter(None, arg("--res", "").split(",")))
    pages = max(1, int(arg("--pages", 1)))
    entity_key = arg("--entity", "")
    tagged = "--tagged" in argv
    sort = arg("--sort", "hot") if arg("--sort", "hot") in ("hot", "new", "top") else "hot"
    prune(CACHE / "thumbs", 30)
    prune(CACHE / "full", 7, keep=in_use())
    try:
        out = search(argv[1], pages, entity_key, tagged, sort)
    except Exception as e:
        out = {"status": "error", "message": str(e)}

    photos = [p for p in out.get("photos", [])
              if (not orient or orientation(p["width"], p["height"]) in orient)
              and (not res or resolution(p["width"], p["height"]) in res)]
    missing = []
    for p in photos:
        f = thumb_file(p["src"])
        if f.exists():
            os.utime(f)  # keeps it out of the 30-day prune
            p["thumb"] = f.as_uri()
        else:
            missing.append(p["src"])
    # query/key/pages let the shell drop stale results
    emit({**out, "photos": photos, "totalFound": len(photos), "query": argv[1], "pages": pages,
          "key": "|".join([arg("--orient", ""), arg("--res", ""), entity_key, "tagged" if tagged else "", sort])})

    with ThreadPoolExecutor(max_workers=8) as pool:
        for src, url in pool.map(fetch_thumb, missing):
            emit({"thumb": src, "url": url})
    return 0


if __name__ == "__main__":
    karina = {"type": "idol", "id": "k", "name": "Karina", "groupName": "aespa"}
    ryujin = {"type": "idol", "id": "r", "name": "Ryujin", "groupName": "ITZY"}
    itzy = {"type": "group", "id": "g", "name": "ITZY"}
    src = "https://x/kpics/2026/10/1791601951723-8g362k-6.JPG"
    yuna_post = {"idolId": "y", "idolName": "Yuna, Ryujin, Lia", "photoDate": "2026-09-17"}
    assert save_path({"photoDate": "2026-10-26", "idolId": "k", "idolName": "Karina"}, karina, src) == "aespa/Karina/Karina_2026-10-26_8g362k-6.jpg"
    assert save_path(yuna_post, ryujin, src, lambda i, n: "ITZY") == "ITZY/Yuna/Yuna_2026-09-17_8g362k-6.jpg"
    assert save_path(yuna_post, itzy, src) == "ITZY/mix/ITZY_2026-09-17_8g362k-6.jpg"
    assert save_path({"idolName": "Yuna"}, itzy, src).startswith("ITZY/Yuna/Yuna_")
    assert save_path({}, {"type": "group", "id": "z", "name": "IZ*ONE"}, src) == "IZ*ONE/mix/IZ*ONE_undated_8g362k-6.jpg"
    assert save_path({"idolName": "IU", "idolId": "i"}, {"type": "idol", "id": "i", "name": "IU"}, src).startswith("IU/IU_")
    assert clean("../..") == "misc" and clean("a/b") == "ab"
    assert YT_LINK.match("https://youtube.com/playlist?list=PLx") and YT_LINK.match("https://youtu.be/abcdefghijk")
    assert not YT_LINK.match("--exec rm") and not YT_LINK.match("https://evil.example/youtube.com/x")
    assert [orientation(*s) for s in ((1920, 1080), (1080, 1350), (1000, 1000))] == ["landscape", "portrait", "square"]
    assert [resolution(*s) for s in ((1024, 682), (1080, 1920), (2592, 1944), (4096, 3072), (8000, 6000))] == ["sd", "fhd", "2k", "4k", "8k"]
    sys.exit(main(sys.argv[1:]))
