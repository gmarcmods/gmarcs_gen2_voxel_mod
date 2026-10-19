-- Source-backed furniture helpers used by the four historic interior recipes.
local P={}
function P.s(r,o,h,d,z) return {rect=r,orientation=o,height=h,depth=d,z=z or 0} end
function P.blank(id,t) return {id=id,tiles=t,surfaces={P.s({0,0,1,1},'vertical',0,1)},voxelEdits={{x=0,y=0,z=0,remove=true}}} end
function P.put(a,x,y,z,i) a.voxelEdits=a.voxelEdits or {};a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=i,region=1} end
function P.box(a,x0,y0,z0,w,h,d,i)
 for x=x0,x0+w-1 do for y=y0,y0+h-1 do for z=z0,z0+d-1 do P.put(a,x,y,z,type(i)=='function' and i(x,y,z) or i) end end end
end
function P.table(id,t,h)
 local W,D=#t[1]*8,(#t-1)*8;h=h or 8
 local a={id=id,tiles=t,surfaces={P.s({0,0,W,D},'horizontal',h,2)},voxelEdits={}}
 for _,x in ipairs({1,W-4}) do for _,z in ipairs({1,D-4}) do P.box(a,x,0,z,3,h,3,(D+2)*W+x) end end
 return a
end
function P.cabinet(id,t,top,depth)
 local W,H=#t[1]*8,#t*8;top=top or 4;depth=depth or 10
 return {id=id,tiles=t,surfaces={P.s({0,0,W,top},'horizontal',H-top,1),P.s({0,top,W,H-top},'vertical',0,depth)},voxelEdits={}}
end
function P.column(id,t,h)
 local a=P.blank(id,t);local W,H=#t[1]*8,#t*8
 for y=0,h-1 do local r=(y<3 or y>h-5) and 7.5 or 5.5
  for x=0,15 do for z=0,15 do if (x-7.5)^2+(z-7.5)^2<=r*r then P.put(a,x,y,z,math.min(H-1,math.floor((h-1-y)*H/h))*W+x) end end end
 end;return a
end
function P.ellipsoid(a,cx,cy,cz,rx,ry,rz,sample)
 for x=math.floor(cx-rx),math.ceil(cx+rx) do for y=math.floor(cy-ry),math.ceil(cy+ry) do for z=math.floor(cz-rz),math.ceil(cz+rz) do
 if ((x-cx)/rx)^2+((y-cy)/ry)^2+((z-cz)/rz)^2<=1 then P.put(a,x,y,z,sample(x,y,z)) end
 end end end
end
return P
