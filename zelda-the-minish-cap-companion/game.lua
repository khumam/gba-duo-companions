-- The Minish Cap (BZM*, same RAM addresses in the US, EU and JP builds): the wide view. Describes
-- the two map layers the game keeps in RAM so GBADuo can paint the margins beside the 240x160 frame.
-- Reads only; the app checks every frame that this matches what the game drew and hides the margins
-- when not. Contract: docs-packs/game-script.md in the app repo.
--
-- Source: zeldaret/tmc (include/map.h, include/room.h, linker.ld). A room is up to 64x64 tiles of
-- 16x16 px in two layers (MapLayer): mapData (u16 tile index, row stride 64) and subTiles (4 u16
-- tile entries per tile index: TL, TR, BL, BR). Special cells (>= 0x4000) go through tileIndices.

local ROOM = 0x03000BF0           -- gRoomControls
local R_ORIGIN_X = 0x06           -- u16: where the room starts in the game's world
local R_ORIGIN_Y = 0x08
local R_SCROLL_X = 0x0A           -- s16: camera, in the same world
local R_SCROLL_Y = 0x0C
local R_WIDTH = 0x1E              -- u16: room size in pixels
local R_HEIGHT = 0x20

local MAP_TOP = 0x0200B650        -- gMapTop
local MAP_BOTTOM = 0x02025EB0     -- gMapBottom
local L_BG = 0x00                 -- BgSettings*: its first u16 is the BG control register
local L_DATA = 0x0004             -- mapData[64 * 64]
local L_INDICES = 0x6004          -- tileIndices[2048]
local L_SUBTILES = 0x7004         -- subTiles[2048 * 4]

local GSCREEN_BG0 = 0x03000F58    -- gScreen.bg0; BgSettings { control, xOffset, yOffset, ... } is 12 bytes
local REG_BG0HOFS = 0x04000010    -- BGnHOFS, BGnVOFS follow every 4 bytes

local STRIDE = 64
local DEBUG = false
local logged = 0
local lastBucket, nilLogged = -1, false
local function bucketChanged(view)   -- debug: true when the match crosses into another 5% step (not on every frame)
  local b = math.floor(view.match * 20)
  if b == lastBucket then return false end
  lastBucket = b
  return true
end

local function s16(v)
  if v >= 0x8000 then return v - 0x10000 end
  return v
end

local function layer(base)
  local bg = mem.u32(base + L_BG)
  if bg < 0x03000000 or bg >= 0x03008000 then return nil end
  local control = mem.u16(bg)
  return {
    grid = base + L_DATA, stride = STRIDE,
    idMask = 0x7FF, special = base + L_INDICES,
    metatiles = base + L_SUBTILES,
    tiles = 0x06000000 + ((control >> 2) & 3) * 0x4000,
  }
end

-- The game updates RAM (room scroll, gScreen.bgN) a frame before the hardware registers hold it, so
-- while the camera moves the picture trails the room scroll by a pixel or two. The BG offset is the
-- scroll modulo 16 (the map is redrawn a tile at a time), so the bottom layer's hardware offset minus
-- the value the game wrote, wrapped to -8..7, tells how far behind the drawn frame is.
local function lag(base)
  local bg = mem.u32(base + L_BG)
  local i = (bg - GSCREEN_BG0) // 12
  if i < 0 or i > 3 then return 0, 0 end
  local function d(hw, game) return ((hw - game + 8) % 16) - 8 end
  return d(mem.u16(REG_BG0HOFS + i * 4), mem.u16(bg + 2)), d(mem.u16(REG_BG0HOFS + i * 4 + 2), mem.u16(bg + 4))
end

