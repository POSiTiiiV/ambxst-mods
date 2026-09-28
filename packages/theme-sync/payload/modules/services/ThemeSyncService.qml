pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.services

Singleton {
    id: root

    readonly property string modId: "positive.theme-sync"

    // Re-runs the full palette sync (colors + Dolphin opacity/blur). Wallpaper
    // changes already trigger this via the ambxst-theme-sync.path systemd
    // unit watching colors.json; this covers the other trigger — the mod's
    // own settings changing, which colors.json doesn't reflect.
    Process {
        id: syncProcess
        command: [Quickshell.env("HOME") + "/.local/bin/ambxst-theme-sync"]
        running: false
    }

    function triggerSync() {
        // Toggling running false->true restarts the process even if a
        // previous run is still the current command instance.
        syncProcess.running = false;
        syncProcess.running = true;
    }

    Connections {
        target: ModsService
        function onSettingChanged(modId, key, value) {
            if (modId !== root.modId) return;
            root.triggerSync();
        }
    }
}
