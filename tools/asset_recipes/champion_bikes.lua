-- Shared bicycle structure, using texels from each selected source drawing.
-- Wheels, frame tubes and controls are actual voxels, not a sprite billboard.
local variants={
 {id='shop_bicycle_side',tiles={{12,13,14,15},{28,29,30,31}},tex={tire=291,frame=204,seat=140,light=197,grip=51}},
 {id='shop_bicycle_front',tiles={{5,6},{21,22}},tex={tire=215,frame=166,seat=149,light=167,grip=216}},
 {id='shop_bicycle_diagonal',tiles={{40,41},{56,57}},tex={tire=217,frame=104,seat=40,light=58,grip=200}},
}
for index,a in ipairs(variants) do
 a.surfaces={{rect={0,0,1,1},orientation='vertical',height=0,depth=1,z=0}}
 a.voxelEdits={{x=0,y=0,z=0,remove=true}}
 local function put(x,y,z,material)
  if index==2 then x,z=z,x*.5
  elseif index==3 then x,z=7.5+(x-15.5)*.38+(z-7)*.45,7.5+(x-15.5)*.38-(z-7)*.45 end
  a.voxelEdits[#a.voxelEdits+1]={x=math.floor(x+.5),y=y,z=math.floor(z+.5),i=a.tex[material],region=1}
 end
 local function tube(x0,y0,x1,y1,z,mat)
  local n=math.max(math.abs(x1-x0),math.abs(y1-y0))
  for k=0,n do put(math.floor(x0+(x1-x0)*k/n+.5),math.floor(y0+(y1-y0)*k/n+.5),z,mat or 'frame') end
 end
 for _,cx in ipairs({6,25}) do
  for x=cx-5,cx+5 do for y=0,10 do
   local r=(x-cx)^2+(y-5)^2
   if r>=16 and r<=27 then for z=6,8 do put(x,y,z,'tire') end
   elseif r<16 and (x==cx or y==5) then put(x,y,7,'light') end
  end end
 end
 for z=7,8 do
  tube(6,5,12,12,z);tube(12,12,16,5,z);tube(16,5,6,5,z)
  tube(12,12,22,12,z);tube(22,12,16,5,z);tube(22,12,25,5,z)
  tube(12,12,12,14,z);tube(22,12,21,16,z)
 end
 for x=10,15 do for z=5,9 do put(x,14,z,'seat') end end
 for z=3,11 do put(21,16,z,(z<=4 or z>=10) and 'grip' or 'frame') end
 for z=3,11 do put(16,4,z,'frame') end
 for _,z in ipairs({3,11}) do for x=15,17 do put(x,4,z,'grip') end end
 a.tex=nil
end
return variants
