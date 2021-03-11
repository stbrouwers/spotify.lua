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
UpdateCount = 0


AuthStatus = "false"
UserName = "-"
SongName = "-"
ArtistName = "-"
SongProgression = "-"
SongLength = "-"
Cornereg = "NONE"
AuthURL = "https://developer.spotify.com/console/get-users-currently-playing-track/"

if database_read("previous_posX") == nil then
    database_write("previous_posX", SpotifyIndicX)
    database_write("previous_posY", SpotifyIndicY)
else
    if database_read("previous_posX") >= 1920 then
        SpotifyIndicX = 0
        SpotifyIndicY = 1020
    end
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
    if apikey == nil then GetToken() return end
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
    IndicType = ui_new_combobox("MISC", "Miscellaneous", "Type", "Spotify", "Minimal"),
    DebugInfo = ui_new_checkbox("MISC", "Miscellaneous", "Debug Info"),
    NowPlaying = ui_new_label("MISC", "Miscellaneous", "Now playing:" .. SongName),
    Artist = ui_new_label("MISC", "Miscellaneous", "By:" .. ArtistName),
    SongDuration = ui_new_label("MISC", "Miscellaneous", SongProgression .. SongLength),
    UpdateRate = ui_new_slider("MISC", "Miscellaneous", "UpdateRate", 1, 5, 1, true, "s"),
    SessionUpdates = ui_new_label("MISC", "Miscellaneous", "Total updates this session: " .. UpdateCount),
    ResetKey = ui_new_button("MISC", "Miscellaneous", "Reset", ResetAPI),
    Cornerswitch = ui_new_checkbox("MISC", "Miscellaneous", "Stick to corner"),
    CustomColors = ui_new_checkbox("MISC", "Miscellaneous", "Custom colors"),
    ProgressGradientSwitch = ui_new_checkbox("MISC", "Miscellaneous", "Gradient progress bar"),
    LabelProgressGradient1 = ui_new_label("MISC", "Miscellaneous", "Progress gradient 1"),
    ProgressGradient1 = ui_new_color_picker("MISC", "Miscellaneous", "Background colourpicker", 0, 255, 0, 255),
    LabelProgressGradient2 = ui_new_label("MISC", "Miscellaneous", "Progress gradient 2"),
    ProgressGradient2 = ui_new_color_picker("MISC", "Miscellaneous", "progressbar gradient 2", 0, 255, 0, 255),
    LabelGradientColour = ui_new_label("MISC", "Miscellaneous", "Progress bar color"),
    GradientColour = ui.new_color_picker("MISC", "Miscellaneous", "progress bar Colourpicker", 0, 255, 0, 255),
    LabelBackgroundColor = ui_new_label("MISC", "Miscellaneous", "Background color"),
    BackgroundColor = ui_new_color_picker("MISC", "Miscellaneous", "Background colourpicker", 25, 25, 25, 255),
    LabelTextColorPrimary = ui_new_label("MISC", "Miscellaneous", "Primary text color"),
    TextColorPrimary = ui_new_color_picker("MISC", "Miscellaneous", "Primary text clr", 255, 255, 255, 255),
    LabelTextColorSecondary = ui_new_label("MISC", "Miscellaneous", "Secondary text color"),
    TextColorSecondary = ui_new_color_picker("MISC", "Miscellaneous", "Secondary text clr", 159, 159, 159, 255),
    LabelBackgroundColorGradient1 = ui_new_label("MISC", "Miscellaneous", "Gradient 1"),
    BackgroundColorGradient1 = ui_new_color_picker("MISC", "Miscellaneous", "Background Gradient colourpicker1", 25, 25, 25, 50),
    LabelBackgroundColorGradient2 = ui_new_label("MISC", "Miscellaneous", "Gradient 2"),
    BackgroundColorGradient2 = ui_new_color_picker("MISC", "Miscellaneous", "Background Gradient colourpicker2", 25, 25, 25, 255),
    Clantag = ui_new_checkbox("MISC", "Miscellaneous", "Clantag"),
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
            ui_set_visible(elements.Connected, true)
            ui_set_visible(elements.ResetKey, ConnectionStatus == 401)
            ui_set_visible(elements.NowPlaying, Authed)
            ui_set_visible(elements.Artist, Authed)
            ui_set_visible(elements.SongDuration, Authed)
            ui_set_visible(elements.IndicType, Authed)
            ui_set_visible(elements.GradientColour, Authed)
            ui_set_visible(elements.LabelGradientColour, Authed)
            ui_set_visible(elements.Connected, Authed)
            ui_set_visible(elements.DebugInfo, Authed and UserName == "stbrouwers" or UserName == "slxyx")
            ui_set_visible(elements.UpdateRate, Authed and ui_get(elements.DebugInfo))
            ui_set_visible(elements.SessionUpdates, Authed and ui_get(elements.DebugInfo))
            ui_set_visible(elements.CustomColors, Authed)
            ui_set_visible(elements.Clantag, Authed)
            ui_set_visible(elements.ProgressGradientSwitch, ui_get(elements.CustomColors) and ui_get(elements.IndicType) == "Big")
            ui_set_visible(elements.LabelProgressGradient1, ui_get(elements.ProgressGradientSwitch))
            ui_set_visible(elements.ProgressGradient1, ui_get(elements.ProgressGradientSwitch))
            ui_set_visible(elements.LabelProgressGradient2, ui_get(elements.ProgressGradientSwitch))
            ui_set_visible(elements.ProgressGradient2, ui_get(elements.ProgressGradientSwitch))
            ui_set_visible(elements.GradientColour, ui_get(elements.CustomColors) and not ui_get(elements.ProgressGradientSwitch))
            ui_set_visible(elements.LabelGradientColour, ui_get(elements.CustomColors) and not ui_get(elements.ProgressGradientSwitch))
            ui_set_visible(elements.BackgroundColor, ui_get(elements.CustomColors) and ui_get(elements.IndicType) == "Big")
            ui_set_visible(elements.LabelBackgroundColor, ui_get(elements.CustomColors) and ui_get(elements.IndicType) == "Big")
            ui_set_visible(elements.LabelTextColorPrimary, ui_get(elements.CustomColors) and ui_get(elements.IndicType) == "Big")
            ui_set_visible(elements.TextColorPrimary, ui_get(elements.CustomColors) and ui_get(elements.IndicType) == "Big")
            ui_set_visible(elements.LabelTextColorSecondary, ui_get(elements.CustomColors) and ui_get(elements.IndicType) == "Big")
            ui_set_visible(elements.TextColorSecondary, ui_get(elements.CustomColors) and ui_get(elements.IndicType) == "Big")
            ui_set_visible(elements.BackgroundColorGradient1, ui_get(elements.CustomColors) and ui_get(elements.IndicType) == "Big")
            ui_set_visible(elements.LabelBackgroundColorGradient1, ui_get(elements.CustomColors) and ui_get(elements.IndicType) == "Big")
            ui_set_visible(elements.BackgroundColorGradient2, ui_get(elements.CustomColors) and ui_get(elements.IndicType) == "Big")
            ui_set_visible(elements.LabelBackgroundColorGradient2, ui_get(elements.CustomColors) and ui_get(elements.IndicType) == "Big")
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
        ui_set_visible(elements.UpdateRate, false)
        ui_set_visible(elements.SessionUpdates, false)
        ui_set_visible(elements.SongDuration, false)
        ui_set_visible(elements.IndicType, false)
        ui_set_visible(elements.CustomColors, false)
        ui_set_visible(elements.ProgressGradientSwitch, false)
        ui_set_visible(elements.LabelProgressGradient1, false)
        ui_set_visible(elements.ProgressGradient1, false)
        ui_set_visible(elements.LabelProgressGradient2, false)
        ui_set_visible(elements.ProgressGradient2, false)
        ui_set_visible(elements.GradientColour, false)
        ui_set_visible(elements.BackgroundColorGradient1, false)
        ui_set_visible(elements.LabelBackgroundColorGradient1, false)
        ui_set_visible(elements.BackgroundColorGradient2, false)
        ui_set_visible(elements.LabelBackgroundColorGradient2, false)
        ui_set_visible(elements.LabelTextColorPrimary, false)
        ui_set_visible(elements.TextColorPrimary, false)
        ui_set_visible(elements.LabelTextColorSecondary, false)
        ui_set_visible(elements.TextColorSecondary, false)
        ui_set_visible(elements.LabelGradientColour, false)
        ui_set_visible(elements.BackgroundColor, false)
        ui_set_visible(elements.LabelBackgroundColor, false)
        ui_set_visible(elements.Clantag, false)
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
        adaptivesize = titlex
    else
        adaptivesize = artistx
    end

    if adaptivesize <= 400 then
        adaptivesize = 400
    end
    
