-- The game's own graphics, drawn at runtime from the player's ROM (gfx.tilemap,
-- gfx.sprite), so the pack ships none of Nintendo's art for them.
--
-- Addresses per release, from the zeldaret/tmc decompilation (assets/gfx.json and
-- assets/assets.json give each asset's US address and the EU/JP offsets); the EU
-- ones were also found and checked pixel for pixel against the running game.
--
-- * World map: the pause screen's map, a text background (gGfx_94_0 tiles,
--   gGfx_94_1 tilemap, palette banks 6-12 from gPalette_2224). The map is tilemap
--   cells 5..24 x 1..16 = 160 x 128 px, the rectangle pauseMenu.c draws Link on.
-- * Item icons: the pause screen's item sprites. gSpriteAnimations_322[item] gives
--   a frame; gSpriteFrames_322[frame] its first tile in gSprite_082E68F4; and
--   gFrameObjLists (sprite 0x141 in EU, 0x142 elsewhere) the frame's object layout:
--   a count, then 5 bytes per object (x, y, flags, tile, high). Flags bit 0 means the
--   palette bank is absolute (high >> 4), else it's 3 + (high >> 4) as the pause menu
--   draws; bits 2/3 flip; bits 4-5 size and 6-7 shape. Palettes: gPalette_0 onward.
-- * Heart piece: the Quest Status screen's container at 0-3 of 4 pieces, one 32x32
--   sprite each at gGfx_91_2 + 0xC00 + pieces * 0x200, palette gPalette_2219.
--   Found on the EU Quest Status screen (2/4 on screen), US/JP from gfx.json.
-- * Ezlo: the EzloCap sprite (sprite 11, the cap that pops off Link's head to talk),
--   frame 44 (beak open). Frames gSpriteFrames_EzloCap, tiles gSprite_Link, palette
--   Link's (gPalette_0 + 14 * 32, the OBJ bank the game loads for him). Checked against
--   a state saved while Ezlo was talking.
-- * Title logo: "The Legend of Zelda: The Minish Cap" from the title screen, 14 sprites
--   (the OAM layout below) over fixedTypeGfx_511/512/513 and palettes gPalette_3419,
--   3421, 3423 (adjacent). From a state saved on the EU title screen; US from gfx.json.
--   Not for JP, whose logo is the Japanese one: that release keeps the pack's logo.
-- * Link: sprite 1 (gSpriteFrames_1 over gSprite_Link, his palette as for Ezlo), frame 0:
--   standing, facing down.
-- * Hearts: the HUD's heart tiles, 8x8 each in gGfx_89_2 + 0x220: empty, 1/4, 1/2, 3/4,
--   full, in that order, with gPalette_12 (BG bank 15 on screen). Found in a state saved
--   in play (BG0 tiles 0x11-0x15).
-- * Link's head: the marker the pause screen's world map draws Link with (pauseMenu.c,
--   DrawDirect sprite 0x1FA EU / 0x1FB, frame 0x59): a 16x16 at OBJ tile 0x240, which the
--   world map screen's gfx group 93 fills from gGfx_94_3 + 0x800. Drawn with Link's own
--   palette (gPalette_0 + 14 * 32), the colours he has on that screen.
-- * Dungeon items: the pause menu's dungeon map page (pauseMenu.c DrawDungeonMapActually)
--   draws the map, compass and big key with sprite 0x143 (EU, 0x144 elsewhere), the frame
--   gSpriteAnimations_322[0x50 + n] gives, over fixedTypeGfx_521 (OBJ tile 0x380, loaded
--   by gfx group 0x81). Map at palette bank 4, compass at 0, the big key's own bank 1.
--   The small key (0x53) isn't drawn there; it uses bank 4 like the map. Rebuilt from the
--   EU ROM; US from gfx.json, JP inferred from the hearts' JP offset.

local M = {}

local RELEASES = {
  BZMP = { -- EU
    mapTiles = 0x08931DB0, map = 0x08935DB0, mapPalette6 = 0x085B39D0,
    anims = 0x080FD51C, frames = 0x0811ACC0, tiles = 0x082E5FE0, objLists = 0x082F3460, sprite = 0x141,
    objPalette = 0x085A23D0,
    questGfx = 0x08910270, questPalette = 0x085B3930,
    ezloFrames = 0x0811651C, linkGfx = 0x0813A500, linkFrames = 0x081146E0,
    logoTiles = 0x088D5F30, logoPalette = 0x085BCEF0,
    heartTiles = 0x085C2D90, hudPalette = 0x085A2550,
    dungeonTiles = 0x085C2470, mapObjTiles = 0x08936CB0,
  },
  BZME = { -- US
    mapTiles = 0x08934FE0, map = 0x08938FE0, mapPalette6 = 0x085B4480,
    anims = 0x080FDFD8, frames = 0x0811B578, tiles = 0x082E68F4, objLists = 0x082F3D74, sprite = 0x142,
    objPalette = 0x085A2E80,
    questGfx = 0x089134A0, questPalette = 0x085B43E0,
    ezloFrames = 0x08116DD4, linkGfx = 0x0813AE14, linkFrames = 0x08114F98,
    logoTiles = 0x088D6760, logoPalette = 0x085BD9E0,
    heartTiles = 0x085C3880, hudPalette = 0x085A3000,
    dungeonTiles = 0x085C2F60, mapObjTiles = 0x08939EE0,
  },
  BZMJ = { -- JP
    mapTiles = 0x08934C80, map = 0x08938C80, mapPalette6 = 0x085B4120,
    anims = 0x080FDC88, frames = 0x0811B23C, tiles = 0x082E6520, objLists = 0x082F39A0, sprite = 0x142,
    objPalette = 0x085A2B20,
    questGfx = 0x08913140, questPalette = 0x085B4080,
    ezloFrames = 0x08116A98, linkGfx = 0x0813AA40, linkFrames = 0x08114C5C,
    heartTiles = 0x085C3520, hudPalette = 0x085A2CA0,
    dungeonTiles = 0x085C2C00, mapObjTiles = 0x08939B80,
  },
}

-- Item ids whose pause-screen sprite is a real icon. The rest of the table holds
-- placeholders (a sword, a bomb, a lantern) for things the pause screen never shows.
local HAS_ICON = {}
for id = 0x01, 0x17 do HAS_ICON[id] = true end
HAS_ICON[0x05] = nil -- unused sword: placeholder
for id = 0x1C, 0x31 do HAS_ICON[id] = true end -- bottles and their contents, charms, picolytes
for id = 0x36, 0x46 do HAS_ICON[id] = true end -- quest items, shells, elements, grip ring, bracelets, flippers
for id = 0x48, 0x4F do HAS_ICON[id] = true end -- tiger scrolls
for id = 0x62, 0x67 do HAS_ICON[id] = true end -- heart container, wallet, bomb bag, quiver, kinstone bag

local SIZES = { -- [shape][size] = { w, h }
  [0] = { [0] = { 8, 8 }, { 16, 16 }, { 32, 32 }, { 64, 64 } },
  [1] = { [0] = { 16, 8 }, { 32, 8 }, { 32, 16 }, { 64, 32 } },
  [2] = { [0] = { 8, 16 }, { 8, 32 }, { 16, 32 }, { 32, 64 } },
}

local release
local function current()
  if release ~= nil then return release or nil end
  local code = {}
  for i = 0, 3 do code[#code + 1] = string.char(mem.u8(0x080000AC + i)) end
  release = RELEASES[table.concat(code)] or false
  return release or nil
end

-- gfx.* is called on every request, not once: the app keeps a limited number of
-- images and redraws a dropped one only when it's asked for again. Only the
-- arguments are worked out once (false: nothing to draw).
local function draw(fn, args, what)
  if not args then return nil end
  local ok, key = pcall(fn, args)
  if ok then return key end
  log(what .. ": " .. tostring(key))
  return nil
end

local mapArgs
--- The world map's image key, or nil on an unknown release.
function M.worldMap()
  if mapArgs == nil then
    local r = current()
    mapArgs = r and {
      tiles = r.mapTiles, map = r.map, palette = r.mapPalette6 - 6 * 32,
      stride = 32, x = 5, y = 1, width = 160, height = 128, opaque = true,
    } or false
  end
  return draw(gfx.tilemap, mapArgs, "world map")
end

-- The pause screen's ammo counter: a 16x8 object at (-1, -4) on the frame's first
-- tile, filled with digits at runtime. Left out: the pack shows counts itself.
local function isCounter(x, y, flags, tile)
  return flags == 0x40 and x == -1 and y == -4 and tile == 0
end

local function s8(v) return v >= 128 and v - 256 or v end

-- The sprite arguments for one frame of a sprite: [frames] gives the frame's first
-- tile in [gfx] (nil: tile 0), gFrameObjLists (entry [sprite]) its objects. [bankOf](flags, high)
-- picks each object's palette bank. False if the frame can't be drawn.
local function frameArgs(r, sprite, frames, gfx, palette, frame, bankOf)
  local firstTile = frames and mem.u16(frames + frame * 4 + 2) or 0
  local list = r.objLists + mem.u32(r.objLists + mem.u32(r.objLists + sprite * 4) + frame * 4)

  local parts, minX, minY, maxX, maxY = {}, 1e9, 1e9, -1e9, -1e9
  for i = 0, math.min(mem.u8(list), 32) - 1 do
    local e = list + 1 + i * 5
    local x, y, flags, tile, high = s8(mem.u8(e)), s8(mem.u8(e + 1)), mem.u8(e + 2), mem.u8(e + 3), mem.u8(e + 4)
    if not isCounter(x, y, flags, tile) then
      local size = SIZES[flags >> 6] and SIZES[flags >> 6][(flags >> 4) & 3]
      if not size then return false end
      parts[#parts + 1] = {
        x = x, y = y, w = size[1], h = size[2], tile = firstTile + tile, bank = bankOf(flags, high) & 15,
        hflip = flags & 4 ~= 0, vflip = flags & 8 ~= 0,
      }
      minX, minY = math.min(minX, x), math.min(minY, y)
      maxX, maxY = math.max(maxX, x + size[1]), math.max(maxY, y + size[2])
    end
  end
  if #parts == 0 then return false end
  for _, p in ipairs(parts) do p.x, p.y = p.x - minX, p.y - minY end
  return { tiles = gfx, palette = palette, width = maxX - minX, height = maxY - minY, parts = parts }
end

-- The pause menu's palette banks: absolute with flags bit 0, else from bank 3.
local function pauseBank(flags, high)
  return (flags & 1 == 1) and (high >> 4) or (3 + (high >> 4))
end

-- The sprite arguments for an item's icon, or false if the ROM has none for it.
local function iconArgs(id)
  local r = current()
  if not r or not HAS_ICON[id] then return false end
  local anim = mem.u32(r.anims + id * 4)
  if anim < 0x08000000 or anim >= 0x0A000000 then return false end
  local frame = mem.u8(anim)
  if frame == 0xFF then return false end
  return frameArgs(r, r.sprite, r.frames, r.tiles, r.objPalette, frame, pauseBank)
end

local icons = {}
--- The item's pause-screen icon as an image key, or nil if the ROM has none for it.
function M.itemIcon(id)
  if not id then return nil end
  if icons[id] == nil then icons[id] = iconArgs(id) end
  return draw(gfx.sprite, icons[id], "item icon " .. id)
end

local hearts = {}
--- The heart-piece container showing [pieces] (0-3) of 4, as an image key; nil on an unknown release.
function M.heartPiece(pieces)
  pieces = math.max(0, math.min(3, math.floor(pieces or 0)))
  if hearts[pieces] == nil then
    local r = current()
    hearts[pieces] = r and {
      tiles = r.questGfx, palette = r.questPalette, width = 32, height = 32,
      parts = { { x = 0, y = 0, w = 32, h = 32, tile = (0xC00 + pieces * 0x200) // 32, bank = 0 } },
    } or false
  end
  return draw(gfx.sprite, hearts[pieces], "heart piece")
end

local LINK_SPRITE, LINK_FRAME = 1, 0

local linkArgs
--- Link standing, facing down, as an image key; nil on an unknown release.
function M.link()
  if linkArgs == nil then
    local r = current()
    linkArgs = r and frameArgs(r, LINK_SPRITE, r.linkFrames, r.linkGfx, r.objPalette + 14 * 32, LINK_FRAME,
      function(_, high) return high >> 4 end) or false
  end
  return draw(gfx.sprite, linkArgs, "link")
end

local heartArgs = {}
--- The HUD heart holding [quarters] (0 empty .. 4 full) as an 8x8 image key; nil on an unknown release.
function M.heart(quarters)
  quarters = math.max(0, math.min(4, math.floor(quarters or 0)))
  if heartArgs[quarters] == nil then
    local r = current()
    heartArgs[quarters] = r and {
      tiles = r.heartTiles, palette = r.hudPalette, width = 8, height = 8,
      parts = { { x = 0, y = 0, w = 8, h = 8, tile = quarters, bank = 0 } },
    } or false
  end
  return draw(gfx.sprite, heartArgs[quarters], "heart")
end

local headArgs
--- Link's head, the pause map's marker for him, as a 16x16 image key; nil on an unknown release.
function M.linkHead()
  if headArgs == nil then
    local r = current()
    headArgs = r and {
      tiles = r.mapObjTiles + 0x800, palette = r.objPalette + 14 * 32, width = 16, height = 16,
      parts = { { x = 0, y = 0, w = 16, h = 16, tile = 0, bank = 0 } },
    } or false
  end
  return draw(gfx.sprite, headArgs, "link head")
end

-- Dungeon items: item id and the palette bank the dungeon map page draws it with.
local DUNGEON_ITEMS = {
  map = { 0x50, 4 }, compass = { 0x51, 0 }, bigKey = { 0x52, 4 }, smallKey = { 0x53, 4 },
}

local dungeonArgs = {}
--- A dungeon item's icon ("map", "compass", "bigKey", "smallKey") as an image key; nil on an unknown release.
function M.dungeonItem(kind)
  local item = DUNGEON_ITEMS[kind]
  if not item then return nil end
  if dungeonArgs[kind] == nil then
    local r = current()
    local anim = r and mem.u32(r.anims + item[1] * 4)
    dungeonArgs[kind] = (r and anim >= 0x08000000 and anim < 0x0A000000)
      and frameArgs(r, r.sprite + 2, nil, r.dungeonTiles, r.objPalette, mem.u8(anim), function(flags, high)
        return (flags & 1 == 1) and (high >> 4) or (item[2] + (high >> 4))
      end) or false
  end
  return draw(gfx.sprite, dungeonArgs[kind], "dungeon " .. kind)
end

local EZLO_SPRITE, EZLO_FRAME = 11, 44

local ezloArgs
--- Ezlo popping out to talk, as an image key; nil on an unknown release.
function M.ezlo()
  if ezloArgs == nil then
    local r = current()
    ezloArgs = r and frameArgs(r, EZLO_SPRITE, r.ezloFrames, r.linkGfx, r.objPalette + 14 * 32, EZLO_FRAME,
      function(_, high) return high >> 4 end) or false
  end
  return draw(gfx.sprite, ezloArgs, "ezlo")
end

-- The title screen's logo objects, in OAM order (the first is drawn on top), placed
-- relative to the logo's top left. tile counts from fixedTypeGfx_511: 512 starts 496
-- tiles on, 513 656. bank counts from gPalette_3419: 3421 is bank 2, 3423 bank 4.
local LOGO_PARTS = {
  { x = 152, y = 9, w = 16, h = 8, tile = 657, bank = 4 },   -- TM (Zelda)
  { x = 160, y = 65, w = 16, h = 16, tile = 659, bank = 4 }, -- TM (Minish Cap)
  { x = 40, y = 57, w = 32, h = 32, tile = 496, bank = 4 },  -- "The Minish Cap"
  { x = 72, y = 57, w = 32, h = 32, tile = 512, bank = 4 },
  { x = 104, y = 57, w = 32, h = 32, tile = 528, bank = 4 },
  { x = 136, y = 57, w = 32, h = 32, tile = 544, bank = 4 },
  { x = 120, y = 41, w = 32, h = 16, tile = 560, bank = 4 }, -- the flourish on the "C"
  { x = 0, y = 0, w = 64, h = 64, tile = 0, bank = 2 },      -- "ZELDA", "The Legend of"
  { x = 0, y = 64, w = 32, h = 8, tile = 64, bank = 2 },
  { x = 32, y = 64, w = 32, h = 8, tile = 68, bank = 2 },
  { x = 64, y = 0, w = 64, h = 64, tile = 72, bank = 2 },
  { x = 128, y = 0, w = 32, h = 32, tile = 136, bank = 2 },
  { x = 128, y = 32, w = 32, h = 32, tile = 152, bank = 2 },
  { x = 160, y = 32, w = 16, h = 32, tile = 168, bank = 2 },
}

local logoArgs
--- The title screen's logo (176 x 89) as an image key; nil on JP or an unknown release.
function M.titleLogo()
  if logoArgs == nil then
    local r = current()
    logoArgs = (r and r.logoTiles) and {
      tiles = r.logoTiles, palette = r.logoPalette, width = 176, height = 89, parts = LOGO_PARTS,
    } or false
  end
  return draw(gfx.sprite, logoArgs, "title logo")
end

return M
