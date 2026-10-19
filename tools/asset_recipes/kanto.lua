-- Kanto source-specific scenery. Every color comes from the selected tiles.
local function s(r,o,h,d,z) return {rect=r,orientation=o,height=h,depth=d,z=z or 0} end
local details=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/kanto_route_details.lua').tilesets.TILESET_KANTO
local assets={}
local function add(a) assets[#assets+1]=a;return a end
local function put(a,x,y,z,i) a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=i,region=1} end
local function blank(id,tiles)
 return add({id=id,tiles=tiles,surfaces={s({0,0,1,1},'vertical',0,1)},voxelEdits={{x=0,y=0,z=0,remove=true}}})
end
local function tree(id,tiles)
 local a=blank(id,tiles);a.border=true
 return dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/native_tree_shape.lua')(a)
end
-- The main forest and Cut saplings are separate drawings and silhouettes.
tree('kanto_tree',{{64,65},{80,81}})
local cut=blank('kanto_sapling',{{45,46},{61,62}});cut.border=true
dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/detail_geometry.lua').cutTree(cut)
add({id='kanto_sign',tiles={{70,71},{86,87}},surfaces={
 s({1,1,14,10},'vertical',5,2,7),s({1,11,2,5},'vertical',0,2,7),s({13,11,2,5},'vertical',0,2,7)}})
-- The shared route pass supplies domed rocks, joined fence rails and the
-- map-local Nugget Bridge model.
for _,a in ipairs(details.assets)do add(a)end
-- Model the sea-facing timber edge of Route 12's low piers.
local deck=blank('kanto_pier_edge',{{49}})
for x=0,7 do for z=0,7 do put(deck,x,2,z,z*8+x) end end
for _,x in ipairs({1,6}) do for y=-3,1 do put(deck,x,y,6,6*8+x) end end
local cave=blank('kanto_cave',{{72,73},{88,89}})
for x=0,15 do for z=0,15 do
 local top=math.floor(8+7*math.sqrt(1-((x-7.5)/8)^2))
 for y=0,top do if x<3 or x>12 or y>=11 then
  local i=(15-y)*16+x
  if z<15 then
   i=(15-y)*16+(x<8 and z%3 or 13+z%3)
   if y>=11 then i=(2+z%4)*16+2+x%4 end
  end
  put(cave,x,y,z,i)
 end end
end end
cave.surfaces[#cave.surfaces+1]=s({3,8,10,8},'horizontal',0,1,4)
local ground={}
for _,a in ipairs(assets) do for _,row in ipairs(a.tiles) do for _,t in ipairs(row) do ground[t]=44 end end end
for _,t in ipairs({70,71,86,87,14,85,72,73,88,89}) do ground[t]=57 end
-- A pier edge must retain the water below its supporting posts.
ground[49]=20
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local buildings=dofile(dir..'/kanto_architecture.lua')
for i=#buildings,1,-1 do table.insert(assets,1,buildings[i]) end
local entrance=dofile(dir..'/tunnel_entrances.lua')
for _,a in ipairs(assets)do entrance(a)end
return {tilesets={TILESET_KANTO={
 heights={ledge=3}, -- shallow jump lip for Kanto routes
 classes={kanto_cliff={base='wall',height=16,art='flat'},kanto_shore={base='ledge',height=3,art='flat'},kanto_deck={base='wall',height=2,art='flat'}},
 pins={
 ground={0,13,16,32,33,35,44,48,57,79,91}, -- roads, curb paint, turf, sand and warp mats remain flat
 grass={82},flower={3}, -- animated encounter grass and flowers use the existing primitives
 water={20}, -- open water, including sea borders
 kanto_shore={51,84}, -- shoreline artwork sits close to the water surface
 kanto_cliff={1,2,17,18,19,30,36,39,52,53,54}, -- mountain tops and edges rise together
 ledge={4,55}, -- low hop-down lips; full rock courses override tile 55 below
 kanto_deck={75}, -- walkable pier planks, with facade occurrences claimed by buildings
 },
 when_above={[55]={{above={1,17,19,30,36,39,52,53,54,55},class='kanto_cliff'}}},
 when_below={[55]={{below={20,51,84},class='kanto_shore'}}},
 prop_ground=ground,planter_spray=false,
 border_blocks={MOUNT_MOON_SQUARE=44}, -- this mountain map must not repeat its water-corner border block
 mountain=details.mountain,assets=assets,
}}}
