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

    // This singleton is first touched from inside DockContent's bindings,
    // while the shell is still building its panels. Pulling ModsService in
    // at that moment (Connections target / getSettings) crashes Quickshell
    // inside QV4::Runtime::IteratorNext a few seconds later (Qt 6.12), so
    // ModsService is only touched once start-up has settled.
    property bool ready: false

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

    Timer {
        interval: 3000
        running: true
        onTriggered: {
            root.ready = true;
            root.load();
        }
    }

    Connections {
        target: root.ready ? ModsService : null
        function onSettingChanged(modId, key, value) {
            if (modId !== root.modId) return;
            const values = {};
            values[key] = value;
            root.applyValues(values);
        }
    }
}
