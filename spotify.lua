local surface = require "gamesense/surface"
local http = require "gamesense/http"
local images = require "gamesense/images"
local ffi = require "ffi"

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
local ui_new_hotkey = ui.new_hotkey
local last_update = client.unix_time()
local last_update_controls = client.unix_time()
local sx, sy = client.screen_size()
local TitleFont = surface.create_font("GothamBookItalic", sy/41.54, 900, 0x010)
local ArtistFont = surface.create_font("GothamBookItalic", sy/63.53, 600, 0x010)

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
ControlCheck = false

limitval = 0
indicxcomp = -0.1
SpotifyScaleX = sx/4.8
SpotifyScaleY = sy/10.8
ArtScaleX, ArtScaleY = SpotifyScaleY
UpdateCount = 0
ClickSpree = 0
ClickSpreeTime = 1

AuthStatus = "> Not connected"
apikey = ""
deviceid = ""
UserName = "-"
SongName = "-"
ArtistName = "-"
SongProgression = "-"
SongLength = "-"
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

switch = function(check)                                        
    return function(cases)
        if type(cases[check]) == "function" then
            return cases[check]()
        elseif type(cases["default"] == "function") then
            return cases["default"]()
        end
    end
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
                Authed = false
                AuthStatus = "FAILED"
                GetToken()
                ShowMenuElements()
                UpdateElements()
                return end
                UpdateCount = UpdateCount + 1
                spotidata = json.parse(response.body)
                UserName = spotidata.display_name
                Authed = true
                AuthStatus = "SUCCESS"
                ShowMenuElements()
                UpdateElements()
            end)
end


function DAuth() 
        if not ConnectionStatus then return end
        if ConnectionStatus == 202 then
            AuthStatus = "SUCCESS"
        end

        if ConnectionStatus == 403 then
            Authed = false
            AuthStatus = "FORBIDDEN"
        end

        if ConnectionStatus == 429 then
            Authed = false
            AuthStatus = "RATE"
        end

        if ConnectionStatus == 503 then
            Authed = false
            AuthStatus = "APIFAIL"
        end

    ShowMenuElements()
    UpdateElements()
end

function ResetAPI() 
    Authed = false
    ConnectionStatus = "NoConnection"
    GetToken()
    ShowMenuElements()
end

function UpdateInf()
    DAuth() 
    http.get("https://api.spotify.com/v1/me/player?access_token=" .. apikey, function(success, response)
        if not success or response.status ~= 200 then
            AuthStatus = "TOKEN"
            Authed = false
            return 
        end
            CurrentDataSpotify = json.parse(response.body)
            deviceid = CurrentDataSpotify.device.id
            if CurrentDataSpotify.is_playing and CurrentDataSpotify.currently_playing_type == "episode" then
                SongName = "Podcast"
                ArtistName = ""
            elseif CurrentDataSpotify.is_playing then
                SongName = CurrentDataSpotify.item.name
                ArtistName = CurrentDataSpotify.item.artists[1].name
            else
                SongName = "Music paused"
                ArtistName = ""
            end
            SongLength = CurrentDataSpotify.item.duration_ms / 1000
            SongProgression = CurrentDataSpotify.progress_ms / 1000
            ThumbnailUrl = CurrentDataSpotify.item.album.images[1].url
            http.get(ThumbnailUrl, function(success, response)
                if not success or response.status ~= 200 then
                  return
                end
            Thumbnail = images.load_jpg(response.body)
            client.log(Thumbnail)
            end)
        end)
end

function PlayPause()

    local options = {
        headers = {
            ["Accept"] = "application/json",
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. apikey,
            ["Content-length"] = 0
        }
    }
    
    if CurrentDataSpotify.is_playing then

        http.put("https://api.spotify.com/v1/me/player/pause?device_id=" .. deviceid, options, function(s, r)
            print(r.status .. " " .. r.status_message)
            print(r.body)
            UpdateCount = UpdateCount + 1
            
        end)
    else
        http.put("https://api.spotify.com/v1/me/player/play?device_id=" .. deviceid, options, function(s, r)
            print(r.status .. " " .. r.status_message)
            print(r.body)
            UpdateCount = UpdateCount + 1
        end)   
    end
    UpdateInf()
end

