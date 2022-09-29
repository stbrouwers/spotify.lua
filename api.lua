local api = {}

local js = panorama.open()
local http = require("gamesense/http")

local auth = {
    status = "UNINITIALISED",
    refresh_token,
    access_token,
}

local update = {
    status = "UNINITIALISED",
    await = false,
}

local data = {
    current_user = {
        id,
        name,
        country,
        image_url,
        followers
    },
    users = {
        --id,
        --name,
        --image_url,
        --followers,
        --playlists = {}
    },
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
    playlists_user_total,
    playlists_local_total = 0,
    playlists_cached_total = 0,
    current_volume,
}

local private_data = {
    previous_song_name = "",
    playlists_next,
    playlists_tracks_next,
    playlist_exist,
    user_exist,
    playlist_data_check,
}

local function item_exists(arr, id)
    for i = 1, #arr do
        if arr[i].uri == id then
            if arr == data.playlists then
                private_data.playlist_exist = i
                client.log('playlist_exist: ' .. private_data.playlist_exist)
            elseif arr == data.users then
                private_data.user_exist = i
                client.log('user_exist: ' .. private_data.user_exist)
            else
                client.log('fuck')
                return false
            end
            return true
        end
    end
    return false
end

local function getcurrentuser()
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. auth.access_token,["Content-length"] = 0}}
    http.get("https://api.spotify.com/v1/me", http_options, function(s, r)
        if r.status == 200 then
            local jsondata = json.parse(r.body)
            data.current_user = {
                uri = jsondata.id,
                name = jsondata.display_name,
                country = jsondata.country,
                image_url = jsondata.images[1].url,
                followers = jsondata.followers.total
            }
        end
    end)
end

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

function api.get_user_profile(id)
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. auth.access_token,["Content-length"] = 0}}
    http.get("https://api.spotify.com/v1/users/"..id, http_options, function(s, r)
        if r.status == 200 then
            local jsondata = json.parse(r.body)
            data.users = {
                uri = jsondata.id,
                name = jsondata.display_name,
                image_url = jsondata.images[1].url,
                followers = jsondata.followers.total
            }
        end
    end)
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
                    data.current_user = jsondata.display_name
                    api.update()
                    if not data.current_user then
                        api.init()
                    end
                    getcurrentuser()
                    auth.status = "PROFILE_SAVED"
                end
            end)
            return auth.status
        end
    end)
end

function api.update()
    update.status = "ONGOING"
    http.get(string.format("https://api.spotify.com/v1/me/player?access_token=%s", auth.access_token), function(s,r)
        if r.status == 200 then
            client.log("Spotify API: Successfully updated")
            local jsondata = json.parse(r.body)
            data.device_id = jsondata.device.id
            data.is_playing = jsondata.is_playing
            data.song_name = jsondata.item.name
            data.artists = jsondata.item.artists
            data.album_name = jsondata.item.album.name
            data.image_url = jsondata.item.album.images[1].url
            data.duration = jsondata.item.duration_ms
            data.timestamp = jsondata.progress_ms
            data.current_volume = jsondata.device.volume_percent

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
            update.status = "COMPLETED"
            update.await = true
        else
            auth.status = "SONG_FAILURE"
            update.status = "FAILED"
        end
        return data
    end)
end

function api.get_data()
    return data
end

function api.play_pause()
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. auth.access_token,["Content-length"] = 0}}

    if data.is_playing then
        data.is_playing = false
        http.put("https://api.spotify.com/v1/me/player/pause?&device_id=" .. data.device_id, http_options, function(s, r) end)
    else
        data.is_playing = true
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

