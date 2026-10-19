-- Sprite-backed detail repairs, shared by the recipes and targeted project migration.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local P=dofile(dir..'/historic_primitives.lua')
local D={}
function D.southCell(a)
 for _,s in ipairs(a.surfaces or {})do s.z=(s.z or 0)+16 end
 for _,c in ipairs(a.voxelEdits or {})do c.z=(c.z or 0)+16 end
 return a
end
function D.bellsprout(a)
 a.surfaces={P.s({0,0,1,1},'vertical',0,1,16)}
 a.voxelEdits={{x=0,y=0,z=16,remove=true}}
 P.box(a,2,0,18,12,4,12,function(x,y,z)return (31-y)*16+x end)
 -- Forked feet, thin stem and two leaves below the round yellow head.
 for y=4,16 do
  local cx=7+math.floor(math.sin(y*.24))
  P.box(a,cx,y,23,2,1,3,math.min(27,31-y)*16+7)
 end
 for _,x in ipairs({4,10})do P.ellipsoid(a,x,10,24,3,2,2,function(xx,y,z)return 21*16+xx end)end
 for _,x in ipairs({5,10})do P.box(a,x,4,23,2,2,3,27*16+x)end
 P.ellipsoid(a,7.5,23,24,6.5,7,5,function(x,y,z)return math.max(0,math.min(14,29-y))*16+x end)
 -- A small forward-facing bell mouth: hollow throat and a solid lip.
 for x=5,10 do for y=16,20 do for z=26,30 do
  local q=((x-7.5)/2.5)^2+((y-18)/2)^2
  if q<.62 then a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,remove=true}
  elseif q<=1 and z>=29 then P.put(a,x,y,z,12*16+x)end
 end end end
 return a
end
function D.cutTree(a)
 a.surfaces={P.s({0,0,1,1},'vertical',0,1)};a.voxelEdits={{x=0,y=0,z=0,remove=true}}
 -- Two asymmetric lobes and the exposed narrow stem in the native 16px cut tree.
 -- Radius varies by source row; this is not the normal round forest canopy.
 local rows={{{10,12}},{{8,13}},{{1,6},{8,14}},{{1,6},{8,15}},{{0,6},{8,14}},
  {{1,13}},{{0,7},{9,14}},{{1,7},{9,12}},{{2,10}},{{3,9}}}
 for sy,ranges in ipairs(rows)do
  local y=16-sy
  for _,range in ipairs(ranges)do for x=range[1],range[2]do
   local center=(range[1]+range[2])/2
   local radius=math.max(1,(range[2]-range[1])/2)
   local depth=math.max(1,math.floor(3*math.sqrt(math.max(0,1-((x-center)/(radius+.5))^2))))
   for z=7-depth,7+depth do P.put(a,x,y,z,(sy-1)*16+x)end
  end end
 end
 for y=0,5 do P.box(a,7,y,6,2,1,3,(15-y)*16+7)end
 -- Forks and surface roots follow the lower native branch rows.
 for _,x in ipairs({5,10})do P.box(a,x,1,6,2,2,3,13*16+x)end

 return a
end
return D
