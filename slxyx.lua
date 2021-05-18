apikey = database.read("StoredKey")
refreshkey = database.read("StoredKey2")
timeCheck = 0
x = 100
y = 100
start_time = globals.realtime()
CurrentSong = "Taliban nigger child"
local http = require "gamesense/http"
local images = require "gamesense/images"
local ffi = require "ffi"
local gif_decoder = require "gamesense/gif_decoder"

ffi.cdef[[
typedef void***(__thiscall* FindHudElement_t)(void*, const char*);
typedef void(__cdecl* ChatPrintf_t)(void*, int, int, const char*, ...);
]]
local signature_gHud = "\xB9\xCC\xCC\xCC\xCC\x88\x46\x09"
local signature_FindElement = "\x55\x8B\xEC\x53\x8B\x5D\x08\x56\x57\x8B\xF9\x33\xF6\x39\x77\x28"
local match = client.find_signature("client_panorama.dll", signature_gHud) or error("sig1 not found")
local hud = ffi.cast("void**", ffi.cast("char*", match) + 1)[0] or error("hud is nil")
match = client.find_signature("client_panorama.dll", signature_FindElement) or error("FindHudElement not found")
local find_hud_element = ffi.cast("FindHudElement_t", match)
local hudchat = find_hud_element(hud, "CHudChat") or error("CHudChat not found")
local chudchat_vtbl = hudchat[0] or error("CHudChat instance vtable is nil")
local print_to_chat = ffi.cast("ChatPrintf_t", chudchat_vtbl[27])

local function print_chat(text)
    print_to_chat(hudchat, 0, 0, text)
end

local function roundedRectangle(x, y, w, h, r, g, b, a, cut, circle)
    renderer.rectangle(x, y, w, h, r, g, b, a)

    if cut ~= "t" then
        renderer.circle(x, y, r-8, g-8, b-8, a, circle, -180, 0.25)
        renderer.circle(x + w, y, r-8, g-8, b-8, a, circle, 90, 0.25)
        renderer.rectangle(x, y - circle, w, circle, r, g, b, a)
    end

    if cut ~= "b" then
        renderer.circle(x + w, y + h, r-8, g-8, b-8, a, circle, 0, 0.25)
        renderer.circle(x, y + h, r-8, g-8, b-8, a, circle, -90, 0.25)
        renderer.rectangle(x, y + h, w, circle, r, g, b, a)
    end
    renderer.rectangle(x - circle, y, circle, h, r, g, b, a)
    renderer.rectangle(x + w, y, circle, h, r, g, b, a)
    
end

function getInfo()
    http.get("https://api.spotify.com/v1/me/player?access_token=" .. apikey, function(success, response)
        if response.body ~= nil then
            CurrentDataSpotify = json.parse(response.body)
            SongName = CurrentDataSpotify.item.name
            ArtistName = CurrentDataSpotify.item.artists[1].name
            if not CurrentDataSpotify.item.is_local then
                ThumbnailUrl = CurrentDataSpotify.item.album.images[1].url
                http.get(ThumbnailUrl, function(success, response)
                    if not success or response.status ~= 200 then
                      return
                    end
                Thumbnail = images.load_jpg(response.body)
                end)
            end
        else
            http.get("https://spotify.stbrouwers.cc/refresh_token?refresh_token="..refreshkey)
        end
    end)
end

function getAstley()
    http.get("http://niggascripts.tech/asstley.gif", function(success, response)
        if response.body ~= nil then
            gif1 = gif_decoder.load_gif(response.body)
        end
    end)
end

getAstley()

function renderIndicator()
    mouseposx, mouseposy = ui.mouse_position()
    if timeCheck < client.unix_time() then
        getInfo()
        timeCheck = client.unix_time() + 1
    end
    if not CurrentDataSpotify or not Thumbnail then return end
    roundedRectangle(x, y+170, 100, 50, 255, 255, 255, 255, "t", 8)
    roundedRectangle(x, y, 100, 220, 255, 255, 255, 255, "b", 8)
    --renderer.text(x+50, y+120, 0, 0, 0, 255, "cbd", 0, SongName)
    --renderer.text(x+50, y+135, 0, 0, 0, 255, "cd", 0, ArtistName)
    renderer.circle_outline(x+50, y+160, 171, 171, 171, 255, 50, 0, 1, 30)
    function lmaoboxCrack()
        renderer.rectangle(x, y, 100, 100, 13, 13, 13, 255)
        renderer.circle_outline(x+50, y+50, 26, 26, 26, 255, 40, 0, 1, 3)
        renderer.circle_outline(x+50, y+50, 26, 26, 26, 255, 10, 0, 1, 3)
        Thumbnail:draw(x, y, 100, 100)
    end
    if client.key_state(0x01) and mouseposy <= y+150 and mouseposy >= y and mouseposx <= x+100 and mouseposx >= x then
        x = mouseposx - 50
        y = mouseposy - 75
    end
    status, retval = pcall(lmaoboxCrack)
    if ArtistName == "Bladee" or ArtistName == "100 gecs" then
        for i = 1, 20 do
            renderer.text(math.random(0,1920), math.random(0,1920), math.random(0,255), math.random(0,255), math.random(0,255), 255, "+b", 0, "KILL YOURSELF")
        end
    end
    if SongName == "Never Gonna Give You Up" then
        if ui.is_menu_open() and gif1 ~= nil then
            local mx, my = ui.menu_position()
            local mw, mh = ui.menu_size()
    
            -- draw gif at top right corner of the menu
            gif1:draw(globals.realtime()-start_time, 0, 0, 1920, 1080, 255, 255, 255, 255)
        end
    end
    if CurrentSong ~= SongName then
        print_chat(" \x06[spotify.lua] ♫ \x01Changed song to "..SongName.." by "..ArtistName)
        CurrentSong = SongName
    end
end

client.set_event_callback("paint_ui", renderIndicator)
