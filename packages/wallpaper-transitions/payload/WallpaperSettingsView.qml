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

    function scrollBy(deltaY) {
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

    Keys.onEscapePressed: (event) => {
        root.backClicked();
        event.accepted = true;
    }

    Keys.onDownPressed: (event) => {
        root.scrollBy(60);
        event.accepted = true;
    }

    Keys.onUpPressed: (event) => {
        root.scrollBy(-60);
        event.accepted = true;
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_PageDown) {
            root.scrollBy(scrollArea.height * 0.75);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            root.scrollBy(-scrollArea.height * 0.75);
            event.accepted = true;
        }
    }

    Keys.onLeftPressed: (event) => {
        let idx = -1;
        for (let i = 0; i < root.styleOptions.length; i++) {
            if (root.styleOptions[i].id === root.currentStyle) {
                idx = i;
                break;
            }
        }
        if (idx > 0) {
            root.updateSetting("transitionStyle", root.styleOptions[idx - 1].id);
        } else if (idx === 0) {
            root.updateSetting("transitionStyle", root.styleOptions[root.styleOptions.length - 1].id);
        }
        event.accepted = true;
    }

    Keys.onRightPressed: (event) => {
        let idx = -1;
        for (let i = 0; i < root.styleOptions.length; i++) {
            if (root.styleOptions[i].id === root.currentStyle) {
                idx = i;
                break;
            }
        }
        if (idx >= 0 && idx < root.styleOptions.length - 1) {
            root.updateSetting("transitionStyle", root.styleOptions[idx + 1].id);
        } else if (idx === root.styleOptions.length - 1) {
            root.updateSetting("transitionStyle", root.styleOptions[0].id);
        }
        event.accepted = true;
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
                variant: backMa.containsMouse ? "focus" : "pane"
                radius: Styling.radius(4)

                MouseArea {
                    id: backMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backClicked()

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: Icons.caretLeft
                            font.family: Icons.font
                            font.pixelSize: 18
                            color: Colors.overSurface
                        }

                        Text {
                            text: "Back to Wallpapers"
                            font.family: Config.theme.font
                            font.pixelSize: Config.theme.fontSize
                            font.weight: Font.Medium
                            color: Colors.overSurface
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
                    text: "Configure transition animations, speed, Material You schemes, and display modes"
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

                // Section 1: Transitions
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "TRANSITION STYLE"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        font.weight: Font.Bold
                        color: Colors.overBackground
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
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52
                                variant: isSelected ? "primary" : (maCard.containsMouse ? "focus" : "pane")
                                radius: Styling.radius(4)

                                readonly property bool isSelected: modelData.id === root.currentStyle

                                MouseArea {
                                    id: maCard
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.updateSetting("transitionStyle", modelData.id)
                                    onWheel: (wheel) => root.scrollBy(-wheel.angleDelta.y)

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8

                                        Text {
                                            text: modelData.icon || Icons.sparkle
                                            font.family: Icons.font
                                            font.pixelSize: 20
                                            color: styleCard.isSelected ? Colors.overPrimary : Colors.overSurface
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

                // Section 2: Easing Curves (Left) & Speed + Display Effects (Right)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    // Easing Curves Column
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 6

                        Text {
                            text: "EASING CURVE"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            font.weight: Font.Bold
                            color: Colors.overBackground
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
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 38
                                    variant: isSelected ? "primary" : (maEase.containsMouse ? "focus" : "pane")
                                    radius: Styling.radius(4)

                                    readonly property bool isSelected: modelData.id === root.currentEasing

                                    MouseArea {
                                        id: maEase
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.updateSetting("easingCurve", modelData.id)
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

                    // Speed & Display Effects Column
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 8

                        // Duration Pills
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "ANIMATION DURATION"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Bold
                                color: Colors.overBackground
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
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        variant: isSelected ? "primary" : (maSpeed.containsMouse ? "focus" : "pane")
                                        radius: Styling.radius(4)

                                        readonly property bool isSelected: Math.abs(root.currentDuration - modelData.value) < 50

                                        MouseArea {
                                            id: maSpeed
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.updateSetting("duration", modelData.value)
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

                        // Display Effects (OLED & Tint)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "DISPLAY & SHADER EFFECTS"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Bold
                                color: Colors.overBackground
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                // OLED Card
                                StyledRect {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 38
                                    variant: Config.theme.oledMode ? "primary" : (maOled.containsMouse ? "focus" : "pane")
                                    radius: Styling.radius(4)

                                    MouseArea {
                                        id: maOled
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Config.theme.oledMode = !Config.theme.oledMode
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
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 38
                                    variant: isTinted ? "primary" : (maTint.containsMouse ? "focus" : "pane")
                                    radius: Styling.radius(4)

                                    MouseArea {
                                        id: maTint
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
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

                // Section 3: Material You Schemes
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "MATERIAL YOU DYNAMIC SCHEMES"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        font.weight: Font.Bold
                        color: Colors.overBackground
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
                                width: Math.max(115, labelText.implicitWidth + (isSelected ? 32 : 20))
                                height: 34
                                variant: isSelected ? "primary" : (maScheme.containsMouse ? "focus" : "pane")
                                radius: Styling.radius(4)

                                readonly property bool isSelected: {
                                    if (!GlobalStates.wallpaperManager) return false;
                                    return !GlobalStates.wallpaperManager.activeColorPreset &&
                                           GlobalStates.wallpaperManager.currentMatugenScheme === modelData.id;
                                }

                                MouseArea {
                                    id: maScheme
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
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

                // Section 4: Color Presets
                ColumnLayout {
                    visible: root.presets && root.presets.length > 0
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "COLOR PALETTE PRESETS"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        font.weight: Font.Bold
                        color: Colors.overBackground
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
                                width: Math.max(100, presetLabel.implicitWidth + (isSelected ? 32 : 20))
                                height: 34
                                variant: isSelected ? "primary" : (maPreset.containsMouse ? "focus" : "pane")
                                radius: Styling.radius(4)

                                readonly property bool isSelected: {
                                    if (!GlobalStates.wallpaperManager) return false;
                                    return GlobalStates.wallpaperManager.activeColorPreset === String(modelData);
                                }

                                MouseArea {
                                    id: maPreset
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
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
