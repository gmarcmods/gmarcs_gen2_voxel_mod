-- A raised table claims its entire original sprite, including painted feet.
-- These atlases use floor tile 1; never let another furniture sprite win the
-- neighbour vote beneath a claimed table/desk. Geometry is left untouched.
local house,players={},{}
for _,t in ipairs({5,21,34,35,37,38,39,41,47,50,51,53,54,57,58,59,60,70,71,82,83,86,87})do house[t]=1 end
for _,t in ipairs({12,13,17,21,28,29,32,33,34,35,36,37,48,49,50,51,52,53,64})do players[t]=1 end
return {tilesets={TILESET_HOUSE={prop_ground=house},TILESET_PLAYERS_HOUSE={prop_ground=players}}}
