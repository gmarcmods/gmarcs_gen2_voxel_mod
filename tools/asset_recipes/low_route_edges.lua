-- Collision-aware jump faces and low banks. Interior rock courses retain
-- their original height field, assets and collision behavior.
local batch={tilesets={}}
for _,v in ipairs({{'TILESET_JOHTO','johto_shore',76},{'TILESET_JOHTO_MODERN','modern_shore',76},{'TILESET_KANTO','kanto_shore',55}})do
 local kanto=v[1]=='TILESET_KANTO'
 batch.tilesets[v[1]]={classes={[v[2]]={base='ledge',height=1,art='top'}},
  terrain_edges={tiles=kanto and {1,2,4,17,18,19,30,36,39,51,52,53,54,55,84} or {43,44,45,59,60,61,75,76,77,92,93},
   ledgeTiles=kanto and {1,2,4,17,18,19,30,36,39,52,53,54,55} or {59,61,75,76,77},
   capTiles=kanto and {1,2,17,19,30,36,39,52,53,54} or {59,61,75,77},
   lipHeight=2,shoreHeight=1,topTile=v[3],shoreClass=v[2]}}
end
return batch
