local surface = require "gamesense/surface"
local http = require "gamesense/http"
local ffi = require "ffi"
local TitleFont = surface.create_font("GothamBookItalic", 26, 900, 0x010)
local ArtistFont = surface.create_font("GothamBookItalic", 17, 600, 0x010)

local database_read = database.read
local database_write = database.write
local package_searchpath = package.searchpath
local ui_set_callback = ui.set_callback
local ui_set_visible = ui.set_visible
local ui_get = ui.get
local ui_set = ui.set
local ui_new_label = ui.new_label
local ui_new_button = ui.new_button
local ui_new_checkbox = ui.new_checkbox
local ui_new_slider = ui.new_slider

local MainCheckbox = ui.new_checkbox("MISC", "Miscellaneous", "Spotify")

local SpotifyIndicX = database_read("previous_posX") or 0
local SpotifyIndicY = database_read("previous_posY") or 1020
local SizePerc = database_read("previous_size") or 30

local native_GetClipboardTextCount = vtable_bind("vgui2.dll", "VGUI_System010", 7, "int(__thiscall*)(void*)")
local native_GetClipboardText = vtable_bind("vgui2.dll", "VGUI_System010", 11, "int(__thiscall*)(void*, int, const char*, int)")
local new_char_arr = ffi.typeof("char[?]")

local function CP()
    local len = native_GetClipboardTextCount()
    if len > 0 then
      local char_arr = new_char_arr(len)
      native_GetClipboardText(0, char_arr, len)
      return ffi.string(char_arr, len-1)
    end
end

dragging = false
Authed = false
CornerReady = false

AuthStatus = "false"
UserName = "-"
SongName = "-"
ArtistName = "-"
SongProgression = "-"
SongLength = "-"
Cornereg = "NONE"
AuthURL = "https://developer.spotify.com/console/get-users-currently-playing-track/"

if database_read("previous_posX") >= 1920 then
    SpotifyIndicX = 0
    SpotifyIndicY = 1020
end

local txt_exists = function(name)
    return (function(filename) return package.searchpath("", filename) == filename end)("./" .. name)
end

function Auth() 
    KeyFile = txt_exists('spotify.txt')
    apikey = CP()
    client.color_log(123, 194, 21, apikey)
    if KeyFile then
        http.get("https://api.spotify.com/v1/me?&access_token=" .. apikey, function(success, response)
            ConnectionStatus = response.status
            if not success or response.status ~= 200 then
                AuthStatus = "Failed to Auth"
                return end
                spotidata = json.parse(response.body)
                UserName = spotidata.display_name
                client.color_log(123, 194, 21, UserName)
            end)
        Authed = true
        ShowMenuElements()
    else
        ConnectionStatus = "NoFile" 
        local js = panorama.loadstring([[
            return {
              open_url: function(url){
                SteamOverlayAPI.OpenURL(url)
              }
            }
            ]])()
            js.open_url(AuthURL) 
    end
    UpdateElements()
end

function ResetAPI() 
    Authed = false
    ConnectionStatus = "NoConnection"
    local js = panorama.loadstring([[
        return {
          open_url: function(url){
            SteamOverlayAPI.OpenURL(url)
          }
        }
        ]])()
        js.open_url(AuthURL) 
    ShowMenuElements()
end

function UpdateInf()
    http.get("https://api.spotify.com/v1/me/player?access_token=" .. apikey, function(success, response)
        
        if not success or response.status ~= 200 then
            AuthStatus = "Failed to Auth"
            return end
            CurrentData = json.parse(response.body)
            SongName = CurrentData.item.name
            ArtistName = CurrentData.item.artists.name[1]
            SongLength = CurrentData.item.duration_ms / 1000
            SongProgression = CurrentData.progress_ms / 1000
            client.color_log(123, 194, 21, UserName)
        end)
end

local elements = {
    AuthButton = ui_new_button("MISC", "Miscellaneous", "Authorize", Auth),
    Connected = ui_new_label("MISC", "Miscellaneous", AuthStatus),
    DebugInfo = ui_new_checkbox("MISC", "Miscellaneous", "Debug Info"),
    NowPlaying = ui_new_label("MISC", "Miscellaneous", "Now playing:" .. SongName),
    Artist = ui_new_label("MISC", "Miscellaneous", "By:" .. ArtistName),
    SongDuration = ui_new_label("MISC", "Miscellaneous", SongProgression .. "/" .. SongLength),
    UpdateButton = ui_new_button("MISC", "Miscellaneous", "Update", UpdateInf),
    ResetKey = ui_new_button("MISC", "Miscellaneous", "Reset", ResetAPI),
    Cornerswitch = ui_new_checkbox("MISC", "Miscellaneous", "Stick to corner"),
    SizeSlider = ui_new_slider("MISC", "Miscellaneous", "Size", 30, 100, SizePerc, true, "%", 1)
}

local scaling = {
    SpotifyScaleX = 200, SpotifyScaleY = 50
}

