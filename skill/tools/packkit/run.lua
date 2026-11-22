-- Runs a pack's main.lua offline over a ROM and a RAM dump (skill/tools/harness/play.py dump:NAME), the same way the
-- app does: init(), then update(ui). Prints the result as JSON, writes preview-data.json, or calls actions and lists
-- the memory writes they make (replay those with play.py wr: steps to check them in the real game).
--
--   cd PACK_DIR
--   lua ../skill/tools/packkit/run.lua ROM DUMP [--page NAME] [--ui k=v,k=v]          -> update() as JSON
--   lua ../skill/tools/packkit/run.lua ROM DUMP --preview preview-data.json --states states.json [--ui k=v]
--   lua ../skill/tools/packkit/run.lua ROM DUMP --act "useItem(41)" --act "equip(1, 3)" [--writes w.txt]
--
-- states.json: [ {"page": "status"}, {"page": "soul", "soulCat": 1}, ... ] - one update() per entry, merged into
-- one snapshot so the preview kit can render every page; its "ui" set is taken from the last "set" key if present.
-- mem.write*/mem.read/u8..s32 follow the app (little-endian; writes recorded, not limited to taps here).

local romPath, dumpPath = arg[1], arg[2]
local function slurp(p) local f = assert(io.open(p, "rb")); local s = f:read("a"); f:close(); return s end
local ROM, RAM = slurp(romPath), slurp(dumpPath)
local W, WR = {}, {}
local function byte(a)
  if a >= 0x08000000 and a < 0x0A000000 then return ROM:byte(a - 0x08000000 + 1) or 0 end
  if a >= 0x03000000 and a < 0x03008000 then return W[a] or RAM:byte(a - 0x03000000 + 1) or 0 end
  if a >= 0x02000000 and a < 0x02040000 then return W[a] or RAM:byte(a - 0x02000000 + 0x8000 + 1) or 0 end
  return 0
end
mem = {}
function mem.u8(a) return byte(a) end
function mem.s8(a) local v = byte(a); return v >= 128 and v - 256 or v end
function mem.u16(a) return byte(a) | (byte(a + 1) << 8) end
function mem.s16(a) local v = mem.u16(a); return v >= 32768 and v - 65536 or v end
function mem.u32(a) return mem.u16(a) | (mem.u16(a + 2) << 16) end
function mem.s32(a) local v = mem.u32(a); return v >= 0x80000000 and v - 0x100000000 or v end
function mem.read(a, n) local t = {} for i = 0, n - 1 do t[#t + 1] = string.char(byte(a + i)) end return table.concat(t) end
local function rec(a, v, w)
  WR[#WR + 1] = string.format("wr:%08X=%X:%d", a, v, w)
  for i = 0, w - 1 do W[a + i] = (v >> (8 * i)) & 255 end
  return true
end
function mem.write8(a, v) return rec(a, v & 0xFF, 1) end
function mem.write16(a, v) return rec(a, v & 0xFFFF, 2) end
function mem.write32(a, v) return rec(a, v & 0xFFFFFFFF, 4) end
function mem.write(a, s)            -- raw bytes, 1..64, recorded as single-byte writes
  if #s < 1 or #s > 64 then return false, "1 to 64 bytes" end
  for i = 1, #s do rec(a + i - 1, s:byte(i), 1) end
  return true
end
function log(s) io.stderr:write(tostring(s), "\n") end
pack = { require = function(n) return dofile(n .. ".lua") end }
-- gfx.* calls come back as "gfxmock:<fn>?k=v&..." keys; tools/packkit/gfxmock.py renders them (decode) from the ROM
-- into PNGs and rewrites the preview JSON, so previews show the real ROM art.
local function mockKey(fn, t)
  local keys = {}
  for k in pairs(t or {}) do if type(t[k]) ~= "table" then keys[#keys + 1] = k end end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do
    local v = t[k]
    if type(v) == "boolean" then v = v and 1 or 0 end
    parts[#parts + 1] = k .. "=" .. tostring(v)
  end
  return "gfxmock:" .. fn .. "?" .. table.concat(parts, "&")
end
gfx = setmetatable({}, { __index = function(_, fn) return function(t) return mockKey(fn, t) end end })
function lz77() return "" end

dofile("main.lua")
if init then init() end

local function json(v, ind)
  ind = ind or ""
  local t = type(v)
  if t == "table" then
    local n = #v
    local parts = {}
    if n > 0 or next(v) == nil then
      for i = 1, n do parts[#parts + 1] = ind .. " " .. json(v[i], ind .. " ") end
      return "[\n" .. table.concat(parts, ",\n") .. "\n" .. ind .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local val = rawget(v, k)
      if val == nil then val = v[tonumber(k)] end
      parts[#parts + 1] = ind .. " " .. string.format("%q", k) .. ": " .. json(val, ind .. " ")
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. ind .. "}"
  elseif t == "string" then
    return (string.format("%q", v):gsub("\\\n", "\\n"))
  elseif t == "number" then
    if v == math.floor(v) and math.abs(v) < 2 ^ 53 then return string.format("%d", v) end
    return string.format("%.4f", v)
  end
  return tostring(v)
end

local function parseUi(s, ui)
  for kv in s:gmatch("[^,]+") do
    local k, v = kv:match("([^=]+)=(.*)")
    ui[k] = tonumber(v) or (v == "true" and true) or (v == "false" and false) or v
  end
end

-- minimal JSON reader for states.json (arrays of flat objects)
local function readStates(path)
  local s = slurp(path)
  local out = {}
  for obj in s:gmatch("{(.-)}") do
    local t = {}
    for k, v in obj:gmatch('"([^"]+)"%s*:%s*([^,}]+)') do
      v = v:gsub("^%s+", ""):gsub("%s+$", "")
      if v:sub(1, 1) == '"' then t[k] = v:sub(2, -2) else t[k] = tonumber(v) or (v == "true") end
    end
    out[#out + 1] = t
  end
  return out
end

local page, extra, preview, states, acts, writes = nil, {}, nil, nil, {}, nil
local i = 3
while arg[i] do
  local a, b = arg[i], arg[i + 1]
  if a == "--page" then page = b
  elseif a == "--ui" then parseUi(b, extra)
  elseif a == "--preview" then preview = b
  elseif a == "--states" then states = b
  elseif a == "--act" then acts[#acts + 1] = b
  elseif a == "--writes" then writes = b end
  i = i + 2
end

if #acts > 0 then
  for _, call in ipairs(acts) do
    local fn = assert(load("return actions." .. call), "bad --act " .. call)
    local r = fn()
    print(call, "->", r and r.set and r.set.note or "")
  end
  for _, w in ipairs(WR) do print(w) end
  if writes then local f = io.open(writes, "w"); f:write(table.concat(WR, " "), "\n"); f:close() end
elseif preview then
  local merged = {}
  local list = states and readStates(states) or { { page = "status" } }
  for _, ui in ipairs(list) do
    for k, v in pairs(extra) do ui[k] = v end
    for k, v in pairs(update(ui)) do merged[k] = v end
  end
  merged.ui = { set = extra }
  local f = assert(io.open(preview, "w")); f:write(json(merged), "\n"); f:close()
  print("wrote " .. preview)
else
  local ui = { page = page }
  for k, v in pairs(extra) do ui[k] = v end
  print(json(update(ui)))
end
