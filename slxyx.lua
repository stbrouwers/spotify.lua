local http = require "gamesense/http"
local ffi = require "ffi"
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

IsNotAuthed = true

local function AuthoriseFunc()
    authkey = CP()
    http.get("https://api.spotify.com/v1/me/player?market=GB&access_token="..authkey, function(success, response)
        if not success or response.status ~= 200 then client.error_log("Failed to authenticate with Spotify servers."); IsNotAuthed = true; return end
        spotidata = json.parse(response.body)
        IsNotAuthed = false
    end)
    http.get("https://api.spotify.com/v1/me?market=GB&access_token=BQB-fa6Sov2AP7qsZ-U8mi-U23P5CedUXjYNHHMR5I0CVabCqcsJ0AF0xXf0WREMxPUe3snhgO55JNFwWYmCNBVoAUAX5NteXyQVmuvSFVX5_bUq0Baeqi_TU_kNzTLoVeQuHHd1gs9GMttVurypA03rJoRcov78Gsc4rHT45IM", function(success, response)
        if not success or response.status ~= 200 then client.error_log("Failed to authenticate with Spotify servers."); IsNotAuthed = true; return end
        spotidata2 = json.parse(response.body)
        IsNotAuthed = false
    end)
end

local labelcol = ui.new_label("MISC", "Miscellaneous", "Spotify Progress Colour")
local col = ui.new_color_picker("MISC", "Miscellaneous", "Spotify Progress Colourr", 0, 255, 0, 255)
local auth = ui.new_button("MISC", "Miscellaneous", "Authorise", AuthoriseFunc)

local last_update = client.unix_time()
client.set_event_callback("paint_ui", function()
    ui.set_visible(auth, IsNotAuthed)
    if not spotidata and not spotidata2 then return end
    if client.unix_time() > last_update + 1 then
        AuthoriseFunc()
        last_update = client.unix_time()
    end
    if spotidata.is_playing and renderer.measure_text("b", "Now Playing: "..spotidata.item.name.." by "..spotidata.item.artists[1].name)+10 > renderer.measure_text("b", "Connected to: "..spotidata2.display_name)+10 then
        textmeasurement = renderer.measure_text("b", "Now Playing: "..spotidata.item.name.." by "..spotidata.item.artists[1].name)+10
    elseif spotidata.is_playing and renderer.measure_text("b", "Now Playing: "..spotidata.item.name.." by "..spotidata.item.artists[1].name)+10 < renderer.measure_text("b", "Connected to: "..spotidata2.display_name)+10 then
        textmeasurement = renderer.measure_text("b", "Connected to: "..spotidata2.display_name)+10
    elseif not spotidata.is_playing then
        textmeasurement = renderer.measure_text("b", "Connected to: "..spotidata2.display_name)+10
    end
    r, g, b, a = ui.get(col)
    renderer.gradient(0, 70, textmeasurement, 32, 0, 22, 22, 255, 22, 22, 22, 10, true)
    renderer.rectangle(0, 70, 2, 32, r, g, b, a)
    renderer.gradient(0, 70, spotidata.progress_ms/spotidata.item.duration_ms*textmeasurement, 2, r, g, b, a, r, g, b, 0, true)
    renderer.gradient(0, 100, spotidata.progress_ms/spotidata.item.duration_ms*textmeasurement, 2, r, g, b, a, r, g, b, 0, true)
    renderer.text(5, 75, 255, 255, 255, 255, "b", 0, "Connected to: "..spotidata2.display_name)
    if spotidata.is_playing then
        renderer.text(5, 85, 255, 255, 255, 255, "b", 0, "Now Playing: "..spotidata.item.name.." by "..spotidata.item.artists[1].name)
    else
        renderer.text(5, 85, 255, 255, 255, 255, "b", 0, "Paused")
    end
    --renderer.rectangle(95, 100, spotidata.progress_ms/spotidata.item.duration_ms*textmeasurement, 3, 0, 255, 0, 255)
    --renderer.circle_outline(200, 200, 0, 255, 0, 255, 10, -90, spotidata.progress_ms/spotidata.item.duration_ms, 4)
end)
