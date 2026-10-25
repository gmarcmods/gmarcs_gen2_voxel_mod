local root=arg[1]or'mods/gen2/new_mod_ex'
local M=assert(loadfile(root..'/lib/RockMaterial.lua'))()
local function check(bottom,top)
 local bands=M.bands(bottom,top);local nextY=top;local rim=0
 for _,b in ipairs(bands)do
  assert(b.y1==nextY and b.y0<b.y1,'face must cover continuous descending intervals')
  assert(b.v1-b.v0==b.y1-b.y0,'source texels must retain native pixel scale')
  assert(b.v0>=0 and b.v1<=8)
  if b.tile==76 then rim=rim+1;assert(b.y1==top,'stone rim belongs only at upper edge')
  else assert(b.tile==54 and b.v0>=2,'body must exclude repeated rim/shadow')end
  nextY=b.y0
 end
 assert(nextY==bottom and rim==1,'face gap or repeated stone rim')
end
for _,p in ipairs({{0,48},{0,16},{14,16},{-2,0},{7,9}})do check(unpack(p))end
local s={class='johto_cliff',h=16,art='flat'}
local o=M.shape({tileset={id='TILESET_JOHTO'}},s)
assert(o~=s and o.topTile==60 and o.rockMaterial and not s.topTile,'cap must use ground without mutating shared shape')
assert(M.shape({tileset={id='TILESET_CAVE'}},s)==s,'unreviewed tileset changed')
assert(M.shape({tileset={id='TILESET_JOHTO'}},{class='desk'}) .rockMaterial==nil,'furniture changed')
print('ROCK MATERIAL PASS')
