-- This is a fucking mess but whatever I guess

local ffi = require("ffi")

ffi.cdef[[
    short GetAsyncKeyState(int);
    int GetForegroundWindow(void);
    int FindWindowA(const char*, const char*);
]]

local function game_is_active()
    local hWndForeGround = ffi.C.GetForegroundWindow();
    local hWndFound = ffi.C.FindWindowA("Valve001", nil);

    return (hWndForeGround == hWndFound) and hWndForeGround ~= nil;
end

local InputSystem = {}
InputSystem.__index = InputSystem

function InputSystem.init()
    local self = setmetatable({
        has_been_pressed = {},
        key_was_down = {},
        drag_table = {},
    }, InputSystem)

    return self
end

function InputSystem:register_key(key)
    if self.has_been_pressed[key] == nil then
        self.has_been_pressed[key] = false
    end

    if self.key_was_down[key] == nil then
        self.key_was_down[key] = false
    end
end

function InputSystem:register_dragging(index)
    local tbl = self.drag_table

    if not tbl[index] then
        tbl[index] = {
            delta_position = {x = 0, y = 0},
            mouse_down_outside = false,
            mouse_down_inside = false
        }
    end

    return tbl[index]
end

function InputSystem:is_key_held(key)
    if ffi.C.GetAsyncKeyState(key) ~= 0 and game_is_active() and cheat.IsMenuVisible() then
        return true
    end

    return false
end

function InputSystem:is_key_pressed(key)
    self:register_key(key)
    
    if self:is_key_held(key) and not self.has_been_pressed[key] then
        self.has_been_pressed[key] = true
        return true
    elseif not self:is_key_held(key) then
        self.has_been_pressed[key] = false
    end

    return false
end

function InputSystem:is_key_released(key)
    self:register_key(key)
    
    if self:is_key_held(key) then
        self.key_was_down[key] = true
    elseif not self:is_key_held(key) and self.key_was_down[key] then
        self.key_was_down[key] = false
        return true
    end

    return false
end

function InputSystem:is_mouse_in_area(x, y, w, h)
    local mouse_pos = cheat.GetMousePos()

    return ((mouse_pos.x >= x and mouse_pos.x < x + w and mouse_pos.y >= y and mouse_pos.y < y + h) and cheat.IsMenuVisible())
end

function InputSystem:handle_dragging(index, x, y, w, h)
    local mouse_pos = cheat.GetMousePos()
    local tbl = self:register_dragging(index)

    if not self:is_key_held(1) then
        tbl.mouse_down_outside = false
        tbl.mouse_down_inside = false
    end

    if not self:is_mouse_in_area(x, y, w, h) then
        tbl.mouse_down_outside = true
    elseif not tbl.mouse_down_inside and not tbl.mouse_down_outside then
        tbl.mouse_down_inside = true
    
        tbl.delta_position.x = mouse_pos.x - x
        tbl.delta_position.y = mouse_pos.y - y
    end

    if tbl.mouse_down_inside then
        x = mouse_pos.x - tbl.delta_position.x
        y = mouse_pos.y - tbl.delta_position.y
    end

    return x, y, x + w, y + h
end

function InputSystem:is_mouse_in_area_vec(pos1, pos2)
    local mouse_pos = cheat.GetMousePos()

    return ((mouse_pos.x >= pos1.x and mouse_pos.x < pos2.x and mouse_pos.y >= pos1.y and mouse_pos.y < pos2.y) and cheat.IsMenuVisible())
end

function InputSystem:handle_dragging_vec(index, pos1, pos2)
    local mouse_pos = cheat.GetMousePos()
    local tbl = self:register_dragging(index)

    if not self:is_key_held(1) then
        tbl.mouse_down_outside = false
        tbl.mouse_down_inside = false
    end

    if not self:is_mouse_in_area_vec(pos1, pos2) then
        tbl.mouse_down_outside = true
    elseif not tbl.mouse_down_inside and not tbl.mouse_down_outside then
        tbl.mouse_down_inside = true
    
        tbl.delta_position.x = mouse_pos.x - pos1.x
        tbl.delta_position.y = mouse_pos.y - pos1.y
    end

    if tbl.mouse_down_inside then
        pos2.x = pos2.x - (pos1.x - (mouse_pos.x - tbl.delta_position.x))
        pos2.y = pos2.y - (pos1.y - (mouse_pos.y - tbl.delta_position.y))

        pos1.x = mouse_pos.x - tbl.delta_position.x
        pos1.y = mouse_pos.y - tbl.delta_position.y
    end
end

local filesystem = utils.CreateInterface("filesystem_stdio.dll", "VBaseFileSystem011")
local filesystem_class = ffi.cast(ffi.typeof("void***"), filesystem)
local filesystem_vftbl = filesystem_class[0]

local func_read_file = ffi.cast("int (__thiscall*)(void*, void*, int, void*)", filesystem_vftbl[0])
local func_write_file = ffi.cast("int (__thiscall*)(void*, void const*, int, void*)", filesystem_vftbl[1])

local func_open_file = ffi.cast("void* (__thiscall*)(void*, const char*, const char*, const char*)", filesystem_vftbl[2])
local func_close_file = ffi.cast("void (__thiscall*)(void*, void*)", filesystem_vftbl[3])

local func_get_file_size = ffi.cast("unsigned int (__thiscall*)(void*, void*)", filesystem_vftbl[7])
local func_file_exists = ffi.cast("bool (__thiscall*)(void*, const char*, const char*)", filesystem_vftbl[10])

local full_filesystem = utils.CreateInterface("filesystem_stdio.dll", "VFileSystem017")
local full_filesystem_class = ffi.cast(ffi.typeof("void***"), full_filesystem)
local full_filesystem_vftbl = full_filesystem_class[0]

local func_add_search_path = ffi.cast("void (__thiscall*)(void*, const char*, const char*, int)", full_filesystem_vftbl[11])
local func_remove_search_path = ffi.cast("bool (__thiscall*)(void*, const char*, const char*)", full_filesystem_vftbl[12])

local func_remove_file = ffi.cast("void (__thiscall*)(void*, const char*, const char*)", full_filesystem_vftbl[20])
local func_rename_file = ffi.cast("bool (__thiscall*)(void*, const char*, const char*, const char*)", full_filesystem_vftbl[21])
local func_create_dir_hierarchy = ffi.cast("void (__thiscall*)(void*, const char*, const char*)", full_filesystem_vftbl[22])
local func_is_directory = ffi.cast("bool (__thiscall*)(void*, const char*, const char*)", full_filesystem_vftbl[23])

local func_find_first = ffi.cast("const char* (__thiscall*)(void*, const char*, int*)", full_filesystem_vftbl[32])
local func_find_next = ffi.cast("const char* (__thiscall*)(void*, int)", full_filesystem_vftbl[33])
local func_find_is_directory = ffi.cast("bool (__thiscall*)(void*, int)", full_filesystem_vftbl[34])
local func_find_close = ffi.cast("void (__thiscall*)(void*, int)", full_filesystem_vftbl[35])

local MODES = {
    ["r"] = "r",
    ["w"] = "w",
    ["a"] = "a",
    ["r+"] = "r+",
    ["w+"] = "w+",
    ["a+"] = "a+",
    ["rb"] = "rb",
    ["wb"] = "wb",
    ["ab"] = "ab",
    ["rb+"] = "rb+",
    ["wb+"] = "wb+",
    ["ab+"] = "ab+",
}

local FileSystem = {}
FileSystem.__index = FileSystem

function FileSystem.exists(file, path_id)
    return func_file_exists(filesystem_class, file, path_id)
end

function FileSystem.rename(old_path, new_path, path_id)
    func_rename_file(full_filesystem_class, old_path, new_path, path_id)
end

function FileSystem.remove(file, path_id)
    func_remove_file(full_filesystem_class, file, path_id)
end

function FileSystem.create_directory(path, path_id)
    func_create_dir_hierarchy(full_filesystem_class, path, path_id)
end

function FileSystem.is_directory(path, path_id)
    return func_is_directory(full_filesystem_class, path, path_id)
end

function FileSystem.find_first(path)
    local handle = ffi.new("int[1]")
    local file = func_find_first(full_filesystem_class, path, handle)
    if file == ffi.NULL then return nil end

    return handle, ffi.string(file)
end

function FileSystem.find_next(handle)
    local file = func_find_next(full_filesystem_class, handle)
    if file == ffi.NULL then return nil end

    return ffi.string(file)
end

function FileSystem.find_is_directory(handle)
    return func_find_is_directory(full_filesystem_class, handle)
end

function FileSystem.find_close(handle)
    func_find_close(full_filesystem_class, handle)
end

function FileSystem.add_search_path(path, path_id, type)
    func_add_search_path(full_filesystem_class, path, path_id, type)
end

function FileSystem.remove_search_path(path, path_id)
    func_remove_search_path(full_filesystem_class, path, path_id)
end

function FileSystem.get_neverlose_path()
    return g_EngineClient:GetGameDirectory():sub(1, -5) .. "nl\\"
end

function FileSystem.open(file, mode, path_id)
    if not MODES[mode] then error("Invalid mode!") end
    local self = setmetatable({
        file = file,
        mode = mode,
        path_id = path_id,
        handle = func_open_file(filesystem_class, file, mode, path_id)
    }, FileSystem)

    return self
end

function FileSystem:get_size()
    return func_get_file_size(filesystem_class, self.handle)
end

