-- Shared source-texel primitives for public interior furniture.
local H={}
function H.s(r,o,h,d,z) return {rect=r,orientation=o,height=h,depth=d,z=z or 0} end
function H.put(a,x,y,z,i) a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=i,region=1} end
function H.blank(id,t) return {id=id,tiles=t,surfaces={H.s({0,0,1,1},'vertical',0,1)},voxelEdits={{x=0,y=0,z=0,remove=true}}} end
function H.box(id,t,d)
 local w,h=#t[1]*8,#t*8;return {id=id,tiles=t,surfaces={H.s({0,0,w,4},'horizontal',h-4,1),H.s({0,4,w,h-4},'vertical',0,d)},voxelEdits={}}
end
function H.desk(id,t)
 local w=#t[1]*8;local a={id=id,tiles=t,surfaces={H.s({0,0,w,8},'horizontal',8,2)},voxelEdits={}}
 for _,x0 in ipairs({1,w-4}) do for _,z0 in ipairs({1,5}) do for x=x0,x0+2 do for z=z0,z0+1 do for y=0,7 do H.put(a,x,y,z,12*w+x) end end end end end
 return a
end
function H.stool(id,t)
 local a=H.blank(id,t)
 for x=1,14 do for z=1,14 do local r=(x-7.5)^2+(z-7.5)^2
 if r<=45 then for y=6,8 do H.put(a,x,y,z,math.min(7,z)*16+x) end end
 if r<=5 then for y=0,5 do H.put(a,x,y,z,12*16+8) end end
 end end;return a
end
function H.plant(id,t)
 local a=H.blank(id,t);local h=#t*8
 for x=2,13 do for z=2,13 do for y=0,7 do if (x-7.5)^2+(z-7.5)^2<=(4+y*.25)^2 then H.put(a,x,y,z,(h-1-y)*16+x) end end end end
 for x=7,9 do for z=7,9 do for y=7,17 do H.put(a,x,y,z,(h-9)*16+x) end end end
 for x=0,15 do for z=0,15 do for y=12,30 do if ((x-7.5)/8)^2+((z-7.5)/8)^2+((y-21)/10)^2<=1 then H.put(a,x,y,z,math.max(2,math.min(h-10,30-y))*16+math.max(3,math.min(12,x))) end end end end
 return a
end
return H
