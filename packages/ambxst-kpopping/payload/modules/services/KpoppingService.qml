pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import qs.modules.services

// Kpopping: search kpopping.com from the Wallpapers tab. Thumbnails and full-size
// photos are cached in ~/.cache/ambxst/kpopping (see kpopping_bridge.py).
// - preview (click / Enter): closes the dashboard, moves to an empty workspace and sets
//   the cached photo as the wallpaper; ✓ / ✗ in the notch keep it or go back.
//   Unsaved previews are pruned after 7 days unless one is still the wallpaper.
// - apply (Shift+click / Shift+Enter, or ✓): copies the photo to
//   <wallpaperDir>/kpopping/<Group>/<Idol>/ and sets it through the stock setWallpaper.
// - fit: before every skwd-wall apply, picks skwd's fill mode (auto = portrait shown whole).
// Lives as long as the shell, so mode, query, results and filters survive the
// dashboard closing (and the tab being rebuilt).
Singleton {
    id: root

    readonly property string modId: "positive.ambxst-kpopping"
    readonly property string bridge: Quickshell.shellDir + "/scripts/kpopping_bridge.py"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/ambxst/kpopping/"

    property bool active: false        // Wallpapers tab is showing kpopping results
    property string lastQuery: ""      // restored into the search box
    signal queryRequested(string query) // a "recent search" chip was clicked

    // ── filter chips (shown in the tab's FilterBar) ─────────────────────
    property var filters: ["sort:hot", "landscape"]
    readonly property var staticChips: [
        { label: "Hot", type: "sort:hot" },
        { label: "Newest", type: "sort:new" },
        { label: "Most liked", type: "sort:top" },
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
    // Empty box: recent searches. Ambiguous name: every match, best first, the shown one active.
    readonly property var filterChips: {
        let lead = [];
        if (!_query)
            lead = recent.map(q => ({ label: q, type: "recent:" + q }));
        else if (_query === shownQuery)
            lead = candidates.map(c => ({ label: c.label, type: "entity:" + c.key }));
        const tagged = entity && entity.type === "idol" ? [{ label: "+ Tagged", type: "tagged" }] : [];
        return lead.concat(staticChips, tagged);
    }
    readonly property string _orient: filters.filter(f => ["landscape", "portrait", "square"].includes(f)).join(",")
    readonly property string _res: filters.filter(f => ["sd", "hd", "fhd", "2k", "4k", "8k"].includes(f)).join(",")
    readonly property bool _tagged: filters.includes("tagged")
    readonly property string _sort: (filters.find(f => f.startsWith("sort:")) || "sort:hot").slice(5)
    property string entityKey: ""      // a match picked from the chips ("" = the best one)
    readonly property string _key: [_orient, _res, entityKey, _tagged ? "tagged" : "", _sort].join("|")

    onFiltersChanged: {
        // recent search chip: fill the box instead of filtering
        const recentChip = filters.find(f => f.startsWith("recent:"));
        if (recentChip) {
            filters = filters.filter(f => !f.startsWith("recent:"));
            queryRequested(recentChip.slice(7));
            return;
        }
        // match and sort chips act like radio buttons: the newest one wins, the shown one can't be unpicked
        const picked = filters.filter(f => f.startsWith("entity:"));
        const keep = picked.length ? picked[picked.length - 1] : (entity && candidates.length ? "entity:" + entity.key : "");
        const sorts = filters.filter(f => f.startsWith("sort:"));
        const sort = sorts.length ? sorts[sorts.length - 1] : "sort:" + _shownSort;
        const normal = filters.filter(f => !f.startsWith("entity:") && !f.startsWith("sort:")).concat([sort], keep ? [keep] : []);
        if (JSON.stringify(normal) !== JSON.stringify(filters)) {
            filters = normal;
            return;
        }
        const key = keep.slice(7);
        if (key && entity && key !== entity.key) {
            entityKey = key;
            pages = 1;
            photos = [];
        }
        if (_sort !== _shownSort) {   // a different order starts again from the top
            _shownSort = _sort;
            pages = 1;
            photos = [];
        }
        _autoPages = 0;
        debounce.restart();
    }

    // ── results ─────────────────────────────────────────────────────────
    property bool searching: false
    property string progress: ""       // "12/30" while albums load
    property string downloading: ""    // src being fetched (card spinner)
    property string error: ""
    property var photos: []
    property var entity: null
    property var candidates: []
    property string shownQuery: ""     // query the current photos belong to
    property string _shownKey: ""
    property string _shownSort: "hot"
    property int _shownPages: 0
    property var thumbs: ({})          // src -> image URL (cached file, or a fallback)
    property int pages: 1
    property bool hasMore: false
    property bool appending: false     // next photos update only adds a page (tab keeps its scroll)
    property int _autoPages: 0
    readonly property var urls: photos.map(p => p.src)
    readonly property var bySrc: {
        const m = {};
        for (const p of photos)
            m[p.src] = p;
        return m;
    }
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
            entity = null;
            candidates = [];
            entityKey = "";
            pages = 1;
            hasMore = false;
            _autoPages = 0;
            error = "";
            progress = "";
            searching = _query !== "";
            filters = filters.filter(f => !f.startsWith("entity:"));
        }
        debounce.restart();
    }

    // The tab calls this when the grid is scrolled to the end.
    function loadMore() {
        if (!hasMore || searchProc.running || !shownQuery || shownQuery !== _query)
            return;
        pages++;
        _run();
    }

    function _stale() {
        return searchProc.query !== _query || searchProc.key !== _key || searchProc.pages !== pages;
    }

    function _run() {
        if (searchProc.running) {
            if (_stale())
                searchProc.running = false;   // stop the old search; onExited starts the newest one
            return;
        }
        if (!_query || (_query === shownQuery && _key === _shownKey && pages === _shownPages && !error)) {
            searching = false;   // nothing to do, or these results are already showing
            return;
        }
        searching = true;
        searchProc.query = _query;
        searchProc.key = _key;
        searchProc.pages = pages;
        searchProc.command = ["python3", bridge, "search", _query, "--orient", _orient, "--res", _res, "--pages", String(pages)]
            .concat(entityKey ? ["--entity", entityKey] : [], _tagged ? ["--tagged"] : [], ["--sort", _sort]);
        searchProc.running = true;
    }

    Timer {
        id: debounce
        interval: 500
        onTriggered: root._run()
    }

    Process {
        id: searchProc
        property string query: ""
        property string key: ""
        property int pages: 1
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
                if (d.key !== root._key || d.pages !== root.pages)
                    return;
                root.searching = false;
                root.progress = "";
                root.error = d.status === "ok" ? "" : (d.message || "Search failed");
                const t = {};
                for (const p of d.photos || [])
                    if (p.thumb)
                        t[p.src] = p.thumb;
                root.appending = d.pages > 1 && root.photos.length > 0;
                root.thumbs = t;
                root.entity = d.entity || null;
                root.candidates = d.candidates || [];
                root.hasMore = !!d.more;
                root.photos = d.photos || [];
                root.shownQuery = d.query;
                root._shownKey = d.key;
                root._shownPages = d.pages;
                if (d.status === "ok")
                    root._remember(d.query);
                // show the picked match as the active chip (no new search: it's the default pick)
                if (root.entity && root.candidates.length && !root.filters.includes("entity:" + root.entity.key))
                    root.filters = root.filters.filter(f => !f.startsWith("entity:")).concat(["entity:" + root.entity.key]);
                // a strict filter can leave a page nearly empty: fetch a few more on its own
                if (root.photos.length < 28 && root.hasMore && root._autoPages < 3) {
                    root._autoPages++;
                    Qt.callLater(root.loadMore);
                }
            }
        }
        onExited: {
            if (root._stale())
                Qt.callLater(root._run);
            else
                root.searching = false;
        }
    }

    // ── recent searches (~/.cache/ambxst/kpopping/recent.json) ──────────
    property var recent: []
    function _remember(query) {
        const next = [query].concat(recent.filter(q => q.toLowerCase() !== query.toLowerCase())).slice(0, 8);
        if (JSON.stringify(next) === JSON.stringify(recent))
            return;
        recent = next;
        recentFile.setText(JSON.stringify(next));
    }
    FileView {
        id: recentFile
        path: root.cacheDir + "recent.json"
        printErrors: false
        onLoaded: {
            try {
                root.recent = JSON.parse(text()) || [];
            } catch (e) {}
        }
    }

    // ── save ────────────────────────────────────────────────────────────
    function apply(src, screenName) {
        const wm = GlobalStates.wallpaperManager;
        const photo = bySrc[src] || (src === previewSrc ? previewPhoto : null);
        if (!wm || !wm.wallpaperDir || !photo || fetcher.running)
            return;
        const path = wm.wallpaperDir.replace(/\/+$/, "") + "/kpopping/" + photo.save;
        const fromPreview = src === previewSrc && previewing ? previewPath : "";
        _clearPreview();
        if (wm.wallpaperPaths.indexOf(path) !== -1) {
            _handOver(fromPreview, path);
            _set(path, screenName, false);
        } else {
            _fetch(src, path, screenName, fromPreview);
        }
    }

    // Saving a preview copies the cached file into the library: same pixels, new path. Tell
    // skwd-wall the screens showing the preview already show the copy, so it doesn't play the
    // transition again from the image to itself.
    function _handOver(from, to) {
        if (!from)
            return;
        const next = Object.assign({}, SkwdWall.applied);
        let changed = false;
        for (const n in next) {
            if (next[n] === from) {
                next[n] = to;
                changed = true;
            } else if (SkwdWall.tint && next[n] === SkwdWall.tintedPath(from)) {
                next[n] = SkwdWall.tintedPath(to);
                changed = true;
            }
        }
        if (changed)
            SkwdWall.applied = next;
    }

    // ── desktop preview ─────────────────────────────────────────────────
    property string previewSrc: ""
    property var previewPhoto: null
    property string previewPath: ""    // cached file currently shown as the wallpaper
    property string _previewScreen: ""
    property string _revertPath: ""
    property int _returnWorkspace: -1
    property int _previewWorkspace: -1
    readonly property bool previewing: previewPath !== "" && _current(_previewScreen) === previewPath
    readonly property bool previewPending: previewSrc !== "" && previewPath === ""   // downloading it

    function preview(src, screenName) {
        if (!src || fetcher.running || !bySrc[src])
            return;
        if (!previewing && !previewPending) {
            _revertPath = _current(screenName);   // what ✗ goes back to
            _returnWorkspace = _workspace();
            _previewWorkspace = _emptyWorkspace();
            if (_previewWorkspace > 0 && _previewWorkspace !== _returnWorkspace)
                AxctlService.dispatch("workspace " + _previewWorkspace);
        }
        Visibilities.setActiveModule("");      // out of the way: the desktop is the preview
        previewSrc = src;
        previewPhoto = bySrc[src];
        _previewScreen = screenName;
        _fetch(src, "", screenName);
    }

    function savePreview() {
        if (!previewing)
            return;
        apply(previewSrc, _previewScreen);
        _goBack();
    }

    function discardPreview() {
        const was = previewing || previewPending;
        if (previewing && _revertPath)
            _set(_revertPath, _previewScreen, false);
        _clearPreview();
        if (!was)
            return;
        _goBack();
        // back to browsing where you left off
        GlobalStates.dashboardCurrentTab = 1;
        Visibilities.setActiveModule("dashboard");
    }

    function _clearPreview() {
        previewSrc = "";
        previewPhoto = null;
        previewPath = "";
    }

    function _goBack() {
        // only if you're still on the preview workspace
        if (_previewWorkspace > 0 && _returnWorkspace > 0 && _workspace() === _previewWorkspace)
            AxctlService.dispatch("workspace " + _returnWorkspace);
        _previewWorkspace = -1;
        _returnWorkspace = -1;
    }

    function _workspace() {
        const ws = AxctlService.focusedWorkspace;
        if (ws && ws.id)
            return ws.id;
        const mon = AxctlService.focusedMonitor;
        return mon && mon.activeWorkspace ? mon.activeWorkspace.id : -1;
    }

    // the current workspace if it has no windows, else the lowest-numbered empty one
    function _emptyWorkspace() {
        const used = {};
        for (const c of AxctlService.clients.values || [])
            if (c.workspace)
                used[c.workspace.id] = true;
        const current = _workspace();
        if (current > 0 && !used[current])
            return current;
        let n = 1;
        while (used[n])
            n++;
        return n;
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
    function _fetch(src, dest, screenName, fromPreview) {
        error = "";
        downloading = src;
        fetcher.src = src;
        fetcher.fromPreview = fromPreview || "";
        fetcher.cached = cacheDir + "full/" + src.split("/").pop();
        fetcher.dest = dest;
        fetcher.screenName = screenName;
        fetcher.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && { [ -s "$1" ] || { curl -fsSL -A "$4" -o "$1.part" "$2" && mv "$1.part" "$1"; }; } && touch "$1" && ' + '{ [ -z "$3" ] || { mkdir -p "$(dirname "$3")" && cp "$1" "$3.part" && mv "$3.part" "$3"; }; }', "sh", fetcher.cached, src, dest, "ambxst-kpopping/1.0 (+https://github.com/POSiTiiiV/ambxst-mods)"];
        fetcher.running = true;
    }

    function _set(path, screenName, temporary) {
        const wm = GlobalStates.wallpaperManager;
        // setWallpaper ignores paths it hasn't scanned yet; add it the way the scan would
        // instead of waiting on the directory watchers, which may not cover a brand-new subfolder.
        const known = wm.wallpaperPaths.indexOf(path) !== -1;
        if (!known)
            wm.wallpaperPaths = wm.wallpaperPaths.concat([path]).sort();
        if (screenName)
            wm.setWallpaper(path, screenName);
        else
            wm.setWallpaper(path);
        // a preview lives in the cache: keep it out of the library grid and the random pool
        if (temporary && !known)
            wm.wallpaperPaths = wm.wallpaperPaths.filter(p => p !== path);
    }

    Process {
        id: fetcher
        property string src: ""
        property string cached: ""
        property string dest: ""
        property string screenName: ""
        property string fromPreview: ""
        stderr: StdioCollector {
            id: fetchErr
        }
        onExited: code => {
            root.downloading = "";
            if (code !== 0) {
                root.error = "Download failed: " + (fetchErr.text.trim() || "curl exit " + code);
                if (src === root.previewSrc)
                    root.discardPreview();
            } else if (dest) {
                root._handOver(fromPreview, dest);
                root._set(dest, screenName, false);
            } else if (src === root.previewSrc) {
                root._set(cached, screenName, true);
                root.previewPath = cached;
            }
        }
    }

    // ── fit (mod settings, applied before every skwd-wall apply) ────────
    property string fitMode: "auto"        // auto | fill | fit | stretch | center | tile | skwd
    property string fitBackground: "blur"  // blur | color

    // SkwdWall.applyCommand wraps its skwd-helm call with this.
    function withFit(file, command) {
        if (fitMode === "skwd")
            return command;
        return ["sh", "-c", 'python3 "$1" fit "$2" "$3" "$4" >/dev/null 2>&1; shift 4; exec "$@"', "sh", bridge, file, fitMode, fitBackground].concat(command);
    }

    function _setting(key, value) {
        if (key === "fitMode" || key === "fitBackground")
            root[key] = String(value);
    }

    Component.onCompleted: ModsService.getSettings(modId, (result, error) => {
        const values = result && result.values ? result.values : {};
        for (const key in values)
            _setting(key, values[key]);
    })

    Connections {
        target: ModsService
        function onSettingChanged(id, key, value) {
            if (id !== root.modId)
                return;
            root._setting(key, value);
            // show the new fit right away: have skwd-wall apply the current wallpaper again
            SkwdWall.applied = ({});
            SkwdWall.sync();
        }
    }
}
