-- Runs main.lua on a save state (mGBA .ss) outside the app and writes preview-data.json from its update().
--   lua art/preview.lua path/to/slot1.ss [ch] [page]
-- Used to test the Lua on real RAM and to give the simulator / PreviewRender realistic data.
local ss = arg[1] or error("usage: lua art/preview.lua state.ss [ch]")
local f = assert(io.open(ss, "rb")); local blob = f:read("a"); f:close()
local IW, EW = 0x19000, 0x21000
local function byte(a)
  if a >= 0x03000000 and a < 0x03008000 then return blob:byte(IW + (a - 0x03000000) + 1) or 0 end
  if a >= 0x02000000 and a < 0x02040000 then return blob:byte(EW + (a - 0x02000000) + 1) or 0 end
  return 0
end
mem = {
  u8 = byte,
  u16 = function(a) return byte(a) | (byte(a + 1) << 8) end,
  u32 = function(a) return byte(a) | (byte(a + 1) << 8) | (byte(a + 2) << 16) | (byte(a + 3) << 24) end,
}
pack = { require = function(n) return dofile(n .. ".lua") end }
dofile("main.lua")
local ui = { ch = tonumber(arg[2] or 0), slot = 1, eq = 0 }
local out = update(ui)

local function enc(v, ind)
  local t = type(v)
  if t == "table" then
    if #v > 0 or next(v) == nil then
      local p = {}
      for i, x in ipairs(v) do p[#p + 1] = enc(x) end
      return "[" .. table.concat(p, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys)
    local p = {}
    for _, k in ipairs(keys) do p[#p + 1] = string.format("%q:%s", k, enc(v[k])) end
    return "{" .. table.concat(p, ",") .. "}"
  elseif t == "string" then
    return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"'
  elseif t == "boolean" or t == "number" then
    return tostring(v)
  end
  return "null"
end
local o = assert(io.open("preview-data.json", "w")); o:write(enc(out)); o:close()
print("wrote preview-data.json", out.ready, out.c and out.c.name, out.dp)