-- Markers for the wide margins: the enemies and NPCs of the room, read from the game's entity array (zeldaret/tmc
-- include/entity.h: 0x88 bytes each, kind @0x08 (3 enemy, 7 NPC), x @0x2C, y @0x30, z @0x34, the world pixel
-- in the high half; a free slot has prev = 0xFFFFFFFF). gPlayerEntity is slot 0.
--
-- Each is drawn as its sprite, the way the game's own OAM builder does it (asm/src/intr.s, arm_DrawEntities).
-- A piece list is a count byte, then 5 bytes a piece (x, y, shape/size/flip, tile, tile high); it comes from
-- gFrameObjLists[sprite index][frame]. What an entity draws depends on its spriteAnimation[2] (s8 @0x28):
--   0   the entity's own sprite (s16 @0x12) and frame (u8 @0x1E), tiles from its spriteVramOffset (u16 @0x60);
--   > 0 up to four parts in gUnk_020000C0[n] (0x10 bytes each, stopping at the first one that is off): flags
--       @0 (bit 0 on, bit 1 = "draw the entity at @0xC instead"), frame @1, sprite index u16 @2, flip bits @4, palette
--       @5, x and y offsets s8 @6 and @7, tile offset @8 (NPCs are built like this: body, head, ...);
--   < 0 a piece list the entity keeps at @0x64.
-- The frame is already in OBJ VRAM while the entity is loaded, so reading it live works off screen. An unknown
-- ROM version, or anything that does not look right, draws nothing (never a placeholder).
local ENTITIES = 0x03001160       -- gEntities (slot 0 is gPlayerEntity)
local ENTITY_SIZE = 0x88
local ENTITY_COUNT = 80
local E_KIND = 0x08
local E_SPRITE, E_FLAGS, E_PALETTE, E_FRAME, E_PARTS = 0x12, 0x18, 0x1A, 0x1E, 0x28
local E_X, E_Y, E_Z = 0x2E, 0x32, 0x36
local E_FRAME_FLAGS, E_VRAM, E_OFFX, E_OFFY, E_LIST = 0x5B, 0x60, 0x62, 0x63, 0x64
local KIND_ENEMY, KIND_PROJECTILE, KIND_OBJECT, KIND_NPC = 3, 4, 6, 7
local MAX_MARKERS = 64
local PARTS, PART_SIZE, PART_COUNT = 0x020000C0, 0x10, 4
local OBJ_TILES, OBJ_PALETTE = 0x06010000, 0x05000200
local ROM_CODE = 0x080000AC