function NextTrack()

    local options = {
        headers = {
            ["Accept"] = "application/json",
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. apikey,
            ["Content-length"] = 0
        }
    }

    http.post("https://api.spotify.com/v1/me/player/next?device_id" .. deviceid, options, function(s, r)
        print(r.status .. " " .. r.status_message)
        print(r.body)
        UpdateCount = UpdateCount + 1
    end)   
    UpdateInf()
end

function PreviousTrack()

    local options = {
        headers = {
            ["Accept"] = "application/json",
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. apikey,
            ["Content-length"] = 0
        }
    }

    http.post("https://api.spotify.com/v1/me/player/previous?device_id" .. deviceid, options, function(s, r)
        print(r.status .. " " .. r.status_message)
        print(r.body)
        UpdateCount = UpdateCount + 1
    end)   
    UpdateInf()
end

local elements = {
    Connected = ui_new_label("MISC", "Miscellaneous", AuthStatus),
    AuthButton = ui_new_button("MISC", "Miscellaneous", "Authorize", Auth),
    IndicType = ui_new_combobox("MISC", "Miscellaneous", "Type", "Spotify", "Minimal"),
    MinimumWidth = ui_new_slider("MISC", "Miscellaneous", "Minimum box width", 199, 600, 400, true, "px", 1, { [199] = "Auto"}),
    DebugInfo = ui_new_checkbox("MISC", "Miscellaneous", "Debug info"),
    NowPlaying = ui_new_label("MISC", "Miscellaneous", "Now playing:" .. SongName),
    Artist = ui_new_label("MISC", "Miscellaneous", "By:" .. ArtistName),
    SongDuration = ui_new_label("MISC", "Miscellaneous", SongProgression .. SongLength),
    UpdateRate = ui_new_slider("MISC", "Miscellaneous", "UpdateRate", 0.5, 5, 1, true, "s"),
    RateLimitWarning = ui_new_label("MISC", "Miscellaneous", "WARNING: using <1s updaterate might get you ratelimited"),
    SessionUpdates = ui_new_label("MISC", "Miscellaneous", "Total updates this session: " .. UpdateCount),
    ResetKey = ui_new_button("MISC", "Miscellaneous", "Reset", ResetAPI),
    ArtButton = ui_new_checkbox("MISC", "Miscellaneous", "Cover art"),
    CustomLayoutType = ui_new_combobox("MISC", "Miscellaneous", "Type", "Left", "Right"),
    CustomColors = ui_new_checkbox("MISC", "Miscellaneous", "Custom colors"),
    ProgressGradientSwitch = ui_new_checkbox("MISC", "Miscellaneous", "Gradient progress bar"),
    BackgroundGradientSwitch = ui_new_checkbox("MISC", "Miscellaneous", "Gradient background"),
    LabelProgressGradient1 = ui_new_label("MISC", "Miscellaneous", "  - Progress gradient L"),
    ProgressGradient1 = ui_new_color_picker("MISC", "Miscellaneous", "progressbar gradient 1", 0, 255, 0, 255),
    LabelProgressGradient2 = ui_new_label("MISC", "Miscellaneous", "  - Progress gradient R"),
    ProgressGradient2 = ui_new_color_picker("MISC", "Miscellaneous", "progressbar gradient 2", 0, 255, 0, 255),
    LabelGradientColour = ui_new_label("MISC", "Miscellaneous", "  - Progress bar color"),
    GradientColour = ui.new_color_picker("MISC", "Miscellaneous", "progress bar Colourpicker", 0, 255, 0, 255),
    LabelBackgroundColor = ui_new_label("MISC", "Miscellaneous", "  - Background color"),
    BackgroundColour = ui_new_color_picker("MISC", "Miscellaneous", "Background colourrpicker", 25, 25, 25, 255),
    LabelBackgroundColorGradient1 = ui_new_label("MISC", "Miscellaneous", "  - Background gradient L"),
    BackgroundColorGradient1 = ui_new_color_picker("MISC", "Miscellaneous", "Background Gradient colourpicker1", 25, 25, 25, 50),
    LabelBackgroundColorGradient2 = ui_new_label("MISC", "Miscellaneous", "  - Background gradient R"),
    BackgroundColorGradient2 = ui_new_color_picker("MISC", "Miscellaneous", "Background Gradient colourpicker2", 25, 25, 25, 255),
    LabelTextColorPrimary = ui_new_label("MISC", "Miscellaneous", "  - Primary text color"),
    TextColorPrimary = ui_new_color_picker("MISC", "Miscellaneous", "Primary text clr", 255, 255, 255, 255),
    LabelTextColorSecondary = ui_new_label("MISC", "Miscellaneous", "  - Secondary text color"),
    TextColorSecondary = ui_new_color_picker("MISC", "Miscellaneous", "Secondary text clr", 159, 159, 159, 255),
    ControlSwitch = ui_new_checkbox("MISC", "Miscellaneous", "Controls"),
    SmartControlSwitch = ui_new_checkbox("MISC", "Miscellaneous", "Smart controls"),
    SmartControls = ui_new_hotkey("MISC", "Miscellaneous", "  - Smart Controls", true),
    PlayPause = ui_new_hotkey("MISC", "Miscellaneous", "  - Play/Pause", false),
    SkipSong = ui_new_hotkey("MISC", "Miscellaneous", "  - Skip song", false),
    PreviousSong = ui_new_hotkey("MISC", "Miscellaneous", "  - Previous song", false),
    Clantag = ui_new_checkbox("MISC", "Miscellaneous", "Now playing clantag")
}

