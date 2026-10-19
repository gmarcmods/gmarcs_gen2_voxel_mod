-- These native blocks draw one-way jump rims, reusing real cliff texels.
-- Match their full 32px block so vertical/diagonal endcaps stay equally low.
local function edges(ice)
 local tiles=ice and {17,19,33,34,35}or{21,23,37,38,39}
 local first=ice and 36 or 56
 return {tiles=tiles,ledgeTiles=tiles,capTiles=tiles,ledgeBlocks={first,first+1,first+2,first+3,first+4},
  lipHeight=2,shoreHeight=2,shoreClass='ledge',topTile=ice and 25 or 1}
end
return {tilesets={TILESET_CAVE={terrain_edges=edges(false)},
 TILESET_DARK_CAVE={terrain_edges=edges(false)},TILESET_ICE_PATH={terrain_edges=edges(true)}}}
