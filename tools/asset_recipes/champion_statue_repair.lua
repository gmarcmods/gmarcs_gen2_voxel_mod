local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local detail=dofile(root..'/detail_geometry.lua')
local D={}
function D.asset(a)
 assert(a.id=='champion_orb_pedestal','unexpected statue')
 if a.surfaces[1].z==19 then return a end -- already aligned; migration is idempotent
 assert(a.surfaces[1].z==3,'unexpected authored pedestal offset')
 return detail.southCell(a)
end
function D.apply(p)
 local count=0
 for _,a in ipairs(p.buildings.TILESET_CHAMPIONS_ROOM)do
  if a.id=='champion_orb_pedestal'then D.asset(a);count=count+1 end
 end
 assert(count==1,'expected one authored Champions Room pedestal')
 return p
end
return D
