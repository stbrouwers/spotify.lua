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
local ui_new_combobox = ui.new_combobox
local ui_new_slider = ui.new_slider
local ui_new_color_picker = ui.new_color_picker
local sx, xy = client.screen_size()

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

SpotifyScaleX = 400
SpotifyScaleY = 100

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

local function GetToken() 
    local js = panorama.loadstring([[
        return {
          open_url: function(url){
            SteamOverlayAPI.OpenURL(url)
          }
        }
        ]])()
      js.open_url(AuthURL) 
end

function Auth() 
    apikey = CP()
        http.get("https://api.spotify.com/v1/me?&access_token=" .. apikey, function(success, response)
            ConnectionStatus = response.status
            if not success or response.status ~= 200 then
                ConnectionStatus = response.status
                AuthStatus = "Failed to Auth"
                Authed = false
                GetToken()
                ShowMenuElements()
                UpdateElements()
                return end
                spotidata = json.parse(response.body)
                UserName = spotidata.display_name
                Authed = true
                ShowMenuElements()
                UpdateElements()
            end)

end

function ResetAPI() 
    Authed = false
    ConnectionStatus = "NoConnection"
    GetToken()
    ShowMenuElements()
end

local last_update = client.unix_time()
function UpdateInf()
    http.get("https://api.spotify.com/v1/me/player?access_token=" .. apikey, function(success, response)
        if not success or response.status ~= 200 then
            AuthStatus = "Failed to Auth"
            return end
            CurrentDataSpotify = json.parse(response.body)
            if CurrentDataSpotify.is_playing then
                SongName = CurrentDataSpotify.item.name
                ArtistName = CurrentDataSpotify.item.artists[1].name
            else
                SongName = "Music paused"
                ArtistName = ""
            end
            SongLength = CurrentDataSpotify.item.duration_ms / 1000
            SongProgression = CurrentDataSpotify.progress_ms / 1000
        end)
end



