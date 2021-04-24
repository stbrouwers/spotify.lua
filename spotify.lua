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
local ui_menu_position = ui.menu_position
local last_update = client.unix_time()
local last_update_controls = client.unix_time()
local last_update_error = client.unix_time()
local last_update_volume = globals.tickcount()
local last_update_volume_press = globals.tickcount()
local last_update_volume_set = globals.tickcount()
local sx, sy = client.screen_size()

MenuScaleX = 4.8
MenuScaleY = 10.8
ScaleTitle = 41.54
ScaleArtist = 63.53
ScaleDuration = 57
local TitleFont = surface.create_font("GothamBookItalic", sy/ScaleTitle, 900, 0x010)
local ArtistFont = surface.create_font("GothamBookItalic", sy/ScaleArtist, 600, 0x010)
local TitleFontHUD = surface.create_font("GothamBookItalic", 25, 900, 0x010)
local ArtistFontHUD = surface.create_font("GothamBookItalic", 20, 600, 0x010)
local DurationFont = surface.create_font("GothamBookItalic", sy/ScaleDuration, 600, 0x010)
local VolumeFont = surface.create_font("GothamBookItalic", sy/ScaleTitle, 900, 0x010)

local MainCheckbox = ui.new_checkbox("MISC", "Miscellaneous", "Spotify")

local SpotifyIndicX = database_read("previous_posX") or 0
local SpotifyIndicY = database_read("previous_posY") or 1020
local SizePerc = database_read("previous_size") or 30
local apikey = database_read("StoredKey") or nil
local refreshkey = database_read("StoredKey2") or nil

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

retardedJpg = false
dragging = false
Authed = false
CornerReady = false
ControlCheck = false
AuthClicked = false
SongChanged = false
VolumeMax = false
VolumeMin = false
VolumeCheck = false
FirstPress = false
RunOnceCheck = false
StopSpamming = false
SetCheck = true
forkinCock = true
bool = true
gropeTits = true

limitval = 0
indicxcomp = -0.1
SpotifyScaleX = sx/4.8
SpotifyScaleY = sy/10.8
SpotifyIndicX2 = 1
adaptivesize = 400
ArtScaleX, ArtScaleY = SpotifyScaleY, SpotifyScaleY
UpdateCount = 0
ClickSpree = 0
ClickSpreeTime = 1
TotalErrors = 0
ErrorSpree = 0
NewApiKeyRequest = 0
AlteredVolume = 0
NewVolume = 0
sectionPrev = 0

AuthStatus = "> Not connected"
deviceid = ""
UserName = "-"
SongName = "-"
ArtistName = "-"
SongProgression = "-"
SongLength = "-"
TotalDuration = "-"
ProgressDuration = "-"
SongNameBack = "-"
AuthURL = "https://spotify.stbrouwers.cc/"

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

