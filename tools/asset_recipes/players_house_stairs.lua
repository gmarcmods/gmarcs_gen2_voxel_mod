-- Flights travel toward the top/north edge. Use the original
-- renderer's stepped flights and excavated stairwells, not flat assets.
return {tilesets={TILESET_PLAYERS_HOUSE={pins={
 stair_n={76,77,92,93}, -- upstairs: four treads rising north, 16px total
 stair_down_n={78,79,94,95}, -- downstairs: cut the floor and descend north
}}}}
