-- Golden Sun: the look of the game while Ambient is on, loaded by game.lua. The app has the effects (colour grade,
-- sprite shadows, sunlit edges, bloom, drifting clouds); these are the numbers. Every field is optional and its default
-- changes nothing, so a field left out is an effect left off. Asked again four times a second, so the look can follow
-- the place: clouds only on the world's open ground.
-- Contract: docs-packs/game-script.md in the app repo.

local REG_DISPCNT = 0x04000000
local REG_BGCNT = 0x04000008    -- BGnCNT, 2 bytes per BG
local SHADOW = 0x03001AD0       -- the BG scroll the game shows next, 4 bytes per BG (the same block game.lua reads)

-- Golden Sun is soft and slightly muted: a touch more colour and punch, a gentle vignette (no colour cast).
local GRADE = {
  sunX = 0,
  saturation = 1.1, contrast = 1.06,
  tint = { 1.02, 1.0, 0.97 },
  vignette = 0.25, vignetteColor = { 0.55, 0.57, 0.63 },
}

-- Out in the world (towns, fields, dungeons' open floors): the sun straight above, soft shadows, warm edges, clouds.
local OUTDOORS = {
  saturation = GRADE.saturation, contrast = GRADE.contrast, tint = GRADE.tint,
  vignette = GRADE.vignette, vignetteColor = GRADE.vignetteColor,
  sunX = 0, sunSlope = 0.06,   -- the sun straight above: the top down view's light, shadows fall straight down
  shadow = 0.5, shadowLength = 8, shadowColor = { 0.62, 0.66, 0.8 },
  rim = 0.3, rimColor = { 1.0, 0.92, 0.78 },
  crease = 0.4, bloom = 0.25,
  clouds = 0.3, cloudSize = 220, cloudSpeed = 1,
}

-- Indoors and in cut scenes: no sky, so no clouds and no slope; shorter, closer shadows, a warmer room.
local INSIDE = {
  saturation = GRADE.saturation, contrast = GRADE.contrast,
  tint = { 1.03, 1.0, 0.95 }, sunX = 0,
  vignette = 0.32, vignetteColor = GRADE.vignetteColor,
  shadow = 0.42, shadowLength = 5, shadowColor = { 0.66, 0.64, 0.72 },
  rim = 0.14, rimColor = { 1.0, 0.9, 0.75 },
  crease = 0.42, bloom = 0.2,
}

-- The world is the game's three-layer map (BG1..BG3 side by side in one grid, see game.lua); houses and battles are not.
local function inWorld()
  local dispcnt = mem.u16(REG_DISPCNT)
  if dispcnt & 7 ~= 0 or dispcnt & 0x0E00 ~= 0x0E00 then return false end
  local hx2, hx3 = mem.u16(SHADOW + 2 * 4), mem.u16(SHADOW + 3 * 4)
  local hx1 = mem.u16(SHADOW + 1 * 4)
  local width = hx2 - hx3
  return width >= 16 and width % 16 == 0 and width <= 16 * 128 // 3 and hx1 - hx2 == width
end

local function ambient()
  local ok, world = pcall(inWorld)
  if ok and world then return OUTDOORS end
  if mem.u16(REG_DISPCNT) & 7 == 0 then return INSIDE end
  return GRADE                      -- battles and the like: the grade only
end

return { ambient = ambient }
