local api = {}

local js = panorama.open()
local http = require("gamesense/http")

local authentication = {
    status = "UNINITIALISED",
    authentication.refresh_token,
    authentication.access_token,
}

local data = {
    user,
    device_id,
    is_playing,
    song_name,
    artist_name,
    song_image,
    image_url,
    image_colours = {
        r,
        g,
        b
    },
    duration,
    timestamp,
    playlists = {},
    playlists_total,
    current_volume,
}

function api.promptlogin()
    local url = "https://spotify.stbrouwers.cc"
    local js = panorama.loadstring([[
        return {
            open_url: function(url){
                SteamOverlayAPI.OpenURL(url)
            }
        }
    ]])()
    js.open_url(page_url)
end

function api.init(rkey)
    http.get(string.format("https://spotify.stbrouwers.cc/refresh_token?refresh_token=%s", rkey), function(s, r)
        if r.status ~= 200 then
            authentication.status = "INVALID_TOKEN"
        else
            authentication.status = "TOKEN_OBTAINED"
            local jsondata = json.parse(r.body)
            authentication.refresh_token = rkey
            authentication.access_token = jsondata.access_token
            http.get(string.format("https://api.spotify.com/v1/me?access_token=%s", authentication.access_token), function(s,r)
                authentication.status = "GATHER_PROFILE
                if r.body then
                    jsondata = json.parse(r.body)
                    data.user = jsondata.display_name
                    if not data.user then
                        api.init()
                    end
                    authentication.status = "PROFILE_SAVED"
                end
            end)
        end
    end)
end

function api.update()
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

    return data
end

function api.get_data()
    return data
end

function api.playpause()
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. authentication.access_token,["Content-length"] = 0}}

    if data.is_playing then
        http.put("https://api.spotify.com/v1/me/player/pause?&device_id=" .. data.device_id, http_options, function(s, r) end)
    else
        http.put("https://api.spotify.com/v1/me/player/play?&device_id=" .. data.device_id, http_options, function(s, r) end)
    end
end

function api.play_song_playlist(pid, sid)
    local x = json.stringify({context_uri = "spotify:playlist:" .. id, offset = {position = sid-1}, position_ms = 0})
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. authentication.access_token,["Content-length"] = 0}, body = x}

    http.put("https://api.spotify.com/v1/me/player/play", http_options, function(s, r)

    end)
end

function api.queue_song(id)
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. authentication.access_token,["Content-length"] = 0}}
    http.post("https://api.spotify.com/v1/me/player/queue?uri=" .. id .. "&device_id=" .. data.device_id, http_options, function(s, r)
        
    end)
end

function api.next()
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. authentication.access_token,["Content-length"] = 0}}
    http.post("https://api.spotify.com/v1/me/player/next?device_id=" .. data.device_id, http_options, function(s, r) end) 
end

function api.previous()
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. authentication.access_token,["Content-length"] = 0}}
    http.post("https://api.spotify.com/v1/me/player/previous?device_id=" .. data.device_id, http_options, function(s, r) end) 
end

function api.volume(a)
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. authentication.access_token,["Content-length"] = 0}}
    http.put("https://api.spotify.com/v1/me/player/volume?volume_percent=" .. round(a) .. "&device_id=" .. data.device_id, http_options, function(s, r)
        UpdateCount = UpdateCount + 1
    end)
end

--bool a
function api.shuffle(a)
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. authentication.access_token,["Content-length"] = 0}}
    http.put("https://api.spotify.com/v1/me/player/shuffle?device_id=" .. data.device_id .. "&state=" .. tostring(a), http_options, function(s, r)

    end)
end

function api.repeat(a)
    if a == 0 then
        RepeatState = "off"
    elseif a == 1 then
        RepeatState = "context"
    elseif a == 2 then
        RepeatState = "track"
    end

    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. authentication.access_token,["Content-length"] = 0}}
    http.put("https://api.spotify.com/v1/me/player/repeat?device_id=" .. data.device_id .. "&state=" .. RepeatState, http_options, function(s, r)

    end)
end

function api.seek(a)
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. authentication.access_token,["Content-length"] = 0}}
    http.put("https://api.spotify.com/v1/me/player/seek?position_ms=" .. math.floor(a) .. "&device_id=" .. data.device_id, http_options, function(s, r) end)
end

function api.get_user_playlists(l, o)
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. authentication.access_token,["Content-length"] = 0}}
    http.get(string.format("https://api.spotify.com/v1/me/playlists?limit=".. l .. "&offset=".. o, http_options), function(s,r)
        if r.status == 200 then
            jsondata = json.parse(r.body)
            data.playlists_total = jsondata.total
            for i = 1, jsondata.items do
                data.playlists[i] = {
                    name = jsondata.items[i].name,
                    uri = jsondata.items[i].uri,
                    tracks = {}
                }
            end
        end
    end)
end

function api.get_playlist_tracks(id, l, o)
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. authentication.access_token, ["Content-length"] = 0}}
    http.get(string.format("https://api.spotify.com/v1/playlists/".. id .."/tracks?limit=".. l .."&offset=" .. o, http_options), function(s,r)
        if r.status == 200 then
            jsondata = json.parse(r.body)
            data.playlists[id].tracks_total = jsondata.total
            for i = 1, jsondata.items do
                data.playlists[i].tracks = {
                    name = jsondata.items[i].name,
                    artists = {jsondata.items[i].artists},
                    id = jsondata.items[i].id
                }
            end
        end
    end)
end

function api.getstatus()
    return authentication.status
end

function api.reset()
    authentication.status = "UNINITIALISED"
    authentication.access_token = ""
    authentication.refresh_token = ""
end

return api
