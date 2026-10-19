-- Native cave rock, bounded per map; no authored profile/collision edits.
local V=...
local I={};local empty={walls={},hangings={}};local cache={};local plans=setmetatable({},{__mode='k'})
local caves={TILESET_CAVE=true,TILESET_DARK_CAVE=true,TILESET_ICE_PATH=true}
local rocks={wall=true,cave_rim=true,cave_plateau=true,ice_wall=true}
function I.supports(map)return map and map.tileset and caves[map.tileset.id]==true and(not map.def.environment or map.def.environment=='CAVE')end
function I.material(map)return map.tileset.id=='TILESET_ICE_PATH'and 18 or 22 end
local function sample(list,limit)
 local out={};local n=math.min(#list,limit)
 for i=1,n do out[i]=list[math.floor((i-.5)*#list/n)+1]end
 return out
end
function I.layout(map)
 if not I.supports(map)or(map.def.voxelShapes and map.def.voxelShapes.caveDetails==false)then return empty end
 if plans[map]then return plans[map]end
 local T=V.require('TileShape');local shapes=T.forMap(map)
 local walls,hanging={},{};local warps={};local solid={}
 for _,w in ipairs(map.def.warps or {})do warps[w.y*1024+w.x]=true end
 local width,height=map.widthCells,map.heightCells
 for cy=0,height-1 do for cx=0,width-1 do
  local walk=map:isWalkableCell(cx,cy);local rock,flat=false,true
  local tiles,rockTiles={},{}
  for dy=0,1 do for dx=0,1 do
   local tile=map:tileAt(cx*2+dx,cy*2+dy);tiles[#tiles+1]=tile
   local s=tile and T.at(map,shapes,tile,cx*2+dx,cy*2+dy)
   if s and rocks[s.class]and(s.h or 0)>=12 then rock=true;rockTiles[#rockTiles+1]=tile end
   flat=flat and s and s.class=='ground'and(s.h or 0)==0
  end end
  if #rockTiles>0 then for i=1,4 do tiles[i]=rockTiles[(i-1)%#rockTiles+1]end end
  local seed=(cx*73+cy*151+#map.id*17)%997
  if not walk and rock and not warps[cy*1024+cx] and not(map.isWaterCell and map:isWaterCell(cx,cy))then
   solid[cy*1024+cx]=true
   local near=false
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local x,y=cx+d[1],cy+d[2]
    if x>=0 and y>=0 and x<width and y<height and map:isWalkableCell(x,y)then near=true end
   end
   if near then walls[#walls+1]={cx=cx,cy=cy,tiles=tiles,seed=seed,height=26+seed%5}end
  elseif walk and flat and not warps[cy*1024+cx]and seed%3==0 then
   -- Every side stays inside this safe floor cell; source rock is taken
   -- from the nearest solid edge later, never from water/carpet artwork.
   hanging[#hanging+1]={cx=cx,cy=cy,seed=seed}
  end
 end end
 local result={walls=sample(walls,96),hangings=sample(hanging,32),solid=solid}
 local material=I.material(map)
 local native=walls[1]and {material,material,material,material}
 for _,w in ipairs(result.walls)do w.tiles=native end
 for _,h in ipairs(result.hangings)do h.tiles=native end
 plans[map]=result;return result
end
-- Native surface occupancy for optional presentation and camera clearance.
-- This describes solids only; it does not move actors or change collision.
function I.openingAt(map,cx,cy)
 return I.supports(map) and V.require('CaveLadders').kind(map,cx,cy)=='up'
end
function I.wallAt(map,cx,cy)
 local plan=I.layout(map)
 return plan.solid and plan.solid[cy*1024+cx] or false
end
local faces={
 {1,{{1,0,0},{1,1,0},{1,1,1},{1,0,1}},.78},
 {2,{{0,0,1},{0,1,1},{0,1,0},{0,0,0}},.78},
 {3,{{0,1,0},{0,1,1},{1,1,1},{1,1,0}},1},
 {4,{{0,0,1},{0,0,0},{1,0,0},{1,0,1}},.55},
 {5,{{1,0,1},{1,1,1},{0,1,1},{0,0,1}},.92},
 {6,{{0,0,0},{0,1,0},{1,1,0},{1,0,0}},.85}}
local function box(g,map,tiles,x,y,z,w,h,d,seed,cap)
 if not tiles then return end
 local aw,ah=map.tileset.imageWidth or 128,map.tileset.imageHeight or 48
 for fi,f in ipairs(faces)do if not(cap=='up'and f[1]==4 or cap=='down'and f[1]==3)then
  local tile=tiles[(seed+fi)%4+1]
  local u0,v0=(tile%16*8+.05)/aw,(math.floor(tile/16)*8+.05)/ah
  local u1,v1=(tile%16*8+7.95)/aw,(math.floor(tile/16)*8+7.95)/ah
  local uv={{u0,v1},{u0,v0},{u1,v0},{u1,v1}};local b=#g.vertices
  for i,p in ipairs(f[2])do g.vertices[#g.vertices+1]={x+p[1]*w,y+p[2]*h,z+p[3]*d,uv[i][1],uv[i][2],f[3]}end
  for _,i in ipairs({1,2,3,1,3,4})do g.indices[#g.indices+1]=b+i end
 end end
end
function I.geometry(map,headroom,count)
 local plan=I.layout(map);local walls={vertices={},indices={}};local ceiling={vertices={},indices={}}
 -- Native authored rock is the only solid surface. Procedural caps used
 -- to stack another 10-14 pixels on it and turn shores into confusing walls.
 headroom=headroom or 32
 if headroom>=28 then for index,p in ipairs(sample(plan.hangings,count or 16))do
  if index>(count or 16)then break end
  local length=4+p.seed%5;local x,z=p.cx*16+8,p.cy*16+8
  for tier=0,3 do
   local radius=4-tier;local top=headroom-math.floor(tier*length/4)
   local bottom=headroom-math.floor((tier+1)*length/4)
   box(ceiling,map,p.tiles,x-radius,bottom,z-radius,radius*2,top-bottom,radius*2,p.seed+tier,'down')
  end
 end end
 return walls,ceiling
end
function I.mesh(map,headroom,count)
 if not I.supports(map)then return nil end
 local key=map.id..':'..(headroom or 0)..':'..(count or 0)
 local entry=cache[key]
 if not entry or entry.map~=map then
  local walls,ceiling=I.geometry(map,headroom or 0,count or 0)
  local R=V.require('Voxel3D')
  entry={map=map,walls=(not headroom or headroom==0)and #walls.vertices>0 and R.newMesh(walls.vertices,walls.indices)or false,
   ceiling=#ceiling.vertices>0 and R.newMesh(ceiling.vertices,ceiling.indices)or false,
   wallQuads=#walls.vertices/4,ceilingQuads=#ceiling.vertices/4};cache[key]=entry
 end
 return entry
end
function I.invalidate(id)
 for k,e in pairs(cache)do if not id or e.map.id==id then
  for _,name in ipairs({'walls','ceiling'})do if e[name]then e[name]:release()end end
  plans[e.map]=nil;cache[k]=nil
 end end
 if not id then plans=setmetatable({},{__mode='k'})
 else for map in pairs(plans)do if map.id==id then plans[map]=nil end end end
end
function I.setLive(live)
 for _,entry in pairs(cache)do if not live[entry.map.id]then I.invalidate(entry.map.id)end end
end
function I.fog(map,world)
 if not I.supports(map)or world and world.daytime=='DARK'then return nil end
 return {color={.12,.13,.16},density=.0012,start=96,heightK=0}
end
return I
