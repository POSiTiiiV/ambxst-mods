-- =============================================================================
-- Special Workspace Group (positive.special-workspaces)
-- =============================================================================
-- A reserved block of real, regular Hyprland workspaces above a threshold
-- (default 50) acts as a hidden "second set" -- slot 1 = threshold+1, slot 2
-- = threshold+2, etc. Since these are genuine regular workspaces, SUPER+Z/X,
-- scrolling, clicking the bar, and 3-finger swipe all work on them exactly
-- like regular workspaces, with zero special-casing in those dispatches.
-- The only custom logic is: (1) a single toggle keybind that jumps straight
-- to slot 1 / back to your last regular workspace, (2) a reactive guard that
-- bounces you back if you ever cross from regular into hidden territory any
-- way other than the toggle (so swipe/scroll/Z/X can't wander in by
-- accident), and (3) number keys meaning "slot N" instead of "workspace N"
-- while you're already inside the group.

local SPECIAL_RETURN_FILE = "/tmp/ambxst_special_ws_return.txt"
local SPECIAL_SETTINGS_PATH = os.getenv("HOME") .. "/.config/ambxst/mods/positive.special-workspaces.json"

-- Minimal ad hoc reader for this mod's own flat settings file -- avoids
-- pulling in a full JSON library for a handful of simple values.
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
        threshold = math.floor(read_json_value(text, "threshold", 50)),
        dynamicMode = read_json_value(text, "dynamicMode", true),
        slotCount = math.floor(read_json_value(text, "slotCount", 4)),
        animationStyle = read_json_value(text, "animationStyle", "fade"),
    }
end

local sw_settings = load_special_ws_settings()
local SPECIAL_THRESHOLD = sw_settings.threshold

-- Previous versions of this mod crippled swipe sensitivity while inside the
-- (then Hyprland-native) special workspace. That's no longer needed -- swipe
-- works natively in both zones now -- but restore normal sensitivity once at
-- load in case a prior session left it stuck in the crippled state.
pcall(hl.config, { gestures = {
    workspace_swipe_distance = 300,
    workspace_swipe_cancel_ratio = 0.5,
    workspace_swipe_min_speed_to_force = 30
} })

local function is_hidden(id)
    return id ~= nil and id > SPECIAL_THRESHOLD
end

-- A workspace only counts as "regular" (safe to remember as a return
-- target) if it's a real, positive, non-hidden id -- excludes 0/negative
-- ids (e.g. a leftover named workspace from something unrelated), which
-- "not is_hidden(id)" alone wouldn't catch.
local function is_regular(id)
    return id ~= nil and id > 0 and id <= SPECIAL_THRESHOLD
end

-- Recover a previously-persisted last regular workspace id. Needed because
-- `hyprctl reload` (e.g. triggered by a wallpaper change) re-executes this
-- whole script, wiping the in-memory value even if we're currently inside
-- the hidden group.
local function read_saved_regular_ws()
    local f = io.open(SPECIAL_RETURN_FILE, "r")
    if not f then return nil end
    local v = tonumber(f:read("*l"))
    f:close()
    if v and v > 0 and v <= SPECIAL_THRESHOLD then return v end
    return nil
end

local function write_saved_regular_ws(id)
    local f = io.open(SPECIAL_RETURN_FILE, "w")
    if f then
        f:write(tostring(id) .. "\n")
        f:close()
    end
end

local last_regular_ws = read_saved_regular_ws() or 1
-- Single source of truth for the guard: the last workspace id we actually
-- believe we're on. Both crossing directions compare against this
-- directly. Updated in one of two ways: reactively, when a same-zone
-- workspace.active event confirms it, or synchronously/preemptively by any
-- function that deliberately crosses the boundary (see cross_boundary_to
-- below) -- NOT via a "this crossing is pre-approved" flag consumed by a
-- follow-up event, because a dispatch issued from inside the
-- workspace.active handler itself doesn't reliably re-trigger a confirming
-- event, which left such a flag stuck and let the next crossing through
-- unchecked.
local initial_ws = hl.get_active_workspace()
local last_workspace_id = (initial_ws and initial_ws.id) or 1

local function special_group_animation()
    if sw_settings.animationStyle == "slide" then
        return { leaf = "workspaces", enabled = true, speed = 3.0, spring = "workspaceSpring", style = "slidefade 20%" }
    end
    return { leaf = "workspaces", enabled = true, speed = 2.2, bezier = "almostLinear", style = "fade" }
end

local function regular_group_animation()
    return { leaf = "workspaces", enabled = true, speed = 3.0, spring = "workspaceSpring", style = "slidefade 20%" }
end

-- Applies whichever animation belongs to the zone a given workspace id is
-- in (used to restore the right one after a bounce-back's instant snap).
local function apply_zone_animation(id)
    pcall(hl.animation, is_hidden(id) and special_group_animation() or regular_group_animation())
end

local function remember_workspace(id)
    last_workspace_id = id
    if is_regular(id) then
        last_regular_ws = id
        write_saved_regular_ws(id)
    end
end

-- Deliberately cross the boundary: updates our own bookkeeping synchronously
-- BEFORE dispatching, so the guard below sees last_workspace_id already
-- matching the target and never treats the resulting event as a crossing
-- to bounce back, regardless of whether that event fires right away, late,
-- or not at all.
local function cross_boundary_to(target_id)
    remember_workspace(target_id)
    hl.dispatch(hl.dsp.focus({ workspace = target_id }))
end

-- Reactive boundary guard: swipe can't be intercepted directly (no Lua hook
-- exists for it), so instead of preventing the crossing, we catch it right
-- after it happens and bounce back. Both directions are guarded -- only
-- cross_boundary_to (the toggle keybind, number-key jumps into/out of the
-- group) may cross the boundary.
hl.on("workspace.active", function(ws)
    if not ws or not ws.id then return end

    local was_hidden = is_hidden(last_workspace_id)
    local now_hidden = is_hidden(ws.id)

    if was_hidden ~= now_hidden then
        -- Not a pre-approved crossing (cross_boundary_to would have already
        -- updated last_workspace_id to match ws.id) -- bounce straight
        -- back. last_workspace_id needs no update: we're returning to
        -- exactly where it already says we were. The initial animated
        -- slide into the forbidden workspace can't be prevented (this
        -- handler only runs after Hyprland already started it, with no
        -- earlier hook available), but the snap back doesn't need its own
        -- animation layered on top -- disabled just for this one dispatch,
        -- then restored to whichever zone we land back in.
        pcall(hl.animation, { leaf = "workspaces", enabled = false })
        hl.dispatch(hl.dsp.focus({ workspace = last_workspace_id }))
        apply_zone_animation(last_workspace_id)
        return
    end

    remember_workspace(ws.id)
