-- =============================================================================
-- Special Workspace Group (positive.special-workspaces)
-- =============================================================================
-- One hidden group of special workspaces (slot 1, 2, 3...), toggled with a
-- single configurable keybind that always opens slot 1. Once inside, SUPER+Z/X
-- and scrolling/clicking the bar move between slots exactly like regular
-- workspaces (see ~/.config/hypr/scripts/special-workspace-nav.sh for the
-- slot-cycling logic shared with the bar's scroll/click handlers). 3-finger
-- swipe is intentionally left alone -- Hyprland's touchpad gesture is
-- hardcoded to regular, numbered workspaces with no hook for custom targets,
-- so it isn't repurposed here.

local SPECIAL_NAV_SCRIPT = os.getenv("HOME") .. "/.config/hypr/scripts/special-workspace-nav.sh"
local SPECIAL_SETTINGS_PATH = os.getenv("HOME") .. "/.config/ambxst/mods/positive.special-workspaces.json"

-- Minimal ad hoc reader for this mod's own flat settings file -- avoids
-- pulling in a full JSON library for four simple values.
local function read_json_value(text, key, default)
    local str_v = text:match('"' .. key .. '"%s*:%s*"([^"]*)"')
    if str_v then return str_v end
    if text:match('"' .. key .. '"%s*:%s*true') then return true end
    if text:match('"' .. key .. '"%s*:%s*false') then return false end
    local num_v = text:match('"' .. key .. '"%s*:%s*(-?%d+%.?%d*)')
    if num_v then return tonumber(num_v) end
    return default
end

local function load_special_ws_settings()
    local f = io.open(SPECIAL_SETTINGS_PATH, "r")
    local text = f and f:read("*a") or ""
    if f then f:close() end
    return {
        keybind = read_json_value(text, "keybind", "SUPER + SHIFT + V"),
        animationStyle = read_json_value(text, "animationStyle", "fade"),
    }
end

local sw_settings = load_special_ws_settings()

-- State synchronization for Ambxst dock
local last_regular_ws = nil

local function special_group_animation()
    if sw_settings.animationStyle == "slide" then
        return { leaf = "workspaces", enabled = true, speed = 3.0, spring = "workspaceSpring", style = "slidefade 20%" }
    end
    return { leaf = "workspaces", enabled = true, speed = 2.2, bezier = "almostLinear", style = "fade" }
end

local function set_special_mode_safety(in_special)
    if in_special then
        pcall(hl.config, { gestures = {
            workspace_swipe_distance = 1000000,
            workspace_swipe_cancel_ratio = 1.0,
            workspace_swipe_min_speed_to_force = 9999
        } })
        pcall(hl.animation, special_group_animation())
    else
        pcall(hl.config, { gestures = {
            workspace_swipe_distance = 300,
            workspace_swipe_cancel_ratio = 0.5,
            workspace_swipe_min_speed_to_force = 30
        } })
        -- Restores custom_rules.lua's own regular-workspace animation.
        pcall(hl.animation, { leaf = "workspaces", enabled = true, speed = 3.0, spring = "workspaceSpring", style = "slidefade 20%" })
    end
end

-- Recover a previously-persisted saved_regular_ws_id from the state file.
-- Needed because `hyprctl reload` (e.g. triggered by a wallpaper change via
-- matugen's post_hook) re-executes this whole script, wiping the in-memory
-- last_regular_ws back to nil even while still inside a special workspace.
-- Without this, write_special_ws_state would fall back to workspace 1 and
-- corrupt the saved workspace for no reason other than a config reload.
local function read_saved_regular_ws_from_file()
    local f = io.open("/tmp/ambxst_special_ws.txt", "r")
    if not f then return nil end
    local lines = {}
    for line in f:lines() do lines[#lines + 1] = line end
    f:close()
    local saved = tonumber(lines[3])
    if saved and saved > 0 then return saved end
    return nil
end

local function write_special_ws_state(ws)
    local is_special = false
    if ws and ws.name and ws.name ~= "" and ws.id and ws.id < 0 then
        is_special = true
    end
    if not is_special then
        local active_sw = hl.get_active_special_workspace()
        if active_sw and active_sw.id and active_sw.id < 0 then
            is_special = true
            ws = active_sw
        end
    end

    local f = io.open("/tmp/ambxst_special_ws.txt", "w")
    if f then
        if is_special and ws then
            local saved_ws
            if last_regular_ws and last_regular_ws > 0 then
                saved_ws = last_regular_ws
            else
                saved_ws = read_saved_regular_ws_from_file() or 1
                last_regular_ws = saved_ws
            end
            f:write(tostring(ws.id) .. "\n" .. tostring(ws.name) .. "\n" .. tostring(saved_ws) .. "\n")
            set_special_mode_safety(true)
        else
            f:write("0\n\n0\n")
            set_special_mode_safety(false)
        end
        f:close()
    end
end

-- Initialize state immediately
write_special_ws_state(hl.get_active_special_workspace())

-- Listen to compositor special workspace changes
hl.on("workspace.special_active", write_special_ws_state)

-- Toggle the special group: opens slot 1 (regardless of occupancy) if not
-- currently inside the group, or closes back to the saved regular workspace
-- if already inside (any slot).
local function toggle_special_group()
    local active_sw = hl.get_active_special_workspace()
    local cur_ws = hl.get_active_workspace()

    if active_sw and active_sw.id and active_sw.id < 0 then
        local slot_name = active_sw.name:gsub("^special:", "")
        hl.dispatch(hl.dsp.workspace.toggle_special(slot_name))
        local target_ws = last_regular_ws
        if not target_ws or target_ws <= 0 then
            target_ws = read_saved_regular_ws_from_file() or 1
        end
        last_regular_ws = nil
        write_special_ws_state(nil)
        if target_ws and target_ws > 0 then
            hl.dispatch(hl.dsp.focus({ workspace = target_ws }))
        end
    else
        if not last_regular_ws or last_regular_ws <= 0 then
            if cur_ws and cur_ws.id > 0 and cur_ws.name ~= "isolated" then
                last_regular_ws = cur_ws.id
            else
                last_regular_ws = 1
            end
        end
        hl.dispatch(hl.dsp.focus({ workspace = "name:isolated" }))
        write_special_ws_state({ id = -99, name = "1" })
        hl.dispatch(hl.dsp.workspace.toggle_special("1"))
    end
end

local function bind_special_toggle()
    local kb = sw_settings.keybind
    pcall(hl.unbind, kb)
    local ok = pcall(hl.bind, kb, toggle_special_group)
    if not ok then
        pcall(hl.unbind, "SUPER + SHIFT + V")
        pcall(hl.bind, "SUPER + SHIFT + V", toggle_special_group)
    end
end
bind_special_toggle()

-- Guard against switching regular workspaces while inside the special group
hl.on("workspace.active", function(ws)
    local sw = hl.get_active_special_workspace()
    if sw and sw.id and ws and ws.name ~= "isolated" then
        -- Force back to isolated background workspace
        hl.dispatch(hl.dsp.focus({ workspace = "name:isolated" }))
        return
    end
    -- NOTE: Do NOT clear last_regular_ws here — wallpaper changes fire workspace.active
    -- events that would corrupt the saved workspace. last_regular_ws is only cleared
    -- intentionally when closing the special group in toggle_special_group.
end)

-- SUPER+1-10 and e+1/e-1 (move-to-empty-workspace) stay blocked while inside
-- the special group -- only the toggle keybind escapes back to regular.
local function safe_ws_focus(target)
    if hl.get_active_special_workspace() then
        return
    end
    hl.dispatch(hl.dsp.focus({ workspace = target }))
end

for i = 1, 10 do
    local key = tostring(i % 10)
    hl.unbind("SUPER + " .. key)
    hl.bind("SUPER + " .. key, function() safe_ws_focus(tostring(i)) end)
end

-- SUPER+Z/X (and the SUPER+Y alias) cycle slots while inside the special
-- group, instead of no-op'ing -- same script the bar's scroll/click
-- handlers call, so there's a single source of truth for slot-cycling.
local function ws_nav_or_special(target, special_direction)
    if hl.get_active_special_workspace() then
        hl.dispatch(hl.dsp.exec_cmd("bash " .. SPECIAL_NAV_SCRIPT .. " " .. special_direction))
        return
    end
    hl.dispatch(hl.dsp.focus({ workspace = target }))
end

hl.unbind("SUPER + X")
hl.bind("SUPER + X", function() ws_nav_or_special("+1", "next") end)

hl.unbind("SUPER + Z")
hl.bind("SUPER + Z", function() ws_nav_or_special("-1", "prev") end)

-- Intercept SUPER + Y (for QWERTZ keyboards or layout variations)
hl.unbind("SUPER + Y")
hl.bind("SUPER + Y", function() ws_nav_or_special("-1", "prev") end)

-- Intercept SUPER + SHIFT + X and SUPER + SHIFT + Z (e+1 and e-1)
hl.unbind("SUPER + SHIFT + X")
hl.bind("SUPER + SHIFT + X", function() safe_ws_focus("e+1") end)

hl.unbind("SUPER + SHIFT + Z")
hl.bind("SUPER + SHIFT + Z", function() safe_ws_focus("e-1") end)

hl.unbind("SUPER + mouse_down")
hl.bind("SUPER + mouse_down", function() safe_ws_focus("e+1") end)

hl.unbind("SUPER + mouse_up")
hl.bind("SUPER + mouse_up", function() safe_ws_focus("e-1") end)

-- Move the active window into/out of slot 1 (SUPER + ALT + V). App
-- auto-assignment (custom_rules.lua) covers Discord -> slot 1 and
-- Spotify/Sonora -> slot 2 by default; this is for anything else you want
-- to throw in/out manually.
hl.unbind("SUPER + ALT + G")
hl.unbind("SUPER + ALT + V")
hl.bind("SUPER + ALT + V", function()
    local win = hl.get_active_window()
    if not win then return end

    local in_special = false
    if win.workspace then
        if win.workspace.id < 0 or (win.workspace.name and win.workspace.name:find("^special")) then
            in_special = true
        end
    end

    if in_special then
        local dest = "1"
        if last_regular_ws and last_regular_ws > 0 then
            dest = tostring(last_regular_ws)
        else
            local cur_ws = hl.get_active_workspace()
            if cur_ws and cur_ws.id > 0 then
                dest = tostring(cur_ws.id)
            end
        end
        hl.dispatch(hl.dsp.window.move({ workspace = dest }))
    else
        hl.dispatch(hl.dsp.window.move({ workspace = "special:1" }))
    end
end)

