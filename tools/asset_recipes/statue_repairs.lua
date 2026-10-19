-- Reusable native-art busts and carved plaques. The face remains the
-- original picture: depth is added behind it, not by scrambling its texels.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local P=dofile(dir..'/historic_primitives.lua');local R={}
R.guardians={station_gym_statue=true,station_dojo_statue=true,underground_gym_statue=true,
 port_gym_statue=true,game_gym_statue=true,ruins_statue=true}
R.plaques={elite_bird_statue=true,elite_dragon_emblem=true}
local outline={
 '...###....###...', '..############..', '..############..', '.##############.',
 '.##############.', '.##############.', '..############..', '...##########...',
 '...##########...', '...##########...', '..############..', '...##########...',
 '...##########...', '...##########...', '..############..', '...##########...',
}
function R.repair(a)
 local guardian,plaque=R.guardians[a.id],R.plaques[a.id]
 if not guardian and not plaque then return false end
 local H=guardian and 32 or 16
 local z0=guardian and 16 or 0
 a.surfaces={P.s({0,0,1,1},'vertical',0,1,z0)}
 a.voxelEdits={{x=0,y=0,z=z0,remove=true}}
 if guardian then
  -- Original pedestal face: keep the plaque and carved border intact.
  for y=0,15 do local inset=(y<2 or y>=14)and 0 or 2
   for x=inset,15-inset do for z=16+inset,31-inset do P.put(a,x,y,z,(31-y)*16+x)end end
  end
  -- Full native eyes, teeth and mouth on the front of a rounded bust.
  local function inside(x,y)return x>=0 and x<16 and y>=0 and y<16 and outline[y+1]:sub(x+1,x+1)=='#'end
  for sy=0,15 do for x=0,15 do if inside(x,sy)then
   local half=4
   for dy=-4,4 do for dx=-4,4 do
    if not inside(x+dx,sy+dy)then half=math.min(half,math.max(math.abs(dx),math.abs(dy)))end
   end end
   for z=24-math.max(1,half),28 do P.put(a,x,31-sy,z,sy*16+x)end
  end end end
 else
  -- Violet's square stone carving and Blackthorn's circular dragon crest
  -- are engraved panels, not freestanding birds or empty toruses.
  for sy=0,15 do for x=0,15 do
   local inside=a.id=='elite_bird_statue'or((x-7.5)^2+(sy-7.5)^2<=64)
   if inside then for z=10,13 do P.put(a,x,15-sy,z,sy*16+x)end end
  end end
 end
 return true
end
function R.apply(p)
 local count=0
 for _,list in pairs(p.buildings)do for _,a in ipairs(list)do if R.repair(a)then count=count+1 end end end
 assert(count==8,'expected eight guardian/carving variants')
 return p
end
return R