function api.get_playlist_data(id)
    if private_data.playlist_data_check ~= id and private_data.playlist_data_check ~= nil then client.log('loop still running, ignored.') return end
    local p_index
    local t_id
    local query
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. auth.access_token,["Content-length"] = 0}}

    if not item_exists(data.playlists, id) then
        p_index = data.playlists_local_total+1
        data.playlists[p_index].image_colour = "IMAGE_LOADING"
    elseif item_exists(data.playlists, id) then
        client.log(private_data.playlist_exist)
        p_index = private_data.playlist_exist
    end

    if private_data.playlists_tracks_next == nil then
        query = "https://api.spotify.com/v1/playlists/"..id
    else
        query = private_data.playlists_tracks_next
    end

    http.get(string.format(query), http_options, function(s,r)
        if r.status == 200 then
            jsondata = json.parse(r.body)

            if private_data.playlists_tracks_next == nil then
                t_id = string.gsub(jsondata.uri, "spotify:playlist:", "")
                if data.playlists[p_index].image_colour == nil or data.playlists[p_index].image_colour == "IMAGE_ERROR" then
                    http.post('https://spotify.stbrouwers.cc/image', { headers = { ['Content-Type'] = 'application/json' }, body = json.stringify({url = jsondata.images[1].url}) }, function(s, res)
                        body = json.parse(res.body)
                        if body.color then
                            local r, g ,b = body.color.r, body.color.g, body.color.b
                            data.playlists[p_index].image_colour = {r, g, b}
                        else
                            data.playlists[p_index].image_colour = "IMAGE_ERROR"
                        end
                    end)
                end 
                data.playlists[p_index] = {
                    name = jsondata.name,
                    uri = t_id,
                    owner = {
                        name = jsondata.owner.display_name,
                        uri = jsondata.owner.id,
                    },
                    is_public = jsondata.public,
                    is_collaborative = jsondata.collaborative,
                    image_url = jsondata.images[1].url,
                    image_colour = data.playlists[p_index].image_colour,
                    description = jsondata.description,
                    followers = jsondata.followers.total,
                    tracks_user_total = jsondata.tracks.total,
                    tracks_local_total = 0,
                    tracks = {},
                }
                if private_data.playlist_exist ~= id and not item_exists(data.playlists, id) then
                    data.playlists_cached_total = data.playlists_cached_total+1
                    data.playlists_local_total = p_index
                end

                for i = 1, #jsondata.tracks.items do
                    data.playlists[p_index].tracks[data.playlists[p_index].tracks_local_total+1] = {
                        uri = jsondata.tracks.items[i].track.id,
                        name = jsondata.tracks.items[i].track.name,
                        artists = {jsondata.tracks.items[i].artists},
                        images = {jsondata.tracks.items[i].track.images},
                        is_local = jsondata.tracks.items[i].track.is_local,
                        markets = jsondata.tracks.items[i].track.available_markets,
                        album = {
                            uri = jsondata.tracks.items[i].track.album.id,
                            name = jsondata.tracks.items[i].track.album.name,
                            artists = {jsondata.tracks.items[i].artists},
                            images = {jsondata.tracks.items[i].track.album.images},
                            is_local = jsondata.tracks.items[i].is_local,
                            markets = jsondata.tracks.items[i].track.available_markets,
                        }
                    }
                    data.playlists[p_index].tracks_local_total = data.playlists[p_index].tracks_local_total + 1
                end
                private_data.playlists_tracks_next = jsondata.tracks.next
            else
                for i = 1, #jsondata.items do
                    data.playlists[p_index].tracks[data.playlists[p_index].tracks_local_total+1] = {
                        uri = jsondata.items[i].track.id,
                        name = jsondata.items[i].track.name,
                        artists = {jsondata.items[i].artists},
                        images = {jsondata.items[i].track.images},
                        is_local = jsondata.items[i].track.is_local,
                        markets = jsondata.items[i].track.available_markets,
                        album = {
                            uri = jsondata.items[i].track.album.id,
                            name = jsondata.items[i].track.album.name,
                            artists = {jsondata.items[i].artists},
                            images = {jsondata.items[i].track.album.images},
                            is_local = jsondata.items[i].is_local,
                            markets = jsondata.items[i].track.available_markets,
                        }
                    }
                    data.playlists[p_index].tracks_local_total = data.playlists[p_index].tracks_local_total + 1
                end
                private_data.playlists_tracks_next = jsondata.next
            end

            if private_data.playlists_tracks_next ~= nil and data.playlists[p_index].tracks_local_total ~= data.playlists[p_index].tracks_user_total then
                private_data.playlist_data_check = id
                api.get_playlist_data(id)
            else
                private_data.playlist_data_check = nil
                private_data.playlists_tracks_next = nil
            end
        end
    end)
end

function api.get_user_playlists()
    local query
    local t_id
    local http_options = { headers = {["Accept"] = "application/json",["Content-Type"] = "application/json",["Authorization"] = "Bearer " .. auth.access_token,["Content-length"] = 0}}
    client.log(private_data.playlists_next)

    if private_data.playlists_next ~= nil then
        query = tostring(private_data.playlists_next)
    else
        query = "https://api.spotify.com/v1/me/playlists?limit=".. 10 .. "&offset=".. 0
    end

    http.get(query, http_options, function(s,r)
        if r.status == 200 then
            jsondata = json.parse(r.body)
            data.playlists_user_total = jsondata.total
            for i = 1, #jsondata.items do
                t_id = string.gsub(jsondata.items[i].uri, "spotify:playlist:", "")
                if (#jsondata.items[i].images < 1) then jsondata.items[i].images = {{url = false}, {url = false}} end
                data.playlists[data.playlists_local_total+1] = {
                    name = jsondata.items[i].name,
                    uri = t_id,
                    owner = {
                        name = jsondata.items[i].owner.display_name,
                        uri = jsondata.items[i].owner.id,
                    },
                    is_public = jsondata.items[i].public,
                    is_collaborative = jsondata.items[i].collaborative,
                    image_url = jsondata.items[i].images[1].url,
                    description = jsondata.items[i].description,
                    tracks_user_total = jsondata.items[i].tracks.total,
                    tracks_local_total = 0,
                    tracks = {},
                }
                data.playlists_local_total = data.playlists_local_total + 1
            end
            private_data.playlists_next = jsondata.next
            if jsondata.next ~= nil then
                api.get_user_playlists()
            end
        end
    end)
end

function api.authstatus()
    return auth.status
end

function api.update_await()
    local x = update.await
    update.await = false
    return x
end

function api.reset()
    auth.status = "UNINITIALISED"
    auth.access_token = ""
    auth.refresh_token = ""
    data = {}
    private_data = {}
end

return api
