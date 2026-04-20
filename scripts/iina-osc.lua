-- IINA-style bottom bar OSC for mpv
-- A from-scratch implementation inspired by IINA's macOS media player interface
--
-- Install:
--   scripts/iina-osc.lua       -> ~/.config/mpv/scripts/
--   fonts/iina-osc-icons.ttf   -> ~/.config/mpv/fonts/
--   script-opts/iina-osc.conf  -> ~/.config/mpv/script-opts/
-- In mpv.conf: osc=no

local assdraw = require "mp.assdraw"
local msg = require "mp.msg"
local opt = require "mp.options"
local utils = require "mp.utils"

mp.set_property("osc", "no")

---------------------------------------------------------------------------
-- User Options
---------------------------------------------------------------------------
local user_opts = {
    -- Visibility
    showwindowed        = true,
    showfullscreen      = true,
    idlescreen          = true,
    visibility          = "auto",           -- auto / always / never
    visibility_modes    = "never_auto_always",

    -- Scaling
    scalewindowed       = 1.0,
    scalefullscreen     = 1.0,
    vidscale            = "auto",

    -- Timing
    hidetimeout         = 1200,             -- ms before auto-hide
    fadeduration        = 200,              -- ms fade in/out
    fadein              = true,
    minmousemove        = 0,

    -- Bar Geometry
    bar_height          = 70,
    bar_padding_h       = 15,
    bar_padding_v       = 8,
    pill_corner_radius  = 14,
    pill_bottom_margin  = 18,
    pill_width_ratio    = 0.70,

    -- Seekbar
    seekbar_fg_color    = "#00E762",
    seekbar_bg_color    = "#48484A",
    seekbar_cache_color = "#636366",
    seekbar_handle_size = 0.85,
    seekbarkeyframes    = true,
    chapter_marker_color= "#FFD60A",

    -- Appearance
    background_color    = "#1C1C1E",
    background_alpha    = 30,               -- 0=opaque, 255=invisible
    panel_blur          = 2,                -- 0-40
    icons_color         = "#FFFFFF",
    text_color          = "#F2F2F7",
    title_color         = "#EBEBF5",
    held_element_color  = "#8E8E93",
    hover_color         = "#0A84FF",

    -- Time Display
    timetotal           = false,
    remaining_playtime  = true,
    timems              = false,
    unicodeminus        = false,

    -- Controls Visibility
    chapter_buttons     = true,
    volume_control      = true,
    audio_button        = true,
    subtitle_button     = true,
    playlist_button     = true,
    speed_button        = true,
    fullscreen_button   = true,

    -- Seekbar range style
    seekrangestyle      = "inverted",       -- bar / line / inverted / none
    seekrangealpha      = 200,
    chapter_fmt         = "Chapter: %s",

    -- Tick rate
    tick_delay                   = 1 / 60,
    tick_delay_follow_display_fps = false,

    -- Scrollable controls
    scrollcontrols      = true,

    -- Title
    title = "${!playlist-count==1:[${playlist-pos-1}/${playlist-count}] }${media-title}",

    -- Window controls
    windowcontrols      = "no",
    windowcontrols_alignment = "right",

    -- Command bindings  (left / mid / right mouse button)
    play_pause_mbtn_left_command  = "cycle pause",
    play_pause_mbtn_mid_command   = "cycle-values loop-file inf no",
    play_pause_mbtn_right_command = "cycle-values loop-playlist inf no",

    playlist_prev_mbtn_left_command  = "playlist-prev",
    playlist_prev_mbtn_mid_command   = "",
    playlist_prev_mbtn_right_command = "script-binding select/select-playlist; script-message-to iina-osc osc-hide",

    playlist_next_mbtn_left_command  = "playlist-next",
    playlist_next_mbtn_mid_command   = "",
    playlist_next_mbtn_right_command = "script-binding select/select-playlist; script-message-to iina-osc osc-hide",

    chapter_prev_mbtn_left_command  = "osd-msg add chapter -1",
    chapter_prev_mbtn_mid_command   = "",
    chapter_prev_mbtn_right_command = "script-binding select/select-chapter; script-message-to iina-osc osc-hide",

    chapter_next_mbtn_left_command  = "osd-msg add chapter 1",
    chapter_next_mbtn_mid_command   = "",
    chapter_next_mbtn_right_command = "script-binding select/select-chapter; script-message-to iina-osc osc-hide",

    audio_track_mbtn_left_command  = "cycle audio",
    audio_track_mbtn_mid_command   = "cycle audio down",
    audio_track_mbtn_right_command = "script-binding select/select-aid; script-message-to iina-osc osc-hide",
    audio_track_wheel_down_command = "cycle audio",
    audio_track_wheel_up_command   = "cycle audio down",

    sub_track_mbtn_left_command  = "cycle sub",
    sub_track_mbtn_mid_command   = "cycle sub down",
    sub_track_mbtn_right_command = "script-binding select/select-sid; script-message-to iina-osc osc-hide",
    sub_track_wheel_down_command = "cycle sub",
    sub_track_wheel_up_command   = "cycle sub down",

    volume_mbtn_left_command  = "no-osd cycle mute",
    volume_mbtn_mid_command   = "",
    volume_mbtn_right_command = "script-binding select/select-audio-device; script-message-to iina-osc osc-hide",
    volume_wheel_down_command = "add volume -5",
    volume_wheel_up_command   = "add volume 5",

    fullscreen_mbtn_left_command  = "cycle fullscreen",
    fullscreen_mbtn_mid_command   = "",
    fullscreen_mbtn_right_command = "cycle window-maximized",
}

---------------------------------------------------------------------------
-- Icon Font & Glyph Mapping (uses modernz-icons / iina-osc-icons.ttf)
---------------------------------------------------------------------------
local icon_font = "modernz-icons"

local icons = {
    play            = "material_play_arrow_filled",
    pause           = "material_pause_filled",
    replay          = "material_replay_filled",
    skip_previous   = "material_skip_previous_filled",
    skip_next       = "material_skip_next_filled",
    chapter_prev    = "material_fast_rewind_filled",
    chapter_next    = "material_fast_forward_filled",
    volume_mute     = "material_no_sound",
    volume_quiet    = "material_volume_mute",
    volume_low      = "material_volume_down",
    volume_high     = "material_volume_up",
    audio           = "fluent_volume_up",
    subtitle        = "material_subtitles",
    fullscreen      = "material_fullscreen",
    fullscreen_exit = "material_fullscreen_exit",
    playlist        = "material_playlist_play",
    close           = "window_close",
    minimize        = "window_minimize",
    maximize        = "window_maximize",
    unmaximize      = "window_unmaximize",
}

---------------------------------------------------------------------------
-- Color Conversion & ASS Styles
---------------------------------------------------------------------------
-- Convert "#RRGGBB" to ASS "BBGGRR"
local function osc_color_convert(color)
    if not color or #color ~= 7 then return "FFFFFF" end
    return color:sub(6, 7) .. color:sub(4, 5) .. color:sub(2, 3)
end

local osc_styles
local function set_osc_styles()
    local ic = osc_color_convert(user_opts.icons_color)
    local tc = osc_color_convert(user_opts.text_color)
    local bg = osc_color_convert(user_opts.background_color)
    local hc = osc_color_convert(user_opts.held_element_color)
    local blur = tostring(math.min(40, math.max(0, user_opts.panel_blur)))

    osc_styles = {
        bar_bg = "{\\rDefault\\blur" .. blur .. "\\bord0\\shad0"
            .. "\\1c&H" .. bg .. "&}",

        icons = "{\\blur0\\bord0\\1c&H" .. ic .. "&\\3c&HFFFFFF&\\fn" .. icon_font .. "}",
        icons_large = "{\\blur0\\bord0\\1c&H" .. ic .. "&\\3c&HFFFFFF&\\fs36\\fn" .. icon_font .. "}",
        icons_small = "{\\blur0\\bord0\\1c&H" .. ic .. "&\\3c&HFFFFFF&\\fs24\\fn" .. icon_font .. "}",

        timecodes = "{\\blur0\\bord0\\1c&H" .. tc .. "&\\3c&HFFFFFF&\\fs20}",
        vidtitle  = "{\\blur0\\bord0\\1c&H" .. osc_color_convert(user_opts.title_color) .. "&\\3c&HFFFFFF&\\fs14\\q2}",

        elementDown = "{\\1c&H" .. hc .. "&}",

        tooltip = "{\\blur0\\bord1\\1c&HFFFFFF&\\3c&H000000&\\fs17}",

        seekbar_fg = "{\\blur0\\bord0\\1c&H" .. osc_color_convert(user_opts.seekbar_fg_color) .. "&}",
        seekbar_bg = "{\\blur0\\bord0\\1c&H" .. osc_color_convert(user_opts.seekbar_bg_color) .. "&}",
        seekbar_cache = "{\\blur0\\bord0\\1c&H" .. osc_color_convert(user_opts.seekbar_cache_color) .. "&}",
        seekbar_marker = "{\\blur0\\bord0\\1c&H" .. osc_color_convert(user_opts.chapter_marker_color) .. "&}",

        wcButtons = "{\\1c&H" .. ic .. "&\\fs20\\fn" .. icon_font .. "}",

        speed_text = "{\\blur0\\bord0\\1c&H" .. ic .. "&\\3c&HFFFFFF&\\fs16}",
        wcBar     = "{\\1c&H" .. bg .. "&}",

        dropdown_bg = "{\\rDefault\\blur1\\bord0\\shad0\\1c&H" .. bg .. "&}",
        dropdown_item = "{\\blur0\\bord1\\shad0\\1c&HFFFFFF&\\3c&H000000&\\fs18\\q2}",
        dropdown_item_active = "{\\blur0\\bord1\\shad0\\1c&H"
            .. osc_color_convert(user_opts.seekbar_fg_color) .. "&\\3c&H000000&\\fs18\\q2}",
    }
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local UNICODE_MINUS = string.char(0xe2, 0x88, 0x92)

local state = {
    showtime          = nil,
    osc_visible       = false,
    anistart          = nil,
    anitype           = nil,        -- "in" / "out" / nil
    animation         = nil,        -- alpha 0-255
    mouse_down_counter = 0,
    active_element    = nil,
    active_event_source = nil,
    rightTC_trem      = true,
    tc_ms             = false,
    screen_sizeX      = nil,
    screen_sizeY      = nil,
    initREQ           = false,
    marginsREQ        = false,
    last_mouseX       = nil,
    last_mouseY       = nil,
    mouse_in_window   = false,
    fullscreen        = false,
    tick_timer        = nil,
    tick_last_time    = 0,
    hide_timer        = nil,
    cache_state       = nil,
    idle              = false,
    enabled           = true,
    input_enabled     = false,
    showhide_enabled  = false,
    border            = true,
    title_bar         = true,
    maximized         = false,
    paused            = false,
    osd               = mp.create_osd_overlay("ass-events"),
    chapter_list      = {},
    forced_title      = nil,
    slider_element    = nil,
    visibility_modes  = {},
    using_video_margins = false,
    -- Pill drag
    pill_y_offset       = 0,
    pill_dragging       = false,
    pill_drag_start_y   = nil,
    pill_drag_start_offset = nil,
    -- Track dropdown
    dropdown            = nil,       -- nil / "audio" / "sub" / "playlist" / "speed"
    dropdown_items      = {},        -- {{id, x1, y1, x2, y2}, ...}
    dropdown_scroll     = 0,         -- scroll offset (number of items scrolled)
    dropdown_hitbox     = nil,       -- {x1, y1, x2, y2} bounding box of dropdown
}

local osc_param = {
    playresy      = 0,
    playresx      = 0,
    display_aspect = 1,
    unscaled_y    = 0,
    areas         = {},
    video_margins = { l = 0, r = 0, t = 0, b = 0 },
}

