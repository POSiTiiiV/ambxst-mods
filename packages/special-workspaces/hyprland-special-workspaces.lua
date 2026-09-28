-- =============================================================================
-- Isolated Special Workspaces & Bidirectional Scratchpad Movement
--
-- Not an Ambxst mod file -- copy this into your own
-- ~/.config/hypr/lua/custom/custom_binds.lua (or loadfile() it from there).
-- Reload with `hyprctl reload` afterwards. See this mod's README for the
-- companion window-rule snippet that auto-assigns apps into a special
-- workspace on launch.
-- =============================================================================

-- Bezier curve used by the workspace-fade animation below when leaving
-- special-workspace mode. Defined here (pcall-guarded in case your own
-- config already registers a curve of this name) so this file works
-- standalone -- it previously assumed "almostLinear" already existed,
-- which broke on any system that hadn't separately defined it.
pcall(hl.curve, "almostLinear", { type = "bezier", points = { {0.5, 0.5}, {0.75, 1} } })

-- State synchronization for Ambxst dock
local last_regular_ws = nil

local function set_special_mode_safety(in_special)
    if in_special then
        pcall(hl.config, { gestures = {
            workspace_swipe_distance = 1000000,
            workspace_swipe_cancel_ratio = 1.0,
            workspace_swipe_min_speed_to_force = 9999
        } })
        pcall(hl.animation, { leaf = "workspaces", enabled = false })
    else
        pcall(hl.config, { gestures = {
            workspace_swipe_distance = 300,
            workspace_swipe_cancel_ratio = 0.5,
            workspace_swipe_min_speed_to_force = 30
        } })
        pcall(hl.animation, { leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
    end
end

-- Recover a previously-persisted saved_regular_ws_id from the state file.
-- Needed because `hyprctl reload` (e.g. triggered by a wallpaper change via
-- matugen's post_hook, or positive.theme-sync's opacity/blur settings) re-
-- executes this whole script, wiping the in-memory last_regular_ws back to
-- nil even while still inside a special workspace. Without this,
-- write_special_ws_state would fall back to workspace 1 and corrupt the
-- saved workspace for no reason other than a config reload.
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

local function toggle_isolated_special(special_name)
    local active_sw = hl.get_active_special_workspace()
    local cur_ws = hl.get_active_workspace()

    -- Check if the requested special workspace is currently open
    local is_currently_open = false
    if active_sw then
        if special_name == "" or special_name == "special" then
            if active_sw.name == "special" or active_sw.name == "special:special" then
                is_currently_open = true
            end
        else
            if active_sw.name == "special:" .. special_name or active_sw.name == special_name then
                is_currently_open = true
            end
        end
    end

    if is_currently_open then
        -- Close the special workspace
        hl.dispatch(hl.dsp.workspace.toggle_special(special_name))
        -- Restore the previous regular workspace.
        -- Fallback: if last_regular_ws was corrupted (e.g. by a config reload),
        -- read the saved ws id from the state file before it gets cleared.
        local target_ws = last_regular_ws
        if not target_ws or target_ws <= 0 then
            local f = io.open("/tmp/ambxst_special_ws.txt", "r")
            if f then
                local lines = {}
                for line in f:lines() do lines[#lines + 1] = line end
                f:close()
                local saved = tonumber(lines[3])
                if saved and saved > 0 then target_ws = saved end
            end
        end
        last_regular_ws = nil
        write_special_ws_state(nil)
        if target_ws and target_ws > 0 then
            hl.dispatch(hl.dsp.focus({ workspace = target_ws }))
        end
    else
        -- If another special workspace is currently open, close it first
        if active_sw then
            local other_name = active_sw.name:gsub("^special:", "")
            if other_name == "special" then other_name = "" end
            hl.dispatch(hl.dsp.workspace.toggle_special(other_name))
        end

        -- Record the real regular workspace before isolating
        if not last_regular_ws or last_regular_ws <= 0 then
            if cur_ws and cur_ws.id > 0 and cur_ws.name ~= "isolated" then
                last_regular_ws = cur_ws.id
            else
                last_regular_ws = 1
            end
        end

        -- Always focus isolated empty workspace in background so no windows bleed through
        hl.dispatch(hl.dsp.focus({ workspace = "name:isolated" }))

        -- Write state with saved regular workspace before opening
        write_special_ws_state({ id = -99, name = special_name })

        hl.dispatch(hl.dsp.workspace.toggle_special(special_name))
    end
end

-- Guard against switching regular workspaces while inside special workspace
hl.on("workspace.active", function(ws)
    local sw = hl.get_active_special_workspace()
    if sw and sw.id and ws and ws.name ~= "isolated" then
        -- Force back to isolated background workspace
        hl.dispatch(hl.dsp.focus({ workspace = "name:isolated" }))
        return
    end
    -- NOTE: Do NOT clear last_regular_ws here — config reloads (wallpaper
    -- changes, theme-sync settings) fire workspace.active events that would
    -- corrupt the saved workspace. last_regular_ws is only cleared
    -- intentionally when closing the special workspace in toggle_isolated_special.
end)

-- Disable switching to real workspaces while inside special workspace
local function safe_ws_focus(target)
    if hl.get_active_special_workspace() then
        return -- Block switching to real workspaces while special workspace is open
    end
    hl.dispatch(hl.dsp.focus({ workspace = target }))
end

for i = 1, 10 do
    local key = tostring(i % 10)
    hl.unbind("SUPER + " .. key)
    hl.bind("SUPER + " .. key, function() safe_ws_focus(tostring(i)) end)
end

-- Intercept SUPER + X and SUPER + Z (+1 and -1)
hl.unbind("SUPER + X")
hl.bind("SUPER + X", function() safe_ws_focus("+1") end)

hl.unbind("SUPER + Z")
hl.bind("SUPER + Z", function() safe_ws_focus("-1") end)

-- Intercept SUPER + Y (for QWERTZ keyboards or layout variations)
hl.unbind("SUPER + Y")
hl.bind("SUPER + Y", function() safe_ws_focus("-1") end)

-- Intercept SUPER + SHIFT + X and SUPER + SHIFT + Z (e+1 and e-1)
hl.unbind("SUPER + SHIFT + X")
hl.bind("SUPER + SHIFT + X", function() safe_ws_focus("e+1") end)

hl.unbind("SUPER + SHIFT + Z")
hl.bind("SUPER + SHIFT + Z", function() safe_ws_focus("e-1") end)

hl.unbind("SUPER + mouse_down")
hl.bind("SUPER + mouse_down", function() safe_ws_focus("e+1") end)

hl.unbind("SUPER + mouse_up")
hl.bind("SUPER + mouse_up", function() safe_ws_focus("e-1") end)

-- Symmetrical bidirectional move: moves window into special workspace if outside,
-- or restores it to the active regular workspace if already inside.
local function toggle_move_special(target_special)
    local win = hl.get_active_window()
    if not win then return end

    local in_special = false
    if win.workspace then
        if win.workspace.id < 0 or (win.workspace.name and win.workspace.name:find("^special")) then
            in_special = true
        end
    end

    if in_special then
        -- Move back to regular workspace
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
        -- Move to target special workspace
        hl.dispatch(hl.dsp.window.move({ workspace = target_special }))
    end
end

-- Discord Special Workspace (Super + Shift + G to toggle, Super + Alt + G to move)
hl.unbind("SUPER + SHIFT + G")
hl.unbind("SUPER + ALT + G")
hl.bind("SUPER + SHIFT + G", function() toggle_isolated_special("discord") end)
hl.bind("SUPER + ALT + G", function() toggle_move_special("special:discord") end)

-- Music Special Workspace (Super + Shift + V to toggle, Super + Alt + V to move)
hl.unbind("SUPER + SHIFT + V")
hl.unbind("SUPER + ALT + V")
hl.bind("SUPER + SHIFT + V", function() toggle_isolated_special("") end)
hl.bind("SUPER + ALT + V", function() toggle_move_special("special") end)