ui_set(elements.CustomLayoutType, "Left")

local startpos = {
    DRegionx = 0, DRegiony = 0,
}

local endpos = {
    DRegionx = SpotifyScaleX, DRegiony = SpotifyScaleY,
}

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
    if ui_get(MainCheckbox) and Authed then
        ui_set_visible(elements.Connected, true)
        ui_set_visible(elements.AuthButton, false)
        ui_set_visible(elements.ResetKey, false)
        ui_set_visible(elements.NowPlaying, true)
        ui_set_visible(elements.Artist, true)
        ui_set_visible(elements.SongDuration, true)
        ui_set_visible(elements.IndicType, true)
        ui_set_visible(elements.GradientColour, true)
        ui_set_visible(elements.LabelGradientColour, true)
        ui_set_visible(elements.CustomColors, true)
        ui_set_visible(elements.ControlSwitch, true)
        
        if ui_get(elements.IndicType) == "Spotify" then
            ui_set_visible(elements.ArtButton, true)
            ui_set_visible(elements.MinimumWidth, true)
            ui_set_visible(elements.CustomLayoutType, ui_get(elements.ArtButton))


            if ui_get(elements.CustomColors) then
                ui_set_visible(elements.ProgressGradientSwitch, true)
                ui_set_visible(elements.BackgroundGradientSwitch, true)
                ui_set_visible(elements.LabelTextColorPrimary, true)
                ui_set_visible(elements.TextColorPrimary, true)
                ui_set_visible(elements.LabelTextColorSecondary, true)
                ui_set_visible(elements.TextColorSecondary, true)
                ui_set_visible(elements.BackgroundColour, true)
                ui_set_visible(elements.LabelBackgroundColor, true)

                if ui_get(elements.ProgressGradientSwitch) then
                    ui_set_visible(elements.LabelProgressGradient1, true)
                    ui_set_visible(elements.ProgressGradient1, true)
                    ui_set_visible(elements.LabelProgressGradient2, true)
                    ui_set_visible(elements.ProgressGradient2, true)
                    ui_set_visible(elements.GradientColour, false)
                    ui_set_visible(elements.LabelGradientColour, false) 
                else
                    ui_set_visible(elements.GradientColour, true)
                    ui_set_visible(elements.LabelGradientColour, true)
                    ui_set_visible(elements.LabelProgressGradient1, false)
                    ui_set_visible(elements.ProgressGradient1, false)
                    ui_set_visible(elements.LabelProgressGradient2, false)
                    ui_set_visible(elements.ProgressGradient2, false)
                end

                if ui_get(elements.BackgroundGradientSwitch) then
                    ui_set_visible(elements.BackgroundColorGradient1, true)
                    ui_set_visible(elements.LabelBackgroundColorGradient1, true)
                    ui_set_visible(elements.BackgroundColorGradient2, true)
                    ui_set_visible(elements.LabelBackgroundColorGradient2, true)
                else
                    ui_set_visible(elements.BackgroundColorGradient1, false)
                    ui_set_visible(elements.LabelBackgroundColorGradient1, false)
                    ui_set_visible(elements.BackgroundColorGradient2, false)
                    ui_set_visible(elements.LabelBackgroundColorGradient2, false)
                end
            else
                ui_set_visible(elements.ProgressGradientSwitch, false)
                ui_set_visible(elements.BackgroundGradientSwitch, false)
                ui_set_visible(elements.BackgroundColour, false)
                ui_set_visible(elements.LabelBackgroundColor, false)
                ui_set_visible(elements.LabelTextColorPrimary, false)
                ui_set_visible(elements.TextColorPrimary, false)
                ui_set_visible(elements.LabelTextColorSecondary, false)
                ui_set_visible(elements.TextColorSecondary, false)
                ui_set_visible(elements.BackgroundColorGradient1, false)
                ui_set_visible(elements.LabelBackgroundColorGradient1, false)
                ui_set_visible(elements.BackgroundColorGradient2, false)
                ui_set_visible(elements.LabelBackgroundColorGradient2, false)
                ui_set_visible(elements.LabelProgressGradient1, false)
                ui_set_visible(elements.ProgressGradient1, false)
                ui_set_visible(elements.LabelProgressGradient2, false)
                ui_set_visible(elements.ProgressGradient2, false)
                ui_set_visible(elements.GradientColour, false)
                ui_set_visible(elements.LabelGradientColour, false)
            end
        elseif ui_get(elements.IndicType) == "Minimal" then
            ui_set_visible(elements.MinimumWidth, false)
            ui_set_visible(elements.ArtButton, false)
            ui_set_visible(elements.ProgressGradientSwitch, false)
            ui_set_visible(elements.BackgroundGradientSwitch, false)
            ui_set_visible(elements.BackgroundColour, false)
            ui_set_visible(elements.LabelBackgroundColor, false)
            ui_set_visible(elements.LabelTextColorPrimary, false)
            ui_set_visible(elements.TextColorPrimary, false)
            ui_set_visible(elements.LabelTextColorSecondary, false)
            ui_set_visible(elements.TextColorSecondary, false)
            ui_set_visible(elements.BackgroundColorGradient1, false)
            ui_set_visible(elements.LabelBackgroundColorGradient1, false)
            ui_set_visible(elements.BackgroundColorGradient2, false)
            ui_set_visible(elements.LabelBackgroundColorGradient2, false)
            ui_set_visible(elements.LabelProgressGradient1, false)
            ui_set_visible(elements.ProgressGradient1, false)
            ui_set_visible(elements.LabelProgressGradient2, false)
            ui_set_visible(elements.ProgressGradient2, false)
            ui_set_visible(elements.GradientColour, false)
            ui_set_visible(elements.LabelGradientColour, false)

            if ui_get(elements.CustomColors) then
                ui_set_visible(elements.GradientColour, true)
                ui_set_visible(elements.LabelGradientColour, true)
            else
                ui_set_visible(elements.GradientColour, false)
                ui_set_visible(elements.LabelGradientColour, false)
            end

        else
            ui_set_visible(elements.ArtButton, false)
            ui_set_visible(elements.MinimumWidth, false)
            ui_set_visible(elements.CustomLayoutType, false)
            ui_set_visible(elements.ProgressGradientSwitch, false)
            ui_set_visible(elements.BackgroundColour, false)
            ui_set_visible(elements.LabelBackgroundColor, false)
            ui_set_visible(elements.LabelTextColorPrimary, false)
            ui_set_visible(elements.TextColorPrimary, false)
            ui_set_visible(elements.LabelTextColorSecondary, false)
            ui_set_visible(elements.TextColorSecondary, false)
            ui_set_visible(elements.BackgroundColorGradient1, false)
            ui_set_visible(elements.LabelBackgroundColorGradient1, false)
            ui_set_visible(elements.BackgroundColorGradient2, false)
            ui_set_visible(elements.LabelBackgroundColorGradient2, false)
            ui_set_visible(elements.LabelProgressGradient1, false)
            ui_set_visible(elements.ProgressGradient1, false)
            ui_set_visible(elements.LabelProgressGradient2, false)
            ui_set_visible(elements.ProgressGradient2, false)
            ui_set_visible(elements.GradientColour, false)
            ui_set_visible(elements.LabelGradientColour, false)
        end
                                                                                    
        if ui_get(elements.ControlSwitch) then
            ui_set_visible(elements.SmartControlSwitch, true)
            if ui_get(elements.SmartControlSwitch) then
                ui_set_visible(elements.SmartControls, true)
                ui_set_visible(elements.SkipSong, false)
                ui_set_visible(elements.PreviousSong, false)
                ui_set_visible(elements.PlayPause, false)
            else
                ui_set_visible(elements.SmartControls, false)
                ui_set_visible(elements.SkipSong, true)
                ui_set_visible(elements.PreviousSong, true)
                ui_set_visible(elements.PlayPause, true)
            end
        else
            ui_set_visible(elements.SmartControlSwitch, false)
            ui_set_visible(elements.SmartControls, false)
            ui_set_visible(elements.SkipSong, false)
            ui_set_visible(elements.PreviousSong, false)
            ui_set_visible(elements.PlayPause, false)
        end

        ui_set_visible(elements.DebugInfo, Authed and UserName == "stbrouwers" or Authed and UserName == "slxyx" or Authed and UserName == "Encoded")
        ui_set_visible(elements.Clantag, Authed and UserName == "stbrouwers" or Authed and UserName == "slxyx" or Authed and UserName == "Encoded")

        if ui_get(elements.DebugInfo) then
            ui_set_visible(elements.NowPlaying, true)
            ui_set_visible(elements.Artist, true)
            ui_set_visible(elements.SongDuration, true)
            ui_set_visible(elements.UpdateRate, true)
            ui_set_visible(elements.RateLimitWarning, ui_get(elements.UpdateRate) <= 0.9)
            ui_set_visible(elements.SessionUpdates, true)
        else
            ui_set_visible(elements.NowPlaying, false)
            ui_set_visible(elements.Artist, false)
            ui_set_visible(elements.SongDuration, false)
            ui_set_visible(elements.UpdateRate, false)
            ui_set_visible(elements.RateLimitWarning, false)
            ui_set_visible(elements.SessionUpdates, false)
        end

    elseif ui_get(MainCheckbox) and not Authed then

        ui_set_visible(elements.Connected, true)
        ui_set_visible(elements.AuthButton, true)
        ui_set_visible(elements.ResetKey, ConnectionStatus == 401)
        
    elseif not ui_get(MainCheckbox) then
        for k,v in pairs(elements) do
            for m,w in pairs(elements) do
                if k ~= m then
                    if w == v then
                        elements[m] = nil
                        elements[k] = nil
                    end
                end
            end
        end
        for k,v in pairs(elements) do
            ui.set_visible(v, false)
        end
    end
