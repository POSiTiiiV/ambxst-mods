#!/usr/bin/env bash
# positive.special-workspaces: slot navigation for the hidden special-workspace
# group. Called both from Hyprland keybinds (custom_binds.lua) and from the
# bar's scroll/click handlers (Workspaces.qml, via Quickshell.execDetached).
#
# Usage: special-workspace-nav.sh <toggle|next|prev|goto> [N]

set -euo pipefail

STATE_FILE="/tmp/ambxst_special_ws.txt"
SETTINGS_FILE="$HOME/.config/ambxst/mods/positive.special-workspaces.json"

dynamic_mode() {
    jq -r '.dynamicMode // true' "$SETTINGS_FILE" 2>/dev/null || echo true
}

slot_count() {
    local n
    n=$(jq -r '.slotCount // 4' "$SETTINGS_FILE" 2>/dev/null || echo 4)
    [[ "$n" =~ ^[0-9]+$ ]] || n=4
    (( n < 2 )) && n=2
    (( n > 20 )) && n=20
    echo "$n"
}

active_special_name() {
    hyprctl -j monitors | jq -r '.[] | select(.focused==true) | .specialWorkspace.name // ""'
}

current_slot() {
    local name
    name=$(active_special_name)
    if [[ "$name" =~ ^special:([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "0"
    fi
}

occupied_slots() {
    hyprctl -j clients | jq -r '.[].workspace.name' | grep -oP '^special:\K[0-9]+' | sort -n -u
}

saved_regular_ws() {
    if [[ -f "$STATE_FILE" ]]; then
        sed -n '3p' "$STATE_FILE"
    else
        echo 1
    fi
}

# This Hyprland build uses a Lua config parser: `hyprctl dispatch <name> <args>`
# doesn't work (it's not the stock dispatcher CLI), dispatches must instead be
# given as a Lua expression, e.g. `hyprctl dispatch 'hl.dsp.focus({workspace="1"})'`.
dispatch_focus() {
    hyprctl dispatch "hl.dsp.focus({workspace=\"$1\"})" >/dev/null
}

dispatch_toggle_special() {
    hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$1\")" >/dev/null
}

# Close whichever special slot is open (if any, and different from $1), then
# open $1. Hyprland's togglespecialworkspace can't jump directly from one
# named special workspace to another -- it must be closed first.
open_slot() {
    local target="$1"
    local cur
    cur=$(current_slot)
    if [[ "$cur" != "0" && "$cur" != "$target" ]]; then
        dispatch_toggle_special "$cur"
    fi
    if [[ "$cur" != "$target" ]]; then
        dispatch_toggle_special "$target"
    fi
}

cmd="${1:-}"

case "$cmd" in
    toggle)
        cur=$(current_slot)
        if [[ "$cur" == "0" ]]; then
            dispatch_focus "name:isolated"
            open_slot "1"
        else
            dispatch_toggle_special "$cur"
            target=$(saved_regular_ws)
            dispatch_focus "$target"
        fi
        ;;

    goto)
        target="${2:-1}"
        [[ "$target" =~ ^[0-9]+$ ]] || exit 1
        open_slot "$target"
        ;;

    next|prev)
        cur=$(current_slot)
        [[ "$cur" == "0" ]] && cur=1

        if [[ "$(dynamic_mode)" == "true" ]]; then
            mapfile -t occ < <(occupied_slots)
            next_slot=""
            if [[ "$cmd" == "next" ]]; then
                for s in "${occ[@]}"; do
                    if (( s > cur )); then next_slot="$s"; break; fi
                done
                if [[ -z "$next_slot" ]]; then
                    max=0
                    for s in "${occ[@]}"; do (( s > max )) && max=$s; done
                    next_slot=$(( max > cur ? max : cur + 1 ))
                fi
            else
                for (( i=${#occ[@]}-1; i>=0; i-- )); do
                    if (( ${occ[i]} < cur )); then next_slot="${occ[i]}"; break; fi
                done
            fi
            [[ -n "$next_slot" ]] && open_slot "$next_slot"
        else
            total=$(slot_count)
            if [[ "$cmd" == "next" ]]; then
                next_slot=$(( cur % total + 1 ))
            else
                next_slot=$(( (cur - 2 + total) % total + 1 ))
            fi
            open_slot "$next_slot"
        fi
        ;;

    *)
        echo "usage: $0 <toggle|next|prev|goto> [N]" >&2
        exit 1
        ;;
esac