local elements = {
    AuthButton = ui_new_button("MISC", "Miscellaneous", "Authorize", Auth),
    Connected = ui_new_label("MISC", "Miscellaneous", AuthStatus),
    IndicType = ui_new_combobox("MISC", "Miscellaneous", "Type", "Big", "Simplistic"),
    DebugInfo = ui_new_checkbox("MISC", "Miscellaneous", "Debug Info"),
    NowPlaying = ui_new_label("MISC", "Miscellaneous", "Now playing:" .. SongName),
    Artist = ui_new_label("MISC", "Miscellaneous", "By:" .. ArtistName),
    SongDuration = ui_new_label("MISC", "Miscellaneous", SongProgression .. SongLength),
    ResetKey = ui_new_button("MISC", "Miscellaneous", "Reset", ResetAPI),
    Cornerswitch = ui_new_checkbox("MISC", "Miscellaneous", "Stick to corner"),
    CustomColors = ui_new_checkbox("MISC", "Miscellaneous", "Custom colors"),
    LabelGradientColour = ui_new_label("MISC", "Miscellaneous", "Progress bar color"),
    GradientColour = ui.new_color_picker("MISC", "Miscellaneous", "progress bar Colourpicker", 0, 255, 0, 255),
    LabelBackgroundColor = ui_new_label("MISC", "Miscellaneous", "Background color"),
    BackgroundColor = ui_new_color_picker("MISC", "Miscellaneous", "Background colourpicker", 25, 25, 25, 255),
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
            ui_set_visible(elements.AuthButton, not Authed)
            ui_set_visible(elements.Cornerswitch, Authed and ui_get(elements.IndicType) == "Big")
            ui_set_visible(elements.Connected, Authed)
            ui_set_visible(elements.ResetKey, ConnectionStatus == 401)
            ui_set_visible(elements.NowPlaying, Authed)
            ui_set_visible(elements.Artist, Authed)
            ui_set_visible(elements.SongDuration, Authed)
            ui_set_visible(elements.IndicType, Authed)
            ui_set_visible(elements.GradientColour, Authed)
            ui_set_visible(elements.LabelGradientColour, Authed)
            ui_set_visible(elements.Connected, Authed)
            ui_set_visible(elements.DebugInfo, Authed and UserName == "stbrouwers" or UserName == "slxyx")
            ui_set_visible(elements.CustomColors, Authed)
            ui_set_visible(elements.GradientColour, ui_get(elements.CustomColors))
            ui_set_visible(elements.LabelGradientColour, ui_get(elements.CustomColors))
            ui_set_visible(elements.BackgroundColor, ui_get(elements.CustomColors) and ui_get(elements.IndicType) == "Big")
            ui_set_visible(elements.LabelBackgroundColor, ui_get(elements.CustomColors) and ui_get(elements.IndicType) == "Big")
            ui_set_visible(elements.NowPlaying, ui_get(elements.DebugInfo))
            ui_set_visible(elements.Artist, ui_get(elements.DebugInfo))
            ui_set_visible(elements.SongDuration, ui_get(elements.DebugInfo))   
    else
        ui_set_visible(elements.AuthButton, false)
        ui_set_visible(elements.Cornerswitch, false)
        ui_set_visible(elements.Connected, false)
        ui_set_visible(elements.ResetKey, false)
        ui_set_visible(elements.DebugInfo, false)
        ui_set_visible(elements.NowPlaying, false)
        ui_set_visible(elements.Artist, false)
        ui_set_visible(elements.SongDuration, false)
        ui_set_visible(elements.IndicType, false)
        ui_set_visible(elements.CustomColors, false)
        ui_set_visible(elements.GradientColour, false)
        ui_set_visible(elements.LabelGradientColour, false)
        ui_set_visible(elements.BackgroundColor, false)
        ui_set_visible(elements.LabelBackgroundColor, false)
    end
end

function UpdateElements()
    if Authed and ConnectionStatus == 200 then
        ui_set(elements.Connected, "> " .. "Connected to " .. UserName)
    elseif AuthStatus == "Failed to Auth" then
        ui_set(elements.Connected, "Please put your API key into your clipboard")
        ShowMenuElements()
    end

    ui_set(elements.NowPlaying, "Now playing: " .. SongName)
    ui_set(elements.Artist, "By: " .. ArtistName)
    ui_set(elements.SongDuration, SongProgression .. "/" .. SongLength)
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
        elseif SpotifyIndicX + SpotifyScaleX >= 1920.1 then
            SpotifyIndicX = 1920 - SpotifyScaleX
        else
            SpotifyIndicX = rawmouseposX - xdrag
        end

        if SpotifyIndicY <= -0.1 then
            SpotifyIndicY = 0
        elseif SpotifyIndicY + SpotifyScaleY >= 1080.1 then
            SpotifyIndicY = 1080 - SpotifyScaleY
        else    
            SpotifyIndicY = rawmouseposY - ydrag
        end

    end

    if intersect(SpotifyIndicX - startpos.DRegionx, SpotifyIndicY - startpos.DRegiony, SpotifyScaleX, SpotifyScaleY, false) and LClick then 
        dragging = true
        xdrag = rawmouseposX - SpotifyIndicX
        ydrag = rawmouseposY - SpotifyIndicY
    end
end



local function AdjustSize() 
    if not Authed then return end

    if SpotifyIndicX <= -0.1 then
        SpotifyIndicX = 0
    elseif SpotifyIndicX + SpotifyScaleX >= 1920.1 then
        SpotifyIndicX = 1920 - SpotifyScaleX
    end

    if SpotifyIndicY <= -0.1 then
        SpotifyIndicY = 0
    elseif SpotifyIndicY + SpotifyScaleY >= 1080.1 then
        SpotifyIndicY = 1080 - SpotifyScaleY
    end

    titlex, titley = surface.get_text_size(TitleFont, SongName)+50
    artistx, artisty = surface.get_text_size(ArtistFont, ArtistName)+50
    if titlex > artistx then
        textsizeing = titlex
    else
        textsizeing = artistx
    end

    if textsizeing <= SpotifyIndicX then
        textsizeing = SpotifyIndicX
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
            if dragging == false and not ui_get(elements.Cornerswitch) then
                surface.draw_text(SpotifyIndicX+20, SpotifyIndicY+22, 255, 255, 255, 255, TitleFont, SongName)
                surface.draw_text(SpotifyIndicX+20, SpotifyIndicY+52, 159, 159, 159, 255, ArtistFont, ArtistName)
            end
        
            if dragging == true and not ui_get(elements.Cornerswitch) then
                surface.draw_text(SpotifyIndicX+20, SpotifyIndicY+22, 255, 255, 255, 255, TitleFont, SongName)
                surface.draw_text(SpotifyIndicX+20, SpotifyIndicY+52, 159, 159, 159, 255, ArtistFont, ArtistName)
            end
        
            if dragging == false and ui_get(elements.Cornerswitch) then
                switch(Cornereg) {
        
                    TL = function()
                        SpotifyIndicX = 0
                        SpotifyIndicY = 0
                        surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+22, 255, 255, 255, 255, TitleFont, SongName)
                        surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+52, 159, 159, 159, 255, ArtistFont, ArtistName)
                    end,
        
                    TR = function()
                        SpotifyIndicX = 1520
                        SpotifyIndicY = 0
                        surface.draw_text(SpotifyIndicX+SpotifyScaleX-titlex, SpotifyIndicY+22, 255, 255, 255, 255, TitleFont, SongName)
                        surface.draw_text(SpotifyIndicX+SpotifyScaleX-artistx, SpotifyIndicY+52, 159, 159, 159, 255, ArtistFont, ArtistName)
                    end,
        
                    BL = function()
                        SpotifyIndicX = 0
                        SpotifyIndicY = 980
                        surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+22, 255, 255, 255, 255, TitleFont, SongName)
                        surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+52, 159, 159, 159, 255, ArtistFont, ArtistName)
                    end,
        
                    BR = function()
                        SpotifyIndicX = 1520
                        SpotifyIndicY = 980
                        surface.draw_text(SpotifyIndicX+SpotifyScaleX-titlex-10, SpotifyIndicY+22, 255, 255, 255, 255, TitleFont, SongName)
                        surface.draw_text(SpotifyIndicX+SpotifyScaleX-artistx-10, SpotifyIndicY+52, 159, 159, 159, 255, ArtistFont, ArtistName)
                    end,
        
                    BM = function()
                        SpotifyIndicX = 760
                        SpotifyIndicY = 980
                        surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+22, 255, 255, 255, 255, TitleFont, SongName)
                        surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+52, 159, 159, 159, 255, ArtistFont, ArtistName)
                    end,
        
                    TM = function()
                        SpotifyIndicX = 760
                        SpotifyIndicY = 0
                        surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+22, 255, 255, 255, 255, TitleFont, SongName)
                        surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+52, 159, 159, 159, 255, ArtistFont, ArtistName)
                    end,
        
                    NONE = function()
                        SpotifyIndicX = SpotifyIndicX
                        SpotifyIndicY = SpotifyIndicY
                        surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+22, 255, 255, 255, 255, TitleFont, SongName)
                        surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+52, 159, 159, 159, 255, ArtistFont, ArtistName)
                    end
                }
            end
        end
        
        local function DrawNowPlaying()
            r, g, b, a = ui.get(elements.GradientColour)
            br, bg, bb, ba = ui.get(elements.BackgroundColor)
            if CurrentDataSpotify == nil then return end
            switch(ui_get(elements.IndicType)) {

            Big = function()

            SpotifyScaleX = 400
            SpotifyScaleY = 100
            
            surface.draw_filled_rect(SpotifyIndicX, SpotifyIndicY, SpotifyScaleX, SpotifyScaleY, br, bg, bb, ba)
            surface.draw_filled_rect(SpotifyIndicX, SpotifyIndicY+90, CurrentDataSpotify.progress_ms/CurrentDataSpotify.item.duration_ms*400, 10, r, g, b, a)
            end,

            Simplistic = function()
                
                SpotifyScaleX = 150
                SpotifyScaleY = 30
                songartist = renderer.measure_text("b", "Now Playing: "..CurrentDataSpotify.item.name.." by "..CurrentDataSpotify.item.artists[1].name)+10
                usrnm = renderer.measure_text("b", "Connected to: "..spotidata.display_name)+10
                if CurrentDataSpotify.is_playing and songartist > usrnm then
                    textmeasurement = renderer.measure_text("b", "Now Playing: "..CurrentDataSpotify.item.name.." by "..CurrentDataSpotify.item.artists[1].name)+10
                elseif CurrentDataSpotify.is_playing and songartist < usrnm then
                    textmeasurement = renderer.measure_text("b", "Connected to: "..spotidata.display_name)+10
                elseif not CurrentDataSpotify.is_playing then
                    textmeasurement = renderer.measure_text("b", "Connected to: "..spotidata.display_name)+10
                end
                renderer.gradient(SpotifyIndicX, SpotifyIndicY, textmeasurement, 32, 22, 22, 22, 255, 22, 22, 22, 10, true)
                renderer.rectangle(SpotifyIndicX, SpotifyIndicY, 2, 32, r, g, b, a)
                renderer.gradient(SpotifyIndicX, SpotifyIndicY, CurrentDataSpotify.progress_ms/CurrentDataSpotify.item.duration_ms*textmeasurement, 2, r, g, b, a, r, g, b, 0, true)
                renderer.gradient(SpotifyIndicX, SpotifyIndicY+30, CurrentDataSpotify.progress_ms/CurrentDataSpotify.item.duration_ms*textmeasurement, 2, r, g, b, a, r, g, b, 0, true)
                renderer.text(SpotifyIndicX+5, SpotifyIndicY+5, 255, 255, 255, 255, "b", 0, "Connected to: "..spotidata.display_name)
                if CurrentDataSpotify.is_playing then
                    renderer.text(SpotifyIndicX+5, SpotifyIndicY+15, 255, 255, 255, 255, "b", 0, "Now Playing: "..CurrentDataSpotify.item.name.." by "..CurrentDataSpotify.item.artists[1].name)
                else
                    renderer.text(SpotifyIndicX+5, SpotifyIndicY+15, 255, 255, 255, 255, "b", 0, "Paused")
                end
            end
        }
    end

