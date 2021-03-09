local surface = require "gamesense/surface"
local TitleFont = surface.create_font("GothamBookItalic", 26, 900, 0x010)
local ArtistFont = surface.create_font("GothamBookItalic", 17, 600, 0x010)

local database_read = database.read
local database_write = database.write
local ui_set_callback = ui.set_callback
local ui_set_visible = ui.set_visible
local ui_get = ui.get

local MainCheckbox = ui.new_checkbox("MISC", "Miscellaneous", "Spotify")

local SpotifyIndicX = database_read("previous_posX") or 0
local SpotifyIndicY = database_read("previous_posY") or 1020
local SizePerc = database_read("previous_size") or 30

dragging = false
Authed = false
CornerReady = false

Cornereg = "NONE"

AuthURL = "https://accounts.spotify.com/en/authorize?response_type=token&redirect_uri=https:%2F%2Fdeveloper.spotify.com%2Fcallback&client_id=774b29d4f13844c495f206cafdad9c86&scope=user-read-currently-playing%20user-read-playback-state%20user-read-playback-position%20user-modify-playback-state%20playlist-read-private%20user-read-private%20user-read-recently-played%20playlist-read-collaborative%20user-library-read%20user-top-read&state=cybpef"


if database_read("previous_posX") >= 1920 then
    SpotifyIndicX = 0
    SpotifyIndicY = 1020
end

local function Auth() 


    Authed = true
    ShowMenuElements()
end

local elements = {
    AuthButton = ui.new_button("MISC", "Miscellaneous", "Authorize", Auth),
    Cornerswitch = ui.new_checkbox("MISC", "Miscellaneous", "Stick to corner"),
    SizeSlider = ui.new_slider("MISC", "Miscellaneous", "Size", 30, 100, SizePerc, true, "%", 1)
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
        else
            ui_set_visible(elements.AuthButton, false)
            ui_set_visible(elements.SizeSlider, true)
            ui_set_visible(elements.Cornerswitch, true)
        end

        if ui_get(elements.Cornerswitch) then
            ui_set_visible(elements.SizeSlider, false)
        end

    else
        ui_set_visible(elements.AuthButton, false)
        ui_set_visible(elements.SizeSlider, false)
        ui_set_visible(elements.Cornerswitch, false)
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

local function DrawNowPlaying(x, y, w, h, r, g, b, a)
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
        end
    end
end

ShowMenuElements()
ui_set_callback(MainCheckbox, ShowMenuElements)
ui_set_callback(elements.Cornerswitch, ShowMenuElements)


client.set_event_callback("paint_ui", OnFrame)

client.set_event_callback('shutdown', function()
    database_write("previous_posX", SpotifyIndicX)
    database_write("previous_posY", SpotifyIndicY)
    database_write("previous_size", SelectedSize)
end)
