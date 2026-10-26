# FireRed outdoor map sizes

From pret/pokefirered `data/maps/*/map.json` + `data/layouts/layouts.json`
(the `gMapGroup_TownsAndRoutes` group). One tile = 16x16 px in game.

`main.lua` reports the player's tile on the *current* map (0,0 = top-left tile,
after subtracting the 7-tile border), so art for a map should cover exactly
`width x height` tiles. Suggested art size = 4 px per tile (crisp at the radar's
~577x619 device px when scaled by a whole number for the smaller maps); the
"16 px/tile" column is the game's own resolution.

`Town Map cell` is the map's spot on the in-game Town Map (`region_map_sections.json`,
8x8 px cells; Kanto fits a 22x15 cell grid, the Sevii Islands use their own grids).

| Map | Map section | Tiles (w x h) | Art @4px/tile | Game px @16px/tile | Town Map cell (x,y,w,h) |
|---|---|---|---|---|---|
| PalletTown | PALLET TOWN | 24 x 20 | 96 x 80 | 384 x 320 | 4,11,1,1 |
| ViridianCity | VIRIDIAN CITY | 48 x 40 | 192 x 160 | 768 x 640 | 4,8,1,1 |
| PewterCity | PEWTER CITY | 48 x 40 | 192 x 160 | 768 x 640 | 4,4,1,1 |
| CeruleanCity | CERULEAN CITY | 48 x 40 | 192 x 160 | 768 x 640 | 14,3,1,1 |
| LavenderTown | LAVENDER TOWN | 24 x 20 | 96 x 80 | 384 x 320 | 18,6,1,1 |
| VermilionCity | VERMILION CITY | 48 x 40 | 192 x 160 | 768 x 640 | 14,9,1,1 |
| CeladonCity | CELADON CITY | 60 x 40 | 240 x 160 | 960 x 640 | 11,6,1,1 |
| FuchsiaCity | FUCHSIA CITY | 48 x 40 | 192 x 160 | 768 x 640 | 12,12,1,1 |
| CinnabarIsland | CINNABAR ISLAND | 24 x 20 | 96 x 80 | 384 x 320 | 4,14,1,1 |
| IndigoPlateau_Exterior | INDIGO PLATEAU | 24 x 20 | 96 x 80 | 384 x 320 | 2,3,1,1 |
| SaffronCity | SAFFRON CITY | 66 x 55 | 264 x 220 | 1056 x 880 | 14,6,1,1 |
| SaffronCity_Connection | SAFFRON CITY | 48 x 40 | 192 x 160 | 768 x 640 | 14,6,1,1 |
| OneIsland | ONE ISLAND | 24 x 20 | 96 x 80 | 384 x 320 | 1,8,1,1 |
| TwoIsland | TWO ISLAND | 48 x 20 | 192 x 80 | 768 x 320 | 9,9,1,1 |
| ThreeIsland | THREE ISLAND | 24 x 40 | 96 x 160 | 384 x 640 | 18,12,1,1 |
| FourIsland | FOUR ISLAND | 48 x 40 | 192 x 160 | 768 x 640 | 3,4,1,1 |
| FiveIsland | FIVE ISLAND | 24 x 20 | 96 x 80 | 384 x 320 | 16,11,1,1 |
| SevenIsland | SEVEN ISLAND | 24 x 20 | 96 x 80 | 384 x 320 | 5,8,1,1 |
| SixIsland | SIX ISLAND | 24 x 30 | 96 x 120 | 384 x 480 | 17,5,1,1 |
| Route1 | ROUTE 1 | 24 x 40 | 96 x 160 | 384 x 640 | 4,9,1,2 |
| Route2 | ROUTE 2 | 24 x 80 | 96 x 320 | 384 x 1280 | 4,5,1,3 |
| Route3 | ROUTE 3 | 84 x 20 | 336 x 80 | 1344 x 320 | 5,4,4,1 |
| Route4 | ROUTE 4 | 108 x 20 | 432 x 80 | 1728 x 320 | 8,3,6,1 |
| Route5 | ROUTE 5 | 48 x 40 | 192 x 160 | 768 x 640 | 14,4,1,2 |
| Route6 | ROUTE 6 | 24 x 40 | 96 x 160 | 384 x 640 | 14,7,1,2 |
| Route7 | ROUTE 7 | 24 x 20 | 96 x 80 | 384 x 320 | 12,6,2,1 |
| Route8 | ROUTE 8 | 72 x 20 | 288 x 80 | 1152 x 320 | 15,6,3,1 |
| Route9 | ROUTE 9 | 72 x 20 | 288 x 80 | 1152 x 320 | 15,3,3,1 |
| Route10 | ROUTE 10 | 24 x 80 | 96 x 320 | 384 x 1280 | 18,3,1,3 |
| Route11 | ROUTE 11 | 72 x 20 | 288 x 80 | 1152 x 320 | 15,9,3,1 |
| Route12 | ROUTE 12 | 24 x 120 | 96 x 480 | 384 x 1920 | 18,7,1,5 |
| Route13 | ROUTE 13 | 72 x 20 | 288 x 80 | 1152 x 320 | 16,11,2,1 |
| Route14 | ROUTE 14 | 24 x 60 | 96 x 240 | 384 x 960 | 15,11,1,2 |
| Route15 | ROUTE 15 | 72 x 20 | 288 x 80 | 1152 x 320 | 13,12,2,1 |
| Route16 | ROUTE 16 | 48 x 20 | 192 x 80 | 768 x 320 | 7,6,4,1 |
| Route17 | ROUTE 17 | 24 x 160 | 96 x 640 | 384 x 2560 | 7,7,1,5 |
| Route18 | ROUTE 18 | 60 x 20 | 240 x 80 | 960 x 320 | 7,12,5,1 |
| Route19 | ROUTE 19 | 24 x 60 | 96 x 240 | 384 x 960 | 12,13,1,2 |
| Route20 | ROUTE 20 | 120 x 20 | 480 x 80 | 1920 x 320 | 5,14,7,1 |
| Route21_North | ROUTE 21 | 24 x 50 | 96 x 200 | 384 x 800 | 4,12,1,2 |
| Route21_South | ROUTE 21 | 24 x 50 | 96 x 200 | 384 x 800 | 4,12,1,2 |
| Route22 | ROUTE 22 | 48 x 24 | 192 x 96 | 768 x 384 | 2,8,2,1 |
| Route23 | ROUTE 23 | 24 x 160 | 96 x 640 | 384 x 2560 | 2,4,1,4 |
| Route24 | ROUTE 24 | 24 x 40 | 96 x 160 | 384 x 640 | 14,1,1,2 |
| Route25 | ROUTE 25 | 72 x 20 | 288 x 80 | 1152 x 320 | 15,1,2,1 |
| OneIsland_KindleRoad | KINDLE ROAD | 24 x 140 | 96 x 560 | 384 x 2240 | 2,3,1,6 |
| OneIsland_TreasureBeach | TREASURE BEACH | 24 x 40 | 96 x 160 | 384 x 640 | 1,9,1,2 |
| TwoIsland_CapeBrink | CAPE BRINK | 24 x 40 | 96 x 160 | 384 x 640 | 9,7,1,2 |
| ThreeIsland_BondBridge | BOND BRIDGE | 96 x 20 | 384 x 80 | 1536 x 320 | 13,12,4,1 |
| ThreeIsland_Port | THREE ISLE PORT | 48 x 20 | 192 x 80 | 768 x 320 | 18,13,2,1 |
| FiveIsland_ResortGorgeous | RESORT GORGEOUS | 72 x 20 | 288 x 80 | 1152 x 320 | 16,9,3,1 |
| FiveIsland_WaterLabyrinth | WATER LABYRINTH | 72 x 20 | 288 x 80 | 1152 x 320 | 14,10,3,1 |
| FiveIsland_Meadow | FIVE ISLE MEADOW | 24 x 40 | 96 x 160 | 384 x 640 | 17,10,1,3 |
| FiveIsland_MemorialPillar | MEMORIAL PILLAR | 24 x 60 | 96 x 240 | 384 x 960 | 18,12,1,3 |
| SixIsland_OutcastIsland | OUTCAST ISLAND | 24 x 80 | 96 x 320 | 384 x 1280 | 15,0,1,3 |
| SixIsland_GreenPath | GREEN PATH | 72 x 20 | 288 x 80 | 1152 x 320 | 15,3,3,1 |
| SixIsland_WaterPath | WATER PATH | 24 x 100 | 96 x 400 | 384 x 1600 | 18,3,1,5 |
| SixIsland_RuinValley | RUIN VALLEY | 48 x 40 | 192 x 160 | 768 x 640 | 16,7,2,2 |
| SevenIsland_TrainerTower | TRAINER TOWER | 120 x 40 | 480 x 160 | 1920 x 640 | 5,6,1,2 |
| SevenIsland_SevaultCanyon_Entrance | CANYON ENTRANCE | 24 x 40 | 96 x 160 | 384 x 640 | 5,9,1,1 |
| SevenIsland_SevaultCanyon | SEVAULT CANYON | 24 x 80 | 96 x 320 | 384 x 1280 | 6,9,1,3 |
| SevenIsland_TanobyRuins | TANOBY RUINS | 144 x 20 | 576 x 80 | 2304 x 320 | 3,12,7,1 |