local msConversion = function(b)
    local c=math.floor(b/1000)
    local d=math.floor(c/3600)
    local c=c-d*3600;
    local e=math.floor(c/60)
    local c='00'..c-e*60;
    local c=c:sub(#c-1)
    if d>0 then 
        local e=''..e;
        local e=('00'..e):sub(#e+1)
        return d..':'..e..':'..c 
    else 
        return e..':'..c 
    end 
end

local function GetRefreshToken() 
    if AuthClicked == false then return end
    local js = panorama.loadstring([[
        return {
          open_url: function(url){
            SteamOverlayAPI.OpenURL(url)
          }
        }
        ]])()
      js.open_url(AuthURL) 
end

function GetApiToken() 
    if NewApiKeyRequest <= 5 then
        if PendingRequest then return end
        PendingRequest = true
        if AuthClicked == true then
            AuthStatus = "TRYING"
        end
        http.get("https://spotify.stbrouwers.cc/refresh_token?refresh_token="..refreshkey, function(s, r)
            if r.status ~= 200 then
                AuthStatus = "WRONGKEY"
                PendingRequest = false
                GetRefreshToken()
                NewApiKeyRequest = NewApiKeyRequest + 1
            return
            else
                PendingRequest = false
                NewApiKeyRequest = 0
                parsed = json.parse(r.body)
                apikey = parsed.access_token
                Auth()
            end
        end)
    else
        return
    end
end

function Auth()
    if AuthClicked == true then refreshkey = CP() end
    if refreshkey == nil then GetRefreshToken() return end
    if refreshkey ~= nil and apikey == nil then
        GetApiToken()
        return end
    if refreshkey ~= nil and apikey ~= nil then
        http.get("https://api.spotify.com/v1/me?&access_token=" .. apikey, function(success, response)
            ConnectionStatus = response.status
            if not success or response.status ~= 200 then
                ConnectionStatus = response.status
                Authed = false
                AuthStatus = "FAILED"
                GetApiToken()
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
end
Auth()

function DAuth() 
        if not ConnectionStatus then return end
        if ConnectionStatus == 202 then
            AuthStatus = "SUCCESS"
        end

        if ConnectionStatus == 403 then
            AuthStatus = "FORBIDDEN"
            ErrorSpree = ErrorSpree + 1
            TotalErrors = TotalErrors + 1
        end

        if ConnectionStatus == 429 then
            AuthStatus = "RATE"
            ErrorSpree = ErrorSpree + 1
            TotalErrors = TotalErrors + 1
        end

        if ConnectionStatus == 503 then
            AuthStatus = "APIFAIL"
            ErrorSpree = ErrorSpree + 1
            TotalErrors = TotalErrors + 1
        end

    ShowMenuElements()
    UpdateElements()
end

function UpdateInf()
    SongNameBack = SongName
    DAuth() 
    http.get("https://api.spotify.com/v1/me/player?access_token=" .. apikey, function(success, response)
        if not success or response.status ~= 200 then
            AuthStatus = "TOKEN"
            ErrorSpree = ErrorSpree + 1
            TotalErrors = TotalErrors + 1
            return 
        end
            CurrentDataSpotify = json.parse(response.body)
            deviceid = CurrentDataSpotify.device.id

            if RunOnceCheck == false then
                NewVolume = CurrentDataSpotify.device.volume_percent
                RunOnceCheck = true
            end

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

            TotalDuration = msConversion(CurrentDataSpotify.item.duration_ms)
            ProgressDuration = msConversion(CurrentDataSpotify.progress_ms)
            if not CurrentDataSpotify.item.is_local then
                ThumbnailUrl = CurrentDataSpotify.item.album.images[1].url
                http.get(ThumbnailUrl, function(success, response)
                    if not success or response.status ~= 200 then
                      return
                    end
                Thumbnail = images.load_jpg(response.body)
                end)
            end
            if SongNameBack ~= SongName and SongNameBack ~= nil then
                SpotifyIndicX2 = SpotifyIndicX+adaptivesize
                SongChanged = true
            end
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
            UpdateCount = UpdateCount + 1
            
        end)
    else
        http.put("https://api.spotify.com/v1/me/player/play?device_id=" .. deviceid, options, function(s, r)
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
        UpdateCount = UpdateCount + 1
    end)   
    UpdateInf()
end

local elements = {
    Connected = ui_new_label("MISC", "Miscellaneous", AuthStatus),
    AuthButton = ui_new_button("MISC", "Miscellaneous", "Authorize", function() AuthClicked = true Auth() end),
    IndicType = ui_new_combobox("MISC", "Miscellaneous", "Type", "Spotify", "Minimal"),
    MenuSize = ui_new_slider("MISC", "Miscellaneous", "Scale", 50, 150, 100, true, "%"),
    WidthLock = ui_new_label("MISC", "Miscellaneous", "⭥                        [LINKED]                         ⭥"),
    MinimumWidth = ui_new_slider("MISC", "Miscellaneous", "Minimum box width", 199, 600, 400, true, "px", 1, { [199] = "Auto"}),
    
    DebugInfo = ui_new_checkbox("MISC", "Miscellaneous", "Debug info"),
        NowPlaying = ui_new_label("MISC", "Miscellaneous", "Now playing:" .. SongName),
        Artist = ui_new_label("MISC", "Miscellaneous", "By:" .. ArtistName),
        SongDuration = ui_new_label("MISC", "Miscellaneous", SongProgression .. SongLength),
        VolumeLabel = ui_new_label("MISC", "Miscellaneous", "NewVolume: " .. NewVolume),
        UpdateRate = ui_new_slider("MISC", "Miscellaneous", "Update rate", 0.5, 5, 1, true, "s"),
        RateLimitWarning = ui_new_label("MISC", "Miscellaneous", "WARNING: using <1s updaterate might get you ratelimited"),
        SessionUpdates = ui_new_label("MISC", "Miscellaneous", "Total updates this session: " .. UpdateCount),
        TotalErrors = ui_new_label("MISC", "Miscellaneous", "Errors this session: " .. TotalErrors),
        SpreeErrors = ui_new_label("MISC", "Miscellaneous", "Errors this spree: " .. ErrorSpree),
        RecentError = ui_new_label("MISC", "Miscellaneous", "Most recent error: " .. "-"),
        MaxErrors = ui_new_slider("MISC", "Miscellaneous", "Max errors", 1, 20, 5, true, "x"),
        ErrorRate = ui_new_slider("MISC", "Miscellaneous", "within", 5, 300, 30, true, "s"),
        FirstPressAmount = ui_new_slider("MISC", "Miscellaneous", "First press amount", 1, 20, 5, true, "%"),
        VolumeTickSpeed = ui_new_slider("MISC", "Miscellaneous", "Volume tick speed", 1, 64, 2, true, "tc"),
        VolumeTickAmount = ui_new_slider("MISC", "Miscellaneous", "Volume tick amount", 1, 10, 1, true, "%"),
        SpotifyPosition = ui_new_label("MISC", "Miscellaneous", "Position(x - x2(width), y): " .. SpotifyIndicX .. " - " .. SpotifyIndicX2 .. "(" .. adaptivesize .. "), " .. SpotifyIndicY .. "y"),
        AddError = ui_new_button("MISC", "Miscellaneous", "Add an error", function() AuthStatus = "TOKEN" ErrorSpree = ErrorSpree + 1 TotalErrors = TotalErrors + 1 end),
        ForceReflowButton = ui_new_button("MISC", "Miscellaneous", "Force element reflow", function() ForceReflow() end),

    ArtButton = ui_new_checkbox("MISC", "Miscellaneous", "Cover art"),
        CustomLayoutType = ui_new_combobox("MISC", "Miscellaneous", "Location", "Left", "Right"),
        SongDurationToggle = ui_new_checkbox("MISC", "Miscellaneous", "Song duration"),

    DisplayConnected = ui_new_checkbox("MISC", "Miscellaneous", "Display connected account"),
    
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
        SmartVolumeSwitch = ui_new_checkbox("MISC", "Miscellaneous", "Smart volume"),
            SmartControls = ui_new_hotkey("MISC", "Miscellaneous", "  - Smart Controls", true),
            

        PlayPause = ui_new_hotkey("MISC", "Miscellaneous", "  - Play/Pause", false),
        SkipSong = ui_new_hotkey("MISC", "Miscellaneous", "  - Skip song", false),
        PreviousSong = ui_new_hotkey("MISC", "Miscellaneous", "  - Previous song", false),
        IncreaseVolume = ui_new_hotkey("MISC", "Miscellaneous", "  - Volume up", false),
        DecreaseVolume = ui_new_hotkey("MISC", "Miscellaneous", "  - Volume down", false),
        AdaptiveVolume = ui_new_slider("MISC", "Miscellaneous", "Decrease volume by % on voicechat", 0, 100, "off", true, "%", 1, { [0] = "off", [100] = "mute"}),


    Clantag = ui_new_checkbox("MISC", "Miscellaneous", "Now playing clantag"),
    ResetAuth = ui_new_button("MISC", "Miscellaneous", "Reset authorization", function() ResetAPI() end),
}

function ChangeVolume() 
    if stopRequest then return end

    local options = {
        headers = {
            ["Accept"] = "application/json",
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. apikey,
            ["Content-length"] = 0
        }
    }

    http.put("https://api.spotify.com/v1/me/player/volume?volume_percent=" .. NewVolume .. "&device_id=" .. deviceid, options, function(s, r)
        UpdateCount = UpdateCount + 1
    end)
    stopRequest = true
    StopSpamming = false
    SetCheck = true
end 

function setConnected(value)
    ui_set(elements.Connected, value)
end

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
        ui_set_visible(elements.NowPlaying, true)
        ui_set_visible(elements.Artist, true)
        ui_set_visible(elements.SongDuration, true)
        ui_set_visible(elements.IndicType, true)
        ui_set_visible(elements.GradientColour, true)
        ui_set_visible(elements.LabelGradientColour, true)
        ui_set_visible(elements.CustomColors, true)
        ui_set_visible(elements.ControlSwitch, true)
        ui_set_visible(elements.Clantag, true)
        ui_set_visible(elements.MenuSize, true)
        ui_set_visible(elements.SongDurationToggle, true)
        ui_set_visible(elements.ResetAuth, true)

        if ui_get(elements.IndicType) == "Spotify" then
            ui_set_visible(elements.DisplayConnected, false)
            ui_set_visible(elements.ArtButton, true)
            ui_set_visible(elements.WidthLock, ShiftClick)
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
            ui_set_visible(elements.DisplayConnected, true)
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
            ui_set_visible(elements.MenuSize, false)
            ui_set_visible(elements.CustomLayoutType, false)
            ui_set_visible(elements.SongDurationToggle, false)

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
            ui_set_visible(elements.SmartVolumeSwitch, false)
            ui_set_visible(elements.IncreaseVolume, true)
            ui_set_visible(elements.DecreaseVolume, true)
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

            if ui_get(elements.SmartVolumeSwitch) then
                ui_set_visible(elements.AdaptiveVolume, false)
            else
                ui_set_visible(elements.AdaptiveVolume, false)
            end

        else
            ui_set_visible(elements.SmartControlSwitch, false)
            ui_set_visible(elements.SmartVolumeSwitch, false)
            ui_set_visible(elements.SmartControls, false)
            ui_set_visible(elements.SkipSong, false)
            ui_set_visible(elements.PreviousSong, false)
            ui_set_visible(elements.PlayPause, false)
            ui_set_visible(elements.IncreaseVolume, false)
            ui_set_visible(elements.DecreaseVolume, false)
            ui_set_visible(elements.AdaptiveVolume, false)
        end

        ui_set_visible(elements.DebugInfo, Authed and UserName == "stbrouwers" or Authed and UserName == "slxyx" or Authed and UserName == "Encoded" or Authed and UserName == "22fzreq5auy5njejk6fzp7nhy")

        if ui_get(elements.DebugInfo) then
            ui_set_visible(elements.NowPlaying, true)
            ui_set_visible(elements.Artist, true)
            ui_set_visible(elements.SongDuration, true)
            ui_set_visible(elements.UpdateRate, true)
            ui_set_visible(elements.RateLimitWarning, ui_get(elements.UpdateRate) <= 0.9)
            ui_set_visible(elements.SessionUpdates, true)
            ui_set_visible(elements.TotalErrors, true)
            ui_set_visible(elements.SpreeErrors, true)
            ui_set_visible(elements.RecentError, true)
            ui_set_visible(elements.ErrorRate, true)
            ui_set_visible(elements.MaxErrors, true)
            ui_set_visible(elements.AddError, true)
            ui_set_visible(elements.SpotifyPosition, true)
            ui_set_visible(elements.ForceReflowButton, true)
            ui_set_visible(elements.VolumeTickSpeed, true)
            ui_set_visible(elements.VolumeTickAmount, true)
            ui_set_visible(elements.FirstPressAmount, true)
            ui_set_visible(elements.VolumeLabel, true)
        else
            ui_set_visible(elements.NowPlaying, false)
            ui_set_visible(elements.Artist, false)
            ui_set_visible(elements.SongDuration, false)
            ui_set_visible(elements.UpdateRate, false)
            ui_set_visible(elements.RateLimitWarning, false)
            ui_set_visible(elements.SessionUpdates, false)
            ui_set_visible(elements.TotalErrors, false)
            ui_set_visible(elements.SpreeErrors, false)
            ui_set_visible(elements.RecentError, false)
            ui_set_visible(elements.ErrorRate, false)
            ui_set_visible(elements.MaxErrors, false)
            ui_set_visible(elements.AddError, false)
            ui_set_visible(elements.SpotifyPosition, false)
            ui_set_visible(elements.ForceReflowButton, false)
            ui_set_visible(elements.VolumeTickSpeed, false)
            ui_set_visible(elements.VolumeTickAmount, false)
            ui_set_visible(elements.FirstPressAmount, false)
            ui_set_visible(elements.VolumeLabel, false)
        end

    elseif ui_get(MainCheckbox) and not Authed then
        ui_set_visible(elements.Connected, true)
        ui_set_visible(elements.AuthButton, true)
        ui_set_visible(elements.ResetAuth, true)

        
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

function ForceReflow()
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
    ShowMenuElements()
end

function ResetAPI() 
    Authed = false
    ConnectionStatus = "NoConnection"
    apikey = nil
    refreshkey = nil
    database_write("StoredKey", nil)
    database_write("StoredKey2", nil)
    ForceReflow()
    client.reload_active_scripts()
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

function gaySexgamer()
    if forkinCock then
        analBuggery = globals.tickcount() % 64
        analGaping = globals.tickcount() % 64
        forkinCock = false
    end
    if globals.tickcount() % 64 == analGaping and bool then
        gropeTits = true
    end
    if gropeTits then
        analBuggery = globals.tickcount() % 64
    end
    if ui.get(elements.IncreaseVolume) or ui_get(elements.DecreaseVolume) then bool = false else bool = true end
    if not bool then
        molestingInfants = true
        gropeTits = false
        analGaping = (globals.tickcount() % 64)-2
    end
end

function VolumeHandler() 
    if ui_get(elements.IncreaseVolume) or ui_get(elements.DecreaseVolume) then
        if FirstPress then
            if VolumeCheck == false then 
                if ui_get(elements.IncreaseVolume) and not ui_get(elements.DecreaseVolume) then
                    NewVolume = NewVolume + ui_get(elements.FirstPressAmount)
                elseif not ui_get(elements.IncreaseVolume) and ui_get(elements.DecreaseVolume) then
                    NewVolume = NewVolume - ui_get(elements.FirstPressAmount)
                end
            end
        end
        if NewVolume >= 100 then 
            NewVolume = 100
        elseif NewVolume <= 0 then
            NewVolume = 0
        end 
    end
    if globals.tickcount() % 64 == analBuggery and not ui_get(elements.IncreaseVolume) and not ui_get(elements.DecreaseVolume) and molestingInfants then
        molestingInfants = false
        stopRequest = false
        NiggerSex = false
        groomingNiglets = true
        ChangeVolume() 
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
            ui_set(elements.RecentError, "Most recent error: " .. "000, REJECTED")
        end,

        FORBIDDEN = function()
            ui_set(elements.Connected, "> The server has dropped your request. Reason unknown")
            ui_set(elements.RecentError, "Most recent error: " .. "403, FORBIDDEN")
        end,

        RATE = function()
            ui_set(elements.Connected, "> You've reached the hourly limit of requests. Contact the lua dev")
            ui_set(elements.RecentError, "Most recent error: " .. "429, RATELIMIT")
        end,

        APIFAIL = function()
            ui_set(elements.Connected, "> An issue on Spotify's end has occurred. Check their status page")
            ui_set(elements.RecentError, "Most recent error: " .. "503, APIFAIL")
        end,

        TRYING = function()
            ui_set(elements.Connected, "> Trying the refresh key")
        end,

        WRONGKEY = function() 
            ui_set(elements.Connected, "> The supplied refresh key was invalid, please try again.")
            ui_set(elements.RecentError, "Most recent error: " .. "XXX, WRONGKEY")
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

    if SongChanged and ui_get(elements.CustomLayoutType) == "Right" and ui_get(elements.IndicType) == "Spotify" then
        SpotifyIndicX = SpotifyIndicX2 - adaptivesize
        SongChanged = false
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
    SpotifyIndicX2 = SpotifyIndicX + adaptivesize
end
        
local c = {130, 130, 130}
local g, h = 255, 0
local l = {30, 150}

local function CustomLayout() 
    ArtScaleX, ArtScaleY = SpotifyScaleY, SpotifyScaleY
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
                if ui_get(elements.ArtButton) and Thumbnail ~= nil and not CurrentDataSpotify.item.is_local then
                    local function drawLeft()
                        Thumbnail:draw(SpotifyIndicX-ArtScaleX, SpotifyIndicY, ArtScaleX, ArtScaleY)
                    end
                    status, retval = pcall(drawLeft)
                    if status == false or CurrentDataSpotify.item.is_local then
                        retardedJpg = true
                    end
                else end
                surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+(SpotifyScaleY/100)*22, tr1, tg1, tb1, ta1, TitleFont, SongName)

                surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+(SpotifyScaleY/100)*52, tr2, tg2, tb2, ta2, ArtistFont, ArtistName)
                if ui_get(elements.SongDurationToggle) then
                    surface.draw_text(SpotifyIndicX+adaptivesize-(SpotifyScaleY/100)*85, SpotifyIndicY+(SpotifyScaleY/100)*67, tr2, tg2, tb2, ta2, DurationFont, ProgressDuration .. "/" .. TotalDuration)
                end
            end,

            Right = function()
                if ui_get(elements.ArtButton) and Thumbnail ~= nil then
                    local function drawRight()
                        Thumbnail:draw(SpotifyIndicX+adaptivesize, SpotifyIndicY, ArtScaleX, ArtScaleY)
                    end
                    status, retval = pcall(drawRight)
                    if status == false then
                        retardedJpg = true
                    end
                    else end
                surface.draw_text(SpotifyIndicX + adaptivesize - titlex +40, SpotifyIndicY+(SpotifyScaleY/100)*22, tr1, tg1, tb1, ta1, TitleFont, SongName)
                surface.draw_text(SpotifyIndicX + adaptivesize - artistx +40, SpotifyIndicY+(SpotifyScaleY/100)*52, tr2, tg2, tb2, ta2, ArtistFont, ArtistName)
                if ui_get(elements.SongDurationToggle) then
                    surface.draw_text(SpotifyIndicX+8, SpotifyIndicY+(SpotifyScaleY/100)*67, tr2, tg2, tb2, ta2, DurationFont, ProgressDuration .. "/" .. TotalDuration)
                end
            end
        }
    else 
        surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+(SpotifyScaleY/100)*22, tr1, tg1, tb1, ta1, TitleFont, SongName)
        surface.draw_text(SpotifyIndicX+10, SpotifyIndicY+(SpotifyScaleY/100)*52, tr2, tg2, tb2, ta2, ArtistFont, ArtistName)

        if ui_get(elements.SongDurationToggle) then
            surface.draw_text(SpotifyIndicX+adaptivesize-(SpotifyScaleY/100)*85, SpotifyIndicY+(SpotifyScaleY/100)*67, tr2, tg2, tb2, ta2, DurationFont, ProgressDuration .. "/" .. TotalDuration)
        end
    end
