-- A source-unwrapped voxel terrace. Occupancy and each face's paint are
-- separate: the cap is ground; the native rim strips fold onto the sides.
local M={}
local function key(x,y,z)return (y*32+z)*32+x end
function M.build(spec,aw,ah,perRow)
 local cells={};local count=0
 for _,r in ipairs(spec.runs)do for dx=0,r[4]-1 do
  cells[key(r[1]+dx,r[2],r[3])]=true;count=count+1
 end end
 local function solid(x,y,z)
  return x>=0 and x<32 and z>=0 and z<32 and y>=0 and y<spec.height and cells[key(x,y,z)]
 end
 local function paint(face,x,y,z)
  if face=='top'then
   if y+1<spec.height then return z*32+x end -- exposed rim shoulders
   -- Keep the same one-texel-per-voxel ground scale as the walking area.
   return (32+z%8)*32+x%8
  end
  local cross=math.min(7,math.floor((y+.5)*8/spec.height))
  local tangent=(face=='west'or face=='east')and z or x
  if face=='north'or face=='west'then tangent=31-tangent end
  -- The dither on the original east edge is a painted 2D shadow, not
  -- stone material. All faces use the actual native stone border once;
  -- direction shading and shadow maps supply the 3D lighting.
  return (31-cross)*32+tangent
 end
 local groups={}
 local function add(face,plane,u,v,i)
  local k=face..':'..plane;local g=groups[k]
  if not g then g={face=face,plane=plane,grid={}};groups[k]=g end
  g.grid[v*32+u]=i
 end
 for y=0,spec.height-1 do for z=0,31 do for x=0,31 do if solid(x,y,z)then
  if not solid(x,y+1,z)then add('top',y+1,x,z,paint('top',x,y,z))end
  if not solid(x,y,z+1)then add('south',z+1,x,y,paint('south',x,y,z))end
  if not solid(x,y,z-1)then add('north',z,x,y,paint('north',x,y,z))end
  if not solid(x-1,y,z)then add('west',x,z,y,paint('west',x,y,z))end
  if not solid(x+1,y,z)then add('east',x+1,z,y,paint('east',x,y,z))end
 end end end end
 local quads={voxels=count}
 local names={};for k in pairs(groups)do names[#names+1]=k end;table.sort(names)
 local shades={top=1,south=.90,north=.68,west=.72,east=.84}
 for _,name in ipairs(names)do local g=groups[name];local grid=g.grid
  for v=0,31 do for u=0,31 do local i=grid[v*32+u]
   if i~=nil then
    local w=1;while u+w<32 and grid[v*32+u+w]==i do w=w+1 end
    local h=1
    while v+h<32 do
     local same=true;for x=0,w-1 do if grid[(v+h)*32+u+x]~=i then same=false;break end end
     if not same then break end;h=h+1
    end
    for yy=v,v+h-1 do for xx=u,u+w-1 do grid[yy*32+xx]=nil end end
    local p,f=g.plane,g.face;local q
    if f=='top'then q={{u,p,v+h},{u+w,p,v+h},{u+w,p,v},{u,p,v}}
    elseif f=='south'then q={{u,v,p},{u+w,v,p},{u+w,v+h,p},{u,v+h,p}}
    elseif f=='north'then q={{u+w,v,p},{u,v,p},{u,v+h,p},{u+w,v+h,p}}
    elseif f=='west'then q={{p,v,u},{p,v,u+w},{p,v+h,u+w},{p,v+h,u}}
    else q={{p,v,u+w},{p,v,u},{p,v+h,u},{p,v+h,u+w}}end
    local sx,sy=i%32,math.floor(i/32);local tile=spec.sourceTiles[math.floor(sy/8)+1][math.floor(sx/8)+1]
    q.u=(tile%perRow*8+sx%8+.5)/aw;q.v=(math.floor(tile/perRow)*8+sy%8+.5)/ah
    q.shade=shades[f];q.texel=i;q.face=f
    quads[#quads+1]=q
   end
  end end
 end
 return quads
end
return M
