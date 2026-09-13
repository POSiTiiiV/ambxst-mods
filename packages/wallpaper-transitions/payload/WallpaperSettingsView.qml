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
    // 0: Transition Style, 1: Easing Curve, 2: Animation Duration, 3: Display & Shader Effects, 4: Material You Schemes, 5: Color Presets, 6: Back Button
    property int currentSection: 0
    property int focusedStyleIndex: 0
    property int focusedEasingIndex: 0
    property int focusedSpeedIndex: 1
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
        if (sec === 0 || sec === 6) {
            smoothScrollTo(0);
            return;
        }
        let targetItem = null;
        if (sec === 1 || sec === 2 || sec === 3) {
            targetItem = sectionEasingAndEffects;
        } else if (sec === 4) {
            targetItem = sectionSchemes;
        } else if (sec === 5) {
            targetItem = sectionPresets;
        }

        if (targetItem) {
            let targetY = targetItem.y;
            let targetH = targetItem.height;
            let viewH = scrollArea.height;
            let maxScroll = Math.max(0, scrollArea.contentHeight - viewH);

            if (sec === 3) {
                smoothScrollTo(Math.min(maxScroll, Math.max(0, targetY + targetH - viewH + 20)));
            } else if (targetY < scrollArea.contentY) {
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
            if (focusedEffectIndex < 0 || focusedEffectIndex > 1) {
                focusedEffectIndex = 0;
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
        case 0:
            if (key === Qt.Key_Right) {
                if (focusedStyleIndex < styleOptions.length - 1) focusedStyleIndex++;
            } else if (key === Qt.Key_Left) {
                if (focusedStyleIndex > 0) focusedStyleIndex--;
            } else if (key === Qt.Key_Down) {
                if (focusedStyleIndex + 2 < styleOptions.length) focusedStyleIndex += 2;
                else if (focusedStyleIndex + 1 < styleOptions.length) focusedStyleIndex += 1;
            } else if (key === Qt.Key_Up) {
                if (focusedStyleIndex - 2 >= 0) focusedStyleIndex -= 2;
                else if (focusedStyleIndex > 0) focusedStyleIndex = 0;
            }
            root.updateSetting("transitionStyle", styleOptions[focusedStyleIndex].id);
            break;

        case 1:
            if (key === Qt.Key_Right) {
                if (focusedEasingIndex < easingOptions.length - 1) focusedEasingIndex++;
            } else if (key === Qt.Key_Left) {
                if (focusedEasingIndex > 0) focusedEasingIndex--;
            } else if (key === Qt.Key_Down) {
                if (focusedEasingIndex + 2 < easingOptions.length) focusedEasingIndex += 2;
                else if (focusedEasingIndex + 1 < easingOptions.length) focusedEasingIndex += 1;
            } else if (key === Qt.Key_Up) {
                if (focusedEasingIndex - 2 >= 0) focusedEasingIndex -= 2;
                else if (focusedEasingIndex > 0) focusedEasingIndex = 0;
            }
            root.updateSetting("easingCurve", easingOptions[focusedEasingIndex].id);
            break;

        case 2:
            if (key === Qt.Key_Right || key === Qt.Key_Down) {
                if (focusedSpeedIndex < speedOptions.length - 1) focusedSpeedIndex++;
            } else if (key === Qt.Key_Left || key === Qt.Key_Up) {
                if (focusedSpeedIndex > 0) focusedSpeedIndex--;
            }
            root.updateSetting("duration", speedOptions[focusedSpeedIndex].value);
            break;

        case 3:
            if (key === Qt.Key_Right || key === Qt.Key_Down) {
                focusedEffectIndex = 1;
            } else if (key === Qt.Key_Left || key === Qt.Key_Up) {
                focusedEffectIndex = 0;
            }
            break;

        case 4:
            if (key === Qt.Key_Right) {
                if (focusedSchemeIndex < matugenSchemes.length - 1) focusedSchemeIndex++;
            } else if (key === Qt.Key_Left) {
                if (focusedSchemeIndex > 0) focusedSchemeIndex--;
            } else if (key === Qt.Key_Down) {
                if (focusedSchemeIndex + 4 < matugenSchemes.length) focusedSchemeIndex += 4;
                else focusedSchemeIndex = matugenSchemes.length - 1;
            } else if (key === Qt.Key_Up) {
                if (focusedSchemeIndex - 4 >= 0) focusedSchemeIndex -= 4;
                else focusedSchemeIndex = 0;
            }
            if (GlobalStates.wallpaperManager) {
                GlobalStates.wallpaperManager.setMatugenScheme(matugenSchemes[focusedSchemeIndex].id);
            }
            break;

        case 5:
            if (root.presets && root.presets.length > 0) {
                if (key === Qt.Key_Right || key === Qt.Key_Down) {
                    if (focusedPresetIndex < root.presets.length - 1) focusedPresetIndex++;
                } else if (key === Qt.Key_Left || key === Qt.Key_Up) {
                    if (focusedPresetIndex > 0) focusedPresetIndex--;
                }
                if (GlobalStates.wallpaperManager) {
                    GlobalStates.wallpaperManager.setColorPreset(String(root.presets[focusedPresetIndex]));
                }
            }
            break;

        case 6:
            break;
        }
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
            if (focusedEffectIndex === 0) {
                Config.theme.oledMode = !Config.theme.oledMode;
            } else if (focusedEffectIndex === 1) {
                if (GlobalStates.wallpaperManager) {
                    GlobalStates.wallpaperManager.tintEnabled = !GlobalStates.wallpaperManager.tintEnabled;
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
            root.backClicked();
            break;
        }
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
            root.backClicked();
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
        spacing: 10

        // Top Navigation Header
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 12

            // Back Button
            StyledRect {
                id: backBtnRect
                Layout.preferredWidth: 175
                Layout.preferredHeight: 38
                readonly property bool isFocused: root.currentSection === 6
                variant: (isFocused || backMa.containsMouse) ? "focus" : "pane"
                radius: Styling.radius(4)

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: Colors.primary
                    border.width: 2
                    radius: Styling.radius(4)
                    visible: backBtnRect.isFocused
                }

                MouseArea {
                    id: backMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.currentSection = 6;
                        root.backClicked();
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: Icons.caretLeft
                            font.family: Icons.font
                            font.pixelSize: 18
                            color: backBtnRect.isFocused ? Colors.primary : Colors.overSurface
                        }

                        Text {
                            text: "Back to Wallpapers"
                            font.family: Config.theme.font
                            font.pixelSize: Config.theme.fontSize
                            font.weight: backBtnRect.isFocused ? Font.Bold : Font.Medium
                            color: backBtnRect.isFocused ? Colors.primary : Colors.overSurface
                        }
                    }
                }
            }

            // Title
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: "Wallpaper & Transition Settings"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(1)
                    font.weight: Font.Bold
                    color: Colors.overBackground
                }

                Text {
                    text: "Use Tab to cycle sections, Arrow keys to choose options, Esc to return"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-3)
                    color: Colors.outline
                }
            }

            // Light / Dark Mode Toggle Switch
            Switch {
                Layout.preferredWidth: 72
                Layout.preferredHeight: 36
                checked: Config.theme.lightMode
                focusPolicy: Qt.NoFocus

                onCheckedChanged: {
                    Config.theme.lightMode = checked;
                }

                indicator: Rectangle {
                    implicitWidth: 72
                    implicitHeight: 36
                    radius: Styling.radius(4)
                    color: Colors.background

                    Text {
                        z: 1
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.sun
                        color: Config.theme.lightMode ? Colors.overPrimary : Colors.overBackground
                        font.family: Icons.font
                        font.pixelSize: 18
                    }

                    Text {
                        z: 1
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.moon
                        color: Config.theme.lightMode ? Colors.overBackground : Colors.overPrimary
                        font.family: Icons.font
                        font.pixelSize: 18
                    }

                    StyledRect {
                        variant: "primary"
                        z: 0
                        width: 34
                        height: 30
                        radius: Styling.radius(2)
                        x: Config.theme.lightMode ? 3 : 35
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on x {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
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
            contentHeight: settingsColumn.implicitHeight + 20
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
                spacing: 14

                // Section 0: Transitions
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
                            text: "Arrow keys to choose style, Enter to confirm"
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

                // Section 1: Easing Curves (Left) & Section 2/3: Speed + Display Effects (Right)
                RowLayout {
                    id: sectionEasingAndEffects
                    Layout.fillWidth: true
                    spacing: 14

                    // Section 1: Easing Curves Column
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
                                    Layout.preferredHeight: 38

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

                    // Section 2: Speed & Section 3: Display Effects Column
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 8

                        // Section 2: Duration Pills
                        ColumnLayout {
                            id: sectionDuration
                            Layout.fillWidth: true
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
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38
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
                        }

                        // Section 3: Display Effects (OLED & Tint)
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
                                    visible: root.currentSection === 3
                                    text: "Enter or Space to toggle"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-4)
                                    color: Colors.outline
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                // OLED Card
                                StyledRect {
                                    id: oledCard
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 38
                                    readonly property bool isFocused: root.currentSection === 3 && root.focusedEffectIndex === 0
                                    variant: Config.theme.oledMode ? "primary" : ((maOled.containsMouse || isFocused) ? "focus" : "pane")
                                    radius: Styling.radius(4)

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.color: Config.theme.oledMode ? Colors.overPrimary : Colors.primary
                                        border.width: 2
                                        radius: Styling.radius(4)
                                        visible: oledCard.isFocused
                                    }

                                    MouseArea {
                                        id: maOled
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.currentSection = 3;
                                            root.focusedEffectIndex = 0;
                                            Config.theme.oledMode = !Config.theme.oledMode;
                                        }
                                        onWheel: (wheel) => root.scrollBy(-wheel.angleDelta.y)

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 6

                                            Text {
                                                Layout.fillWidth: true
                                                text: "OLED Pitch Black"
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-1)
                                                font.weight: Config.theme.oledMode ? Font.Bold : Font.Medium
                                                color: Config.theme.oledMode ? Colors.overPrimary : Colors.overBackground
                                            }

                                            Text {
                                                visible: Config.theme.oledMode
                                                text: Icons.accept
                                                font.family: Icons.font
                                                font.pixelSize: 14
                                                color: Colors.overPrimary
                                            }
                                        }
                                    }
                                }

                                // Tint Card
                                StyledRect {
                                    id: tintRect
                                    readonly property bool isTinted: GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.tintEnabled
                                    readonly property bool isFocused: root.currentSection === 3 && root.focusedEffectIndex === 1
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 38
                                    variant: isTinted ? "primary" : ((maTint.containsMouse || isFocused) ? "focus" : "pane")
                                    radius: Styling.radius(4)

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.color: tintRect.isTinted ? Colors.overPrimary : Colors.primary
                                        border.width: 2
                                        radius: Styling.radius(4)
                                        visible: tintRect.isFocused
                                    }

                                    MouseArea {
                                        id: maTint
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.currentSection = 3;
                                            root.focusedEffectIndex = 1;
                                            if (GlobalStates.wallpaperManager) {
                                                GlobalStates.wallpaperManager.tintEnabled = !GlobalStates.wallpaperManager.tintEnabled;
                                            }
                                        }
                                        onWheel: (wheel) => root.scrollBy(-wheel.angleDelta.y)

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 6

                                            Text {
                                                Layout.fillWidth: true
                                                text: "Wallpaper Tint"
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-1)
                                                font.weight: tintRect.isTinted ? Font.Bold : Font.Medium
                                                color: tintRect.isTinted ? Colors.overPrimary : Colors.overBackground
                                            }

                                            Text {
                                                visible: tintRect.isTinted
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

                // Section 4: Material You Schemes
                ColumnLayout {
                    id: sectionSchemes
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "MATERIAL YOU DYNAMIC SCHEMES"
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
                    }

                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: childrenRect.height
                        spacing: 6

                        Repeater {
                            model: root.matugenSchemes

                            delegate: StyledRect {
                                id: schemeCard
                                required property var modelData
                                required property int index
                                width: Math.max(115, labelText.implicitWidth + (isSelected ? 32 : 20))
                                height: 34

                                readonly property bool isSelected: {
                                    if (!GlobalStates.wallpaperManager) return false;
                                    return !GlobalStates.wallpaperManager.activeColorPreset &&
                                           GlobalStates.wallpaperManager.currentMatugenScheme === modelData.id;
                                }
                                readonly property bool isFocused: root.currentSection === 4 && root.focusedSchemeIndex === index

                                variant: isSelected ? "primary" : ((maScheme.containsMouse || isFocused) ? "focus" : "pane")
                                radius: Styling.radius(4)

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: schemeCard.isSelected ? Colors.overPrimary : Colors.primary
                                    border.width: 2
                                    radius: Styling.radius(4)
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
                                    onWheel: (wheel) => root.scrollBy(-wheel.angleDelta.y)

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            id: labelText
                                            text: modelData.label || ""
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            font.weight: schemeCard.isSelected ? Font.Bold : Font.Normal
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

                // Section 5: Color Presets
                ColumnLayout {
                    id: sectionPresets
                    visible: root.presets && root.presets.length > 0
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "COLOR PALETTE PRESETS"
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
                    }

                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: childrenRect.height
                        spacing: 6

                        Repeater {
                            model: root.presets

                            delegate: StyledRect {
                                id: presetCard
                                required property var modelData
                                required property int index
                                width: Math.max(100, presetLabel.implicitWidth + (isSelected ? 32 : 20))
                                height: 34

                                readonly property bool isSelected: {
                                    if (!GlobalStates.wallpaperManager) return false;
                                    return GlobalStates.wallpaperManager.activeColorPreset === String(modelData);
                                }
                                readonly property bool isFocused: root.currentSection === 5 && root.focusedPresetIndex === index

                                variant: isSelected ? "primary" : ((maPreset.containsMouse || isFocused) ? "focus" : "pane")
                                radius: Styling.radius(4)

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: presetCard.isSelected ? Colors.overPrimary : Colors.primary
                                    border.width: 2
                                    radius: Styling.radius(4)
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
                                    onWheel: (wheel) => root.scrollBy(-wheel.angleDelta.y)

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            id: presetLabel
                                            text: String(modelData || "")
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            font.weight: presetCard.isSelected ? Font.Bold : Font.Normal
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

                // Bottom spacer for comfortable scrolling
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                }
            }
        }
    }
}