end)

-- Toggle the special group (default SUPER+SHIFT+V, configurable from
-- Ambxst Settings -> Mods): jumps to slot 1 if not currently inside,
-- back to the last regular workspace if already inside.
local function toggle_special_group()
    local cur = hl.get_active_workspace()
    local cur_id = cur and cur.id or 1

    if is_hidden(cur_id) then
        -- Restore the regular animation BEFORE dispatching, so the exit
        -- transition itself (and everything after) uses it.
        pcall(hl.animation, regular_group_animation())
        cross_boundary_to(last_regular_ws)
    else
        remember_workspace(cur_id)
        -- Applied before dispatching, so the entry transition (and
        -- everything else while inside the group) uses it.
        pcall(hl.animation, special_group_animation())
        cross_boundary_to(SPECIAL_THRESHOLD + 1)
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

-- SUPER+1-10 means "slot N" while inside the group, "workspace N" outside
-- it -- same meaning number keys already have for regular workspaces.
local function number_key_nav(n)
    local cur = hl.get_active_workspace()
    local cur_id = cur and cur.id or 1
    if is_hidden(cur_id) then
        cross_boundary_to(SPECIAL_THRESHOLD + n)
    else
        hl.dispatch(hl.dsp.focus({ workspace = n }))
    end
end

for i = 1, 10 do
    local key = tostring(i % 10)
    hl.unbind("SUPER + " .. key)
    hl.bind("SUPER + " .. key, function() number_key_nav(i) end)
end

-- SUPER+Z/X (and the SUPER+Y alias) just use native relative dispatch in
-- both zones -- the boundary guard above catches any accidental crossing.
-- The one exception: a fixed (non-dynamic) slot count needs its own
-- wraparound, since Hyprland's native relative dispatch has no concept of
-- our custom upper bound.
local function zx_nav(relative_dir)
    local cur = hl.get_active_workspace()
    local cur_id = cur and cur.id or 1
    if is_hidden(cur_id) and sw_settings.dynamicMode == false then
        local slot = cur_id - SPECIAL_THRESHOLD
        local total = sw_settings.slotCount
        local next_slot
        if relative_dir == "+1" then
            next_slot = (slot % total) + 1
        else
            next_slot = ((slot - 2 + total) % total) + 1
        end
        hl.dispatch(hl.dsp.focus({ workspace = SPECIAL_THRESHOLD + next_slot }))
    else
        hl.dispatch(hl.dsp.focus({ workspace = relative_dir }))
    end
end

hl.unbind("SUPER + X")
hl.bind("SUPER + X", function() zx_nav("+1") end)

hl.unbind("SUPER + Z")
hl.bind("SUPER + Z", function() zx_nav("-1") end)

-- Intercept SUPER + Y (for QWERTZ keyboards or layout variations)
hl.unbind("SUPER + Y")
hl.bind("SUPER + Y", function() zx_nav("-1") end)

-- SUPER + SHIFT + X/Z (move-to-empty-workspace) and the mouse-button
-- aliases keep their stock, un-special-cased meaning -- Hyprland already
-- won't create an empty workspace past where dynamic creation stops
-- making sense, and these aren't part of what was asked to mirror.
hl.unbind("SUPER + SHIFT + X")
hl.bind("SUPER + SHIFT + X", function() hl.dispatch(hl.dsp.focus({ workspace = "e+1" })) end)

hl.unbind("SUPER + SHIFT + Z")
hl.bind("SUPER + SHIFT + Z", function() hl.dispatch(hl.dsp.focus({ workspace = "e-1" })) end)

hl.unbind("SUPER + mouse_down")
hl.bind("SUPER + mouse_down", function() hl.dispatch(hl.dsp.focus({ workspace = "e+1" })) end)

hl.unbind("SUPER + mouse_up")
hl.bind("SUPER + mouse_up", function() hl.dispatch(hl.dsp.focus({ workspace = "e-1" })) end)

-- Move the active window into/out of slot 1 (SUPER + ALT + V). App
-- auto-assignment (custom_rules.lua) covers Discord -> slot 1 and
-- Spotify/Sonora -> slot 2 by default; this is for anything else you want
-- to throw in/out manually.
hl.unbind("SUPER + ALT + G")
hl.unbind("SUPER + ALT + V")
hl.bind("SUPER + ALT + V", function()
    local win = hl.get_active_window()
    if not win then return end

    local win_ws_id = win.workspace and win.workspace.id or nil
    if is_hidden(win_ws_id) then
        hl.dispatch(hl.dsp.window.move({ workspace = tostring(last_regular_ws) }))
    else
        hl.dispatch(hl.dsp.window.move({ workspace = tostring(SPECIAL_THRESHOLD + 1) }))
    end
end)
