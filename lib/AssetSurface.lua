-- The editor and runtime share this pixel-to-voxel mapping. A cell's i is
-- its source texel in the complete selected tile arrangement, including white.
local Surface = {}
local function integer(value, default, lo, hi)
  if value == nil then return default end
  assert(type(value)=="number" and value==value and value~=math.huge and value~=-math.huge,
    "surface coordinates must be finite numbers")
  return math.max(lo,math.min(hi,math.floor(value)))
end
function Surface.build(W,H,surfaces,edits,sortCells)
  W,H=integer(W,8,1,256),integer(H,8,1,256)
  assert(type(surfaces)=="table","surfaces must be a list")
  local occupied={}
  local sourceOwners, normalized = {}, {}
  -- Every generated/sculpted coordinate is in [-128,383]. Packing the
  -- three 9-bit coordinates is exact in Lua numbers and avoids allocating
  -- a temporary string on each of the mesher's millions of empty probes.
  local function key(x,y,z) return ((y+128)*512+z+128)*512+x+128 end
  for region,s in ipairs(surfaces) do
    assert(type(s)=="table" and type(s.rect)=="table","surface needs a source rectangle")
    assert(s.orientation=="vertical" or s.orientation=="horizontal","unknown surface orientation")
    local r=s.rect
    local rx=integer(r[1] or r.x,0,0,W-1)
    local ry=integer(r[2] or r.y,0,0,H-1)
    local rw=integer(r[3] or r.w,W-rx,1,W-rx)
    local rh=integer(r[4] or r.h,H-ry,1,H-ry)
    local depth=integer(s.depth,1,1,32)
    local height=integer(s.height,0,-128,128)
    local z0=integer(s.z,0,-128,128)
    normalized[region]={rx=rx,ry=ry,rw=rw,rh=rh,depth=depth,height=height,z=z0,
      orientation=s.orientation}
    for sy=ry,ry+rh-1 do for sx=rx,rx+rw-1 do
      sourceOwners[sy*W+sx]=region
    end end
  end
  -- A later region moves its source pixels out of earlier surfaces, even
  -- when the two resulting volumes never intersect in world space.
  for region,s in ipairs(normalized) do
    local rx,ry,rw,rh=s.rx,s.ry,s.rw,s.rh
    local depth,height,z0=s.depth,s.height,s.z
    for sy=ry,ry+rh-1 do for sx=rx,rx+rw-1 do
      if sourceOwners[sy*W+sx]==region then
      for d=0,depth-1 do
        local y,z
        if s.orientation=="vertical" then y,z=height+ry+rh-1-sy,z0+d
        else y,z=height+d,z0+sy-ry end
        occupied[key(sx,y,z)]={x=sx,y=y,z=z,i=sy*W+sx,region=region}
      end
      end
    end end
  end
  for _,edit in ipairs(edits or {}) do
    local x=integer(edit.x,0,-128,383)
    local y=integer(edit.y,0,-128,383)
    local z=integer(edit.z,0,-128,383)
    if edit.remove then occupied[key(x,y,z)]=nil
    else
      occupied[key(x,y,z)]={x=x,y=y,z=z,i=integer(edit.i,0,0,W*H-1),
        region=integer(edit.region,1,1,math.max(1,#surfaces))}
    end
  end
  local cells={}
  local xmin,xmax,ymin,ytop,zmin,zmax=math.huge,-math.huge,math.huge,-math.huge,math.huge,-math.huge
  for _,cell in pairs(occupied) do
    cells[#cells+1]=cell
    xmin,xmax=math.min(xmin,cell.x),math.max(xmax,cell.x)
    ymin,ytop=math.min(ymin,cell.y),math.max(ytop,cell.y)
    zmin,zmax=math.min(zmin,cell.z),math.max(zmax,cell.z)
  end
  if #cells==0 then xmin,xmax,ymin,ytop,zmin,zmax=0,-1,0,-1,0,-1 end
  if sortCells~=false then table.sort(cells,function(a,b)
    if a.y~=b.y then return a.y<b.y end
    if a.z~=b.z then return a.z<b.z end
    return a.x<b.x
  end) end
  local model={W=W,xmin=xmin,xmax=xmax,ymin=ymin,ytop=ytop,zmin=zmin,zmax=zmax,cells=cells}
  function model.at(x,y,z)
    if x<xmin or x>xmax or y<ymin or y>ytop or z<zmin or z>zmax then return nil end
    if x%1~=0 or y%1~=0 or z%1~=0 then return nil end
    local cell=occupied[key(x,y,z)]
    return cell and cell.i
  end
  return model,cells
end
return Surface