local tick_delay = 1 / 60
local audio_track_count = 0
local sub_track_count = 0
local window_control_box_width = 80
local elements = {}

-- Thumbfast state
local thumbfast = { width = 0, height = 0, disabled = true, available = false }

---------------------------------------------------------------------------
-- Logo lines (mpv idle screen)
---------------------------------------------------------------------------
local logo_lines = {
    "{\\c&HE5E5E5&\\p6}m 895 10 b 401 10 0 410 0 905 0 1399 401 1800 895 1800 1390 1800 1790 1399 1790 905 1790 410 1390 10 895 10 {\\p0}",
    "{\\c&H682167&\\p6}m 925 42 b 463 42 87 418 87 880 87 1343 463 1718 925 1718 1388 1718 1763 1343 1763 880 1763 418 1388 42 925 42{\\p0}",
    "{\\c&H430142&\\p6}m 1605 828 b 1605 1175 1324 1456 977 1456 631 1456 349 1175 349 828 349 482 631 200 977 200 1324 200 1605 482 1605 828{\\p0}",
    "{\\c&HDDDBDD&\\p6}m 1296 910 b 1296 1131 1117 1310 897 1310 676 1310 497 1131 497 910 497 689 676 511 897 511 1117 511 1296 689 1296 910{\\p0}",
    "{\\c&H691F69&\\p6}m 762 1113 l 762 708 b 881 776 1000 843 1119 911 1000 978 881 1046 762 1113{\\p0}",
}

---------------------------------------------------------------------------
-- Helper Functions
---------------------------------------------------------------------------

local function kill_animation()
    state.anistart = nil
    state.animation = nil
    state.anitype = nil
end

local function set_osd(res_x, res_y, text, z)
    if state.osd.res_x == res_x and
       state.osd.res_y == res_y and
       state.osd.data == text then
        return
    end
    state.osd.res_x = res_x
    state.osd.res_y = res_y
    state.osd.data = text
    state.osd.z = z
    state.osd:update()
end

-- scale factor: virtual ASS coords <-> real screen coords
local function get_virt_scale_factor()
    local w, h = mp.get_osd_size()
    if w <= 0 or h <= 0 then return 0, 0 end
    return osc_param.playresx / w, osc_param.playresy / h
end

local function get_virt_mouse_pos()
    if state.mouse_in_window then
        local sx, sy = get_virt_scale_factor()
        local x, y = mp.get_mouse_pos()
        return x * sx, y * sy
    end
    return -1, -1
end

local function set_virt_mouse_area(x0, y0, x1, y1, name)
    local sx, sy = get_virt_scale_factor()
    if sx > 0 and sy > 0 then
        mp.set_mouse_area(x0 / sx, y0 / sy, x1 / sx, y1 / sy, name)
    end
end

local function scale_value(x0, x1, y0, y1, val)
    local m = (y1 - y0) / (x1 - x0)
    local b = y0 - (m * x0)
    return (m * val) + b
end

local function limit_range(min, max, val)
    if val > max then val = max
    elseif val < min then val = min
    end
    return val
end

-- alignment helper: place object within frame
local function get_align(align, frame, obj, margin)
    return (frame / 2) + (((frame / 2) - margin - (obj / 2)) * align)
end

-- alpha blending
local function mult_alpha(alphaA, alphaB)
    return 255 - (((1 - (alphaA / 255)) * (1 - (alphaB / 255))) * 255)
end

local function add_area(name, x1, y1, x2, y2)
    if osc_param.areas[name] == nil then
        osc_param.areas[name] = {}
    end
    table.insert(osc_param.areas[name], {x1 = x1, y1 = y1, x2 = x2, y2 = y2})
end

local function ass_append_alpha(ass, alpha, modifier)
    local ar = {}
    for ai, av in pairs(alpha) do
        av = mult_alpha(av, modifier)
        if state.animation then
            av = mult_alpha(av, state.animation)
        end
        ar[ai] = av
    end
    ass:append(string.format("{\\1a&H%X&\\2a&H%X&\\3a&H%X&\\4a&H%X&}",
        ar[1], ar[2], ar[3], ar[4]))
end

-- hitbox from geometry
local function get_hitbox_coords(x, y, an, w, h)
    local alignments = {
        [1] = function() return x, y - h, x + w, y end,
        [2] = function() return x - (w / 2), y - h, x + (w / 2), y end,
        [3] = function() return x - w, y - h, x, y end,
        [4] = function() return x, y - (h / 2), x + w, y + (h / 2) end,
        [5] = function() return x - (w / 2), y - (h / 2), x + (w / 2), y + (h / 2) end,
        [6] = function() return x - w, y - (h / 2), x, y + (h / 2) end,
        [7] = function() return x, y, x + w, y + h end,
        [8] = function() return x - (w / 2), y, x + (w / 2), y + h end,
        [9] = function() return x - w, y, x, y + h end,
    }
    return alignments[an]()
end

local function get_hitbox_coords_geo(geometry)
    return get_hitbox_coords(geometry.x, geometry.y, geometry.an,
        geometry.w, geometry.h)
end

local function get_element_hitbox(element)
    return element.hitbox.x1, element.hitbox.y1,
        element.hitbox.x2, element.hitbox.y2
end

local function mouse_hit_coords(bX1, bY1, bX2, bY2)
    local mX, mY = get_virt_mouse_pos()
    return (mX >= bX1 and mX <= bX2 and mY >= bY1 and mY <= bY2)
end

local function mouse_hit(element)
    return mouse_hit_coords(get_element_hitbox(element))
end

-- slider: translate value to element position
local function get_slider_ele_pos_for(element, val)
    local ele_pos = scale_value(
        element.slider.min.value, element.slider.max.value,
        element.slider.min.ele_pos, element.slider.max.ele_pos,
        val)
    return limit_range(
        element.slider.min.ele_pos, element.slider.max.ele_pos,
        ele_pos)
end

-- slider: translate global mouse position to value
local function get_slider_value_at(element, glob_pos)
    local val = scale_value(
        element.slider.min.glob_pos, element.slider.max.glob_pos,
        element.slider.min.value, element.slider.max.value,
        glob_pos)
    return limit_range(
        element.slider.min.value, element.slider.max.value,
        val)
end

local function get_slider_value(element)
    return get_slider_value_at(element, get_virt_mouse_pos())
end

local function get_hidetimeout()
    if user_opts.visibility == "always" then return -1 end
    return user_opts.hidetimeout
end

local function cache_enabled()
    return state.cache_state and #state.cache_state["seekable-ranges"] > 0
end

local function render_wipe()
    msg.trace("render_wipe()")
    state.osd.data = ""
    state.osd:remove()
end

local function update_margins()
    local margins = { l = 0, r = 0, t = 0, b = 0 }
    mp.set_property_native("user-data/osc/margins", margins)
end

---------------------------------------------------------------------------
-- Pill Offset Persistence
---------------------------------------------------------------------------
local function get_state_file_path()
    local dir = mp.command_native({"expand-path", "~~home/script-data"})
    return utils.join_path(dir, "iina-osc-state")
end

local function save_pill_offset()
    local dir = mp.command_native({"expand-path", "~~home/script-data"})
    utils.subprocess({args = {"mkdir", "-p", dir}})
    local path = get_state_file_path()
    local f = io.open(path, "w")
    if f then
        f:write(string.format("pill_y_offset=%d\n", state.pill_y_offset or 0))
        f:close()
    end
end

local function load_pill_offset()
    local path = get_state_file_path()
    local f = io.open(path, "r")
    if f then
        for line in f:lines() do
            local val = line:match("^pill_y_offset=(-?%d+)")
            if val then state.pill_y_offset = tonumber(val) end
        end
        f:close()
    end
end

---------------------------------------------------------------------------
-- Tick Request (forward declaration)
---------------------------------------------------------------------------
local tick

local function request_tick()
    if state.tick_timer == nil then
        state.tick_timer = mp.add_timeout(0, tick)
    end
    if not state.tick_timer:is_enabled() then
        local now = mp.get_time()
        local timeout = tick_delay - (now - state.tick_last_time)
        if timeout < 0 then timeout = 0 end
        state.tick_timer.timeout = timeout
        state.tick_timer:resume()
    end
end

local function request_init()
    state.initREQ = true
    request_tick()
end

local function request_init_resize()
    request_init()
    if state.tick_timer then
        state.tick_timer:kill()
        state.tick_timer.timeout = 0
        state.tick_timer:resume()
    end
end

---------------------------------------------------------------------------
-- Tracklist Management
---------------------------------------------------------------------------
local function update_tracklist()
    audio_track_count, sub_track_count = 0, 0
    for _, track in pairs(mp.get_property_native("track-list")) do
        if track.type == "audio" then
            audio_track_count = audio_track_count + 1
        elseif track.type == "sub" then
            sub_track_count = sub_track_count + 1
        end
    end
end

---------------------------------------------------------------------------
-- Window Controls
---------------------------------------------------------------------------
local function window_controls_enabled()
    local val = user_opts.windowcontrols
    if val == "auto" then
        return not (state.border and state.title_bar)
    end
    return val ~= "no"
end

---------------------------------------------------------------------------
-- Element System
---------------------------------------------------------------------------

local function new_element(name, type)
    elements[name] = {}
    elements[name].name = name
    elements[name].type = type
    elements[name].eventresponder = {}
    elements[name].visible = true
    elements[name].enabled = true
    elements[name].softrepeat = false
    elements[name].styledown = (type == "button")
    elements[name].state = {}
    elements[name].iina_seekbar = false

    if type == "slider" then
        elements[name].slider = {min = {value = 0}, max = {value = 100}}
    end

    return elements[name]
end

local function add_layout(name)
    if elements[name] == nil then
        msg.error("Can't add_layout to element '" .. name .. "', doesn't exist.")
        return
    end

    elements[name].layout = {}
    elements[name].layout.layer = 50
    elements[name].layout.alpha = {[1] = 0, [2] = 255, [3] = 255, [4] = 255}

    if elements[name].type == "button" then
        elements[name].layout.button = { maxchars = nil }
    elseif elements[name].type == "slider" then
        elements[name].layout.slider = {
            border = 0,
            gap = 2,
            nibbles_top = false,
            nibbles_bottom = false,
            stype = "knob",
            adjust_tooltip = true,
            tooltip_style = "",
            tooltip_an = 2,
            alpha = {[1] = 0, [2] = 255, [3] = 88, [4] = 255},
        }
    elseif elements[name].type == "box" then
        elements[name].layout.box = { radius = 0 }
    end

    return elements[name].layout
end

