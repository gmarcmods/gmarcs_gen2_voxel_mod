-- Alph's five chambers: upright inscription bands and freestanding statues.
local function s(r,o,h,d,z) return {rect=r,orientation=o,height=h,depth=d,z=z or 0} end
local assets={};local function add(a) assets[#assets+1]=a;return a end
local function put(a,x,y,z,i) a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=i,region=1} end
local statue=add({id='ruins_statue',tiles={{14,15},{30,31},{46,47},{62,63}},surfaces={
 s({2,16,12,16},'vertical',0,12,2)},voxelEdits={}})
-- Broad carved plinth supports a rounded head and separated upper corners.
for x=0,15 do for z=0,15 do for y=16,32 do
 local q=((x-7.5)/7.5)^2+((z-7.5)/6)^2+((y-24)/9)^2
 if q<=1 then put(statue,x,y,z,math.max(0,31-y)*16+x) end
end end end
for _,x0 in ipairs({2,11}) do for x=x0,x0+2 do for z=5,9 do for y=29,34 do put(statue,x,y,z,2*16+x) end end end end
for x=0,15 do for z=0,15 do for y=0,2 do put(statue,x,y,z,30*16+x) end end end
-- Each authored panel retains its actual Unown pair; no generic substitute.
local pairsList={{20,34},{23,49},{29,48},{32,57},{33,64},{34,55},{35,29},{35,56},{50,22},{50,33},{54,22},{54,28},{55,27},{56,51},{57,26},{65,26},{66,20},{67,32}}
for _,p in ipairs(pairsList) do add({id='ruins_inscription_'..p[1]..'_'..p[2],tiles={{6,6},{p[1],p[2]}},surfaces={s({0,0,16,16},'vertical',0,8)}}) end
add({id='ruins_puzzle_altar',tiles={{6,6,6,6},{71,72,73,74}},surfaces={s({0,0,32,16},'vertical',0,8,4)}})
local ground={[14]=2,[15]=3,[30]=3,[31]=2,[46]=2,[47]=3,[62]=3,[63]=2}
local repair=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/service_prop_repairs.lua')
for _,a in ipairs(assets)do repair(a)end
local audited=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/statue_repairs.lua')
for _,a in ipairs(assets)do audited.repair(a)end
return {tilesets={TILESET_RUINS_OF_ALPH={assets=assets,prop_ground=ground,planter_spray=false,
 classes={ruins_wall={base='wall',height=16,art='flat'}},pins={
 ground={2,3,12,13,16,17}, -- chamber paving and puzzle floor markings stay flat
 ruins_wall={6,8,9,10,11}, -- continuous chamber caps and dividing walls
 stair_w={38,39,40,41}, -- ladder at the west side of its landing rises toward west
 void={0,1}, -- outside chamber and open puzzle drop shafts
 }}}}
