#!/usr/bin/env python3
"""kpopping.com search for the Ambxst wallpaper tab, plus skwd-wall fit modes.

usage:
  kpopping_bridge.py search <query> [--orient landscape,portrait,square] [--res sd,hd,fhd,2k,4k,8k]
                                    [--pages N] [--entity idol:<id>|group:<id>] [--tagged] [--sort hot|new|top]
  kpopping_bridge.py fit <image> <auto|fill|fit|stretch|center|tile> <blur|color>

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

fit: writes skwd-wall's display.fillMode / display.backgroundMode before an apply.
  auto = landscape images fill the screen, portrait and square ones are shown whole.

Caches in ~/.cache/ambxst/kpopping: name lookups and post pages (6 h), album sizes (per post,
until the album grows), idols' groups, and thumbnails (pruned after 30 days unused). The shell
puts full-size previews in full/ (pruned after 7 days unless one is still your wallpaper).
Stdlib only, public API, no cookies.
"""
import hashlib
import json
import os
import struct
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


def fetch_thumb(src):
    f = thumb_file(src)
    try:
        data = fetch("https://kpopping.com/_next/image", url=src, w=384, q=75)
        f.parent.mkdir(parents=True, exist_ok=True)
        tmp = f.with_name(f.name + ".part")
        tmp.write_bytes(data)
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


# ── cli ──────────────────────────────────────────────────────────────────

def main(argv):
    if len(argv) == 4 and argv[0] == "fit":
        return fit(*argv[1:])
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
    assert [orientation(*s) for s in ((1920, 1080), (1080, 1350), (1000, 1000))] == ["landscape", "portrait", "square"]
    assert [resolution(*s) for s in ((1024, 682), (1080, 1920), (2592, 1944), (4096, 3072), (8000, 6000))] == ["sd", "fhd", "2k", "4k", "8k"]
    sys.exit(main(sys.argv[1:]))