end

-- not stolen
local volume_drawer=(function()local a={callback_registered=false,maximum_count=7,data={}}function a:register_callback()if self.callback_registered then return end;client.set_event_callback('paint_ui',function()local b={30,150}local c={13,13,13}local d=5;local e=self.data;for f=#e,1,-1 do self.data[f].time=self.data[f].time-globals.frametime()local g,h=255,0;local i=e[f]if i.time<0 then table.remove(self.data,f)else local j=i.def_time-i.time;local j=j>1 and 1 or j;if i.time<0.5 or j<0.5 then h=(j<1 and j or i.time)/0.5;g=h*255;if h<0.2 then d=d+15*(1.0-h/0.2)end end;local k={renderer.measure_text(nil,i.draw)}local l={b[1],b[2]}renderer.circle(l[1],l[2],c[1],c[2],c[3],g,20,90,0.5)renderer.circle(l[1],l[2]+100,c[1],c[2],c[3],g,19,270,0.5)renderer.rectangle(l[1]-19.3,l[2],39,100,c[1],c[2],c[3],g)renderer.circle(l[1],l[2],130,130,130,g,19,270,0.5)renderer.rectangle(l[1]-19.3,l[2],39,NewVolume,130,130,130,g)d=d-50 end end;self.callback_registered=true end)end;function a:paint(m,n)local o=tonumber(m)+1;for f=self.maximum_count,2,-1 do self.data[f]=self.data[f-1]end;self.data[1]={time=o,def_time=o,draw=n}self:register_callback()end;return a end)()
        
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

    if NiggerSex then
        --surface.draw_text(10,10, 255, 255, 255, 255, DurationFont, "Volume: " .. NewVolume .. "%")
        renderer.rectangle(l[1]-10, l[2], 5, 100, 64, 64, 64, 255)
        renderer.rectangle(l[1]-10, l[2]+100, 5, -NewVolume, 29, 185, 84, 255)
        renderer.circle(l[1]-7, l[2]+100-NewVolume, 255, 255, 255, 255, 6, 0, 1)
    end
    switch(ui_get(elements.IndicType)) {

        Spotify = function()
            SpotifyScaleX = sx/MenuScaleX
            SpotifyScaleY = sy/MenuScaleY
            if ui_get(elements.CustomLayoutType) == "Left" and ui_get(elements.ArtButton) then
                surface.draw_filled_rect(SpotifyIndicX, SpotifyIndicY, adaptivesize, SpotifyScaleY, br, bg, bb, ba)
                surface.draw_filled_rect(SpotifyIndicX-ArtScaleX, SpotifyIndicY, SpotifyScaleY, SpotifyScaleY, 18, 18, 18, 255)
                renderer.circle_outline(SpotifyIndicX-ArtScaleX/2, SpotifyIndicY+SpotifyScaleY/2, 64, 64, 64, 255, SpotifyScaleY/10, 0, 1, 3)
                renderer.circle_outline(SpotifyIndicX-ArtScaleX/2, SpotifyIndicY+SpotifyScaleY/2, 64, 64, 64, 255, (SpotifyScaleY/100)*35, 0, 1, 3)
            elseif ui_get(elements.CustomLayoutType) == "Right" and ui_get(elements.ArtButton) then 
                surface.draw_filled_rect(SpotifyIndicX, SpotifyIndicY, adaptivesize, SpotifyScaleY, br, bg, bb, ba) 
                surface.draw_filled_rect(SpotifyIndicX+adaptivesize, SpotifyIndicY, ArtScaleX, ArtScaleX, 18, 18, 18, 255)
                renderer.circle_outline(SpotifyIndicX+adaptivesize+ArtScaleX/2, SpotifyIndicY+SpotifyScaleY/2, 64, 64, 64, 255, SpotifyScaleY/10, 0, 1, 3)
                renderer.circle_outline(SpotifyIndicX+adaptivesize+ArtScaleX/2, SpotifyIndicY+SpotifyScaleY/2, 64, 64, 64, 255, (SpotifyScaleY/100)*35, 0, 1, 3)
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
            if ui_get(elements.DisplayConnected) then
                SpotifyScaleX = 150
                SpotifyScaleY = 30
            else
                SpotifyScaleX = 150
                SpotifyScaleY = 15
            end
            songartist = renderer.measure_text("b", "Now Playing: "..CurrentDataSpotify.item.name.." by "..CurrentDataSpotify.item.artists[1].name)+10
            usrnm = renderer.measure_text("b", "Connected to: "..spotidata.display_name)+10
            if CurrentDataSpotify.is_playing and songartist > usrnm then
                textmeasurement = renderer.measure_text("b", "Now Playing: "..CurrentDataSpotify.item.name.." by "..CurrentDataSpotify.item.artists[1].name)+10
            elseif CurrentDataSpotify.is_playing and songartist < usrnm then
                textmeasurement = renderer.measure_text("b", "Connected to: "..spotidata.display_name)+10
            elseif not CurrentDataSpotify.is_playing then
                textmeasurement = renderer.measure_text("b", "Connected to: "..spotidata.display_name)+10
            end

            renderer.gradient(SpotifyIndicX, SpotifyIndicY, textmeasurement, SpotifyScaleY+2, 22, 22, 22, 255, 22, 22, 22, 10, true)
            renderer.rectangle(SpotifyIndicX, SpotifyIndicY, 2, SpotifyScaleY+2, r, g, b, a)
            renderer.gradient(SpotifyIndicX, SpotifyIndicY, CurrentDataSpotify.progress_ms/CurrentDataSpotify.item.duration_ms*textmeasurement, 2, r, g, b, a, r, g, b, 0, true)
            renderer.gradient(SpotifyIndicX, SpotifyIndicY+SpotifyScaleY, CurrentDataSpotify.progress_ms/CurrentDataSpotify.item.duration_ms*textmeasurement, 2, r, g, b, a, r, g, b, 0, true)
            if ui_get(elements.DisplayConnected) then
                renderer.text(SpotifyIndicX+5, SpotifyIndicY+5, 255, 255, 255, 255, "b", 0, "Connected to: "..spotidata.display_name)
                if CurrentDataSpotify.is_playing then
                    renderer.text(SpotifyIndicX+5, SpotifyIndicY+15, 255, 255, 255, 255, "b", 0, "Now Playing: "..CurrentDataSpotify.item.name.." by "..CurrentDataSpotify.item.artists[1].name)
                else
                    renderer.text(SpotifyIndicX+5, SpotifyIndicY+15, 255, 255, 255, 255, "b", 0, "Paused")
                end
            else
                if CurrentDataSpotify.is_playing then
                    renderer.text(SpotifyIndicX+5, SpotifyIndicY+2, 255, 255, 255, 255, "b", 0, "Now Playing: "..CurrentDataSpotify.item.name.." by "..CurrentDataSpotify.item.artists[1].name)
                else
                    renderer.text(SpotifyIndicX+5, SpotifyIndicY+2, 255, 255, 255, 255, "b", 0, "Paused")
                end
            end
        end
    }
end

function ChangeMenuSize()
    MenuScaleChange = 2 - ui_get(elements.MenuSize)/100
    MenuScaleX = 4.8 * MenuScaleChange
    MenuScaleY = 10.8 * MenuScaleChange
    ScaleTitle = 41.54 * MenuScaleChange
    ScaleArtist = 63.53 * MenuScaleChange
    ScaleDuration = 54 * MenuScaleChange
    TitleFont = surface.create_font("GothamBookItalic", sy/ScaleTitle, 900, 0x010)
    ArtistFont = surface.create_font("GothamBookItalic", sy/ScaleArtist, 600, 0x010)
    DurationFont = surface.create_font("GothamBookItalic", sy/ScaleDuration, 600, 0x010)
    local minwidth = ui_get(elements.MinimumWidth) 
    if ShiftClick then 
        ui_set(elements.MinimumWidth, ui_get(elements.MenuSize)/100 * 400) 
    end
    print(ScaleArtist)
end

function drawHUD()
    local menuX, menuY = ui.menu_position()
    local menuW, menuH = ui.menu_size()
    if ui.is_menu_open() then
        --renderer.rectangle(menuX, menuY + menuH, menuW, 100, 13, 13, 13, 255)
        surface.draw_filled_rect(menuX, menuY + menuH, menuW, 100, 25, 25, 25, 255)
        renderer.circle_outline(menuX + (menuW / 2), menuY + menuH + 40, 255, 255, 255, 255, 16, 0, 1, 1)
        --surface.draw_outlined_circle(menuX + (menuW / 2), menuY + menuH + 50, 255, 255, 255, 255, 24, 21)
        surface.draw_filled_rect(menuX + (menuW / 2) - 5, menuY + menuH + 34, 3, 12, 255, 255, 255, 255)
        surface.draw_filled_rect(menuX + (menuW / 2) + 2, menuY + menuH + 34, 3, 12, 255, 255, 255, 255)
        surface.draw_text(menuX + 100, menuY + menuH + 20, 255, 255, 255, 255, TitleFontHUD, SongName)
        surface.draw_text(menuX + 100, menuY + menuH + 50, 159, 159, 159, 255, ArtistFontHUD, ArtistName)
        if Thumbnail ~= nil and not CurrentDataSpotify.item.is_local then
            Thumbnail:draw(menuX + 10, menuY + menuH + 10, 75, 75)
        end
    end
end

local clantagduration = 70
local clantag_prev
function SpotifyClantag()
    if CurrentDataSpotify == nil then return end
    clantags = {"Listening to", CurrentDataSpotify.item.name, "by", CurrentDataSpotify.item.artists[1].name}
    local cur = math.floor(globals.tickcount() / clantagduration) % #clantags
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
        ui_set(elements.TotalErrors, "Errors this session: " .. TotalErrors)
        ui_set(elements.SpreeErrors, "Errors this spree: " .. ErrorSpree)

        if ErrorSpree == ui_get(elements.MaxErrors) or ErrorSpree >= ui_get(elements.MaxErrors) then
            Authed = false
            ErrorSpree = 0
            ShowMenuElements()
            GetApiToken()

            if AuthStatus == "TOKEN" then
                ui_set(elements.Connected, "> Please play a song before authorising. If you are listening then your token has expired.")
            end
        end
    end

    if client.unix_time() > last_update_error + ui_get(elements.ErrorRate) then
        ErrorSpree = 0
        ui_set(elements.SpreeErrors,  "Errors this spree: " .. ErrorSpree)
        last_update_error = client.unix_time()
    end

    ShiftClick = client.key_state(0x10)
    if ui_get(MainCheckbox) and Authed then
        drawHUD()
        AdjustSize()
        DrawNowPlaying()
        ShowMenuElements()

        if ui_get(elements.DebugInfo) then
            ui_set(elements.VolumeLabel, "NewVolume: " .. NewVolume)
            ui_set(elements.SpotifyPosition, "Position(x - x2(width), y): " .. SpotifyIndicX .. " - " .. SpotifyIndicX2 .. "(" .. adaptivesize .. "), " .. SpotifyIndicY .. "y")
        end

        if ui_get(elements.IndicType) == "Spotify" then CustomLayout() end
        if ui_get(elements.Clantag) then SpotifyClantag() end

        local LClick = client.key_state(0x01)
        local mousepos = { ui.mouse_position() }
        rawmouseposX = mousepos[1]
        rawmouseposY = mousepos[2]
        mouseposX = mousepos[1] - SpotifyIndicX
        mouseposY = mousepos[2] - SpotifyIndicY
        if ui.is_menu_open() then Dragging(); UpdateElements() end

        if ui_get(elements.ControlSwitch) then
            if NewVolume >= 100 then 
                NewVolume = 100
            elseif NewVolume <= 0 then
                NewVolume = 0
            end 
            MusicControls()
            gaySexgamer()
            VolumeHandler()
            if ui_get(elements.PlayPause) or ui_get(elements.SkipSong) or ui_get(elements.PreviousSong) or ui_get(elements.SmartControls) then
                ControlCheck = true
            else
                ControlCheck = false
            end
            
            if ui_get(elements.IncreaseVolume) or ui_get(elements.DecreaseVolume) then

                NiggerSex = true
                VolumeCheck = true
                SetCheck = false       

                if globals.tickcount() > last_update_volume_press + 64 then
                    FirstPress = false
                end
            else
                last_update_volume_press = globals.tickcount()
                FirstPress = true
                VolumeCheck = false
                StopSpamming = true
            end

            if StopSpamming == false then
                last_update_volume_set = globals.tickcount()
            end

            if FirstPress == false then
                if globals.tickcount() > last_update_volume + ui_get(elements.VolumeTickSpeed) then
                    if ui_get(elements.IncreaseVolume) then
                        NewVolume = NewVolume + ui_get(elements.VolumeTickAmount)
                    elseif ui_get(elements.DecreaseVolume) then
                        NewVolume = NewVolume - ui_get(elements.VolumeTickAmount)
                    end
                    last_update_volume = globals.tickcount()
                end
            end  
        end
    end
end

ShowMenuElements()
ui_set_callback(MainCheckbox, ShowMenuElements)
ui_set_callback(elements.ArtButton, ShowMenuElements)
ui_set_callback(elements.DebugInfo, ShowMenuElements)
ui_set_callback(elements.CustomColors, ShowMenuElements)
ui_set_callback(elements.MenuSize, ChangeMenuSize)

client.set_event_callback("paint_ui", OnFrame)
client.set_event_callback('shutdown', function()
    database_write("previous_posX", SpotifyIndicX)
    database_write("previous_posY", SpotifyIndicY)
    database_write("previous_size", SelectedSize)
    database_write("StoredKey", apikey)
    database_write("StoredKey2", refreshkey)
end)