local startpos = {
    DRegionx = 0, DRegiony = 0,
}

local endpos = {
    DRegionx = SpotifyScaleX, DRegiony = SpotifyScaleY,
}

switch = function(check)                                        
    return function(cases)
        if type(cases[check]) == "function" then
            return cases[check]()
        elseif type(cases["default"] == "function") then
            return cases["default"]()
        end
    end
end

local function intersect(x, y, w, h, debug) 
    local mousepos = { ui.mouse_position() }
    rawmouseposX = mousepos[1]
    rawmouseposY = mousepos[2]
    debug = debug or false
    if debug then 
        surface.draw_filled_rect(x, y, w, h, 255, 0, 0, 50)
    end

    return rawmouseposX >= x and rawmouseposX <= x + w and rawmouseposY >= y and rawmouseposY <= y + h
end

function ShowMenuElements() 
    if ui_get(MainCheckbox) then
        if Authed == false then 
            ui_set_visible(elements.AuthButton, true)
            ui_set_visible(elements.SizeSlider, false)
            ui_set_visible(elements.Cornerswitch, false)
            ui_set_visible(elements.Connected, false)
            ui_set_visible(elements.ResetKey, false)
            ui_set_visible(elements.NowPlaying, false)
            ui_set_visible(elements.Artist, false)
            ui_set_visible(elements.UpdateButton, false)
            ui_set_visible(elements.SongDuration, false)
        else
            ui_set_visible(elements.AuthButton, false)
            ui_set_visible(elements.SizeSlider, true)
            ui_set_visible(elements.Cornerswitch, true)
            ui_set_visible(elements.Connected, true)
            ui_set_visible(elements.ResetKey, false)
            ui_set_visible(elements.DebugInfo, true)
            

            if ui_get(elements.DebugInfo) then
                ui_set_visible(elements.NowPlaying, true)
                ui_set_visible(elements.Artist, true)
                ui_set_visible(elements.SongDuration, true)
                ui_set_visible(elements.UpdateButton, true)
            else
                ui_set_visible(elements.NowPlaying, false)
                ui_set_visible(elements.Artist, false)
                ui_set_visible(elements.SongDuration, false)
                ui_set_visible(elements.UpdateButton, false)
            end    
        end


        if ui_get(elements.Cornerswitch) then
            ui_set_visible(elements.SizeSlider, false)
        end

        if ConnectionStatus == 401 then
            ui_set_visible(elements.ResetKey, true)
            ui_set_visible(elements.AuthButton, false)
            ui_set_visible(elements.SizeSlider, false)
            ui_set_visible(elements.Cornerswitch, false)
        end

    else
        ui_set_visible(elements.AuthButton, false)
        ui_set_visible(elements.SizeSlider, false)
        ui_set_visible(elements.Cornerswitch, false)
        ui_set_visible(elements.Connected, false)
        ui_set_visible(elements.ResetKey, false)
        ui_set_visible(elements.DebugInfo, false)
        ui_set_visible(elements.NowPlaying, false)
        ui_set_visible(elements.Artist, false)
        ui_set_visible(elements.UpdateButton, false)
        ui_set_visible(elements.SongDuration, false)
    end
end

function UpdateElements()
    if Authed and ConnectionStatus == 200 then
        ui_set(elements.Connected, "> " .. "Connected to " .. UserName)
    elseif ConnectionStatus == NoFile then
        ui_set(elements.Connected, "Put your API key in spotify.txt (main csgo dir)")
    elseif ConnectionStatus == 401 then
        ui_set(elements.Connected, "Invalid API key")
        ShowMenuElements()
    end
end

local function Dragging()
    local mousepos = { ui.mouse_position() }
    rawmouseposX = mousepos[1]
    rawmouseposY = mousepos[2]
    local LClick = client.key_state(0x01)

    if dragging and not LClick then
        dragging = false
    end

    if dragging and LClick then

        if SpotifyIndicX <= -0.1 then
            SpotifyIndicX = 0
        elseif SpotifyIndicX + scaling.SpotifyScaleX >= 1920.1 then
            SpotifyIndicX = 1920 - scaling.SpotifyScaleX
        else
            SpotifyIndicX = rawmouseposX - xdrag
        end

        if SpotifyIndicY <= -0.1 then
            SpotifyIndicY = 0
        elseif SpotifyIndicY + scaling.SpotifyScaleY >= 1080.1 then
            SpotifyIndicY = 1080 - scaling.SpotifyScaleY
        else    
            SpotifyIndicY = rawmouseposY - ydrag
        end

    end

    if intersect(SpotifyIndicX - startpos.DRegionx, SpotifyIndicY - startpos.DRegiony, scaling.SpotifyScaleX, scaling.SpotifyScaleY, false) and LClick then 
        dragging = true
        xdrag = rawmouseposX - SpotifyIndicX
        ydrag = rawmouseposY - SpotifyIndicY
    end

end

