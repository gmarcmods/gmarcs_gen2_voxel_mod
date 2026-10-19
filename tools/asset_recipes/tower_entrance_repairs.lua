-- Source-backed connected timber partitions and complete tower stair flights.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local P=dofile(dir..'/historic_primitives.lua')
local D={}
local function reset(a,z)
 a.surfaces={P.s({0,0,1,1},'vertical',0,1,z or 0)}
 a.voxelEdits={{x=0,y=0,z=z or 0,remove=true}}
end
local function wood(x,y,z)return (15-math.min(15,y))*16+3 end
local function horizontal(a,z)
 P.box(a,0,0,z,16,3,8,wood)
 P.box(a,0,13,z,16,3,8,wood)
 for x=0,15 do if x%4<3 then P.box(a,x,3,z+1,1,10,6,wood)end end
end
local function vertical(a,z0,length)
 P.box(a,4,0,z0,8,3,length,function(x,y,z)return z%16*16+5 end)
 P.box(a,4,13,z0,8,3,length,function(x,y,z)return z%16*16+5 end)
 for z=z0,z0+length-1 do if z%4<3 then P.box(a,5,3,z,6,10,1,function(x,y,zz)return zz%16*16+5 end)end end
end
function D.repair(a)
 if a.id=='tower_timber_rail'then reset(a);horizontal(a,8)
 elseif a.id=='tower_timber_rail_side'then reset(a);vertical(a,0,16)
 elseif a.id=='tower_stone_pillar'then
  reset(a,16)
  -- Stone base occupies the original bottom cell. The timber above it
  -- has a solid shaft and cross-cap instead of a striped cylinder lid.
  for y=0,17 do local r=(y<3 or y>=14)and 7.5 or 5.5
   for x=0,15 do for z=16,31 do if (x-7.5)^2+(z-23.5)^2<=r*r then
    P.put(a,x,y,z,(y<3 and 29 or 16+(17-y)%8)*16+x)
   end end end
  end
  P.box(a,5,18,21,6,10,6,function(x,y,z)return math.max(2,15-(y-18))*16+5 end)
  P.box(a,0,28,16,16,4,16,function(x,y,z)return (6-y%2)*16+math.max(2,math.min(13,x))end)
 else return false end
 return true
end
local function stairs(id,tiles,down)
 local a=P.blank(id,tiles);a.cutFloor=down or nil
 for z=0,15 do
  local top=down and(-16+math.floor(z/4)*4)or(15-math.floor(z/4)*4)
  local bottom=down and-16 or 0
  for x=0,15 do for y=bottom,top do P.put(a,x,y,z,z*16+x)end end
 end
 if down then
  for _,x in ipairs({0,15})do P.box(a,x,-16,0,1,16,16,function(xx,y,z)return z*16+xx end)end
 end
 return a
end
function D.extras()
 local corner=P.blank('tower_timber_corner',{{17,17},{64,32},{65,49},{65,49}})
 horizontal(corner,8);vertical(corner,8,24)
 return {TILESET_TOWER={corner,
  stairs('tower_stairs_up',{{12,13},{28,29}},false),
  stairs('tower_stairs_down',{{14,15},{30,31}},true)},
  TILESET_TRADITIONAL_HOUSE={stairs('traditional_tower_stairs_down',{{76,77},{92,93}},true)}}
end
function D.apply(p)
 for _,a in ipairs(p.buildings.TILESET_TOWER)do D.repair(a)end
 for ts,extras in pairs(D.extras())do
  local list=p.buildings[ts];local found={};for _,a in ipairs(list)do found[a.id]=true end
  for i=#extras,1,-1 do if not found[extras[i].id]then table.insert(list,1,extras[i])end end
 end
 return p
end
return D
