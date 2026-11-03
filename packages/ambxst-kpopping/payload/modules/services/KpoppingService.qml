pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals

// Kpopping: search kpopping.com from the Wallpapers tab. Thumbnails and full-size
// photos are cached in ~/.cache/ambxst/kpopping (see kpopping_bridge.py).
// - apply: copies the photo to <wallpaperDir>/kpopping/<Group>/<Idol>/ and sets it
//   through the stock setWallpaper (matugen + skwd-wall run as usual)
// - preview: sets the cached copy as the wallpaper so it can be judged on the real
//   desktop; save keeps it (= apply), discard goes back to the previous wallpaper.
//   Unsaved previews are pruned after 7 days unless one is still the wallpaper.
// Lives as long as the shell, so mode, query, results and filters survive the
// dashboard closing (and the tab being rebuilt).
Singleton {
    id: root

    property bool active: false        // Wallpapers tab is showing kpopping results
    property string lastQuery: ""      // restored into the search box
    property var filters: ["landscape"] // FilterBar chip types, see filterChips
    readonly property var filterChips: [
        { label: "Landscape", type: "landscape" },
        { label: "Portrait", type: "portrait" },
        { label: "Square", type: "square" },
        { label: "SD", type: "sd" },
        { label: "HD", type: "hd" },
        { label: "FHD", type: "fhd" },
        { label: "2K", type: "2k" },
        { label: "4K", type: "4k" },
        { label: "8K", type: "8k" }
    ]
    readonly property string _orient: filters.filter(f => ["landscape", "portrait", "square"].includes(f)).join(",")
    readonly property string _res: filters.filter(f => ["sd", "hd", "fhd", "2k", "4k", "8k"].includes(f)).join(",")

    property bool searching: false
    property string progress: ""       // "12/30" while albums load
    property string downloading: ""    // src being fetched (card spinner)
    property string error: ""
    property var photos: []
    property string shownQuery: ""     // query the current photos belong to
    property var thumbs: ({})          // src -> image URL (cached file, or a fallback)
    readonly property var urls: photos.map(p => p.src)
    readonly property var bySrc: {
        const m = {};
        for (const p of photos)
            m[p.src] = p;
        return m;
    }

    // Desktop preview
    property string previewSrc: ""
    property var previewPhoto: null
    property string previewPath: ""    // cached file currently shown as the wallpaper
    property string _previewScreen: ""
    property string _revertPath: ""
    readonly property bool previewing: previewPath !== "" && _current(_previewScreen) === previewPath

    readonly property string _ua: "ambxst-kpopping/1.0 (+https://github.com/POSiTiiiV/ambxst-mods)"
    readonly property string _fullCache: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/ambxst/kpopping/full/"
    property string _query: ""

    function search(query) {
        _query = query.trim();
        if (_query)
            lastQuery = _query;
        if (_query !== shownQuery) {
            // don't leave the old idol's photos up while the new search runs
            photos = [];
            thumbs = {};
            shownQuery = "";
            error = "";
            progress = "";
            searching = _query !== "";
        }
        debounce.restart();
    }

    function apply(src, screenName) {
        const wm = GlobalStates.wallpaperManager;
        const photo = bySrc[src] || (src === previewSrc ? previewPhoto : null);
        if (!wm || !wm.wallpaperDir || !photo || fetcher.running)
            return;
        const path = wm.wallpaperDir.replace(/\/+$/, "") + "/kpopping/" + photo.save;
        _clearPreview();
        if (wm.wallpaperPaths.indexOf(path) !== -1)
            _set(path, screenName);
        else
            _fetch(src, path, screenName);
    }

    function preview(src, screenName) {
        if (!src || fetcher.running || !bySrc[src])
            return;
        if (!previewing)
            _revertPath = _current(screenName);   // what "discard" goes back to
        previewSrc = src;
        previewPhoto = bySrc[src];
        _previewScreen = screenName;
        _fetch(src, "", screenName);
    }

    function savePreview() {
        if (previewing)
            apply(previewSrc, _previewScreen);
    }

    function discardPreview() {
        if (previewing && _revertPath)
            _set(_revertPath, _previewScreen);
        _clearPreview();
    }

    function _clearPreview() {
        previewSrc = "";
        previewPhoto = null;
        previewPath = "";
    }

    function _current(screenName) {
        const wm = GlobalStates.wallpaperManager;
        if (!wm)
            return "";
        const perScreen = wm.perScreenWallpapers || {};
        return screenName && perScreen[screenName] !== undefined ? perScreen[screenName] : (wm.currentWallpaper || "");
    }

    // Full-size file into the cache (unless already there), then copied to dest if given.
    // .part names keep half-written files out of the wallpaper scan (it filters by extension).
    function _fetch(src, dest, screenName) {
        error = "";
        downloading = src;
        fetcher.src = src;
        fetcher.cached = _fullCache + src.split("/").pop();
        fetcher.dest = dest;
        fetcher.screenName = screenName;
        fetcher.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && { [ -s "$1" ] || { curl -fsSL -A "$4" -o "$1.part" "$2" && mv "$1.part" "$1"; }; } && touch "$1" && ' + '{ [ -z "$3" ] || { mkdir -p "$(dirname "$3")" && cp "$1" "$3.part" && mv "$3.part" "$3"; }; }', "sh", fetcher.cached, src, dest, _ua];
        fetcher.running = true;
    }

    function _set(path, screenName) {
        const wm = GlobalStates.wallpaperManager;
        // setWallpaper ignores paths it hasn't scanned yet; add it the way the scan would
        // instead of waiting on the directory watchers, which may not cover a brand-new subfolder.
        if (wm.wallpaperPaths.indexOf(path) === -1)
            wm.wallpaperPaths = wm.wallpaperPaths.concat([path]).sort();
        if (screenName)
            wm.setWallpaper(path, screenName);
        else
            wm.setWallpaper(path);
    }

    function _stale() {
        return searchProc.query !== _query || searchProc.filterKey !== _orient + "|" + _res;
    }

    function _run() {
        if (searchProc.running) {
            if (_stale())
                searchProc.running = false;   // stop the old search; onExited starts the newest one
            return;
        }
        if (!_query) {
            searching = false;
            return;
        }
        searching = true;
        searchProc.query = _query;
        searchProc.orient = _orient;
        searchProc.res = _res;
        searchProc.running = true;
    }

    onFiltersChanged: _run()

    Timer {
        id: debounce
        interval: 500
        onTriggered: root._run()
    }

    Process {
        id: searchProc
        property string query: ""
        property string orient: ""
        property string res: ""
        readonly property string filterKey: orient + "|" + res
        command: ["python3", Quickshell.shellDir + "/scripts/kpopping_bridge.py", "search", query, "--orient", orient, "--res", res]
        stdout: SplitParser {
            onRead: line => {
                let d;
                try {
                    d = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (d.thumb !== undefined) {
                    const t = Object.assign({}, root.thumbs);
                    t[d.thumb] = d.url;
                    root.thumbs = t;
                    return;
                }
                if (d.query !== root._query)
                    return;   // stale: a newer search is queued
                if (d.progress !== undefined) {
                    root.progress = d.progress + "/" + d.total;
                    return;
                }
                if (d.filters !== root._orient + "|" + root._res)
                    return;
                root.searching = false;
                root.progress = "";
                root.error = d.status === "ok" ? "" : (d.message || "Search failed");
                const t = {};
                for (const p of d.photos || [])
                    if (p.thumb)
                        t[p.src] = p.thumb;
                root.thumbs = t;
                root.photos = d.photos || [];
                root.shownQuery = d.query;
            }
        }
        onExited: {
            if (root._stale())
                Qt.callLater(root._run);
            else
                root.searching = false;
        }
    }

    Process {
        id: fetcher
        property string src: ""
        property string cached: ""
        property string dest: ""
        property string screenName: ""
        stderr: StdioCollector {
            id: fetchErr
        }
        onExited: code => {
            root.downloading = "";
            if (code !== 0) {
                root.error = "Download failed: " + (fetchErr.text.trim() || "curl exit " + code);
                if (src === root.previewSrc)
                    root._clearPreview();
            } else if (dest) {
                root._set(dest, screenName);
            } else if (src === root.previewSrc) {
                root._set(cached, screenName);
                root.previewPath = cached;
            }
        }
    }
}