end

function MusicControls()
    if ControlCheck == false then  
        if not ui_get(elements.SmartControlSwitch) then
            if ui_get(elements.PlayPause) then
                PlayPause()
            elseif ui_get(elements.SkipSong) then
                NextTrack()
            elseif ui_get(elements.PreviousSong) then
                PreviousTrack()
            end
        elseif ui_get(elements.SmartControls) then
            ClickSpree = ClickSpree + 1
            ClickSpreeTime = ClickSpreeTime + 0.45
            ControlCheck = true
        end
    end

    if client.unix_time() > last_update_controls + ClickSpreeTime and ui_get(elements.SmartControlSwitch) then
        if ClickSpree == 0 then ClickSpree = 0 end
        if ClickSpree == 1 then ClickSpree = 0 PlayPause() end
        if ClickSpree == 2 then ClickSpree = 0 NextTrack() end
        if ClickSpree == 3 then ClickSpree = 0 PreviousTrack() end
        if ClickSpree >= 3.1 then ClickSpree = 0 PreviousTrack() end
        last_update_controls = client.unix_time()
        ClickSpreeTime = 0.5
    end
end

function UpdateElements()
    
    switch(AuthStatus) {

        SUCCESS = function()
            ui_set(elements.Connected, "> " .. "Connected to " .. UserName)
        end,

        FAILED = function()
            ui_set(elements.Connected, "> Please put your API key into your clipboard (Invalid token)")
        end,

        TOKEN = function()
            if ui_get(elements.Connected) == "> Please put your API key into your clipboard (Invalid token)" then return end
            ui_set(elements.Connected, "> Please play a song before authorising. If you are listening then your token has expired.")
        end,

        FORBIDDEN = function()
            ui_set(elements.Connected, "> The server has dropped your request. Reason unknown")
        end,

        RATE = function()
            ui_set(elements.Connected, "> You've reached the hourly limit of requests. Contact the lua dev")
        end,

        APIFAIL = function()
            ui_set(elements.Connected, "> An issue on Spotify's end has occurred. Check their status page")
        end
    }

    ui_set(elements.NowPlaying, "Now playing: " .. SongName)
    ui_set(elements.Artist, "By: " .. ArtistName)
    ui_set(elements.SongDuration, SongProgression .. "/" .. SongLength)
    ShowMenuElements()
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
        if SpotifyIndicX <= -0.1 and not ui_get(elements.ArtButton)  then
            SpotifyIndicX = 0
        elseif SpotifyIndicX + adaptivesize >= sx+0.1 and not ui_get(elements.ArtButton) then
            SpotifyIndicX = sx - adaptivesize
        elseif SpotifyIndicX - ArtScaleX <= -0.1 and ui_get(elements.ArtButton) and ui_get(elements.CustomLayoutType) == "Left" and not ui_get(elements.IndicType) == "Minimal" then
            SpotifyIndicX = ArtScaleX
        elseif SpotifyIndicX + adaptivesize >= sx+0.1 and ui_get(elements.ArtButton) and ui_get(elements.CustomLayoutType) == "Left" and not ui_get(elements.IndicType) == "Minimal" then
            SpotifyIndicX = sx - adaptivesize    
        elseif SpotifyIndicX + adaptivesize + ArtScaleX >= sx+0.1 and ui_get(elements.ArtButton) and ui_get(elements.CustomLayoutType) == "Right" and not ui_get(elements.IndicType) == "Minimal" then
            SpotifyIndicX = sx - adaptivesize - ArtScaleX
        elseif SpotifyIndicX <= -0.1 and ui_get(elements.ArtButton) and ui_get(elements.CustomLayoutType) == "Right" and not ui_get(elements.IndicType) == "Minimal" then
            SpotifyIndicX = 0
        else
            SpotifyIndicX = rawmouseposX - xdrag
        end

        if SpotifyIndicY <= -0.1 then
            SpotifyIndicY = 0
        elseif SpotifyIndicY + SpotifyScaleY >= sy+0.1 then
            SpotifyIndicY = sy - SpotifyScaleY
        else    
            SpotifyIndicY = rawmouseposY - ydrag
        end

    end

    if intersect(SpotifyIndicX - startpos.DRegionx, SpotifyIndicY - startpos.DRegiony, adaptivesize, SpotifyScaleY, false) and LClick then 
        dragging = true
        xdrag = rawmouseposX - SpotifyIndicX
        ydrag = rawmouseposY - SpotifyIndicY
    end
