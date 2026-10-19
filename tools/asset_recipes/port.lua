-- Olivine/Vermilion harbors and Cerulean Gym share this tileset.
local shipTiles={
 {20,20,20,20,20,20,26,35,20,20,20,20,20,20,20,20},
 {20,20,20,20,20,20,36,37,38,39,40,41,42,20,20,20},
 {43,44,45,45,46,47,48,50,51,52,53,16,54,55,56,20},
 {57,58,58,51,59,60,61,62,63,64,65,66,67,68,69,20},
 {43,44,45,51,70,71,72,73,73,74,75,76,77,78,79,20},
 {57,58,80,81,82,82,83,83,84,44,45,85,86,87,20,20},
 {20,88,89,90,90,91,92,92,93,94,94,94,95,20,20,20},
 {20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20},
}
local function s(r,o,h,d,z) return {rect=r,orientation=o,height=h,depth=d,z=z or 0} end
local assets={};local function add(a) assets[#assets+1]=a;return a end
local function blank(id,tiles) return add({id=id,tiles=tiles,surfaces={s({0,0,1,1},'vertical',0,1)},voxelEdits={{x=0,y=0,z=0,remove=true}}}) end
local function put(a,x,y,z,i) a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=i,region=1} end
local ship=blank('port_ship',shipTiles)
-- Long curved hull follows the actual east-west ship footprint. Its lower
-- shell penetrates the sea; a pale deck supports the cabin and tall funnel.
for x=1,118 do for z=17,52 do
 local q=((x-60)/60)^4+((z-34.5)/18)^4
 if q<=1 then
  for y=-4,9 do
   local inset=(9-y)*.07
   if q<1-inset*.15 and (y==-4 or y==9 or q> .75-inset*.15) then
    local sy=y==9 and math.max(17,math.min(46,z)) or math.max(48,math.min(55,55-y))
    local sx=math.max(8,math.min(109,x));put(ship,x,y,z,sy*128+sx)
   end
  end
 end
end end
-- Cabin has an inset bridge above the main deck. Its source window band
-- is upright, while the light upper panels form a flat roof.
for x=46,92 do for z=22,45 do for y=10,23 do
 if x==46 or x==92 or z==22 or z==45 or y==23 then
  local sy=y==23 and 22 or math.max(23,math.min(43,45-(y-10)))
  put(ship,x,y,z,sy*128+math.max(48,math.min(90,x)))
 end
end end end
-- Funnel/mast uses the tall blue-white source drawing at the ship's north.
for x=51,58 do for z=30,35 do for y=24,43 do
 put(ship,x,y,z,math.max(0,19-(y-24))*128+x)
end end end
-- Low deck rails run along the hull with open gaps between stanchions.
for x=12,108 do for _,z in ipairs({18,50}) do for y=10,12 do
 if y==12 or x%12<2 then put(ship,x,y,z,32*128+30) end
end end end
local bollard=blank('port_bollard',{{1,2},{17,18}});bollard.border=true
for x=0,15 do for z=0,15 do local q=((x-7.5)/6.5)^2+((z-7.5)/6.5)^2
 if q<=1 then for y=-3,10 do put(bollard,x,y,z,math.max(1,math.min(14,14-y))*16+x) end end
end end
local statue=add({id='port_gym_statue',tiles={{6,7},{22,23},{8,9},{24,25}},surfaces={s({2,16,12,16},'vertical',0,12,2)},voxelEdits={}})
for x=0,15 do for z=0,15 do for y=16,32 do
 if ((x-7.5)/7)^2+((z-7.5)/6)^2+((y-24)/9)^2<=1 then put(statue,x,y,z,math.max(0,31-y)*16+x) end
end end end
local ground={};for _,r in ipairs(shipTiles) do for _,t in ipairs(r) do ground[t]=20 end end
for _,t in ipairs({1,2,17,18}) do ground[t]=20 end
for _,t in ipairs({6,7,22,23,8,9,24,25}) do ground[t]=5 end
local detail=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/detail_geometry.lua')
for _,a in ipairs(assets)do if a.id=='port_gym_statue' then detail.southCell(a) end end
local audited=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/statue_repairs.lua')
for _,a in ipairs(assets)do audited.repair(a)end
return {tilesets={TILESET_PORT={assets=assets,prop_ground=ground,planter_spray=false,
 classes={port_deck={base='wall',height=2,art='flat'},port_pool_wall={base='wall',height=16,art='flat'},port_pool_rim={base='ledge',height=2,art='flat'}},
 pins={
 ground={0,10,12,13,14,21,28,29}, -- concrete gym border, entry mat and sandy dock
 port_deck={5,49}, -- low brick walkway and its entrance landing
 port_pool_rim={11,34}, -- pool surround and bridge sides remain a low rim
 port_pool_wall={15}, -- only the gym's north boundary is a tall wall
 water={20},stair_w={3,4,30,31}, -- harbor stair rises west out of the landing
 }}}}
