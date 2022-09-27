    --[[
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @@@@@@@@@@@@@@@@@@@///////////////////////@@@@@@@@@@@@@@@@@@
    @@@@@@@@@@@@@@/////////////////////////////////@@@@@@@@@@@@@
    @@@@@@@@@@@///////////////////////////////////////@@@@@@@@@@
    @@@@@@@@/////////////////////////////////////////////@@@@@@@        
    @@@@@@/////////////////////////////////////////////////@@@@@
    @@@@@///////////////////////////////////////////////////@@@@
    @@@//////////@@@@@@@@@@@@@@@@@@@@@@@@@@@//////////////////@@
    @@////////@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%///////////@
    @@/////////@@@@@/////////////////////@@@@@@@@@@@@@@@///////@
    @////////////////////////////////////////////@@@@@@@////////    SpotiLite
    @//////////////@@@@@@@@@@@@@@@@@@@@@////////////////////////    UHQ Spotify Client for Gamesense
    @///////////@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@////////////////
    @////////////////////////////////////@@@@@@@@@@@////////////
    @//////////////////////////////////////////@@@@@////////////
    @@////////////@@@@@@@@@@@@@@@@@@@@@@@//////////////////////@
    @@///////////@@@@@@@@//////////@@@@@@@@@@@/////////////////@
    @@@////////////////////////////////////@@@@@//////////////@@
    @@@@@///////////////////////////////////////////////////@@@@
    @@@@@@/////////////////////////////////////////////////@@@@@
    @@@@@@@@/////////////////////////////////////////////@@@@@@@
    @@@@@@@@@@@///////////////////////////////////////@@@@@@@@@@
    @@@@@@@@@@@@@@/////////////////////////////////@@@@@@@@@@@@@
    @@@@@@@@@@@@@@@@@@@///////////////////////@@@@@@@@@@@@@@@@@@
]]

local ffi, http, surface, images, spotify = require "ffi", require "gamesense/http", require "gamesense/surface", require "gamesense/images", require "spotifyAPI"

ffi.cdef[[
    typedef bool (__thiscall *IsButtonDown_t)(void*, int);
    typedef int (__thiscall *GetAnalogValue_t)(void*, int);
	typedef int (__thiscall *GetAnalogDelta_t)(void*, int);
    typedef void***(__thiscall* FindHudElement_t)(void*, const char*);
    typedef void(__cdecl* ChatPrintf_t)(void*, int, int, const char*, ...);
]]

local interface_ptr = ffi.typeof('void***')
local raw_inputsystem = client.create_interface('inputsystem.dll', 'InputSystemVersion001')
local inputsystem = ffi.cast(interface_ptr, raw_inputsystem)
local input_vmt = inputsystem[0]
local raw_IsButtonDown = input_vmt[15]
local raw_GetAnalogValue = input_vmt[18]
local raw_GetAnalogDelta = input_vmt[19]
local IsButtonDown = ffi.cast('IsButtonDown_t', raw_IsButtonDown)
local GetAnalogValue = ffi.cast('GetAnalogValue_t', raw_GetAnalogValue)
local GetAnalogDelta = ffi.cast('GetAnalogDelta_t', raw_GetAnalogDelta)

local native_GetClipboardTextCount = vtable_bind("vgui2.dll", "VGUI_System010", 7, "int(__thiscall*)(void*)")
local native_GetClipboardText = vtable_bind("vgui2.dll", "VGUI_System010", 11, "int(__thiscall*)(void*, int, const char*, int)")
local new_char_arr = ffi.typeof("char[?]")


local pi, max = math.pi, math.max

local dynamic = {}
local mouse_state = {}

dynamic.__index = dynamic

function dynamic.new(f, z, r, xi)
   f = max(f, 0.001)
   z = max(z, 0)

   local pif = pi * f
   local twopif = 2 * pif

   local a = z / pif
   local b = 1 / ( twopif * twopif )
   local c = r * z / twopif

   return setmetatable({
      a = a,
      b = b,
      c = c,

      px = xi,
      y = xi,
      dy = 0
   }, dynamic)
end
--client.log('optimized: ' .. x .. " self.y: " .. self.y)
--else client.log('not optimized: ' .. x .. " self.y: " .. self.y)
function dynamic:update(dt, x, dx)
   if not x then return end -- stops all the fucking errors wallah
   if self.y == x then return self end --epic
   if dx == nil then
      dx = ( x - self.px ) / dt
      self.px = x
   end
   	
   if self.y == self.px then client.log("optimized:" .. x ..  "self.px: " .. self.px) return self end
   self.y  = self.y + dt * self.dy
   self.dy = self.dy + dt * ( x + self.c * dx - self.y - self.a * self.dy ) / self.b
   return self
end

function dynamic:get()
   return self.y
end

