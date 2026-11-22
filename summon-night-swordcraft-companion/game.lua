-- Summon Night: Swordcraft Story (AB4E) game script: only the COLOR look (ambient.lua).
-- No wide(): the game streams its maps into a 32x32-tile ring from room chunks, so there is no whole
-- metatile grid in memory to paint the margins from.
local ID = mem.read(0x080000AC, 4)
local look = ID == "AB4E" and pack.require("ambient").ambient or nil

function ambient()
  if look then return look() end
  return nil
end
