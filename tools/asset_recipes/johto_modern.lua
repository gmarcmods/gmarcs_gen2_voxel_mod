-- Modern-specific forest source: 19/21 are foliage; 46/47 are metal/brick.
local function s(r,o,h,d,z) return {rect=r,orientation=o,height=h,depth=d,z=z or 0} end
local assets={}
local recipeDir=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local function add(a) assets[#assets+1]=a;return a end
local function put(a,x,y,z,i) a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=i,region=1} end
local function blank(id,tiles)
 return add({id=id,tiles=tiles,surfaces={s({0,0,1,1},'vertical',0,1)},voxelEdits={{x=0,y=0,z=0,remove=true}}})
end
local function tree(id,tiles)
 local a=blank(id,tiles);a.border=true
 return dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/native_tree_shape.lua')(a)
end
-- Tall pattern precedes the small pattern sharing its crown and base tiles.
tree('modern_tree',{{30,31},{19,21},{19,21},{62,63}})
tree('modern_small_tree',{{30,31},{62,63}})
add({id='modern_sign',tiles={{78,79},{94,95}},surfaces={
 s({1,1,14,10},'vertical',5,2,7),s({1,11,2,5},'vertical',0,2,7),s({13,11,2,5},'vertical',0,2,7)}})
-- Single-column modules cover odd-length runs and don't leave a final wall
-- tile behind when a two-column match overlaps its neighbour.
local function rail(id,bottom,corner)
 local a=blank(id,{{90},{bottom}})
 for x=0,7 do for y=8,10 do for z=7,8 do put(a,x,y,z,8*8+x) end end end
 for x=1,3 do for y=0,12 do for z=7,8 do put(a,x,y,z,(15-math.min(15,y))*8+x) end end end
 if corner then for z=0,6 do for y=8,10 do for x=1,3 do put(a,x,y,z,8*8+1) end end end end
 return a
end
rail('modern_rail',89,false)
rail('modern_rail_corner',74,true)
local cave=blank('modern_cave_mouth',{{69,34},{39,40}})
-- Its dark drawing is the passage, not a black cube. Rock frames the opening.
for x=0,15 do for z=0,15 do
 local top=math.floor(8+7*math.sqrt(1-((x-7.5)/8)^2))
 for y=0,top do if x<3 or x>12 or y>=11 then
  local i=(15-y)*16+x
  if z<15 then
   local sx=x<8 and z%3 or 13+z%3
   i=(15-y)*16+sx
   if y>=11 then i=(2+z%4)*16+2+x%4 end
  end
  put(cave,x,y,z,i)
 end end
end end
-- Keep the threshold dark and flush with the approach.
cave.surfaces[#cave.surfaces+1]=s({3,8,10,8},'horizontal',0,1,4)
local ground={}
for _,a in ipairs(assets) do for _,row in ipairs(a.tiles) do for _,t in ipairs(row) do ground[t]=5 end end end
for _,t in ipairs({78,79,94,95,90,89,69,34,39,40}) do ground[t]=6 end
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local buildings=dofile(dir..'/modern_architecture.lua')
for i=#buildings,1,-1 do table.insert(assets,1,buildings[i]) end
local entrance=dofile(dir..'/tunnel_entrances.lua')
for _,a in ipairs(assets)do entrance(a)end
assets[#assets+1]=dofile(dir..'/small_water_rock.lua')('modern_water_rock')
ground[88]=20 -- sea rocks stand in recessed animated water
local coast=dofile(dir..'/coastal_formations.lua').batch().tilesets.TILESET_JOHTO_MODERN.assets
for i=#coast,1,-1 do table.insert(assets,1,coast[i])end
return {tilesets={TILESET_JOHTO_MODERN={
 heights={ledge=3}, -- shallow jump lip; not a full tile-height wall
 classes={modern_cliff={base='wall',height=16,art='flat'},modern_shore={base='ledge',height=4,art='flat'},modern_track={base='wall',height=1,art='flat'}},
 pins={
 ground={0,5,6,47,91}, -- paving, brick roads and approach steps stay at walking height
 grass={4},flower={3}, -- use the existing grass/blossom primitives
 water={20,73,88}, -- fill, shore ripple and claimed sea-rock backing
 modern_cliff={43,44,45,59,60,61,75,77}, -- continuous rock courses, raised toward their interior
 ledge={76}, -- hop-down edge; tall rock and water contexts override below
 modern_track={54,70}, -- railway stripes and ballast stay shallow; gate roofs are claimed assets
 post={74}, -- thin north/south rail posts, not solid walls
 modern_shore={92,93}, -- inside water corners remain low
 cylinder={30,31,62,63},planter={19,21}, -- unclaimed foliage fallback; complete trees take priority
 },
 when_above={[76]={{above={60,75,76,77},class='modern_cliff'}}},
 when_below={ [76]={{below={20,73,88},class='modern_shore'}},
 [75]={{below={20,73,88},class='modern_shore'}},[77]={{below={20,73,88},class='modern_shore'}}},
 prop_ground=ground,planter_spray=false,
 mountain={classes={'modern_cliff'},rise=2,maxHeight=48,sideTile=60},assets=assets,
}}}
