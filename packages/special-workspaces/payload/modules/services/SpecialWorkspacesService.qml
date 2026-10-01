pragma Singleton
import QtQuick
import Quickshell
import qs.modules.services

Singleton {
    id: root

    readonly property string modId: "positive.special-workspaces"

    // Hyprland Lua re-reads these from the mod's own settings.json values
    // file on load/reload. The bar's own QML picks up threshold/
    // dynamicMode/slotCount live via its own settings FileView already --
    // this service's job is just to apply a 'hyprctl reload' so the Lua
    // side (keybind, boundary guard, Z/X wraparound) picks up the change
    // too, instead of silently waiting for the next manual reload.
    readonly property var hyprlandKeys: ["keybind", "threshold", "dynamicMode", "slotCount", "animationStyle"]

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
