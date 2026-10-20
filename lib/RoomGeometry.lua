-- Local corrections for reused furniture tiles. Other rooms keep their art.
local R={};local counters={[64]=true,[65]=true,[66]=true,[80]=true,[81]=true,[82]=true,[83]=true,[84]=true}
local cache={}
local routeCopies=setmetatable({},{__mode='k'})
local pit={class='elite_pit',base='elite_pit',h=-32,art='flat',flat=true,authored=true}
function R.at(map,shape,tile)
 if map.tileset and map.tileset.id=='TILESET_ELITE_FOUR_ROOM'and shape.class=='elite_void'then
  return pit
 end
 if map.id=='ROUTE_6'and(tile==4 or tile==55 or tile==52)then
  local out=routeCopies[shape]
  if not out then out={};for k,v in pairs(shape)do out[k]=v end;out.h=4;routeCopies[shape]=out end
  return out
 end
 if map.id~='SILPH_CO_1F'or not counters[tile]then return shape end
 if not cache[tile]then cache[tile]={class='counter',base='counter',h=8,art='flat',flat=true,authored=true}end
 return cache[tile]
end
function R.build(S,map,key)
 if map.id~='ROUTE_6'then return end
 local aw,ah=map.tileset and map.tileset.imageWidth or 128,map.tileset and map.tileset.imageHeight or 48
 local function face(points,tile,shade)
  local q={uv={},shade=shade};local u,v=tile%16*8,math.floor(tile/16)*8
  for i,p in ipairs(points)do q[i]=p;local uv=({{0,8},{8,8},{8,0},{0,0}})[i];q.uv[i]={(u+uv[1])/aw,(v+uv[2])/ah}end
  S.objectQuads[#S.objectQuads+1]=q
 end
 for ty=0,map.heightCells*2-1 do for tx=0,map.widthCells*2-1 do
  local k=key(tx,ty)
  if map:tileAt(tx,ty)==4 and not S.skip[k]then
   S.skip[k]=true;S.ground[k]=44
   local x,z=tx*8,ty*8
   for step=0,3 do local a,b,h=z+step*2,z+(step+1)*2,4-step
    face({{x,h,a},{x+8,h,a},{x+8,h,b},{x,h,b}},44,1)
    face({{x,h-1,b},{x+8,h-1,b},{x+8,h,b},{x,h,b}},4,.7)
    face({{x,0,a},{x,h,a},{x,h,b},{x,0,b}},4,.78)
    face({{x+8,0,b},{x+8,h,b},{x+8,h,a},{x+8,0,a}},4,.78)
   end
  end
 end end
end
return R
