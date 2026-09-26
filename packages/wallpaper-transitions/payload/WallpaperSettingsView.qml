import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.config

FocusScope {
    id: root
    focus: true

    Rectangle {
        anchors.fill: parent
        color: Colors.background
        z: -1

        MouseArea {
            anchors.fill: parent
            // Prevent clicks from penetrating through empty areas
            onClicked: {}
        }
    }

    signal backClicked

    component MarqueeText: Item {
        id: marqueeRoot
        clip: true
        implicitHeight: textItem.implicitHeight
        implicitWidth: textItem.implicitWidth

        property alias text: textItem.text
        property alias font: textItem.font
        property alias color: textItem.color
        property alias textOpacity: textItem.opacity
        property bool hovered: false
        property bool isSelected: false
        property real speed: 38

        readonly property bool isOverflowing: marqueeRoot.width > 0 && textItem.implicitWidth > marqueeRoot.width
        readonly property real overflowDistance: (marqueeRoot.width > 0 && isOverflowing) ? Math.max(0, textItem.implicitWidth - marqueeRoot.width) : 0
        readonly property int animDuration: Math.max(1200, Math.round((overflowDistance / Math.max(1, speed)) * 1000))
        readonly property bool shouldAnimate: isOverflowing && (hovered || isSelected) && marqueeRoot.visible

        Text {
            id: textItem
            x: 0
            width: implicitWidth
            anchors.verticalCenter: parent.verticalCenter
        }

        SequentialAnimation {
            id: marqueeAnim
            running: marqueeRoot.shouldAnimate
            loops: Animation.Infinite

            PauseAnimation { duration: 1100 }
            NumberAnimation {
                target: textItem
                property: "x"
                to: -marqueeRoot.overflowDistance
                duration: marqueeRoot.animDuration
                easing.type: Easing.InOutQuad
            }
            PauseAnimation { duration: 1300 }
            NumberAnimation {
                target: textItem
                property: "x"
                to: 0
                duration: Math.max(700, Math.round(marqueeRoot.animDuration * 0.75))
                easing.type: Easing.InOutQuad
            }
            PauseAnimation { duration: 800 }
        }

        onShouldAnimateChanged: {
            if (!shouldAnimate) {
                marqueeAnim.stop();
                textItem.x = 0;
            }
        }
    }

    property string currentStyle: (GlobalStates && GlobalStates.wallpaperTransitionStyle) ? GlobalStates.wallpaperTransitionStyle : "crossfade"
    property string currentEasing: (GlobalStates && GlobalStates.wallpaperTransitionEasing) ? GlobalStates.wallpaperTransitionEasing : "cubic"
    property int currentDuration: (GlobalStates && GlobalStates.wallpaperTransitionDuration) ? GlobalStates.wallpaperTransitionDuration : 400

    readonly property string modId: "positive.wallpaper-transitions"

    // Active navigation section
    // 0: Transition Style, 1: Easing Curve, 2: Animation Duration, 3: Automation & Rotation,
    // 4: Material You Schemes, 5: Color Presets, 6: Back Button
    property int currentSection: 0
    property int focusedStyleIndex: 0
    property int focusedEasingIndex: 0
    property int focusedSpeedIndex: 1
    property int focusedAutomationIndex: 0 // 0: Periodic Toggle, 1-6: Intervals, 7: All Wallpapers, 8+: Sources
    property int focusedSchemeIndex: 0
    property int focusedPresetIndex: 0

    readonly property var styleOptions: [
        { id: "crossfade", title: "Crossfade", desc: "Smooth continuous opacity dissolve", icon: Icons.sparkle },
        { id: "circleOut", title: "Circle Expand", desc: "Iris expands outwards from center", icon: Icons.circle },
        { id: "circleIn", title: "Circle Shrink", desc: "Iris contracts inwards to center", icon: Icons.circleNotch },
        { id: "slideLeft", title: "Slide Left", desc: "Pushes outgoing wallpaper left", icon: Icons.caretLeft },
        { id: "slideRight", title: "Slide Right", desc: "Pushes outgoing wallpaper right", icon: Icons.caretRight },
        { id: "slideUp", title: "Slide Up", desc: "Pushes outgoing wallpaper upwards", icon: Icons.caretUp },
        { id: "slideDown", title: "Slide Down", desc: "Pushes outgoing wallpaper downwards", icon: Icons.caretDown },
        { id: "zoomFade", title: "Zoom & Fade", desc: "Cinematic scale & depth dissolve", icon: Icons.glassPlus },
        { id: "pulse", title: "Ambxst Pulse", desc: "Subtle zoom pulse & brightness dip", icon: Icons.heartbeat },
        { id: "none", title: "Instant", desc: "Seamless instant swap (zero flash)", icon: Icons.lightning }
    ]

    readonly property var easingOptions: [
        { id: "cubic", title: "Cubic (Default)", desc: "Natural deceleration (brisk start, soft stop)" },
        { id: "inOut", title: "Ease In-Out", desc: "S-Curve (gentle start, fast mid, gentle stop)" },
        { id: "expo", title: "Exponential", desc: "High-velocity snap with elongated settle" },
        { id: "back", title: "Elastic Back", desc: "Dynamic spring with subtle overshoot" },
        { id: "quad", title: "Quadratic", desc: "Gentle ease-out deceleration" },
        { id: "linear", title: "Linear", desc: "Constant unvarying rate from start to end" }
    ]

    readonly property var speedOptions: [
        { label: "200ms", sub: "Fast", value: 200 },
        { label: "400ms", sub: "Normal", value: 400 },
        { label: "700ms", sub: "Smooth", value: 700 },
        { label: "1.2s", sub: "Cinematic", value: 1200 }
    ]

    readonly property var intervalOptions: [
        { label: "30s", text: "30s", sec: 30 },
        { label: "1m", text: "1m", sec: 60 },
        { label: "5m", text: "5m", sec: 300 },
        { label: "15m", text: "15m", sec: 900 },
        { label: "30m", text: "30m", sec: 1800 },
        { label: "1h", text: "1h", sec: 3600 },
        { label: "2h", text: "2h", sec: 7200 }
    ]

    readonly property int currentPeriodicSeconds: GlobalStates ? GlobalStates.wallpaperPeriodicSeconds : 900
    readonly property string currentRotationMode: GlobalStates ? GlobalStates.wallpaperRotationMode : "interval"
    property bool showCustomInput: !isStandardPreset(currentPeriodicSeconds)
    property int customHours: 0
    property int customMinutes: 15
    property int customSeconds: 0

    function initCustomInput() {
        let sec = root.currentPeriodicSeconds;
        customHours = Math.floor(sec / 3600);
        customMinutes = Math.floor((sec % 3600) / 60);
        customSeconds = sec % 60;
    }

    onCurrentPeriodicSecondsChanged: initCustomInput()

    function applyCustomTimer() {
        let sec = (customHours * 3600) + (customMinutes * 60) + customSeconds;
        sec = Math.max(5, sec);
        if (GlobalStates) {
            if (!GlobalStates.wallpaperPeriodicEnabled) {
                GlobalStates.setWallpaperPeriodicEnabled(true);
            }
            GlobalStates.setWallpaperPeriodicSeconds(sec);
        }
    }

    readonly property bool isSolarSync: GlobalStates && GlobalStates.wallpaperSolarSyncEnabled
    readonly property string currentSolarPeriod: GlobalStates ? GlobalStates.getCurrentSolarPeriod() : "afternoon"

    function isStandardPreset(sec) {
        for (let i = 0; i < intervalOptions.length; i++) {
            if (intervalOptions[i].sec === sec) return true;
        }
        return false;
    }

    function formatDuration(sec) {
        if (!sec || sec < 60) {
            return (sec || 15) + "s";
        }
        let h = Math.floor(sec / 3600);
        let m = Math.floor((sec % 3600) / 60);
        let s = sec % 60;
        let parts = [];
        if (h > 0) parts.push(h + "h");
        if (m > 0) parts.push(m + "m");
        if (s > 0) parts.push(s + "s");
        return parts.join(" ");
    }

    function getSolarPhaseInfo(id) {
        switch (id) {
            case "morning": return { title: "Morning (06:00 – 11:00)", icon: Icons.sunDim, desc: "Fresh daylight & bright pastels" };
            case "afternoon": return { title: "Afternoon (11:00 – 17:00)", icon: Icons.sun, desc: "Warm, bright & vibrant daylight" };
            case "sunset": return { title: "Sunset (17:00 – 21:00)", icon: Icons.sunDim, desc: "Golden hour, warm orange & dusk" };
            case "night": return { title: "Night (21:00 – 06:00)", icon: Icons.moon, desc: "Dark, starry night & deep tones" };
            default: return { title: "Daytime", icon: Icons.sun, desc: "Balanced daylight" };
        }
    }

    function getSolarCount(period) {
        if (!GlobalStates || !GlobalStates.solarCacheMap) return 0;
        let map = GlobalStates.solarCacheMap;
        let count = 0;
        for (let k in map) {
            if (map[k] === period) count++;
        }
        return count;
    }

    readonly property var pauseOptions: [
        {
            id: "fullscreen",
            title: "Fullscreen only (Default)",
            sub: "Pause when an app is in exclusive fullscreen mode",
            desc: "Pauses video & GIF playback when a game, media player, or window is fullscreen."
        },
        {
            id: "covered",
            title: "Maximized & Fullscreen",
            sub: "Pause whenever windows cover the screen",
            desc: "Pauses live wallpaper whenever a tiled, maximized, or fullscreen window covers the screen."
        },
        {
            id: "never",
            title: "Never pause",
            sub: "Keep playing continuously",
            desc: "Always keeps video and GIF wallpapers playing, regardless of open windows."
        }
    ]

    readonly property string currentPauseMode: (GlobalStates && GlobalStates.wallpaperPauseMode) ? GlobalStates.wallpaperPauseMode : "fullscreen"
    readonly property string currentPauseScope: (GlobalStates && GlobalStates.wallpaperPauseScope) ? GlobalStates.wallpaperPauseScope : "perScreen"

    readonly property var availableSourceOptions: {
        let list = [
            { key: "image", label: "Images", icon: Icons.image, isSubfolder: false },
            { key: "gif", label: "GIFs", icon: Icons.play, isSubfolder: false },
            { key: "video", label: "Videos", icon: Icons.play, isSubfolder: false }
        ];
        if (GlobalStates && GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.subfolderFilters) {
            let subs = GlobalStates.wallpaperManager.subfolderFilters;
            for (let i = 0; i < subs.length; i++) {
                list.push({
                    key: "subfolder_" + subs[i],
                    label: subs[i],
                    icon: Icons.folder,
                    isSubfolder: true
                });
            }
        }
        return list;
    }

    function getMatchingCountText() {
        if (!GlobalStates || !GlobalStates.wallpaperManager || !GlobalStates.wallpaperManager.wallpaperPaths) {
            return "0 wallpapers";
        }
        let allPaths = GlobalStates.wallpaperManager.wallpaperPaths;
        let filters = (GlobalStates.wallpaperRandomSourceFilters && Array.isArray(GlobalStates.wallpaperRandomSourceFilters)) ? GlobalStates.wallpaperRandomSourceFilters : [];
        if (filters.length === 0) {
            return "Pool: " + allPaths.length + " (All)";
        }
        let basePath = (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.wallpaperDir) ? GlobalStates.wallpaperManager.wallpaperDir : "";
        if (basePath && !basePath.endsWith("/")) basePath += "/";

        let hasImage = filters.includes("image");
        let hasGif = filters.includes("gif");
        let hasVideo = filters.includes("video");
        let subfilters = [];
        for (let j = 0; j < filters.length; j++) {
            let f = filters[j];
            if (f.startsWith("subfolder_")) {
                subfilters.push(f.replace("subfolder_", ""));
            } else if (f !== "image" && f !== "gif" && f !== "video") {
                subfilters.push(f);
            }
        }

        let count = 0;
        for (let i = 0; i < allPaths.length; i++) {
            let p = allPaths[i];
            let ext = p.substring(p.lastIndexOf('.') + 1).toLowerCase();
            let isImg = (ext === 'jpg' || ext === 'jpeg' || ext === 'png' || ext === 'webp' || ext === 'bmp' || ext === 'tif' || ext === 'tiff');
            let isG = (ext === 'gif');
            let isV = (ext === 'mp4' || ext === 'webm' || ext === 'mov' || ext === 'avi' || ext === 'mkv');

            if ((hasImage && isImg) || (hasGif && isG) || (hasVideo && isV)) {
                count++;
                continue;
            }

            if (subfilters.length > 0 && basePath) {
                let rel = p.startsWith(basePath) ? p.substring(basePath.length) : p;
                let slashIdx = rel.indexOf('/');
                if (slashIdx !== -1) {
                    let topDir = rel.substring(0, slashIdx);
                    if (subfilters.includes(topDir)) {
                        count++;
                        continue;
                    }
                }
            }
        }
        return "Pool: " + count + " wallpapers";
    }

    property string matchingCountText: "Pool: (Calculating...)"

    function updateMatchingCount() {
        if (!root.visible) return;
        matchingCountText = getMatchingCountText();
    }

    Connections {
        target: GlobalStates
        function onWallpaperRandomSourceFiltersChanged() {
            if (root.visible) {
                root.updateMatchingCount();
            }
        }
    }

    readonly property var matugenSchemes: [
        { id: "scheme-content", label: "Content" },
        { id: "scheme-expressive", label: "Expressive" },
        { id: "scheme-fidelity", label: "Fidelity" },
        { id: "scheme-fruit-salad", label: "Fruit Salad" },
        { id: "scheme-monochrome", label: "Monochrome" },
        { id: "scheme-neutral", label: "Neutral" },
        { id: "scheme-rainbow", label: "Rainbow" },
        { id: "scheme-tonal-spot", label: "Tonal Spot" }
    ]

    property var presets: (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.colorPresets) ? GlobalStates.wallpaperManager.colorPresets : []

    NumberAnimation {
        id: scrollAnim
        target: scrollArea
        property: "contentY"
        duration: Config.animDuration > 0 ? 250 : 0
        easing.type: Easing.OutCubic
    }

    function smoothScrollTo(newY) {
        let maxScroll = Math.max(0, scrollArea.contentHeight - scrollArea.height);
        let clampedY = Math.max(0, Math.min(maxScroll, newY));
        if (Config.animDuration > 0) {
            scrollAnim.stop();
            scrollAnim.to = clampedY;
            scrollAnim.start();
        } else {
            scrollArea.contentY = clampedY;
        }
    }

    function scrollBy(deltaY) {
        scrollAnim.stop();
        let maxScroll = Math.max(0, scrollArea.contentHeight - scrollArea.height);
        scrollArea.contentY = Math.max(0, Math.min(maxScroll, scrollArea.contentY + deltaY));
    }

    function updateSetting(key, val) {
        if (!GlobalStates) return;
        if (key === "transitionStyle") {
            currentStyle = val;
            GlobalStates.setWallpaperTransitionStyle(val);
        } else if (key === "easingCurve") {
            currentEasing = val;
            GlobalStates.setWallpaperTransitionEasing(val);
        } else if (key === "duration") {
            currentDuration = val;
            GlobalStates.setWallpaperTransitionDuration(val);
        }
    }

    Connections {
        target: GlobalStates
        function onWallpaperTransitionStyleChanged() {
            root.currentStyle = GlobalStates.wallpaperTransitionStyle;
        }
        function onWallpaperTransitionEasingChanged() {
            root.currentEasing = GlobalStates.wallpaperTransitionEasing;
        }
        function onWallpaperTransitionDurationChanged() {
            root.currentDuration = GlobalStates.wallpaperTransitionDuration;
        }
    }

    function getAvailableSections() {
        let secs = [0, 1, 2, 3, 4];
        if (root.presets && root.presets.length > 0) {
            secs.push(5);
        }
        secs.push(6);
        return secs;
    }

    function scrollToSection(sec) {
        if (sec === 0 && focusedStyleIndex <= 1) {
            smoothScrollTo(0);
            return;
        }
        if (sec === 6) {
            smoothScrollTo(0);
            return;
        }
        let targetItem = null;
        if (sec === 0) {
            targetItem = sectionStyle;
        } else if (sec === 1 || sec === 2) {
            targetItem = sectionEasingAndDuration;
        } else if (sec === 3) {
            targetItem = sectionAutomation;
        } else if (sec === 4) {
            targetItem = sectionSchemes;
        } else if (sec === 5) {
            targetItem = sectionPresets;
        }

        if (targetItem) {
            let itemTop = targetItem.y;
            let itemBottom = targetItem.y + targetItem.height;

            if (sec === 0) {
                let row = Math.floor(focusedStyleIndex / 2);
                itemTop = row === 0 ? targetItem.y : (targetItem.y + 28 + (row * 58));
                itemBottom = itemTop + 52;
            } else if (sec === 1) {
                let row = Math.floor(focusedEasingIndex / 2);
                itemTop = row === 0 ? targetItem.y : (targetItem.y + 28 + (row * 54));
                itemBottom = itemTop + 48;
            } else if (sec === 2) {
                itemTop = targetItem.y;
                itemBottom = targetItem.y + 76;
            } else if (sec === 3) {
                if (focusedAutomationIndex <= 6) {
                    itemTop = targetItem.y;
                    itemBottom = targetItem.y + 110;
                } else {
                    itemTop = targetItem.y + 80;
                    itemBottom = targetItem.y + targetItem.height;
                }
            } else if (sec === 4) {
                let row = Math.floor(focusedSchemeIndex / 4);
                itemTop = row === 0 ? targetItem.y : (targetItem.y + 28 + (row * 46));
                itemBottom = itemTop + 40;
            } else if (sec === 5 && root.presets && root.presets.length > 0) {
                let row = Math.floor(focusedPresetIndex / 4);
                itemTop = row === 0 ? targetItem.y : (targetItem.y + 28 + (row * 44));
                itemBottom = itemTop + 38;
            }

            let viewH = scrollArea.height > 0 ? scrollArea.height : 500;
            let maxScroll = Math.max(0, scrollArea.contentHeight - viewH);

            if (itemTop < scrollArea.contentY + 10) {
                smoothScrollTo(Math.max(0, itemTop - 12));
            } else if (itemBottom > scrollArea.contentY + viewH - 10) {
                smoothScrollTo(Math.min(maxScroll, itemBottom - viewH + 16));
            }
        }
    }

    function syncSectionFocus(sec) {
        switch (sec) {
        case 0:
            for (let i = 0; i < root.styleOptions.length; i++) {
                if (root.styleOptions[i].id === root.currentStyle) {
                    focusedStyleIndex = i;
                    break;
                }
            }
            break;
        case 1:
            for (let i = 0; i < root.easingOptions.length; i++) {
                if (root.easingOptions[i].id === root.currentEasing) {
                    focusedEasingIndex = i;
                    break;
                }
            }
            break;
        case 2:
            for (let i = 0; i < root.speedOptions.length; i++) {
                if (Math.abs(root.currentDuration - root.speedOptions[i].value) < 50) {
                    focusedSpeedIndex = i;
                    break;
                }
            }
            break;
        case 3:
            let maxAutomation = 7 + (root.availableSourceOptions ? root.availableSourceOptions.length : 0);
            if (focusedAutomationIndex < 0 || focusedAutomationIndex > maxAutomation) {
                focusedAutomationIndex = 0;
            }
            break;
        case 4:
            if (GlobalStates.wallpaperManager) {
                let curScheme = GlobalStates.wallpaperManager.currentMatugenScheme;
                for (let i = 0; i < root.matugenSchemes.length; i++) {
                    if (root.matugenSchemes[i].id === curScheme) {
                        focusedSchemeIndex = i;
                        break;
                    }
                }
            }
            break;
        case 5:
            if (root.presets && GlobalStates.wallpaperManager) {
                let curPreset = GlobalStates.wallpaperManager.activeColorPreset;
                for (let i = 0; i < root.presets.length; i++) {
                    if (String(root.presets[i]) === curPreset) {
                        focusedPresetIndex = i;
                        break;
                    }
                }
            }
            break;
        case 6:
            break;
        }
        scrollToSection(sec);
    }

    function nextSection() {
        let secs = getAvailableSections();
        let currentIdxInSecs = secs.indexOf(currentSection);
        if (currentIdxInSecs === -1 || currentIdxInSecs >= secs.length - 1) {
            currentSection = secs[0];
        } else {
            currentSection = secs[currentIdxInSecs + 1];
        }
        syncSectionFocus(currentSection);
    }

    function previousSection() {
        let secs = getAvailableSections();
        let currentIdxInSecs = secs.indexOf(currentSection);
        if (currentIdxInSecs <= 0) {
            currentSection = secs[secs.length - 1];
        } else {
            currentSection = secs[currentIdxInSecs - 1];
        }
        syncSectionFocus(currentSection);
    }

    function handleArrowKey(key) {
        switch (currentSection) {
        case 6: // Back to Wallpapers button (at top)
            if (key === Qt.Key_Down) {
                currentSection = 0;
                focusedStyleIndex = 0;
            }
            break;

        case 0: // Transition Style (10 items, 2 cols x 5 rows)
            // Column 0 (even): 0, 2, 4, 6, 8
            // Column 1 (odd):  1, 3, 5, 7, 9
            if (key === Qt.Key_Right) {
                if (focusedStyleIndex % 2 === 0 && focusedStyleIndex + 1 < styleOptions.length) {
                    focusedStyleIndex++;
                }
            } else if (key === Qt.Key_Left) {
                if (focusedStyleIndex % 2 === 1) {
                    focusedStyleIndex--;
                }
            } else if (key === Qt.Key_Down) {
                if (focusedStyleIndex + 2 < styleOptions.length) {
                    focusedStyleIndex += 2;
                } else {
                    // Reached bottom row of Transition Style (index 8 or 9)
                    // Move down to Easing Curve (if left column) or Duration (if right column)
                    if (focusedStyleIndex % 2 === 0) {
                        currentSection = 1; // Easing Curve
                        focusedEasingIndex = 0;
                    } else {
                        currentSection = 2; // Animation Duration
                        focusedSpeedIndex = 0;
                    }
                }
            } else if (key === Qt.Key_Up) {
                if (focusedStyleIndex >= 2) {
                    focusedStyleIndex -= 2;
                } else {
                    // Top row (index 0 or 1), go up to Back Button
                    currentSection = 6;
                }
            }
            break;

        case 1: // Easing Curve (6 items, 2 cols x 3 rows: 0,1 / 2,3 / 4,5)
            if (key === Qt.Key_Right) {
                if (focusedEasingIndex % 2 === 0 && focusedEasingIndex + 1 < easingOptions.length) {
                    focusedEasingIndex++;
                } else {
                    // At right column of Easing, cross over horizontally to Animation Duration!
                    currentSection = 2;
                    let row = Math.floor(focusedEasingIndex / 2);
                    focusedSpeedIndex = Math.min(row, speedOptions.length - 1);
                }
            } else if (key === Qt.Key_Left) {
                if (focusedEasingIndex % 2 === 1) {
                    focusedEasingIndex--;
                }
            } else if (key === Qt.Key_Down) {
                if (focusedEasingIndex + 2 < easingOptions.length) {
                    focusedEasingIndex += 2;
                } else {
                    // Reached bottom of Easing Curve -> move down to Section 3 (Periodic switch on left)
                    currentSection = 3;
                    focusedAutomationIndex = 0;
                }
            } else if (key === Qt.Key_Up) {
                if (focusedEasingIndex >= 2) {
                    focusedEasingIndex -= 2;
                } else {
                    // Move up to Transition Style (bottom row, left col: index 8)
                    currentSection = 0;
                    focusedStyleIndex = 8;
                }
            }
            break;

        case 2: // Animation Duration (4 items in 1 horizontal row: 0..3)
            if (key === Qt.Key_Right) {
                if (focusedSpeedIndex < speedOptions.length - 1) {
                    focusedSpeedIndex++;
                }
            } else if (key === Qt.Key_Left) {
                if (focusedSpeedIndex > 0) {
                    focusedSpeedIndex--;
                } else {
                    // At left edge of Duration, cross over horizontally to Easing Curve (right column)!
                    currentSection = 1;
                    focusedEasingIndex = 1; // right col, top row
                }
            } else if (key === Qt.Key_Down) {
                // Move down to Section 3 (Interval pills on right)
                currentSection = 3;
                focusedAutomationIndex = 1; // 1m interval pill
            } else if (key === Qt.Key_Up) {
                // Move up to Transition Style (bottom row, right col: index 9)
                currentSection = 0;
                focusedStyleIndex = 9;
            }
            break;

        case 3: // Automation & Rotation (0: Periodic Toggle, 1..6: Presets, 7: Custom Btn, 8: Solar Toggle, 9: All Walls, 10+: Sources)
            let maxSourceIdx = 9 + (root.availableSourceOptions ? root.availableSourceOptions.length : 0);
            if (key === Qt.Key_Right) {
                if (focusedAutomationIndex < 7) {
                    focusedAutomationIndex++;
                } else if (focusedAutomationIndex >= 9 && focusedAutomationIndex < maxSourceIdx) {
                    focusedAutomationIndex++;
                }
            } else if (key === Qt.Key_Left) {
                if (focusedAutomationIndex > 0 && focusedAutomationIndex <= 7) {
                    focusedAutomationIndex--;
                } else if (focusedAutomationIndex > 9) {
                    focusedAutomationIndex--;
                }
            } else if (key === Qt.Key_Down) {
                if (focusedAutomationIndex <= 7) {
                    focusedAutomationIndex = 8; // Move down to Time of Day
                } else if (focusedAutomationIndex === 8) {
                    focusedAutomationIndex = 9; // Move down to Sources (All Wallpapers)
                } else {
                    // Move from Sources down to Material You Schemes
                    currentSection = 4;
                    focusedSchemeIndex = Math.min(focusedAutomationIndex - 9, matugenSchemes.length - 1);
                }
            } else if (key === Qt.Key_Up) {
                if (focusedAutomationIndex >= 9) {
                    focusedAutomationIndex = 8; // Move up to Time of Day
                } else if (focusedAutomationIndex === 8) {
                    focusedAutomationIndex = 0; // Move up to Periodic row
                } else {
                    // Move up to Easing (if left) or Duration (if right)
                    if (focusedAutomationIndex === 0) {
                        currentSection = 1;
                        focusedEasingIndex = 4; // bottom row of Easing
                    } else {
                        currentSection = 2;
                        focusedSpeedIndex = Math.min(Math.max(0, focusedAutomationIndex - 1), speedOptions.length - 1);
                    }
                }
            }
            break;

        case 4: // Material You Schemes (8 items, 4 cols x 2 rows: 0..3, 4..7)
            if (key === Qt.Key_Right) {
                if (focusedSchemeIndex % 4 < 3 && focusedSchemeIndex < matugenSchemes.length - 1) {
                    focusedSchemeIndex++;
                }
            } else if (key === Qt.Key_Left) {
                if (focusedSchemeIndex % 4 > 0) {
                    focusedSchemeIndex--;
                }
            } else if (key === Qt.Key_Down) {
                if (focusedSchemeIndex + 4 < matugenSchemes.length) {
                    focusedSchemeIndex += 4;
                } else {
                    // Reached bottom row of schemes
                    if (root.presets && root.presets.length > 0) {
                        currentSection = 5;
                        focusedPresetIndex = Math.min(focusedSchemeIndex - 4, root.presets.length - 1);
                    }
                }
            } else if (key === Qt.Key_Up) {
                if (focusedSchemeIndex >= 4) {
                    focusedSchemeIndex -= 4;
                } else {
                    // Move up to Section 3 (Random Sources row)
                    currentSection = 3;
                    focusedAutomationIndex = 9 + Math.min(focusedSchemeIndex, root.availableSourceOptions ? root.availableSourceOptions.length : 0);
                }
            }
            break;

        case 5: // Color Presets (4 cols x N rows)
            if (root.presets && root.presets.length > 0) {
                let len = root.presets.length;
                if (key === Qt.Key_Right) {
                    if (focusedPresetIndex < len - 1) focusedPresetIndex++;
                } else if (key === Qt.Key_Left) {
                    if (focusedPresetIndex > 0) focusedPresetIndex--;
                } else if (key === Qt.Key_Down) {
                    if (focusedPresetIndex + 4 < len) {
                        focusedPresetIndex += 4;
                    }
                } else if (key === Qt.Key_Up) {
                    if (focusedPresetIndex >= 4) {
                        focusedPresetIndex -= 4;
                    } else {
                        // Top row of presets, move up to Section 4 (Schemes bottom row)
                        currentSection = 4;
                        focusedSchemeIndex = Math.min(4 + (focusedPresetIndex % 4), matugenSchemes.length - 1);
                    }
                }
            }
            break;
        }
        scrollToSection(currentSection);
    }

    function handleActivate() {
        switch (currentSection) {
        case 0:
            if (focusedStyleIndex >= 0 && focusedStyleIndex < styleOptions.length) {
                root.updateSetting("transitionStyle", styleOptions[focusedStyleIndex].id);
            }
            break;
        case 1:
            if (focusedEasingIndex >= 0 && focusedEasingIndex < easingOptions.length) {
                root.updateSetting("easingCurve", easingOptions[focusedEasingIndex].id);
            }
            break;
        case 2:
            if (focusedSpeedIndex >= 0 && focusedSpeedIndex < speedOptions.length) {
                root.updateSetting("duration", speedOptions[focusedSpeedIndex].value);
            }
            break;
        case 3:
            if (focusedAutomationIndex === 0) {
                if (GlobalStates) GlobalStates.setWallpaperPeriodicEnabled(!GlobalStates.wallpaperPeriodicEnabled);
            } else if (focusedAutomationIndex >= 1 && focusedAutomationIndex <= 6) {
                if (GlobalStates) {
                    if (!GlobalStates.wallpaperPeriodicEnabled) {
                        GlobalStates.setWallpaperPeriodicEnabled(true);
                    }
                    GlobalStates.setWallpaperPeriodicSeconds(intervalOptions[focusedAutomationIndex - 1].sec);
                }
            } else if (focusedAutomationIndex === 7) {
                root.showCustomInput = !root.showCustomInput;
                if (root.showCustomInput) root.initCustomInput();
            } else if (focusedAutomationIndex === 8) {
                if (GlobalStates) GlobalStates.setWallpaperSolarSyncEnabled(!GlobalStates.wallpaperSolarSyncEnabled);
            } else if (focusedAutomationIndex === 9) {
                // "All Wallpapers"
                if (GlobalStates) {
                    GlobalStates.setWallpaperRandomSourceFilters([]);
                }
            } else if (focusedAutomationIndex >= 10) {
                let optIdx = focusedAutomationIndex - 10;
                if (root.availableSourceOptions && optIdx < root.availableSourceOptions.length) {
                    let key = root.availableSourceOptions[optIdx].key;
                    if (GlobalStates) {
                        GlobalStates.toggleWallpaperRandomSourceFilter(key);
                    }
                }
            }
            break;
        case 4:
            if (focusedSchemeIndex >= 0 && focusedSchemeIndex < matugenSchemes.length) {
                if (GlobalStates.wallpaperManager) {
                    GlobalStates.wallpaperManager.setMatugenScheme(matugenSchemes[focusedSchemeIndex].id);
                }
            }
            break;
        case 5:
            if (root.presets && focusedPresetIndex >= 0 && focusedPresetIndex < root.presets.length) {
                if (GlobalStates.wallpaperManager) {
                    GlobalStates.wallpaperManager.setColorPreset(String(root.presets[focusedPresetIndex]));
                }
            }
            break;
        case 6:
            root.goBack();
            break;
        }
    }

    function goBack() {
        root.focus = false;
        root.backClicked();
    }

    onVisibleChanged: {
        if (visible) {
            root.forceActiveFocus();
            currentSection = 0;
            syncSectionFocus(0);
            updateMatchingCount();
            if (GlobalStates && GlobalStates.wallpaperManager && (!GlobalStates.wallpaperManager.subfolderFilters || GlobalStates.wallpaperManager.subfolderFilters.length === 0)) {
                GlobalStates.wallpaperManager.scanSubfolders();
            }
        }
    }

    onActiveFocusChanged: {
        if (activeFocus && visible) {
            syncSectionFocus(currentSection);
        }
    }

    Component.onCompleted: {
        initCustomInput();
        syncSectionFocus(0);
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Tab) {
            if (event.modifiers & Qt.ShiftModifier) {
                root.previousSection();
            } else {
                root.nextSection();
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Backtab) {
            root.previousSection();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.goBack();
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            root.handleArrowKey(Qt.Key_Right);
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            root.handleArrowKey(Qt.Key_Left);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            root.handleArrowKey(Qt.Key_Down);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            root.handleArrowKey(Qt.Key_Up);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.handleActivate();
            event.accepted = true;
        } else if (event.key === Qt.Key_PageDown) {
            root.scrollBy(scrollArea.height * 0.75);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            root.scrollBy(-scrollArea.height * 0.75);
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // Top Navigation & Header Bar
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            spacing: 12

            // Back Button
            StyledRect {
                id: backBtnRect
                Layout.preferredHeight: 44
                Layout.preferredWidth: 160
                readonly property bool isFocused: root.currentSection === 6
                variant: isFocused || backMa.containsMouse ? "primary" : "pane"
                radius: Styling.radius(4)

                MouseArea {
                    id: backMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goBack()

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: Icons.caretLeft
                            font.family: Icons.font
                            font.pixelSize: 18
                            color: backBtnRect.isFocused || backMa.containsMouse ? Colors.overPrimary : Colors.overSurface
                        }

                        Text {
                            text: "Back to Wallpapers"
                            font.family: Config.theme.font
                            font.pixelSize: Config.theme.fontSize
                            font.weight: backBtnRect.isFocused || backMa.containsMouse ? Font.Bold : Font.Medium
                            color: backBtnRect.isFocused || backMa.containsMouse ? Colors.overPrimary : Colors.overSurface
                        }
                    }
                }
            }

            // Title
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: "Advanced Wallpaper Settings"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(1)
                    font.weight: Font.Bold
                    color: Colors.overBackground
                }

                Text {
                    text: "Arrow keys navigate settings • Space/Enter to toggle sources • Tab to jump sections • Esc to return"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-3)
                    color: Colors.outline
                }
            }
        }

        // Scrollable Settings Content
        Flickable {
            id: scrollArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: settingsColumn.implicitHeight + 12
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                id: vScrollBar
                policy: scrollArea.contentHeight > scrollArea.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            WheelHandler {
                id: wheelHandler
                target: null
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    let delta = (event.pixelDelta && event.pixelDelta.y !== 0) ? event.pixelDelta.y : event.angleDelta.y;
                    if (delta !== 0) {
                        root.scrollBy(-delta);
                    }
                }
            }

            ColumnLayout {
                id: settingsColumn
                width: scrollArea.width - (vScrollBar.visible ? 16 : 4)
                spacing: 16

                // Section 0: Transition Style
                ColumnLayout {
                    id: sectionStyle
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "TRANSITION STYLE"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            font.weight: Font.Bold
                            color: root.currentSection === 0 ? Colors.primary : Colors.overBackground
                        }

                        Item { Layout.fillWidth: true }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 6
                        columnSpacing: 6

                        Repeater {
                            model: root.styleOptions

                            delegate: StyledRect {
                                id: styleCard
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52

                                readonly property bool isSelected: modelData.id === root.currentStyle
                                readonly property bool isFocused: root.currentSection === 0 && root.focusedStyleIndex === index

                                variant: isSelected ? "primary" : ((maCard.containsMouse || isFocused) ? "focus" : "pane")
                                radius: Styling.radius(4)

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: styleCard.isSelected ? Colors.overPrimary : Colors.primary
                                    border.width: 2
                                    radius: Styling.radius(4)
                                    visible: styleCard.isFocused
                                }

                                MouseArea {
                                    id: maCard
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentSection = 0;
                                        root.focusedStyleIndex = index;
                                        root.updateSetting("transitionStyle", modelData.id);
                                    }
                                    onWheel: (wheel) => root.scrollBy(-((wheel.pixelDelta && wheel.pixelDelta.y !== 0) ? wheel.pixelDelta.y : wheel.angleDelta.y))

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8

                                        Text {
                                            text: modelData.icon || Icons.sparkle
                                            font.family: Icons.font
                                            font.pixelSize: 20
                                            color: styleCard.isSelected ? Colors.overPrimary : (styleCard.isFocused ? Colors.primary : Colors.overSurface)
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                text: modelData.title
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-1)
                                                font.weight: styleCard.isSelected ? Font.Bold : Font.Medium
                                                color: styleCard.isSelected ? Colors.overPrimary : Colors.overBackground
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.desc
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-3)
                                                color: styleCard.isSelected ? Colors.overPrimary : Colors.outline
                                                opacity: styleCard.isSelected ? 0.85 : 1.0
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Text {
                                            visible: styleCard.isSelected
                                            text: Icons.accept
                                            font.family: Icons.font
                                            font.pixelSize: 16
                                            color: Colors.overPrimary
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Row with Section 1 (Easing Curve) & Section 2 (Animation Duration)
                RowLayout {
                    id: sectionEasingAndDuration
                    Layout.fillWidth: true
                    spacing: 14

                    // Section 1: Easing Curves
                    ColumnLayout {
                        id: sectionEasing
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "EASING CURVE"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Bold
                                color: root.currentSection === 1 ? Colors.primary : Colors.overBackground
                            }

                            Item { Layout.fillWidth: true }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: 6
                            columnSpacing: 6

                            Repeater {
                                model: root.easingOptions

                                delegate: StyledRect {
                                    id: easeCard
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 48

                                    readonly property bool isSelected: modelData.id === root.currentEasing
                                    readonly property bool isFocused: root.currentSection === 1 && root.focusedEasingIndex === index

                                    variant: isSelected ? "primary" : ((maEase.containsMouse || isFocused) ? "focus" : "pane")
                                    radius: Styling.radius(4)

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.color: easeCard.isSelected ? Colors.overPrimary : Colors.primary
                                        border.width: 2
                                        radius: Styling.radius(4)
                                        visible: easeCard.isFocused
                                    }

                                    MouseArea {
                                        id: maEase
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.currentSection = 1;
                                            root.focusedEasingIndex = index;
                                            root.updateSetting("easingCurve", modelData.id);
                                        }
                                        onWheel: (wheel) => root.scrollBy(-((wheel.pixelDelta && wheel.pixelDelta.y !== 0) ? wheel.pixelDelta.y : wheel.angleDelta.y))

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 6

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0

                                                Text {
                                                    text: modelData.title
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-1)
                                                    font.weight: easeCard.isSelected ? Font.Bold : Font.Medium
                                                    color: easeCard.isSelected ? Colors.overPrimary : Colors.overBackground
                                                    elide: Text.ElideRight
                                                }

                                                MarqueeText {
                                                    Layout.fillWidth: true
                                                    text: modelData.desc
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-3)
                                                    color: easeCard.isSelected ? Colors.overPrimary : Colors.outline
                                                    textOpacity: easeCard.isSelected ? 0.85 : 1.0
                                                    hovered: maEase.containsMouse
                                                    isSelected: easeCard.isSelected
                                                }
                                            }

                                            Text {
                                                visible: easeCard.isSelected
                                                text: Icons.accept
                                                font.family: Icons.font
                                                font.pixelSize: 14
                                                color: Colors.overPrimary
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Section 2: Duration Column
                    ColumnLayout {
                        id: sectionDuration
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "ANIMATION DURATION"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Bold
                                color: root.currentSection === 2 ? Colors.primary : Colors.overBackground
                            }

                            Item { Layout.fillWidth: true }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            spacing: 6

                            Repeater {
                                model: root.speedOptions

                                delegate: StyledRect {
                                    id: speedCard
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    readonly property bool isSelected: Math.abs(root.currentDuration - modelData.value) < 50
                                    readonly property bool isFocused: root.currentSection === 2 && root.focusedSpeedIndex === index

                                    variant: isSelected ? "primary" : ((maSpeed.containsMouse || isFocused) ? "focus" : "pane")
                                    radius: Styling.radius(4)

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.color: speedCard.isSelected ? Colors.overPrimary : Colors.primary
                                        border.width: 2
                                        radius: Styling.radius(4)
                                        visible: speedCard.isFocused
                                    }

                                    MouseArea {
                                        id: maSpeed
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.currentSection = 2;
                                            root.focusedSpeedIndex = index;
                                            root.updateSetting("duration", modelData.value);
                                        }
                                        onWheel: (wheel) => root.scrollBy(-((wheel.pixelDelta && wheel.pixelDelta.y !== 0) ? wheel.pixelDelta.y : wheel.angleDelta.y))

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 4

                                            Text {
                                                text: modelData.label
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-1)
                                                font.weight: speedCard.isSelected ? Font.Bold : Font.Medium
                                                color: speedCard.isSelected ? Colors.overPrimary : Colors.overSurface
                                            }

                                            Text {
                                                text: "(" + modelData.sub + ")"
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-3)
                                                color: speedCard.isSelected ? Colors.overPrimary : Colors.outline
                                                opacity: speedCard.isSelected ? 0.85 : 1.0
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Hint under speed options
                        Text {
                            text: "Controls how briskly or leisurely wallpaper dissolves transition."
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-3)
                            color: Colors.outline
                            Layout.topMargin: 4
                        }
                    }
                }

                // Section 3: AUTOMATION & ROTATION (New feature requested by community)
                ColumnLayout {
                    id: sectionAutomation
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "AUTOMATION & ROTATION"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            font.weight: Font.Bold
                            color: root.currentSection === 3 ? Colors.primary : Colors.overBackground
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "CLI / Keybind: ambxst run wallpaper-random"
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.fontSize(-4)
                            color: Colors.primary
                        }
                    }

                    // Card 1: Automatic Wallpaper Rotation
                    StyledRect {
                        id: periodicCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: periodicColumn.implicitHeight + 20
                        readonly property bool isPeriodic: GlobalStates && GlobalStates.wallpaperPeriodicEnabled
                        readonly property int periodicSec: root.currentPeriodicSeconds
                        variant: "pane"
                        radius: Styling.radius(4)

                        ColumnLayout {
                            id: periodicColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            // Row 1: Header + Master Toggle
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Item {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.timer
                                        font.family: Icons.font
                                        font.pixelSize: 22
                                        color: periodicCard.isPeriodic ? Colors.primary : Colors.overSurface
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: "Automatic Rotation"
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(0)
                                        font.weight: Font.Bold
                                        color: Colors.overBackground
                                    }

                                    Text {
                                        text: periodicCard.isPeriodic ? ("Rotates every " + root.formatDuration(periodicCard.periodicSec)) : "Automatic rotation disabled"
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-3)
                                        color: periodicCard.isPeriodic ? Colors.primary : Colors.outline
                                        elide: Text.ElideRight
                                    }
                                }

                                Switch {
                                    id: periodicSwitch
                                    checked: periodicCard.isPeriodic
                                    focusPolicy: Qt.NoFocus
                                    onToggled: {
                                        root.currentSection = 3;
                                        root.focusedAutomationIndex = 0;
                                        if (GlobalStates) GlobalStates.setWallpaperPeriodicEnabled(checked);
                                    }
                                }
                            }

                            // Divider
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: Colors.outline
                                opacity: 0.15
                            }

                            // Presets Row + Dedicated Custom Timer Button
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                opacity: periodicCard.isPeriodic ? 1.0 : 0.45

                                Repeater {
                                    model: root.intervalOptions

                                    delegate: StyledRect {
                                        id: intCard
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36

                                        readonly property bool isSelected: !root.showCustomInput && periodicCard.periodicSec === modelData.sec
                                        readonly property bool isFocused: root.currentSection === 3 && root.focusedAutomationIndex === (index + 1)
                                        variant: isSelected ? "primary" : ((maInt.containsMouse || isFocused) ? "focus" : "pane")
                                        radius: Styling.radius(3)

                                        Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"
                                            border.color: intCard.isSelected ? Colors.overPrimary : Colors.primary
                                            border.width: 2
                                            radius: Styling.radius(3)
                                            visible: intCard.isFocused
                                        }

                                        MouseArea {
                                            id: maInt
                                            anchors.fill: parent
                                            hoverEnabled: periodicCard.isPeriodic
                                            cursorShape: periodicCard.isPeriodic ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: {
                                                root.showCustomInput = false;
                                                root.currentSection = 3;
                                                root.focusedAutomationIndex = index + 1;
                                                if (!periodicCard.isPeriodic && GlobalStates) {
                                                    GlobalStates.setWallpaperPeriodicEnabled(true);
                                                }
                                                if (GlobalStates) GlobalStates.setWallpaperPeriodicSeconds(modelData.sec);
                                            }
                                            onWheel: (wheel) => root.scrollBy(-((wheel.pixelDelta && wheel.pixelDelta.y !== 0) ? wheel.pixelDelta.y : wheel.angleDelta.y))

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.text
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-2)
                                                font.weight: intCard.isSelected ? Font.Bold : Font.Medium
                                                color: intCard.isSelected ? Colors.overPrimary : Colors.overSurface
                                            }
                                        }
                                    }
                                }

                                // Distinct Dedicated Button: Custom Timer
                                StyledRect {
                                    id: customTimerButton
                                    Layout.preferredWidth: customBtnLayout.implicitWidth + 24
                                    Layout.preferredHeight: 36
                                    readonly property bool isCustomActive: !root.isStandardPreset(periodicCard.periodicSec)
                                    readonly property bool isHighlighted: root.showCustomInput || isCustomActive
                                    readonly property bool isFocused: root.currentSection === 3 && root.focusedAutomationIndex === 7
                                    variant: isHighlighted ? "primary" : ((maCustomBtn.containsMouse || isFocused) ? "focus" : "pane")
                                    radius: Styling.radius(3)

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.color: customTimerButton.isHighlighted ? Colors.overPrimary : Colors.primary
                                        border.width: 2
                                        radius: Styling.radius(3)
                                        visible: customTimerButton.isFocused
                                    }

                                    MouseArea {
                                        id: maCustomBtn
                                        anchors.fill: parent
                                        hoverEnabled: periodicCard.isPeriodic
                                        cursorShape: periodicCard.isPeriodic ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            root.currentSection = 3;
                                            root.focusedAutomationIndex = 7;
                                            root.showCustomInput = !root.showCustomInput;
                                            if (root.showCustomInput) {
                                                root.initCustomInput();
                                            }
                                        }
                                        onWheel: (wheel) => root.scrollBy(-((wheel.pixelDelta && wheel.pixelDelta.y !== 0) ? wheel.pixelDelta.y : wheel.angleDelta.y))

                                        RowLayout {
                                            id: customBtnLayout
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                text: Icons.timer || "⏱"
                                                font.family: Icons.font
                                                font.pixelSize: 13
                                                color: customTimerButton.isHighlighted ? Colors.overPrimary : Colors.primary
                                            }

                                            Text {
                                                text: customTimerButton.isCustomActive ? ("Custom (" + root.formatDuration(periodicCard.periodicSec) + ")") : "Custom Timer..."
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-2)
                                                font.weight: customTimerButton.isHighlighted ? Font.Bold : Font.Medium
                                                color: customTimerButton.isHighlighted ? Colors.overPrimary : Colors.overSurface
                                            }

                                            Text {
                                                text: root.showCustomInput ? "▲" : "▼"
                                                font.family: Config.theme.font
                                                font.pixelSize: 10
                                                color: customTimerButton.isHighlighted ? Colors.overPrimary : Colors.outline
                                            }
                                        }
                                    }
                                }
                            }

                            // Dedicated Custom Timer Configuration Card
                            StyledRect {
                                id: customBuilderCard
                                Layout.fillWidth: true
                                Layout.preferredHeight: customBuilderCol.implicitHeight + 20
                                visible: root.showCustomInput || !root.isStandardPreset(periodicCard.periodicSec)
                                variant: "pane"
                                radius: Styling.radius(4)

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: Colors.primary
                                    border.width: 1
                                    opacity: 0.25
                                    radius: Styling.radius(4)
                                }

                                ColumnLayout {
                                    id: customBuilderCol
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10

                                    // Header
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: Icons.timer || "⏱"
                                            font.family: Icons.font
                                            font.pixelSize: 14
                                            color: Colors.primary
                                        }

                                        Text {
                                            text: "CUSTOM ROTATION INTERVAL"
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-2)
                                            font.weight: Font.Bold
                                            color: Colors.primary
                                        }

                                        Item { Layout.fillWidth: true }

                                        StyledRect {
                                            Layout.preferredHeight: 22
                                            Layout.preferredWidth: activeDurText.implicitWidth + 14
                                            variant: "focus"
                                            radius: Styling.radius(1)

                                            Text {
                                                id: activeDurText
                                                anchors.centerIn: parent
                                                text: "Active: Every " + root.formatDuration(periodicCard.periodicSec)
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-3)
                                                font.weight: Font.Bold
                                                color: Colors.primary
                                            }
                                        }
                                    }

                                    // Stepper Containers Row + Apply Button
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        // 1. Hours Stepper Card
                                        StyledRect {
                                            Layout.preferredWidth: 140
                                            Layout.preferredHeight: 64
                                            variant: "common"
                                            radius: Styling.radius(3)

                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 3

                                                Text {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: "HOURS"
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-4)
                                                    font.weight: Font.Bold
                                                    color: Colors.outline
                                                }

                                                RowLayout {
                                                    spacing: 6

                                                    // [-] Button
                                                    StyledRect {
                                                        Layout.preferredWidth: 32
                                                        Layout.preferredHeight: 32
                                                        variant: maHMinus.containsMouse ? "primary" : "focus"
                                                        radius: Styling.radius(2)

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            color: "transparent"
                                                            border.color: Colors.primary
                                                            border.width: 1
                                                            opacity: maHMinus.containsMouse ? 1.0 : 0.35
                                                            radius: Styling.radius(2)
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: Icons.minus
                                                            font.family: Icons.font
                                                            font.pixelSize: 14
                                                            font.bold: true
                                                            color: maHMinus.containsMouse ? Colors.overPrimary : Colors.primary
                                                        }

                                                        MouseArea {
                                                            id: maHMinus
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: { root.customHours = Math.max(0, root.customHours - 1); }
                                                        }
                                                    }

                                                    // Number Input Box
                                                    TextField {
                                                        id: inputHours
                                                        Layout.preferredWidth: 46
                                                        Layout.preferredHeight: 32
                                                        text: String(root.customHours)
                                                        horizontalAlignment: TextInput.AlignHCenter
                                                        font.family: Config.theme.monoFont
                                                        font.pixelSize: Styling.fontSize(1)
                                                        font.weight: Font.Bold
                                                        color: Colors.overBackground
                                                        validator: IntValidator { bottom: 0; top: 23 }
                                                        selectByMouse: true
                                                        Binding on text {
                                                            value: String(root.customHours)
                                                            when: !inputHours.activeFocus
                                                        }
                                                        background: StyledRect {
                                                            variant: inputHours.activeFocus ? "focus" : "pane"
                                                            radius: Styling.radius(2)
                                                            Rectangle {
                                                                anchors.fill: parent
                                                                color: "transparent"
                                                                border.color: inputHours.activeFocus ? Colors.primary : Colors.outline
                                                                border.width: 1
                                                                opacity: inputHours.activeFocus ? 1.0 : 0.25
                                                                radius: Styling.radius(2)
                                                            }
                                                        }
                                                        onTextChanged: {
                                                            let val = parseInt(text);
                                                            if (!isNaN(val) && val >= 0 && val <= 23) root.customHours = val;
                                                        }
                                                    }

                                                    // [+] Button
                                                    StyledRect {
                                                        Layout.preferredWidth: 32
                                                        Layout.preferredHeight: 32
                                                        variant: maHPlus.containsMouse ? "primary" : "focus"
                                                        radius: Styling.radius(2)

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            color: "transparent"
                                                            border.color: Colors.primary
                                                            border.width: 1
                                                            opacity: maHPlus.containsMouse ? 1.0 : 0.35
                                                            radius: Styling.radius(2)
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: Icons.plus
                                                            font.family: Icons.font
                                                            font.pixelSize: 14
                                                            font.bold: true
                                                            color: maHPlus.containsMouse ? Colors.overPrimary : Colors.primary
                                                        }

                                                        MouseArea {
                                                            id: maHPlus
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: { root.customHours = Math.min(23, root.customHours + 1); }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // 2. Minutes Stepper Card
                                        StyledRect {
                                            Layout.preferredWidth: 140
                                            Layout.preferredHeight: 64
                                            variant: "common"
                                            radius: Styling.radius(3)

                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 3

                                                Text {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: "MINUTES"
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-4)
                                                    font.weight: Font.Bold
                                                    color: Colors.outline
                                                }

                                                RowLayout {
                                                    spacing: 6

                                                    // [-] Button
                                                    StyledRect {
                                                        Layout.preferredWidth: 32
                                                        Layout.preferredHeight: 32
                                                        variant: maMMinus.containsMouse ? "primary" : "focus"
                                                        radius: Styling.radius(2)

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            color: "transparent"
                                                            border.color: Colors.primary
                                                            border.width: 1
                                                            opacity: maMMinus.containsMouse ? 1.0 : 0.35
                                                            radius: Styling.radius(2)
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: Icons.minus
                                                            font.family: Icons.font
                                                            font.pixelSize: 14
                                                            font.bold: true
                                                            color: maMMinus.containsMouse ? Colors.overPrimary : Colors.primary
                                                        }

                                                        MouseArea {
                                                            id: maMMinus
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: { root.customMinutes = Math.max(0, root.customMinutes - 1); }
                                                        }
                                                    }

                                                    // Number Input Box
                                                    TextField {
                                                        id: inputMinutes
                                                        Layout.preferredWidth: 46
                                                        Layout.preferredHeight: 32
                                                        text: String(root.customMinutes)
                                                        horizontalAlignment: TextInput.AlignHCenter
                                                        font.family: Config.theme.monoFont
                                                        font.pixelSize: Styling.fontSize(1)
                                                        font.weight: Font.Bold
                                                        color: Colors.overBackground
                                                        validator: IntValidator { bottom: 0; top: 59 }
                                                        selectByMouse: true
                                                        Binding on text {
                                                            value: String(root.customMinutes)
                                                            when: !inputMinutes.activeFocus
                                                        }
                                                        background: StyledRect {
                                                            variant: inputMinutes.activeFocus ? "focus" : "pane"
                                                            radius: Styling.radius(2)
                                                            Rectangle {
                                                                anchors.fill: parent
                                                                color: "transparent"
                                                                border.color: inputMinutes.activeFocus ? Colors.primary : Colors.outline
                                                                border.width: 1
                                                                opacity: inputMinutes.activeFocus ? 1.0 : 0.25
                                                                radius: Styling.radius(2)
                                                            }
                                                        }
                                                        onTextChanged: {
                                                            let val = parseInt(text);
                                                            if (!isNaN(val) && val >= 0 && val <= 59) root.customMinutes = val;
                                                        }
                                                    }

                                                    // [+] Button
                                                    StyledRect {
                                                        Layout.preferredWidth: 32
                                                        Layout.preferredHeight: 32
                                                        variant: maMPlus.containsMouse ? "primary" : "focus"
                                                        radius: Styling.radius(2)

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            color: "transparent"
                                                            border.color: Colors.primary
                                                            border.width: 1
                                                            opacity: maMPlus.containsMouse ? 1.0 : 0.35
                                                            radius: Styling.radius(2)
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: Icons.plus
                                                            font.family: Icons.font
                                                            font.pixelSize: 14
                                                            font.bold: true
                                                            color: maMPlus.containsMouse ? Colors.overPrimary : Colors.primary
                                                        }

                                                        MouseArea {
                                                            id: maMPlus
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: { root.customMinutes = Math.min(59, root.customMinutes + 1); }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // 3. Seconds Stepper Card
                                        StyledRect {
                                            Layout.preferredWidth: 140
                                            Layout.preferredHeight: 64
                                            variant: "common"
                                            radius: Styling.radius(3)

                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 3

                                                Text {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: "SECONDS"
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-4)
                                                    font.weight: Font.Bold
                                                    color: Colors.outline
                                                }

                                                RowLayout {
                                                    spacing: 6

                                                    // [-] Button
                                                    StyledRect {
                                                        Layout.preferredWidth: 32
                                                        Layout.preferredHeight: 32
                                                        variant: maSMinus.containsMouse ? "primary" : "focus"
                                                        radius: Styling.radius(2)

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            color: "transparent"
                                                            border.color: Colors.primary
                                                            border.width: 1
                                                            opacity: maSMinus.containsMouse ? 1.0 : 0.35
                                                            radius: Styling.radius(2)
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: Icons.minus
                                                            font.family: Icons.font
                                                            font.pixelSize: 14
                                                            font.bold: true
                                                            color: maSMinus.containsMouse ? Colors.overPrimary : Colors.primary
                                                        }

                                                        MouseArea {
                                                            id: maSMinus
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: { root.customSeconds = Math.max(0, root.customSeconds - 1); }
                                                        }
                                                    }

                                                    // Number Input Box
                                                    TextField {
                                                        id: inputSeconds
                                                        Layout.preferredWidth: 46
                                                        Layout.preferredHeight: 32
                                                        text: String(root.customSeconds)
                                                        horizontalAlignment: TextInput.AlignHCenter
                                                        font.family: Config.theme.monoFont
                                                        font.pixelSize: Styling.fontSize(1)
                                                        font.weight: Font.Bold
                                                        color: Colors.overBackground
                                                        validator: IntValidator { bottom: 0; top: 59 }
                                                        selectByMouse: true
                                                        Binding on text {
                                                            value: String(root.customSeconds)
                                                            when: !inputSeconds.activeFocus
                                                        }
                                                        background: StyledRect {
                                                            variant: inputSeconds.activeFocus ? "focus" : "pane"
                                                            radius: Styling.radius(2)
                                                            Rectangle {
                                                                anchors.fill: parent
                                                                color: "transparent"
                                                                border.color: inputSeconds.activeFocus ? Colors.primary : Colors.outline
                                                                border.width: 1
                                                                opacity: inputSeconds.activeFocus ? 1.0 : 0.25
                                                                radius: Styling.radius(2)
                                                            }
                                                        }
                                                        onTextChanged: {
                                                            let val = parseInt(text);
                                                            if (!isNaN(val) && val >= 0 && val <= 59) root.customSeconds = val;
                                                        }
                                                    }

                                                    // [+] Button
                                                    StyledRect {
                                                        Layout.preferredWidth: 32
                                                        Layout.preferredHeight: 32
                                                        variant: maSPlus.containsMouse ? "primary" : "focus"
                                                        radius: Styling.radius(2)

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            color: "transparent"
                                                            border.color: Colors.primary
                                                            border.width: 1
                                                            opacity: maSPlus.containsMouse ? 1.0 : 0.35
                                                            radius: Styling.radius(2)
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: Icons.plus
                                                            font.family: Icons.font
                                                            font.pixelSize: 14
                                                            font.bold: true
                                                            color: maSPlus.containsMouse ? Colors.overPrimary : Colors.primary
                                                        }

                                                        MouseArea {
                                                            id: maSPlus
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: { root.customSeconds = Math.min(59, root.customSeconds + 1); }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        // Apply Custom Timer Button
                                        StyledRect {
                                            id: applyBtn
                                            Layout.preferredHeight: 48
                                            Layout.preferredWidth: applyBtnLayout.implicitWidth + 28
                                            variant: maApply.containsMouse ? "focus" : "primary"
                                            radius: Styling.radius(3)

                                            MouseArea {
                                                id: maApply
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.applyCustomTimer()

                                                RowLayout {
                                                    id: applyBtnLayout
                                                    anchors.centerIn: parent
                                                    spacing: 8

                                                    Text {
                                                        text: Icons.accept
                                                        font.family: Icons.font
                                                        font.pixelSize: 16
                                                        color: applyBtn.variant === "primary" ? Colors.overPrimary : Colors.primary
                                                    }

                                                    ColumnLayout {
                                                        spacing: 0
                                                        Text {
                                                            text: "Set Timer"
                                                            font.family: Config.theme.font
                                                            font.pixelSize: Styling.fontSize(0)
                                                            font.weight: Font.Bold
                                                            color: applyBtn.variant === "primary" ? Colors.overPrimary : Colors.primary
                                                        }
                                                        Text {
                                                            text: root.formatDuration(Math.max(5, (root.customHours * 3600) + (root.customMinutes * 60) + root.customSeconds))
                                                            font.family: Config.theme.font
                                                            font.pixelSize: Styling.fontSize(-3)
                                                            color: applyBtn.variant === "primary" ? Colors.overPrimary : Colors.primary
                                                            opacity: 0.85
                                                        }
                                                    }
                                                }
                                            }
                                    }
                                }
                                }
                            }
                        }
                    }

                    // Card 2: Match Time of the Day (SEPARATE TOGGLE BUTTON / FEATURE)
                    StyledRect {
                        id: solarCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: solarColumn.implicitHeight + 20
                        variant: "pane"
                        radius: Styling.radius(4)

                        ColumnLayout {
                            id: solarColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            // Row 1: Header + Independent Master Toggle
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Item {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.getSolarPhaseInfo(root.currentSolarPeriod).icon
                                        font.family: Icons.font
                                        font.pixelSize: 22
                                        color: root.isSolarSync ? Colors.primary : Colors.overSurface
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    RowLayout {
                                        spacing: 8
                                        Text {
                                            text: "Match Time of Day"
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(0)
                                            font.weight: Font.Bold
                                            color: Colors.overBackground
                                        }

                                        StyledRect {
                                            Layout.preferredHeight: 18
                                            Layout.preferredWidth: curPhaseBadgeText.implicitWidth + 10
                                            variant: root.isSolarSync ? "primary" : "focus"
                                            radius: Styling.radius(1)

                                            Text {
                                                id: curPhaseBadgeText
                                                anchors.centerIn: parent
                                                text: (root.currentSolarPeriod.toUpperCase()) + " NOW"
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-4)
                                                font.weight: Font.Bold
                                                color: root.isSolarSync ? Colors.overPrimary : Colors.primary
                                            }
                                        }
                                    }

                                    Text {
                                        text: root.isSolarSync ? "Active: Selecting wallpapers matching current " + root.currentSolarPeriod + " lighting" : "Disabled: Wallpaper rotation selects from all color palettes"
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-3)
                                        color: root.isSolarSync ? Colors.primary : Colors.outline
                                        elide: Text.ElideRight
                                    }
                                }

                                Switch {
                                    id: solarSwitch
                                    checked: root.isSolarSync
                                    focusPolicy: Qt.NoFocus
                                    onToggled: {
                                        if (GlobalStates) GlobalStates.setWallpaperSolarSyncEnabled(checked);
                                    }
                                }
                            }

                            // Divider
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: Colors.outline
                                opacity: 0.15
                            }

                            // 4 Solar Phase Cards Strip
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 4
                                rowSpacing: 6
                                columnSpacing: 6
                                opacity: root.isSolarSync ? 1.0 : 0.55

                                Repeater {
                                    model: [
                                        { id: "morning", title: "Morning", time: "06:00 – 11:00", icon: Icons.sunDim, desc: "Fresh daylight & bright pastels" },
                                        { id: "afternoon", title: "Afternoon", time: "11:00 – 17:00", icon: Icons.sun, desc: "Warm, bright & vibrant daylight" },
                                        { id: "sunset", title: "Sunset", time: "17:00 – 21:00", icon: Icons.sunDim, desc: "Golden hour, warm orange & dusk" },
                                        { id: "night", title: "Night", time: "21:00 – 06:00", icon: Icons.moon, desc: "Dark, starry night & deep tones" }
                                    ]

                                    delegate: StyledRect {
                                        id: phaseMiniCard
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 74

                                        readonly property bool isCurrent: root.currentSolarPeriod === modelData.id
                                        readonly property int matchingCount: root.getSolarCount(modelData.id)
                                        variant: isCurrent ? "focus" : "pane"
                                        radius: Styling.radius(3)

                                        Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"
                                            border.color: Colors.primary
                                            border.width: phaseMiniCard.isCurrent ? 2 : 0
                                            radius: Styling.radius(3)
                                            visible: phaseMiniCard.isCurrent
                                        }

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            spacing: 2

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 4

                                                Text {
                                                    text: modelData.icon
                                                    font.family: Icons.font
                                                    font.pixelSize: 14
                                                    color: phaseMiniCard.isCurrent ? Colors.primary : Colors.overBackground
                                                }

                                                Text {
                                                    text: modelData.title
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-1)
                                                    font.weight: Font.Bold
                                                    color: Colors.overBackground
                                                }

                                                Item { Layout.fillWidth: true }

                                                StyledRect {
                                                    visible: phaseMiniCard.isCurrent
                                                    Layout.preferredHeight: 16
                                                    Layout.preferredWidth: livePillText.implicitWidth + 6
                                                    variant: "primary"
                                                    radius: Styling.radius(1)
                                                    Text {
                                                        id: livePillText
                                                        anchors.centerIn: parent
                                                        text: "ACTIVE"
                                                        font.family: Config.theme.font
                                                        font.pixelSize: Styling.fontSize(-5)
                                                        font.weight: Font.Bold
                                                        color: Colors.overPrimary
                                                    }
                                                }
                                            }

                                            Text {
                                                text: modelData.time
                                                font.family: Config.theme.monoFont
                                                font.pixelSize: Styling.fontSize(-4)
                                                color: Colors.outline
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.desc
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-4)
                                                color: Colors.outline
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: phaseMiniCard.matchingCount > 0 ? (phaseMiniCard.matchingCount + " wallpapers match") : "Keywords fallback"
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-4)
                                                font.weight: Font.Medium
                                                color: phaseMiniCard.isCurrent ? Colors.primary : Colors.overSurface
                                            }
                                        }
                                    }
                                }
                            }

                            // Footer row: info note + re-index button
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    Layout.fillWidth: true
                                    text: "Palette matching applies to both automatic rotation and shortcut triggers (ambxst run wallpaper-random)."
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-3)
                                    color: Colors.outline
                                }

                                StyledRect {
                                    id: refreshIndexBtn
                                    Layout.preferredHeight: 28
                                    Layout.preferredWidth: refreshText.implicitWidth + 18
                                    variant: maRef.containsMouse ? "focus" : "pane"
                                    radius: Styling.radius(2)

                                    MouseArea {
                                        id: maRef
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (GlobalStates) GlobalStates.refreshSolarCache();
                                        }

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 4

                                            Text {
                                                text: "↻"
                                                font.family: Config.theme.font
                                                font.pixelSize: 12
                                                color: Colors.primary
                                            }

                                            Text {
                                                id: refreshText
                                                text: "Re-index Colors"
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-3)
                                                font.weight: Font.Medium
                                                color: Colors.overBackground
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Card 2: Random Wallpaper Sources & Directories Pool
                    StyledRect {
                        id: poolCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: poolColumn.implicitHeight + 20
                        variant: "pane"
                        radius: Styling.radius(4)

                        ColumnLayout {
                            id: poolColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: Icons.folder
                                    font.family: Icons.font
                                    font.pixelSize: 18
                                    color: Colors.primary
                                }

                                Text {
                                    text: "Random Rotation Sources"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    font.weight: Font.Bold
                                    color: Colors.overBackground
                                }

                                Text {
                                    text: "• Select directories & types for shuffle and periodic rotation (empty = all)"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-3)
                                    color: Colors.outline
                                }

                                Item { Layout.fillWidth: true }

                                // Wallpaper count badge
                                StyledRect {
                                    Layout.preferredHeight: 26
                                    Layout.preferredWidth: countText.implicitWidth + 20
                                    variant: "focus"
                                    radius: Styling.radius(2)

                                    Text {
                                        id: countText
                                        anchors.centerIn: parent
                                        text: root.matchingCountText
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-3)
                                        font.weight: Font.Medium
                                        color: Colors.primary
                                    }
                                }
                            }

                            // Flow of source chips
                            Flow {
                                id: sourceChipsFlow
                                Layout.fillWidth: true
                                spacing: 6

                                // "All Wallpapers" chip (index: 9)
                                StyledRect {
                                    id: allChip
                                    readonly property bool isSelected: !GlobalStates || !GlobalStates.wallpaperRandomSourceFilters || GlobalStates.wallpaperRandomSourceFilters.length === 0
                                    readonly property bool isFocused: root.currentSection === 3 && root.focusedAutomationIndex === 9
                                    variant: isSelected ? "primary" : ((allMa.containsMouse || isFocused) ? "focus" : "pane")
                                    radius: Styling.radius(3)
                                    height: 32
                                    width: allRow.implicitWidth + 18

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.color: allChip.isSelected ? Colors.overPrimary : Colors.primary
                                        border.width: 2
                                        radius: Styling.radius(3)
                                        visible: allChip.isFocused
                                    }

                                    MouseArea {
                                        id: allMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.currentSection = 3;
                                            root.focusedAutomationIndex = 9;
                                            if (GlobalStates) GlobalStates.setWallpaperRandomSourceFilters([]);
                                        }
                                        onWheel: (wheel) => root.scrollBy(-((wheel.pixelDelta && wheel.pixelDelta.y !== 0) ? wheel.pixelDelta.y : wheel.angleDelta.y))

                                        RowLayout {
                                            id: allRow
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                text: allChip.isSelected ? Icons.accept : Icons.sparkle
                                                font.family: Icons.font
                                                font.pixelSize: 14
                                                color: allChip.isSelected ? Colors.overPrimary : Colors.primary
                                            }

                                            Text {
                                                text: "All Wallpapers"
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-2)
                                                font.weight: allChip.isSelected ? Font.Bold : Font.Medium
                                                color: allChip.isSelected ? Colors.overPrimary : Colors.overBackground
                                            }
                                        }
                                    }
                                }

                                // Base Types & Subfolders Repeater
                                Repeater {
                                    id: sourceRepeater
                                    model: root.availableSourceOptions

                                    delegate: StyledRect {
                                        id: chipCard
                                        required property var modelData
                                        required property int index
                                        readonly property int itemIndex: 10 + index

                                        readonly property bool isSelected: (GlobalStates && GlobalStates.wallpaperRandomSourceFilters && GlobalStates.wallpaperRandomSourceFilters.includes(modelData.key))
                                        readonly property bool isFocused: root.currentSection === 3 && root.focusedAutomationIndex === itemIndex

                                        variant: isSelected ? "primary" : ((maChip.containsMouse || isFocused) ? "focus" : "pane")
                                        radius: Styling.radius(3)
                                        height: 32
                                        width: chipRow.implicitWidth + 18

                                        Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"
                                            border.color: chipCard.isSelected ? Colors.overPrimary : Colors.primary
                                            border.width: 2
                                            radius: Styling.radius(3)
                                            visible: chipCard.isFocused
                                        }

                                        MouseArea {
                                            id: maChip
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.currentSection = 3;
                                                root.focusedAutomationIndex = itemIndex;
                                                if (GlobalStates) GlobalStates.toggleWallpaperRandomSourceFilter(modelData.key);
                                            }
                                            onWheel: (wheel) => root.scrollBy(-((wheel.pixelDelta && wheel.pixelDelta.y !== 0) ? wheel.pixelDelta.y : wheel.angleDelta.y))

                                            RowLayout {
                                                id: chipRow
                                                anchors.centerIn: parent
                                                spacing: 6

                                                Text {
                                                    text: chipCard.isSelected ? Icons.accept : modelData.icon
                                                    font.family: Icons.font
                                                    font.pixelSize: 14
                                                    color: chipCard.isSelected ? Colors.overPrimary : (modelData.isSubfolder ? Colors.primary : Colors.overSurface)
                                                }

                                                Text {
                                                    text: modelData.label
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-2)
                                                    font.weight: chipCard.isSelected ? Font.Bold : Font.Medium
                                                    color: chipCard.isSelected ? Colors.overPrimary : Colors.overBackground
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Card 3: Live Wallpaper Playback & Power Saving
                    StyledRect {
                        id: playbackPauseCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: 104
                        variant: "pane"
                        radius: Styling.radius(4)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: Icons.play
                                    font.family: Icons.font
                                    font.pixelSize: 18
                                    color: Colors.primary
                                }

                                Text {
                                    text: "Live Wallpaper Playback & Power Saving"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    font.weight: Font.Bold
                                    color: Colors.overBackground
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "Pauses live wallpaper to save VRAM and GPU resources"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-3)
                                    color: Colors.outline
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: root.pauseOptions

                                    delegate: StyledRect {
                                        id: pauseCard
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 52

                                        readonly property bool isSelected: modelData.id === root.currentPauseMode

                                        variant: isSelected ? "primary" : (maPause.containsMouse ? "focus" : "pane")
                                        radius: Styling.radius(3)

                                        MouseArea {
                                            id: maPause
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (GlobalStates) GlobalStates.setWallpaperPauseMode(modelData.id);
                                            }
                                            onWheel: (wheel) => root.scrollBy(-((wheel.pixelDelta && wheel.pixelDelta.y !== 0) ? wheel.pixelDelta.y : wheel.angleDelta.y))

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 8

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1

                                                    Text {
                                                        text: modelData.title
                                                        font.family: Config.theme.font
                                                        font.pixelSize: Styling.fontSize(-1)
                                                        font.weight: pauseCard.isSelected ? Font.Bold : Font.Medium
                                                        color: pauseCard.isSelected ? Colors.overPrimary : Colors.overBackground
                                                    }

                                                    MarqueeText {
                                                        Layout.fillWidth: true
                                                        text: modelData.sub
                                                        font.family: Config.theme.font
                                                        font.pixelSize: Styling.fontSize(-3)
                                                        color: pauseCard.isSelected ? Colors.overPrimary : Colors.outline
                                                        hovered: maPause.containsMouse
                                                        isSelected: pauseCard.isSelected
                                                    }
                                                }

                                                Text {
                                                    visible: pauseCard.isSelected
                                                    text: Icons.accept
                                                    font.family: Icons.font
                                                    font.pixelSize: 14
                                                    color: Colors.overPrimary
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Monitor Scope Selector
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                                spacing: 8

                                Text {
                                    text: "Pause Scope:"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.weight: Font.Bold
                                    color: Colors.overBackground
                                }

                                RowLayout {
                                    spacing: 6

                                    Repeater {
                                        model: [
                                            { id: "perScreen", title: "Current monitor only (Default)", icon: Icons.desktop },
                                            { id: "allScreens", title: "All monitors", icon: Icons.layoutGrid }
                                        ]

                                        StyledRect {
                                            id: scopeCard
                                            Layout.preferredHeight: 30
                                            Layout.preferredWidth: scopeLayout.implicitWidth + 20

                                            readonly property bool isSelected: root.currentPauseScope === modelData.id
                                            variant: isSelected ? "primary" : (maScope.containsMouse ? "focus" : "pane")
                                            radius: Styling.radius(3)

                                            MouseArea {
                                                id: maScope
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (GlobalStates) GlobalStates.setWallpaperPauseScope(modelData.id);
                                                }
                                                onWheel: (wheel) => root.scrollBy(-((wheel.pixelDelta && wheel.pixelDelta.y !== 0) ? wheel.pixelDelta.y : wheel.angleDelta.y))

                                                RowLayout {
                                                    id: scopeLayout
                                                    anchors.centerIn: parent
                                                    spacing: 6

                                                    Text {
                                                        text: modelData.icon
                                                        font.family: Icons.font
                                                        font.pixelSize: 13
                                                        color: scopeCard.isSelected ? Colors.overPrimary : Colors.primary
                                                    }

                                                    Text {
                                                        text: modelData.title
                                                        font.family: Config.theme.font
                                                        font.pixelSize: Styling.fontSize(-2)
                                                        font.weight: scopeCard.isSelected ? Font.Bold : Font.Medium
                                                        color: scopeCard.isSelected ? Colors.overPrimary : Colors.overSurface
                                                    }

                                                    Text {
                                                        visible: scopeCard.isSelected
                                                        text: Icons.accept
                                                        font.family: Icons.font
                                                        font.pixelSize: 12
                                                        color: Colors.overPrimary
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }
                        }
                    }
                }

                // Section 4: Material You Color Schemes
                ColumnLayout {
                    id: sectionSchemes
                    Layout.fillWidth: true
                    spacing: 6
                    readonly property bool isPresetActive: Boolean(GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.activeColorPreset)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "MATERIAL YOU COLOR SCHEMES"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            font.weight: Font.Bold
                            color: root.currentSection === 4 ? Colors.primary : Colors.overBackground
                        }

                        Text {
                            visible: sectionSchemes.isPresetActive
                            text: "(Preset active — click a scheme to enable)"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-3)
                            color: Colors.outline
                        }

                        Item { Layout.fillWidth: true }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4
                        rowSpacing: 6
                        columnSpacing: 6
                        opacity: sectionSchemes.isPresetActive ? 0.65 : 1.0

                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }

                        Repeater {
                            model: root.matugenSchemes

                            delegate: StyledRect {
                                id: schemeCard
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40

                                readonly property bool isSelected: !sectionSchemes.isPresetActive && (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.currentMatugenScheme === modelData.id)
                                readonly property bool isFocused: root.currentSection === 4 && root.focusedSchemeIndex === index

                                variant: isSelected ? "primary" : ((maScheme.containsMouse || isFocused) ? "focus" : "pane")
                                radius: Styling.radius(3)

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: schemeCard.isSelected ? Colors.overPrimary : Colors.primary
                                    border.width: 2
                                    radius: Styling.radius(3)
                                    visible: schemeCard.isFocused
                                }

                                MouseArea {
                                    id: maScheme
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentSection = 4;
                                        root.focusedSchemeIndex = index;
                                        if (GlobalStates.wallpaperManager) {
                                            GlobalStates.wallpaperManager.setMatugenScheme(modelData.id);
                                        }
                                    }
                                    onWheel: (wheel) => root.scrollBy(-((wheel.pixelDelta && wheel.pixelDelta.y !== 0) ? wheel.pixelDelta.y : wheel.angleDelta.y))

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            text: modelData.label
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            font.weight: schemeCard.isSelected ? Font.Bold : Font.Medium
                                            color: schemeCard.isSelected ? Colors.overPrimary : Colors.overSurface
                                        }

                                        Text {
                                            visible: schemeCard.isSelected
                                            text: Icons.accept
                                            font.family: Icons.font
                                            font.pixelSize: 14
                                            color: Colors.overPrimary
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Section 5: Color Presets (optional)
                ColumnLayout {
                    id: sectionPresets
                    visible: root.presets && root.presets.length > 0
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "COLOR PRESETS"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            font.weight: Font.Bold
                            color: root.currentSection === 5 ? Colors.primary : Colors.overBackground
                        }

                        Text {
                            visible: Boolean(GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.activeColorPreset)
                            text: "(Click active preset to toggle off)"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-3)
                            color: Colors.outline
                        }

                        Item { Layout.fillWidth: true }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4
                        rowSpacing: 6
                        columnSpacing: 6

                        Repeater {
                            model: root.presets

                            delegate: StyledRect {
                                id: presetCard
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38

                                readonly property bool isSelected: (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.activeColorPreset === String(modelData))
                                readonly property bool isFocused: root.currentSection === 5 && root.focusedPresetIndex === index

                                variant: isSelected ? "primary" : ((maPreset.containsMouse || isFocused) ? "focus" : "pane")
                                radius: Styling.radius(3)

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: presetCard.isSelected ? Colors.overPrimary : Colors.primary
                                    border.width: 2
                                    radius: Styling.radius(3)
                                    visible: presetCard.isFocused
                                }

                                MouseArea {
                                    id: maPreset
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentSection = 5;
                                        root.focusedPresetIndex = index;
                                        if (GlobalStates.wallpaperManager) {
                                            GlobalStates.wallpaperManager.setColorPreset(String(modelData));
                                        }
                                    }
                                    onWheel: (wheel) => root.scrollBy(-((wheel.pixelDelta && wheel.pixelDelta.y !== 0) ? wheel.pixelDelta.y : wheel.angleDelta.y))

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            text: String(modelData)
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            font.weight: presetCard.isSelected ? Font.Bold : Font.Medium
                                            color: presetCard.isSelected ? Colors.overPrimary : Colors.overSurface
                                        }

                                        Text {
                                            visible: presetCard.isSelected
                                            text: Icons.accept
                                            font.family: Icons.font
                                            font.pixelSize: 14
                                            color: Colors.overPrimary
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
