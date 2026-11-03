#!/usr/bin/env python3
"""kpopping.com search for the Ambxst wallpaper tab.

usage: kpopping_bridge.py search <query> [--orient landscape,portrait,square] [--res sd,hd,fhd,2k,4k,8k] [--limit N]

Filters: chips within --orient (or --res) are OR'd, the two groups AND'd; empty = any.
Resolution buckets go by the longer edge: hd >= 1280, fhd >= 1920, 2k >= 2560, 4k >= 3840, 8k >= 7680.

stdout, one JSON object per line:
  0. {"progress": done, "total": n, "query": ...} while uncached albums load
  1. {"status": "ok", "entity": {...}, "photos": [...], "query": ..., "filters": ...}
     (or {"status": "error", "message": ...}); a photo's "thumb" is set when already cached
  2. then {"thumb": <src>, "url": <file:// or remote>} as missing thumbnails finish

Caches in ~/.cache/ambxst/kpopping: search results (6 h), album sizes (per post,
until the album grows) and thumbnails (pruned after 30 days unused). The shell
puts full-size previews in full/ (pruned after 7 days unless one is still your wallpaper).
Stdlib only, public API, no cookies.
"""
import hashlib
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

API = "https://kpopping.com/api"
UA = "ambxst-kpopping/1.0 (+https://github.com/POSiTiiiV/ambxst-mods)"
MIN_RATIO = 1.2
RES_BUCKETS = [("sd", 0), ("hd", 1280), ("fhd", 1920), ("2k", 2560), ("4k", 3840), ("8k", 7680)]
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "ambxst" / "kpopping"
RESULT_TTL = 6 * 3600
WALL_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".tif", ".tiff", ".gif"}  # what Ambxst's scan picks up


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
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(obj))
    tmp.replace(path)  # atomic: a killed search never leaves half a cache file


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


def pick_entity(query, found):
    pool = found.get("idols", []) + found.get("groups", [])
    q = query.strip().lower()
    # upstream ranks alias hits first ("Wonyoung" -> "Ever"), so prefer exact, then contained, names
    rank = lambda e: (e["name"].lower() != q, q not in e["name"].lower() and q not in e.get("slug", "").lower())
    return min(pool, key=rank) if pool else None


def clean(part):
    # names come from the network: one path segment each, but keep "IZ*ONE" / "(G)I-DLE" as written
    part = "".join(c for c in part if c != "/" and c.isprintable()).strip().lstrip(".")
    return part or "misc"


def save_path(post, entity, src):
    """<Group>/<Idol>/<Idol>_<date>_<id>.jpg; group-wide shots go in <Group>/mix, soloists in <Idol>/."""
    idol, group = post.get("idolName"), post.get("groupName")
    if entity["type"] == "idol":
        idol = idol or entity["name"]
        if idol == entity["name"]:
            group = group or entity.get("groupName")
    else:
        group = group or entity["name"]
    dirs = [group, idol] if group and idol else [group, "mix"] if group else [idol or "misc"]
    stem, ext = os.path.splitext(src.rsplit("/", 1)[-1])  # "1791601951723-8g362k-6", ".jpg"
    ext = ext.lower() if ext.lower() in WALL_EXTS else ".jpg"
    uid = stem.split("-", 1)[-1]  # drop the upload timestamp, keep the unique part
    name = f"{idol or group}_{post.get('photoDate') or 'undated'}_{uid}{ext}"
    return "/".join(clean(p) for p in dirs + [name])


def orientation(w, h):
    return "landscape" if w / h >= MIN_RATIO else "portrait" if h / w >= MIN_RATIO else "square"


def resolution(w, h):
    return [name for name, edge in RES_BUCKETS if max(w, h) >= edge][-1]


def search(query, limit):
    """Every album image of the entity's top posts, any orientation (filtered later)."""
    key_file = CACHE / "search" / (hashlib.sha1(f"{query.strip().lower()}|{limit}".encode()).hexdigest() + ".json")
    hit = load(key_file, None)
    if hit and time.time() - hit["time"] < RESULT_TTL:
        return hit["result"]

    entity = pick_entity(query, get("search/entities", q=query))
    if not entity:
        return {"status": "error", "message": f"No idol or group found for '{query}'"}
    key = "idolId" if entity["type"] == "idol" else "groupId"
    posts = get("photos", **{key: entity["id"], "limit": limit, "sort": "hot"})

    albums_file = CACHE / "albums.json"
    albums = load(albums_file, {})

    def album(post):
        cached = albums.get(post["id"])
        if cached and cached[0] == post.get("albumCount"):
            return post, cached[1]
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
                                   "save": save_path(post, entity, src)})
    save(albums_file, albums)

    result = {"status": "ok", "entity": {"name": entity["name"], "group": entity.get("groupName"),
                                         "type": entity["type"]}, "photos": photos}
    save(key_file, {"time": time.time(), "result": result})
    return result


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


def emit(obj):
    print(json.dumps(obj), flush=True)


def main(argv):
    if len(argv) < 2 or argv[0] != "search":
        print(__doc__, file=sys.stderr)
        return 2
    arg = lambda name, default: argv[argv.index(name) + 1] if name in argv[:-1] else default
    orient = set(filter(None, arg("--orient", "").split(",")))
    res = set(filter(None, arg("--res", "").split(",")))
    limit = int(arg("--limit", 30))
    prune(CACHE / "thumbs", 30)
    prune(CACHE / "full", 7, keep=in_use())
    try:
        out = search(argv[1], limit)
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
    # lets the shell drop stale results
    emit({**out, "photos": photos, "totalFound": len(photos), "query": argv[1],
          "filters": arg("--orient", "") + "|" + arg("--res", "")})

    with ThreadPoolExecutor(max_workers=8) as pool:
        for src, url in pool.map(fetch_thumb, missing):
            emit({"thumb": src, "url": url})
    return 0


if __name__ == "__main__":
    e = {"type": "idol", "name": "Karina", "groupName": "aespa"}
    src = "https://x/kpics/2026/10/1791601951723-8g362k-6.JPG"
    assert save_path({"photoDate": "2026-10-26"}, e, src) == "aespa/Karina/Karina_2026-10-26_8g362k-6.jpg"
    assert save_path({}, {"type": "group", "name": "IZ*ONE"}, src) == "IZ*ONE/mix/IZ*ONE_undated_8g362k-6.jpg"
    assert save_path({"idolName": "IU"}, {"type": "idol", "name": "IU"}, src).startswith("IU/IU_")
    assert clean("../..") == "misc" and clean("a/b") == "ab"
    assert [orientation(*s) for s in ((1920, 1080), (1080, 1350), (1000, 1000))] == ["landscape", "portrait", "square"]
    assert [resolution(*s) for s in ((1024, 682), (1080, 1920), (2592, 1944), (4096, 3072), (8000, 6000))] == ["sd", "fhd", "2k", "4k", "8k"]
    sys.exit(main(sys.argv[1:]))
