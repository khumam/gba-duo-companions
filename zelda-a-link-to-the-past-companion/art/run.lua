-- Runs main.lua offline over a ROM and a RAM dump (harness `dump`: IWRAM 32 KB, then EWRAM 256 KB) and prints
-- update()'s result per page as JSON. With --preview it writes one merged snapshot for preview-data.json.
--   lua art/run.lua ROM DUMP [--preview OUT.json] [--page name] [--ui k=v,...]
local romPath, dumpPath = arg[1], arg[2]
local function slurp(p) local f = assert(io.open(p, "rb")); local s = f:read("a"); f:close(); return s end
local ROM, RAM = slurp(romPath), slurp(dumpPath)
local writes = {}
local function byte(a)
  if a >= 0x08000000 and a < 0x0A000000 then return ROM:byte(a - 0x08000000 + 1) or 0 end
  if a >= 0x03000000 and a < 0x03008000 then return RAM:byte(a - 0x03000000 + 1) or 0 end
  if a >= 0x02000000 and a < 0x02040000 then return writes[a] or RAM:byte(a - 0x02000000 + 0x8000 + 1) or 0 end
  return 0
end
mem = {}
function mem.u8(a) return byte(a) end
function mem.s8(a) local v = byte(a); return v >= 128 and v - 256 or v end
function mem.s16(a) local v = byte(a) | (byte(a + 1) << 8); return v >= 32768 and v - 65536 or v end
function mem.u16(a) return byte(a) | (byte(a + 1) << 8) end
function mem.u32(a) return mem.u16(a) | (mem.u16(a + 2) << 16) end
function mem.read(a, n) local t = {} for i = 0, n - 1 do t[#t + 1] = string.char(byte(a + i)) end return table.concat(t) end
function mem.write8(a, v) writes[a] = v & 255; return true end
function mem.write16(a, v) writes[a] = v & 255; writes[a + 1] = (v >> 8) & 255; return true end
function log(s) io.stderr:write(s, "\n") end
pack = { require = function(n) return dofile(n .. ".lua") end }

dofile("main.lua")
init()

local function json(v, ind)
  ind = ind or ""
  local t = type(v)
  if t == "table" then
    local n = #v
    local isArr = n > 0 or next(v) == nil
    local parts = {}
    if isArr then
      for i = 1, n do parts[#parts + 1] = ind .. " " .. json(v[i], ind .. " ") end
      return "[\n" .. table.concat(parts, ",\n") .. "\n" .. ind .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    for _, k in ipairs(keys) do parts[#parts + 1] = ind .. " " .. string.format("%q", k) .. ": " .. json(rawget(v, k) == nil and v[tonumber(k)] or rawget(v, k), ind .. " ") end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. ind .. "}"
  elseif t == "string" then
    return (string.format("%q", v):gsub("\\\n", "\\n"))
  elseif t == "number" then
    if v == math.floor(v) and math.abs(v) < 2^53 then return string.format("%d", v) end
    return string.format("%.4f", v)
  else return tostring(v) end
end

local mode, out = nil, nil
local page, uiExtra = nil, {}
local i = 3
while arg[i] do
  if arg[i] == "--preview" then mode, out = "preview", arg[i + 1]; i = i + 2
  elseif arg[i] == "--page" then page = arg[i + 1]; i = i + 2
  elseif arg[i] == "--ui" then
    for kv in arg[i + 1]:gmatch("[^,]+") do
      local k, v = kv:match("([^=]+)=(.*)")
      uiExtra[k] = tonumber(v) or (v == "true" and true) or (v == "false" and false) or v
    end
    i = i + 2
  else i = i + 1 end
end

if mode == "preview" then
  -- every page's data in one snapshot, so the preview can show any page
  local merged = {}
  local states = {
    { page = "items", cell = 1 }, { page = "status" },
    { page = "dungeons" }, { page = "map" },

  }
  for _, ui in ipairs(states) do
    for k, v in pairs(uiExtra) do ui[k] = v end
    local r = update(ui)
    for k, v in pairs(r) do
      if not (k == "sw" and merged.sw and merged.sw.str and merged.sw.str.cmp) then merged[k] = v end   -- keep the Item preview arrows
    end
  end
  merged.ui = { set = { cell = 1 } }
  local f = assert(io.open(out, "w")); f:write(json(merged), "\n"); f:close()
  print("wrote " .. out)
else
  local ui = { page = page or "status" }
  for k, v in pairs(uiExtra) do ui[k] = v end
  print(json(update(ui)))
end
