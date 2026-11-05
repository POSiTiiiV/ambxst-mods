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
// - YouTube (source "youtube"): search / paste a link, click plays the video as the wallpaper
//   (`bridge yt-player` downloads videos into an LRU cache with yt-dlp, since YouTube refuses mpv's own
//   stream fetches, prefetches the next ones, and plays them with mpvpaper on the layer above skwd-wall;
//   controls in the notch), Shift+click adds it
//   to "My playlist" (~/.config/ambxst/kpopping-youtube.json). The player is detached, so it
//   keeps playing across shell reloads; any other wallpaper change stops it.
// Lives as long as the shell, so mode, query, results and filters survive the
// dashboard closing (and the tab being rebuilt).
Singleton {
    id: root

    readonly property string modId: "positive.ambxst-kpopping"
    readonly property string bridge: Quickshell.shellDir + "/scripts/kpopping_bridge.py"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/ambxst/kpopping/"

    property bool active: false        // Wallpapers tab is showing online results
    property string source: "kpopping" // "kpopping" | "youtube"
    property var _lastQueries: ({})
    readonly property string lastQuery: _lastQueries[source] || ""   // restored into the search box
    readonly property string sourceName: source === "youtube" ? "YouTube" : "kpopping.com"

    // Globe / ▶ buttons: switch source, or back to the local library ("").
    function setSource(next) {
        if (!next) {
            active = false;
            return;
        }
        if (next !== source) {
            source = next;
            _query = "";
            photos = [];
            thumbs = {};
            shownQuery = "";
            _shownKey = "";
            entity = null;
            candidates = [];
            entityKey = "";
            error = "";
        }
        active = true;
    }

    // Click / Enter (shift = Shift+click / Shift+Enter, ctrl = Ctrl+click / Ctrl+P) on a grid item.
    function activate(src, screenName, shift, ctrl) {
        if (source === "youtube") {
            const p = bySrc[src];
            if (ytQueueView && p && p.coming) {   // an autoplay video in Up next
                if (ctrl)
                    ytQueueToggle(src, screenName);   // queue it
                else if (shift)
                    ytTogglePlaylist(src);
                else
                    ytJump(p.listIndex);   // continue the list from it
            } else if (ytQueueView && (shift || ctrl))
                ytQueueToggle(src, screenName);   // remove from Up next
            else if (ctrl)
                ytQueueToggle(src, screenName);
            else if (shift)
                ytTogglePlaylist(src);
            else
                ytPlay(src, screenName);
        } else if (shift) {
            apply(src, screenName);
        } else {
            preview(src, screenName);
        }
    }

    function label(p) {
        if (!p)
            return "";
        if (source === "youtube")
            return p.title + (p.channel ? " · " + p.channel : "") + (p.duration ? " · " + _clock(p.duration) : "")
                + (ytInPlaylist(p.id) ? " · in My playlist" : "")
                + (p.coming ? " · autoplay (click: jump here, Ctrl+click: queue)" : ytQueued(p.id) ? " · up next" : "");
        return p.width + "×" + p.height + " · " + p.likes + (p.likes === 1 ? " like · " : " likes · ") + p.title;
    }
    function _clock(sec) {
        const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), s = sec % 60;
        return (h ? h + ":" + String(m).padStart(2, "0") : m) + ":" + String(s).padStart(2, "0");
    }

    // The line shown over an empty grid.
    readonly property string statusText: searching ? "Searching " + sourceName + "…" + (progress ? "  (" + progress + " albums)" : "")
        : error ? error
        : source === "youtube" && ytListView ? "My playlist is empty. Shift+click a video to add it"
        : source === "youtube" && ytQueueView ? "Up next is empty. Ctrl+click a video (or Ctrl+P) to play it next"
        : !_query ? (source === "youtube" ? "Search YouTube or paste a video / playlist link" : "Type an idol or group name") + (recent.length ? ", or pick a recent search below the box" : "")
        : "No " + (source === "youtube" ? "videos" : "photos match these filters") + (hasMore ? " yet — scroll down or wait for more" : "")
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
    readonly property var ytChips: [
        { label: "Loop video", type: "yt:loop" },
        { label: "Shuffle", type: "yt:shuffle" },
        { label: "Autoplay", type: "yt:autoplay" }
    ]
    // Empty box: recent searches. Ambiguous name: every match, best first, the shown one active.
    readonly property var filterChips: {
        if (source === "youtube")
            return (!_query && !ytListView && !ytQueueView ? recent.map(q => ({ label: q, type: "recent:" + q })) : [])
                .concat(ytResume && !ytPlaying ? [{ label: "⏵ Resume: " + ytResume.item.title, type: "yt:resume" }] : [],
                        ytPlaylist.length ? [{ label: "▶ Play My playlist", type: "yt:playall" }] : [],
                        [{ label: "My playlist (" + ytPlaylist.length + ")", type: "yt:playlist" },
                         { label: "Up next (" + ytQueue.length + (ytComing.length ? " + " + ytComing.length + " autoplay" : "") + ")", type: "yt:queue" }], ytChips);
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
    readonly property string _key: source === "youtube" ? "yt|" + (ytListView ? "list" : ytQueueView ? "queue" : "")
        : [_orient, _res, entityKey, _tagged ? "tagged" : "", _sort].join("|")
    readonly property bool ytListView: filters.includes("yt:playlist")
    readonly property bool ytQueueView: filters.includes("yt:queue")

    onFiltersChanged: {
        // recent search chip: fill the box instead of filtering
        const recentChip = filters.find(f => f.startsWith("recent:"));
        if (recentChip) {
            filters = filters.filter(f => !f.startsWith("recent:"));
            queryRequested(recentChip.slice(7));
            return;
        }
        // ⏵ Resume / ▶ Play My playlist: actions, not filters
        if (filters.includes("yt:resume")) {
            filters = filters.filter(f => f !== "yt:resume");
            ytResumePlay();
            return;
        }
        if (filters.includes("yt:playall")) {
            filters = filters.filter(f => f !== "yt:playall");
            ytPlayAll();
            return;
        }
        // My playlist / Up next: one view at a time, the newest wins
        const views = filters.filter(f => f === "yt:playlist" || f === "yt:queue");
        if (views.length > 1) {
            filters = filters.filter(f => f !== views[0]);
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
        _ytOptionsChanged();
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
        // typing in My playlist goes back to searching
        if (source === "youtube" && (ytListView || ytQueueView) && query.trim() && query.trim() !== _query)
            filters = filters.filter(f => f !== "yt:playlist" && f !== "yt:queue");
        _query = query.trim();
        if (_query) {
            const q = Object.assign({}, _lastQueries);
            q[source] = _query;
            _lastQueries = q;
        }
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
        if (source === "youtube" && (ytListView || ytQueueView)) {
            _ytShowList(ytQueueView ? ytQueue.concat(ytComing) : ytPlaylist);
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
        searchProc.command = source === "youtube" ? ["python3", bridge, "yt", _query, "--pages", String(pages)]
            : ["python3", bridge, "search", _query, "--orient", _orient, "--res", _res, "--pages", String(pages)]
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
                root._shownList = !!d.list;
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

    // ── recent searches (kpopping: ~/.cache/ambxst/kpopping/recent.json, YouTube: in its json) ──
    property var kpRecent: []
    readonly property var recent: source === "youtube" ? ytRecent : kpRecent
    function _remember(query) {
        const next = [query].concat(recent.filter(q => q.toLowerCase() !== query.toLowerCase())).slice(0, 8);
        if (JSON.stringify(next) === JSON.stringify(recent))
            return;
        if (source === "youtube") {
            ytRecent = next;
            _ytSave();
        } else {
            kpRecent = next;
            recentFile.setText(JSON.stringify(next));
        }
    }
    FileView {
        id: recentFile
        path: root.cacheDir + "recent.json"
        printErrors: false
        onLoaded: {
            try {
                root.kpRecent = JSON.parse(text()) || [];
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
        if (!previewing && !previewPending)
            _revertPath = _current(screenName);   // what ✗ goes back to
        // every preview, not just the first: you may have gone back to your windows meanwhile
        const here = _workspace();
        const empty = _emptyWorkspace();
        if (empty > 0 && empty !== here) {
            _returnWorkspace = here;
            _previewWorkspace = empty;
            AxctlService.dispatch("workspace " + empty);
        } else if (here !== _previewWorkspace) {
            _returnWorkspace = -1;   // already on an empty workspace of your own: stay there after
            _previewWorkspace = -1;
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

    // The current workspace if it has no windows, else the lowest-numbered empty one on the
    // same side of positive.special-workspaces' threshold: its Hyprland boundary guard
    // bounces any switch across it straight back (from 51 to 6 lands you on 51 again).
    function _emptyWorkspace() {
        const used = {};
        for (const c of AxctlService.clients.values || [])
            if (c.workspace)
                used[c.workspace.id] = true;
        const current = _workspace();
        if (current > 0 && !used[current])
            return current;
        let n = current > _threshold ? _threshold + 1 : 1;
        while (used[n])
            n++;
        return n;
    }

    property int _threshold: 50   // positive.special-workspaces' default
    FileView {
        path: Quickshell.env("HOME") + "/.config/ambxst/mods/positive.special-workspaces.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const t = parseInt(JSON.parse(text()).threshold);
                if (t > 0)
                    root._threshold = t;
            } catch (e) {}
        }
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

    // ── YouTube wallpaper ──────────────────────────────────────────────
    property string ytQuality: "auto"   // setting: auto (screen height) | best | 2160 | 1440 | 1080 | 720
    property string ytCache: "2"        // setting: YouTube cache size in GB
    property bool ytPause: false        // setting: pause while a window covers the screen
    property var ytPlaylist: []         // [{id, title, channel, duration}]
    property var ytRecent: []
    property bool _shownList: false     // the grid shows a pasted playlist link
    property bool ytPlaying: false
    property bool ytLoading: false   // a video is downloading before it can play
    property string ytVideoId: ""
    // the notch paints this behind its strip, blurred, like Ambxst's media player does with album art
    readonly property string ytThumb: ytVideoId ? "https://i.ytimg.com/vi/" + ytVideoId + "/hqdefault.jpg" : ""
    property string ytTitle: ""
    // the same mute / volume as skwd-wall's video wallpapers (Wallpaper settings)
    readonly property bool ytMuted: GlobalStates.videoWallpaperMuted
    readonly property real ytVolume: GlobalStates.videoWallpaperVolume !== undefined ? GlobalStates.videoWallpaperVolume : 0.5
    property bool ytPaused: false
    property int ytCount: 0
    property string _ytOutput: "ALL"
    readonly property string _ytSocket: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ambxst-kpopping-mpv.sock"
    readonly property string _ytFifo: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ambxst-kpopping-stream"
    readonly property string _ytOptionsFile: Quickshell.env("HOME") + "/.config/ambxst/kpopping-youtube.json"
    // stops the player and the feeder (they ignore SIGTERM while stuck: SIGKILL after)
    readonly property string _ytKill: 'for p in "^mpvpaper .*ambxst-kpopping-mpv.sock" "^python3 .*kpopping_bridge.py yt-player"; do pkill -f "$p"; done; sleep 0.3; for p in "^mpvpaper .*ambxst-kpopping-mpv.sock" "^python3 .*kpopping_bridge.py yt-player"; do pkill -9 -f "$p"; done; '
    readonly property bool _ytLoop: filters.includes("yt:loop")
    readonly property bool _ytShuffle: filters.includes("yt:shuffle")
    readonly property bool _ytAutoplay: filters.includes("yt:autoplay")

    function ytInPlaylist(id) {
        return ytPlaylist.some(e => e.id === id);
    }

    function ytTogglePlaylist(src) {
        const p = bySrc[src];
        if (!p)
            return;
        ytPlaylist = ytInPlaylist(p.id) ? ytPlaylist.filter(e => e.id !== p.id)
            : ytPlaylist.concat([{ id: p.id, title: p.title, channel: p.channel, duration: p.duration }]);
        _ytSave();
        if (ytListView) {
            _shownKey = "";
            _run();
        }
    }

    // ── Up next (Ctrl+click): $XDG_RUNTIME_DIR/ambxst-kpopping-upnext.json, popped by the feeder.
    // The runtime dir survives `ambxst reload` and is emptied by a new session. ──
    property var ytQueue: []   // [{id, title, channel, duration, url}]
    readonly property string _ytUpnextFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ambxst-kpopping-upnext.json"
    function ytQueued(id) {
        return ytQueue.some(e => e.id === id);
    }
    function ytQueueToggle(src, screenName) {
        const p = bySrc[src];
        if (!p)
            return;
        if (ytQueued(p.id)) {
            _ytSetQueue(ytQueue.filter(e => e.id !== p.id));
        } else if (!ytPlaying) {
            ytPlay(src, screenName);   // nothing playing: "play next" means now
            return;
        } else {
            _ytSetQueue(ytQueue.concat([{ id: p.id, title: p.title, channel: p.channel, duration: p.duration, url: "https://www.youtube.com/watch?v=" + p.id }]));
        }
    }
    // ── what the list plays after the current video (Autoplay's Mix / playlist), from the feeder ──
    property var ytComing: []   // [{url, title, channel, coming: true, listIndex}]
    readonly property string _ytComingFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ambxst-kpopping-coming.json"
    readonly property string _ytJumpFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ambxst-kpopping-jump.json"
    FileView {
        path: root._ytComingFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const list = (JSON.parse(text()) || []).map(e => Object.assign({}, e, { coming: true, listIndex: e.i }));
                if (JSON.stringify(list) !== JSON.stringify(root.ytComing)) {
                    root.ytComing = list;
                    if (root.ytQueueView) {
                        root._shownKey = "";
                        root._run();
                    }
                }
            } catch (e) {}
        }
    }
    // An autoplay video picked in Up next: the feeder continues the list from it.
    function ytJump(listIndex) {
        if (!ytPlaying || listIndex === undefined)
            return;
        Quickshell.execDetached(["sh", "-c", 'printf \'{"i": %s}\' "$1" > "$2" && pkill -USR1 -f "^python3 .*kpopping_bridge.py yt-player"',
                                 "sh", String(listIndex), _ytJumpFile]);
    }
    // Up next is one list to reorder: queued videos (always first), then the autoplay ones.
    // Moves a card earlier (-1) / later (+1); returns how far the card moved in the grid (0, ±1).
    function ytQueueMove(src, delta) {
        const p = bySrc[src];
        if (!p)
            return 0;
        if (p.coming) {
            const at = ytComing.findIndex(e => e.listIndex === p.listIndex);
            if (delta < 0 && at === 0) {   // the first autoplay video, moved up: into the queue
                _ytSetQueue(ytQueue.concat([{ id: p.id, title: p.title, channel: p.channel, duration: p.duration, url: "https://www.youtube.com/watch?v=" + p.id }]));
                _ytListCommand({ remove: p.listIndex });   // so it doesn't play twice
                return 0;
            }
            if (delta > 0 && at === ytComing.length - 1)
                return 0;
            _ytListCommand({ move: p.listIndex, delta: delta });
            return delta;
        }
        const from = ytQueue.findIndex(e => e.id === p.id), to = from + delta;
        if (from < 0 || to < 0 || to >= ytQueue.length)
            return 0;   // queued videos stay ahead of the autoplay ones
        const list = ytQueue.slice();
        list.splice(to, 0, list.splice(from, 1)[0]);
        _ytSetQueue(list);
        return delta;
    }
    // Drag and drop in Up next: move a card by `delta` places in the combined list (queued, then
    // autoplay). Queued videos stay ahead of the autoplay ones; an autoplay video dropped among the
    // queued ones becomes a queued video there. Returns how far it actually moved.
    function ytQueueMoveBy(src, delta) {
        const p = bySrc[src];
        if (!p || !delta)
            return 0;
        if (!p.coming) {
            const from = ytQueue.findIndex(e => e.id === p.id);
            const to = Math.max(0, Math.min(ytQueue.length - 1, from + delta));
            if (from < 0 || to === from)
                return 0;
            const list = ytQueue.slice();
            list.splice(to, 0, list.splice(from, 1)[0]);
            _ytSetQueue(list);
            return to - from;
        }
        const at = ytComing.findIndex(e => e.listIndex === p.listIndex);
        if (at < 0)
            return 0;
        if (at + delta < 0) {   // into the queued part
            const queued = ytQueue.length, from = queued + at;   // its place in the combined list
            const to = Math.max(0, from + delta);
            const list = ytQueue.slice();
            list.splice(to, 0, { id: p.id, title: p.title, channel: p.channel, duration: p.duration, url: "https://www.youtube.com/watch?v=" + p.id });
            _ytSetQueue(list);
            _ytListCommand({ remove: p.listIndex });   // so it doesn't play twice
            return to - from;
        }
        const target = Math.min(ytComing.length - 1, at + delta);
        const steps = target - at, dir = steps > 0 ? 1 : -1;
        // the feeder swaps with the neighbour in play order: n swaps carry it n places (follows the card's list index)
        let li = p.listIndex;
        const commands = [];
        for (let k = 0; k < Math.abs(steps); k++) {
            const next = ytComing[at + (k + 1) * dir];
            commands.push({ move: li, delta: dir });
            li = next ? next.listIndex : li;
        }
        _ytListCommand(commands);   // one write, so the swaps reach the feeder in order
        return steps;
    }

    function ytQueueRemove(src) {
        const p = bySrc[src];
        if (!p)
            return;
        if (p.coming)
            _ytListCommand({ remove: p.listIndex });
        else
            _ytSetQueue(ytQueue.filter(e => e.id !== p.id));
    }
    // edits to the feeder's list (Autoplay's Mix / playlist), applied within half a second
    readonly property string _ytCommandsFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ambxst-kpopping-commands.jsonl"
    function _ytListCommand(command) {   // one command, or a list written in one go (kept in order)
        if (!ytPlaying)
            return;
        const lines = (Array.isArray(command) ? command : [command]).map(c => JSON.stringify(c));
        if (lines.length)
            Quickshell.execDetached(["sh", "-c", 'f="$1"; shift; printf "%s\\n" "$@" >> "$f"', "sh", _ytCommandsFile].concat(lines));
    }
    function isDimmed(src) {   // autoplay cards in Up next
        return source === "youtube" && !!(bySrc[src] && bySrc[src].coming);
    }
    function isQueueViewCard(src) {
        return source === "youtube" && ytQueueView && !!bySrc[src];
    }

    function _ytSetQueue(list) {
        ytQueue = list;
        upnextFile.setText(JSON.stringify(list));
        if (ytQueueView) {
            _shownKey = "";
            _run();
        }
    }
    FileView {
        id: upnextFile
        path: root._ytUpnextFile
        watchChanges: true   // the feeder takes videos off the front
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const list = JSON.parse(text()) || [];
                if (JSON.stringify(list) !== JSON.stringify(root.ytQueue)) {
                    root.ytQueue = list;
                    if (root.ytQueueView) {
                        root._shownKey = "";
                        root._run();
                    }
                }
            } catch (e) {}
        }
    }

    // ▶ Play My playlist: just your playlist, in order (or shuffled)
    function ytPlayAll() {
        if (!ytPlaylist.length)
            return;
        const queue = ytPlaylist.map(e => ({ url: "https://www.youtube.com/watch?v=" + e.id, title: e.title, channel: e.channel }));
        _ytLaunch(queue, _ytShuffle ? Math.floor(Math.random() * queue.length) : 0, false, _ytLastScreen, queue[0].title);
    }

    function _ytShowList(entries) {
        const list = entries.map(e => {
            const id = e.id || ((e.url || "").match(/v=([\w-]{11})/) || [])[1] || "";
            // autoplay entries get their own src, so a video both queued and coming up stays two cards
            return { src: "https://www.youtube.com/watch?v=" + id + (e.coming ? "#autoplay" + e.listIndex : ""), id: id,
                     title: e.title, channel: e.channel, duration: e.duration, coming: !!e.coming, listIndex: e.listIndex,
                     thumb: "https://i.ytimg.com/vi/" + id + "/mqdefault.jpg" };
        });
        const t = {};
        for (const p of list)
            t[p.src] = p.thumb;
        thumbs = t;
        photos = list;
        _shownList = true;
        hasMore = false;
        error = "";
        searching = false;
        shownQuery = _query;
        _shownKey = _key;
        _shownPages = pages;
    }

    // Play the clicked video. In My playlist or a pasted playlist: the whole list from there.
    // A search result: that video, or with Autoplay, YouTube's Mix of related videos after it.
    function ytPlay(src, screenName) {
        const p = bySrc[src];
        if (!p)
            return;
        let queue, start = 0, mix = false;
        if (ytQueueView) {   // Up next: play this one now, the rest stays queued
            _ytSetQueue(ytQueue.filter(e => e.id !== p.id));
            queue = [{ url: src, title: p.title, channel: p.channel }];
        } else if (_shownList) {
            queue = photos.map(x => ({ url: x.src, title: x.title, channel: x.channel }));
            start = Math.max(0, photos.findIndex(x => x.src === src));
        } else {
            mix = _ytAutoplay;
            queue = [{ url: src, title: p.title, channel: p.channel, mix: "https://www.youtube.com/watch?v=" + p.id + "&list=RD" + p.id }];
        }
        _ytLaunch(queue, start, mix, screenName, p.title);
    }

    property string _ytLastScreen: ""
    function _ytLaunch(queue, start, mix, screenName, title, extra) {
        ytResume = null;
        _ytLastScreen = screenName || "";
        const fmt = _ytFormat(screenName);
        // auto-safe: decoders that can draw directly (no copying frames between GPUs);
        // display-resample + interpolation: even motion for 60 fps video on a 144 Hz screen
        // keep-open (no pause): the last frame stays up while the feeder loads the next file;
        // load-scripts=no: no second MPRIS player from an mpv plugin (the feeder is one)
        const opts = ["hwdec=auto-safe", "video-sync=display-resample", "interpolation", "tscale=oversample", "no-osc", "panscan=1.0",
                      "keep-open=yes", "keep-open-pause=no", "load-scripts=no",
                      "input-ipc-server=" + _ytSocket, "ytdl=no", "idle=yes",
                      "mute=" + (ytMuted ? "yes" : "no"), "volume=" + Math.round(Math.max(0, Math.min(1, ytVolume)) * 100)].join(" ");
        const job = JSON.stringify(Object.assign({ fifo: _ytFifo, format: fmt, options: _ytOptionsFile, upnext: _ytUpnextFile,
                                                   state: _ytStateFile, coming: _ytComingFile, jump: _ytJumpFile, commands: _ytCommandsFile,
                                                   output: screenName || "", start: start, mix: mix, queue: queue,
                                                   mpv_opts: opts, cache_gb: parseFloat(ytCache) || 2 }, extra || {}));
        _ytOutput = screenName || "ALL";
        _ytStopping = false;
        _ytStarting = true;   // the wallpaper-change watcher below must not stop the new video
        _ytBase = "";
        ytTitle = title;
        ytLoading = true;
        // replace a running player; the feeder starts mpvpaper once the first video is ready.
        // setsid: both keep running across shell reloads
        ytLauncher.command = ["sh", "-c", _ytKill
            + 'mkdir -p "$(dirname "$1")"; printf "%s" "$2" > "$1"; '
            + 'setsid -f python3 "$3" yt-player "$1" >/dev/null 2>&1',
            "sh", cacheDir + "yt-queue.json", job, bridge];
        ytLauncher.running = true;
        Visibilities.setActiveModule("");
    }

    // yt-dlp format: at most the screen's height (auto) or the cap, preferring VP9 then H.264 over
    // AV1 at that size. Many GPUs (AMD Renoir included) decode VP9/H.264 but not AV1, and a 4K
    // AV1 stream on a 1080p screen decodes 4x the pixels on the CPU only to throw them away.
    function _ytFormat(screenName) {
        let cap = 0;
        if (ytQuality === "auto") {
            for (const m of AxctlService.monitors.values || [])
                if (!screenName || m.name === screenName)
                    cap = Math.max(cap, Math.min(m.width || 0, m.height || 0));
        } else if (ytQuality !== "best") {
            cap = parseInt(ytQuality) || 0;
        }
        const h = cap > 0 ? "[height<=?" + cap + "]" : "";
        return ["bestvideo" + h + "[vcodec^=vp09]+bestaudio", "bestvideo" + h + "[vcodec^=avc1]+bestaudio",
                "bestvideo" + h + "+bestaudio", "best" + h, "best"].join("/");
    }

    // Stop hides the video: the feeder saves video, position and list (SIGHUP), then the player
    // closes; ⏵ Resume continues there. Kept in $XDG_RUNTIME_DIR: survives `ambxst reload`, a new session forgets it.
    function ytStop() {
        _ytStopping = true;
        ytLoading = false;
        Quickshell.execDetached(["pkill", "-HUP", "-f", "^python3 .*kpopping_bridge.py yt-player"]);
        ytStopCleanup.restart();
    }
    Timer {
        id: ytStopCleanup
        interval: 1500   // whatever didn't close by itself (an older or stuck feeder)
        onTriggered: {
            Quickshell.execDetached(["sh", "-c", root._ytKill + 'rm -f "$1"', "sh", root._ytFifo]);
            ytStateFile.reload();   // the hide's saved state, even if the watcher never connected
        }
    }

    property var ytResume: null   // {queue, i, from_list, item, seek, output}
    readonly property string _ytStateFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ambxst-kpopping-state.json"

    function ytResumePlay() {
        const st = ytResume;
        if (!st || !st.queue)
            return;
        _ytLaunch(st.queue, st.i || 0, false, st.output || "", st.item.title,
                  { first_item: st.from_list ? null : st.item, from_list: !!st.from_list, seek: st.seek || 0, topup: !!st.topup });
    }

    FileView {
        id: ytStateFile
        path: root._ytStateFile
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (d.hidden && !root.ytPlaying)
                    root.ytResume = d;
            } catch (e) {}
        }
    }
    function ytToggleMute() {
        GlobalStates.setVideoWallpaperMuted(!GlobalStates.videoWallpaperMuted);
    }
    function ytNext() {
        Quickshell.execDetached(["pkill", "-USR1", "-f", "^python3 .*kpopping_bridge.py yt-player"]);
    }
    function ytPrevious() {
        Quickshell.execDetached(["pkill", "-USR2", "-f", "^python3 .*kpopping_bridge.py yt-player"]);
    }
    function ytSeek(seconds) {
        _ytCommand(["seek", seconds, "relative+exact"]);
    }
    function ytTogglePause() {
        _ytAutoPaused = false;   // your choice now; the covered-screen rule won't undo it
        _ytCommand(["cycle", "pause"]);
    }
    onYtMutedChanged: if (ytPlaying) _ytCommand(["set_property", "mute", ytMuted])
    onYtVolumeChanged: if (ytPlaying) _ytCommand(["set_property", "volume", Math.round(Math.max(0, Math.min(1, ytVolume)) * 100)])
    function _ytCommand(command) {
        Quickshell.execDetached(["python3", bridge, "mpv", JSON.stringify(command)]);
    }

    // Loop / Shuffle chips also change the video that's playing.
    property string _ytOptionsSaved: ""
    function _ytOptionsChanged() {
        const now = [_ytLoop, _ytShuffle, _ytAutoplay].join();
        if (now === _ytOptionsSaved)
            return;
        _ytOptionsSaved = now;
        if (ytLoaded)
            _ytSave();   // the feeder re-reads Loop / Shuffle from it before every video
    }

    Process {
        id: ytLauncher
        onExited: watchRestart.restart()
    }
    Timer {
        id: watchRestart
        interval: 400
        onTriggered: {
            ytWatch.running = false;
            ytWatch.running = true;
        }
    }
    // Follows the player (also one that survived a reload): title, mute, pause; ends when it quits.
    Process {
        id: ytWatch
        command: ["python3", root.bridge, "mpv-watch"]
        stdout: SplitParser {
            onRead: line => {
                let d;
                try {
                    d = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (!root.ytPlaying)
                    root._ytBase = root._current(root._ytOutput === "ALL" ? "" : root._ytOutput);
                root.ytPlaying = true;
                root._ytStarting = false;
                if (d.prop !== "user-data/kpopping/loading")
                    root.ytLoading = false;
                if (d.prop === "media-title" && d.value)
                    root.ytTitle = d.value;
                else if (d.prop === "pause")
                    root.ytPaused = !!d.value;
                else if (d.prop === "user-data/kpopping/count")
                    root.ytCount = d.value || 0;
                else if (d.prop === "user-data/kpopping/loading")
                    root.ytLoading = !!d.value;
                else if (d.prop === "user-data/kpopping/id")
                    root.ytVideoId = d.value || "";
            }
        }
        onExited: {
            root.ytPlaying = false;
            root.ytLoading = false;
            root.ytPaused = false;
            ytStateFile.reload();
        }
    }

    // Choosing any other wallpaper (picker, kpopping preview, rotation) stops the video. Compared
    // with the wallpaper current when it started: right after a reload, currentWallpaper still
    // follows the startup scan, which isn't a choice.
    property bool _ytStarting: false
    property bool _ytStopping: false
    property string _ytBase: ""
    function _ytWallChanged() {
        if (!ytPlaying || _ytStopping)
            return;
        const now = _current(_ytOutput === "ALL" ? "" : _ytOutput);
        if (_ytStarting || !_ytBase) {
            _ytBase = now;
            return;
        }
        if (now && now !== _ytBase)
            ytStop();
    }
    Connections {
        target: GlobalStates.wallpaperManager
        function onCurrentWallpaperChanged() {
            root._ytWallChanged();
        }
        function onPerScreenWallpapersChanged() {
            root._ytWallChanged();
        }
    }

    // Setting "pause while covered": the same rule skwd-wall uses for video wallpapers.
    readonly property bool ytWantPause: ytPause && ytPlaying && (GameModeClient.toggled
        || (_ytOutput === "ALL" ? (AxctlService.monitors.values || []).some(m => SkwdWall.coveredScreen(m.name)) : SkwdWall.coveredScreen(_ytOutput)))
    // only undo a pause this rule made, never one you made (notch ⏯ / media keys)
    property bool _ytAutoPaused: false
    onYtWantPauseChanged: {
        if (ytWantPause && !ytPaused) {
            _ytAutoPaused = true;
            _ytCommand(["set_property", "pause", true]);
        } else if (!ytWantPause && _ytAutoPaused) {
            _ytAutoPaused = false;
            _ytCommand(["set_property", "pause", false]);
        }
    }

    // ~/.config/ambxst/kpopping-youtube.json: My playlist, chip states, mute, recent searches
    property bool ytLoaded: false
    function _ytSave() {
        ytFile.setText(JSON.stringify({ playlist: ytPlaylist, recent: ytRecent,
                                        loop: _ytLoop, shuffle: _ytShuffle, autoplay: _ytAutoplay }, null, 2) + "\n");
    }
    FileView {
        id: ytFile
        path: root._ytOptionsFile
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.ytPlaylist = d.playlist || [];
                root.ytRecent = d.recent || [];
                const chips = (d.loop ? ["yt:loop"] : []).concat(d.shuffle ? ["yt:shuffle"] : [], d.autoplay !== false ? ["yt:autoplay"] : []);
                root.filters = root.filters.filter(f => !["yt:loop", "yt:shuffle", "yt:autoplay"].includes(f)).concat(chips);
            } catch (e) {}
            root.ytLoaded = true;
        }
        onLoadFailed: {
            root.filters = root.filters.concat(["yt:autoplay"]);   // first run: Autoplay on
            root.ytLoaded = true;
        }
    }

    // ── wallpaper grid layout (mod settings "gridLayout" / "ytLayout" / "cardSize") ───
    property string gridLayout: "classic"   // pictures: classic (Ambxst's squares) | fit (rows) | masonry (Pinterest)
    property string ytLayout: "squares"     // YouTube: squares | tiles (16:9 grid) | list (like YouTube search)
    property string cardSize: "compact"     // compact (Ambxst's 7 a row) | comfortable | large
    property string ytCardSize: "same"      // YouTube's own: same (as cardSize) | compact | comfortable | large
    readonly property string _ytSize: ytCardSize === "same" ? cardSize : ytCardSize
    readonly property bool _yt: active && source === "youtube"
    readonly property bool ytTiles: _yt && ytLayout === "tiles"
    readonly property bool ytList: _yt && ytLayout === "list"
    readonly property bool collage: gridLayout === "fit" && !_yt        // justified rows
    readonly property bool masonry: gridLayout === "masonry" && !_yt    // Pinterest-style columns
    readonly property int gridColumns: ytList ? ({ compact: 3, comfortable: 2, large: 1 })[_ytSize] || 3
        : ytTiles ? ({ compact: 5, comfortable: 4, large: 3 })[_ytSize] || 5
        : ({ compact: 7, comfortable: 5, large: 4 })[_yt ? _ytSize : cardSize] || 7
    // height of a YouTube list row's thumbnail (16:9)
    readonly property int ytListThumbHeight: ({ compact: 72, comfortable: 96, large: 132 })[_ytSize] || 72
    // Ambxst's own thumbnails are 140 px squares: fine for compact squares, too small or the wrong
    // shape otherwise, so the mod makes 480 px shape-keeping ones for the local library
    readonly property bool wantLocalThumbs: collage || masonry || cardSize !== "compact"

    // Width / height of a grid item, for the collage (kpopping photos know theirs; local wallpapers
    // once their thumbnails exist; anything else 16:9).
    function aspect(src) {
        const p = active ? bySrc[src] : null;
        if (p && p.width && p.height)
            return p.width / p.height;
        const t = localThumbs[src];
        return t && t.w && t.h ? t.w / t.h : 16 / 9;
    }
    function localThumb(path) {
        const t = wantLocalThumbs ? localThumbs[path] : null;
        return t ? t.thumb : "";
    }

    property var localThumbs: ({})   // path -> {w, h, thumb}
    property string localThumbsProgress: ""   // "1200/5857" while thumbnails are being made
    property var _ltPending: ({})
    readonly property string _ltList: cacheDir + "local-thumbs.txt"
    function _localThumbsRun() {
        const wm = GlobalStates.wallpaperManager;
        if (!wantLocalThumbs || !wm || !wm.wallpaperPaths.length)
            return;
        if (localThumbsProc.running) {
            _ltAgain = true;
            return;
        }
        localThumbsProc.command = ["sh", "-c", 'f="$1"; b="$2"; shift 2; mkdir -p "$(dirname "$f")"; printf "%s\\n" "$@" > "$f"; exec python3 "$b" local-thumbs "$f"',
                                   "sh", _ltList, bridge].concat(wm.wallpaperPaths);
        localThumbsProc.running = true;
    }
    property bool _ltAgain: false
    onWantLocalThumbsChanged: _localThumbsRun()
    Connections {
        target: GlobalStates.wallpaperManager
        function onWallpaperPathsChanged() {
            ltDebounce.restart();
        }
    }
    Timer {
        id: ltDebounce
        interval: 3000   // the scan updates the list in bursts
        onTriggered: root._localThumbsRun()
    }
    Process {
        id: localThumbsProc
        stdout: SplitParser {
            onRead: line => {
                let d;
                try {
                    d = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (d.path !== undefined) {
                    root._ltPending[d.path] = { w: d.w, h: d.h, thumb: d.thumb };
                } else if (d.progress !== undefined) {
                    root.localThumbsProgress = d.progress < d.total ? d.progress + "/" + d.total : "";
                    root._ltFlush();
                } else if (d.done) {
                    root.localThumbsProgress = "";
                    root._ltFlush();
                }
            }
        }
        onExited: {
            root._ltFlush();
            if (root._ltAgain) {
                root._ltAgain = false;
                root._localThumbsRun();
            }
        }
    }
    // hand thumbnails to the grid in batches, not one binding storm per file
    function _ltFlush() {
        const keys = Object.keys(_ltPending);
        if (!keys.length)
            return;
        localThumbs = Object.assign({}, localThumbs, _ltPending);
        _ltPending = {};
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
        if (key === "fitMode" || key === "fitBackground" || key === "ytQuality" || key === "ytCache" || key === "gridLayout" || key === "cardSize" || key === "ytLayout" || key === "ytCardSize")
            root[key] = String(value);
        else if (key === "ytPause")
            root.ytPause = value === true || value === "true";
    }

    Component.onCompleted: {
        ModsService.getSettings(modId, (result, error) => {
            const values = result && result.values ? result.values : {};
            for (const key in values)
                _setting(key, values[key]);
        });
        ytWatch.running = true;   // pick up a YouTube wallpaper still playing from before a reload
        ltDebounce.restart();     // thumbnails for big cards / the collage, if those are on
    }

    Connections {
        target: ModsService
        function onSettingChanged(id, key, value) {
            if (id !== root.modId)
                return;
            root._setting(key, value);
            if (key !== "fitMode" && key !== "fitBackground")
                return;
            // show the new fit right away: have skwd-wall apply the current wallpaper again
            SkwdWall.applied = ({});
            SkwdWall.sync();
        }
    }
}
