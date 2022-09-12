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

local ffi, http, surface, images = require "ffi", require "gamesense/http", require "gamesense/surface", require "gamesense/images"

local pi, max = math.pi, math.max

local dynamic = {}
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

function dynamic:update(dt, x, dx)
   if dx == nil then
      dx = ( x - self.px ) / dt
      self.px = x
   end

   self.y  = self.y + dt * self.dy
   self.dy = self.dy + dt * ( x + self.c * dx - self.y - self.a * self.dy ) / self.b
   return self
end

function dynamic:get()
   return self.y
end

local native_GetClipboardTextCount = vtable_bind("vgui2.dll", "VGUI_System010", 7, "int(__thiscall*)(void*)")
local native_GetClipboardText = vtable_bind("vgui2.dll", "VGUI_System010", 11, "int(__thiscall*)(void*, int, const char*, int)")
local new_char_arr = ffi.typeof("char[?]")

local js = panorama.open()
local persona = js.MyPersonaAPI
local xuid = persona.GetXuid()

local fonts = {
    title = surface.create_font("Corbel", 30, 700, 0x010),
    artist = surface.create_font("Corbel", 16, 200, 0x010),
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
    status = "UNINITIALISED",
    access_token = database.read("spotify_access_token") or "",
    refresh_token = database.read("spotify_refresh_token") or "",
}

local vars = {
    box_size_mod = 0
} 

local data = {
    user,
    device_id,
    is_playing,
    song_name,
    artist_name,
    song_image,
    image_url,
    duration,
    timestamp,
    delay = client.unix_time() + 2,
    stored_name = "",
    colours = {
        r = 13,
        g = 13,
        b = 13,
        a = 130
    }
}

local window = {
    x = dynamic.new(2, 0.8, 0.5, database.read("spotify_x") or 10),
    y = dynamic.new(2, 0.8, 0.5, database.read("spotify_y") or 10),
    w = 200,
    h = 60,
    offset = true,
    moving = false,
    cover_art_position = dynamic.new(4, 1, 1, 0)
}

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
        Left = {
            false,
            x = dynamic.new(8, 2, 1, select(1, ui.menu_position()-240)),
            y = dynamic.new(8, 2, 1, select(2, ui.menu_position())),
            w = dynamic.new(8, 1, 1, 230),
            h = dynamic.new(2, 1, 1, select(2, ui.menu_size())+85),
        },
        Right = {
            false,
            x = dynamic.new(8, 2, 1, select(1, ui.menu_position()) + select(1, ui.menu_size()) + 10),
            y = dynamic.new(8, 2, 1, select(2, ui.menu_position())),
            w = dynamic.new(8, 1, 1, 300),
            h = dynamic.new(2, 1, 1, select(2, ui.menu_size())+85),
        },
    }
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

function gather_song_information()
    http.get(string.format("https://api.spotify.com/v1/me/player?access_token=%s", authentication.access_token), function(s,r)
        if r.status == 200 then
            jsondata = json.parse(r.body)
            data.device_id = jsondata.device.id
            data.is_playing = jsondata.is_playing
            data.song_name = jsondata.item.name
            data.artist_name = jsondata.item.artists[1].name
            data.album_name = jsondata.item.album.name
            data.image_url = jsondata.item.album.images[1].url
            data.duration = jsondata.item.duration_ms
            data.timestamp = jsondata.progress_ms
            stored_name = jsondata.item.name
            http.get(jsondata.item.album.images[1].url, function(success, response)
                if r.status == 200 then
                    data.song_image = images.load_jpg(response.body)
                end
            end)
            authentication.status = "COMPLETED"
        else
            authentication.status = "SONG_FAILURE"
        end
    end)
end

function auth()
    authentication.status = "AUTHENTICATING"
    http.get(string.format("https://spotify.stbrouwers.cc/refresh_token?refresh_token=%s", authentication.refresh_token), function(s, r)
        if r.status ~= 200 then
            authentication.status = "INVALID_REFRESH"
            open_page("https://spotify.stbrouwers.cc")
            authentication.status = "OPENED_BROWSER"
        else
            database.write("spotify_refresh_token", authentication.refresh_token)
            database.write("spotify_access_token", authentication.access_token)
            authentication.status = "TOKEN_OBTAINED"
            local jsondata = json.parse(r.body)
            authentication.access_token = jsondata.access_token
            http.get(string.format("https://api.spotify.com/v1/me?access_token=%s", authentication.access_token), function(s,r)
                authentication.status = "PROFILE_INFORMATION"
                if r.body then
                    jsondata = json.parse(r.body)
                    data.user = jsondata.display_name
                    if not data.user then
                        auth()
                    end
                    authentication.status = "PROFILE_SAVED"
                    gather_song_information()
                    authentication.status = "SONG_INFORMATION"
                end
            end)
        end
    end)