local hud = {
    x = dynamic.new(8, 2, 1, select(1, ui.menu_position())),
    y = dynamic.new(8, 2, 1, select(2, ui.menu_position()) + select(2, ui.menu_size()) + 10),
    w = dynamic.new(8, 1, 1, select(1, ui.menu_size())),
    h = dynamic.new(2, 1, 1, 75),
    bar_width = dynamic.new(2, 1, 1, 2),
    bar_length = dynamic.new(3, 1, 1, 0),
    hover_alpha = dynamic.new(6, 1, 0.8, 255),
    hover_movement  = dynamic.new(1.5, 1, 0.8, 0),
    play_alpha = dynamic.new(2, 1, 1, 0),
    next_alpha = dynamic.new(2, 1, 1, 0),
    back_alpha = dynamic.new(2, 1, 1, 0),
    song_name = "", -- so it adapts to menu size bratan kuku bra
    cover_art_position = dynamic.new(4, 1, 1, 55),
    extended = {
        buffer_p = dynamic.new(0.5, 1, 1, 0),
        buffer_s = dynamic.new(0.5, 1, 1, 360),
        initpercentage = dynamic.new(2, 1, 1, 0),
        Left = {
            false,
            x = dynamic.new(8, 2, 1, select(1, ui.menu_position()-240)),
            y = dynamic.new(8, 2, 1, select(2, ui.menu_position())),
            w = dynamic.new(8, 1, 1, 230),
            h = dynamic.new(2, 1, 1, select(2, ui.menu_size())+85),

            navigation = {
                bar_height = {
                    dynamic.new(2, 1, 1, -0.3),
                    dynamic.new(2, 1, 1, -0.3),
                    dynamic.new(2, 1, 1, -0.3),
                    dynamic.new(2, 1, 1, -0.3),
                    dynamic.new(2, 1, 1, -0.3),
                },
                active = {
                    true,
                    false,
                    false,
                    false,
                }
            },

            context = {
                scrolling = false,
                scrollvalue = 0,
                last_analogvalue = 0,
                scrollmin = 0,
                scrollmax = 0,
                itemcount = 0,
                maxitemcount = 0,
                titlelinewidth = dynamic.new(2, 1, 1, 0),
            },
        },
        Right = {
            false,
            x = dynamic.new(8, 2, 1, select(1, ui.menu_position()) + select(1, ui.menu_size()) + 10),
            y = dynamic.new(8, 2, 1, select(2, ui.menu_position())),
            w = dynamic.new(8, 1, 1, 400),
            h = dynamic.new(2, 1, 1, select(2, ui.menu_size())+85),

            playlist = {
                false,
                active_data_index,
                image_data,
                r =  dynamic.new(2, 0.8, 0.5, 70),
                g =  dynamic.new(2, 0.8, 0.5, 70),
                b =  dynamic.new(2, 0.8, 0.5, 70),
            },
        },
    }
}

--start scrollwheel
function mouse_state.new()
	return setmetatable({tape = 0, laststate = 0, initd = false, events = {}}, {__index = mouse_state})
end
local scrollstate = mouse_state.new()

function mouse_state:init()
    if not self.init then
        self.tape = 0
        self.laststate = GetAnalogDelta(inputsystem, 0x03)
        self.initd = true
    end
    if GetAnalogDelta(inputsystem, 0x03) == 0 and self.tape ~= 0 then
        self.tape = 0
        return
    end
    local currentTape = GetAnalogValue(inputsystem, 0x03)
    if currentTape > self.tape then
        for index, value in ipairs(self.events) do
            value({state = "Up", pos = currentTape})
        end
        self.tape = currentTape
    elseif currentTape < self.tape then
        for index, value in ipairs(self.events) do
            value({state = "Down", pos = currentTape})
        end
        self.tape = currentTape
    end

    if GetAnalogValue(inputsystem, 0x03) >= hud.extended.Left.context.last_analogvalue + 1 and not hud.extended.Left.context.scrollmin then
        hud.extended.Left.context.scrollvalue = hud.extended.Left.context.scrollvalue + 1
    elseif GetAnalogValue(inputsystem, 0x03) <= hud.extended.Left.context.last_analogvalue - 1 and not hud.extended.Left.context.scrollmax then
        hud.extended.Left.context.scrollvalue = hud.extended.Left.context.scrollvalue - 1
    end
    hud.extended.Left.context.last_analogvalue = GetAnalogValue(inputsystem, 0x03)
end

--i don't want to talk about it
local pswitch = false
local sswitch = false
local function buffer(x, y ,r, t)
    
    local p = hud.extended.buffer_p:get()
    local s = hud.extended.buffer_s:get()

    if pswitch and not sswitch then
        s = hud.extended.buffer_s:update(globals.frametime(), 360, nil):get()
        p = hud.extended.buffer_p:update(globals.frametime(), 1, nil):get()
    elseif pswitch and sswitch then
        p = hud.extended.buffer_p:update(globals.frametime(), 0, nil):get()
    else
        p = hud.extended.buffer_p:update(globals.frametime(), 1, nil):get()
    end

    if p >= 0.97 then
        pswitch = true
        sswitch = true
    elseif p <= 0.03 then
        pswitch = false
    end

    if sswitch then
        s = hud.extended.buffer_s:update(globals.frametime(), 0, nil):get()
        if s <= 12 and p <= 0.1 then
            sswitch = false
        end
    end
    --client.log("p: "..p.." s: "..s .. " pswitch: "..tostring(pswitch).." sswitch: "..tostring(sswitch))
    renderer.circle_outline(x, y, 30, 215, 96, 255, r, s, p, t)
