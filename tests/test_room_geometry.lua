local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/tests/')
local R=assert(loadfile(root..'/lib/RoomGeometry.lua'))()
local wall={class='facility_wall',h=16}
assert(R.at({id='SILPH_CO_1F'},wall,65).h==8,'Silph reception counter hides receptionist')
assert(R.at({id='SILPH_CO_1F'},wall,34)==wall,'actual room wall changed')
assert(R.at({id='POWER_PLANT'},wall,65)==wall,'shared tiles changed another building')
print('Silph reception counter is low; walls and other facility rooms unchanged PASS')
local map={id='ROUTE_6',widthCells=2,heightCells=2,tileAt=function(_,x,y)return y==1 and(x==1 and 4 or 55)or 44 end}
assert(R.at(map,{class='ledge',h=2},55).h==4,'Route 6 jump border is indistinguishable from floor')
local S={skip={},ground={},objectQuads={}}
R.build(S,map,function(x,y)return y*8+x end)
assert(S.skip[9]and #S.objectQuads>=8,'walkable ledge gap has no visible 3D treads')
local heights={};for _,q in ipairs(S.objectQuads)do for _,p in ipairs(q)do heights[p[2]]=true end end
assert(heights[1]and heights[4],'Route 6 staircase does not bridge its low kerb')
print('Route 6 access gaps have distinct four-pixel treads aligned with low jump borders PASS')
local pit=R.at({id='KARENS_ROOM',tileset={id='TILESET_ELITE_FOUR_ROOM'}},{class='elite_void',base='void',h=-16,art='flat'},0)
assert(pit.h==-32 and pit.base~='void','Elite Four pit has no full cliff depth or duplicates the indoor skirt')
print('Elite Four voids have continuous deep cliff sides rather than thin floor edges PASS')
