-- Native palette texels, arranged as a low counter and horizontal machine.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')
local H=dofile(dir..'/public_interior_shapes.lua')
local R={}
function R.repair(a)
 local donors={pokecenter_counter={32,16,128},pokecenter_ball_counter={32,16,128},
  center_counter_single={16,8,64},center_ball_counter_single={16,8,64},
  pokecenter_counter_edge={0,1,84},center_short_counter_edge={0,1,84},center_counter_return={2,7,1}}
 local d=donors[a.id]
 if d then
  a.groundTile=17
  local W=#a.tiles[1]*8;local z0=(a.id:find('edge')and 8 or 0)
  a.surfaces={H.s({0,0,1,1},'vertical',0,1)}
  a.voxelEdits={{x=0,y=0,z=0,remove=true}}
  -- Plain worktop and continuous recessed blue fascia. Decorative PC/ball
  -- pixels in the source selection never become patterns on the worktop.
  for x=0,W-1 do for z=0,15 do for y=0,6 do
   H.put(a,x,y,z0+z,y==6 and d[1]or(y==5 and d[2]or d[3]))
  end end end
 elseif a.id=='center_healing_machine' then
  a.groundTile=17
  a.surfaces={H.s({0,0,1,1},'vertical',0,1)}
  a.voxelEdits={{x=0,y=0,z=0,remove=true}}
  -- Full native footprint: low cabinet, horizontal six-ball tray, shallow
  -- control strip at the back. No upright arch or balls outside healing.
  for x=0,31 do for z=0,31 do
   local cut=(x<2 or x>29)and(z<2 or z>29)
   if not cut then
    local rim=x<3 or x>28 or z<3 or z>28
    local top=z<6 and 13 or(rim and 10 or 8)
    for y=0,top do
     local i
     if y==top then i=z*32+x
     else i=(26+math.min(5,9-y))*32+x end
     H.put(a,x,y,z,i)
    end
   end
  end end
  -- Six contrasting recessed slots; two columns, three rows, all inside tray.
  for _,cx in ipairs({9,22})do for _,cz in ipairs({10,18,26})do
   for x=cx-3,cx+3 do for z=cz-3,cz+3 do
    local r=(x-cx)^2+(z-cz)^2
    if r<=10 then H.put(a,x,9,z,r>=7 and 16 or 0)end
   end end
  end end
 end
 return a
end
function R.apply(profile)
 for _,a in ipairs(profile.buildings.TILESET_POKECENTER)do R.repair(a)end
 local list=profile.buildings.TILESET_POKECENTER
 local ids={};for _,a in ipairs(list)do ids[a.id]=true end
 for _,a in ipairs(R.fillers())do if not ids[a.id]then list[#list+1]=a end end
 -- No painted furniture should be chosen as floor beneath the storage unit.
 for _,a in ipairs(list)do if a.id=='center_storage_unit'then a.groundTile=17 end end
end
function R.fillers()
 local out={}
 for _,item in ipairs({{'center_counter_single',52},{'center_ball_counter_single',12}})do
  local a=H.blank(item[1],{{item[2]},{36}});R.repair(a);out[#out+1]=a
 end
 return out
end
return R