local function AdjustSize() 
    SelectedSize = ui_get(elements.SizeSlider)
    ConvSize = SelectedSize / 100
    scaling.SpotifyScaleX, endpos.DRegionx = 400 * ConvSize
    scaling.SpotifyScaleY, endpos.DRegiony = 100 * ConvSize
    
    
    if SpotifyIndicX <= -0.1 then
        SpotifyIndicX = 0
    elseif SpotifyIndicX + scaling.SpotifyScaleX >= 1920.1 then
        SpotifyIndicX = 1920 - scaling.SpotifyScaleX
    end

    if SpotifyIndicY <= -0.1 then
        SpotifyIndicY = 0
    elseif SpotifyIndicY + scaling.SpotifyScaleY >= 1080.1 then
        SpotifyIndicY = 1080 - scaling.SpotifyScaleY
    end

end

function SetAutocorner()
    if dragging == true and ui_get(elements.Cornerswitch) then
        if rawmouseposX <= 760 and rawmouseposY <= 540 then
            surface.draw_filled_rect(0, 0, 400, 100, 20, 146, 255, 30)
            surface.draw_outlined_rect(0, 0, 400, 100, 40, 40, 255, 190)
            Cornereg = "TL"
        end

        if rawmouseposX >= 1160 and rawmouseposY <= 540 then
            surface.draw_filled_rect(1520, 0, 400, 100, 20, 146, 255, 30)
            surface.draw_outlined_rect(1520, 0, 400, 100, 40, 40, 255, 190)
            Cornereg = "TR"
        end

        if rawmouseposX <= 760 and rawmouseposY >= 540 then
            surface.draw_filled_rect(0, 980, 400, 100, 20, 146, 255, 30)
            surface.draw_outlined_rect(0, 980, 400, 100, 40, 40, 255, 190)
            Cornereg = "BL"
        end

        if rawmouseposX >= 1160 and rawmouseposY >= 540 then
            surface.draw_filled_rect(1520, 980, 400, 100, 20, 146, 255, 30)
            surface.draw_outlined_rect(1520, 980, 400, 100, 40, 40, 255, 190)
            Cornereg = "BR"
        end

        if rawmouseposX >= 760 and rawmouseposX <= 1160 and rawmouseposY >= 540 then
            surface.draw_filled_rect(760, 980, 400, 100, 20, 146, 255, 30)
            surface.draw_outlined_rect(760, 980, 400, 100, 40, 40, 255, 190)
            Cornereg = "BM"
        end

        if rawmouseposX >= 760 and rawmouseposX <= 1160 and rawmouseposY <= 540 then
            surface.draw_filled_rect(760, 0, 400, 100, 20, 146, 255, 30)
            surface.draw_outlined_rect(760, 0, 400, 100, 40, 40, 255, 190)
            Cornereg = "TM"
        end
        CornerReady = true
    end
end

local function Autocorner() 
    if dragging == false and ui_get(elements.Cornerswitch) then
        ui.set(elements.SizeSlider, "100")
        switch(Cornereg) {

            TL = function()
                SpotifyIndicX = 0
                SpotifyIndicY = 0
            end,

            TR = function()
                SpotifyIndicX = 1520
                SpotifyIndicY = 0
            end,

            BL = function()
                SpotifyIndicX = 0
                SpotifyIndicY = 980
            end,

            BR = function()
                SpotifyIndicX = 1520
                SpotifyIndicY = 980
            end,

            BM = function()
                SpotifyIndicX = 760
                SpotifyIndicY = 980
            end,

            TM = function()
                SpotifyIndicX = 760
                SpotifyIndicY = 0
            end,

            NONE = function()
                SpotifyIndicX = SpotifyIndicX
                SpotifyIndicY = SpotifyIndicY
            end
        }
    end
end

local function DrawNowPlaying()
    surface.draw_filled_rect(SpotifyIndicX, SpotifyIndicY, scaling.SpotifyScaleX, scaling.SpotifyScaleY, 22, 22, 22, 255)
end

function OnFrame()
    if ui_get(MainCheckbox) and Authed then
        DrawNowPlaying()

        local LClick = client.key_state(0x01)
        local mousepos = { ui.mouse_position() }
        rawmouseposX = mousepos[1]
        rawmouseposY = mousepos[2]
        mouseposX = mousepos[1] - SpotifyIndicX
        mouseposY = mousepos[2] - SpotifyIndicY

        if ui.is_menu_open() then
            Dragging()
            AdjustSize()
            SetAutocorner() 
            Autocorner()
            UpdateElements()
        end
    end
end

ShowMenuElements()
ui_set_callback(MainCheckbox, ShowMenuElements)
ui_set_callback(elements.Cornerswitch, ShowMenuElements)
ui_set_callback(elements.DebugInfo, ShowMenuElements)


client.set_event_callback("paint_ui", OnFrame)

client.set_event_callback('shutdown', function()
    database_write("previous_posX", SpotifyIndicX)
    database_write("previous_posY", SpotifyIndicY)
    database_write("previous_size", SelectedSize)
end)
