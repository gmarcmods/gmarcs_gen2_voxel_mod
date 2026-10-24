local root=arg[1]or'mods/gen2/new_mod_ex'
local C=assert(loadfile(root..'/lib/CoastalPlatforms.lua'))()
local shape={class='johto_cliff',base='wall',h=18,art='flat',topTile=54}
local shapes={mountain={classes={'johto_cliff','johto_plateau'}}}
local function map(id,land)
 return {id=id,def={width=4,height=4},widthCells=8,heightCells=8,
  isWalkableCell=function(_,x,y)return land[x..':'..y]or false end,
  isWaterCell=function(_,x,y)return not land[x..':'..y]end,
  inBounds=function(_,x,y)return x>=0 and y>=0 and x<8 and y<8 end}
end
local land={};for y=2,4 do for x=2,4 do land[x..':'..y]=true end end
local m=map('CHERRYGROVE_CITY',land)
local out=C.at(m,shapes,shape,54,4,4)
assert(out.h==0 and out.base=='ground','walkable island must be a low flat rock surface')
assert(shape.h==18,'shared authored cliff definition mutated')
assert(C.at(map('ROUTE_41',land),shapes,shape,54,4,4)==shape,'unreviewed maps must stay unchanged')
local mainland={};for y=0,7 do for x=0,7 do mainland[x..':'..y]=true end end
assert(C.at(map('CHERRYGROVE_CITY',mainland),shapes,shape,54,4,4)==shape,'mainland cliffs must stay unchanged')
local water={class='water',h=-2}
assert(C.at(m,shapes,water,20,4,4)==water,'water changed')
assert(C.at(m,shapes,shape,54,0,0)==shape,'water cell cliff banks must keep shoreline handling')
local blockedRim=map('CHERRYGROVE_CITY',land)
blockedRim.isWalkableCell=function(_,x,y)return x==3 and y==3 end
assert(C.at(blockedRim,shapes,shape,54,4,4).h==0,'blocked rock rim must not turn a walkable island back into a mountain')
local outcrop=map('CHERRYGROVE_CITY',land)
outcrop.isWalkableCell=function()return false end
assert(C.at(outcrop,shapes,shape,54,4,4)==shape,'unwalkable sea rocks must remain rocks')
print('COASTAL PLATFORMS PASS')