end

switch = function(check)                                        
    return function(cases)
        if type(cases[check]) == "function" then
            return cases[check]()
        elseif type(cases["default"] == "function") then
            return cases["default"]()
        end
    end
end

function round(n)
	return n % 1 >= 0.5 and math.ceil(n) or math.floor(n)
end

local js = panorama.open()
local persona = js.MyPersonaAPI
local xuid = persona.GetXuid()

local fonts = {
    title = surface.create_font("Corbel", 30, 700, 0x010),
    artist = surface.create_font("Corbel", 16, 200, 0x010),
    hud_navtitle = surface.create_font("Corbel", 25, 700, 0x010),
    hud_playlist = surface.create_font("Corbel", 22, 300, 0x010),
}

local function CP()
    local len = native_GetClipboardTextCount()
    if len > 0 then
      local char_arr = new_char_arr(len)
      native_GetClipboardText(0, char_arr, len)
      return ffi.string(char_arr, len-1)
    end
end

local authentication = {
    access_token = database.read("spotify_access_token") or "",
    refresh_token = database.read("spotify_refresh_token") or "",
}

local data = {}

local colours = {        
    r =  dynamic.new(2, 0.8, 0.5, 13),
    g =  dynamic.new(2, 0.8, 0.5, 13),
    b =  dynamic.new(2, 0.8, 0.5, 13),
}

local vars = {
    delay = 2,
    switch = false,
    artist_string = "",
    total_updates = 0,
}

local window = {
    x = dynamic.new(2, 0.8, 0.5, database.read("spotify_x") or 10),
    y = dynamic.new(2, 0.8, 0.5, database.read("spotify_y") or 10),
    w = 200,
    h = 60,
    offset = true,
    moving = false,
    cover_art_position = dynamic.new(4, 1, 1, 0),
}

local function open_page(page_url) 
    local js = panorama.loadstring([[
        return {
            open_url: function(url){
                SteamOverlayAPI.OpenURL(url)
            }
        }
    ]])()
    js.open_url(page_url) 
end

local function intersect(x, y, w, h, d) 
    if d then surface.draw_filled_rect(x, y, w, h, 255, 0, 0, 50) end
    local mousepos = { ui.mouse_position() }
    return mousepos[1] >= x and mousepos[1] <= x + w and mousepos[2] >= y and mousepos[2] <= y + h
end

function auth(rtk)
    if spotify.authstatus() == "UNINITIALISED" or spotify.authstatus() == "OPENED_BROWSER" then
        client.log(rtk)
        spotify.init(rtk)
        database.write("spotify_refresh_token", rtk)
    elseif spotify.authstatus() == "INVALID_TOKEN" then
        spotify.reset() 
        spotify.promptlogin()
    else
        return
    end 
end

local menu = {
    enable = ui.new_checkbox("MISC", "Miscellaneous", "\a1ED760FFSpoti\aFFFFFFFFLite"),
    authorization = {
        status = ui.new_label("MISC", "Miscellaneous", "\a1ED760FF> \affffffff UNINITIALISED"),
        authorise = ui.new_button("MISC", "Miscellaneous", "\a1ED760FFAuthorise",  function() auth(CP()) end),
        reset = ui.new_button("MISC", "Miscellaneous", "\a1ED760FFreset",  function() spotify.reset() end),

    },
    options = {
        cover_art = ui.new_checkbox("MISC", "Miscellaneous", "\a1ED760FF> \affffffff Cover art"),
        cover_art_colour = ui.new_checkbox("MISC", "Miscellaneous", "\a1ED760FF> \affffffff Use cover art colour for background rectangle?"),
        background_colour_label = ui.new_label("MISC", "Miscellaneous", "\a1ED760FF> \affffffff Background colour"),
        background_colour = ui.new_color_picker("MISC", "Miscellaneous", "BACKGROUND_COLOUR", 13,13,13,130),
        hud = ui.new_checkbox("MISC", "Miscellaneous", "\a1ED760FF> \affffffff Spotify HUD")
    }
}

