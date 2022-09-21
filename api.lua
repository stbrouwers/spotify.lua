local api = {}

local js = panorama.open()
local http = require("gamesense/http")

local auth = {
    status = "UNINITIALISED",
    refresh_token,
    access_token,
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
    playlists_local_total = 0,
    current_volume,
}

local private_data = {
    previous_song_name = "",
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
    js.open_url(url)
    auth.status = "OPENED_BROWSER"
end

function api.init(rkey)
    auth.status = "AUTHENTICATING"
    http.get(string.format("https://spotify.stbrouwers.cc/refresh_token?refresh_token=%s", rkey), function(s, r)
        if r.status ~= 200 then
            auth.status = "INVALID_TOKEN"
            return auth.status
        else
            auth.status = "TOKEN_OBTAINED"
            local jsondata = json.parse(r.body)
            auth.refresh_token = rkey
            auth.access_token = jsondata.access_token
            http.get(string.format("https://api.spotify.com/v1/me?access_token=%s", auth.access_token), function(s,r)
                auth.status = "GATHER_PROFILE"
                if r.body then
                    jsondata = json.parse(r.body)
                    data.user = jsondata.display_name
                    api.update()
                    if not data.user then
                        api.init()
                    end
                    auth.status = "PROFILE_SAVED"
                end
            end)
            return auth.status
        end
    end)
end

function api.update()
    http.get(string.format("https://api.spotify.com/v1/me/player?access_token=%s", auth.access_token), function(s,r)
        if r.status == 200 then
            client.log("Spotify API: Successfully updated")
            jsondata = json.parse(r.body)
            data.device_id = jsondata.device.id
            data.is_playing = jsondata.is_playing
            data.song_name = jsondata.item.name
            data.artists = jsondata.item.artists
            data.album_name = jsondata.item.album.name
            data.image_url = jsondata.item.album.images[1].url
            data.duration = jsondata.item.duration_ms
            data.timestamp = jsondata.progress_ms
            http.get(jsondata.item.album.images[1].url, function(success, response)
                if r.status == 200 then
                    data.song_image = response.body
                end
            end)

            if private_data.previous_song_name ~= data.song_name then
                private_data.previous_song_name = data.song_name
                http.post('https://spotify.stbrouwers.cc/image', { headers = { ['Content-Type'] = 'application/json' }, body = json.stringify({url = data.image_url}) }, function(s, res)
                    body = json.parse(res.body)
                    if body.color then
                        data.image_colours.r, data.image_colours.g, data.image_colours.b = body.color.r, body.color.g, body.color.b
                    end
                end)
            end
            auth.status = "COMPLETED"

        else
            auth.status = "SONG_FAILURE"
        end
    end)

    return data
end

function api.get_data()
    return data
end

function api.playpause()
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. auth.access_token,["Content-length"] = 0}}

    if data.is_playing then
        http.put("https://api.spotify.com/v1/me/player/pause?&device_id=" .. data.device_id, http_options, function(s, r) end)
    else
        http.put("https://api.spotify.com/v1/me/player/play?&device_id=" .. data.device_id, http_options, function(s, r) end)
    end
end

function api.play_song(id)
    local x = json.stringify({context_uri = "spotify:track:" .. id, position_ms = 0})
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. auth.access_token,["Content-length"] = 0}, body = x}
    http.put("https://api.spotify.com/v1/me/player/play", http_options, function(s, r) 
        print(r.body)
    end)
end

function api.play_song_playlist(pid, sid)
    local x = json.stringify({context_uri = "spotify:playlist:" .. id, offset = {position = sid-1}, position_ms = 0})
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. auth.access_token,["Content-length"] = 0}, body = x}

    http.put("https://api.spotify.com/v1/me/player/play", http_options, function(s, r)

    end)
end

function api.queue_song(id) -- not working
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. auth.access_token,["Content-length"] = 0}}
    http.post("https://api.spotify.com/v1/me/player/queue?uri=" .. id .. "&device_id=" .. data.device_id, http_options, function(s, r)
        
    end)
end

function api.next()
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. auth.access_token,["Content-length"] = 0}}
    http.post("https://api.spotify.com/v1/me/player/next?device_id=" .. data.device_id, http_options, function(s, r) end) 
end

function api.previous()
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. auth.access_token,["Content-length"] = 0}}
    http.post("https://api.spotify.com/v1/me/player/previous?device_id=" .. data.device_id, http_options, function(s, r) end) 
end

function api.volume(a)
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. auth.access_token,["Content-length"] = 0}}
    http.put("https://api.spotify.com/v1/me/player/volume?volume_percent=" .. math.floor(a) .. "&device_id=" .. data.device_id, http_options, function(s, r)
    end)
end

--bool a
function api.shuffle(a) -- not working
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. auth.access_token,["Content-length"] = 0}}
    http.put("https://api.spotify.com/v1/me/player/shuffle?device_id=" .. data.device_id .. "&state=" .. tostring(a), http_options, function(s, r)

    end)
end

--[[function api.repeat(a)
    if a == 0 then
        RepeatState = "off"
    elseif a == 1 then
        RepeatState = "context"
    elseif a == 2 then
        RepeatState = "track"
    end

    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. auth.access_token,["Content-length"] = 0}}
    http.put("https://api.spotify.com/v1/me/player/repeat?device_id=" .. data.device_id .. "&state=" .. RepeatState, http_options, function(s, r)

    end)
end]]

function api.seek(a)
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. auth.access_token,["Content-length"] = 0}}
    http.put("https://api.spotify.com/v1/me/player/seek?position_ms=" .. math.floor(a) .. "&device_id=" .. data.device_id, http_options, function(s, r) end)
end

function api.get_user_playlists(l, o)
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. auth.access_token,["Content-length"] = 0}}
    http.get("https://api.spotify.com/v1/me/playlists?limit=".. l .. "&offset=".. o, http_options, function(s,r)
        if r.status == 200 then
            jsondata = json.parse(r.body)
            data.playlists_user_total = jsondata.total
            for i = 1, #jsondata.items do
                data.playlists[i] = {
                    name = jsondata.items[i].name,
                    uri = jsondata.items[i].uri,
                    tracks = {}
                }
                data.playlists_local_total = data.playlists_local_total + 1
            end
        end
    end)
end

function api.get_playlist_tracks(id, l, o)
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. auth.access_token, ["Content-length"] = 0}}
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

function api.status()
    return auth.status
end

function api.reset()
    auth.status = "UNINITIALISED"
    auth.access_token = ""
    auth.refresh_token = ""
end

return api