-- gFrameObjLists per ROM version (the decomp's USA address is not checked on a device)
local FRAME_LISTS = { [0x504D5A42] = 0x082F3460, [0x454D5A42] = 0x082F3D74 }   -- BZMP (EU), BZME (US)
-- gFrameObjLists[0] is where the first sprite's frame table starts, so it is also 4 x the number of sprites: 0x7FC in
-- the EU build, 0x800 in the US one (one more sprite). Checked against both ROMs.
local frameLists, frameListsChecked, spriteCount = nil, false, 0
local function findFrameLists()
  if not frameListsChecked then
    frameListsChecked = true
    local at = FRAME_LISTS[mem.u32(ROM_CODE)]
    local first = at and mem.u32(at) or 0
    if first >= 0x7FC and first <= 0x820 and first % 4 == 0 then frameLists, spriteCount = at, first // 4 end
  end
  return frameLists
end

-- OAM shape (0 square, 1 wide, 2 tall) and size to pixels
local PIECE_W = { { 8, 16, 32, 64 }, { 16, 32, 32, 64 }, { 8, 8, 16, 32 } }
local PIECE_H = { { 8, 16, 32, 64 }, { 8, 8, 16, 32 }, { 16, 32, 32, 64 } }

local function inIwram(p) return p >= 0x03000000 and p < 0x03008000 end
local function inRam(p) return inIwram(p) or (p >= 0x02000000 and p < 0x02040000) end

local function s8(v) if v >= 0x80 then return v - 0x100 end return v end

-- The address of the piece list for [sprite], [frame], or nil.
local function frameList(sprite, frame)
  local lists = findFrameLists()
  if not lists or frame == 0xFF or sprite < 0 or sprite >= spriteCount then return nil end
  local per = mem.u32(lists + sprite * 4)
  if per < 0x400 or per >= 0x100000 then return nil end
  local at = mem.u32(lists + per + frame * 4)
  if at < 0x400 or at >= 0x400000 then return nil end
  return lists + at
end

-- Adds the pieces of the list at [list] to [out]: (x, y) is where the sprite stands, [vram] the tile the entity's
-- graphics start at, [palette] the bank, [flipX] a mirrored sprite.
local function addPieces(out, kind, list, x, y, vram, palette, flipX)
  local count = mem.u8(list)
  if count == 0 or count > 16 or #out + count > MAX_MARKERS then return end
  for i = 0, count - 1 do
    local p = list + 1 + i * 5
    local px, py, shape, tile, high = s8(mem.u8(p)), s8(mem.u8(p + 1)), mem.u8(p + 2), mem.u8(p + 3), mem.u8(p + 4)
    local form, size = shape >> 6, (shape >> 4) & 3
    if form > 2 then return end
    local w, h = PIECE_W[form + 1][size + 1], PIECE_H[form + 1][size + 1]
    local attr = (vram | (palette << 12)) + tile
    if shape & 1 ~= 0 then attr = attr & 0x0FFF end
    attr = attr + (high << 8)
    local hflip = shape & 4 ~= 0
    local ox = px
    if flipX then ox, hflip = -px - w, not hflip end
    out[#out + 1] = {
      x = x + ox, y = y + py, kind = kind,
      tiles = OBJ_TILES + (attr & 0x3FF) * 32, palette = OBJ_PALETTE + ((attr >> 12) & 0xF) * 32,
      w = w, h = h, hflip = hflip and 1 or 0,
    }
  end
end

-- Adds entity [e]'s own sprite (what the game does for a part that points at another entity too).
local function addMain(out, e, kind, originX, originY)
  local flipX = (mem.u8(e + E_FLAGS) ~ mem.u8(e + E_FRAME_FLAGS)) & 0x40 ~= 0
  local x = mem.u16(e + E_X) - originX + s8(mem.u8(e + E_OFFX))
  local y = mem.u16(e + E_Y) + s16(mem.u16(e + E_Z)) - originY + s8(mem.u8(e + E_OFFY))
  local list = frameList(mem.u16(e + E_SPRITE), mem.u8(e + E_FRAME))
  if list then addPieces(out, kind, list, x, y, mem.u16(e + E_VRAM), mem.u8(e + E_PALETTE) & 0xF, flipX) end
end

-- Adds everything entity [e] draws (see the table above).
local function addEntity(out, e, kind, originX, originY)
  local mode = s8(mem.u8(e + E_PARTS))
  if mode == 0 then
    addMain(out, e, kind, originX, originY)
    return
  end
  local flipX = (mem.u8(e + E_FLAGS) ~ mem.u8(e + E_FRAME_FLAGS)) & 0x40 ~= 0
  local vram = mem.u16(e + E_VRAM)
  local x = mem.u16(e + E_X) - originX + s8(mem.u8(e + E_OFFX))
  local y = mem.u16(e + E_Y) + s16(mem.u16(e + E_Z)) - originY + s8(mem.u8(e + E_OFFY))
  if mode < 0 then
    local list = mem.u32(e + E_LIST)
    if inRam(list) or (list >= 0x08000000 and list < 0x0A000000) then
      addPieces(out, kind, list, x, y, vram, mem.u8(e + E_PALETTE) & 0xF, flipX)
    end
    return
  end
  local base = PARTS + mode * (PART_SIZE * PART_COUNT)
  if base + PART_SIZE * PART_COUNT > 0x02040000 then return end
  for i = 0, PART_COUNT - 1 do
    local part = base + i * PART_SIZE
    local flags = mem.u8(part)
    if flags & 1 == 0 then break end
    if flags & 2 ~= 0 then
      local other = mem.u32(part + 0xC)
      if inIwram(other) then addMain(out, other, kind, originX, originY) end
    else
      local list = frameList(mem.u16(part + 2), mem.u8(part + 1))
      if list then
        local flip = flipX ~= (mem.u8(part + 4) & 1 ~= 0)
        local off = s8(mem.u8(part + 6))
        addPieces(out, kind, list, flip and x - off or x + off, y + s8(mem.u8(part + 7)),
          vram + mem.u8(part + 8), mem.u8(part + 5) & 0xF, flip)
      end
    end
  end
end

local function markers(view, width, height, originX, originY, camX, camY)
  local out = {}
  for i = 1, ENTITY_COUNT - 1 do
    local e = ENTITIES + i * ENTITY_SIZE
    local kind = mem.u8(e + E_KIND)
    -- enemies, their projectiles, props (pots, signs, chests, ...) and NPCs; a prop the game is not drawing
    -- (SpriteSettings.draw, the low 2 bits of @0x18, is 0) is left out
    if kind == KIND_ENEMY or kind == KIND_NPC
        or ((kind == KIND_OBJECT or kind == KIND_PROJECTILE) and mem.u8(e + E_FLAGS) & 3 ~= 0) then
      local prev, nxt = mem.u32(e), mem.u32(e + 4)
      if (prev == 0 or inIwram(prev)) and (nxt == 0 or inIwram(nxt)) then
        local x = mem.u16(e + E_X) - originX
        local y = mem.u16(e + E_Y) + s16(mem.u16(e + E_Z)) - originY
        if x >= 0 and x < width and y >= 0 and y < height
            and x >= camX - view.width and x <= camX + view.width
            and y >= camY - view.height and y <= camY + view.height then
          addEntity(out, e, (kind == KIND_ENEMY or kind == KIND_PROJECTILE) and 2 or 1, originX, originY)
          if #out >= MAX_MARKERS then break end
        end
      end
    end
  end
  return out
end

-- The HUD (hearts, rupees, buttons, keys) is drawn by the game over its own picture, so it would sit in the middle
-- of the wide view. gHUD.hideFlags (include/ui.h, linker.ld: gHUD = 0x0200AF00, flags @+1) makes the game skip
-- drawing those; bit 5 (the spin attack charge bar) is left on. It is only written while the Wide view is showing
-- a room (wide() ran in the last few frames: that memory is something else on the title screen and menus), and
-- put back to 0 when the view stops showing (only if it still holds exactly the value written). Side effect: the game also disables the Select-for-Ezlo hint while it is set.
local HUD_HIDE_FLAGS = 0x0200AF01
local HUD_HIDDEN = 0xDF
local ticks, lastWide, hidden = 0, -100, false

function frame(view)
  ticks = ticks + 1
  if DEBUG and ticks % 60 == 0 and logged < 600 then
    logged = logged + 1
    local function r(a) return mem.u16(0x04000000 + a) end
    log(string.format("IO disp=%04X bld=%04X alpha=%04X y=%04X bg0=%04X/%d,%d bg1=%04X/%d,%d bg2=%04X/%d,%d bg3=%04X/%d,%d win=%04X,%04X out=%04X",
      r(0), r(0x50), r(0x52), r(0x54), r(8), r(0x10), r(0x12), r(0xA), r(0x14), r(0x16), r(0xC), r(0x18), r(0x1A), r(0xE), r(0x1C), r(0x1E), r(0x48), r(0x4A), r(0x4A)))
  end
  local wideOn = (view.left > 0 or view.top > 0) and ticks - lastWide <= 3
  if wideOn then
    if mem.u8(HUD_HIDE_FLAGS) ~= HUD_HIDDEN then mem.write8(HUD_HIDE_FLAGS, HUD_HIDDEN) end
    hidden = true
  elseif hidden then
    hidden = false
    if mem.u8(HUD_HIDE_FLAGS) == HUD_HIDDEN then mem.write8(HUD_HIDE_FLAGS, 0) end
  end
end

-- The cloud shadows of the overworld are BG3 alpha-blended over everything else (BLDCNT: mode 1, BG3 the first target;
-- BLDALPHA: its share and the ground's, in 16ths), a wrapping 256x256 map the game scrolls on its own. The frame has
-- them but the margins would not, so wide() hands them over as an overlay, read from the display registers.
local function clouds()
  local function io(a) return mem.u16(0x04000000 + a) end
  local disp, bld, cnt = io(0x00), io(0x50), io(0x0E)
  if disp & 0x0800 == 0 or bld & 0xC0 ~= 0x40 or bld & 0x08 == 0 then return nil end
  if cnt & 0x4080 ~= 0 or cnt >> 14 ~= 0 then return nil end          -- a 4bpp text map of 256x256 only
  local alpha = io(0x52)
  return {
    map = 0x06000000 + ((cnt >> 8) & 0x1F) * 0x800, tiles = 0x06000000 + ((cnt >> 2) & 3) * 0x4000,
    scrollX = io(0x1C) & 0x1FF, scrollY = io(0x1E) & 0x1FF,
    eva = math.min(alpha & 0x1F, 16), evb = math.min((alpha >> 8) & 0x1F, 16),
  }
end

function wide(view)
  local width = mem.u16(ROOM + R_WIDTH)
  local height = mem.u16(ROOM + R_HEIGHT)
  local bottom = layer(MAP_BOTTOM)
  local top = layer(MAP_TOP)
  if width < 16 or height < 16 or width > 1024 or height > 1024 or not bottom or not top then
    if DEBUG and not nilLogged and logged < 600 then
      nilLogged = true
      logged = logged + 1
      log(string.format("NIL room=%dx%d bottom=%s top=%s area=%d", width, height, tostring(bottom ~= nil), tostring(top ~= nil), mem.u8(0x03000BF4)))
    end
    return nil
  end
  bottom.gridW, bottom.gridH = width // 16, height // 16
  top.gridW, top.gridH = bottom.gridW, bottom.gridH

  local lx, ly = lag(MAP_BOTTOM)
  local x = s16(mem.u16(ROOM + R_SCROLL_X)) - mem.u16(ROOM + R_ORIGIN_X) + lx
  local y = s16(mem.u16(ROOM + R_SCROLL_Y)) - mem.u16(ROOM + R_ORIGIN_Y) + ly
  if DEBUG and bucketChanged(view) and logged < 600 then
    logged = logged + 1
    log(string.format("LOW match=%.3f x=%d y=%d lag=%d,%d room=%dx%d", view.match, x, y, lx, ly, width, height))
  end
  nilLogged = false
  local ok, list = pcall(markers, view, width, height, mem.u16(ROOM + R_ORIGIN_X), mem.u16(ROOM + R_ORIGIN_Y), x, y)
  lastWide = ticks
  return { x = x, y = y, palette = 0x05000000, layers = { bottom, top }, markers = ok and list or nil, overlay = clouds() }
end

-- The look of the game while Ambient is on (ambient.lua).
ambient = pack.require("ambient").ambient
