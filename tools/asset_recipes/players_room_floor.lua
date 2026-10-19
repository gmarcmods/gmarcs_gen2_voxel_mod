-- The wall desk is shifted north of its original sprite footprint. Once
-- that footprint is exposed, neighbor voting must not paint desk tile 49
-- beneath the radio. Use the room's original striped floor, tile 1.
local ground={}
for _,tile in ipairs({11,12,27,28,43,44,66,67,82,83,48,49,50}) do ground[tile]=1 end
return {tilesets={TILESET_PLAYERS_ROOM={prop_ground=ground}}}
