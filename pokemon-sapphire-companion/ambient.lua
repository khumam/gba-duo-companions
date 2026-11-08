-- Sapphire (AXPE 1.0): the look of the game while Ambient is on, loaded by game.lua. The app has the effects (colour
-- grade, sprite shadows, sunlit edges, bloom, drifting clouds); these are the numbers. Every field is optional and its
-- default changes nothing, so a field left out is an effect left off. Asked again four times a second, so the look can
-- follow the place: clouds only under an open sky, a warmer, closer light indoors.
-- Contract: docs-packs/game-script.md in the app repo.

local MAP_HEADER = 0x0202E828       -- gMapHeader
local MAP_TYPE = 0x17               -- its mapType (u8)

-- Sapphire's map types
local TOWN, CITY, ROUTE, UNDERGROUND, OCEAN_ROUTE, INDOOR, SECRET_BASE = 1, 2, 3, 4, 6, 8, 9

-- The game's own colours, a touch fuller; a gentle neutral vignette (no colour cast).
local GRADE = {
  saturation = 1.08, contrast = 1.04,
  tint = { 1.02, 1.0, 0.98 },
  vignette = 0.25, vignetteColor = { 0.55, 0.56, 0.62 },
}

-- Under an open sky: a low sun at the top left, soft sprite shadows, warm edges, slow clouds.
local OUTDOORS = {
  saturation = GRADE.saturation, contrast = GRADE.contrast, tint = GRADE.tint,
  vignette = GRADE.vignette, vignetteColor = GRADE.vignetteColor,
  sunSlope = 0.06,
  shadow = 0.55, shadowLength = 8, shadowColor = { 0.62, 0.66, 0.78 },
  rim = 0.35, rimColor = { 1.0, 0.92, 0.78 },
  crease = 0.4, bloom = 0.25,
  clouds = 0.35, cloudSize = 180, cloudSpeed = 1,
}

-- Inside (houses, the Center, caves): no sky, so no clouds and no slope; shorter, closer shadows, a warmer room.
local INSIDE = {
  saturation = GRADE.saturation, contrast = GRADE.contrast,
  tint = { 1.03, 1.0, 0.95 },
  vignette = 0.35, vignetteColor = GRADE.vignetteColor,
  shadow = 0.45, shadowLength = 5, shadowColor = { 0.66, 0.64, 0.70 },
  rim = 0.15, rimColor = { 1.0, 0.9, 0.75 },
  crease = 0.45, bloom = 0.2,
}

local function ambient()
  local kind = mem.u8(MAP_HEADER + MAP_TYPE)
  if kind == TOWN or kind == CITY or kind == ROUTE or kind == OCEAN_ROUTE then return OUTDOORS end
  if kind == INDOOR or kind == UNDERGROUND or kind == SECRET_BASE then return INSIDE end
  return GRADE                      -- anywhere else: the grade only
end

return { ambient = ambient }
