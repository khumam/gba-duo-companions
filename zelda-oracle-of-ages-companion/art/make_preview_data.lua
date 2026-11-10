-- Writes preview-data.json for skill/preview-pack.sh: runs main.lua's update() against fake RAM (a mid-game file: seven
-- hearts, some items, five essences, some rings) and dumps what it returns. Run from the pack folder:
--   lua art/make_preview_data.lua [page [out.json]]   (the page sets the nav highlight: items, map, seeds, rings, status)
local dir = arg[0]:match("^(.*)/art/") or "."
local ram = {}
local function put(addr, value, size) for i = 0, (size or 1) - 1 do ram[addr + i] = (value >> (8 * i)) & 255 end end
mem = {}
function mem.u8(a) return ram[a] or 0 end
function mem.u16(a) return mem.u8(a) | (mem.u8(a + 1) << 8) end
function mem.u32(a) return mem.u16(a) | (mem.u16(a + 2) << 16) end
log = function() end
pack = { require = function(m) return assert(loadfile(dir .. "/" .. m .. ".lua"))() end }
actions = {}
assert(loadfile(dir .. "/main.lua"))()

put(0xC6AB, 28); put(0xC6AA, 22)                 -- seven hearts, 5 3/4 full
put(0xC6AC, 2)                                   -- two heart pieces
put(0xC6AD, 0x0347, 2)                           -- 347 rupees (BCD)
put(0xC688, 0x05); put(0xC689, 0x01)             -- B sword, A shield
put(0xC6B2, 2); put(0xC6AF, 2)                   -- L-2 sword, L-2 shield
local inv = { 0x03, 0x04, 0x06, 0x0A, 0x0D, 0x0E, 0x11, 0x15, 0x16, 0x17, 0x19 }
for i, id in ipairs(inv) do put(0xC68A + i - 1, id) end
put(0xC6B0, 0x12); put(0xC6B1, 0x30); put(0xC6B3, 0x08) -- bombs 12/30, bombchus 8
put(0xC6B6, 1); put(0xC6B8, 2)                   -- hook L-1, bracelet L-2
for i, v in ipairs({ 0x20, 0x15, 0x09, 0x30, 0x12 }) do put(0xC6B9 + i - 1, v) end
put(0xC6BE, 0x07); put(0xC6C4, 2)
put(0xC6BF, 0x57)                                -- five essences
put(0xC6B7, 1)
for i, id in ipairs({ 0, 3, 12, 8, 0xFF }) do put(0xC6C6 + i - 1, id) end
put(0xC6CB, 3); put(0xC6CC, 2)
for r = 0, 63 do if r % 3 ~= 1 then put(0xC616 + r // 8, mem.u8(0xC616 + r // 8) | (1 << (r % 8))) end end
put(0xCC2D, 1); put(0xCC30, 0x55)
for room = 0, 0xDF do if room % 16 < 14 and (room // 16) < 14 and (room % 7 ~= 0 or room % 3 == 0) then put(0xC800 + room, 0x10) end end

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
local page = arg[1] or "items"
local out = update({ page = page })
assert(out.ready, "fake file must be ready")
local f = assert(io.open(arg[2] or (dir .. "/preview-data.json"), "w")); f:write(json(out)); f:close()
print("preview-data.json written for " .. page)
