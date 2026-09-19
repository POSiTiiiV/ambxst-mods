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

    property string currentStyle: (GlobalStates && GlobalStates.wallpaperTransitionStyle) ? GlobalStates.wallpaperTransitionStyle : "crossfade"
    property string currentEasing: (GlobalStates && GlobalStates.wallpaperTransitionEasing) ? GlobalStates.wallpaperTransitionEasing : "cubic"
    property int currentDuration: (GlobalStates && GlobalStates.wallpaperTransitionDuration) ? GlobalStates.wallpaperTransitionDuration : 400

    readonly property string modId: "positive.wallpaper-transitions"

    // Active navigation section
    // 0: Transition Style, 1: Easing Curve, 2: Animation Duration, 3: Automation & Rotation,
    // 4: Display & Shader Effects, 5: Material You Schemes, 6: Color Presets, 7: Back Button
    property int currentSection: 0
    property int focusedStyleIndex: 0
    property int focusedEasingIndex: 0
    property int focusedSpeedIndex: 1
    property int focusedAutomationIndex: 0 // 0: Shuffle Now, 1: Periodic Toggle, 2-7: Intervals
    property int focusedEffectIndex: 0
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
        { label: "1m", text: "1 min", value: 1 },
        { label: "5m", text: "5 mins", value: 5 },
        { label: "15m", text: "15 mins", value: 15 },
        { label: "30m", text: "30 mins", value: 30 },
        { label: "1h", text: "1 hour", value: 60 },
        { label: "2h", text: "2 hours", value: 120 }
    ]

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
        let secs = [0, 1, 2, 3, 4, 5];
        if (root.presets && root.presets.length > 0) {
            secs.push(6);
        }
        secs.push(7);
        return secs;
    }

    function scrollToSection(sec) {
        if (sec === 0 || sec === 7) {
            smoothScrollTo(0);
            return;
        }
        let targetItem = null;
        if (sec === 1 || sec === 2) {
            targetItem = sectionEasingAndDuration;
        } else if (sec === 3) {
            targetItem = sectionAutomation;
        } else if (sec === 4) {
            targetItem = sectionEffects;
        } else if (sec === 5) {
            targetItem = sectionSchemes;
        } else if (sec === 6) {
            targetItem = sectionPresets;
        }

        if (targetItem) {
            let targetY = targetItem.y;
            let targetH = targetItem.height;
            let viewH = scrollArea.height;
            let maxScroll = Math.max(0, scrollArea.contentHeight - viewH);

            if (targetY < scrollArea.contentY) {
                smoothScrollTo(Math.max(0, targetY - 10));
            } else if (targetY + 60 > scrollArea.contentY + viewH) {
                smoothScrollTo(Math.min(maxScroll, targetY - 10));
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
            if (focusedAutomationIndex < 0 || focusedAutomationIndex > 7) {
                focusedAutomationIndex = 0;
            }
            break;
        case 4:
            if (focusedEffectIndex < 0 || focusedEffectIndex > 1) {
                focusedEffectIndex = 0;
            }
            break;
        case 5:
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
        case 6:
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
        case 7:
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
        case 7: // Back to Wallpapers button (at top)
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
                    currentSection = 7;
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
                    // Reached bottom of Easing Curve -> move down to Section 3 (Automation)
                    currentSection = 3;
                    focusedAutomationIndex = 0; // "Shuffle Now" (left side)
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
                // Move down to Section 3 (Automation & Rotation, right side: periodic toggle/intervals)
                currentSection = 3;
                focusedAutomationIndex = 1; // Periodic Rotation
            } else if (key === Qt.Key_Up) {
                // Move up to Transition Style (bottom row, right col: index 9)
                currentSection = 0;
                focusedStyleIndex = 9;
            }
            break;

        case 3: // Automation & Rotation (0: Shuffle, 1: Periodic Toggle, 2..7: Interval pills)
            if (key === Qt.Key_Right) {
                if (focusedAutomationIndex < 7) {
                    focusedAutomationIndex++;
                }
            } else if (key === Qt.Key_Left) {
                if (focusedAutomationIndex > 0) {
                    focusedAutomationIndex--;
                }
            } else if (key === Qt.Key_Down) {
                // Move down to Section 4 (Display & Shader Effects)
                currentSection = 4;
                if (focusedAutomationIndex === 0) {
                    focusedEffectIndex = 0; // OLED mode (left)
                } else {
                    focusedEffectIndex = 1; // Dynamic tint (right)
                }
            } else if (key === Qt.Key_Up) {
                // Move up to Easing (if left) or Duration (if right)
                if (focusedAutomationIndex === 0) {
                    currentSection = 1;
                    focusedEasingIndex = 4; // bottom row of Easing
                } else {
                    currentSection = 2;
                    focusedSpeedIndex = Math.min(Math.max(0, focusedAutomationIndex - 2), speedOptions.length - 1);
                }
            }
            break;

        case 4: // Display & Shader Effects (0: OLED, 1: Tint)
            if (key === Qt.Key_Right) {
                if (focusedEffectIndex === 0) {
                    focusedEffectIndex = 1;
                }
            } else if (key === Qt.Key_Left) {
                if (focusedEffectIndex === 1) {
                    focusedEffectIndex = 0;
                }
            } else if (key === Qt.Key_Down) {
                // Move down to Section 5 (Material You Schemes)
                currentSection = 5;
                if (focusedEffectIndex === 0) {
                    focusedSchemeIndex = 0;
                } else {
                    focusedSchemeIndex = 2;
                }
            } else if (key === Qt.Key_Up) {
                // Move up to Section 3 (Automation)
                currentSection = 3;
                if (focusedEffectIndex === 0) {
                    focusedAutomationIndex = 0; // Shuffle
                } else {
                    focusedAutomationIndex = 1; // Periodic toggle
                }
            }
            break;

        case 5: // Material You Schemes (8 items, 4 cols x 2 rows: 0..3, 4..7)
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
                        currentSection = 6;
                        focusedPresetIndex = Math.min(focusedSchemeIndex - 4, root.presets.length - 1);
                    }
                }
            } else if (key === Qt.Key_Up) {
                if (focusedSchemeIndex >= 4) {
                    focusedSchemeIndex -= 4;
                } else {
                    // Top row of schemes, move up to Section 4 (Effects)
                    currentSection = 4;
                    if (focusedSchemeIndex <= 1) {
                        focusedEffectIndex = 0; // OLED
                    } else {
                        focusedEffectIndex = 1; // Tint
                    }
                }
            }
            break;

        case 6: // Color Presets (4 cols x N rows)
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
                        // Top row of presets, move up to Section 5 (Schemes bottom row)
                        currentSection = 5;
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
                if (GlobalStates) GlobalStates.triggerRandomWallpaper();
            } else if (focusedAutomationIndex === 1) {
                if (GlobalStates) GlobalStates.setWallpaperPeriodicEnabled(!GlobalStates.wallpaperPeriodicEnabled);
            } else if (focusedAutomationIndex >= 2) {
                if (GlobalStates) {
                    if (!GlobalStates.wallpaperPeriodicEnabled) {
                        GlobalStates.setWallpaperPeriodicEnabled(true);
                    }
                    GlobalStates.setWallpaperPeriodicInterval(intervalOptions[focusedAutomationIndex - 2].value);
                }
            }
            break;
        case 4:
            if (focusedEffectIndex === 0) {
                Config.theme.oledMode = !Config.theme.oledMode;
            } else if (focusedEffectIndex === 1) {
                if (GlobalStates.wallpaperManager) {
                    GlobalStates.wallpaperManager.tintEnabled = !GlobalStates.wallpaperManager.tintEnabled;
                }
            }
            break;
        case 5:
            if (focusedSchemeIndex >= 0 && focusedSchemeIndex < matugenSchemes.length) {
                if (GlobalStates.wallpaperManager) {
                    GlobalStates.wallpaperManager.setMatugenScheme(matugenSchemes[focusedSchemeIndex].id);
                }
            }
            break;
        case 6:
            if (root.presets && focusedPresetIndex >= 0 && focusedPresetIndex < root.presets.length) {
                if (GlobalStates.wallpaperManager) {
                    GlobalStates.wallpaperManager.setColorPreset(String(root.presets[focusedPresetIndex]));
                }
            }
            break;
        case 7:
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
        }
    }

    onActiveFocusChanged: {
        if (activeFocus && visible) {
            syncSectionFocus(currentSection);
        }
    }

    Component.onCompleted: {
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
                readonly property bool isFocused: root.currentSection === 7
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
                    text: "Arrow keys navigate all settings & sub-panels • Enter/Space to apply • Tab to jump • Esc to return"
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
            contentHeight: settingsColumn.implicitHeight + 24
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
                    let delta = event.angleDelta.y;
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

                        StyledRect {
                            visible: root.currentSection === 0
                            variant: "focus"
                            Layout.preferredHeight: 18
                            Layout.preferredWidth: 54
                            radius: Styling.radius(2)

                            Text {
                                anchors.centerIn: parent
                                text: "ACTIVE"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-4)
                                font.weight: Font.Bold
                                color: Colors.primary
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            visible: root.currentSection === 0
                            text: "Arrow keys to navigate • Enter/Space to select • Esc to go back"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-4)
                            color: Colors.outline
                        }
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
                                    onWheel: (wheel) => root.scrollBy(-wheel.angleDelta.y)

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

                            StyledRect {
                                visible: root.currentSection === 1
                                variant: "focus"
                                Layout.preferredHeight: 18
                                Layout.preferredWidth: 54
                                radius: Styling.radius(2)

                                Text {
                                    anchors.centerIn: parent
                                    text: "ACTIVE"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-4)
                                    font.weight: Font.Bold
                                    color: Colors.primary
                                }
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
                                        onWheel: (wheel) => root.scrollBy(-wheel.angleDelta.y)

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

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.desc
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-3)
                                                    color: easeCard.isSelected ? Colors.overPrimary : Colors.outline
                                                    opacity: easeCard.isSelected ? 0.85 : 1.0
                                                    elide: Text.ElideRight
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

                            StyledRect {
                                visible: root.currentSection === 2
                                variant: "focus"
                                Layout.preferredHeight: 18
                                Layout.preferredWidth: 54
                                radius: Styling.radius(2)

                                Text {
                                    anchors.centerIn: parent
                                    text: "ACTIVE"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-4)
                                    font.weight: Font.Bold
                                    color: Colors.primary
                                }
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
                                        onWheel: (wheel) => root.scrollBy(-wheel.angleDelta.y)

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

                        StyledRect {
                            visible: root.currentSection === 3
                            variant: "focus"
                            Layout.preferredHeight: 18
                            Layout.preferredWidth: 54
                            radius: Styling.radius(2)

                            Text {
                                anchors.centerIn: parent
                                text: "ACTIVE"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-4)
                                font.weight: Font.Bold
                                color: Colors.primary
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "CLI / Keybind: ambxst run wallpaper-random"
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.fontSize(-4)
                            color: Colors.primary
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // Card 1: Shuffle Wallpaper Now Button
                        StyledRect {
                            id: shuffleCard
                            Layout.preferredWidth: 260
                            Layout.preferredHeight: 74
                            readonly property bool isFocused: root.currentSection === 3 && root.focusedAutomationIndex === 0
                            variant: isFocused || shuffleMa.containsMouse ? "primary" : "pane"
                            radius: Styling.radius(4)

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: Colors.primary
                                border.width: 2
                                radius: Styling.radius(4)
                                visible: shuffleCard.isFocused
                            }

                            MouseArea {
                                id: shuffleMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.currentSection = 3;
                                    root.focusedAutomationIndex = 0;
                                    if (GlobalStates) GlobalStates.triggerRandomWallpaper();
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    Text {
                                        text: Icons.shuffle
                                        font.family: Icons.font
                                        font.pixelSize: 26
                                        color: shuffleCard.isFocused || shuffleMa.containsMouse ? Colors.overPrimary : Colors.primary
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: "Shuffle Wallpaper Now"
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(0)
                                            font.weight: Font.Bold
                                            color: shuffleCard.isFocused || shuffleMa.containsMouse ? Colors.overPrimary : Colors.overBackground
                                        }

                                        Text {
                                            text: "Pick random wallpaper instantly"
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-3)
                                            color: shuffleCard.isFocused || shuffleMa.containsMouse ? Colors.overPrimary : Colors.outline
                                            opacity: 0.9
                                        }
                                    }
                                }
                            }
                        }

                        // Card 2: Periodic Wallpaper Rotation
                        StyledRect {
                            id: periodicCard
                            Layout.fillWidth: true
                            Layout.preferredHeight: 74
                            readonly property bool isPeriodic: GlobalStates && GlobalStates.wallpaperPeriodicEnabled
                            readonly property int periodicInt: GlobalStates ? GlobalStates.wallpaperPeriodicInterval : 15
                            variant: "pane"
                            radius: Styling.radius(4)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 14

                                // Toggle Area
                                StyledRect {
                                    id: periodicToggleRect
                                    Layout.preferredWidth: 230
                                    Layout.fillHeight: true
                                    readonly property bool isFocused: root.currentSection === 3 && root.focusedAutomationIndex === 1
                                    variant: isFocused || toggleMa.containsMouse ? "focus" : "pane"
                                    radius: Styling.radius(3)

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.color: Colors.primary
                                        border.width: 2
                                        radius: Styling.radius(3)
                                        visible: periodicToggleRect.isFocused
                                    }

                                    MouseArea {
                                        id: toggleMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.currentSection = 3;
                                            root.focusedAutomationIndex = 1;
                                            if (GlobalStates) GlobalStates.setWallpaperPeriodicEnabled(!periodicCard.isPeriodic);
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            spacing: 8

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
                                                    text: "Periodic Rotation"
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(0)
                                                    font.weight: Font.Bold
                                                    color: Colors.overBackground
                                                }

                                                Text {
                                                    text: periodicCard.isPeriodic ? ("Rotates every " + periodicCard.periodicInt + "m") : "Automatic switching disabled"
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-3)
                                                    color: periodicCard.isPeriodic ? Colors.primary : Colors.outline
                                                }
                                            }

                                            Switch {
                                                checked: periodicCard.isPeriodic
                                                focusPolicy: Qt.NoFocus
                                                onToggled: {
                                                    root.currentSection = 3;
                                                    root.focusedAutomationIndex = 1;
                                                    if (GlobalStates) GlobalStates.setWallpaperPeriodicEnabled(checked);
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 1
                                    color: Colors.outline
                                    opacity: 0.2
                                }

                                // Interval Pills
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
                                            Layout.preferredHeight: 38

                                            readonly property bool isSelected: periodicCard.periodicInt === modelData.value
                                            readonly property bool isFocused: root.currentSection === 3 && root.focusedAutomationIndex === (index + 2)

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
                                                    if (!periodicCard.isPeriodic && GlobalStates) {
                                                        GlobalStates.setWallpaperPeriodicEnabled(true);
                                                    }
                                                    root.currentSection = 3;
                                                    root.focusedAutomationIndex = index + 2;
                                                    if (GlobalStates) GlobalStates.setWallpaperPeriodicInterval(modelData.value);
                                                }

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
                                }
                            }
                        }
                    }
                }

                // Section 4: DISPLAY & SHADER EFFECTS (OLED & Tint)
                ColumnLayout {
                    id: sectionEffects
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "DISPLAY & SHADER EFFECTS"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            font.weight: Font.Bold
                            color: root.currentSection === 4 ? Colors.primary : Colors.overBackground
                        }

                        StyledRect {
                            visible: root.currentSection === 4
                            variant: "focus"
                            Layout.preferredHeight: 18
                            Layout.preferredWidth: 54
                            radius: Styling.radius(2)

                            Text {
                                anchors.centerIn: parent
                                text: "ACTIVE"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-4)
                                font.weight: Font.Bold
                                color: Colors.primary
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // OLED Card
                        StyledRect {
                            id: cardOled
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            readonly property bool isSelected: Config.theme.oledMode
                            readonly property bool isFocused: root.currentSection === 4 && root.focusedEffectIndex === 0
                            variant: isSelected ? "primary" : ((maOled.containsMouse || isFocused) ? "focus" : "pane")
                            radius: Styling.radius(4)

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: cardOled.isSelected ? Colors.overPrimary : Colors.primary
                                border.width: 2
                                radius: Styling.radius(4)
                                visible: cardOled.isFocused
                            }

                            MouseArea {
                                id: maOled
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.currentSection = 4;
                                    root.focusedEffectIndex = 0;
                                    Config.theme.oledMode = !Config.theme.oledMode;
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8

                                    Text {
                                        text: Icons.nightLight
                                        font.family: Icons.font
                                        font.pixelSize: 20
                                        color: cardOled.isSelected ? Colors.overPrimary : Colors.overSurface
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: "OLED Pitch-Black Mode"
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            font.weight: cardOled.isSelected ? Font.Bold : Font.Medium
                                            color: cardOled.isSelected ? Colors.overPrimary : Colors.overBackground
                                        }

                                        Text {
                                            text: "Deep true blacks for OLED screens"
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-3)
                                            color: cardOled.isSelected ? Colors.overPrimary : Colors.outline
                                            opacity: cardOled.isSelected ? 0.85 : 1.0
                                        }
                                    }

                                    Text {
                                        visible: cardOled.isSelected
                                        text: Icons.accept
                                        font.family: Icons.font
                                        font.pixelSize: 16
                                        color: Colors.overPrimary
                                    }
                                }
                            }
                        }

                        // Tint Card
                        StyledRect {
                            id: cardTint
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            readonly property bool isSelected: GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.tintEnabled : false
                            readonly property bool isFocused: root.currentSection === 4 && root.focusedEffectIndex === 1
                            variant: isSelected ? "primary" : ((maTint.containsMouse || isFocused) ? "focus" : "pane")
                            radius: Styling.radius(4)

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: cardTint.isSelected ? Colors.overPrimary : Colors.primary
                                border.width: 2
                                radius: Styling.radius(4)
                                visible: cardTint.isFocused
                            }

                            MouseArea {
                                id: maTint
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.currentSection = 4;
                                    root.focusedEffectIndex = 1;
                                    if (GlobalStates.wallpaperManager) {
                                        GlobalStates.wallpaperManager.tintEnabled = !GlobalStates.wallpaperManager.tintEnabled;
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8

                                    Text {
                                        text: Icons.palette
                                        font.family: Icons.font
                                        font.pixelSize: 20
                                        color: cardTint.isSelected ? Colors.overPrimary : Colors.overSurface
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: "Dynamic Wallpaper Tint"
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            font.weight: cardTint.isSelected ? Font.Bold : Font.Medium
                                            color: cardTint.isSelected ? Colors.overPrimary : Colors.overBackground
                                        }

                                        Text {
                                            text: "Shader re-tints wallpaper to match theme"
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-3)
                                            color: cardTint.isSelected ? Colors.overPrimary : Colors.outline
                                            opacity: cardTint.isSelected ? 0.85 : 1.0
                                        }
                                    }

                                    Text {
                                        visible: cardTint.isSelected
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

                // Section 5: Material You Color Schemes
                ColumnLayout {
                    id: sectionSchemes
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "MATERIAL YOU COLOR SCHEMES"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            font.weight: Font.Bold
                            color: root.currentSection === 5 ? Colors.primary : Colors.overBackground
                        }

                        StyledRect {
                            visible: root.currentSection === 5
                            variant: "focus"
                            Layout.preferredHeight: 18
                            Layout.preferredWidth: 54
                            radius: Styling.radius(2)

                            Text {
                                anchors.centerIn: parent
                                text: "ACTIVE"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-4)
                                font.weight: Font.Bold
                                color: Colors.primary
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4
                        rowSpacing: 6
                        columnSpacing: 6

                        Repeater {
                            model: root.matugenSchemes

                            delegate: StyledRect {
                                id: schemeCard
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40

                                readonly property bool isSelected: (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.currentMatugenScheme === modelData.id)
                                readonly property bool isFocused: root.currentSection === 5 && root.focusedSchemeIndex === index

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
                                        root.currentSection = 5;
                                        root.focusedSchemeIndex = index;
                                        if (GlobalStates.wallpaperManager) {
                                            GlobalStates.wallpaperManager.setMatugenScheme(modelData.id);
                                        }
                                    }

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

                // Section 6: Color Presets (optional)
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
                            color: root.currentSection === 6 ? Colors.primary : Colors.overBackground
                        }

                        StyledRect {
                            visible: root.currentSection === 6
                            variant: "focus"
                            Layout.preferredHeight: 18
                            Layout.preferredWidth: 54
                            radius: Styling.radius(2)

                            Text {
                                anchors.centerIn: parent
                                text: "ACTIVE"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-4)
                                font.weight: Font.Bold
                                color: Colors.primary
                            }
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
                                readonly property bool isFocused: root.currentSection === 6 && root.focusedPresetIndex === index

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
                                        root.currentSection = 6;
                                        root.focusedPresetIndex = index;
                                        if (GlobalStates.wallpaperManager) {
                                            GlobalStates.wallpaperManager.setColorPreset(String(modelData));
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: String(modelData)
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        font.weight: presetCard.isSelected ? Font.Bold : Font.Medium
                                        color: presetCard.isSelected ? Colors.overPrimary : Colors.overSurface
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
