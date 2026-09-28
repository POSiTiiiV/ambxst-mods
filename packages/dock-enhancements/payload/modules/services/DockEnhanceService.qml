pragma Singleton
import QtQuick
import Quickshell
import qs.modules.services
import qs.config

Singleton {
    id: root

    readonly property string modId: "positive.dock-enhancements"

    property bool hideForFloating: Config.dock?.hideForFloating ?? true
    property bool loaded: false

    function applyValues(values) {
        if (!values) return;
        if (values.hideForFloating !== undefined) root.hideForFloating = !!values.hideForFloating;
    }

    function load() {
        if (typeof ModsService === "undefined" || typeof ModsService.getSettings !== "function") return;
        ModsService.getSettings(root.modId, (settings, error) => {
            if (error || !settings) return;
            root.applyValues(settings.values);
            root.loaded = true;
        });
    }

    Connections {
        target: ModsService
        function onSettingChanged(modId, key, value) {
            if (modId !== root.modId) return;
            const values = {};
            values[key] = value;
            root.applyValues(values);
        }
    }

    Component.onCompleted: load()
}