function update_data()
    if spotify.authstatus() == "COMPLETED" and ui.get(menu.enable) or spotify.authstatus() == "SONG_FAILURE" then
        if vars.delay < client.unix_time() then
            status, data = pcall(spotify.update) -- i love spotifys images and image library!
            vars.delay = client.unix_time() + 2
        elseif spotify.updateasync() then
            vars.artist_string = ""
            for i = 1, #data.artists do
                vars.artist_string = i == #data.artists and vars.artist_string .. data.artists[i].name or vars.artist_string .. data.artists[i].name ..  ", "
            end
            
            http.get(data.image_url, function(success, response)
                if response.status == 200 then
                    vars.song_image = images.load_jpg(response.body)
                    vars.total_updates = vars.total_updates + 1
                end
            end)
        end
        status, data = pcall(spotify.get_data)
        if ui.get(menu.options.cover_art_colour) then 
            r, g ,b = data.image_colours.r, data.image_colours.g, data.image_colours.b
        elseif not ui.get(menu.options.cover_art_colour) then
            r,g,b,a = ui.get(menu.options.background_colour)
        end

        colours.r:update(globals.frametime(), r, nil)
        colours.g:update(globals.frametime(), g, nil)
        colours.b:update(globals.frametime(), b, nil)
    end
end

function draw_spotify_window()
    local r, g, b = colours.r:get(), colours.g:get(), colours.b:get()
    window.cover_art_position:update(globals.frametime(), ui.get(menu.options.cover_art) and 50 or 0, nil)
    data.song_size = surface.get_text_size(fonts.title, data.song_name)
    data.artist_size = surface.get_text_size(fonts.artist, vars.artist_string)
    window_x = window.x:get()
    window_y = window.y:get()
    window.w = data.song_size > data.artist_size and data.song_size + 40+window.cover_art_position:get() or data.artist_size + 40+window.cover_art_position:get()
    surface.draw_filled_rect(window_x,window_y,window.w,window.h,r,g,b,130)
    surface.draw_text(window_x+15+window.cover_art_position:get(), window_y+5, 255, 255, 255, 255, fonts.title, data.song_name)
    surface.draw_text(window_x+15+window.cover_art_position:get(), window_y+35, 255, 255, 255, 255, fonts.artist, vars.artist_string)
    surface.draw_filled_rect(window_x+5,window_y+5,math.floor(window.cover_art_position:get()),50,26,26,26,255)
    surface.draw_text(window_x+window.cover_art_position:get()/2-1, window_y+15, 130, 130, 130, 255, fonts.title, window.cover_art_position:get() < 1 and "" or "?")
    if vars.song_image then
        vars.song_image:draw(window_x+5,window_y+5,math.floor(window.cover_art_position:get()),50)
    end
    if intersect(window_x, window_y, window.w, window.h) and client.key_state(0x01) then
        window.moving = true
    elseif not client.key_state(0x01) then
        window.moving = false
    end
    if window.moving then
        local mousepos = { ui.mouse_position() }
        if window.offset then
            mouseposx = mousepos[1] - window_x
            mouseposy = mousepos[2] - window_y
            window.offset = false
        end
        window.x:update(globals.frametime(), mousepos[1] - mouseposx, nil)
        window.y:update(globals.frametime(), mousepos[2] - mouseposy, nil)
    else
        window.offset = true
    end
end

