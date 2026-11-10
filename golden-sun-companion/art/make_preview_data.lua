-- Writes preview-data.json for skill/preview-pack.sh: runs main.lua's update() against fake RAM (a four-person party
-- with items, spells and Djinn) and dumps what it returns. Run from the pack folder:
--   lua art/make_preview_data.lua [page [out.json]]   (the page sets the nav highlight: party, djinn, psynergy, maps, options)
local dir = arg[0]:match("^(.*)/art/") or "."
local ram, modules = {}, {}
local function put(addr, value, size)
  for i = 0, (size or 1) - 1 do ram[addr + i] = (value >> (8 * i)) & 255 end
end
mem = {}
function mem.u8(a) return ram[a] or 0 end
function mem.u16(a) return mem.u8(a) | (mem.u8(a + 1) << 8) end
function mem.u32(a) return mem.u16(a) | (mem.u16(a + 2) << 16) end
function mem.read(a, n) local t = {} for i = 0, n - 1 do t[#t + 1] = string.char(mem.u8(a + i)) end return table.concat(t) end
gfx = { layers = function() return "gfx" end, sprite = function() return "gfx" end }
log = function() end
pack = { require = function(m)
  if not modules[m] then modules[m] = assert(loadfile(dir .. "/" .. m .. ".lua"))() end
  return modules[m]
end }
actions = {}
assert(loadfile(dir .. "/main.lua"))()

local BASE, SIZE = 0x02000500, 0x14C
local chars = {
  { "Isaac", 28, 263, 263, 86, 112, 210, 139, 101, 24, 48210, { 0x01, 0x04, 0x06, 0x0F }, { 3, 4, 6, 100 }, { 7, 0, 3, 1 } },
  { "Garet", 28, 51, 255, 40, 96, 190, 150, 90, 19, 47100, { 0x02, 0x0D, 0x11 }, { 45, 48, 51 }, { 0, 0, 7, 2 } },
  { "Ivan", 27, 198, 198, 120, 140, 150, 98, 160, 31, 44800, { 0x0B, 0x0D }, { 69, 70, 79 }, { 0, 1, 0, 7 } },
  { "Mia", 27, 0, 210, 70, 130, 160, 110, 120, 28, 44200, { 0x01 }, { 24, 25, 100 }, { 0, 7, 2, 0 } },
}
for i, c in ipairs(chars) do
  local b = BASE + (i - 1) * SIZE
  for k = 1, #c[1] do put(b + k - 1, c[1]:byte(k)) end
  put(b + 0x0F, c[2]); put(b + 0x34, c[4], 2); put(b + 0x38, c[3], 2); put(b + 0x36, c[6], 2); put(b + 0x3A, c[5], 2)
  put(b + 0x3C, c[7], 2); put(b + 0x3E, c[8], 2); put(b + 0x40, c[9], 2); put(b + 0x42, c[10])
  put(b + 0x124, c[11], 4)
  for e = 1, 4 do put(b + 0x48 + (e - 1) * 4, c[14][e] * 10 + 20, 2); put(b + 0x48 + (e - 1) * 4 + 2, 50, 2) end
  for s, id in ipairs(c[12]) do put(b + 0xD8 + (s - 1) * 2, id | (s <= 2 and 0x200 or 0), 2) end
  for s, id in ipairs(c[13]) do put(b + 0x58 + (s - 1) * 4, id, 4) end
  put(0x0200001C + i - 1, i - 1)
end
put(0x0200001C + 4, 0xFF); put(0x02000014, 14230, 4)
-- Djinn: Isaac holds Flint, Granite, Quartz, Sap (Granite and Sap on Standby); Garet Forge, Corona, Scorch (Scorch Standby);
-- Ivan Breeze, Zephyr, Smog, Kite; Mia Fizz, Sleet, Spritz, Hail, Tonic (Tonic Standby)
local function djinn(i, masks, set)
  local b = BASE + (i - 1) * SIZE
  for e = 1, 4 do put(b + 0xF8 + (e - 1) * 4, masks[e], 4); put(b + 0x108 + (e - 1) * 4, set[e], 4) end
end
djinn(1, { 0x1f, 0, 0, 0 }, { 0xd, 0, 0, 0 })
djinn(2, { 0, 0, 0x15, 0 }, { 0, 0, 0x5, 0 })
djinn(3, { 0, 0, 0, 0x37 }, { 0, 0, 0, 0x37 })
djinn(4, { 0, 0x2b, 0, 0 }, { 0, 0xb, 0, 0 })

local function json(v)
  local t = type(v)
  if t == "table" then
    if #v > 0 or next(v) == nil then
      local parts = {}
      for _, x in ipairs(v) do parts[#parts + 1] = json(x) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = json(k) .. ":" .. json(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif t == "string" then
    return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"'
  end
  return tostring(v)
end
local page = arg[1] or "party"
local out = update({ page = page, member = 0, item = 0 })
assert(out.ready, "fake party must be ready")
out.map = { on = false, off = true, hasMe = false }
out._wide, out._wideLabel, out._ambient, out._ambientLabel = 0, "OFF", 1, "ON"
local f = assert(io.open(arg[2] or (dir .. "/preview-data.json"), "w")); f:write(json(out)); f:close()
print("preview-data.json written, " .. #out.members .. " members, " .. out.djinnNote)
