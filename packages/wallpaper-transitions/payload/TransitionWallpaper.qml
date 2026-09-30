import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.services
import qs.modules.theme
import qs.config
import qs.modules.bar.workspaces // For CompositorData

Item {
    id: root

    property var wallpaperManager: null
    property string source: ""
    property string previousSource: ""
    property string activeSource: ""
    property string pendingSource: ""
    property int activeSlot: 0 // 0: slot0 is active, 1: slot1 is active
    property bool isTransitioning: false

    // Mod settings - reactive to GlobalStates
    readonly property string transitionStyle: (GlobalStates && GlobalStates.wallpaperTransitionStyle) ? GlobalStates.wallpaperTransitionStyle : "crossfade"
    readonly property int duration: (GlobalStates && GlobalStates.wallpaperTransitionDuration !== undefined) ? GlobalStates.wallpaperTransitionDuration : 400
    readonly property string easingCurve: (GlobalStates && GlobalStates.wallpaperTransitionEasing) ? GlobalStates.wallpaperTransitionEasing : "cubic"
    readonly property string pauseMode: (GlobalStates && GlobalStates.wallpaperPauseMode) ? GlobalStates.wallpaperPauseMode : "fullscreen"
    readonly property string pauseScope: (GlobalStates && GlobalStates.wallpaperPauseScope) ? GlobalStates.wallpaperPauseScope : "perScreen"

    readonly property string modId: "positive.wallpaper-transitions"
    readonly property bool tintEnabled: wallpaperManager ? wallpaperManager.tintEnabled : false
    readonly property string currentScreenName: {
        if (wallpaperManager && wallpaperManager.screen && wallpaperManager.screen.name) {
            return wallpaperManager.screen.name;
        }
        if (wallpaperManager && wallpaperManager.currentScreenName) {
            return wallpaperManager.currentScreenName;
        }
        return "";
    }
    readonly property var compositorMonitor: {
        let mon = AxctlService.monitorFor(currentScreenName);
        if (mon) return mon;
        let vals = AxctlService.monitors ? AxctlService.monitors.values : null;
        if (vals && vals.length === 1) return vals[0];
        return AxctlService.focusedMonitor;
    }

    property bool isMonitorFullscreen: false
    property bool isMonitorCovered: false

    // Confirmed pause state — only flips true after pauseConfirmTimer fires.
    // Clears immediately when the condition is no longer met.
    property bool _pauseConfirmed: false

    function updateWindowState() {
        if (pauseMode === "never") {
            isMonitorFullscreen = false;
            isMonitorCovered = false;
            pauseConfirmTimer.stop();
            _pauseConfirmed = false;
            return;
        }

        const isPerScreen = (pauseScope === "perScreen");

        if (isPerScreen && !compositorMonitor) {
            isMonitorFullscreen = false;
            isMonitorCovered = false;
            pauseConfirmTimer.stop();
            _pauseConfirmed = false;
            return;
        }

        const monId = compositorMonitor ? compositorMonitor.id : -1;
        const activeWorkspaceId = compositorMonitor && compositorMonitor.activeWorkspace ? compositorMonitor.activeWorkspace.id : 0;

        let fs = false;
        let covered = false;

        if (isPerScreen) {
            // Rely exclusively on Hyprland's CompositorData window list for this monitor.
            // (ToplevelManager.activeToplevel.fullscreen is unreliable in Hyprland — it fires
            //  on shell focus changes and layer-shell windows, causing false positives.)
            const wins = CompositorData.windowList || [];
            for (let i = 0; i < wins.length; i++) {
                const w = wins[i];
                // Skip hidden windows and Hyprland special workspaces (id < 0)
                if (w.monitor === monId && w.workspace && w.workspace.id >= 0 && w.workspace.id === activeWorkspaceId && !w.hidden) {
                    if (w.fullscreen) {
                        fs = true;
                        covered = true;
                        break;
                    }
                    if (!w.floating) {
                        covered = true;
                    } else if (w.size && compositorMonitor && compositorMonitor.width > 0 && compositorMonitor.height > 0) {
                        const winArea = w.size[0] * w.size[1];
                        const screenArea = compositorMonitor.width * compositorMonitor.height;
                        if (winArea >= (screenArea * 0.9)) {
                            covered = true;
                        }
                    }
                }
            }
        } else {
            // Global scope ("allScreens"): pause if ANY normal workspace has a fullscreen/covered window.
            // Skip Hyprland special workspaces (id < 0) to avoid false positives from shell overlays.
            const wins = CompositorData.windowList || [];
            for (let i = 0; i < wins.length; i++) {
                const w = wins[i];
                if (!w.hidden && w.workspace && w.workspace.id >= 0) {
                    if (w.fullscreen) {
                        fs = true;
                        covered = true;
                        break;
                    }
                    if (!w.floating) {
                        covered = true;
                    }
                }
            }
        }

        isMonitorFullscreen = fs;
        isMonitorCovered = covered;
    }

    // Raw computed pause intent — true when window state says we should pause.
    readonly property bool _pauseIntent: {
        if (pauseMode === "never") return false;
        if (pauseMode === "covered") return isMonitorFullscreen || isMonitorCovered;
        return isMonitorFullscreen; // "fullscreen" (default)
    }

    // Delayed-confirm timer: only pause after state has been stable for 800ms.
    // This absorbs transient fullscreen signals from window manager events,
    // workspace switches, and Ambxst shell layer-shell focus changes.
    Timer {
        id: pauseConfirmTimer
        interval: 800
        repeat: false
        onTriggered: {
            if (root._pauseIntent) root._pauseConfirmed = true;
        }
    }

    // React to intent changes: arm confirm timer when we want to pause,
    // but clear immediately when the condition lifts so resume is instant.
    // (Property _pauseIntent emits signal _pauseIntentChanged → handler on_PauseIntentChanged)
    on_PauseIntentChanged: {
        if (_pauseIntent) {
            if (!pauseConfirmTimer.running) pauseConfirmTimer.restart();
        } else {
            pauseConfirmTimer.stop();
            _pauseConfirmed = false;
        }
    }

    readonly property bool shouldPauseLiveWallpaper: {
        if (isTransitioning || pendingSource !== "") return false;
        return _pauseConfirmed;
    }

    Timer {
        id: windowStateDebounce
        interval: 50
        repeat: false
        onTriggered: root.updateWindowState()
    }

    Connections {
        target: CompositorData
        function onWindowListChanged() { windowStateDebounce.restart(); }
    }

    Connections {
        target: AxctlService.monitors
        function onValuesChanged() { windowStateDebounce.restart(); }
    }

    Connections {
        target: AxctlService
        function onFocusedMonitorChanged() { windowStateDebounce.restart(); }
        function onFocusedClientChanged() { windowStateDebounce.restart(); }
        function onFocusedWorkspaceChanged() { windowStateDebounce.restart(); }
    }

    onPauseModeChanged: { pauseConfirmTimer.stop(); _pauseConfirmed = false; updateWindowState(); }
    onPauseScopeChanged: { pauseConfirmTimer.stop(); _pauseConfirmed = false; updateWindowState(); }
    Component.onCompleted: updateWindowState()

    clip: true

    // Optimized palette (identical to Ambxst stock)
    readonly property var optimizedPalette: [
        "background", "overBackground", "shadow", "surface", "surfaceBright",
        "surfaceDim", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest",
        "surfaceContainerLow", "surfaceContainerLowest", "primary", "secondary",
        "tertiary", "red", "lightRed", "green", "lightGreen", "blue", "lightBlue",
        "yellow", "lightYellow", "cyan", "lightCyan", "magenta", "lightMagenta"
    ]

    function getFileType(path) {
        if (!path) return "unknown";
        var clean = path.replace(/^file:\/\//, "");
        var ext = clean.toLowerCase().split('.').pop();
        if (['jpg', 'jpeg', 'png', 'webp', 'tif', 'tiff', 'bmp'].includes(ext)) {
            return 'image';
        } else if (['gif'].includes(ext)) {
            return 'gif';
        } else if (['mp4', 'webm', 'mov', 'avi', 'mkv'].includes(ext)) {
            return 'video';
        }
        return 'unknown';
    }

    function notifyShown() {
        try {
            if (typeof ShellTransitions !== "undefined" && ShellTransitions.wallpaperShown) {
                ShellTransitions.wallpaperShown(currentScreenName);
            }
        } catch (e) {}
    }

    function getEasingType() {
        switch (easingCurve) {
            case "inOut":
            case "inOutCubic": return Easing.InOutCubic;
            case "expo": return Easing.OutExpo;
            case "back": return Easing.OutBack;
            case "quad": return Easing.OutQuad;
            case "sine": return Easing.OutSine;
            case "linear": return Easing.Linear;
            case "cubic":
            default: return Easing.OutCubic;
        }
    }

    // Palette texture source for shader tinting
    Item {
        id: paletteSourceItem
        visible: true
        width: root.optimizedPalette.length
        height: 1
        opacity: 0

        Row {
            anchors.fill: parent
            Repeater {
                model: root.optimizedPalette
                Rectangle {
                    width: 1
                    height: 1
                    color: (Colors && Colors[modelData]) ? Colors[modelData] : "transparent"
                }
            }
        }
    }

    ShaderEffectSource {
        id: paletteTextureSource
        sourceItem: paletteSourceItem
        hideSource: true
        visible: false
        smooth: false
        recursive: false
    }

    // Circle Mask Engine (Iris Transitions)
    readonly property real maxCircleRadius: Math.ceil(Math.hypot(root.width > 0 ? root.width : 1920, root.height > 0 ? root.height : 1080) / 2) + 50
    property real circleRadius: 0
    property bool circleMaskInverted: false
    property int activeCircleSlot: -1

    Item {
        id: circleMaskItem
        width: root.width > 0 ? root.width : 1920
        height: root.height > 0 ? root.height : 1080
        visible: true
        opacity: 0
        z: -100
        clip: true

        Rectangle {
            id: circleShape
            width: root.circleRadius * 2
            height: root.circleRadius * 2
            radius: root.circleRadius
            anchors.centerIn: parent
            color: "white"
        }
    }

    ShaderEffectSource {
        id: circleMaskSource
        sourceItem: circleMaskItem
        live: root.isTransitioning && (root.transitionStyle === "circleOut" || root.transitionStyle === "circleIn")
        hideSource: true
        visible: false
    }

    // Container for all layers, which can be blurred on Niri overview
    Item {
        id: layersContainer
        anchors.fill: parent

        // Unified Multimedia Layer Component (Image, Animated GIF, Live Video)
        component WallpaperLayer: Item {
            id: layerRoot
            width: root.width
            height: root.height
            property string imageSource: ""
            readonly property string mediaType: root.getFileType(imageSource)
            property var activeVideoRef: null
            property bool videoFrameReady: false

            readonly property bool isReady: {
                if (!imageSource) return false;
                if (mediaType === "image") {
                    return rawImg.status === Image.Ready;
                } else if (mediaType === "gif") {
                    return animImgLoader.item ? animImgLoader.item.status === Image.Ready : false;
                } else if (mediaType === "video") {
                    return videoFrameReady || (videoCompLoader.item ? (videoCompLoader.item.hasFirstFrame || videoCompLoader.item.positionMs > 0) : false);
                }
                return false;
            }

            readonly property bool isError: {
                if (!imageSource) return false;
                if (mediaType === "image") {
                    return rawImg.status === Image.Error;
                } else if (mediaType === "gif") {
                    return animImgLoader.item ? animImgLoader.item.status === Image.Error : false;
                }
                return false;
            }

            onImageSourceChanged: {
                videoFrameReady = false;
                if (imageSource === "") {
                    activeVideoRef = null;
                }
            }

            function notifyIfReady() {
                if (layerRoot.imageSource !== "") {
                    if (layerRoot.isReady) {
                        root.onSlotImageReady(layerRoot);
                    } else if (layerRoot.isError) {
                        root.onSlotImageError(layerRoot);
                    }
                }
            }

            Timer {
                id: videoFallbackTimer
                interval: 2500
                repeat: false
                running: layerRoot.mediaType === "video" && layerRoot.imageSource !== "" && !layerRoot.videoFrameReady
                onTriggered: {
                    if (!layerRoot.videoFrameReady) {
                        console.warn("TransitionWallpaper: Video first-frame timeout (2500ms), starting transition:", layerRoot.imageSource);
                        layerRoot.videoFrameReady = true;
                        layerRoot.notifyIfReady();
                    }
                }
            }

            // Static Image Renderer
            Image {
                id: rawImg
                anchors.fill: parent
                visible: layerRoot.mediaType === "image"
                source: {
                    if (!layerRoot.imageSource || layerRoot.mediaType !== "image") return "";
                    return layerRoot.imageSource.startsWith("file://") ? layerRoot.imageSource : ("file://" + layerRoot.imageSource);
                }
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                mipmap: true
                sourceSize.width: (root.wallpaperManager && root.wallpaperManager.width > 0) ? root.wallpaperManager.width : (root.width > 0 ? root.width : undefined)
                sourceSize.height: (root.wallpaperManager && root.wallpaperManager.height > 0) ? root.wallpaperManager.height : (root.height > 0 ? root.height : undefined)
                layer.enabled: root.tintEnabled && visible
                layer.effect: ShaderEffect {
                    property var paletteTexture: paletteTextureSource
                    property real paletteSize: root.optimizedPalette.length
                    property real texWidth: rawImg.width
                    property real texHeight: rawImg.height

                    vertexShader: "palette.vert.qsb"
                    fragmentShader: "palette.frag.qsb"
                }

                onStatusChanged: {
                    if (layerRoot.mediaType === "image") {
                        layerRoot.notifyIfReady();
                    }
                }
            }

            // Animated GIF Renderer (Native QtQuick AnimatedImage)
            Loader {
                id: animImgLoader
                anchors.fill: parent
                active: layerRoot.mediaType === "gif" && layerRoot.imageSource !== ""
                sourceComponent: Component {
                    AnimatedImage {
                        id: animImg
                        anchors.fill: parent
                        paused: root.shouldPauseLiveWallpaper
                        source: {
                            if (!layerRoot.imageSource) return "";
                            return layerRoot.imageSource.startsWith("file://") ? layerRoot.imageSource : ("file://" + layerRoot.imageSource);
                        }
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        mipmap: true
                        sourceSize.width: (root.wallpaperManager && root.wallpaperManager.width > 0) ? root.wallpaperManager.width : (root.width > 0 ? root.width : undefined)
                        sourceSize.height: (root.wallpaperManager && root.wallpaperManager.height > 0) ? root.wallpaperManager.height : (root.height > 0 ? root.height : undefined)
                        layer.enabled: root.tintEnabled
                        layer.effect: ShaderEffect {
                            property var paletteTexture: paletteTextureSource
                            property real paletteSize: root.optimizedPalette.length
                            property real texWidth: animImg.width
                            property real texHeight: animImg.height

                            vertexShader: "palette.vert.qsb"
                            fragmentShader: "palette.frag.qsb"
                        }

                        onStatusChanged: {
                            if (layerRoot.mediaType === "gif") {
                                layerRoot.notifyIfReady();
                            }
                        }
                    }
                }
            }

            // Live Video Wallpaper Renderer (QtMultimedia VideoWallpaper)
            Loader {
                id: videoCompLoader
                anchors.fill: parent
                active: layerRoot.mediaType === "video" && layerRoot.imageSource !== ""
                sourceComponent: Component {
                    VideoWallpaper {
                        id: videoWallpaperChild
                        sourceFile: layerRoot.imageSource.replace(/^file:\/\//, "")
                        tint: root.tintEnabled
                        paused: root.shouldPauseLiveWallpaper
                        onRequestVideoSync: {
                            if (root.wallpaperManager && root.wallpaperManager.requestVideoSync)
                                root.wallpaperManager.requestVideoSync();
                        }
                        onFirstFrameReady: {
                            if (!layerRoot.videoFrameReady) {
                                layerRoot.videoFrameReady = true;
                                layerRoot.notifyIfReady();
                            }
                        }
                        onPositionMsChanged: {
                            if (positionMs > 0 && !layerRoot.videoFrameReady) {
                                layerRoot.videoFrameReady = true;
                                layerRoot.notifyIfReady();
                            }
                        }
                        Component.onCompleted: {
                            layerRoot.activeVideoRef = videoWallpaperChild;
                            if (videoWallpaperChild.hasFirstFrame && !layerRoot.videoFrameReady) {
                                layerRoot.videoFrameReady = true;
                                layerRoot.notifyIfReady();
                            }
                        }
                        Component.onDestruction: {
                            if (layerRoot.activeVideoRef === videoWallpaperChild)
                                layerRoot.activeVideoRef = null;
                        }
                    }
                }
            }
        }

        WallpaperLayer {
            id: slot0
            z: root.activeSlot === 0 ? 1 : 0
            opacity: 1.0
            x: 0
            y: 0
            scale: 1.0
            layer.enabled: root.isTransitioning && (root.transitionStyle === "circleOut" || root.transitionStyle === "circleIn") && root.activeCircleSlot === 0
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: circleMaskSource
                maskInverted: root.circleMaskInverted
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        }

        WallpaperLayer {
            id: slot1
            z: root.activeSlot === 1 ? 1 : 0
            opacity: 0.0
            x: 0
            y: 0
            scale: 1.0
            layer.enabled: root.isTransitioning && (root.transitionStyle === "circleOut" || root.transitionStyle === "circleIn") && root.activeCircleSlot === 1
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: circleMaskSource
                maskInverted: root.circleMaskInverted
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        }
    }

    // Automatically synchronize the active playing VideoWallpaper with WallpaperManager for lockscreen sync
    Binding {
        target: root.wallpaperManager
        property: "activeVideo"
        value: root.activeSlot === 0 ? slot0.activeVideoRef : slot1.activeVideoRef
        when: root.wallpaperManager !== null
    }

    // Niri native overview blur pass (Ambxst 1.3.6+)
    Loader {
        anchors.fill: parent
        active: root.wallpaperManager ? root.wallpaperManager.overviewBlurPossible : (AxctlService.compositorName === "niri")
        sourceComponent: Component {
            MultiEffect {
                anchors.fill: parent
                source: layersContainer
                autoPaddingEnabled: false
                blurEnabled: (root.wallpaperManager && root.wallpaperManager.overviewBlurActive) || blur > 0
                blurMax: 64
                blur: (root.wallpaperManager && root.wallpaperManager.overviewBlurActive) ? 1.0 : 0.0
                visible: true

                Behavior on blur {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    function onSlotImageReady(slot) {
        var targetSlot = activeSlot === 0 ? slot1 : slot0;
        if (slot === targetSlot && pendingSource !== "" && !isTransitioning) {
            readyCheckTimer.stop();
            stallTimeout.stop();
            startAnimation();
        }
    }

    function onSlotImageError(slot) {
        var targetSlot = activeSlot === 0 ? slot1 : slot0;
        if (slot === targetSlot && pendingSource !== "") {
            readyCheckTimer.stop();
            stallTimeout.stop();
            console.warn("TransitionWallpaper: Error loading media:", pendingSource);
            finishTransition();
        }
    }

    // Transition watchdog timer to wait for media readiness before triggering animation
    Timer {
        id: readyCheckTimer
        interval: 16
        repeat: true
        onTriggered: {
            var targetSlot = root.activeSlot === 0 ? slot1 : slot0;
            if (targetSlot.isReady) {
                readyCheckTimer.stop();
                stallTimeout.stop();
                root.startAnimation();
            } else if (targetSlot.isError) {
                readyCheckTimer.stop();
                stallTimeout.stop();
                console.warn("TransitionWallpaper: Error loading media:", root.pendingSource);
                root.finishTransition();
            }
        }
    }

    // Fallback timeout in case media loading stalls
    Timer {
        id: stallTimeout
        interval: 5000
        repeat: false
        onTriggered: {
            if (readyCheckTimer.running) {
                readyCheckTimer.stop();
                root.startAnimation();
            }
        }
    }

    onSourceChanged: {
        if (!source) return;

        if (activeSource === "") {
            // First load on boot or initialization
            slot0.imageSource = source;
            slot0.opacity = 1.0;
            slot0.scale = 1.0;
            slot0.x = 0;
            slot0.y = 0;
            slot1.opacity = 0.0;
            slot1.imageSource = "";
            activeSlot = 0;
            activeSource = source;
            previousSource = source;
            notifyShown();
            return;
        }

        if (source === activeSource && !isTransitioning) return;

        // If currently in an animation, complete it immediately
        if (isTransitioning) {
            stopAllAnimations();
            finishTransition();
        }

        pendingSource = source;
        previousSource = source;
        var targetSlot = activeSlot === 0 ? slot1 : slot0;

        // Prepare incoming slot keeping it hidden until decoded
        targetSlot.opacity = 0.0;
        targetSlot.scale = 1.0;
        targetSlot.x = 0;
        targetSlot.y = 0;
        targetSlot.imageSource = source;

        if (targetSlot.isReady) {
            Qt.callLater(root.startAnimation);
        } else {
            readyCheckTimer.restart();
            stallTimeout.restart();
        }
    }

    function stopAllAnimations() {
        animCrossfade.stop();
        animCircle.stop();
        animSlide.stop();
        animZoomFade.stop();
        animPulse.stop();
    }

    function startAnimation() {
        stallTimeout.stop();

        var dur = duration >= 0 ? duration : (Config.animDuration >= 0 ? Config.animDuration : 300);
        if (transitionStyle === "none" || dur <= 0) {
            finishTransition();
            return;
        }

        isTransitioning = true;

        var fromSlot = activeSlot === 0 ? slot0 : slot1;
        var toSlot = activeSlot === 0 ? slot1 : slot0;
        var fromIndex = activeSlot;
        var toIndex = activeSlot === 0 ? 1 : 0;
        var easing = getEasingType();

        var w = root.width > 0 ? root.width : (wallpaperManager && wallpaperManager.width > 0 ? wallpaperManager.width : 1920);
        var h = root.height > 0 ? root.height : (wallpaperManager && wallpaperManager.height > 0 ? wallpaperManager.height : 1080);
        var maxR = Math.ceil(Math.hypot(w, h) / 2) + 50;

        // Reset geometry & transforms
        fromSlot.x = 0;
        fromSlot.y = 0;
        fromSlot.scale = 1.0;
        fromSlot.opacity = 1.0;

        toSlot.x = 0;
        toSlot.y = 0;
        toSlot.scale = 1.0;
        toSlot.opacity = 1.0;

        activeCircleSlot = -1;

        if (transitionStyle === "crossfade") {
            toSlot.z = 1;
            fromSlot.z = 0;
            toSlot.opacity = 0.0;

            fadeIncoming.target = toSlot;
            fadeIncoming.duration = dur;
            fadeIncoming.easing.type = easing;

            fadeOutgoing.target = fromSlot;
            fadeOutgoing.duration = dur;
            fadeOutgoing.easing.type = easing;

            animCrossfade.start();
        } else if (transitionStyle === "circleOut") {
            // Circle Expand: incoming starts at center and expands outwards to cover the screen
            toSlot.z = 1;
            fromSlot.z = 0;
            toSlot.opacity = 1.0;
            fromSlot.opacity = 1.0;

            activeCircleSlot = toIndex;
            circleMaskInverted = false;
            circleRadius = 0;

            circleAnim.target = root;
            circleAnim.property = "circleRadius";
            circleAnim.from = 0;
            circleAnim.to = maxR;
            circleAnim.duration = dur;
            circleAnim.easing.type = easing;

            animCircle.start();
        } else if (transitionStyle === "circleIn") {
            // Circle Shrink: outgoing shrinks down to center revealing incoming underneath
            fromSlot.z = 1;
            toSlot.z = 0;
            fromSlot.opacity = 1.0;
            toSlot.opacity = 1.0;

            activeCircleSlot = fromIndex;
            circleMaskInverted = false;
            circleRadius = maxR;

            circleAnim.target = root;
            circleAnim.property = "circleRadius";
            circleAnim.from = maxR;
            circleAnim.to = 0;
            circleAnim.duration = dur;
            circleAnim.easing.type = easing;

            animCircle.start();
        } else if (transitionStyle === "slideLeft") {
            toSlot.z = 1;
            fromSlot.z = 0;
            toSlot.x = w;
            fromSlot.x = 0;

            slideIn.target = toSlot;
            slideIn.property = "x";
            slideIn.from = w;
            slideIn.to = 0;
            slideIn.duration = dur;
            slideIn.easing.type = easing;

            slideOut.target = fromSlot;
            slideOut.property = "x";
            slideOut.from = 0;
            slideOut.to = -w;
            slideOut.duration = dur;
            slideOut.easing.type = easing;

            animSlide.start();
        } else if (transitionStyle === "slideRight") {
            toSlot.z = 1;
            fromSlot.z = 0;
            toSlot.x = -w;
            fromSlot.x = 0;

            slideIn.target = toSlot;
            slideIn.property = "x";
            slideIn.from = -w;
            slideIn.to = 0;
            slideIn.duration = dur;
            slideIn.easing.type = easing;

            slideOut.target = fromSlot;
            slideOut.property = "x";
            slideOut.from = 0;
            slideOut.to = w;
            slideOut.duration = dur;
            slideOut.easing.type = easing;

            animSlide.start();
        } else if (transitionStyle === "slideUp") {
            toSlot.z = 1;
            fromSlot.z = 0;
            toSlot.y = h;
            fromSlot.y = 0;

            slideIn.target = toSlot;
            slideIn.property = "y";
            slideIn.from = h;
            slideIn.to = 0;
            slideIn.duration = dur;
            slideIn.easing.type = easing;

            slideOut.target = fromSlot;
            slideOut.property = "y";
            slideOut.from = 0;
            slideOut.to = -h;
            slideOut.duration = dur;
            slideOut.easing.type = easing;

            animSlide.start();
        } else if (transitionStyle === "slideDown") {
            toSlot.z = 1;
            fromSlot.z = 0;
            toSlot.y = -h;
            fromSlot.y = 0;

            slideIn.target = toSlot;
            slideIn.property = "y";
            slideIn.from = -h;
            slideIn.to = 0;
            slideIn.duration = dur;
            slideIn.easing.type = easing;

            slideOut.target = fromSlot;
            slideOut.property = "y";
            slideOut.from = 0;
            slideOut.to = h;
            slideOut.duration = dur;
            slideOut.easing.type = easing;

            animSlide.start();
        } else if (transitionStyle === "zoomFade") {
            toSlot.z = 1;
            fromSlot.z = 0;
            toSlot.opacity = 0.0;
            toSlot.scale = 1.08;
            fromSlot.opacity = 1.0;
            fromSlot.scale = 1.0;

            zoomInScale.target = toSlot;
            zoomInScale.from = 1.08;
            zoomInScale.to = 1.0;
            zoomInScale.duration = dur;
            zoomInScale.easing.type = easing;

            zoomInFade.target = toSlot;
            zoomInFade.duration = dur;
            zoomInFade.easing.type = easing;

            zoomOutFade.target = fromSlot;
            zoomOutFade.duration = dur;
            zoomOutFade.easing.type = easing;

            animZoomFade.start();
        } else if (transitionStyle === "pulse") {
            toSlot.z = 1;
            fromSlot.z = 0;
            fromSlot.opacity = 1.0;
            fromSlot.scale = 1.0;
            toSlot.opacity = 0.0;
            toSlot.scale = 0.97;

            pulseScale1.target = fromSlot;
            pulseScale1.duration = dur / 2;
            pulseScale1.easing.type = easing;

            pulseOpacity1.target = fromSlot;
            pulseOpacity1.duration = dur / 2;
            pulseOpacity1.easing.type = easing;

            pulseScale2.target = toSlot;
            pulseScale2.duration = dur;
            pulseScale2.easing.type = easing;

            pulseOpacity2.target = toSlot;
            pulseOpacity2.duration = dur;
            pulseOpacity2.easing.type = easing;

            animPulse.start();
        } else {
            finishTransition();
        }
    }

    function finishTransition() {
        readyCheckTimer.stop();
        stallTimeout.stop();
        isTransitioning = false;
        activeCircleSlot = -1;
        activeSlot = activeSlot === 0 ? 1 : 0;
        activeSource = pendingSource;
        pendingSource = "";

        var currentActive = activeSlot === 0 ? slot0 : slot1;
        var currentInactive = activeSlot === 0 ? slot1 : slot0;

        currentActive.opacity = 1.0;
        currentActive.scale = 1.0;
        currentActive.x = 0;
        currentActive.y = 0;
        currentActive.z = 1;

        currentInactive.opacity = 0.0;
        currentInactive.scale = 1.0;
        currentInactive.x = 0;
        currentInactive.y = 0;
        currentInactive.z = 0;
        currentInactive.imageSource = ""; // Free GPU texture and unloads inactive video/gif immediately!

        if (root.wallpaperManager) {
            root.wallpaperManager.activeVideo = currentActive.activeVideoRef;
            if (typeof root.wallpaperManager.onWallpaperTransitionFinished === "function") {
                root.wallpaperManager.onWallpaperTransitionFinished(activeSource);
            }
        }

        notifyShown();
    }

    // Animation definitions
    ParallelAnimation {
        id: animCrossfade
        NumberAnimation { id: fadeIncoming; property: "opacity"; from: 0.0; to: 1.0 }
        NumberAnimation { id: fadeOutgoing; property: "opacity"; from: 1.0; to: 0.0 }
        onFinished: root.finishTransition()
    }

    ParallelAnimation {
        id: animCircle
        NumberAnimation { id: circleAnim }
        onFinished: root.finishTransition()
    }

    ParallelAnimation {
        id: animSlide
        NumberAnimation { id: slideIn }
        NumberAnimation { id: slideOut }
        onFinished: root.finishTransition()
    }

    ParallelAnimation {
        id: animZoomFade
        NumberAnimation { id: zoomInScale; property: "scale" }
        NumberAnimation { id: zoomInFade; property: "opacity"; from: 0.0; to: 1.0 }
        NumberAnimation { id: zoomOutFade; property: "opacity"; from: 1.0; to: 0.0 }
        onFinished: root.finishTransition()
    }

    ParallelAnimation {
        id: animPulse
        NumberAnimation { id: pulseScale1; property: "scale"; from: 1.0; to: 1.03 }
        NumberAnimation { id: pulseOpacity1; property: "opacity"; from: 1.0; to: 0.0 }
        NumberAnimation { id: pulseScale2; property: "scale"; from: 0.97; to: 1.0 }
        NumberAnimation { id: pulseOpacity2; property: "opacity"; from: 0.0; to: 1.0 }
        onFinished: root.finishTransition()
    }
}
