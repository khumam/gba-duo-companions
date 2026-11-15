-- Runs main.lua against the real ROM + a RAM dump and prints the result as JSON (preview data).
-- usage: lua test-dump.lua DIR dump.bin > out.json
log = function() end
local dir, dumpName = arg[1], arg[2]
local function slurp(p) local f = assert(io.open(p, "rb")); local s = f:read("a"); f:close(); return s end
local rom, dump = slurp(dir .. "/romx/Pokemon Monomyth.gba"), slurp(dir .. "/" .. dumpName)
local iwram, ewram = dump:sub(1, 32768), dump:sub(32769, 32768 + 0x40000)
local function byte(a)
  if a >= 0x08000000 and a < 0x0A000000 then return rom:byte(a - 0x08000000 + 1) or 0 end
  if a >= 0x03000000 and a < 0x03008000 then return iwram:byte(a - 0x03000000 + 1) or 0 end
  if a >= 0x02000000 and a < 0x02040000 then return ewram:byte(a - 0x02000000 + 1) or 0 end
  return 0
end
mem = { u8 = byte, u16 = function(a) return byte(a) | (byte(a + 1) << 8) end,
  u32 = function(a) return byte(a) | (byte(a + 1) << 8) | (byte(a + 2) << 16) | (byte(a + 3) << 24) end,
  read = function(a, n) local t = {} for i = 0, n - 1 do t[#t + 1] = string.char(byte(a + i)) end return table.concat(t) end }
dofile(arg[3] or "main.lua")
log = print
local r = update({ page = arg[4] or "party", mapView = arg[5] })
local function enc(v)
  local t = type(v)
  if t == "table" then
    if #v > 0 or next(v) == nil then
      local o = {} for i, x in ipairs(v) do o[#o + 1] = enc(x) end return "[" .. table.concat(o, ",") .. "]"
    end
    local keys = {} for k in pairs(v) do keys[#keys + 1] = k end table.sort(keys)
    local o = {} for _, k in ipairs(keys) do o[#o + 1] = string.format("%q:%s", k, enc(v[k])) end return "{" .. table.concat(o, ",") .. "}"
  elseif t == "string" then return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"'
  elseif t == "number" then if v ~= v then return "0" end return string.format("%.6g", v)
  else return tostring(v) end
end
print(enc(r))