end

local function AdjustSize() 
    if not Authed then return end
    
    titlex, titley = surface.get_text_size(TitleFont, SongName)+50
    artistx, artisty = surface.get_text_size(ArtistFont, ArtistName)+50

    if titlex > artistx then
        adaptivesize = titlex
    else
        adaptivesize = artistx
    end

    if ui_get(elements.MinimumWidth) > 199 and adaptivesize < ui.get(elements.MinimumWidth) then
        adaptivesize = ui.get(elements.MinimumWidth)
    end
    if ui_get(elements.IndicType) == "Minimal" then
        if SpotifyIndicX <= -0.1 then
            SpotifyIndicX = 0
        elseif SpotifyIndicX >= sx+0.1 then
            SpotifyIndicX = sx - adaptivesize
        end
    end

    if ui_get(elements.IndicType) == "Spotify" then
        if SpotifyIndicX <= -0.1 and not ui_get(elements.ArtButton) then
            SpotifyIndicX = 0
        elseif SpotifyIndicX + adaptivesize >= sx+0.1 and not ui_get(elements.ArtButton) then
            SpotifyIndicX = sx - adaptivesize
        elseif SpotifyIndicX - ArtScaleX <= -0.1 and ui_get(elements.ArtButton) and ui_get(elements.CustomLayoutType) == "Left" then
            SpotifyIndicX = ArtScaleX
        elseif SpotifyIndicX + adaptivesize >= sx+0.1 and ui_get(elements.ArtButton) and ui_get(elements.CustomLayoutType) == "Left" then
            SpotifyIndicX = sx - adaptivesize    
        elseif SpotifyIndicX + adaptivesize + ArtScaleX >= sx+0.1 and ui_get(elements.ArtButton) and ui_get(elements.CustomLayoutType) == "Right" then
            SpotifyIndicX = sx - adaptivesize - ArtScaleX
        elseif SpotifyIndicX <= -0.1 and ui_get(elements.ArtButton) and ui_get(elements.CustomLayoutType) == "Right" then
            SpotifyIndicX = 0
        end
    end

    if SpotifyIndicY <= -0.01 then
        SpotifyIndicY = 0
    elseif SpotifyIndicY + SpotifyScaleY >= sy+0.1 then
        SpotifyIndicY = sy - SpotifyScaleY
    end