end

function SetAutocorner()
    if dragging == true and ui_get(elements.Cornerswitch) then
        if rawmouseposX <= 760 and rawmouseposY <= 540 then
            surface.draw_filled_rect(0, 0, adaptivesize, 100, 20, 146, 255, 30)
            surface.draw_outlined_rect(0, 0, adaptivesize, 100, 40, 40, 255, 190)
                    
            Cornereg = "TL"
        end
        
        if rawmouseposX >= 1160 and rawmouseposY <= 540 then
            surface.draw_filled_rect(1520, 0, adaptivesize, 100, 20, 146, 255, 30)
            surface.draw_outlined_rect(1520, 0, adaptivesize, 100, 40, 40, 255, 190)
            Cornereg = "TR"
        end
        
        if rawmouseposX <= 760 and rawmouseposY >= 540 then
            surface.draw_filled_rect(0, 980, adaptivesize, 100, 20, 146, 255, 30)
            surface.draw_outlined_rect(0, 980, adaptivesize, 100, 40, 40, 255, 190)
            Cornereg = "BL"
        end
        
        if rawmouseposX >= 1160 and rawmouseposY >= 540 then
            surface.draw_filled_rect(1520, 980, adaptivesize, 100, 20, 146, 255, 30)
            surface.draw_outlined_rect(1520, 980, adaptivesize, 100, 40, 40, 255, 190)
            Cornereg = "BR"
        end
        
        if rawmouseposX >= 760 and rawmouseposX <= 1160 and rawmouseposY >= 540 then
            surface.draw_filled_rect(760, 980, adaptivesize, 100, 20, 146, 255, 30)
            surface.draw_outlined_rect(760, 980, adaptivesize, 100, 40, 40, 255, 190)
            Cornereg = "BM"
        end
        
        if rawmouseposX >= 760 and rawmouseposX <= 1160 and rawmouseposY <= 540 then
            surface.draw_filled_rect(760, 0, adaptivesize, 100, 20, 146, 255, 30)
            surface.draw_outlined_rect(760, 0, adaptivesize, 100, 40, 40, 255, 190)
            Cornereg = "TM"
        end
            CornerReady = true
    end
