-- One complete gate crosses the Route 29/46 connection. The northern
-- roof fragment only claims its tiles; the southern facade owns the model.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local H=dofile(dir..'/public_interior_shapes.lua')
local roof={{49,54,54,54,54,54,54,52},{65,72,72,72,72,72,72,68},
 {65,72,72,72,72,72,72,68},{81,82,82,82,82,82,82,84}}
local north={id='johto_route_29_46_gate_north',tiles=roof,map='ROUTE_46',claimOnly=true}
local south=H.blank('johto_route_29_46_gate_south',{
 {26,7,7,7,7,7,7,28},{26,7,7,7,7,38,38,28},
 {26,7,55,56,7,7,7,28},{1,2,57,58,2,2,2,22}})
south.map='ROUTE_29';south.topRows=roof
local function facade(x,y)return (63-y)*64+x end
for x=-1,64 do for z=-33,32 do for y=32,34 do
 -- The original roof band supplies a continuous flat deck with its own
 -- edge trim. Compress its 32 source rows over the building's 64px depth.
 local sx=math.max(0,math.min(63,x));local sy=math.max(0,math.min(31,math.floor((z+32)/2)))
 H.put(south,x,y,z,sy*64+sx)
end end end
for y=0,31 do
 for x=0,63 do
  local door=x>=18 and x<30 and y<14
  local window=x>=40 and x<56 and y>=18 and y<=23 and (x%8==1 or x%8==2 or x%8==5 or x%8==6)
  H.put(south,x,y,door and 28 or window and 30 or 31,facade(x,y))
  -- Reuse the brick facade and door art on the northern entrance. The
  -- double warp gets a double-width door, with real jambs and a lintel.
  local rearDoor=x>=16 and x<48 and y<14
  local sourceX=rearDoor and (16+math.floor((x-16)/2)) or x
  H.put(south,x,y,rearDoor and -29 or -32,facade(sourceX,y))
 end
 for z=-32,31 do
  -- Brick tiles from the facade, bordered by the original corner posts.
  local sx=(z+32)%8+8
  H.put(south,0,y,z,facade(y<3 and 1 or sx,y))
  H.put(south,63,y,z,facade(y<3 and 62 or sx,y))
 end
end
for x=40,55 do H.put(south,x,16,32,facade(x,16)) end
return {tilesets={TILESET_JOHTO={assets={north,south}}}}