function FileSystem:write(buffer)
    func_write_file(filesystem_class, buffer, #buffer, self.handle)
end

function FileSystem:read()
    local size = self:get_size()
    local output = ffi.new("char[?]", size + 1)
    func_read_file(filesystem_class, output, size, self.handle)

    return ffi.string(output)
end

function FileSystem:close()
    func_close_file(filesystem_class, self.handle)
end

local Timer = {}
Timer.__index = Timer

function Timer.create(milliseconds, func)
    local self = setmetatable({
        callback = func,
        milliseconds = milliseconds,
        old_milliseconds = milliseconds,
        curtime = g_GlobalVars.realtime,
        oldtime = 0 - milliseconds,
        
    }, Timer)

    return self
end

function Timer:update()
    self.curtime = g_GlobalVars.realtime
    if self.curtime >= self.oldtime + self.milliseconds then
        local return_val = self.callback()
        if return_val then
            if return_val ~= true and return_val > 1 then
                self:changeUpdateTime(return_val)
            else
                self.milliseconds = self.old_milliseconds
                self.oldtime = self.curtime
            end
        end
    end
end

function Timer:changeUpdateTime(milliseconds)
    if self.milliseconds == self.old_milliseconds then
        self.old_milliseconds = self.milliseconds
    end

    self.milliseconds = milliseconds
    self.oldtime = g_GlobalVars.realtime
end

local Cryption = {}

local Key53 = 5136466140843921
local Key14 = 6472
local inv256 = nil

Cryption.encode = function(str)
    if not inv256 then
    inv256 = {}
    for M = 0, 127 do
        local inv = -1
        repeat inv = inv + 2
        until inv * (2*M + 1) % 256 == 1
        inv256[M] = inv
    end
    end
    local K, F = Key53, 16384 + Key14
    return (str:gsub('.',
    function(m)
        local L = K % 274835406221
        local H = (K - L) / 274835406221
        local M = H % 128
        m = m:byte()
        local c = (m * inv256[M] - (H - M) / 128) % 256
        K = L * F + H + c + m
        return ('%02x'):format(c)
    end
    ))
end

Cryption.decode = function(str)
    local K, F = Key53, 16384 + Key14
    return (str:gsub('%x%x',
    function(c)
        local L = K % 274835406221
        local H = (K - L) / 274835406221
        local M = H % 128
        c = tonumber(c, 16)
        local m = (c + (H - M) / 128) * (2*M + 1) % 256
        K = L * F + H + c + m
        return string.char(m)
    end
    ))
end

local JSON = {}

local function kind_of(obj)
  if type(obj) ~= 'table' then return type(obj) end
  local i = 1
  for _ in pairs(obj) do
    if obj[i] ~= nil then i = i + 1 else return 'table' end
  end
  if i == 1 then return 'table' else return 'array' end
end

local function escape_str(s)
  local in_char  = {'\\', '"', '/', '\b', '\f', '\n', '\r', '\t'}
  local out_char = {'\\', '"', '/',  'b',  'f',  'n',  'r',  't'}
  for i, c in ipairs(in_char) do
    s = s:gsub(c, '\\' .. out_char[i])
  end
  return s
end

local function skip_delim(str, pos, delim, err_if_missing)
  pos = pos + #str:match('^%s*', pos)
  if str:sub(pos, pos) ~= delim then
    if err_if_missing then
      error('Expected ' .. delim .. ' near position ' .. pos)
    end
    return pos, false
  end
  return pos + 1, true
end

local function parse_str_val(str, pos, val)
  val = val or ''
  local early_end_error = 'End of input found while parsing string.'
  if pos > #str then error(early_end_error) end
  local c = str:sub(pos, pos)
  if c == '"'  then return val, pos + 1 end
  if c ~= '\\' then return parse_str_val(str, pos + 1, val .. c) end
  local esc_map = {b = '\b', f = '\f', n = '\n', r = '\r', t = '\t'}
  local nextc = str:sub(pos + 1, pos + 1)
  if not nextc then error(early_end_error) end
  return parse_str_val(str, pos + 2, val .. (esc_map[nextc] or nextc))
end

local function parse_num_val(str, pos)
  local num_str = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
  local val = tonumber(num_str)
  if not val then error('Error parsing number at position ' .. pos .. '.') end
  return val, pos + #num_str
end

function JSON.stringify(obj, as_key)
  local s = {}
  local kind = kind_of(obj) 
  if kind == 'array' then
    if as_key then error('Can\'t encode array as key.') end
    s[#s + 1] = '['
    for i, val in ipairs(obj) do
      if i > 1 then s[#s + 1] = ', ' end
      s[#s + 1] = JSON.stringify(val)
    end
    s[#s + 1] = ']'
  elseif kind == 'table' then
    if as_key then error('Can\'t encode table as key.') end
    s[#s + 1] = '{'
    for k, v in pairs(obj) do
      if #s > 1 then s[#s + 1] = ', ' end
      s[#s + 1] = JSON.stringify(k, true)
      s[#s + 1] = ':'
      s[#s + 1] = JSON.stringify(v)
    end
    s[#s + 1] = '}'
  elseif kind == 'string' then
    return '"' .. escape_str(obj) .. '"'
  elseif kind == 'number' then
    if as_key then return '"' .. tostring(obj) .. '"' end
    return tostring(obj)
  elseif kind == 'boolean' then
    return tostring(obj)
  elseif kind == 'nil' then
    return 'null'
  else
    error('Unjsonifiable type: ' .. kind .. '.')
  end
  return table.concat(s)
end

JSON.null = {}

function JSON.parse(str, pos, end_delim)
  pos = pos or 1
  if pos > #str then error('Reached unexpected end of input.') end
  local pos = pos + #str:match('^%s*', pos)
  local first = str:sub(pos, pos)
  if first == '{' then
    local obj, key, delim_found = {}, true, true
    pos = pos + 1
    while true do
      key, pos = JSON.parse(str, pos, '}')
      if key == nil then return obj, pos end
      if not delim_found then error('Comma missing between object items.') end
      pos = skip_delim(str, pos, ':', true)
      obj[key], pos = JSON.parse(str, pos)
      pos, delim_found = skip_delim(str, pos, ',')
    end
  elseif first == '[' then
    local arr, val, delim_found = {}, true, true
    pos = pos + 1
    while true do
      val, pos = JSON.parse(str, pos, ']')
      if val == nil then return arr, pos end
      if not delim_found then error('Comma missing between array items.') end
      arr[#arr + 1] = val
      pos, delim_found = skip_delim(str, pos, ',')
    end
  elseif first == '"' then
    return parse_str_val(str, pos + 1)
  elseif first == '-' or first:match('%d') then
    return parse_num_val(str, pos)
  elseif first == end_delim then
    return nil, pos + 1
  else
    local literals = {['true'] = true, ['false'] = false, ['null'] = JSON.null}
    for lit_str, lit_val in pairs(literals) do
      local lit_end = pos + #lit_str - 1
      if str:sub(pos, lit_end) == lit_str then return lit_val, lit_end + 1 end
    end
    return nil
  end
end

local func_change_clantag = utils.PatternScan("engine.dll", "53 56 57 8B DA 8B F9 FF 15")
local set_clantag = ffi.cast("int(__fastcall*)(const char*, const char*)", func_change_clantag)

local vgui_system010 = utils.CreateInterface("vgui2.dll", "VGUI_System010")
local vgui_system010_class = ffi.cast(ffi.typeof("void***"), vgui_system010)
local vgui_system010_vftbl = vgui_system010_class[0]

local func_get_clipboard_text_count =  ffi.cast("int(__thiscall*)(void*)", vgui_system010_vftbl[7])
local func_set_clipboard_text =  ffi.cast("void(__thiscall*)(void*, const char*, int)", vgui_system010_vftbl[9])
local func_get_clipboard_text = ffi.cast("int(__thiscall*)(void*, int, const char*, int)", vgui_system010_vftbl[11])

local screen_size = g_EngineClient:GetScreenSize()
local cfg_path = FileSystem.get_neverlose_path()
local file_path = cfg_path .. "spotifyV1_5"
FileSystem.add_search_path(cfg_path, "GAME", 0)

local function table_clone(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local font_sizes = {
    song = 20 * 2,
    artist = 12 * 2,
    duration = 16 * 2,
    minimalist = 12,
}

local default_colors = {
    title = Color.new(1.0, 1.0, 1.0, 1.0),
    artist = Color.new(0.8, 0.8, 0.8, 1.0),
    duration = Color.new(0.7, 0.7, 0.7, 1.0),
    container = Color.new(24 / 255, 24 / 255, 24 / 255, 1),
    progressbar1 = Color.new(29 / 255, 185 / 255, 84 / 255, 1.0),
    progressbar2 = Color.new(83 / 255, 83 / 255, 83 / 255, 1.0),
    minimalist_text = Color.new(1.0, 1.0, 1.0, 1.0),
    minimalist_container = Color.new(0.0, 0.0, 0.0, 0.7),
    minimalist_outline = Color.new(29 / 255, 185 / 255, 84 / 255, 1.0)
}

local colors = table_clone(default_colors)

local cfg_window_enable = menu.Switch("Spotify Window", "Enable", false)
local cfg_window_hide = menu.Switch("Spotify Window", "Hide in main menu", false)
local cfg_window_minimalist = menu.Switch("Spotify Window", "Minimalist style", false)
local cfg_window_position_x = menu.SliderInt("Spotify Window", "X-Axis", 0, 0, screen_size.x)
local cfg_window_position_y = menu.SliderInt("Spotify Window", "Y-Axis", 0, 0, screen_size.y)
local cfg_window_scale = menu.SliderInt("Spotify Window", "Scale", 100, 75, 200)
local cfg_window_width = menu.SliderInt("Spotify Window", "Max Width", 310, 300, 500, "Min Value = Automatic\nDefault = 310")
local cfg_window_cover = menu.Combo("Spotify Window", "Cover art", {"Off", "Left", "Right"}, 1)
local cfg_window_duration = menu.Switch("Spotify Window", "Show duration", true)
local cfg_window_clantag = menu.Switch("Spotify Window", "Currently playing clantag", false)

local cfg_window_colors_rainbow = menu.Switch("Spotify Colors", "Rainbow mode", false)
local cfg_window_colors = menu.Switch("Spotify Colors", "Custom colors", false)
local cfg_window_color_title = menu.ColorEdit("Spotify Colors", "Title color", default_colors.title)
local cfg_window_color_artist = menu.ColorEdit("Spotify Colors", "Artist color", default_colors.artist)
local cfg_window_color_duration = menu.ColorEdit("Spotify Colors", "Duration color", default_colors.duration)
local cfg_window_color_container = menu.ColorEdit("Spotify Colors", "Container color", default_colors.container)
local cfg_window_color_progressbar1 = menu.ColorEdit("Spotify Colors", "Progressbar1 color", default_colors.progressbar1)
local cfg_window_color_progressbar2 = menu.ColorEdit("Spotify Colors", "Progressbar2 color", default_colors.progressbar2)
local cfg_window_color_text_minimalist = menu.ColorEdit("Spotify Colors", "Minimalist text color", default_colors.minimalist_text)
local cfg_window_color_container_minimalist = menu.ColorEdit("Spotify Colors", "Minimalist container color", default_colors.minimalist_container)
local cfg_window_color_outline_minimalist = menu.ColorEdit("Spotify Colors", "Minimalist outline color", default_colors.minimalist_outline)
local cfg_window_colors_reset = menu.Button("Spotify Colors", "Reset Colors")

local cfg_window_menu_bar= menu.Switch("Spotify Controls", "Menu bar", false)

local cfg_authorize_link = menu.Button("Setup Spotify", "Open auth website", "Opens the browser in steam overlay and redirects you to auth website.")
local cfg_authorize = menu.Button("Setup Spotify", "Authorize", "Copy the code from the website and then press this button")
local cfg_deauthorize = menu.Button("Setup Spotify", "Deauthorize")

cfg_window_position_x:SetVisible(false)
cfg_window_position_y:SetVisible(false)
cfg_deauthorize:SetVisible(false)

local auth_code = "Basic ZDc5Y2ZkOTJmYjY2NGExZDllNTRmODYwN2ViMzhlODE6MWY0Zjk5M2JlMjA0NDhhNDg3MzkzYWFiN2UwNmE1YmI="
local uri = "http://localhost:8888/callback"
local authURL = "https://spotify.stbrouwers.cc/"
local scope = "user-read-playback-state user-modify-playback-state"
local query = "https://accounts.spotify.com/authorize?client_id=d79cfd92fb664a1d9e54f8607eb38e81&response_type=code&redirect_uri=".. uri .. "&scope=" .. scope

local font_song = g_Render:InitFont("Verdana", font_sizes.song)
local font_artist = g_Render:InitFont("Verdana", font_sizes.artist)
local font_duration = g_Render:InitFont("Verdana", font_sizes.duration)
local font_minimalist = g_Render:InitFont("Verdana", font_sizes.minimalist)
local font_bar_song = g_Render:InitFont("Verdana", 20)
local font_bar_artist = g_Render:InitFont("Verdana", 14)
local font_bar_time = g_Render:InitFont("Verdana", 14)

local image_shuffle_bytes = "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00\x00\x40\x00\x00\x00\x40\x08\x06\x00\x00\x00\xAA\x69\x71\xDE\x00\x00\x03\x3A\x49\x44\x41\x54\x78\x9C\xED\x9A\x3F\x6B\x54\x41\x14\xC5\xCF\x4D\x88\x44\x24\x85\x85\x4A\xA2\x46\x88\x55\x2C\x22\x08\x36\x81\x98\x10\x93\x28\x69\xC5\x6F\x20\x58\x68\x97\x2A\xE9\xB4\xD1\x56\x3F\x83\x68\xE1\x17\x50\x88\x8A\x88\x58\xAB\xE0\x1F\x34\x48\x88\xD1\x14\x36\x8A\x8A\xB8\xC6\x23\x57\xE7\x85\xE7\xB2\x7F\x66\xDE\xBB\x2F\xFB\x76\x77\x7E\x90\x22\xE4\xE5\xDE\x7B\xCE\xCE\x9D\x79\x3B\x33\x88\x44\x22\x91\x48\x24\x12\xE9\x54\x48\xEE\xEE\xEA\x0F\x97\xE4\x07\x92\x47\x4B\x50\x4A\x6B\x70\x06\x28\xA7\xBB\x51\x7F\xDA\x00\xE5\x5C\xF5\xDF\x45\x1F\xF0\x8C\xF5\x1D\xC0\x3A\x80\x65\x00\xB7\x00\xAC\x88\x08\xED\x4B\x0E\x87\xA4\x00\x18\x01\x70\x16\xC0\x1C\x80\x83\x00\x76\xB9\x40\xFB\x00\xF4\xA4\x82\x5E\x11\x91\xA5\xAD\xDF\x98\x8F\x55\x92\xE3\x2D\x14\x3E\xEE\x6A\x08\xE5\xA6\x95\x01\x09\x15\x92\xA7\xB6\x51\xF8\xBC\xCB\x99\x87\x07\x1A\x4B\x5B\xC0\x72\x18\x6B\x8B\x8C\x88\xC8\x4F\xC3\x98\x5B\x90\xDC\x01\xE0\x1D\x80\x21\xA3\x90\xAF\xAD\x0D\x48\x18\x13\x91\xE7\x96\x01\x49\x8E\x01\x78\x6A\x19\x52\x8D\xEC\xF1\x78\x30\x0B\xCF\x2C\x97\x1D\xD7\x5E\x96\xE2\x37\x01\x0C\x88\xC8\x46\x51\x23\x20\x61\x56\x44\x96\xF3\x04\x70\xE2\xEF\x18\xD6\xF4\xC3\x89\xFF\x95\x24\x10\xCF\x9F\x5E\x92\x83\x24\x97\x48\x7E\x0E\x98\x7C\x4E\xE6\x10\x3F\x17\x90\xE7\x0B\xC9\x45\x57\x63\x6F\x4A\xD3\xC7\xD4\x33\x9F\xDC\x92\x99\x1F\x92\x7B\x49\xAE\x17\x65\x82\x7E\xF2\x9E\xB1\xD7\x48\xEE\x69\x10\x27\x79\x11\x5A\x31\x11\x5E\x23\xC1\x45\x6B\x13\x02\xC4\x5F\xF0\x88\xA5\x06\x3C\xC9\x2D\xB4\x49\x92\x09\x2B\x13\x02\x86\xFD\x09\xCF\xDA\xAE\x9B\x88\xF4\x48\x34\x99\xD7\x04\x6B\xF1\xDB\x0E\xC9\xE9\xAC\x26\x04\x0C\xFB\x72\x8A\x4F\xC8\x62\x42\x80\xF8\xC9\x96\x0B\xF4\xC1\xD3\x84\x4D\x92\x3D\x6D\x3F\xEC\xEB\xD1\xC4\x04\x15\xBF\xB3\x63\xC5\x27\xD4\x31\x41\xC5\xF7\x77\x4C\xCF\x37\xA3\xCA\x84\x50\xF1\xED\xD1\xF3\xCD\x70\x26\x74\xC7\xB0\xAF\x47\x47\x4F\x78\x3E\x84\xF4\xBC\x7E\x99\x29\xBF\xA2\x00\x02\xC5\x0F\x90\xFC\xAD\xA3\xA5\x6D\x04\x36\x22\x60\xD8\x4F\xA4\xC4\x27\xCC\x96\x57\x99\x07\x21\x3D\x5F\x43\x7C\xC2\x4C\xE9\x85\xD6\x22\xE3\xB0\xAF\x47\xE6\x4D\x95\x96\x10\xB2\xCE\xBB\xDD\x9B\x46\xE2\x13\xDA\xC3\x84\x2C\x4B\x9D\x1B\x05\x3E\x94\xDB\x84\x3C\xEB\xBC\xC5\x7E\x42\x4B\xB1\x78\xC9\x21\x39\xD5\x96\x26\x04\xEC\x01\x34\x7D\xB7\xCF\xB3\xA9\x52\x27\xDE\x35\x13\x91\x0D\x12\x2C\x78\x16\xEC\xFD\x7A\x1B\x60\xC2\x82\x47\x2C\xDD\x14\x7D\x9C\x5B\x68\x8D\xC0\x43\x24\x37\xAC\xC5\xA7\xE2\xFB\x9A\xA0\xFB\xFE\xFB\x1B\xC4\x49\xB6\xC5\xDF\xD4\x7B\xC0\xF7\x60\xA4\x8F\xE4\x30\xC9\x4B\x24\xBF\x7A\x16\x97\x49\x7C\x06\x13\x94\x6F\x24\x2F\xBB\x1A\xFB\x7C\x0F\x46\x8A\x3E\x1A\x9B\x12\x91\x87\x79\x02\xA8\x09\x00\xEE\xD9\x95\xF4\xFF\xD1\x58\x51\x87\xA3\xCA\x4C\x5E\xF1\x8A\x88\xDC\x07\x60\x39\xEB\xF7\xAB\x09\x24\xFF\xDE\x20\x29\x6A\x04\x1C\x11\x91\x97\x96\x01\x49\x8E\x02\x78\x61\x19\x12\xC0\xA0\xB5\x01\x6B\x00\x0E\x8B\x48\xC5\x30\xE6\x16\xDA\xDB\x7A\x37\xC9\xDD\x01\xB2\xE0\x95\x55\x0B\xA8\xE0\x69\x11\x19\x2E\x4A\x3C\xFE\xB5\x43\x45\x73\xB8\x96\xC8\x9B\xE7\x91\x88\x8C\xE6\xBD\x23\xF4\x96\xE4\x71\x23\x7D\xC1\x68\x6E\x3D\xF5\xCD\x50\xF7\x8D\x24\x97\xB6\xC0\xAA\x67\x62\xBD\x26\xF7\x1E\xC0\x5D\x00\xB7\x45\xC4\xF7\xFF\xB6\x05\x92\x87\x00\x9C\xD1\xC9\x57\xDB\xD0\x4D\x76\xCA\x81\xAA\xC9\xFE\xAA\x88\x2C\x96\xA9\xF6\x42\xA9\xBA\x28\x79\xBE\x83\xA5\xD6\x26\x65\xC0\x7C\x19\xEB\x2B\x1C\x67\xC0\xB1\x0E\x97\x59\x9F\xAE\xBF\x2E\x1F\x89\x44\x22\x91\x48\xA4\x36\x00\xFE\x00\x30\x45\xD4\x7E\x4F\xDF\xA8\x55\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82"
local image_shuffle = g_Render:LoadImage(image_shuffle_bytes, Vector2.new(96, 64))

local image_repeate_bytes = "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00\x00\x40\x00\x00\x00\x40\x08\x06\x00\x00\x00\xAA\x69\x71\xDE\x00\x00\x02\xFD\x49\x44\x41\x54\x78\x9C\xED\x9A\x3D\x68\x14\x41\x18\x86\xDF\xF7\xE2\x45\x89\x06\x8B\xD8\xA8\x18\x11\x94\xA0\x48\x30\x76\x41\xB0\x51\x30\x28\x76\x22\x12\x14\x6C\xD2\x0B\x16\xE2\x4F\x2D\x16\x2A\x82\x36\x01\xC1\xDA\x42\x25\x28\x28\x11\xAC\x44\xC1\x42\x0B\xFF\xB0\x10\x51\x24\x8D\x5A\xA8\x51\x31\x4A\x5E\x99\xDC\x25\x9E\xEB\xCE\x66\xF7\x76\xF6\x76\xF7\x32\x0F\x5C\x91\xFD\x76\x67\xBE\x67\x76\xB3\xDF\xCC\xDC\xC1\xE3\xF1\x78\x3C\x1E\x8F\xC7\xE3\xF1\x94\x0A\x49\x15\x17\xF9\x3A\x69\x24\x27\x7E\x4A\x5A\x56\xE2\xFC\xD3\xA1\xBF\x6C\x28\xB3\x47\xD3\xE8\x5F\x86\x9A\x6D\x67\x51\x8A\x04\xBA\x00\xAC\xAB\x7F\x96\x3A\xB5\x4B\xCE\x6D\x49\x27\x49\x9E\xCE\xAC\x07\x49\x94\xB4\x5F\xD2\x7B\x15\x97\x6B\x49\xBD\x18\x47\x1C\xC0\x28\x80\x91\xA6\x47\xAF\xB5\x3C\x27\xB9\xD9\xC9\x00\x48\xDA\x09\x60\x3C\xCE\x40\x15\x8C\x09\x92\xAB\xE3\xA4\x64\x2D\x83\x92\xAE\x03\xB8\x5B\x42\xF9\xB7\x71\xE5\x0D\xA1\x72\x92\x5E\x00\xD8\xE8\x34\xAD\xD6\x70\x8F\xE4\x8E\x24\x3D\xFD\x57\x05\x24\x3D\x8E\x29\xFF\x03\xC0\x03\x00\x0F\x01\x7C\xCC\x41\xF6\x42\xE0\xEF\xF3\x24\x8F\xA6\x6A\x51\xD2\xD9\x18\xEF\xF7\x8B\x92\xAA\xA9\x3A\x72\x40\x20\xA7\x83\xA9\x5B\x94\xB4\x6A\x1E\xF1\x57\x92\x3A\xF2\x16\x9F\xA5\x21\xAF\x01\x57\x0D\x7E\x8E\x90\xBF\xE2\xA4\x13\x87\x48\x9A\x96\xB4\x22\xA1\x63\x97\xA9\x6C\x92\x56\x06\x03\x83\x11\xF2\x63\x45\x93\x47\x2D\xE7\xCE\x84\xE7\x9F\x08\x78\xDD\x37\xC7\x59\x0F\x9A\x97\x58\x4F\xC8\x75\x93\x24\xBB\x5D\x25\x9D\x17\x92\xCC\xCB\xFE\x57\x48\xF7\x03\x26\x58\x8D\xB8\xFB\x6B\xCB\x2E\x8F\xDA\x00\xF4\x59\xFC\x6E\x99\xE0\x21\x4B\xF0\x43\x01\x72\x77\x82\x79\x02\x2C\x8E\x93\x26\xF8\xC8\x12\xDC\xD7\x06\xEE\x73\x58\x1C\xA7\xCD\x0A\xCF\x4C\x68\x96\x84\x5C\xB3\x98\xE4\x54\x4E\xF9\x3A\xC7\xC8\x86\xCD\x7C\x69\x0D\x90\x65\x5B\x03\x44\x62\xF3\xAC\x58\xD6\x03\xCA\x37\xDD\x4C\x08\xF5\x2C\xF3\xA6\x68\x6C\x22\xA6\xEE\x53\x15\xCB\xDD\x6E\xAB\xC7\x1F\xC0\x5E\xCB\xF1\x67\x9C\x29\x05\xE1\x7B\x7A\x55\x92\xBF\x33\x4E\xAC\x25\xD4\x4B\x7A\xD8\xB4\xF9\xB0\x09\xDE\xB4\x94\x88\xBE\x36\x91\xEF\xB5\xF8\x19\x3A\xCD\x09\xFD\x96\x60\xEE\x4B\x5E\x17\x48\xFA\x6A\xF1\xFB\x34\xD7\xBC\x59\x18\x04\x82\xA7\x92\xF4\x5D\xD4\xC1\x92\x74\x23\xE2\xEE\x6F\x0B\x9E\x6C\xF6\x03\xF6\x48\x4A\xB4\xC7\x2F\xA9\xA7\x5E\x63\x0B\x85\xA4\xD1\x08\xF9\x2F\xAE\x46\x78\xCB\x6C\x8B\x45\x91\x37\x9B\x36\x66\x4F\x33\x42\xDE\x10\x7B\xD3\x34\xAA\xA3\xE1\xC6\x16\x9D\x64\x9F\x2E\x1F\xB3\xAA\xBD\x34\x8F\xB8\xE1\x5C\xE3\x75\x4D\xD5\x7B\x49\x67\x00\x1C\x0B\x1C\x3E\x92\xCA\xA0\x39\x96\x03\x18\x04\xB0\x1D\x40\x57\x8C\x16\x9E\x90\xDC\xDA\x78\x20\xF1\x00\x48\xBA\x03\x60\x57\xB6\x5E\x99\xF0\x92\xE4\xA6\x60\xC3\x89\xA6\xC2\x92\x5E\x97\x54\x7E\x2C\x4C\xDE\x10\xFB\x09\x90\xF4\x0E\xC0\x1A\xA7\x69\x65\x8F\x79\x37\x0D\x91\x1C\xB7\xF5\x14\xFB\x09\x20\xD9\x0B\xE0\x69\x39\xBC\x67\xB8\x0C\xA0\x23\x4A\xDE\x90\xE8\x5F\x80\x64\x3F\x80\xAB\xA9\x53\xCB\x8E\x09\x00\xC3\xC6\x8B\xE4\x08\xC9\x79\xAB\x53\xB3\x55\xE0\x38\x80\xE0\x8F\x11\x0E\xE4\x20\xFC\x1D\xC0\x1B\xF3\x21\xF9\xAD\xA5\x3D\x4B\xDA\x5D\xA4\x79\x40\x2E\x48\x5A\xBF\xA0\x07\x00\xB5\x41\xE8\x96\x14\xF6\xA5\xC3\xC2\xC1\xD5\x8F\x16\x3D\x1E\x8F\xC7\xE3\xF1\x78\x3C\x1E\x4F\x6B\x00\xF0\x07\x85\x8E\x0E\xBA\x5A\x4C\x55\x86\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82"
local image_repeat = g_Render:LoadImage(image_repeate_bytes, Vector2.new(64, 64))

local image_volume_bytes = "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00\x00\x40\x00\x00\x00\x40\x08\x06\x00\x00\x00\xAA\x69\x71\xDE\x00\x00\x07\xCF\x49\x44\x41\x54\x78\x9C\xED\x5B\x7D\x4C\x53\x57\x14\x2F\x05\xDB\x4E\x47\x65\x0A\x95\xAD\x8A\x2C\x64\x01\xD9\xDC\x86\x32\x15\x32\x89\x7F\x38\xE3\x96\x30\xFE\x99\xC3\x11\xD0\x65\xD9\x20\xFB\x43\x97\x7D\x24\x1A\x31\xEF\xBD\x42\xC1\x04\x99\x8D\xB0\x98\xE8\xA2\x8D\x40\x6A\x20\x21\x2C\x01\x03\x41\x4C\x19\x48\x2C\x2B\x61\x7E\xD5\xC0\x2C\x41\x24\x7C\x49\xD9\x6B\xAD\x02\xA5\xB4\x5D\x6E\xEC\x63\xAF\x87\xF7\xCA\xEB\xA7\x35\xF6\x97\xDC\xE4\xDD\xD3\x73\xCE\x7D\xE7\xF7\xEE\xBB\x1F\xE7\xBE\xF2\xC2\x08\x23\x8C\x30\xC2\x78\x85\x11\x81\x42\x77\x38\x1C\x2F\x05\x03\xBD\xBD\xBD\x6B\xA3\xA3\xA3\xE7\x52\x53\x53\x17\x7C\xF5\x15\x11\x11\xF1\x7F\x05\x11\x10\xEA\x45\xA7\xD3\x0D\x38\x9C\x68\x69\x69\xE9\xEA\xE8\xE8\x90\xF8\x72\xCF\x2E\x08\xF5\xE0\x4B\x4A\x4A\x0E\x3A\x18\x50\x5B\x5B\x7B\x55\xA7\xD3\x09\x7C\x21\x80\xEF\x6B\x57\x0A\x06\x16\x17\x17\xD7\x32\x35\x93\x9F\x9F\xFF\x59\x4A\x4A\xCA\x9C\x5C\x2E\xFF\xD2\xDB\xDB\x08\xCA\x18\xF0\xF0\xE1\xC3\x08\xA5\x52\x59\xC4\xE3\xF1\x44\x79\x79\x79\xBF\x25\x27\x27\x2F\x7A\x62\x3F\x34\x34\x14\x19\x17\x17\x37\x23\x16\x8B\x19\x89\x40\xA8\xAF\xAF\x6F\xDF\xB9\x73\xE7\xFE\xC4\xC4\x44\x4E\xC1\x04\x6D\x0C\x18\x18\x18\x88\x9A\x9E\x9E\x7E\x4C\x75\x60\xB3\xD9\xFC\x64\x78\x78\x38\xC2\x53\x3F\xC8\x06\xC3\xB0\x63\x16\x8B\xC5\xC2\xF4\x3A\x20\x4C\x4D\x4D\x4D\xEA\x74\x3A\x61\xC8\x8C\x01\x30\x78\x0A\x4A\xA5\xF2\x7D\x6F\x7D\x22\x22\x08\x82\x28\x61\x23\xE1\xD9\xB3\x67\xCF\xFA\xFB\xFB\xD7\xBC\x70\x02\xD8\x82\x47\x38\x7F\xFE\xFC\x47\xBE\xFA\xEF\xE9\xE9\x79\x63\x74\x74\xF4\x11\x0B\x09\x4F\x57\xEA\x09\x14\x02\x32\x08\x0E\x0E\x0E\x46\xAD\x5F\xBF\x7E\x3C\x36\x36\x36\x2E\x10\xFE\x11\x32\x33\x33\xC9\x8D\x1B\x37\x26\x54\x57\x57\xD7\xC1\xDF\x56\xAF\x5E\xBD\x66\xDD\xBA\x75\xC3\x68\xEC\x59\xC9\x8F\xDF\x09\xF0\x57\xF0\xBD\xBD\xBD\xE2\xEE\xEE\xEE\xBE\xC9\xC9\xC9\x71\x1C\xC7\x8F\xB2\x05\x73\xE4\xC8\x91\x02\x1C\xC7\x8B\xA1\x3C\x3E\x3E\xFE\xCD\x1B\x37\x6E\xB4\x70\x6A\x2C\x18\xDD\xDE\xD3\x57\xC0\x64\x32\x19\xE9\x36\x56\xAB\xD5\x4A\x10\x44\x3E\x9B\x3E\x86\x61\xC7\x99\xDA\x2A\x2D\x2D\xFD\x22\x28\x63\x00\xD7\xE0\xB9\x10\x30\x30\x30\xB0\x8A\xCD\xB6\xBF\xBF\xFF\x1E\xDB\xE2\x47\xA1\x50\x5C\x82\xFA\x36\x9B\xCD\xC6\x34\x1E\xF8\x95\x00\x4F\x82\xE7\x42\x00\x2A\x24\x49\xFE\xCB\x66\x3F\x37\x37\x37\xA7\x56\xAB\xE3\x98\xEC\xF4\x7A\xFD\x10\xD4\x6F\x68\x68\x68\x0F\xD8\x20\x18\xA8\x01\x6F\x74\x74\x54\x7A\xFD\xFA\xF5\x5E\xA6\xDF\x44\x22\x91\x28\x2B\x2B\x6B\xA2\xB3\xB3\x33\x16\xFE\x46\x92\xE4\x07\xE8\x99\xD2\x65\x07\x0E\x1C\xF8\xE4\xEA\xD5\xAB\x9B\x58\x1B\x0B\xD6\x93\xF7\xA4\x07\x50\xA5\xB1\xB1\x31\x69\x6C\x6C\x6C\x8C\xA5\x27\xCC\xA2\x7B\x60\x18\x0F\x7E\x84\xBA\x3D\x3D\x3D\x7F\xFB\xF5\x15\xF0\x36\x78\x4F\x09\xA0\x8A\x5C\x2E\xFF\x95\xC9\x17\x0C\x8C\x2A\x68\x41\x04\x75\xBB\xBA\xBA\xD6\xF9\x85\x00\x5F\x82\xF7\x96\x00\x54\x70\x1C\xFF\x96\xC9\x5F\x49\x49\xC9\x57\x50\x97\x69\x07\xA9\x50\x28\x94\xAC\x04\x34\x34\x34\xBC\x43\x92\x24\x69\xE3\x08\x6F\x83\x77\x47\xC0\x9D\x3B\x77\x44\x95\x95\x95\x7B\x3B\x3A\x3A\x36\xB0\x91\x40\x10\x84\x0C\xFA\x43\x53\xA4\x5E\xAF\xE7\xD3\xF5\xD0\x92\xD9\x66\xB3\x2D\x42\x3D\x56\x02\xAC\x56\xEB\x82\x2F\x41\xF9\x4A\x40\x4B\x4B\xCB\x26\x87\xC3\x61\xA7\x74\xD0\x74\xA7\xD5\x6A\xA3\x59\x88\xBA\x0F\x7D\x62\x18\x56\x0C\xF5\x9C\x4F\xDC\x05\x4D\x4D\x4D\x89\xCB\x66\x81\xFB\xF7\xEF\x0B\xA2\xA2\xA2\x56\xB1\x8E\x92\x41\xC0\xD3\xA7\x4F\x7F\xA7\xB6\xE7\x08\x69\x69\x69\xEF\x6E\xDB\xB6\xCD\x78\xE5\xCA\x95\x14\xD8\xBA\xD9\x6C\xCE\x84\xB2\xE2\xE2\x62\x0C\xCA\x92\x92\x92\x08\x28\xBB\x7B\xF7\x6E\x11\xBD\x1E\x32\x09\x11\x83\xC1\x60\x80\x32\x3E\x9F\xCF\xCF\xCD\xCD\xD5\xF5\xF5\xF5\x45\xD3\xE5\x99\x99\x99\xC6\x9A\x9A\x1A\x97\x65\xAE\x40\x20\x10\xD4\xD4\xD4\xBC\x47\x97\x65\x67\x67\x8F\xD8\xED\x76\x1B\x5D\x56\x50\x50\x90\xEB\xD2\x86\xDF\x22\xF0\x11\x7B\xF7\xEE\xFD\xDA\x60\x30\x4C\x43\x2F\x88\x04\xA1\x50\xF8\x17\x94\x4B\x24\x92\x22\x28\x33\x99\x4C\xC7\xA0\x4C\xA7\xD3\x3D\xA0\xD7\x13\x12\x12\x12\x96\xDD\xA9\x73\x69\x19\x34\xB8\x9B\x05\xE4\x72\x79\x25\xD3\x7D\xA8\x54\xAA\x14\xA8\x8B\x56\x84\x74\x1D\xE7\xEA\xD1\x45\xA7\xBC\xBC\xFC\x2C\xF4\x85\x96\xDA\x4B\x04\x07\xF5\x31\x73\x40\x71\x71\xF1\x2F\x72\xB9\xFC\x20\xD4\xE4\xF3\xF9\x67\xA1\xAC\xAD\xAD\x4D\x43\xAF\xC7\xC4\xC4\xC4\xC0\x5D\xA3\xDD\x6E\xEF\x82\x76\x13\x13\x13\x4B\xA9\xB5\x90\x4C\x8A\x9E\x3C\x79\xB2\x1E\xBE\x0E\x39\x39\x39\x59\x50\xEF\xD6\xAD\x5B\xD7\x81\x28\x62\x76\x76\xD6\x65\x30\x97\x4A\xA5\x7A\x68\x37\x35\x35\xB5\x9E\xBA\x0E\xD9\xAC\xB0\x4A\xA5\x6A\xA5\xD7\x45\x22\x91\x10\x3E\xDD\xA8\xA8\xA8\x7F\xA0\x9D\xD9\x6C\x16\xD1\xEB\x31\x31\x31\x4F\x18\x74\xD6\x50\xD7\x21\x4B\xC0\xFC\xFC\xBC\x19\x88\x96\x25\x44\xF8\x7C\xBE\x95\xC1\xD4\x45\x2F\x32\x32\xD2\x0E\x15\xEC\x76\xFB\x52\xDC\x21\x4B\x40\x46\x46\xC6\x2E\x7A\x1D\x4D\x67\x30\xE5\x6D\xB1\x58\xE2\xA1\x9D\x40\x20\x70\x21\x65\x76\x76\x56\x04\x75\x44\x22\x91\x85\xBA\x0E\x49\x02\xD0\x19\xE0\xEE\xDD\xBB\xB7\xD3\x65\xC3\xC3\xC3\x23\x50\x2F\x36\x36\x76\xD9\x82\x48\x2C\x16\xCF\xD3\xEB\xE3\xE3\xE3\x52\xA8\x23\x91\x48\x66\xA8\xEB\x90\x23\xA0\xB3\xB3\x33\x6E\xCB\x96\x2D\x8F\xA0\xBC\xAE\xAE\x4E\x06\x65\xB9\xB9\xB9\x9F\xD0\xEB\x0B\x0B\x0B\x96\xA4\xA4\x24\x97\x2E\x6F\x34\x1A\xD3\xA1\x9D\x54\x2A\x25\xA9\xEB\x90\x22\x00\xC7\xF1\xE3\x7B\xF6\xEC\x79\x2C\x16\x8B\xC5\x74\xF9\xE2\xE2\xA2\xF5\xF0\xE1\xC3\xB5\x74\xD9\xE0\xE0\xE0\x2A\x89\x44\xB2\x81\x2E\xEB\xEE\xEE\xBE\x0D\x7D\xA6\xA5\xA5\xED\x07\x22\x47\x74\x74\xF4\x52\x2F\x09\x19\x02\x08\x82\xF8\x46\x26\x93\x9D\x62\xFA\x4D\xA1\x50\xE4\xC0\xF7\x5F\xA5\x52\x7D\x0F\xF5\x6E\xDE\xBC\x79\x06\xCA\xF6\xED\xDB\xB7\x83\x5E\x37\x1A\x8D\xA6\x65\xC7\x67\xA1\xB0\x12\x6C\x6D\x6D\xED\x61\xD2\x2D\x2B\x2B\x3B\x03\x75\xD1\x56\xD7\x62\xB1\xCC\x43\x5D\x67\x32\x95\xBE\x6B\x7C\x0D\xEA\x28\x95\xCA\x3F\x96\xED\x06\x85\x42\xA1\xCB\x86\xE1\x45\x40\xA3\xD1\x5C\x82\xCD\xE2\x38\xFE\xC3\x89\x13\x27\x7E\x82\xF2\xCB\x97\x2F\x13\x02\x81\x40\x48\x97\x35\x37\x37\xFF\x99\x9C\x9C\xEC\x32\x03\x34\x36\x36\xE6\x43\x5B\x92\x24\xAB\x97\x85\x87\x18\x39\x75\xEA\x54\x75\xA0\x9E\x38\x04\xDB\x5E\x00\xC3\xB0\x9F\xD1\x71\x57\x55\x55\x55\xAD\x56\xAB\x7D\x9D\x49\xA7\xA9\xA9\xE9\x6D\x26\x9F\xED\xED\xED\xF1\x50\x17\x1D\x96\x42\x3D\x2A\x87\x48\xC1\xE5\x78\xBC\xAD\xAD\x4D\x3A\x34\x34\xB4\x79\xA5\x0E\x40\x92\xE4\x46\xB4\x5C\xF5\xB6\xA3\x5C\xB8\x70\x61\x47\x61\x61\xA1\xD6\x53\x3B\x74\x5A\xB4\x7D\xFB\x76\x03\xCC\x5D\xA0\xAD\xF1\xA1\x43\x87\xB2\xE9\xB2\xE6\xE6\xE6\xCD\xD9\xD9\xD9\x0F\xE9\xB2\xBE\xBE\xBE\x7B\xE9\xE9\xE9\x5B\x79\xFE\x38\x1E\x57\x28\x14\x7B\xFC\xDD\x03\xDC\x95\xD6\xD6\xD6\xB7\x98\x8E\xC6\x51\x9A\x8B\x29\x33\xAC\x56\xAB\xB5\x50\xB7\xAA\xAA\xEA\x63\xD6\x94\x58\x30\x49\xF0\x94\x00\x0C\xC3\x0A\x3D\xF1\x85\xF2\x9B\x50\xCF\x99\x25\xE6\xF9\x95\x00\x6F\x49\xE0\x4A\xC0\xB9\x73\xE7\x76\xCD\xCC\xCC\x18\xD8\xFC\x60\x18\x76\x94\xC9\x8E\x29\x63\x0D\xCF\x15\xFD\x46\x80\x37\x24\x70\x21\x00\x0D\x84\xEE\x7C\xE0\x38\x7E\x92\xC9\x4E\x26\x93\x95\x41\x5D\x93\xC9\x64\x82\x7A\x7E\x25\xC0\x53\x12\x56\x22\x40\xAF\xD7\x47\xBA\xB3\x67\x3B\xF1\x75\xFA\x65\x6A\x2F\x3D\xE0\x04\x78\x42\x02\x07\x02\xF8\xF4\x14\x39\x85\x91\x91\x91\x11\xB5\x5A\x1D\xCB\x64\xE3\x3C\x4B\x58\x66\x53\x5B\x5B\xDB\xC2\xA4\x1F\x10\x02\xB8\x92\xC0\xE5\x15\xC0\x30\xAC\x88\xD2\x47\xB9\xBE\x8A\x8A\x8A\x4F\xD9\x74\x11\x29\xCE\x43\x0F\x17\xA0\x81\x0F\x1E\x98\x04\x9C\x00\x2E\x24\x70\x1D\x04\xD1\xD2\x56\xA3\xD1\x88\xDD\xE9\xA0\x64\x29\x3C\x01\xA2\xE0\x3C\x6C\x61\xB4\x0B\x28\x01\x2B\x91\xE0\x8F\x8F\xA4\x1C\x2B\x4C\x8F\xA7\x4F\x9F\xDE\xE7\xCE\x36\xE0\x04\xB8\x23\xC1\x57\x02\x34\x1A\xCD\x5A\xAD\x56\x7B\x97\x2D\x78\x82\x20\x0A\x56\xF2\x11\x14\x02\xD8\x48\x60\x3B\xF3\x5B\xA9\xA0\xC3\xD3\x8A\x8A\x8A\x73\x6C\x81\x3B\x9E\xCF\x10\x07\xB8\xF8\x0A\x1A\x01\x8E\xE7\x0B\x9A\x0C\xF4\xD1\x13\xFA\x7E\xAF\xBC\xBC\xFC\x73\x6F\x7C\x94\x96\x96\x9E\x76\x17\x38\x1A\x07\x2E\x5E\xBC\xF8\x21\x57\x7F\x41\x25\xC0\xD7\xE2\x5C\xC3\xB3\x42\xA7\xD3\x0D\x3A\xF7\xFE\x9C\xDB\xA2\xF0\x52\x7C\x2D\x6E\x30\x18\x76\x31\xC9\xED\x76\xBB\x9D\x20\x88\xEF\x52\x53\x53\x93\xB7\x6E\xDD\x3A\xE7\x75\x03\xA1\xDE\x03\xD0\x67\xB1\xE0\xE9\xDB\x2B\x2B\x2B\x2F\x30\xED\x02\x3D\xED\x01\x2F\xCD\x5F\x66\xAE\x5D\xBB\x16\x7F\xFB\xF6\x6D\x99\xD9\x6C\x7E\x90\x97\x97\x77\x16\x66\x7F\x3C\x85\x4B\x3E\x20\x8C\x30\xC2\x08\x23\x8C\x57\x11\x3C\x1E\xEF\x3F\x78\x1D\x9C\x79\x9C\xC9\x4A\x0C\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82"
local image_volume = g_Render:LoadImage(image_volume_bytes, Vector2.new(64, 64))

local input = InputSystem.init()

local access_token = nil
local refresh_token = nil
local song_info = nil
local old_song_id = nil
local image_loaded = nil

local is_dragging_timeline = false
local is_dragging_volume = false
local successful_auth = false

local current_clantag = ""
local max_clantag_size = 14
local current_index = 1
local old_tickcount = g_GlobalVars.tickcount
local e_repeat_state = {"off", "context", "track"}
local e_repeate_index = {["off"] = 1, ["context"] = 2, ["track"] = 3}
local current_state = e_repeat_state[1]

local function get_clipboard_text()
	local length = func_get_clipboard_text_count(vgui_system010_class)
    if length <= 0 then return "" end

    local buffer = ffi.new("char[?]", length)
    func_get_clipboard_text(vgui_system010_class, 0, buffer, length)

    return ffi.string(buffer, length - 1)
end

local function set_clipboard_text(text)
	text = tostring(text)
	func_set_clipboard_text(vgui_system010_class, text, string.len(text))
end

local function get_refresh_token_local()
    if FileSystem.exists(file_path, "GAME") then
        local auth_file = FileSystem.open(file_path, "rb", "GAME")
        refresh_token = Cryption.decode(auth_file:read())
        auth_file:close()
        
        cfg_authorize_link:SetVisible(false)
        cfg_authorize:SetVisible(false)
        cfg_deauthorize:SetVisible(true)
    end
end

local function get_refresh_token()
    local authCode = get_clipboard_text()
    if not authCode then
        print("Error: Clipboard empty!")
        return
    end

    refresh_token = authCode
end

local function deauthorize()
    if FileSystem.exists(file_path, "GAME") then
        FileSystem.remove(file_path, "GAME")
    end

    refresh_token = nil
    access_token = nil
    song_info = nil
    successful_auth = false

    cfg_authorize_link:SetVisible(true)
    cfg_authorize:SetVisible(true)
    cfg_deauthorize:SetVisible(false)
end

local function update_scale()
    local scale = cfg_window_scale:GetInt() * 0.01
    font_sizes.song = math.floor(20 * scale + 0.5)
    font_sizes.artist = math.floor(12 * scale + 0.5)
    font_sizes.duration = math.floor(16 * scale + 0.5)
    font_sizes.minimalist = math.floor(12 * scale + 0.5)

    --font_song = g_Render:InitFont("Verdana", font_sizes.song)
    --font_artist = g_Render:InitFont("Verdana", font_sizes.artist)
    --font_duration = g_Render:InitFont("Verdana", font_sizes.duration)
end

local function custom_colors_callback()
    if cfg_window_colors:GetBool() then
        if cfg_window_minimalist:GetBool() then
            cfg_window_color_text_minimalist:SetVisible(true)
            cfg_window_color_container_minimalist:SetVisible(true)
            cfg_window_color_outline_minimalist:SetVisible(true)
            cfg_window_color_title:SetVisible(false)
            cfg_window_color_artist:SetVisible(false)
            cfg_window_color_duration:SetVisible(false)
            cfg_window_color_container:SetVisible(false)
            cfg_window_color_progressbar1:SetVisible(false)
            cfg_window_color_progressbar2:SetVisible(false)
        else
            cfg_window_color_text_minimalist:SetVisible(false)
            cfg_window_color_container_minimalist:SetVisible(false)
            cfg_window_color_outline_minimalist:SetVisible(false)
            cfg_window_color_title:SetVisible(true)
            cfg_window_color_artist:SetVisible(true)
            cfg_window_color_duration:SetVisible(true)
            cfg_window_color_container:SetVisible(true)
            cfg_window_color_progressbar1:SetVisible(true)
            cfg_window_color_progressbar2:SetVisible(true)
        end
        cfg_window_colors_reset:SetVisible(true)
    else
        cfg_window_color_text_minimalist:SetVisible(false)
        cfg_window_color_container_minimalist:SetVisible(false)
        cfg_window_color_outline_minimalist:SetVisible(false)
        cfg_window_color_title:SetVisible(false)
        cfg_window_color_artist:SetVisible(false)
        cfg_window_color_duration:SetVisible(false)
        cfg_window_color_container:SetVisible(false)
        cfg_window_color_progressbar1:SetVisible(false)
        cfg_window_color_progressbar2:SetVisible(false)
        cfg_window_colors_reset:SetVisible(false)
    end
end

local function callback_reset_colors()
    cfg_window_color_title:SetColor(default_colors.title)
    cfg_window_color_artist:SetColor(default_colors.artist)
    cfg_window_color_duration:SetColor(default_colors.duration)
    cfg_window_color_container:SetColor(default_colors.container)
    cfg_window_color_progressbar1:SetColor(default_colors.progressbar1)
    cfg_window_color_progressbar2:SetColor(default_colors.progressbar2)
    cfg_window_color_text_minimalist:SetColor(default_colors.minimalist_text)
    cfg_window_color_container_minimalist:SetColor(default_colors.minimalist_container)
    cfg_window_color_outline_minimalist:SetColor(default_colors.minimalist_outline)
end

local function render_text_width_font(text, pos, clr, size, max_width, font, out)
    local output = ""
    local buffer_str = ""

    for i = 1, #text do
        local char = text:sub(i,i)
        buffer_str = buffer_str .. char
        local buffer_size = g_Render:CalcTextSize(buffer_str, size, font)

        if buffer_size.x <= max_width then
            output = buffer_str
        end
    end

    g_Render:Text(output, pos, clr, size, font, out)
end

local function get_song_title()
    local title_text = song_info.item.name
    local title_size = g_Render:CalcTextSize(song_info.item.name, font_sizes.song, font_song)
    return title_text, title_size
end

local function get_song_artists()
    local artist_text = song_info.item.artists[1].name
    local artists = song_info.item.artists
    local artist_size = g_Render:CalcTextSize(artist_text, font_sizes.artist, font_artist)

    for i = 2, #artists do
        artist_text = artist_text .. ", " .. artists[i].name
    end

    artist_size = g_Render:CalcTextSize(artist_text, font_sizes.artist, font_artist)
    return artist_text, artist_size
end

local function get_song_duration()
    local progress_ms = song_info.progress_ms
    local duration_ms = song_info.item.duration_ms

    local progress = string.format("%d:%02d", math.floor(progress_ms / 60000), math.floor(progress_ms / 1000) % 60)
    local duration = string.format("%d:%02d", math.floor(duration_ms / 60000), math.floor(duration_ms / 1000) % 60)
    local song_progess_text = progress .. "/" .. duration
    local song_progress_size = g_Render:CalcTextSize(song_progess_text, font_sizes.duration, font_duration)

    return (progress_ms / duration_ms), song_progess_text, song_progress_size
end

local getAccessToken = Timer.create(1800, function()
    if not auth_code or not refresh_token then return false end

    local response = g_Panorama:Exec([[
        if (typeof accessToken === "undefined") {
            var accessToken = "";
        }
        
        $.AsyncWebRequest("https://spotify.stbrouwers.cc/refresh_token?refresh_token=]].. refresh_token .. [[", {
            ["type"]: "GET", 
            ["headers"]: {
                ["Host"]: "spotify.stbrouwers.cc",
                ["Content-Length"]: 0,
            },
            ["error"]: function(response) {
                accessToken = "";
            },
            ["success"]: function(response) {
                accessToken = response.access_token;
            }
        }); 
          
        accessToken;
    ]])

    if response and response ~= "" then 
        if not successful_auth then
            local auth_file = FileSystem.open(file_path, "wb", "GAME")
            auth_file:write(Cryption.encode(refresh_token))
            auth_file:close()
        
            cfg_authorize_link:SetVisible(false)
            cfg_authorize:SetVisible(false)
            cfg_deauthorize:SetVisible(true)
            successful_auth = true
        end

        access_token = response
        return true
    else
        refresh_token = nil
        print("Invalid auth code!")
    end

    return 1.1
end)

local has_been_called = false

local getSongInfo = Timer.create(2.0, function()
    if not access_token then return false end

    local response = g_Panorama:Exec([[
        if (typeof songInfo === 'undefined')
            var songInfo = "";

        $.AsyncWebRequest("https://api.spotify.com/v1/me/player", {
            ["type"]: "GET", 
            ["headers"]: {
                ["Authorization"]: "Bearer ]] .. access_token .. [[",
                ["Accept"]: "application/json", 
                ["Content-Type"]: "application/json",
            },
            ["error"]: function(response) {
                songInfo = "error";
            },
            ["success"]: function(response) {
                var songInfoJson = response;

                if (!/^[ -~]+$/.test(songInfoJson.item.name))
                    songInfoJson.item.name = "Placeholder Title";
                if (!/^[ -~]+$/.test(songInfoJson.item.album.name))
                    songInfoJson.item.album.name = "Placeholder Album";

                for(var index = 0; index < songInfoJson.item.artists.length; index++)
                {
                    if (!/^[ -~]+$/.test(songInfoJson.item.artists[index].name))
                        songInfoJson.item.artists[index].name = "Artist " + index.toString();
                }

                songInfo = JSON.stringify(songInfoJson).replace((/  |\r\n|\n|\r/gm),"");
            }
        });

        songInfo;
    ]])


    -- No idea what i did there
    if response and response ~= "" and response ~= "complete" and string.find(response, "device") ~= nil then
        local info = JSON.parse(response)

        if info and info.timestamp and info.currently_playing_type ~= "ad" and info.currently_playing_type ~= "unknown" then
            song_info = info
        end

    end

    return true
end)

local updateClantag = Timer.create(0.25, function()
    if cfg_window_clantag:GetBool() then
        local title_text = get_song_title()
        local artist_text = get_song_artists()
        local text = "Listening to " .. title_text .. " by " .. artist_text
        local current_text = text:sub(current_index, max_clantag_size + current_index)

        if g_GlobalVars.tickcount > old_tickcount then
            set_clantag(current_text, current_text)
            current_clantag = current_text
            old_tickcount = g_GlobalVars.tickcount
        end

        if current_index == 1 then
            current_index = current_index + 1
            return 2
        end

        current_index = current_index + 1
        if max_clantag_size + current_index > text:len() then 
            current_index = 1
            return 2
        end
    end

    return true
end)

local function previousSong(device)
    g_Panorama:Exec([[
        $.AsyncWebRequest("https://api.spotify.com/v1/me/player/previous?device_id=]] .. device .. [[", {
            ["type"]: "POST", 
            ["headers"]: {
                ["Authorization"]: "Bearer ]] .. access_token .. [[", 
                ["Host"]: "api.spotify.com",
                ["Content-Type"]: "application/x-www-form-urlencoded",
                ["Content-Length"]: 0
            },
            ["complete"]: function(response) {
                songInfo = "complete";
            }
        });
    ]])

end

local function skipSong(device)
    g_Panorama:Exec([[
        $.AsyncWebRequest("https://api.spotify.com/v1/me/player/next?device_id=]] .. device .. [[", {
            ["type"]: "POST", 
            ["headers"]: {
                ["Authorization"]: "Bearer ]] .. access_token .. [[", 
                ["Host"]: "api.spotify.com",
                ["Content-Type"]: "application/x-www-form-urlencoded",
                ["Content-Length"]: 0
            },
            ["complete"]: function(response) {
                songInfo = "complete";
            }
        });
    ]])

end

local function updateVolume(device, volume)
    g_Panorama:Exec([[
        $.AsyncWebRequest("https://api.spotify.com/v1/me/player/volume?volume_percent=]] .. tostring(math.min(math.max(0, volume), 100)) .. "&device_id=" .. device .. [[", {
            ["type"]: "PUT", 
            ["headers"]: {
                ["Authorization"]: "Bearer ]] .. access_token .. [[", 
                ["Host"]: "api.spotify.com",
                ["Content-Type"]: "application/x-www-form-urlencoded",
                ["Content-Length"]: 0
            },
            ["complete"]: function(response) {
                songInfo = "complete";
            }
        });
    ]])

end

local function changeSongPosition(device, position)
    g_Panorama:Exec([[
        $.AsyncWebRequest("https://api.spotify.com/v1/me/player/seek?position_ms=]] .. tostring(position) .. "&device_id=" .. device .. [[", {
            ["type"]: "PUT", 
            ["headers"]: {
                ["Authorization"]: "Bearer ]] .. access_token .. [[", 
                ["Host"]: "api.spotify.com",
                ["Content-Type"]: "application/x-www-form-urlencoded",
                ["Content-Length"]: 0
            },
            ["complete"]: function(response) {
                songInfo = "complete";
            }
        });
    ]])

end

local function setShuffle(device, shouldShuffle)
    g_Panorama:Exec([[
        $.AsyncWebRequest("https://api.spotify.com/v1/me/player/shuffle?state=]] .. tostring(shouldShuffle) .. "&device_id=" .. device .. [[", {
            ["type"]: "PUT", 
            ["headers"]: {
                ["Authorization"]: "Bearer ]] .. access_token .. [[", 
                ["Host"]: "api.spotify.com",
                ["Content-Type"]: "application/x-www-form-urlencoded",
                ["Content-Length"]: 0
            },
            ["complete"]: function(response) {
                songInfo = "complete";
            }
        });
    ]])

end

local function setRepeat(device, repeat_state)
    g_Panorama:Exec([[
        $.AsyncWebRequest("https://api.spotify.com/v1/me/player/repeat?state=]] .. repeat_state .. "&device_id=" .. device .. [[", {
            ["type"]: "PUT", 
            ["headers"]: {
                ["Authorization"]: "Bearer ]] .. access_token .. [[", 
                ["Host"]: "api.spotify.com",
                ["Content-Type"]: "application/x-www-form-urlencoded",
                ["Content-Length"]: 0
            },
            ["complete"]: function(response) {
                songInfo = "complete";
            }
        });
    ]])

end

local function pauseSong(device, shouldPause)
    if shouldPause then
        g_Panorama:Exec([[
            $.AsyncWebRequest("https://api.spotify.com/v1/me/player/pause?device_id=]] .. device .. [[", {
                ["type"]: "PUT", 
                ["headers"]: {
                    ["Authorization"]: "Bearer ]] .. access_token .. [[", 
                    ["Host"]: "api.spotify.com",
                    ["Content-Type"]: "application/x-www-form-urlencoded",
                    ["Content-Length"]: 0
                },
                ["complete"]: function(response) {
                    songInfo = "complete";
                }
            });
        ]])
    else
        g_Panorama:Exec([[
            $.AsyncWebRequest("https://api.spotify.com/v1/me/player/play?device_id=]] .. device .. [[", {
                ["type"]: "PUT", 
                ["headers"]: {
                    ["Authorization"]: "Bearer ]] .. access_token .. [[", 
                    ["Host"]: "api.spotify.com",
                    ["Content-Type"]: "application/x-www-form-urlencoded",
                    ["Content-Length"]: 0
                },
                ["complete"]: function(response) {
                    songInfo = "complete";
                }
            });
        ]])
    end

end

local function hsv_to_rgb(h, s, v, a)
    local r, g, b
  
    local i = math.floor(h * 6);
    local f = h * 6 - i;
    local p = v * (1 - s);
    local q = v * (1 - f * s);
    local t = v * (1 - (1 - f) * s);
  
    i = i % 6
  
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end
  
    return r, g, b, a
end

local function render_spotify_controls(song_name, song_artist)
    local mouse_pos = cheat.GetMousePos()
    local menu_pos = g_Render:GetMenuPos()
    local menu_sz = g_Render:GetMenuSize()
    local color_progressbar = colors.progressbar1

    local position = Vector2.new(menu_pos.x, menu_pos.y + menu_sz.y)
    local height = 100

    local image_position = Vector2.new(position.x + 10, position.y + 10)
    local image_size = Vector2.new(75, 75)

    local title_position = Vector2.new(image_position.x + image_size.x + 15, image_position.y + 10)
    local artist_position = Vector2.new(title_position.x, title_position.y + 20)

    local time_passed_position = Vector2.new(image_position.x + image_size.x + 15, artist_position.y + 25)
    local time_bar_position = Vector2.new(time_passed_position.x + 40, time_passed_position.y + 3)
    local time_bar_size = Vector2.new(menu_sz.x - (time_passed_position.x - menu_pos.x) * 2, 10)
    local time_left_position = Vector2.new(time_bar_position.x + time_bar_size.x + 15, time_passed_position.y)

    local play_pause_radius = 16
    local play_pause_position = Vector2.new(time_bar_position.x + (time_bar_size.x / 2), time_bar_position.y - play_pause_radius - 15)

    local arrow_gap = 40
    local arrow_height = math.floor(play_pause_radius * 0.5 + 0.5)

    local shuffle_position = Vector2.new(play_pause_position.x - (play_pause_radius + arrow_gap * 2 + 36), play_pause_position.y - 12)
    local repeat_position = Vector2.new(play_pause_position.x + (play_pause_radius + arrow_gap * 2 + 12), play_pause_position.y - 12)
    local image_size2 = Vector2.new(24, 24)
    local image_size3 = Vector2.new(16, 16)
    
    local volume_position = Vector2.new(position.x + (menu_sz.x * 0.83), play_pause_position.y - 4)
    local volume_size = Vector2.new(menu_sz.x * 0.14, 8)

    local is_mouse1_pressed = input:is_key_pressed(1)
    local is_mouse1_held = input:is_key_held(1)
    local is_mouse1_released = input:is_key_released(1)

    local device = song_info.device.id
    local is_playing = song_info.is_playing
    local is_shuffling = song_info.shuffle_state
    local repeat_state = song_info.repeat_state
    local volume = song_info.device.volume_percent / 100

    local progress_ms = song_info.progress_ms
    local duration_ms = song_info.item.duration_ms
    local left_ms = duration_ms - progress_ms

    local song_progess_text = string.format("%d:%02d", math.floor(progress_ms / 60000), math.floor(progress_ms / 1000) % 60)
    local song_left_text = "-" .. string.format("%d:%02d", math.floor(left_ms / 60000), math.floor(left_ms / 1000) % 60)
    g_Render:BoxFilled(position, Vector2.new(position.x + menu_sz.x, position.y + height), Color.new(0.1, 0.1, 0.1, 1))

    if image_loaded then
        g_Render:Image(image_loaded, image_position, image_size)
    end

    render_text_width_font(song_name, title_position, Color.new(1.0, 1.0, 1.0, 1.0), 20, shuffle_position.x - title_position.x - 20, font_bar_song, true)
    render_text_width_font(song_artist, artist_position, Color.new(0.7, 0.7, 0.7, 1.0), 14, shuffle_position.x - title_position.x - 20, font_bar_artist, true)

    local new_song_position = song_info.progress_ms
    if not is_dragging_volume and (input:is_mouse_in_area(time_bar_position.x + 1, time_bar_position.y + 1, time_bar_size.x - 1, time_bar_size.y - 1) or is_dragging_timeline) then
        if is_mouse1_held or is_mouse1_released then
            local max_val = time_bar_size.x - 1
            local calc = math.min(math.max(0, mouse_pos.x - (time_bar_position.x + 1)), time_bar_size.x - 1) / max_val
            new_song_position = math.floor(duration_ms * calc + 0.5)
            progress_ms = new_song_position
            is_dragging_timeline = true
        else
            is_dragging_timeline = false
        end
    end

    if new_song_position ~= song_info.progress_ms and is_mouse1_released then
        changeSongPosition(device, new_song_position)
    end

    g_Render:Text(song_progess_text, time_passed_position, Color.new(0.7, 0.7, 0.7, 1.0), 14, font_bar_time, false)
    g_Render:Text(song_left_text, time_left_position, Color.new(0.7, 0.7, 0.7, 1.0), 14, font_bar_time, false)
    g_Render:Box(time_bar_position, Vector2.new(time_bar_position.x + time_bar_size.x, time_bar_position.y + time_bar_size.y), Color.new(0.0, 0.0, 0.0, 1))
    g_Render:BoxFilled(
        Vector2.new(time_bar_position.x + 1, time_bar_position.y + 1), 
        Vector2.new(time_bar_position.x + time_bar_size.x - 1, time_bar_position.y + time_bar_size.y - 1), 
        Color.new(0.2, 0.2, 0.2, 1)
    )
    g_Render:BoxFilled(
        Vector2.new(time_bar_position.x + 1, time_bar_position.y + 1), 
        Vector2.new(time_bar_position.x + (time_bar_size.x - 2) * (progress_ms / duration_ms) + 1, time_bar_position.y + time_bar_size.y - 1), 
        color_progressbar
    )

    -- Play Pause
    local color_play_pause = Color.new(0.6, 0.6, 0.6, 1.0)
    if input:is_mouse_in_area(play_pause_position.x - 15, play_pause_position.y - 15, 30, 30) then
        if is_mouse1_pressed then
            pauseSong(device, song_info.is_playing)
        end
        color_play_pause = Color.new(1.0, 1.0, 1.0, 1.0)
    end
    if is_playing then
        g_Render:Circle(play_pause_position, play_pause_radius, 30, color_play_pause)
        g_Render:BoxFilled(
            Vector2.new(play_pause_position.x - play_pause_radius * 0.4, play_pause_position.y - play_pause_radius * 0.5), 
            Vector2.new(play_pause_position.x - play_pause_radius * 0.2, play_pause_position.y + play_pause_radius * 0.5), 
            color_play_pause
        )
        g_Render:BoxFilled(
            Vector2.new(play_pause_position.x + play_pause_radius * 0.2, play_pause_position.y - play_pause_radius * 0.5), 
            Vector2.new(play_pause_position.x + play_pause_radius * 0.4, play_pause_position.y + play_pause_radius * 0.5), 
            color_play_pause
        )
    else
        g_Render:Circle(play_pause_position, play_pause_radius, 30, color_play_pause)
        g_Render:PolyFilled(
            color_play_pause, 
            Vector2.new(play_pause_position.x - play_pause_radius * 0.35, play_pause_position.y - play_pause_radius * 0.5), 
            Vector2.new(play_pause_position.x + play_pause_radius * 0.55, play_pause_position.y), 
            Vector2.new(play_pause_position.x - play_pause_radius * 0.35, play_pause_position.y + play_pause_radius * 0.5) 
        )
    end

    -- Skip
    local color_skip = Color.new(0.6, 0.6, 0.6, 1.0)
    if input:is_mouse_in_area(play_pause_position.x + play_pause_radius + arrow_gap, play_pause_position.y - arrow_height, 12, arrow_height * 2) then
        if is_mouse1_pressed then 
            skipSong(device)
        end
        color_skip = Color.new(1.0, 1.0, 1.0, 1.0)
    end
    g_Render:PolyFilled(
        color_skip, 
        Vector2.new(play_pause_position.x + play_pause_radius + arrow_gap, play_pause_position.y - arrow_height), 
        Vector2.new(play_pause_position.x + play_pause_radius + arrow_gap + 10, play_pause_position.y), 
        Vector2.new(play_pause_position.x + play_pause_radius + arrow_gap, play_pause_position.y + arrow_height) 
    )
    g_Render:BoxFilled(
        Vector2.new(play_pause_position.x + play_pause_radius + arrow_gap + 12, play_pause_position.y - arrow_height), 
        Vector2.new(play_pause_position.x + play_pause_radius + arrow_gap + 10, play_pause_position.y + arrow_height), 
        color_skip
    )

    -- Previous
    local color_previous = Color.new(0.6, 0.6, 0.6, 1.0)
    if input:is_mouse_in_area(play_pause_position.x - play_pause_radius - arrow_gap - 12, play_pause_position.y - arrow_height, 12, arrow_height * 2) then
        if is_mouse1_pressed then 
            previousSong(device)
        end
        color_previous = Color.new(1.0, 1.0, 1.0, 1.0)
    end
    g_Render:PolyFilled(
        color_previous, 
        Vector2.new(play_pause_position.x - (play_pause_radius + arrow_gap), play_pause_position.y - arrow_height), 
        Vector2.new(play_pause_position.x - (play_pause_radius + arrow_gap + 10), play_pause_position.y), 
        Vector2.new(play_pause_position.x - (play_pause_radius + arrow_gap), play_pause_position.y + arrow_height) 
    )
    g_Render:BoxFilled(
        Vector2.new(play_pause_position.x - (play_pause_radius + arrow_gap + 12), play_pause_position.y - arrow_height),
        Vector2.new(play_pause_position.x - (play_pause_radius + arrow_gap + 10), play_pause_position.y + arrow_height), 
        color_previous
    )

    -- Shuffle
    local color_shuffle = Color.new(0.6, 0.6, 0.6, 1.0)
    if input:is_mouse_in_area(shuffle_position.x, shuffle_position.y, image_size2.x, image_size2.y) then
        if is_mouse1_pressed then 
            setShuffle(device, not song_info.shuffle_state)
        end
        color_shuffle = Color.new(1.0, 1.0, 1.0, 1.0)
    end
    if song_info.shuffle_state then
        color_shuffle = color_progressbar
    end
    g_Render:Image(image_shuffle, Vector2.new(play_pause_position.x - (play_pause_radius + arrow_gap * 2 + 36), play_pause_position.y - 12), image_size2, color_shuffle)

    -- Repeat
    local color_repeat = Color.new(0.6, 0.6, 0.6, 1.0)
    if input:is_mouse_in_area(repeat_position.x, repeat_position.y, image_size2.x, image_size2.y) then
        if is_mouse1_pressed then
            local new_state_index = e_repeate_index[repeat_state] + 1
            if new_state_index > 3 then new_state_index = 1 end
            setRepeat(device, e_repeat_state[new_state_index])
        end
        color_repeat = Color.new(1.0, 1.0, 1.0, 1.0)
    end
    if repeat_state ~= "off" then
        color_repeat = color_progressbar
    end
    g_Render:Image(image_repeat, Vector2.new(play_pause_position.x + (play_pause_radius + arrow_gap * 2 + 12), play_pause_position.y - 12), image_size2, color_repeat)
    if repeat_state == "track" then
        g_Render:CircleFilled(Vector2.new(repeat_position.x + image_size2.x - 2, repeat_position.y + 7), 5, 30, color_repeat)
    end

    -- Volume
    local new_song_volume = song_info.device.volume_percent
    if not is_dragging_timeline and (input:is_mouse_in_area(volume_position.x + 1, volume_position.y + 1, volume_size.x - 1, volume_size.y - 1) or is_dragging_volume) then
        if is_mouse1_held or is_mouse1_released then
            local max_val = volume_size.x - 1
            local calc = math.floor(math.min(math.max(0, mouse_pos.x - (volume_position.x + 1)), volume_size.x - 1) + 0.5) / max_val
            new_song_volume = math.floor(calc * 100 + 0.5)
            volume = calc
            is_dragging_volume = true
        else
            is_dragging_volume = false
        end
    end

    if new_song_volume ~= song_info.device.volume_percent and is_mouse1_released then
        updateVolume(device, new_song_volume)
    end

    g_Render:Image(image_volume, Vector2.new(volume_position.x - image_size3.x - 10, volume_position.y - image_size3.y / 2 + volume_size.y / 2), image_size3, Color.new(0.6, 0.6, 0.6, 1.0))
    g_Render:Box(volume_position, volume_position + volume_size, Color.new(0.0, 0.0, 0.0))
    g_Render:BoxFilled(
        Vector2.new(volume_position.x + 1, volume_position.y + 1), 
        Vector2.new(volume_position.x + volume_size.x - 1, volume_position.y + volume_size.y - 1), 
        Color.new(0.2, 0.2, 0.2, 1)
    )
    g_Render:BoxFilled(
        Vector2.new(volume_position.x + 1, volume_position.y + 1), 
        Vector2.new(volume_position.x + (volume_size.x - 2) * volume + 1, volume_position.y + volume_size.y - 1), 
        color_progressbar
    )
end

local hue = 0

local function render_spotify_info(song_title_text, song_title_size, song_artist_text, song_artist_size, x, y, w, h, scale)
    local has_cover = cfg_window_cover:GetInt()
    local widht = cfg_window_width:GetInt()

    local image_size = Vector2.new(h, h)
    local progress_bar = math.floor(4 * scale + 0.5)
    local progress_ms = song_info.progress_ms
    local duration_ms = song_info.item.duration_ms
    local info_x, info_w = x, w

    local max_width = (has_cover ~= 0) and info_w - h - 12 * scale - 9 or info_w - 12 * scale - 8
    if widht == 300 then max_width = screen_size.x end
    
    if has_cover == 0 then
        g_Render:BoxFilled(Vector2.new(x, y), Vector2.new(x + info_w, y + h), colors.container)
    elseif has_cover == 1 then
        g_Render:BoxFilled(Vector2.new(x + h, y), Vector2.new(x + info_w, y + h), colors.container)
        g_Render:Image(image_loaded, Vector2.new(x, y), image_size)
        info_x = info_x + h; info_w = info_w - h
    elseif has_cover == 2 then
        g_Render:BoxFilled(Vector2.new(x, y), Vector2.new(x + info_w - h, y + h), colors.container)
        g_Render:Image(image_loaded, Vector2.new(x + info_w - h, y), image_size)
        info_x = info_x; info_w = info_w - h
    end

    local progress_w = info_w * (progress_ms / duration_ms)

    g_Render:BoxFilled(Vector2.new(info_x, y + h - progress_bar), Vector2.new(info_x + progress_w, y + h), colors.progressbar1)
    g_Render:BoxFilled(Vector2.new(info_x + progress_w, y + h - progress_bar), Vector2.new(info_x + info_w, y + h), colors.progressbar2)

    render_text_width_font(song_title_text, Vector2.new(info_x + 11 * scale, y + (h - 4 - song_title_size.y + song_artist_size.y + 5) / 2 - song_title_size.y / 2 - 5), colors.title, font_sizes.song, max_width, font_song, true)
    render_text_width_font(song_artist_text, Vector2.new(info_x + 12 * scale, y + (h - 4 - song_title_size.y + song_artist_size.y + 5) / 2 + song_artist_size.y / 2), colors.artist, font_sizes.artist, max_width, font_artist, true)
    
    if cfg_window_duration:GetBool() then
        local progress = string.format("%d:%02d", math.floor(progress_ms / 60000), math.floor(progress_ms / 1000) % 60)
        local duration = string.format("%d:%02d", math.floor(duration_ms / 60000), math.floor(duration_ms / 1000) % 60)
        local song_progess_text = progress .. "/" .. duration
        local song_progress_size = g_Render:CalcTextSize(song_progess_text, font_sizes.duration, font_duration)
        g_Render:Text(song_progess_text, Vector2.new(info_x + info_w - song_progress_size.x - 2, y + h - progress_bar - 1 - song_progress_size.y), colors.duration, font_sizes.duration, font_duration)
    end
end

local function render_spotify_info_minimalist(text, text_size, x, y)
    local position = Vector2.new(x, y)
    local size = Vector2.new(position.x + text_size.x + 4, position.y + 2)
    local track_position = (text_size.x + 4) * get_song_duration()

    local fade_out = Color.new(colors.minimalist_outline:r(), colors.minimalist_outline:g(), colors.minimalist_outline:b(), 0.0)
    local fade_out_container = Color.new(colors.minimalist_container:r(), colors.minimalist_container:g(), colors.minimalist_container:b(), 0.0)

    g_Render:GradientBoxFilled(Vector2.new(position.x, position.y), Vector2.new(position.x + text_size.x, position.y + text_size.y + 7), colors.minimalist_container, fade_out_container, colors.minimalist_container, fade_out_container)
    g_Render:GradientBoxFilled(Vector2.new(position.x + 2, position.y), Vector2.new(position.x + track_position, size.y), colors.minimalist_outline, fade_out, colors.minimalist_outline, fade_out)
    g_Render:GradientBoxFilled(Vector2.new(position.x + 2, position.y + text_size.y + 5), Vector2.new(position.x + track_position, position.y + text_size.y + 7), colors.minimalist_outline, fade_out, colors.minimalist_outline, fade_out)
    g_Render:BoxFilled(Vector2.new(position.x, position.y), Vector2.new(position.x + 2, position.y + text_size.y + 7), colors.minimalist_outline)
    g_Render:Text(text, Vector2.new(position.x + 2, position.y + 3), colors.minimalist_text, font_sizes.minimalist, font_minimalist)
end

cheat.RegisterCallback("draw", function()
    if not cfg_window_enable:GetBool() or not cfg_window_clantag:GetBool() then 
        if current_clantag ~= "" then
            set_clantag("", "")
            current_clantag = ""
        end
    end

    getAccessToken:update()
    getSongInfo:update()

    if g_Panorama:Exec([[songInfo;]]) == "complete" then
        getSongInfo.milliseconds = 0.2
    end

    if not song_info then return end
    if song_info then
        local title_text, title_size = get_song_title()
        local artist_text, artist_size = get_song_artists()
        local text = "Now playing: " .. title_text .. " by " .. artist_text

        local scale = cfg_window_scale:GetInt() * 0.01
        local x, y = cfg_window_position_x:GetInt(), cfg_window_position_y:GetInt()
        local w, h = cfg_window_width:GetInt() * scale, 70 * scale

        if cfg_window_colors:GetBool() then
            colors.title = cfg_window_color_title:GetColor()
            colors.artist = cfg_window_color_artist:GetColor()
            colors.duration = cfg_window_color_duration:GetColor()
            colors.container = cfg_window_color_container:GetColor()
            colors.progressbar1 = cfg_window_color_progressbar1:GetColor()
            colors.progressbar2 = cfg_window_color_progressbar2:GetColor()
            colors.minimalist_text = cfg_window_color_text_minimalist:GetColor()
            colors.minimalist_container = cfg_window_color_container_minimalist:GetColor()
            colors.minimalist_outline = cfg_window_color_outline_minimalist:GetColor()
        else
            colors = table_clone(default_colors)
        end
    
        if cfg_window_colors_rainbow:GetBool() then
            local r, g, b, a = hsv_to_rgb(hue, 1, 1, 255)
            hue = hue + 0.2 * g_GlobalVars.frametime
            if hue > 1 then hue = 0 end
    
            colors.progressbar1 = Color.new(r, g, b, a)
            colors.minimalist_outline = Color.new(r, g, b, a)
        end

        if cfg_window_cover:GetInt() ~= 0 or cfg_window_menu_bar:GetBool() then
            if old_song_id ~= song_info.item.id then
                http.GetAsync(song_info.item.album.images[2].url, function(bytes)
                    image_loaded = g_Render:LoadImage(bytes, Vector2.new(300, 300))
                end)
                old_song_id = song_info.item.id
            end
        end

        if (cfg_window_hide:GetBool() and g_EngineClient:IsConnected()) or not cfg_window_hide:GetBool() and cfg_window_enable:GetBool() then
            if cfg_window_minimalist:GetBool() then
                local text_size = g_Render:CalcTextSize(text, font_sizes.minimalist, font_minimalist)
                w, h = text_size.x, text_size.y
            
                x, y = input:handle_dragging(1, x, y, w + 2, h + 7)
                if x < 0 then x = 0 end
                if y < 0 then y = 0 end
                cfg_window_position_x:SetInt(x) 
                cfg_window_position_y:SetInt(y)

                render_spotify_info_minimalist(text, text_size, x, y)
            elseif image_loaded or cfg_window_cover:GetInt() == 0 then
                local automatic_width = cfg_window_width:GetInt() == 300
                local image_modifier = (cfg_window_cover:GetInt() ~= 0) and h or 0


                if automatic_width and (title_size.x > w - image_modifier - 19 - 12 * scale or artist_size.x > w - image_modifier - 20 - 12 * scale) then
                    w = (title_size.x > artist_size.x) and title_size.x + image_modifier + 19 + 12 * scale or artist_size.x + image_modifier + 20 + 12 * scale
                end

                x, y = input:handle_dragging(1, x, y, w, h)
                if x < 0 then x = 0 end
                if y < 0 then y = 0 end
                cfg_window_position_x:SetInt(x) 
                cfg_window_position_y:SetInt(y)

                render_spotify_info(title_text, title_size, artist_text, artist_size, x, y, w, h, scale)
            end
        end

        if cheat.IsMenuVisible() and cfg_window_menu_bar:GetBool() then
            render_spotify_controls(title_text, artist_text)
        end

        updateClantag:update()
    end
end)

cheat.RegisterCallback("destroy", function()
    FileSystem.remove_search_path(cfg_path, "GAME")
    set_clantag("", "")
end)

cfg_authorize:RegisterCallback(get_refresh_token)
cfg_deauthorize:RegisterCallback(function() deauthorize(); getAccessToken.oldtime = 0 - getAccessToken.milliseconds end)
cfg_window_scale:RegisterCallback(update_scale)
cfg_window_colors:RegisterCallback(custom_colors_callback)
cfg_window_colors_reset:RegisterCallback(callback_reset_colors)
cfg_window_minimalist:RegisterCallback(custom_colors_callback)

cfg_authorize_link:RegisterCallback(function() 
    local js = g_Panorama:Exec([[
        SteamOverlayAPI.OpenURL("]] .. authURL .. [[");
    ]])
end)

get_refresh_token_local()
custom_colors_callback()
update_scale()