function OnFrame()
    if not apikey then return end
    if client.unix_time() > last_update + 1 then
        UpdateInf()
        last_update = client.unix_time()
    end
    if ui_get(MainCheckbox) and Authed then
        AdjustSize()
        DrawNowPlaying()
        if ui_get(elements.IndicType) == "Big" then Autocorner() end
        ShowMenuElements()
        
        
        if ui.is_menu_open() then
            if ui_get(elements.IndicType) == "Big" then SetAutocorner() end
            Dragging()
            UpdateElements()
        end

        local LClick = client.key_state(0x01)
        local mousepos = { ui.mouse_position() }
        rawmouseposX = mousepos[1]
        rawmouseposY = mousepos[2]
        mouseposX = mousepos[1] - SpotifyIndicX
        mouseposY = mousepos[2] - SpotifyIndicY


    end
end

ShowMenuElements()
ui_set_callback(MainCheckbox, ShowMenuElements)
ui_set_callback(elements.Cornerswitch, ShowMenuElements)
ui_set_callback(elements.DebugInfo, ShowMenuElements)
ui_set_callback(elements.CustomColors, ShowMenuElements)



client.set_event_callback("paint_ui", OnFrame)

client.set_event_callback('shutdown', function()
    database_write("previous_posX", SpotifyIndicX)
    database_write("previous_posY", SpotifyIndicY)
    database_write("previous_size", SelectedSize)
end)
