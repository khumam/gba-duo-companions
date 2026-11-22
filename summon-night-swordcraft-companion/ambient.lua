-- Summon Night: Swordcraft Story (AB4E): the look of the game while COLOR is on, loaded by game.lua.
-- The app has the effects; these are the numbers. Asked four times a second, so the look follows the place:
-- the town under an open sky, the warm inside of the guild, workshop and tower, the cold Labyrinth, and battles.
-- Contract: docs-packs/game-script.md in the app repo.

local MAP_AREA = 0x02002316          -- u8: 01 town, 04/05 guild (05 0C workshop), 06/07 tower, 0E Labyrinth
local BATTLE = 0x03000718            -- first battle actor record (see main.lua actorOk); 0x0300002C = 1 in battle

-- The game's parchment-and-wood palette, a touch fuller, with a soft neutral vignette.
local GRADE = { saturation = 1.08, contrast = 1.04, tint = { 1.02, 1.0, 0.98 },
                vignette = 0.22, vignetteColor = { 0.55, 0.55, 0.6 } }

-- Town: a late-morning sun from the top left, soft shadows, warm edges and slow clouds.
local TOWN = {
  saturation = 1.1, contrast = 1.04, tint = { 1.03, 1.0, 0.96 },
  vignette = 0.2, vignetteColor = { 0.6, 0.6, 0.66 },
  sunSlope = 0.06, sunX = -1,
  shadow = 0.5, shadowLength = 8, shadowColor = { 0.62, 0.64, 0.76 },
  rim = 0.3, rimColor = { 1.0, 0.92, 0.78 },
  crease = 0.35, bloom = 0.2,
  clouds = 0.3, cloudSize = 200, cloudSpeed = 1,
}

-- Guild, workshop and tower rooms: lamplight, close shadows, no sky.
local INSIDE = {
  saturation = 1.06, contrast = 1.04, tint = { 1.05, 1.0, 0.92 },
  vignette = 0.32, vignetteColor = { 0.6, 0.5, 0.42 },
  shadow = 0.42, shadowLength = 5, shadowColor = { 0.7, 0.62, 0.6 },
  rim = 0.15, rimColor = { 1.0, 0.86, 0.66 },
  crease = 0.45, bloom = 0.25,
}

-- The Labyrinth: cool stone, deeper corners, crystals that glow.
local LABYRINTH = {
  saturation = 1.04, contrast = 1.08, brightness = 0.97, tint = { 0.96, 0.99, 1.05 },
  vignette = 0.4, vignetteColor = { 0.35, 0.36, 0.5 },
  shadow = 0.45, shadowLength = 6, shadowColor = { 0.55, 0.58, 0.75 },
  rim = 0.12, rimColor = { 0.85, 0.9, 1.0 },
  crease = 0.5, bloom = 0.4, haze = 0.15,
}

-- Battles: the same place, a little punchier, no clouds over the arena.
local BATTLE_LOOK = {
  saturation = 1.12, contrast = 1.08, tint = { 1.0, 0.99, 1.02 },
  vignette = 0.3, vignetteColor = { 0.4, 0.38, 0.5 },
  shadow = 0.4, shadowLength = 6, shadowColor = { 0.55, 0.55, 0.7 },
  rim = 0.25, rimColor = { 1.0, 0.95, 0.85 },
  bloom = 0.3,
}

local function ambient()
  -- battle mode flag (1) plus a sane first actor record (see main.lua actorOk)
  if mem.u8(0x0300002C) == 1 and mem.u8(BATTLE + 3) == 0 and mem.u32(BATTLE + 0x14) > 0 and mem.u32(BATTLE + 0x14) <= 9999 then return BATTLE_LOOK end
  local area = mem.u8(MAP_AREA)
  if area == 0x01 then return TOWN end
  if area == 0x0E then return LABYRINTH end
  if area >= 0x02 and area <= 0x0D then return INSIDE end
  return GRADE
end

return { ambient = ambient }