local function prepare_elements()
    -- filter to visible elements with layout
    local elements2 = {}
    for _, element in pairs(elements) do
        if element.layout ~= nil and element.visible then
            table.insert(elements2, element)
        end
    end
    elements = elements2

    -- sort by layer
    table.sort(elements, function(a, b)
        return a.layout.layer < b.layout.layer
    end)

    for _, element in pairs(elements) do
        local elem_geo = element.layout.geometry

        -- Calculate hitbox
        local bX1, bY1, bX2, bY2 = get_hitbox_coords_geo(elem_geo)
        element.hitbox = {x1 = bX1, y1 = bY1, x2 = bX2, y2 = bY2}

        -- Prepare style ASS
        local style_ass = assdraw.ass_new()
        style_ass:append("{}") -- force new line
        style_ass:new_event()
        style_ass:pos(elem_geo.x, elem_geo.y)
        style_ass:an(elem_geo.an)
        style_ass:append(element.layout.style)
        element.style_ass = style_ass

        -- Prepare static ASS (for box and slider outlines)
        local static_ass = assdraw.ass_new()

        if element.type == "box" then
            static_ass:draw_start()
            local r = element.layout.box.radius
            if r > 0 then
                static_ass:round_rect_cw(0, 0, elem_geo.w, elem_geo.h, r)
            else
                static_ass:rect_cw(0, 0, elem_geo.w, elem_geo.h)
            end
            static_ass:draw_stop()

        elseif element.type == "slider" then
            local slider_lo = element.layout.slider
            local foV = slider_lo.border + slider_lo.gap
            local r1 = elem_geo.h / 2
            local r2 = r1

            element.slider.min.ele_pos = r1
            element.slider.max.ele_pos = elem_geo.w - r1

            element.slider.min.glob_pos =
                element.hitbox.x1 + element.slider.min.ele_pos
            element.slider.max.glob_pos =
                element.hitbox.x1 + element.slider.max.ele_pos

            -- For IINA seekbar, we draw the track/fill/knob in render_elements
            -- For volume slider, draw a thin outline
            if not element.iina_seekbar then
                static_ass:draw_start()
                static_ass:round_rect_cw(0, 0, elem_geo.w, elem_geo.h, r1)
                static_ass:round_rect_ccw(slider_lo.border, slider_lo.border,
                    elem_geo.w - slider_lo.border, elem_geo.h - slider_lo.border, r2)
                static_ass:draw_stop()
            end
        end

        element.static_ass = static_ass

        -- disabled styling
        if not element.enabled then
            element.layout.alpha[1] = 136
            element.eventresponder = nil
        end
    end
end

---------------------------------------------------------------------------
-- Element Rendering
---------------------------------------------------------------------------

local function get_chapter(possec)
    local cl = state.chapter_list
    for n = #cl, 1, -1 do
        if possec >= cl[n].time then
            return cl[n]
        end
    end
end