end
        
local function CustomLayout() 
    if ui_get(elements.CustomColors) then
        tr1, tg1, tb1, ta1 = ui.get(elements.TextColorPrimary)
        tr2, tg2, tb2, ta2 = ui.get(elements.TextColorSecondary)
    else
        tr1, tg1, tb1, ta1 = 255,255,255,255
        tr2, tg2, tb2, ta2 = 159,159,159,255
    end
    
    if ui_get(elements.ArtButton) then
        switch(ui_get(elements.CustomLayoutType)) {
        
            Left = function()
                if ui_get(elements.ArtButton) and Thumbnail ~= nil then Thumbnail:draw(SpotifyIndicX-ArtScaleX, SpotifyIndicY, ArtScaleX, ArtScaleY) else end
                surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+22, tr1, tg1, tb1, ta1, TitleFont, SongName)
                surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+52, tr2, tg2, tb2, ta2, ArtistFont, ArtistName)
            end,

            Right = function()
                if ui_get(elements.ArtButton) and Thumbnail ~= nil then Thumbnail:draw(SpotifyIndicX+adaptivesize, SpotifyIndicY, ArtScaleX, ArtScaleY) else end
                surface.draw_text(SpotifyIndicX + adaptivesize - titlex + (SpotifyScaleY/100*40), SpotifyIndicY+22, tr1, tg1, tb1, ta1, TitleFont, SongName)
                surface.draw_text(SpotifyIndicX + adaptivesize - artistx + (SpotifyScaleY/100*40), SpotifyIndicY+52, tr2, tg2, tb2, ta2, ArtistFont, ArtistName)
            end
            
