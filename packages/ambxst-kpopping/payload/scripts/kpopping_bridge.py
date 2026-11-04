#!/usr/bin/env python3
"""kpopping.com search for the Ambxst wallpaper tab, plus skwd-wall fit modes.

usage:
  kpopping_bridge.py search <query> [--orient landscape,portrait,square] [--res sd,hd,fhd,2k,4k,8k]
                                    [--pages N] [--entity idol:<id>|group:<id>] [--tagged] [--sort hot|new|top]
  kpopping_bridge.py fit <image> <auto|fill|fit|stretch|center|tile> <blur|color>
  kpopping_bridge.py yt <search words | youtube video/playlist link> [--pages N]
  kpopping_bridge.py mpv <json command array>        e.g. mpv '["cycle","mute"]'
  kpopping_bridge.py mpv-watch                       stream the player's title/mute/pause as JSON lines
  kpopping_bridge.py yt-player <queue.json>          feed the queue into the player's pipe, one video at a time

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

yt-player: YouTube refuses mpv's own stream fetches (403 since late 2026), while yt-dlp's downloader
  works. So the player (mpvpaper, ytdl=no, loop-playlist=force) reads a named pipe, and this feeds it
  one video at a time: yt-dlp -o - into the pipe, nothing on disk. queue.json:
  {"fifo", "format", "queue": [{"url", "title"}], "start", "mix": bool, "options": <json with loop/shuffle>,
   "upnext": <json list of {"url", "title"}>}. Up next (popped from its file) plays first, ahead of Loop;
  then the list carries on. Loop/shuffle are re-read before every video. SIGUSR1 = next video.
  Exits (and quits the player) when done; exits quietly when the player is gone.

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
    for _ in range(60):  # the player opens its socket a moment after it starts
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
        for i, prop in enumerate(("media-title", "mute", "pause", "user-data/kpopping/count"), 1):
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


def _pop_upnext(path):
    """First video of the up-next queue (the shell's Ctrl+click), removed from the file."""
    if not path:
        return None
    items = load(Path(path), [])
    if not items:
        return None
    save(Path(path), items[1:])
    return items[0]


def yt_player(queue_file):
    cfg = json.loads(Path(queue_file).read_text())
    fifo, fmt, queue, upnext = cfg["fifo"], cfg["format"], cfg["queue"], cfg.get("upnext")
    # the player is started at the same moment: wait for its socket (losing this race used to end
    # the feeder at once, leaving an idle player the notch showed as playing)
    for _ in range(60):
        if _mpv_alive():
            break
        time.sleep(0.25)
    else:
        return 0
    if cfg.get("mix") and queue:  # YouTube's Mix after the clicked video, like YouTube's autoplay
        try:
            out = subprocess.run(["yt-dlp", "--flat-playlist", "-J", "--playlist-end", "50", "--no-warnings", "--", queue[0]["mix"]],
                                 capture_output=True, text=True, timeout=90)
            for e in (json.loads(out.stdout).get("entries") or [])[1:]:
                if e.get("id") and len(e["id"]) == 11:
                    queue.append({"url": f"https://www.youtube.com/watch?v={e['id']}", "title": e.get("title") or e["id"]})
        except Exception:
            pass  # the clicked video still plays (and loops)
    state = {"skip": False, "child": None}

    def next_video(*_):
        state["skip"] = True
        if state["child"]:
            try:
                os.killpg(state["child"].pid, signal.SIGKILL)
            except OSError:
                pass
    signal.signal(signal.SIGUSR1, next_video)
    signal.signal(signal.SIGTERM, lambda *_: (next_video(), sys.exit(0)))

    def call(command, tries=8):
        """mpv IPC that rides out a brief hiccup; OSError only when the player is really gone."""
        for n in range(tries):
            try:
                return mpv(command)
            except OSError:
                if n == tries - 1:
                    raise
                time.sleep(0.25)

    def finish(skipped):
        """Wait until the player is done with the current video (drop it on Next); None if it's gone."""
        if skipped:
            call(["loadfile", fifo, "replace"])
        while True:
            if state["skip"]:  # Next while the player still plays what it buffered
                state["skip"], skipped = False, True
                call(["loadfile", fifo, "replace"])
            try:
                reply = json.loads(call(["get_property", "time-pos"]))
            except (OSError, ValueError):
                return None
            if reply.get("error") != "success":  # reopening the pipe: ready for the next video
                return skipped
            time.sleep(0.3)

    i = max(0, min(cfg.get("start", 0), len(queue) - 1))
    item, from_list, gone = (queue[i] if queue else _pop_upnext(upnext)), True, False
    try:
        while item:
            try:
                call(["set_property", "force-media-title", item["title"]])
                call(["set_property", "user-data/kpopping/count", len(queue) + len(load(Path(upnext), [])) if upnext else len(queue)])
            except OSError:
                gone = True
                return 0
            state["skip"] = False
            fd = None
            while fd is None and not state["skip"]:  # the player opens the pipe when it's ready to read
                try:
                    fd = os.open(fifo, os.O_WRONLY | os.O_NONBLOCK)
                except OSError as e:
                    if e.errno != errno.ENXIO:
                        raise
                    if not _mpv_alive():
                        gone = True
                        return 0
                    time.sleep(0.2)
            started, code = time.time(), 0
            if fd is not None:
                fcntl.fcntl(fd, fcntl.F_SETFL, fcntl.fcntl(fd, fcntl.F_GETFL) & ~os.O_NONBLOCK)
                state["child"] = subprocess.Popen(["yt-dlp", "-q", "--no-warnings", "-f", fmt, "-o", "-", "--", item["url"]],
                                                  stdout=fd, stderr=subprocess.DEVNULL, start_new_session=True)
                os.close(fd)
                code = state["child"].wait()
                state["child"] = None
            skipped = finish(state["skip"])
            if skipped is None:
                gone = True
                return 0
            if code != 0 and not skipped and time.time() - started < 5:
                time.sleep(5)  # failing fast (network down, video gone): don't spin
            opts = load(Path(cfg["options"]), {})
            repeat = opts.get("loop") and not skipped
            if from_list and not repeat and queue:  # leaving a list video: move on in the list
                if opts.get("shuffle") and len(queue) > 1:
                    i = random.choice([n for n in range(len(queue)) if n != i])
                else:
                    i = (i + 1) % len(queue)
            queued = _pop_upnext(upnext)  # Up next comes first, ahead of Loop
            if queued:
                item, from_list = queued, False
            elif repeat:
                pass  # same video again
            else:
                item, from_list = (queue[i] if queue else None), True
        return 0
    finally:
        if not gone:  # stopping for any other reason: don't leave an idle player behind
            try:
                mpv(["quit"])
            except OSError:
                pass


# ── cli ──────────────────────────────────────────────────────────────────

def main(argv):
    if len(argv) == 4 and argv[0] == "fit":
        return fit(*argv[1:])
    if argv[:1] == ["mpv-watch"]:
        return mpv_watch()
    if len(argv) == 2 and argv[0] == "yt-player":
        return yt_player(argv[1])
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