function draw_hud()
    menu_position = {ui.menu_position()}
    menu_size = {ui.menu_size()}
    mouse_position = { ui.mouse_position() }
    hud_x = hud.x:update(globals.frametime(), menu_position[1], nil):get()
    hud_y = hud.y:update(globals.frametime(), menu_position[2] + menu_size[2] + 10, nil):get()
    hud_w = hud.w:update(globals.frametime(), menu_size[1], nil):get()
    hud_h = hud.h:get()
    surface.draw_filled_rect(hud_x,hud_y,hud_w,hud_h,26,26,26,255)
    surface.draw_filled_rect(hud_x+10,hud_y+5,math.floor(window.cover_art_position:get()),50,26,26,26,255)
    if not hud.extended.Left[0] then
        surface.draw_text(hud_x+30, hud_y+20, 130, 130, 130, 255, fonts.title, window.cover_art_position:get() < 1 and "" or "?")
    end
    if vars.song_image then
        vars.song_image:draw(hud_x+10,hud_y+10,hud.cover_art_position:get(),55)
    end
    surface.draw_text(hud_x+15+(hud.cover_art_position:get()*1.15), hud_y+10, 255, 255, 255, 255, fonts.title, data.song_name)
    surface.draw_text(hud_x+15+(hud.cover_art_position:get()*1.15), hud_y+42, 255, 255, 255, 255, fonts.artist, vars.artist_string)
    surface.draw_filled_gradient_rect(hud_x+390, hud_y, 30, hud_h, 26,26,26,0, 26,26,26,hud.hover_alpha:get(), true)
    surface.draw_filled_rect(hud_x+420,hud_y,hud_w-420,hud_h,26,26,26,hud.hover_alpha:get())
    if intersect(hud_x-10,hud_y,hud_w,hud_h) then
        hud.hover_alpha:update(globals.frametime(), 255, nil)
        hud.hover_movement:update(globals.frametime(), 1, nil)

        if not hud.extended.Left[0] then
            renderer.circle(hud_x+12-(hud.hover_movement:get() * 12), hud_y+20,19,19,19,255, 12, 180, 0.5)
            renderer.line(hud_x+12-(hud.hover_movement:get() * 12), hud_y + 13, hud_x+4-(hud.hover_movement:get() * 12), hud_y + 20, 255, 255, 255, 150*hud.hover_movement:get())
            renderer.line(hud_x+12-(hud.hover_movement:get() * 12), hud_y + 27, hud_x+4-(hud.hover_movement:get() * 12), hud_y + 20, 255, 255, 255, 150*hud.hover_movement:get())
            if intersect(hud_x-12, hud_y+12, 13, 28) then
                renderer.line(hud_x+12-(hud.hover_movement:get() * 12), hud_y + 13, hud_x+4-(hud.hover_movement:get() * 12), hud_y + 20, 255, 255, 255, 255*hud.hover_movement:get())
                renderer.line(hud_x+12-(hud.hover_movement:get() * 12), hud_y + 27, hud_x+4-(hud.hover_movement:get() * 12), hud_y + 20, 255, 255, 255, 255*hud.hover_movement:get())
                if client.key_state(0x01) and not clicked_once then
                    hud.extended.Left[0] = true
                    clicked_once = true
                end
            end
        end

    else
        hud.hover_alpha:update(globals.frametime(), 0, nil)
        hud.hover_movement:update(globals.frametime(), 0, nil)
        if not hud.extended.Left[0] then
            renderer.circle(hud_x+12-(hud.hover_movement:get() * 12), hud_y+20,19,19,19,hud.hover_movement:get()*255, 12, 180, 0.5)
        end
    end
    if intersect(hud_x,hud_y+65,hud_w,10) then
        hud.bar_width:update(globals.frametime(), 5, nil)
        hud.bar_length:update(globals.frametime(), (mouse_position[1]-hud_x)/hud_w, nil)
        surface.draw_filled_rect(hud_x,hud_y+75-hud.bar_width:get(),(hud.bar_length:get()*hud_w),hud.bar_width:get(),0,255,0,255)
        renderer.circle(mouse_position[1], hud_y+75-hud.bar_width:get()+2,255,255,255,255, hud.bar_width:get()*1.3, 0, 1)
    else
        hud.bar_width:update(globals.frametime(), 2, nil)
        hud.bar_length:update(globals.frametime(), (data.timestamp / data.duration), nil)
        surface.draw_filled_rect(hud_x,hud_y+75-hud.bar_width:get(),(hud.bar_length:get()*hud_w),hud.bar_width:get(),0,255,0,255)
    end
    if data.is_playing then
        renderer.text(hud_x+hud_w/2, hud_y+hud_h/2, 255,255,255,hud.hover_alpha:get()/2+hud.play_alpha:get(),"c+",0,"⏸")
    else
        renderer.text(hud_x+hud_w/2, hud_y+hud_h/2, 255,255,255,hud.hover_alpha:get()/2+hud.play_alpha:get(),"c+",0,"▶")
    end
    renderer.text(hud_x+hud_w/2-40, hud_y+hud_h/2, 255,255,255,hud.hover_alpha:get()/2+hud.back_alpha:get(),"c+",0,"⏮")
    renderer.text(hud_x+hud_w/2+40, hud_y+hud_h/2, 255,255,255,hud.hover_alpha:get()/2+hud.next_alpha:get(),"c+",0,"⏭")
    if intersect(hud_x+hud_w/2-5, hud_y+hud_h/2-5, 15, 20) then
        hud.play_alpha:update(globals.frametime(), 127.5, nil)
        hud.back_alpha:update(globals.frametime(), 0, nil)
        hud.next_alpha:update(globals.frametime(), 0, nil)
        if client.key_state(0x01) and not clicked_once then
            spotify.playpause()
            clicked_once = true
        end
    elseif intersect(hud_x+hud_w/2-55, hud_y+hud_h/2-5, 30, 20) then
        hud.play_alpha:update(globals.frametime(), 0, nil)
        hud.back_alpha:update(globals.frametime(), 127.5, nil)
        hud.next_alpha:update(globals.frametime(), 0, nil)
        if client.key_state(0x01) and not clicked_once then
            spotify.previous()
            clicked_once = true
        end
    elseif intersect(hud_x+hud_w/2+25, hud_y+hud_h/2-5, 30, 20) then
        hud.play_alpha:update(globals.frametime(), 0, nil)
        hud.back_alpha:update(globals.frametime(), 0, nil)
        hud.next_alpha:update(globals.frametime(), 127.5, nil)
        if client.key_state(0x01) and not clicked_once then
            spotify.next()
            clicked_once = true
        end
    elseif not client.key_state(0x01) and clicked_once then
        clicked_once = false
    else
        hud.play_alpha:update(globals.frametime(), 0, nil)
        hud.back_alpha:update(globals.frametime(), 0, nil)
        hud.next_alpha:update(globals.frametime(), 0, nil)
    end

    xtl_x = hud.extended.Left.x:update(globals.frametime(), menu_position[1]-240, nil):get()
    xtl_y = hud.extended.Left.y:update(globals.frametime(), menu_position[2], nil):get()
    xtl_w = hud.extended.Left.w:get()
    xtl_h = hud.extended.Left.h:update(globals.frametime(), menu_size[2]+85, nil):get()

    if hud.extended.Left[0] then 
        hud.cover_art_position:update(globals.frametime(), 0, nil)
        gl_perc = math.max(hud.extended.initpercentage:update(globals.frametime(), 1, nil):get(), 0)
        gl_unfuckedperc = math.ceil(gl_perc*100)/100

        gl_opac = math.ceil(gl_perc*255)
        --client.log(gl_opac .. " " .. tostring(hud.extended.Left[0]) .. "percent: " .. gl_perc)

        surface.draw_filled_rect(xtl_x,xtl_y,xtl_w,40,18,18,18, gl_opac)

        surface.draw_filled_rect(xtl_x,xtl_y+50,xtl_w,xtl_h-290,18,18,18,gl_opac)
        surface.draw_filled_rect(xtl_x,xtl_y+menu_size[2]-145,xtl_w,230,26,26,26,gl_opac)

        --start navigation
        for i = 0, 4 do
            if i == 4 then
                renderer.line(xtl_x+46*i+13, xtl_y + 13, xtl_x+46*i+23, xtl_y + 25, 200, 200, 200, 200)
                renderer.line(xtl_x+46*i+31, xtl_y + 13, xtl_x+46*i+22, xtl_y + 25, 200, 200, 200, 200)
            end
            if intersect(xtl_x+46*i, xtl_y, 45, 40) then 
                surface.draw_filled_rect(xtl_x+46*i,xtl_y,46,40,50,50,50,gl_opac)
                surface.draw_filled_rect(xtl_x+46*i,xtl_y+41-hud.extended.Left.navigation.bar_height[i+1]:get(), 46, hud.extended.Left.navigation.bar_height[i+1]:get(),0,255,0,(gl_opac/4)*hud.extended.Left.navigation.bar_height[i+1]:get())
                hud.extended.Left.navigation.bar_height[i+1]:update(globals.frametime(), 3, nil)
                navHandler(i)
            else
                if hud.extended.Left.navigation.active[i] then
                    surface.draw_filled_rect(xtl_x+46*i,xtl_y,46,40,50,50,50,gl_opac)
                    hud.extended.Left.navigation.bar_height[i+1]:update(globals.frametime(), 3, nil)
                    surface.draw_filled_rect(xtl_x+46*i,xtl_y+38,46,3,0,255,0,(gl_opac/4)*hud.extended.Left.navigation.bar_height[i+1]:get())
                else
                    hud.extended.Left.navigation.bar_height[i+1]:update(globals.frametime(), -0.1, nil)
                    surface.draw_filled_rect(xtl_x+46*i,xtl_y+41-hud.extended.Left.navigation.bar_height[i+1]:get(), 46, hud.extended.Left.navigation.bar_height[i+1]:get(),0,255,0,(gl_opac/4)*hud.extended.Left.navigation.bar_height[i+1]:get())
                end
            end
            i = i + 1
        end
        --end navigation

        --start context rendering
        local scroll_value = hud.extended.Left.context.scrollvalue*-1
        local item_index = 1

        surface.draw_filled_rect(xtl_x + 10, xtl_y + 80, (xtl_w - 20)*hud.extended.Left.context.titlelinewidth:get(), 1, 70, 70, 70, 255)
        if hud.extended.Left.navigation.active[0] then
            hud.extended.Left.context.itemcount = data.playlists_local_total
            local rm = round(260/(xtl_h-290))
            hud.extended.Left.context.maxitemcount = round(((xtl_h-290)/33))-rm
            surface.draw_text(xtl_x + 12, xtl_y + 60, 210, 210, 210, 255, fonts.hud_navtitle, "Your library")
            hud.extended.Left.context.titlelinewidth:update(globals.frametime(), 0.505, nil)
            if data.playlists_local_total == data.playlists_user_total then
                for i = hud.extended.Left.context.maxitemcount, 1, -1 do
                    --client.log(scroll_value .. " scrolli: ".. item_index .." scrollmax: ".. hud.extended.Left.context.maxitemcount .. " local pcount: " .. data.playlists_local_total .. " item_index-scroll_value:" .. item_index+hud.extended.Left.context.scrollvalue)
                    if scroll_value+item_index <= hud.extended.Left.context.itemcount then
                        local pname = tostring(data.playlists[scroll_value+item_index].name)
                        if pname:len() > 20 then
                            pname = pname:sub(1, 20) .. "..."
                        end
                        if intersect(xtl_x + 6, xtl_y + 70 + (30 * item_index), 224, 29) then
                            if client.key_state(0x01) then
                                surface.draw_text(xtl_x + 12, xtl_y + 70 + (30 * item_index), 160, 160, 160, 160, fonts.hud_playlist, pname)
                                if not clicked_once then
                                    hud.extended.Right[0] = true
                                    clicked_once = true
                                    hud.extended.Right.playlist[0] = true
                                    hud.extended.Right.playlist.active_data_index = scroll_value+item_index
                                    http.get(data.playlists[scroll_value+item_index].image_url, function(success, response)
                                        if response.status == 200 then
                                            hud.extended.Right.playlist.image_data = images.load_jpg(response.body)
                                        end
                                    end)
                                    spotify.get_playlist_data(data.playlists[scroll_value+item_index].uri, 50, 0, false)
                                end
                            else
                                surface.draw_text(xtl_x + 12, xtl_y + 70 + (30 * item_index), 230, 230, 230, 255, fonts.hud_playlist, pname)
                            end
                        else
                            surface.draw_text(xtl_x + 12, xtl_y + 70 + (30 * item_index), 160, 160, 160, 160, fonts.hud_playlist, pname)
                        end
                        item_index = item_index + 1
                    end
                end
                item_index = 1
            else
                buffer(xtl_x+114, ((xtl_h-290)/2)+(xtl_y+60), 28, 1)
            end
        elseif hud.extended.Left.navigation.active[1] then
            hud.extended.Left.context.itemcount = 0
            hud.extended.Left.context.titlelinewidth:update(globals.frametime(), 0.30, nil)
            surface.draw_text(xtl_x + 12, xtl_y + 60, 210, 210, 210, 255, fonts.hud_navtitle, "Search")
        elseif hud.extended.Left.navigation.active[2] then
            hud.extended.Left.context.itemcount = 0
            hud.extended.Left.context.titlelinewidth:update(globals.frametime(), 0.36, nil)
            surface.draw_text(xtl_x + 12, xtl_y + 60, 210, 210, 210, 255, fonts.hud_navtitle, "Sessions")
        elseif hud.extended.Left.navigation.active[3] then
            hud.extended.Left.context.itemcount = 0
            hud.extended.Left.context.titlelinewidth:update(globals.frametime(), 0.36, nil)
            surface.draw_text(xtl_x + 12, xtl_y + 60, 210, 210, 210, 255, fonts.hud_navtitle, "Settings")
        end
        if hud.extended.Left.context.maxitemcount < hud.extended.Left.context.itemcount and hud.extended.Left.context.itemcount ~= nil then
            local sbh = (100/(hud.extended.Left.context.itemcount/hud.extended.Left.context.maxitemcount))
            renderer.rectangle(xtl_x + xtl_w - 14, xtl_y + 90 + (((hud.extended.Left.context.maxitemcount-1)*29)/(data.playlists_local_total-hud.extended.Left.context.maxitemcount))*(scroll_value), 11, 15+sbh, 120, 120, 120, 130)
        end

        if intersect(xtl_x, xtl_y+60, xtl_w, xtl_h) and hud.extended.Left.context.maxitemcount <= hud.extended.Left.context.itemcount then
            hud.extended.Left.context.scrolling = true
            if scroll_value <= 0 then
                hud.extended.Left.context.scrollmin = true
            else
                hud.extended.Left.context.scrollmin = false
            end
            if scroll_value >= (hud.extended.Left.context.itemcount-hud.extended.Left.context.maxitemcount) then
                hud.extended.Left.context.scrollmax = true
            else
                hud.extended.Left.context.scrollmax = false
            end
            scrollstate:init()
        else
            hud.extended.Left.context.scrolling = false
        end

        --end context rendering

        if vars.song_image then
            vars.song_image:draw(xtl_x+115+(-110*gl_unfuckedperc),xtl_y+menu_size[2]-(140*(gl_unfuckedperc)),220*gl_unfuckedperc,220*gl_unfuckedperc)
        end

        if hud.extended.Right[0] then
            xtr_x = hud.extended.Right.x:update(globals.frametime(), menu_position[1]+menu_size[1]+10, nil):get()
            xtr_y = hud.extended.Right.y:update(globals.frametime(), menu_position[2], nil):get()
            xtr_w = hud.extended.Right.w:get()
            xtr_h = hud.extended.Right.h:update(globals.frametime(), menu_size[2]+85):get()
    
            surface.draw_filled_rect(xtr_x,xtr_y,xtr_w,xtr_h,26,26,26,255)

            if hud.extended.Right.playlist[0] then
                local image_r, image_g, image_b = hud.extended.Right.playlist.r:get(), hud.extended.Right.playlist.g:get(), hud.extended.Right.playlist.b:get()
                local a_index = hud.extended.Right.playlist.active_data_index
                if data.playlists[a_index].image_colour == nil and data.playlists[a_index].image_colour ~= "IMAGE_ERROR" then
                    buffer(xtr_x+85, xtr_y+85, 22, 1)
                elseif data.playlists[a_index].image_colour == "IMAGE_ERROR" then
                    hud.extended.Right.playlist.r:update(globals.frametime(), 50, nil)
                    hud.extended.Right.playlist.g:update(globals.frametime(), 50, nil)
                    hud.extended.Right.playlist.b:update(globals.frametime(), 50, nil)
                else
                    hud.extended.Right.playlist.r:update(globals.frametime(), data.playlists[a_index].image_colour[1], nil)
                    hud.extended.Right.playlist.g:update(globals.frametime(), data.playlists[a_index].image_colour[2], nil)
                    hud.extended.Right.playlist.b:update(globals.frametime(), data.playlists[a_index].image_colour[3], nil)
                    hud.extended.Right.playlist.image_data:draw(xtr_x+10,xtr_y+10,150,150)
                end
                surface.draw_filled_rect(xtr_x,xtr_y,xtr_w,170,image_r,image_g,image_b,200)
                surface.draw_filled_gradient_rect(xtr_x,xtr_y,xtr_w,330,image_r,image_g,image_b,255,26,26,26,255, false)
                surface.draw_filled_rect(xtr_x+6,xtr_y+6,158,158,1,1,1,140)
                surface.draw_filled_rect(xtr_x+10,xtr_y+10,150,150,0,0,0,80)
                surface.draw_filled_rect(xtr_x,xtr_y+170,xtr_w,xtr_h-170,20,20,20,240)
            end

        end
    else
        hud.cover_art_position:update(globals.frametime(), 55, nil)
        hud.extended.initpercentage:update(globals.frametime(), 0, nil)
    end