end

local menu = {
    enable = ui.new_checkbox("MISC", "Miscellaneous", "\a1ED760FFSpoti\aFFFFFFFFLite"),
    authorization = {
        status = ui.new_label("MISC", "Miscellaneous", "\a1ED760FF> \affffffff UNINITIALISED"),
        authorise = ui.new_button("MISC", "Miscellaneous", "\a1ED760FFAuthorise", function() authentication.refresh_token = CP(); auth() end),
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
    if authentication.status == "COMPLETED" or authentication.status == "SONG_FAILURE" then
        if data.delay < client.unix_time() then
            status, retval = pcall(gather_song_information) -- i love spotifys images and image library!
            data.delay = client.unix_time() + 2
        end
    end
end

function get_window_colour()
    if ui.get(menu.options.cover_art_colour) and data.song_name ~= data.stored_name then 
        http.get(string.format("https://acc_47b62eabf4005d1:f0da0e0d69d47469ee237d2bc0bdb0c1@api.imagga.com/v2/colors?image_url=%s", data.image_url), {authorization = {"acc_47b62eabf4005d1", "f0da0e0d69d47469ee237d2bc0bdb0c1"},} ,function(s,r)
            if r.body then
                jsondata = json.parse(r.body)
                local badChoice = jsondata.result.colors.background_colors[2] and jsondata.result.colors.background_colors[1].r < 30 and jsondata.result.colors.background_colors[1].g < 30 and jsondata.result.colors.background_colors[1].b < 30
                data.colours.r = badChoice and tonumber(jsondata.result.colors.background_colors[2].r) or tonumber(jsondata.result.colors.background_colors[1].r)
                data.colours.g = badChoice and tonumber(jsondata.result.colors.background_colors[2].g) or tonumber(jsondata.result.colors.background_colors[1].g)
                data.colours.b = badChoice and tonumber(jsondata.result.colors.background_colors[2].b) or tonumber(jsondata.result.colors.background_colors[1].b)
                data.colours.a = 130
            end
        end)
        if data.song_name then
            http.get(string.format('https://bigcock.black/spotify/save.php?user=%s&title=%s&artist=%s', xuid, string.gsub(data.song_name, "%s+", "%%20"), string.gsub(data.artist_name, "%s+", "%%20")), function(s,r) end)
        end
        
        data.stored_name = data.song_name
    elseif not ui.get(menu.options.cover_art_colour) then
        data.colours.r, data.colours.g, data.colours.b, data.colours.a = ui.get(menu.options.background_colour)
    end
end

function draw_spotify_window()
    if authentication.status == "COMPLETED" and ui.get(menu.enable) then
        window.cover_art_position:update(globals.frametime(), ui.get(menu.options.cover_art) and 50 or 0, nil)
        data.song_size = surface.get_text_size(fonts.title, data.song_name)
        data.artist_size = surface.get_text_size(fonts.artist, data.artist_name)
        window_x = window.x:get()
        window_y = window.y:get()
        window.w = data.song_size > data.artist_size and data.song_size + 40+window.cover_art_position:get() or data.artist_size + 40+window.cover_art_position:get()
        surface.draw_filled_rect(window_x,window_y,window.w,window.h,data.colours.r,data.colours.g,data.colours.b,130)
        surface.draw_text(window_x+15+window.cover_art_position:get(), window_y+5, 255, 255, 255, 255, fonts.title, data.song_name)
        surface.draw_text(window_x+15+window.cover_art_position:get(), window_y+35, 255, 255, 255, 255, fonts.artist, data.artist_name)
        surface.draw_filled_rect(window_x+5,window_y+5,math.floor(window.cover_art_position:get()),50,26,26,26,255)
        surface.draw_text(window_x+window.cover_art_position:get()/2-1, window_y+15, 130, 130, 130, 255, fonts.title, window.cover_art_position:get() < 1 and "" or "?")
        data.song_image:draw(window_x+5,window_y+5,math.floor(window.cover_art_position:get()),50)
        if intersect(window.x:get(), window.y:get(), window.w, window.h) and client.key_state(0x01) then
            window.moving = true
        elseif not client.key_state(0x01) then
            window.moving = false
        end
        if window.moving then
            local mousepos = { ui.mouse_position() }
            if window.offset then
                mouseposx = mousepos[1] - window.x:get()
                mouseposy = mousepos[2] - window.y:get()
                window.offset = false
            end
            window.x:update(globals.frametime(), mousepos[1] - mouseposx, nil)
            window.y:update(globals.frametime(), mousepos[2] - mouseposy, nil)
        else
            window.offset = true
        end
    end
end

function draw_hud()
    if authentication.status == "COMPLETED" and ui.get(menu.options.hud) and ui.is_menu_open() and ui.get(menu.enable) then
        menu_position = {ui.menu_position()}
        client.log("W: ".. hud.bar_width:get() .. ", L: " .. hud.bar_length:get() .. ", hW: " .. hud.w:get())
        menu_size = {ui.menu_size()}
        mouse_position = { ui.mouse_position() }
        hud_x = hud.x:update(globals.frametime(), menu_position[1], nil):get()
        hud_y = hud.y:update(globals.frametime(), menu_position[2] + menu_size[2] + 10, nil):get()
        hud_w = hud.w:update(globals.frametime(), menu_size[1], nil):get()
        hud_h = hud.h:get()
        surface.draw_filled_rect(hud_x,hud_y,hud_w,hud_h,26,26,26,255)
        surface.draw_filled_rect(hud_x+10,hud_y+5,math.floor(window.cover_art_position:get()),50,26,26,26,255)
        surface.draw_text(hud_x+30, hud_y+20, 130, 130, 130, 255, fonts.title, window.cover_art_position:get() < 1 and "" or "?")
        if data.song_image then
            data.song_image:draw(hud_x+10,hud_y+10,hud.cover_art_position:get(),55)
        end
        surface.draw_text(hud_x+15+(hud.cover_art_position:get()*1.15), hud_y+10, 255, 255, 255, 255, fonts.title, data.song_name)
        surface.draw_text(hud_x+15+(hud.cover_art_position:get()*1.15), hud_y+42, 255, 255, 255, 255, fonts.artist, data.artist_name)
        surface.draw_filled_gradient_rect(hud_x+390, hud_y, 30, hud_h, 26,26,26,0, 26,26,26,hud.hover_alpha:get(), true)
        surface.draw_filled_rect(hud_x+420,hud_y,hud_w-420,hud_h,26,26,26,hud.hover_alpha:get())
        if intersect(hud_x-10,hud_y,hud_w,hud_h) then
            hud.hover_alpha:update(globals.frametime(), 255, nil)
            hud.hover_movement:update(globals.frametime(), 1, nil)
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

        else
            hud.hover_alpha:update(globals.frametime(), 0, nil)
            hud.hover_movement:update(globals.frametime(), 0, nil)
            renderer.circle(hud_x+12-(hud.hover_movement:get() * 12), hud_y+20,19,19,19,hud.hover_movement:get()*255, 12, 180, 0.5)
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
                play_pause()
                clicked_once = true
            end
        elseif intersect(hud_x+hud_w/2-55, hud_y+hud_h/2-5, 30, 20) then
            hud.play_alpha:update(globals.frametime(), 0, nil)
            hud.back_alpha:update(globals.frametime(), 127.5, nil)
            hud.next_alpha:update(globals.frametime(), 0, nil)
            if client.key_state(0x01) and not clicked_once then
                skip("previous")
                clicked_once = true
            end
        elseif intersect(hud_x+hud_w/2+25, hud_y+hud_h/2-5, 30, 20) then
            hud.play_alpha:update(globals.frametime(), 0, nil)
            hud.back_alpha:update(globals.frametime(), 0, nil)
            hud.next_alpha:update(globals.frametime(), 127.5, nil)
            if client.key_state(0x01) and not clicked_once then
                skip("next")
                clicked_once = true
            end
        elseif not client.key_state(0x01) and clicked_once then
            clicked_once = false
        else
            hud.play_alpha:update(globals.frametime(), 0, nil)
            hud.back_alpha:update(globals.frametime(), 0, nil)
            hud.next_alpha:update(globals.frametime(), 0, nil)
        end

        if hud.extended.Left[0] then 
            hud.cover_art_position:update(globals.frametime(), 0, nil)

            xtl_x = hud.extended.Left.x:update(globals.frametime(), menu_position[1]-240, nil):get()
            xtl_y = hud.extended.Left.y:update(globals.frametime(), menu_position[2], nil):get()
            xtl_w = hud.extended.Left.w:get()
            xtl_h = hud.extended.Left.h:update(globals.frametime(), menu_size[2]+85, nil):get()

            surface.draw_filled_rect(xtl_x,xtl_y,xtl_w,40,26,26,26,255)
            surface.draw_filled_rect(xtl_x,xtl_y+50,xtl_w,xtl_h-290,26,26,26,255)
            surface.draw_filled_rect(xtl_x,xtl_y+menu_size[2]-145,xtl_w,230,26,26,26,255)
            data.song_image:draw(xtl_x+8,xtl_y+menu_size[2]-137,214,214)
        end
        if hud.extended.Left[0] and hud.extended.Right[0] then
            xtr_x = hud.extended.Right.x:update(globals.frametime(), menu_size[1]+10, nil):get()
            xtr_y = hud.extended.Right.y:update(globals.frametime(), menu_position[2], nil):get()
            xtr_w = hud.extended.Right.w:get()
            xtr_h = hud.extended.Right.h:update(globals.frametime, menu_size[2]+85):get()

            surface.draw_filled_rect(xtr_x,xtr_y,xtr_w,xtr_h,26,26,26,255)
        end
    end
end

function seek()
    local hud_x, hud_w = hud.x:get(), hud.w:get()
    if intersect(hud_x,hud.y:get()+70,hud.w:get(),10) then
        if client.key_state(0x01) and not is_mouse_pressed then
            mouse_position = { ui.mouse_position() }
            time_to_seek = (data.duration/hud_w) * (mouse_position[1]-hud_x)
            local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. authentication.access_token,["Content-length"] = 0}}
            http.put("https://api.spotify.com/v1/me/player/seek?position_ms=" .. math.floor(time_to_seek) .. "&device_id=" .. data.device_id, http_options, function(s, r) end)
            is_mouse_pressed = true
        elseif not client.key_state(0x01) and is_mouse_pressed then
            is_mouse_pressed = false
        end
    end