end 
        
local function Autocorner() 
    gr1, gg1, gb1, ga1 = ui.get(elements.BackgroundColorGradient1)
    gr2, gg2, gb2, ga2 = ui.get(elements.BackgroundColorGradient2)
    tr1, tg1, tb1, ta1 = ui.get(elements.TextColorPrimary)
    tr2, tg2, tb2, ta2 = ui.get(elements.TextColorSecondary)

    if dragging == false and not ui_get(elements.Cornerswitch) then
        surface.draw_filled_gradient_rect(SpotifyIndicX, SpotifyIndicY, adaptivesize, 95, gr1, gg1, gb1, ga1, gr2, gg2, gb2, ga2, true)
        surface.draw_text(SpotifyIndicX+20, SpotifyIndicY+22, tr1, tg1, tb1, ta1, TitleFont, SongName)
        surface.draw_text(SpotifyIndicX+20, SpotifyIndicY+52, tr2, tg2, tb2, ta2, ArtistFont, ArtistName)
    end
        
    if dragging == true and not ui_get(elements.Cornerswitch) then
        surface.draw_filled_gradient_rect(SpotifyIndicX, SpotifyIndicY, adaptivesize, 95, gr1, gg1, gb1, ga1, gr2, gg2, gb2, ga2, true)
        surface.draw_text(SpotifyIndicX+20, SpotifyIndicY+22, tr1, tg1, tb1, ta1, TitleFont, SongName)
        surface.draw_text(SpotifyIndicX+20, SpotifyIndicY+52, tr2, tg2, tb2, ta2, ArtistFont, ArtistName)
    end
        
    if dragging == false and ui_get(elements.Cornerswitch) then
        switch(Cornereg) {
        
            TL = function()
                SpotifyIndicX = 0
                SpotifyIndicY = 0
                surface.draw_filled_gradient_rect(SpotifyIndicX, SpotifyIndicY, adaptivesize, 95, gr1, gg1, gb1, ga1, gr2, gg2, gb2, ga2, true)
                surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+22, tr1, tg1, tb1, ta1, TitleFont, SongName)
                surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+52, tr2, tg2, tb2, ta2, ArtistFont, ArtistName)
            end,
        
            TR = function()
                SpotifyIndicX = sx-adaptivesize
                SpotifyIndicY = 0
                surface.draw_filled_gradient_rect(SpotifyIndicX, SpotifyIndicY, adaptivesize, 95, gr1, gg1, gb1, ga1, gr2, gg2, gb2, ga2, true)
                surface.draw_text(sx-titlex+10, SpotifyIndicY+22, tr1, tg1, tb1, ta1, TitleFont, SongName)
                surface.draw_text(sx-artistx+10, SpotifyIndicY+52, tr2, tg2, tb2, ta2, ArtistFont, ArtistName)
            end,
        
            BL = function()
                SpotifyIndicX = 0
                SpotifyIndicY = 980
                surface.draw_filled_gradient_rect(SpotifyIndicX, SpotifyIndicY, adaptivesize, 95, gr1, gg1, gb1, ga1, gr2, gg2, gb2, ga2, true)
                surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+22, tr1, tg1, tb1, ta1, TitleFont, SongName)
                surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+52, tr2, tg2, tb2, ta2, ArtistFont, ArtistName)
            end,
        
            BR = function()
                SpotifyIndicX = sx-adaptivesize
                SpotifyIndicY = 980
                surface.draw_filled_gradient_rect(SpotifyIndicX, SpotifyIndicY, adaptivesize, 95, gr1, gg1, gb1, ga1, gr2, gg2, gb2, ga2, true)
                surface.draw_text(sx-titlex+10, SpotifyIndicY+22, tr1, tg1, tb1, ta1, TitleFont, SongName)
                surface.draw_text(sx-artistx+10, SpotifyIndicY+52, tr2, tg2, tb2, ta2, ArtistFont, ArtistName)
            end,
        
            BM = function()
                SpotifyIndicX = 760
                SpotifyIndicY = 980
                surface.draw_filled_gradient_rect(SpotifyIndicX, SpotifyIndicY, adaptivesize, 95, gr1, gg1, gb1, ga1, gr2, gg2, gb2, ga2, true)
                surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+22, tr1, tg1, tb1, ta1, TitleFont, SongName)
                surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+52, tr2, tg2, tb2, ta2, ArtistFont, ArtistName)
            end,
        
            TM = function()
                SpotifyIndicX = 760
                SpotifyIndicY = 0
                surface.draw_filled_gradient_rect(SpotifyIndicX, SpotifyIndicY, adaptivesize, 95, gr1, gg1, gb1, ga1, gr2, gg2, gb2, ga2, true)
                surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+22, tr1, tg1, tb1, ta1, TitleFont, SongName)
                surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+52, tr2, tg2, tb2, ta2, ArtistFont, ArtistName)
            end,
        
            NONE = function()
                SpotifyIndicX = SpotifyIndicX
                SpotifyIndicY = SpotifyIndicY
                surface.draw_filled_gradient_rect(SpotifyIndicX, SpotifyIndicY, adaptivesize, 95, gr1, gg1, gb1, ga1, gr2, gg2, gb2, ga2, true)
                surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+22, tr1, tg1, tb1, ta1, TitleFont, SongName)
                surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+52, tr2, tg2, tb2, ta2, ArtistFont, ArtistName)
            end
        }
    end