end

function navHandler(index)
    if client.key_state(0x01) and not clicked_once then
        clicked_once = true

        if index == 4 then
            hud.extended.Left[0] = false
            clicked_once = false
            return
        end

        if index == 0 then
            spotify.get_user_playlists(10, 0, true)
        end

        for i = 0, 3 do
            if index == i then
                hud.extended.Left.navigation.active[i] = true
            else
                hud.extended.Left.navigation.active[i] = false
            end
        end

    elseif not client.key_state(0x01) and clicked_once then
        clicked_once = false
    end
end

function seek()
    local hud_x, hud_w = hud.x:get(), hud.w:get()
    if intersect(hud_x,hud.y:get()+70,hud.w:get(),10) then
        if client.key_state(0x01) and not is_mouse_pressed then
            mouse_position = { ui.mouse_position() }
            time_to_seek = (data.duration/hud_w) * (mouse_position[1]-hud_x)
            spotify.seek(time_to_seek)
            is_mouse_pressed = true
            data.timestamp = time_to_seek
        elseif not client.key_state(0x01) and is_mouse_pressed then
            is_mouse_pressed = false
        end
    end
end

function handle_menu()
    ui.set_visible(menu.authorization.authorise, ui.get(menu.enable) and spotify.authstatus() ~= "COMPLETED")
    ui.set_visible(menu.authorization.status, ui.get(menu.enable))
    for i,v in pairs(menu.options) do
        if i == "background_colour" or i == "background_colour_label" then
            ui.set_visible(v, ui.get(menu.enable) and spotify.authstatus() == "COMPLETED" and not ui.get(menu.options.cover_art_colour))
        else
            ui.set_visible(v, ui.get(menu.enable) and spotify.authstatus() == "COMPLETED")
        end
    end
    ui.set(menu.authorization.status, "\a1ED760FF> \affffffff ".. spotify.authstatus())
end

function debug()
    renderer.text(100,100,255,255,255,255,"+",0,spotify.authstatus())
    renderer.text(100,130,255,255,255,255,"+",0,data.user)
    renderer.text(100,160,255,255,255,255,"+",0,data.song_name)
    renderer.text(100,190,255,255,255,255,"+",0,vars.artist_string)
    renderer.text(100,220,255,255,255,255,"+",0,data.playlists_local_total)
end

client.set_event_callback("paint_ui", function()
    handle_menu()
    if spotify.authstatus() == "COMPLETED" and ui.get(menu.enable) then 
        update_data()
        if vars.total_updates ~= 0 then
            debug()
            draw_spotify_window()
            --_, __ = pcall(draw_spotify_window)

            if ui.get(menu.options.hud) and ui.is_menu_open() then
                draw_hud()
                --_, __ = pcall(draw_hud)
                seek()
            end
        end
    end
end)

local gaySexgamer = mouse_state.new() --you wouldn't get it
gaySexgamer:init()

client.set_event_callback("shutdown", function()
    database.write("spotify_x", window.x:get())
    database.write("spotify_y", window.y:get())
end)

if database.read("spotify_refresh_token") then
    auth(authentication.refresh_token)
    data = spotify.update()
end