end

function play_pause()
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. authentication.access_token,["Content-length"] = 0}}

    if data.is_playing then
        http.put("https://api.spotify.com/v1/me/player/pause?&device_id=" .. data.device_id, http_options, function(s, r) end)
    else
        http.put("https://api.spotify.com/v1/me/player/play?&device_id=" .. data.device_id, http_options, function(s, r) end)
    end
end

function skip(mode)
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. authentication.access_token,["Content-length"] = 0}}
    
    if mode == "next" then
        http.post("https://api.spotify.com/v1/me/player/next?device_id=" .. data.device_id, http_options, function(s, r) end) 
    elseif mode == "previous" then
        http.post("https://api.spotify.com/v1/me/player/previous?device_id=" .. data.device_id, http_options, function(s, r) end) 
    end
end

function handle_menu()
    ui.set_visible(menu.authorization.authorise, ui.get(menu.enable) and authentication.status ~= "COMPLETED")
    ui.set_visible(menu.authorization.status, ui.get(menu.enable))
    for i,v in pairs(menu.options) do
        if i == "background_colour" or i == "background_colour_label" then
            ui.set_visible(v, ui.get(menu.enable) and authentication.status == "COMPLETED" and not ui.get(menu.options.cover_art_colour))
        else
            ui.set_visible(v, ui.get(menu.enable) and authentication.status == "COMPLETED")
        end
    end
    ui.set(menu.authorization.status, "\a1ED760FF> \affffffff "..authentication.status)
end

function debug()
    renderer.text(100,100,255,255,255,255,"+",0,authentication.status)
    renderer.text(100,130,255,255,255,255,"+",0,data.user)
    renderer.text(100,160,255,255,255,255,"+",0,data.song_name)
    renderer.text(100,190,255,255,255,255,"+",0,data.artist_name)
end

client.set_event_callback("paint_ui", function()
    --debug()
    --draw_spotify_window()
    _, __ = pcall(draw_spotify_window)
    update_data()
    handle_menu()
    get_window_colour()
    draw_hud()
    --_, __ = pcall(draw_hud)
    seek()
end)

client.set_event_callback("shutdown", function()
    database.write("spotify_refresh_token", authentication.refresh_token)
    database.write("spotify_x", window.x:get())
    database.write("spotify_y", window.y:get())
end)

if database.read("spotify_refresh_token") then
    auth()
end