end
        
local function DrawNowPlaying()
    r, g, b, a = ui.get(elements.GradientColour)
    br, bg, bb, ba = ui.get(elements.BackgroundColor)
    gr1, gg1, gb1, ga1 = ui.get(elements.ProgressGradient1)
    gr2, gg2, gb2, ga2 = ui.get(elements.ProgressGradient2)

    if CurrentDataSpotify == nil then return end

    switch(ui_get(elements.IndicType)) {

        Spotify = function()
            SpotifyScaleX = 400
            SpotifyScaleY = 100
            surface.draw_filled_rect(SpotifyIndicX, SpotifyIndicY, adaptivesize, SpotifyScaleY, br, bg, bb, ba)
            if not ui_get(elements.ProgressGradientSwitch) then
                surface.draw_filled_rect(SpotifyIndicX, SpotifyIndicY+95, CurrentDataSpotify.progress_ms/CurrentDataSpotify.item.duration_ms*adaptivesize, 5, r, g, b, a)
            else
                surface.draw_filled_gradient_rect(SpotifyIndicX, SpotifyIndicY+95, CurrentDataSpotify.progress_ms/CurrentDataSpotify.item.duration_ms*adaptivesize, 5, gr1, gg1, gb1, ga1, gr2, gg2, gb2, ga2, true)
            end
        end,

        Minimal = function()
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

local duration = 70
local clantag_prev
function SpotifyClantag()
    if CurrentDataSpotify == nil then return end
    clantags = {"Listening to:", CurrentDataSpotify.item.name, "by", CurrentDataSpotify.item.artists[1].name, ""}
    local cur = math.floor(globals.tickcount() / duration) % #clantags
    clantag = clantags[cur+1]
    if clantag ~= clantag_prev then
        clantag_prev = clantag
        client.set_clan_tag(clantag)
    end
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
        if ui_get(elements.IndicType) == "Spotify" then Autocorner() end
        ShowMenuElements()
        if ui_get(elements.Clantag) then SpotifyClantag() end
        
        
        if ui.is_menu_open() then
            if ui_get(elements.IndicType) == "Spotify" then SetAutocorner() end
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