--            Top = function()
--                if ui_get(elements.ArtButton) and Thumbnail ~= nil then Thumbnail:draw(SpotifyIndicX-ArtScaleX+1, SpotifyIndicY, ArtScaleX, ArtScaleY) else end
--                surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+22, tr1, tg1, tb1, ta1, TitleFont, SongName)
--                surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+52, tr2, tg2, tb2, ta2, ArtistFont, ArtistName)
--            end,

--            Behind = function()
--                if ui_get(elements.ArtButton) and Thumbnail ~= nil then Thumbnail:draw(SpotifyIndicX-ArtScaleX+1, SpotifyIndicY, ArtScaleX, ArtScaleY) else end
--                surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+22, tr1, tg1, tb1, ta1, TitleFont, SongName)
--                surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+52, tr2, tg2, tb2, ta2, ArtistFont, ArtistName)
--            end
        }
    else 
        surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+22, tr1, tg1, tb1, ta1, TitleFont, SongName)
        surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+52, tr2, tg2, tb2, ta2, ArtistFont, ArtistName)
    end
end
        
local function DrawNowPlaying()
    if ui_get(elements.CustomColors) then
        r, g, b, a = ui.get(elements.GradientColour)
        br, bg, bb, ba = ui.get(elements.BackgroundColour)
        gr1, gg1, gb1, ga1 = ui.get(elements.ProgressGradient1)
        gr2, gg2, gb2, ga2 = ui.get(elements.ProgressGradient2)
        br1, bg1, bb1, ba1 = ui.get(elements.BackgroundColorGradient1)
        br2, bg2, bb2, ba2 = ui.get(elements.BackgroundColorGradient2)
    else
        r, g, b, a =  0, 255, 0, 255
        br, bg, bb, ba = 25, 25, 25, 255
        gr1, gg1, gb1, ga1 = 0, 255, 0, 255
        gr2, gg2, gb2, ga2 = 0, 255, 0, 255
        br1, bg1, bb1, ba1 = 25, 25, 25, 100
        br2, bg2, bb2, ba2 = 25, 25, 25, 255
    end

    if CurrentDataSpotify == nil then return end

    switch(ui_get(elements.IndicType)) {

        Spotify = function()
            SpotifyScaleX = sx/4.8
            SpotifyScaleY = sy/10.8 
            if ui_get(elements.CustomLayoutType) == "Left" and ui_get(elements.ArtButton) then 
                surface.draw_filled_rect(SpotifyIndicX, SpotifyIndicY, adaptivesize, SpotifyScaleY, br, bg, bb, ba) 
            elseif ui_get(elements.CustomLayoutType) == "Right" and ui_get(elements.ArtButton) then 
                surface.draw_filled_rect(adaptivesize+SpotifyIndicX, SpotifyIndicY, SpotifyIndicX-adaptivesize, SpotifyScaleY, br, bg, bb, ba) 
            else 
                surface.draw_filled_rect(SpotifyIndicX, SpotifyIndicY, adaptivesize, SpotifyScaleY, br, bg, bb, ba) 
            end

            if ui_get(elements.BackgroundGradientSwitch) then
                surface.draw_filled_gradient_rect(SpotifyIndicX, SpotifyIndicY, adaptivesize, (SpotifyScaleY/20*19), br1, bg1, bb1, ba1, br2, bg2, bb2, ba2, true)
            end

            if not ui_get(elements.ProgressGradientSwitch) then
                surface.draw_filled_rect(SpotifyIndicX, SpotifyIndicY+(SpotifyScaleY/20*19), CurrentDataSpotify.progress_ms/CurrentDataSpotify.item.duration_ms*adaptivesize, (SpotifyScaleY/20*1), r, g, b, a)
            else
                surface.draw_filled_gradient_rect(SpotifyIndicX, SpotifyIndicY+(SpotifyScaleY/20*19), CurrentDataSpotify.progress_ms/CurrentDataSpotify.item.duration_ms*adaptivesize, (SpotifyScaleY/20*1), gr1, gg1, gb1, ga1, gr2, gg2, gb2, ga2, true)
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
    clantags = {"Listening to", CurrentDataSpotify.item.name, "by", CurrentDataSpotify.item.artists[1].name}
    local cur = math.floor(globals.tickcount() / duration) % #clantags
    clantag = clantags[cur+1]
    if clantag ~= clantag_prev then
        clantag_prev = clantag
        client.set_clan_tag(clantag)
    end
end

function OnFrame()
    if not apikey then return end
    if client.unix_time() > last_update + ui_get(elements.UpdateRate) then
        UpdateInf()
        last_update = client.unix_time()
        UpdateCount = UpdateCount + 1
        ui_set(elements.SessionUpdates, "Total updates this session: " .. UpdateCount)
    end

    if ui_get(MainCheckbox) and Authed then
        AdjustSize()
        DrawNowPlaying()
        ShowMenuElements()
        MusicControls()


        if ui_get(elements.IndicType) == "Spotify" then CustomLayout() end
        if ui_get(elements.Clantag) then SpotifyClantag() end
        if ui.is_menu_open() then Dragging(); UpdateElements() end

        if ui_get(elements.ControlSwitch) then
            if ui_get(elements.PlayPause) or ui_get(elements.SkipSong) or ui_get(elements.PreviousSong) or ui_get(elements.SmartControls) then
                ControlCheck = true
            else
                ControlCheck = false
            end
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
ui_set_callback(elements.ArtButton, ShowMenuElements)
ui_set_callback(elements.DebugInfo, ShowMenuElements)
ui_set_callback(elements.CustomColors, ShowMenuElements)

client.set_event_callback("paint_ui", OnFrame)

client.set_event_callback('shutdown', function()
    database_write("previous_posX", SpotifyIndicX)
    database_write("previous_posY", SpotifyIndicY)
    database_write("previous_size", SelectedSize)
end)
