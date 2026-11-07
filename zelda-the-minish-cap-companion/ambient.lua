-- The Minish Cap: the look of the game while Ambient is on, loaded by game.lua. The app has the effects (colour
-- grade, sprite shadows, sunlit edges, bloom, drifting clouds); these are the numbers. Every field is optional and its
-- default changes nothing, so a field left out is an effect left off. Asked again four times a second, so the look can
-- follow the place: clouds only under an open sky, a warmer, closer light indoors.
-- Contract: docs-packs/game-script.md in the app repo.

local AREA_FLAGS = 0x02033A90       -- gArea.areaMetadata (u8); bit 0 = AR_IS_OVERWORLD (area.h)

-- The game is already bright and saturated, so the grade is light; a soft neutral vignette (no colour cast).
local GRADE = {
  sunX = 0,
  saturation = 1.06, contrast = 1.05,
  tint = { 1.02, 1.0, 0.97 },
  vignette = 0.22, vignetteColor = { 0.55, 0.58, 0.62 },
}

-- An overworld area (Hyrule Town, the Field, Minish Woods...): the sun straight above, soft shadows, warm edges, clouds.
local OUTDOORS = {
  saturation = GRADE.saturation, contrast = GRADE.contrast, tint = GRADE.tint,
  vignette = GRADE.vignette, vignetteColor = GRADE.vignetteColor,
  sunX = 0, sunSlope = 0.06,   -- the sun straight above: the top down view's light, shadows fall straight down
  shadow = 0.5, shadowLength = 8, shadowColor = { 0.62, 0.68, 0.8 },
  rim = 0.3, rimColor = { 1.0, 0.93, 0.78 },
  crease = 0.4, bloom = 0.22,
  clouds = 0.3, cloudSize = 200, cloudSpeed = 1,
}

-- Houses, caves and dungeons: no sky, so no clouds and no slope; shorter, closer shadows, a warmer room.
local INSIDE = {
  saturation = GRADE.saturation, contrast = GRADE.contrast,
  tint = { 1.03, 1.0, 0.94 }, sunX = 0,
  vignette = 0.32, vignetteColor = GRADE.vignetteColor,
  shadow = 0.42, shadowLength = 5, shadowColor = { 0.66, 0.65, 0.74 },
  rim = 0.14, rimColor = { 1.0, 0.9, 0.75 },
  crease = 0.45, bloom = 0.18,
}

local function ambient()
  if mem.u8(AREA_FLAGS) & 1 == 1 then return OUTDOORS end
  return INSIDE
end

return { ambient = ambient }
