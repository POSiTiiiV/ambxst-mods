pragma Singleton
import QtQuick
import Quickshell
import qs.modules.services

Singleton {
    id: root

    readonly property string modId: "positive.special-workspaces"

    // Hyprland Lua re-reads these from the mod's own settings.json values
    // file on load/reload -- they're not consumed directly by QML. This
    // service's only job is to apply a 'hyprctl reload' whenever one of
    // them changes, so a Settings-page edit takes effect immediately
    // instead of silently waiting for the next manual reload.
    readonly property var hyprlandKeys: ["keybind", "dynamicMode", "slotCount", "animationStyle"]

    function load() {
        if (typeof ModsService === "undefined" || typeof ModsService.getSettings !== "function") return;
        ModsService.getSettings(root.modId, (settings, error) => {
            if (error || !settings) return;
        });
    }

    Connections {
        target: ModsService
        function onSettingChanged(modId, key, value) {
            if (modId !== root.modId) return;
            if (root.hyprlandKeys.indexOf(key) === -1) return;
            Quickshell.execDetached(["hyprctl", "reload"]);
        }
    }

    Component.onCompleted: load()
}