local function render_elements(master_ass)
    -- Chapter tooltip from seekbar hover
    state.forced_title = nil
    local se, ae = state.slider_element, elements[state.active_element]
    if user_opts.chapter_fmt ~= "no" and se and
       (ae == se or (not ae and mouse_hit(se))) then
        local dur = mp.get_property_number("duration", 0)
        if dur > 0 then
            local possec = get_slider_value(se) * dur / 100
            local ch = get_chapter(possec)
            if ch and ch.title and ch.title ~= "" then
                state.forced_title = string.format(user_opts.chapter_fmt, ch.title)
            end
        end
    end

    for n = 1, #elements do
        local element = elements[n]
        local elem_geo = element.layout.geometry

        local style_ass = assdraw.ass_new()
        style_ass:merge(element.style_ass)
        ass_append_alpha(style_ass, element.layout.alpha, 0)

        if element.eventresponder and (state.active_element == n) then
            if element.eventresponder.render then
                element.eventresponder.render(element)
            end
            if mouse_hit(element) then
                if element.styledown then
                    style_ass:append(osc_styles.elementDown)
                end
                if element.softrepeat and state.mouse_down_counter >= 15
                    and state.mouse_down_counter % 5 == 0 then
                    element.eventresponder[state.active_event_source .. "_down"](element)
                end
                state.mouse_down_counter = state.mouse_down_counter + 1
            end
        end

        local elem_ass = assdraw.ass_new()
        elem_ass:merge(style_ass)

        if element.type == "box" then
            elem_ass:merge(element.static_ass)

        elseif element.type == "slider" then

            if element.iina_seekbar then
                -- === IINA-style custom seekbar rendering ===
                local pos = element.slider.posF()
                local xp = pos and get_slider_ele_pos_for(element, pos)
                local cx = elem_geo.h / 2  -- center y in local coords
                local track_h = 5
                local handle_r = (user_opts.seekbar_handle_size * (elem_geo.h - 4)) / 2
                local seek_left = element.slider.min.ele_pos
                local seek_right = element.slider.max.ele_pos

                -- 1. Track background (gray bar, full width)
                elem_ass:new_event()
                elem_ass:pos(elem_geo.x, elem_geo.y)
                elem_ass:an(elem_geo.an)
                ass_append_alpha(elem_ass, element.layout.alpha, 0)
                elem_ass:append(osc_styles.seekbar_bg)
                elem_ass:draw_start()
                elem_ass:move_to(0, 0)
                elem_ass:move_to(elem_geo.w, elem_geo.h)
                elem_ass:round_rect_cw(seek_left, cx - track_h / 2,
                    seek_right, cx + track_h / 2, track_h / 2)
                elem_ass:draw_stop()

                -- 2. Seek ranges / buffer (medium gray)
                if user_opts.seekrangestyle ~= "none" then
                    local seekRanges = element.slider.seekRangesF()
                    if seekRanges then
                        elem_ass:new_event()
                        elem_ass:pos(elem_geo.x, elem_geo.y)
                        elem_ass:an(elem_geo.an)
                        ass_append_alpha(elem_ass, element.layout.alpha,
                            user_opts.seekrangealpha)
                        elem_ass:append(osc_styles.seekbar_cache)
                        elem_ass:draw_start()
                        elem_ass:move_to(0, 0)
                        elem_ass:move_to(elem_geo.w, elem_geo.h)
                        for _, range in pairs(seekRanges) do
                            local ps = get_slider_ele_pos_for(element, range["start"])
                            local pe = get_slider_ele_pos_for(element, range["end"])
                            elem_ass:round_rect_cw(ps, cx - track_h / 2,
                                pe, cx + track_h / 2, track_h / 2)
                        end
                        elem_ass:draw_stop()
                    end
                end

                -- 3. Progress fill (white bar, from left to position)
                if xp then
                    elem_ass:new_event()
                    elem_ass:pos(elem_geo.x, elem_geo.y)
                    elem_ass:an(elem_geo.an)
                    ass_append_alpha(elem_ass, element.layout.alpha, 0)
                    elem_ass:append(osc_styles.seekbar_fg)
                    elem_ass:draw_start()
                    elem_ass:move_to(0, 0)
                    elem_ass:move_to(elem_geo.w, elem_geo.h)
                    elem_ass:round_rect_cw(seek_left, cx - track_h / 2,
                        xp, cx + track_h / 2, track_h / 2)
                    elem_ass:draw_stop()
                end

                -- 4. Chapter markers (yellow ticks)
                if element.slider.markerF then
                    local markers = element.slider.markerF()
                    if markers and #markers > 0 then
                        elem_ass:new_event()
                        elem_ass:pos(elem_geo.x, elem_geo.y)
                        elem_ass:an(elem_geo.an)
                        ass_append_alpha(elem_ass, element.layout.alpha, 0)
                        elem_ass:append(osc_styles.seekbar_marker)
                        elem_ass:draw_start()
                        elem_ass:move_to(0, 0)
                        elem_ass:move_to(elem_geo.w, elem_geo.h)
                        for _, marker in pairs(markers) do
                            if marker > element.slider.min.value and
                               marker < element.slider.max.value then
                                local s = get_slider_ele_pos_for(element, marker)
                                elem_ass:rect_cw(s - 1.2, cx - track_h * 1.3, s + 1.2, cx + track_h * 1.3)
                            end
                        end
                        elem_ass:draw_stop()
                    end
                end

                -- 5. Knob handle (white circle)
                if xp then
                    local kr = handle_r
                    -- enlarge on hover
                    if mouse_hit(element) and state.active_element ~= n then
                        kr = kr * 1.3
                    end
                    elem_ass:new_event()
                    elem_ass:pos(elem_geo.x, elem_geo.y)
                    elem_ass:an(elem_geo.an)
                    ass_append_alpha(elem_ass, element.layout.alpha, 0)
                    elem_ass:append("{\\blur0\\bord0\\1c&HFFFFFF&}")
                    elem_ass:draw_start()
                    elem_ass:move_to(0, 0)
                    elem_ass:move_to(elem_geo.w, elem_geo.h)
                    elem_ass:round_rect_cw(xp - kr, cx - kr, xp + kr, cx + kr, kr)
                    elem_ass:draw_stop()
                end

                -- 6. Tooltip (time on hover)
                if element.slider.tooltipF and mouse_hit(element) then
                    local sliderpos = get_slider_value(element)
                    local tooltiplabel = element.slider.tooltipF(sliderpos)
                    local tx = get_virt_mouse_pos()
                    local ty = element.hitbox.y1 - 6

                    -- clamp tooltip position
                    local an = 2
                    if sliderpos < 3 then
                        an = 1
                    elseif sliderpos > 97 then
                        an = 3
                    end

                    elem_ass:new_event()
                    elem_ass:pos(tx, ty)
                    elem_ass:an(an)
                    elem_ass:append(osc_styles.tooltip)
                    ass_append_alpha(elem_ass, element.layout.slider.alpha, 0)
                    elem_ass:append(tooltiplabel)

                    -- Thumbfast thumbnail
                    if thumbfast.available and not thumbfast.disabled then
                        local duration = mp.get_property_number("duration", 0)
                        if duration > 0 then
                            local possec = duration * sliderpos / 100
                            local sx, sy = get_virt_scale_factor()
                            if sx > 0 and sy > 0 then
                                local thumb_x = math.floor(
                                    get_virt_mouse_pos() / sx - thumbfast.width / 2)
                                local thumb_y = math.floor(
                                    element.hitbox.y1 / sy - thumbfast.height - 10)
                                mp.commandv("script-message-to", "thumbfast",
                                    "thumb", possec, thumb_x, thumb_y)
                            end
                        end
                    end
                else
                    -- Clear thumbfast when not hovering seekbar
                    if thumbfast.available and element.iina_seekbar then
                        mp.commandv("script-message-to", "thumbfast", "clear")
                    end
                end

            else
                -- === Standard slider rendering (for volume etc.) ===
                elem_ass:merge(element.static_ass)

                local slider_lo = element.layout.slider
                local pos = element.slider.posF()
                local foV = slider_lo.border + slider_lo.gap
                local foH = elem_geo.h / 2
                local innerH = elem_geo.h - (2 * foV)

                if pos then
                    local xp = get_slider_ele_pos_for(element, pos)
                    local r = (0.5 * innerH) / 2  -- small knob for volume

                    -- remaining track (gray)
                    elem_ass:new_event()
                    elem_ass:pos(elem_geo.x, elem_geo.y)
                    elem_ass:an(elem_geo.an)
                    ass_append_alpha(elem_ass, element.layout.alpha, 0)
                    elem_ass:append(osc_styles.seekbar_bg)
                    elem_ass:draw_start()
                    elem_ass:move_to(0, 0)
                    elem_ass:move_to(elem_geo.w, elem_geo.h)
                    elem_ass:round_rect_cw(foH - innerH / 6, foH - innerH / 6,
                        elem_geo.w - foH + innerH / 6, foH + innerH / 6, innerH / 6)
                    elem_ass:draw_stop()

                    -- fill bar (green)
                    elem_ass:new_event()
                    elem_ass:pos(elem_geo.x, elem_geo.y)
                    elem_ass:an(elem_geo.an)
                    ass_append_alpha(elem_ass, element.layout.alpha, 0)
                    elem_ass:append(osc_styles.seekbar_fg)
                    elem_ass:draw_start()
                    elem_ass:move_to(0, 0)
                    elem_ass:move_to(elem_geo.w, elem_geo.h)
                    elem_ass:round_rect_cw(foH - innerH / 6, foH - innerH / 6,
                        xp, foH + innerH / 6, innerH / 6)
                    elem_ass:draw_stop()

                    -- knob (white)
                    elem_ass:new_event()
                    elem_ass:pos(elem_geo.x, elem_geo.y)
                    elem_ass:an(elem_geo.an)
                    ass_append_alpha(elem_ass, element.layout.alpha, 0)
                    elem_ass:append("{\\blur0\\bord0\\1c&HFFFFFF&}")
                    elem_ass:draw_start()
                    elem_ass:move_to(0, 0)
                    elem_ass:move_to(elem_geo.w, elem_geo.h)
                    elem_ass:round_rect_cw(xp - r, foH - r, xp + r, foH + r, r)
                    elem_ass:draw_stop()
                end

                -- Volume tooltip
                if element.slider.tooltipF and mouse_hit(element) then
                    local sliderpos = get_slider_value(element)
                    local tooltiplabel = element.slider.tooltipF(sliderpos)
                    elem_ass:new_event()
                    elem_ass:pos(get_virt_mouse_pos(), element.hitbox.y1 - 4)
                    elem_ass:an(2)
                    elem_ass:append(osc_styles.tooltip)
                    ass_append_alpha(elem_ass, slider_lo.alpha, 0)
                    elem_ass:append(tooltiplabel)
                end
            end

        elseif element.type == "button" then
            local buttontext
            if type(element.content) == "function" then
                buttontext = element.content()
            elseif element.content ~= nil then
                buttontext = element.content
            end

            if buttontext then
                local maxchars = element.layout.button.maxchars
                if maxchars ~= nil and #buttontext > maxchars then
                    local limit = math.max(0, math.floor(maxchars * 1.25) - 3)
                    if #buttontext > limit then
                        while #buttontext > limit do
                            buttontext = buttontext:gsub(".[\128-\191]*$", "")
                        end
                        buttontext = buttontext .. "..."
                    end
                    buttontext = string.format("{\\fscx%f}",
                        (maxchars / #buttontext) * 100) .. buttontext
                end
                elem_ass:append(buttontext)
            end
        end

        master_ass:merge(elem_ass)
    end
end

-- UTF-8 aware string truncation (max_chars = max Unicode codepoints)
-- Width-aware UTF-8 truncation: CJK chars count as 2 width units, others as 1
local function utf8_trunc(s, max_width)
    local width = 0
    local i = 1
    local len = #s
    while i <= len do
        local b = s:byte(i)
        local char_len, codepoint
        if b < 0x80 then
            char_len = 1
            codepoint = b
        elseif b < 0xE0 then
            char_len = 2
            codepoint = (b - 0xC0) * 64 + (s:byte(i + 1) - 0x80)
        elseif b < 0xF0 then
            char_len = 3
            codepoint = (b - 0xE0) * 4096 + (s:byte(i + 1) - 0x80) * 64
                      + (s:byte(i + 2) - 0x80)
        else
            char_len = 4
            codepoint = (b - 0xF0) * 262144 + (s:byte(i + 1) - 0x80) * 4096
                      + (s:byte(i + 2) - 0x80) * 64 + (s:byte(i + 3) - 0x80)
        end
        local cw = (codepoint >= 0x2E80) and 2 or 1
        if width + cw > max_width then
            return s:sub(1, i - 1) .. "..."
        end
        width = width + cw
        i = i + char_len
    end
    return s
end

local function render_dropdown(master_ass)
    if state.dropdown == nil then
        state.dropdown_hitbox = nil
        return
    end

    -- Find anchor button element
    local anchor_name
    if state.dropdown == "audio" then
        anchor_name = "audio_track"
    elseif state.dropdown == "sub" then
        anchor_name = "sub_track"
    elseif state.dropdown == "playlist" then
        anchor_name = "playlist_list"
    elseif state.dropdown == "speed" then
        anchor_name = "speed"
    else
        state.dropdown = nil
        state.dropdown_hitbox = nil
        return
    end

    local anchor = nil
    for _, element in ipairs(elements) do
        if element.name == anchor_name then
            anchor = element
            break
        end
    end
    if not anchor or not anchor.hitbox then
        state.dropdown = nil
        state.dropdown_hitbox = nil
        return
    end

    -- Build items depending on dropdown type
    local items = {}

    if state.dropdown == "playlist" then
        local playlist = mp.get_property_native("playlist", {})
        local current_pos = mp.get_property_number("playlist-pos", 0)
        for i, entry in ipairs(playlist) do
            local label = ""
            if entry.title and entry.title ~= "" then
                label = entry.title
            elseif entry.filename then
                label = entry.filename:match("([^/\\]+)$") or entry.filename
            end
            if label == "" then
                label = "Item " .. i
            end
            label = utf8_trunc(label, 36)
            table.insert(items, {
                id = i - 1,
                label = label,
                selected = ((i - 1) == current_pos),
            })
        end
    elseif state.dropdown == "speed" then
        local speed_presets = {2.0, 1.75, 1.5, 1.25, 1.0, 0.75, 0.5, 0.25}
        local current_speed = mp.get_property_number("speed", 1)
        for i, sp in ipairs(speed_presets) do
            local label
            if sp == math.floor(sp) then
                label = string.format("%d.0x", sp)
            else
                label = string.format("%gx", sp)
            end
            local is_selected = (math.abs(current_speed - sp) < 0.01)
            table.insert(items, {
                id = i,
                label = label,
                selected = is_selected,
                speed_val = sp,
            })
        end
    else
        -- Audio / subtitle track dropdown
        local track_type = state.dropdown == "audio" and "audio" or "sub"
        local prop = state.dropdown == "audio" and "aid" or "sid"
        local tracks = mp.get_property_native("track-list", {})
        local current_id = mp.get_property_number(prop, 0)

        table.insert(items, {id = 0, label = "Disabled", selected = (current_id == 0)})
        for _, track in ipairs(tracks) do
            if track.type == track_type then
                local label = ""
                if track.title and track.title ~= "" then
                    label = track.title
                elseif track.lang and track.lang ~= "" then
                    label = track.lang
                end
                if label == "" then
                    label = "Track " .. track.id
                else
                    label = "Track " .. track.id .. ": " .. label
                end
                label = utf8_trunc(label, 36)
                table.insert(items, {
                    id = track.id,
                    label = label,
                    selected = track.selected,
                })
            end
        end
    end

    if #items == 0 then
        state.dropdown = nil
        state.dropdown_hitbox = nil
        return
    end

    -- Dropdown geometry
    local item_h = 30
    local pad = 10
    local dropdown_w = (state.dropdown == "speed") and 130 or 370

    -- Calculate max available height (don't exceed video window)
    local input_area = osc_param.areas["input"] and osc_param.areas["input"][1]
    local pill_top = input_area and input_area.y1 or anchor.hitbox.y1
    local dropdown_bottom = pill_top - 6
    local max_dropdown_h = dropdown_bottom - 10  -- leave 10px margin at top

    -- Full content height vs max height
    local full_h = (#items * item_h) + (2 * pad)
    local dropdown_h = math.min(full_h, max_dropdown_h)

    -- How many items can be visible at once
    local visible_area_h = dropdown_h - (2 * pad)
    local max_visible = math.floor(visible_area_h / item_h)
    if max_visible < 1 then max_visible = 1 end
    local needs_scroll = #items > max_visible

    -- Clamp scroll offset
    local max_scroll = math.max(0, #items - max_visible)
    state.dropdown_scroll = math.max(0, math.min(state.dropdown_scroll, max_scroll))
    local scroll_offset = state.dropdown_scroll

    -- Recalculate dropdown_h based on actual visible items
    local visible_count = math.min(#items, max_visible)
    dropdown_h = (visible_count * item_h) + (2 * pad)

    local anchor_cx = (anchor.hitbox.x1 + anchor.hitbox.x2) / 2
    local dropdown_x = anchor_cx - dropdown_w / 2
    local dropdown_top = dropdown_bottom - dropdown_h

    -- Clamp to screen horizontally
    if dropdown_x < 5 then dropdown_x = 5 end
    if dropdown_x + dropdown_w > osc_param.playresx - 5 then
        dropdown_x = osc_param.playresx - 5 - dropdown_w
    end
    if dropdown_top < 5 then dropdown_top = 5 end

    -- Store dropdown hitbox for mouse-over detection
    state.dropdown_hitbox = {
        x1 = dropdown_x,
        y1 = dropdown_top,
        x2 = dropdown_x + dropdown_w,
        y2 = dropdown_top + dropdown_h,
    }

    -- Apply OSC alpha
    local alpha = state.animation or 0

    -- Get mouse position for hover detection
    local mx, my = get_virt_mouse_pos()

    -- Render background
    master_ass:new_event()
    master_ass:pos(dropdown_x, dropdown_top)
    master_ass:an(7)
    master_ass:append(string.format("{\\alpha&H%02X&}", alpha))
    master_ass:append(osc_styles.dropdown_bg)
    master_ass:draw_start()
    master_ass:move_to(0, 0)
    master_ass:move_to(dropdown_w, dropdown_h)
    master_ass:round_rect_cw(0, 0, dropdown_w, dropdown_h, 10)
    master_ass:draw_stop()

    -- Render visible items and store hitboxes
    state.dropdown_items = {}
    for vi = 1, visible_count do
        local i = vi + scroll_offset
        local item = items[i]
        if not item then break end

        local item_y = dropdown_top + pad + (vi - 1) * item_h
        local item_cy = item_y + item_h / 2
        local ix1 = dropdown_x + 4
        local ix2 = dropdown_x + dropdown_w - 4
        local is_hovered = (mx >= ix1 and mx <= ix2 and my >= item_y and my <= item_y + item_h)

        -- Hover highlight background
        if is_hovered then
            master_ass:new_event()
            master_ass:pos(dropdown_x + 4, item_y)
            master_ass:an(7)
            master_ass:append(string.format("{\\alpha&H%02X&}", alpha))
            master_ass:append("{\\bord0\\shad0\\1c&HFFFFFF&\\1a&HD0&}")
            master_ass:draw_start()
            master_ass:move_to(0, 0)
            master_ass:move_to(dropdown_w - 8, item_h)
            master_ass:round_rect_cw(0, 0, dropdown_w - 8, item_h, 6)
            master_ass:draw_stop()
        end

        -- Selected item background tint
        if item.selected and not is_hovered then
            master_ass:new_event()
            master_ass:pos(dropdown_x + 4, item_y)
            master_ass:an(7)
            master_ass:append(string.format("{\\alpha&H%02X&}", alpha))
            master_ass:append("{\\bord0\\shad0\\1c&H"
                .. osc_color_convert(user_opts.seekbar_fg_color) .. "&\\1a&HE0&}")
            master_ass:draw_start()
            master_ass:move_to(0, 0)
            master_ass:move_to(dropdown_w - 8, item_h)
            master_ass:round_rect_cw(0, 0, dropdown_w - 8, item_h, 6)
            master_ass:draw_stop()
        end

        -- Item text (with checkmark for selected)
        local display_label = item.label
        if item.selected then
            display_label = "\xe2\x9c\x93  " .. display_label
        end

        master_ass:new_event()
        master_ass:pos(dropdown_x + pad + 6, item_cy)
        master_ass:an(4)
        master_ass:append(string.format("{\\alpha&H%02X&}", alpha))
        if item.selected then
            master_ass:append(osc_styles.dropdown_item_active)
        else
            master_ass:append(osc_styles.dropdown_item)
        end
        master_ass:append(mp.command_native({"escape-ass", display_label}))

        -- Store hitbox for click detection
        state.dropdown_items[vi] = {
            id = item.id,
            speed_val = item.speed_val,
            x1 = dropdown_x,
            y1 = item_y,
            x2 = dropdown_x + dropdown_w,
            y2 = item_y + item_h,
        }
    end

    -- Scroll indicators
    if needs_scroll then
        -- Up arrow indicator
        if scroll_offset > 0 then
            master_ass:new_event()
            master_ass:pos(dropdown_x + dropdown_w / 2, dropdown_top + 4)
            master_ass:an(8)
            master_ass:append(string.format("{\\alpha&H%02X&}", alpha))
            master_ass:append("{\\blur0\\bord0\\shad0\\1c&HFFFFFF&\\fs10}")
            master_ass:append("\xe2\x96\xb2")
        end
        -- Down arrow indicator
        if scroll_offset < max_scroll then
            master_ass:new_event()
            master_ass:pos(dropdown_x + dropdown_w / 2, dropdown_top + dropdown_h - 4)
            master_ass:an(2)
            master_ass:append(string.format("{\\alpha&H%02X&}", alpha))
            master_ass:append("{\\blur0\\bord0\\shad0\\1c&HFFFFFF&\\fs10}")
            master_ass:append("\xe2\x96\xbc")
        end
    end
end

---------------------------------------------------------------------------
-- Bottom Bar Layout
---------------------------------------------------------------------------

local function layout_bottom_bar()
    local bar_h = user_opts.bar_height
    local pad_h = user_opts.bar_padding_h
    local pad_v = user_opts.bar_padding_v

    -- Pill width: ratio of window, clamped to reasonable bounds
    local raw_w = osc_param.playresx * user_opts.pill_width_ratio
    local pill_w = math.max(480, math.min(1100, raw_w))
    pill_w = math.min(pill_w, osc_param.playresx - 20)

    -- Centered horizontally, floating above bottom edge
    local bar_left  = (osc_param.playresx - pill_w) / 2
    local bar_right = bar_left + pill_w
    local bar_bot   = osc_param.playresy - user_opts.pill_bottom_margin - (state.pill_y_offset or 0)
    local bar_top   = bar_bot - bar_h

    local bar_cx = osc_param.playresx / 2
    local bar_cy = bar_top + bar_h / 2

    osc_param.areas = {}

    -- Input area = pill bounds
    add_area("input", bar_left, bar_top, bar_right, bar_bot)

    -- Show/hide area = full-width bottom portion of screen
    local sh_area_y0 = bar_top - (bar_h * 1.0)
    add_area("showhide", 0, sh_area_y0, osc_param.playresx, osc_param.playresy)

    local lo

    -- === Bar Background (floating pill with rounded corners) ===
    new_element("bar_bg", "box")
    lo = add_layout("bar_bg")
    lo.geometry = {x = bar_cx, y = bar_cy, an = 5, w = pill_w, h = bar_h}
    lo.layer = 10
    lo.style = osc_styles.bar_bg
    lo.alpha[1] = user_opts.background_alpha
    lo.alpha[3] = 255
    lo.alpha[4] = 255
    lo.box.radius = user_opts.pill_corner_radius

    -- === Row 1: Seekbar with flanking time codes ===
    local seekbar_row_cy = bar_top + pad_v + 12
    local tc_w = 62
    local tc_gap = 8
    local seekbar_h = 20

    -- Time left (current position)
    local tc_left_x = bar_left + pad_h
    lo = add_layout("tc_left")
    lo.geometry = {x = tc_left_x, y = seekbar_row_cy, an = 4, w = tc_w, h = 24}
    lo.style = osc_styles.timecodes

    -- Time right (remaining/total)
    lo = add_layout("tc_right")
    lo.geometry = {x = bar_right - pad_h, y = seekbar_row_cy, an = 6, w = tc_w, h = 24}
    lo.style = osc_styles.timecodes

    -- Seekbar (between time codes)
    local seekbar_x0 = tc_left_x + tc_w + tc_gap
    local seekbar_x1 = bar_right - pad_h - tc_w - tc_gap
    local seekbar_w = seekbar_x1 - seekbar_x0
    local seekbar_cx = (seekbar_x0 + seekbar_x1) / 2

    lo = add_layout("seekbar")
    lo.geometry = {x = seekbar_cx, y = seekbar_row_cy, an = 5, w = seekbar_w, h = seekbar_h}
    lo.style = osc_styles.seekbar_fg
    lo.slider.border = 0
    lo.slider.gap = 2
    lo.slider.tooltip_style = osc_styles.tooltip
    lo.slider.tooltip_an = 2
    lo.slider.stype = "knob"

    -- === Row 2: Controls (3-group layout) ===
    local ctrl_y = bar_bot - pad_v - 15
    local btn_w = 30
    local btn_h = 30
    local btn_gap = 5
    local play_w = 38
    local play_h = 38

    -- Responsive visibility (keyed off pill_w)
    local show_chapter    = user_opts.chapter_buttons and pill_w > 450
    local show_volume     = user_opts.volume_control and pill_w > 300
    local show_vol_slider = show_volume and pill_w > 480
    local show_audio      = user_opts.audio_button and pill_w > 500
    local show_sub        = user_opts.subtitle_button and pill_w > 500
    local show_playlist   = user_opts.playlist_button and pill_w > 500
        and mp.get_property_number("playlist-count", 0) > 1
    local show_speed      = user_opts.speed_button and pill_w > 400
    local show_fs         = user_opts.fullscreen_button and pill_w > 350

    -- === LEFT GROUP: volume icon + volume slider ===
    local lx = bar_left + pad_h

    if show_volume then
        lo = add_layout("volume")
        lo.geometry = {x = lx, y = ctrl_y, an = 4, w = btn_w, h = btn_h}
        lo.style = osc_styles.icons_small
        lx = lx + btn_w + 4
    end

    if show_vol_slider then
        local vol_slider_w = 65
        local vol_slider_h = 14
        lo = add_layout("volume_slider")
        lo.geometry = {x = lx, y = ctrl_y, an = 4, w = vol_slider_w, h = vol_slider_h}
        lo.style = osc_styles.seekbar_fg
        lo.slider.border = 0
        lo.slider.gap = 1
        lo.slider.stype = "knob"
        lo.slider.tooltip_an = 2
        lo.slider.tooltip_style = osc_styles.tooltip
    end

    -- === CENTER GROUP: transport controls (centered on screen) ===
    local center_btns = {}
    table.insert(center_btns, {name = "playlist_prev", w = btn_w})
    if show_chapter then
        table.insert(center_btns, {name = "chapter_prev", w = btn_w})
    end
    table.insert(center_btns, {name = "play_pause", w = play_w})
    if show_chapter then
        table.insert(center_btns, {name = "chapter_next", w = btn_w})
    end
    table.insert(center_btns, {name = "playlist_next", w = btn_w})

    local center_total_w = 0
    for i, btn in ipairs(center_btns) do
        center_total_w = center_total_w + btn.w
        if i < #center_btns then
            center_total_w = center_total_w + btn_gap
        end
    end

    local cx = bar_cx - (center_total_w / 2)
    for _, btn in ipairs(center_btns) do
        lo = add_layout(btn.name)
        if btn.name == "play_pause" then
            lo.geometry = {x = cx, y = ctrl_y, an = 4, w = play_w, h = play_h}
            lo.style = osc_styles.icons_large
        else
            lo.geometry = {x = cx, y = ctrl_y, an = 4, w = btn_w, h = btn_h}
            lo.style = osc_styles.icons_small
        end
        cx = cx + btn.w + btn_gap
    end

    -- === RIGHT GROUP: audio, subtitle, fullscreen ===
    local rx = bar_right - pad_h

    if show_fs then
        rx = rx - btn_w
        lo = add_layout("fullscreen")
        lo.geometry = {x = rx, y = ctrl_y, an = 4, w = btn_w, h = btn_h}
        lo.style = osc_styles.icons_small
        rx = rx - btn_gap
    end

    if show_sub then
        rx = rx - btn_w
        lo = add_layout("sub_track")
        lo.geometry = {x = rx, y = ctrl_y, an = 4, w = btn_w, h = btn_h}
        lo.style = osc_styles.icons_small
        rx = rx - btn_gap
    end

    if show_audio then
        rx = rx - btn_w
        lo = add_layout("audio_track")
        lo.geometry = {x = rx, y = ctrl_y, an = 4, w = btn_w, h = btn_h}
        lo.style = osc_styles.icons_small
        rx = rx - btn_gap
    end

    if show_playlist then
        rx = rx - btn_w
        lo = add_layout("playlist_list")
        lo.geometry = {x = rx, y = ctrl_y, an = 4, w = btn_w, h = btn_h}
        lo.style = osc_styles.icons_small
        rx = rx - btn_gap
    end

    if show_speed then
        local speed_w = 38
        rx = rx - speed_w
        lo = add_layout("speed")
        lo.geometry = {x = rx, y = ctrl_y, an = 4, w = speed_w, h = btn_h}
        lo.style = osc_styles.speed_text
    end

    -- Window controls (top bar for borderless/fullscreen)
    if window_controls_enabled() then
        local wc_h = 30
        local wc_y = 15
        local wc_btn_w = 25
        local alignment = user_opts.windowcontrols_alignment

        local wc_x_start
        if alignment == "left" then
            wc_x_start = 5
        else
            wc_x_start = osc_param.playresx - (wc_btn_w * 3) - 15
        end

        new_element("wcbar", "box")
        lo = add_layout("wcbar")
        lo.geometry = {x = osc_param.playresx / 2, y = wc_y, an = 5,
            w = osc_param.playresx + 4, h = wc_h}
        lo.layer = 10
        lo.style = osc_styles.wcBar
        lo.alpha[1] = math.min(255, user_opts.background_alpha + 30)

        lo = add_layout("wc_close")
        lo.geometry = {x = wc_x_start + (alignment == "left" and 0 or wc_btn_w * 2),
            y = wc_y, an = 4, w = wc_btn_w, h = wc_btn_w}
        lo.style = osc_styles.wcButtons

        lo = add_layout("wc_minimize")
        lo.geometry = {x = wc_x_start + (alignment == "left" and wc_btn_w or 0),
            y = wc_y, an = 4, w = wc_btn_w, h = wc_btn_w}
        lo.style = osc_styles.wcButtons

        lo = add_layout("wc_maximize")
        lo.geometry = {x = wc_x_start + wc_btn_w,
            y = wc_y, an = 4, w = wc_btn_w, h = wc_btn_w}
        lo.style = osc_styles.wcButtons

        add_area("showhide_wc", 0, 0, osc_param.playresx, wc_h + 10)
    end
end

---------------------------------------------------------------------------
-- Bind mouse commands to an element
---------------------------------------------------------------------------
local function bind_mouse_buttons(element_name)
    for _, button in pairs({"mbtn_left", "mbtn_mid", "mbtn_right"}) do
        local command = user_opts[element_name .. "_" .. button .. "_command"]
        if command and command ~= "" then
            elements[element_name].eventresponder[button .. "_up"] = function()
                mp.command(command)
            end
        end
    end
    if user_opts.scrollcontrols then
        for _, button in pairs({"wheel_down", "wheel_up"}) do
            local command = user_opts[element_name .. "_" .. button .. "_command"]
            if command and command ~= "" then
                elements[element_name].eventresponder[button .. "_press"] = function()
                    mp.command(command)
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- OSC Initialization
---------------------------------------------------------------------------
local function osc_init()
    msg.debug("osc_init")

    -- Canvas resolution
    local baseResY = 720
    local _, display_h, display_aspect = mp.get_osd_size()
    local scale = state.fullscreen and user_opts.scalefullscreen
                                    or user_opts.scalewindowed

    local scale_with_video
    if user_opts.vidscale == "auto" then
        scale_with_video = mp.get_property_native("osd-scale-by-window")
    else
        scale_with_video = user_opts.vidscale == "yes"
    end

    if scale_with_video then
        osc_param.unscaled_y = baseResY
    else
        osc_param.unscaled_y = display_h
    end
    osc_param.playresy = osc_param.unscaled_y / scale
    if display_aspect > 0 then
        osc_param.display_aspect = display_aspect
    end
    osc_param.playresx = osc_param.playresy * osc_param.display_aspect

    -- Reset
    state.active_element = nil
    osc_param.video_margins = {l = 0, r = 0, t = 0, b = 0}
    elements = {}

    -- Gather context
    local pl_count = mp.get_property_number("playlist-count", 0)
    local have_pl = (pl_count > 1)
    local pl_pos = mp.get_property_number("playlist-pos", 0) + 1
    local have_ch = (mp.get_property_number("chapters", 0) > 0)
    local loop = mp.get_property("loop-playlist", "no")

    local ne

    -- === Title (currently unused in floating pill, reserved) ===
    ne = new_element("title", "button")
    ne.visible = false
    ne.content = function()
        local title = state.forced_title or
            mp.command_native({"expand-text", user_opts.title})
        title = title:gsub("\n", " ")
        return title ~= "" and mp.command_native({"escape-ass", title}) or "mpv"
    end

    -- === Play/Pause ===
    ne = new_element("play_pause", "button")
    ne.content = function()
        if not mp.get_property_native("pause") then
            return icons.pause
        end
        return icons.play
    end
    bind_mouse_buttons("play_pause")

    -- === Playlist Prev ===
    ne = new_element("playlist_prev", "button")
    ne.content = icons.skip_previous
    ne.enabled = (pl_pos > 1) or (loop ~= "no")
    bind_mouse_buttons("playlist_prev")

    -- === Playlist Next ===
    ne = new_element("playlist_next", "button")
    ne.content = icons.skip_next
    ne.enabled = (have_pl and (pl_pos < pl_count)) or (loop ~= "no")
    bind_mouse_buttons("playlist_next")

    -- === Chapter Prev ===
    ne = new_element("chapter_prev", "button")
    ne.content = icons.chapter_prev
    ne.enabled = have_ch
    bind_mouse_buttons("chapter_prev")

    -- === Chapter Next ===
    ne = new_element("chapter_next", "button")
    ne.content = icons.chapter_next
    ne.enabled = have_ch
    bind_mouse_buttons("chapter_next")

    -- === Track info ===
    update_tracklist()

    -- === Audio Track ===
    ne = new_element("audio_track", "button")
    ne.enabled = audio_track_count > 0
    -- Custom waveform-in-circle icon (ASS drawing, \p2 = 2x subpixel)
    -- 40x40 canvas at \p2 = 20x20px icon; circle ring + 5 equalizer bars
    ne.content = "{\\p2}"
        -- outer circle CW (r=19, center 20,20)
        .. "m 39 20 b 39 31 31 39 20 39 b 9 39 1 31 1 20 b 1 9 9 1 20 1 b 31 1 39 9 39 20 "
        -- inner circle CCW (r=15, center 20,20) → ring hole
        .. "m 35 20 b 35 12 28 5 20 5 b 12 5 5 12 5 20 b 5 28 12 35 20 35 b 28 35 35 28 35 20 "
        -- 5 vertical bars (equalizer waveform)
        .. "m 8 16 l 12 16 12 24 8 24 "
        .. "m 13 13 l 17 13 17 27 13 27 "
        .. "m 18 11 l 22 11 22 29 18 29 "
        .. "m 23 13 l 27 13 27 27 23 27 "
        .. "m 28 16 l 32 16 32 24 28 24"
    ne.eventresponder["mbtn_left_up"] = function()
        if state.dropdown == "audio" then
            state.dropdown = nil
        else
            state.dropdown = "audio"
            state.dropdown_scroll = 0
        end
        state.dropdown_items = {}
        request_tick()
    end
    ne.eventresponder["wheel_up_press"] = function()
        mp.command("cycle audio down")
    end
    ne.eventresponder["wheel_down_press"] = function()
        mp.command("cycle audio")
    end

    -- === Subtitle Track ===
    ne = new_element("sub_track", "button")
    ne.enabled = sub_track_count > 0
    ne.content = icons.subtitle
    ne.eventresponder["mbtn_left_up"] = function()
        if state.dropdown == "sub" then
            state.dropdown = nil
        else
            state.dropdown = "sub"
            state.dropdown_scroll = 0
        end
        state.dropdown_items = {}
        request_tick()
    end
    ne.eventresponder["wheel_up_press"] = function()
        mp.command("cycle sub down")
    end
    ne.eventresponder["wheel_down_press"] = function()
        mp.command("cycle sub")
    end

    -- === Playlist List ===
    ne = new_element("playlist_list", "button")
    ne.enabled = have_pl
    ne.content = icons.playlist
    ne.eventresponder["mbtn_left_up"] = function()
        if state.dropdown == "playlist" then
            state.dropdown = nil
        else
            state.dropdown = "playlist"
            local pos = mp.get_property_number("playlist-pos", 0)
            state.dropdown_scroll = math.max(0, pos - 2)
        end
        state.dropdown_items = {}
        request_tick()
    end
    ne.eventresponder["wheel_up_press"] = function()
        mp.command("playlist-prev")
    end
    ne.eventresponder["wheel_down_press"] = function()
        mp.command("playlist-next")
    end

    -- === Volume ===
    ne = new_element("volume", "button")
    ne.content = function()
        local volume = mp.get_property_number("volume", 0)
        if volume == 0 or mp.get_property_native("mute") then
            return icons.volume_mute
        elseif volume < 33 then
            return icons.volume_low
        elseif volume < 66 then
            return icons.volume_low
        else
            return icons.volume_high
        end
    end
    bind_mouse_buttons("volume")

    -- === Volume Slider ===
    ne = new_element("volume_slider", "slider")
    ne.enabled = true
    ne.slider.markerF = nil
    ne.slider.posF = function()
        return mp.get_property_number("volume", 0)
    end
    ne.slider.tooltipF = function(pos)
        return string.format("Vol: %d%%", math.floor(pos))
    end
    ne.slider.seekRangesF = function() return nil end
    ne.eventresponder["mouse_move"] = function(element)
        if not element.state.mbtn_left then return end
        local val = get_slider_value(element)
        mp.commandv("set", "volume", val)
    end
    ne.eventresponder["mbtn_left_down"] = function(element)
        element.state.mbtn_left = true
        mp.commandv("set", "volume", get_slider_value(element))
    end
    ne.eventresponder["mbtn_left_up"] = function(element)
        element.state.mbtn_left = false
    end
    ne.eventresponder["reset"] = function(element)
        element.state.mbtn_left = false
    end
    if user_opts.scrollcontrols then
        ne.eventresponder["wheel_up_press"] = function()
            mp.commandv("osd-auto", "add", "volume", 5)
        end
        ne.eventresponder["wheel_down_press"] = function()
            mp.commandv("osd-auto", "add", "volume", -5)
        end
    end

    -- === Speed ===
    ne = new_element("speed", "button")
    ne.content = function()
        local speed = mp.get_property_number("speed", 1)
        if speed == math.floor(speed) then
            return string.format("%d.0x", speed)
        else
            return string.format("%gx", speed)
        end
    end
    ne.eventresponder["mbtn_left_up"] = function()
        if state.dropdown == "speed" then
            state.dropdown = nil
        else
            state.dropdown = "speed"
            state.dropdown_scroll = 0
        end
        state.dropdown_items = {}
        request_tick()
    end
    ne.eventresponder["mbtn_right_up"] = function()
        mp.set_property_number("speed", 1.0)
        mp.osd_message("Speed: 1.0x")
    end
    ne.eventresponder["wheel_up_press"] = function()
        local speed = mp.get_property_number("speed", 1)
        speed = math.min(5.0, speed + 0.25)
        mp.set_property_number("speed", speed)
        mp.osd_message(string.format("Speed: %gx", speed))
    end
    ne.eventresponder["wheel_down_press"] = function()
        local speed = mp.get_property_number("speed", 1)
        speed = math.max(0.25, speed - 0.25)
        mp.set_property_number("speed", speed)
        mp.osd_message(string.format("Speed: %gx", speed))
    end

    -- === Fullscreen ===
    ne = new_element("fullscreen", "button")
    ne.content = function()
        return state.fullscreen and icons.fullscreen_exit or icons.fullscreen
    end
    bind_mouse_buttons("fullscreen")

    -- === Seekbar ===
    ne = new_element("seekbar", "slider")
    ne.iina_seekbar = true
    ne.enabled = mp.get_property("percent-pos") ~= nil
    state.slider_element = ne.enabled and ne or nil

    ne.slider.markerF = function()
        local duration = mp.get_property_number("duration")
        if duration then
            local chapters = mp.get_property_native("chapter-list", {})
            local markers = {}
            for i = 1, #chapters do
                markers[i] = chapters[i].time / duration * 100
            end
            return markers
        end
        return {}
    end

    ne.slider.posF = function()
        return mp.get_property_number("percent-pos")
    end

    ne.slider.tooltipF = function(pos)
        local duration = mp.get_property_number("duration")
        if duration and pos then
            return mp.format_time(duration * pos / 100)
        end
        return ""
    end

    ne.slider.seekRangesF = function()
        if user_opts.seekrangestyle == "none" or not cache_enabled() then
            return nil
        end
        local duration = mp.get_property_number("duration")
        if not duration or duration <= 0 then return nil end
        local nranges = {}
        for _, range in pairs(state.cache_state["seekable-ranges"]) do
            nranges[#nranges + 1] = {
                ["start"] = 100 * range["start"] / duration,
                ["end"]   = 100 * range["end"] / duration,
            }
        end
        return nranges
    end

    ne.eventresponder["mouse_move"] = function(element)
        if not element.state.mbtn_left then return end
        local seekto = get_slider_value(element)
        if element.state.lastseek == nil or element.state.lastseek ~= seekto then
            local flags = "absolute-percent"
            if not user_opts.seekbarkeyframes then
                flags = flags .. "+exact"
            end
            mp.commandv("seek", seekto, flags)
            element.state.lastseek = seekto
        end
    end
    ne.eventresponder["mbtn_left_down"] = function(element)
        element.state.mbtn_left = true
        mp.commandv("seek", get_slider_value(element), "absolute-percent+exact")
    end
    ne.eventresponder["mbtn_left_up"] = function(element)
        element.state.mbtn_left = false
    end
    ne.eventresponder["mbtn_right_up"] = function(element)
        local pos = get_slider_value(element)
        local diff = math.huge
        local chapter
        for i, marker in ipairs(element.slider.markerF()) do
            if math.abs(pos - marker) < diff then
                diff = math.abs(pos - marker)
                chapter = i
            end
        end
        if chapter then
            mp.set_property("chapter", chapter - 1)
        end
    end
    ne.eventresponder["reset"] = function(element)
        element.state.lastseek = nil
    end
    if user_opts.scrollcontrols then
        ne.eventresponder["wheel_up_press"] = function()
            mp.commandv("osd-auto", "seek", 10)
        end
        ne.eventresponder["wheel_down_press"] = function()
            mp.commandv("osd-auto", "seek", -10)
        end
    end

    -- === Time Codes ===
    ne = new_element("tc_left", "button")
    ne.content = function()
        if state.tc_ms then
            return mp.get_property_osd("playback-time/full")
        end
        return mp.get_property_osd("playback-time")
    end
    ne.eventresponder["mbtn_left_up"] = function()
        state.tc_ms = not state.tc_ms
        request_init()
    end

    ne = new_element("tc_right", "button")
    ne.visible = (mp.get_property_number("duration", 0) > 0)
    ne.content = function()
        if state.rightTC_trem then
            local minus = user_opts.unicodeminus and UNICODE_MINUS or "-"
            local prop = user_opts.remaining_playtime and "playtime-remaining"
                                                      or "time-remaining"
            if state.tc_ms then
                return minus .. mp.get_property_osd(prop .. "/full")
            end
            return minus .. mp.get_property_osd(prop)
        else
            if state.tc_ms then
                return mp.get_property_osd("duration/full")
            end
            return mp.get_property_osd("duration")
        end
    end
    ne.eventresponder["mbtn_left_up"] = function()
        state.rightTC_trem = not state.rightTC_trem
    end

    -- === Window Controls ===
    if window_controls_enabled() then
        ne = new_element("wc_close", "button")
        ne.content = icons.close
        ne.eventresponder["mbtn_left_up"] = function()
            mp.commandv("quit")
        end

        ne = new_element("wc_minimize", "button")
        ne.content = icons.minimize
        ne.eventresponder["mbtn_left_up"] = function()
            mp.commandv("cycle", "window-minimized")
        end

        ne = new_element("wc_maximize", "button")
        ne.content = function()
            return (state.maximized or state.fullscreen) and icons.unmaximize
                                                          or icons.maximize
        end
        ne.eventresponder["mbtn_left_up"] = function()
            if state.fullscreen then
                mp.commandv("cycle", "fullscreen")
            else
                mp.commandv("cycle", "window-maximized")
            end
        end
    end

    -- === Apply Layout ===
    layout_bottom_bar()

    -- === Finalize ===
    prepare_elements()
    update_margins()
end

---------------------------------------------------------------------------
-- Visibility & Animation
---------------------------------------------------------------------------

local function osc_visible(visible)
    if state.osc_visible ~= visible then
        state.osc_visible = visible
        update_margins()
    end
    request_tick()
end

local function show_osc()
    if not state.enabled then return end
    msg.trace("show_osc")
    state.showtime = mp.get_time()

    if user_opts.fadeduration <= 0 then
        osc_visible(true)
    elseif user_opts.fadein then
        if not state.osc_visible then
            state.anitype = "in"
            request_tick()
        end
    else
        osc_visible(true)
        state.anitype = nil
    end
end

local function hide_osc()
    msg.trace("hide_osc")
    state.dropdown = nil
    state.dropdown_items = {}
    state.dropdown_hitbox = nil

    if not state.enabled then
        state.osc_visible = false
        render_wipe()
    elseif user_opts.fadeduration > 0 then
        if state.osc_visible then
            state.anitype = "out"
            request_tick()
        end
    else
        osc_visible(false)
    end
end

local function mouse_leave()
    -- Don't hide if a dropdown is open (mouse may have moved into dropdown area)
    if state.dropdown ~= nil then return end
    if get_hidetimeout() >= 0 then
        hide_osc()
    end
    state.last_mouseX, state.last_mouseY = nil, nil
    state.mouse_in_window = false
end

---------------------------------------------------------------------------
-- Event Handling
---------------------------------------------------------------------------

local function element_has_action(element, action)
    return element and element.eventresponder and element.eventresponder[action]
end

local function process_event(source, what)
    local action = string.format("%s%s", source, what and ("_" .. what) or "")

    if what == "down" or what == "press" then

        if source == "mbtn_left" then
            state.click_consumed = false
        end

        -- Dropdown scroll interception (wheel events over dropdown)
        if state.dropdown ~= nil and state.dropdown_hitbox and
           (source == "wheel_up" or source == "wheel_down") then
            local mx, my = get_virt_mouse_pos()
            local dh = state.dropdown_hitbox
            if mx >= dh.x1 and mx <= dh.x2 and my >= dh.y1 and my <= dh.y2 then
                if source == "wheel_up" then
                    state.dropdown_scroll = math.max(0, state.dropdown_scroll - 3)
                else
                    state.dropdown_scroll = state.dropdown_scroll + 3
                end
                request_tick()
                return
            end
        end

        -- Dropdown click interception (before element loop)
        if state.dropdown ~= nil and source == "mbtn_left" then
            local mx, my = get_virt_mouse_pos()
            local hit_item = false
            for _, item in ipairs(state.dropdown_items) do
                if mx >= item.x1 and mx <= item.x2 and my >= item.y1 and my <= item.y2 then
                    if state.dropdown == "playlist" then
                        mp.set_property("playlist-pos", item.id)
                    elseif state.dropdown == "speed" then
                        if item.speed_val then
                            mp.set_property_number("speed", item.speed_val)
                        end
                    else
                        local prop = state.dropdown == "audio" and "aid" or "sid"
                        if item.id == 0 then
                            mp.set_property(prop, "no")
                        else
                            mp.set_property(prop, tostring(item.id))
                        end
                    end
                    hit_item = true
                    break
                end
            end
            state.dropdown = nil
            state.dropdown_items = {}
            state.dropdown_hitbox = nil
            state.click_consumed = true
            request_tick()
            return
        end

        for n = 1, #elements do
            if mouse_hit(elements[n]) and elements[n].eventresponder and
               (elements[n].eventresponder[source .. "_up"] or
                elements[n].eventresponder[action]) then

                if what == "down" then
                    state.active_element = n
                    state.active_event_source = source
                end
                if element_has_action(elements[n], action) then
                    elements[n].eventresponder[action](elements[n])
                end
            end
        end

        -- Pill drag: if no element was hit, check if mouse is in pill area
        if state.active_element == nil and source == "mbtn_left" then
            local input_area = osc_param.areas["input"] and osc_param.areas["input"][1]
            if input_area then
                local mx, my = get_virt_mouse_pos()
                if mx >= input_area.x1 and mx <= input_area.x2 and
                   my >= input_area.y1 and my <= input_area.y2 then
                    state.pill_dragging = true
                    state.pill_drag_start_y = my
                    state.pill_drag_start_offset = state.pill_y_offset or 0
                end
            end
        end

    elseif what == "up" then

        -- Pill drag end
        if state.pill_dragging then
            state.pill_dragging = false
            state.pill_drag_start_y = nil
            state.pill_drag_start_offset = nil
            save_pill_offset()
            request_tick()
            return
        end

        local had_active = (state.active_element ~= nil)
        if elements[state.active_element] then
            local n = state.active_element
            if element_has_action(elements[n], action) and mouse_hit(elements[n]) then
                elements[n].eventresponder[action](elements[n])
            end
            if element_has_action(elements[n], "reset") then
                elements[n].eventresponder["reset"](elements[n])
            end
        end
        state.active_element = nil
        state.mouse_down_counter = 0

        -- Click on empty video area (not on any OSC element) toggles pause
        if source == "mbtn_left" and not had_active and not state.click_consumed then
            mp.commandv("cycle", "pause")
        end

    elseif source == "mouse_move" then
        state.mouse_in_window = true
        local mouseX, mouseY = get_virt_mouse_pos()

        -- Pill drag move
        if state.pill_dragging then
            local dy = state.pill_drag_start_y - mouseY
            state.pill_y_offset = state.pill_drag_start_offset + dy
            -- Clamp: can't go below default position, can't go off top
            local max_offset = osc_param.playresy - user_opts.pill_bottom_margin
                               - user_opts.bar_height - 20
            state.pill_y_offset = math.max(0, math.min(max_offset, state.pill_y_offset))
            request_init()
            request_tick()
            return
        end

        if user_opts.minmousemove == 0 or
           ((state.last_mouseX ~= nil and state.last_mouseY ~= nil) and
            (math.abs(mouseX - state.last_mouseX) >= user_opts.minmousemove or
             math.abs(mouseY - state.last_mouseY) >= user_opts.minmousemove)) then
            show_osc()
        end
        state.last_mouseX, state.last_mouseY = mouseX, mouseY

        local n = state.active_element
        if element_has_action(elements[n], action) then
            elements[n].eventresponder[action](elements[n])
        end
    end

    request_tick()
end

---------------------------------------------------------------------------
-- Render Loop
---------------------------------------------------------------------------

local function do_enable_keybindings()
    if state.enabled then
        if not state.showhide_enabled then
            mp.enable_key_bindings("showhide", "allow-vo-dragging+allow-hide-cursor")
            mp.enable_key_bindings("showhide_wc", "allow-vo-dragging+allow-hide-cursor")
        end
        state.showhide_enabled = true
    end
end

local function enable_osc(enable)
    state.enabled = enable
    if enable then
        do_enable_keybindings()
    else
        hide_osc()
        if state.showhide_enabled then
            mp.disable_key_bindings("showhide")
            mp.disable_key_bindings("showhide_wc")
        end
        state.showhide_enabled = false
    end
end

local function render()
    msg.trace("rendering")
    local current_screen_sizeX, current_screen_sizeY = mp.get_osd_size()
    local now = mp.get_time()

    -- Detect display size change
    if state.screen_sizeX ~= current_screen_sizeX or
       state.screen_sizeY ~= current_screen_sizeY then
        request_init_resize()
        state.screen_sizeX = current_screen_sizeX
        state.screen_sizeY = current_screen_sizeY
    end

    -- Init management
    if state.active_element then
        request_tick()
    elseif state.initREQ then
        osc_init()
        state.initREQ = false
        if state.last_mouseX == nil or state.last_mouseY == nil then
            local mx, my = get_virt_mouse_pos()
            if mx and my then
                state.last_mouseX, state.last_mouseY = mx, my
            end
        end
    end

    -- Fade animation
    if state.anitype ~= nil then
        if state.anistart == nil then
            state.anistart = now
        end
        if now < state.anistart + (user_opts.fadeduration / 1000) then
            if state.anitype == "in" then
                osc_visible(true)
                state.animation = scale_value(state.anistart,
                    state.anistart + (user_opts.fadeduration / 1000),
                    255, 0, now)
            elseif state.anitype == "out" then
                state.animation = scale_value(state.anistart,
                    state.anistart + (user_opts.fadeduration / 1000),
                    0, 255, now)
            end
        else
            if state.anitype == "out" then
                osc_visible(false)
            end
            kill_animation()
        end
    else
        kill_animation()
    end

    -- Mouse show/hide areas
    for _, cords in pairs(osc_param.areas["showhide"] or {}) do
        local y1 = cords.y1
        -- Expand showhide area upward to cover dropdown when open
        if state.dropdown ~= nil and state.dropdown_hitbox then
            y1 = math.min(y1, state.dropdown_hitbox.y1)
        end
        set_virt_mouse_area(cords.x1, y1, cords.x2, cords.y2, "showhide")
    end
    if osc_param.areas["showhide_wc"] then
        for _, cords in pairs(osc_param.areas["showhide_wc"]) do
            set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, "showhide_wc")
        end
    else
        set_virt_mouse_area(0, 0, 0, 0, "showhide_wc")
    end
    do_enable_keybindings()

    -- Mouse input area
    local mouse_over_osc = false
    for _, cords in ipairs(osc_param.areas["input"] or {}) do
        if state.osc_visible then
            local y1 = cords.y1
            -- Expand input area upward to cover dropdown when open
            if state.dropdown ~= nil and state.dropdown_hitbox then
                y1 = math.min(y1, state.dropdown_hitbox.y1)
            end
            set_virt_mouse_area(cords.x1, y1, cords.x2, cords.y2, "input")
        end
        if state.osc_visible ~= state.input_enabled then
            if state.osc_visible then
                mp.enable_key_bindings("input")
            else
                mp.disable_key_bindings("input")
            end
            state.input_enabled = state.osc_visible
        end
        if mouse_hit_coords(cords.x1, cords.y1, cords.x2, cords.y2) then
            mouse_over_osc = true
        end
    end

    -- Also prevent hide when mouse is over an open dropdown
    if state.dropdown ~= nil and state.dropdown_hitbox then
        local dh = state.dropdown_hitbox
        if mouse_hit_coords(dh.x1, dh.y1, dh.x2, dh.y2) then
            mouse_over_osc = true
        end
    end

    -- Auto-hide timer
    if state.showtime ~= nil and get_hidetimeout() >= 0 then
        local timeout = state.showtime + (get_hidetimeout() / 1000) - now
        if timeout <= 0 then
            if state.active_element == nil and not mouse_over_osc then
                hide_osc()
            else
                -- Mouse is over OSC/dropdown; re-check soon
                if not state.hide_timer then
                    state.hide_timer = mp.add_timeout(0, tick)
                end
                state.hide_timer.timeout = 0.5
                state.hide_timer:kill()
                state.hide_timer:resume()
            end
        else
            if not state.hide_timer then
                state.hide_timer = mp.add_timeout(0, tick)
            end
            state.hide_timer.timeout = timeout
            state.hide_timer:kill()
            state.hide_timer:resume()
        end
    end

    -- Build ASS
    local ass = assdraw.ass_new()
    if state.osc_visible then
        render_elements(ass)
        render_dropdown(ass)
    end

    -- Submit
    set_osd(osc_param.playresy * osc_param.display_aspect,
            osc_param.playresy, ass.text, 1000)
end

-- Main tick function
tick = function()
    if state.marginsREQ then
        update_margins()
        state.marginsREQ = false
    end

    if not state.enabled then return end

    if state.idle then
        -- Render idle screen
        msg.trace("idle message")
        local _, _, display_aspect = mp.get_osd_size()
        if display_aspect == 0 then return end
        local display_h = 360
        local display_w = display_h * display_aspect
        local icon_x, icon_y = (display_w - 1800 / 32) / 2, 140
        local line_prefix = ("{\\rDefault\\an7\\1a&H00&\\bord0\\shad0\\pos(%f,%f)}")
            :format(icon_x, icon_y)

        local ass = assdraw.ass_new()
        if user_opts.idlescreen then
            for _, line in ipairs(logo_lines) do
                ass:new_event()
                ass:append(line_prefix .. line)
            end
            ass:new_event()
            ass:pos(display_w / 2, icon_y + 65)
            ass:an(8)
            ass:append("Drop files or URLs to play here.")
        end
        set_osd(display_w, display_h, ass.text, -1000)

        if state.showhide_enabled then
            mp.disable_key_bindings("showhide")
            mp.disable_key_bindings("showhide_wc")
            state.showhide_enabled = false
        end

    elseif (state.fullscreen and user_opts.showfullscreen) or
           (not state.fullscreen and user_opts.showwindowed) then
        render()
    else
        render_wipe()
    end

    state.tick_last_time = mp.get_time()

    if state.anitype ~= nil then
        if not state.idle and
           (not state.anistart or
            mp.get_time() < 1 + state.anistart + user_opts.fadeduration / 1000) then
            request_tick()
        else
            kill_animation()
        end
    end
end

---------------------------------------------------------------------------
-- Key Bindings
---------------------------------------------------------------------------

-- Mouse show/hide
mp.set_key_bindings({
    {"mouse_move",  function() process_event("mouse_move", nil) end},
    {"mouse_leave", mouse_leave},
}, "showhide", "force")

mp.set_key_bindings({
    {"mouse_move",  function() process_event("mouse_move", nil) end},
    {"mouse_leave", mouse_leave},
}, "showhide_wc", "force")

do_enable_keybindings()

-- Mouse input
mp.set_key_bindings({
    {"mbtn_left",       function() process_event("mbtn_left", "up") end,
                        function() process_event("mbtn_left", "down") end},
    {"mbtn_mid",        function() process_event("mbtn_mid", "up") end,
                        function() process_event("mbtn_mid", "down") end},
    {"mbtn_right",      function() process_event("mbtn_right", "up") end,
                        function() process_event("mbtn_right", "down") end},
    {"shift+mbtn_left", function() process_event("mbtn_mid", "up") end,
                        function() process_event("mbtn_mid", "down") end},
    {"wheel_up",        function() process_event("wheel_up", "press") end},
    {"wheel_down",      function() process_event("wheel_down", "press") end},
    {"mbtn_left_dbl",       "ignore"},
    {"shift+mbtn_left_dbl", "ignore"},
    {"mbtn_right_dbl",      "ignore"},
}, "input", "force")

mp.enable_key_bindings("input")

---------------------------------------------------------------------------
-- Visibility Mode
---------------------------------------------------------------------------

local function always_on(val)
    if state.enabled then
        if val then show_osc() else hide_osc() end
    end
end

local function visibility_mode(mode, no_osd)
    if mode == "cycle" then
        for i, allowed in ipairs(state.visibility_modes) do
            if i == #state.visibility_modes then
                mode = state.visibility_modes[1]
                break
            elseif user_opts.visibility == allowed then
                mode = state.visibility_modes[i + 1]
                break
            end
        end
    end

    if mode == "auto" then
        always_on(false)
        enable_osc(true)
    elseif mode == "always" then
        enable_osc(true)
        always_on(true)
    elseif mode == "never" then
        enable_osc(false)
    else
        msg.warn("Ignoring unknown visibility mode '" .. mode .. "'")
        return
    end

    user_opts.visibility = mode
    mp.set_property_native("user-data/osc/visibility", mode)

    if not no_osd and tonumber(mp.get_property("osd-level")) >= 1 then
        mp.osd_message("OSC visibility: " .. mode)
    end

    mp.disable_key_bindings("input")
    state.input_enabled = false
    update_margins()
    request_tick()
end

---------------------------------------------------------------------------
-- Property Observers
---------------------------------------------------------------------------

mp.register_event("shutdown", function()
    update_margins()
    mp.del_property("user-data/osc")
end)

mp.register_event("start-file", request_init)

-- Clamp window size to screen for large videos
mp.register_event("file-loaded", function()
    if state.fullscreen then return end
    local vw = mp.get_property_number("video-params/dw")
    local vh = mp.get_property_number("video-params/dh")
    if not vw or not vh or vw <= 0 or vh <= 0 then return end

    -- Get screen size
    local sw = mp.get_property_number("display-width")
    local sh = mp.get_property_number("display-height")
    if not sw or not sh or sw <= 0 or sh <= 0 then
        sw = 1920
        sh = 1080
    end

    -- Allow up to 85% of screen dimensions
    local max_w = math.floor(sw * 0.85)
    local max_h = math.floor(sh * 0.85)

    if vw > max_w or vh > max_h then
        local scale = math.min(max_w / vw, max_h / vh)
        mp.set_property_number("window-scale", scale)
    end
end)

-- Briefly show OSC when a file starts playing
mp.register_event("file-loaded", function()
    if state.enabled and user_opts.visibility == "auto" then
        show_osc()
    end
end)

mp.observe_property("track-list", "native", request_init)
mp.observe_property("playlist-count", "native", request_init)

mp.observe_property("playlist-pos", "number", function()
    if state.dropdown == "playlist" then
        state.dropdown = nil
        state.dropdown_items = {}
    end
    request_init()
end)

mp.observe_property("chapter-list", "native", function(_, list)
    list = list or {}
    table.sort(list, function(a, b) return a.time < b.time end)
    state.chapter_list = list
    request_init()
end)

mp.observe_property("fullscreen", "bool", function(_, val)
    state.fullscreen = val
    state.marginsREQ = true
    request_init_resize()
end)

mp.observe_property("border", "bool", function(_, val)
    state.border = val
    request_init_resize()
end)

mp.observe_property("title-bar", "bool", function(_, val)
    state.title_bar = val
    request_init_resize()
end)

mp.observe_property("window-maximized", "bool", function(_, val)
    state.maximized = val
    request_init_resize()
end)

mp.observe_property("idle-active", "bool", function(_, val)
    state.idle = val
    request_tick()
end)

mp.observe_property("pause", "bool", function(_, val)
    state.paused = val
    request_tick()
end)

mp.observe_property("demuxer-cache-state", "native", function(_, st)
    state.cache_state = st
    request_tick()
end)

mp.observe_property("vo-configured", "bool", request_tick)
mp.observe_property("playback-time", "number", request_tick)

mp.observe_property("osd-dimensions", "native", function()
    request_init_resize()
end)

mp.observe_property("osd-scale-by-window", "native", request_init_resize)

local function set_tick_delay(_, display_fps)
    if not display_fps or not user_opts.tick_delay_follow_display_fps then
        tick_delay = user_opts.tick_delay
        return
    end
    tick_delay = 1 / display_fps
end

mp.observe_property("display-fps", "number", set_tick_delay)

---------------------------------------------------------------------------
-- Script Messages
---------------------------------------------------------------------------

-- Thumbfast
mp.register_script_message("thumbfast-info", function(json)
    local data = utils.parse_json(json)
    if type(data) == "table" then
        thumbfast = data
    end
end)

-- OSC visibility control
mp.register_script_message("osc-visibility", visibility_mode)
mp.register_script_message("osc-show", show_osc)
mp.register_script_message("osc-hide", function()
    if user_opts.visibility == "auto" then
        osc_visible(false)
    end
end)

mp.add_key_binding(nil, "visibility", function() visibility_mode("cycle") end)

-- Volume up/down arrows
mp.add_key_binding("UP", "osc-volume-up", function()
    mp.commandv("osd-auto", "add", "volume", "5")
end, {repeatable = true})

mp.add_key_binding("DOWN", "osc-volume-down", function()
    mp.commandv("osd-auto", "add", "volume", "-5")
end, {repeatable = true})

---------------------------------------------------------------------------
-- Bootstrap
---------------------------------------------------------------------------

local function validate_user_opts()
    -- Validate colors
    local colors = {
        user_opts.background_color,
        user_opts.icons_color,
        user_opts.text_color,
        user_opts.title_color,
        user_opts.held_element_color,
        user_opts.seekbar_fg_color,
        user_opts.seekbar_bg_color,
        user_opts.seekbar_cache_color,
        user_opts.chapter_marker_color,
    }
    for _, color in pairs(colors) do
        if color:find("^#%x%x%x%x%x%x$") == nil then
            msg.warn("'" .. color .. "' is not a valid color")
        end
    end

    -- Validate ranges
    user_opts.panel_blur = math.min(40, math.max(0, user_opts.panel_blur or 2))
    user_opts.background_alpha = math.min(255, math.max(0, user_opts.background_alpha or 30))

    if user_opts.seekrangestyle ~= "bar" and
       user_opts.seekrangestyle ~= "line" and
       user_opts.seekrangestyle ~= "inverted" and
       user_opts.seekrangestyle ~= "none" then
        user_opts.seekrangestyle = "inverted"
    end

    if user_opts.windowcontrols ~= "auto" and
       user_opts.windowcontrols ~= "yes" and
       user_opts.windowcontrols ~= "no" then
        user_opts.windowcontrols = "auto"
    end

    -- Parse visibility modes
    for str in string.gmatch(user_opts.visibility_modes, "([^_]+)") do
        if str == "auto" or str == "always" or str == "never" then
            table.insert(state.visibility_modes, str)
        end
    end
end

opt.read_options(user_opts, "iina-osc", function(changed)
    validate_user_opts()
    set_osc_styles()
    if changed.timetotal then
        state.rightTC_trem = not user_opts.timetotal
    end
    if changed.timems then
        state.tc_ms = user_opts.timems
    end
    if changed.tick_delay or changed.tick_delay_follow_display_fps then
        set_tick_delay("display_fps", mp.get_property_number("display-fps"))
    end
    request_tick()
    visibility_mode(user_opts.visibility, true)
    request_init()
end)

validate_user_opts()
set_osc_styles()
load_pill_offset()
state.rightTC_trem = not user_opts.timetotal
state.tc_ms = user_opts.timems
set_tick_delay("display_fps", mp.get_property_number("display-fps"))
visibility_mode(user_opts.visibility, true)

set_virt_mouse_area(0, 0, 0, 0, "input")

msg.info("IINA-style bottom bar OSC loaded")
