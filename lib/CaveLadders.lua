-- Native cave ladder warps rendered in their own collision cell. No new
-- exits, movement rules or companion scenery; all source texels are native.
local L={}
local caves={TILESET_CAVE=true,TILESET_DARK_CAVE=true,TILESET_ICE_PATH=true}
function L.kind(map,cx,cy)
 if not(map.tileset and caves[map.tileset.id])or not map.cellCollision or map:cellCollision(cx,cy)~=0x72 then return nil end
 local tile=map:tileAt(cx*2,cy*2)
 if map.tileset.id=='TILESET_ICE_PATH'then return nil end -- authored ice ladders already own their cells
 if tile==40 or tile==42 then return 'up' end
 if tile==32 or tile==34 then return 'down' end
end
function L.build(S,map,key)
 if not(map.def and caves[map.tileset.id])then return end
 local aw,ah=map.tileset.imageWidth or 128,map.tileset.imageHeight or 64
 local stride=map.tileset.tilesPerRow or 16
 local function uv(tile,px,py)return ((tile%stride)*8+px)/aw,(math.floor(tile/stride)*8+py)/ah end
 local function face(points,tile,shade,solid)
  local q={uv={},shade=shade or 1};local corners={{.05,7.95},{7.95,7.95},{7.95,.05},{.05,.05}}
  for i,p in ipairs(points)do
   local u,v=uv(tile,solid and 2.5 or corners[i][1],solid and 1.5 or corners[i][2])
   q[i]={p[1],p[2],p[3]};q.uv[i]={u,v}
  end
  S.objectQuads[#S.objectQuads+1]=q
 end
 local function box(x,y,z,w,h,d,tile,solid)
  face({{x,y,z+d},{x+w,y,z+d},{x+w,y+h,z+d},{x,y+h,z+d}},tile,.9,solid)
  face({{x+w,y,z},{x,y,z},{x,y+h,z},{x+w,y+h,z}},tile,.8,solid)
  face({{x,y,z},{x,y,z+d},{x,y+h,z+d},{x,y+h,z}},tile,.75,solid)
  face({{x+w,y,z+d},{x+w,y,z},{x+w,y+h,z},{x+w,y+h,z+d}},tile,.75,solid)
  face({{x,y+h,z+d},{x+w,y+h,z+d},{x+w,y+h,z},{x,y+h,z}},tile,1,solid)
 end
 for _,warp in ipairs(map.def.warps or{})do
  local kind=L.kind(map,warp.x,warp.y)
  if kind then
   local x,z=warp.x*16,warp.y*16
   local level=0;local samples={}
   for _,d in ipairs({{0,1},{0,-1},{1,0},{-1,0}})do
    local cx,cy=warp.x+d[1],warp.y+d[2]
    local shape=S.shapeAt and S.shapeAt[key(cx*2,cy*2)]
    if shape and shape.art~='stair' and map.isWalkableCell and map:isWalkableCell(cx,cy)then
     samples[#samples+1]=math.max(0,shape.h or 0)
    end
   end
   if #samples>0 then table.sort(samples);level=samples[1]end
   S.support=S.support or{}
   for dy=0,1 do for dx=0,1 do local k=key(warp.x*2+dx,warp.y*2+dy)
    S.skip[k]=true;S.ground[k]=nil;S.support[k]=level
   end end
   local bottom,top=level+(kind=='up'and 0 or -12),level+(kind=='up'and 48 or 3)
   if kind=='down'then
    -- Frame an actual shaft, keeping the surrounding walking floor intact.
    box(x, level-1,z,16,1,3,1);box(x,level-1,z+13,16,1,3,1)
    box(x,level-1,z+3,3,1,10,1);box(x+13,level-1,z+3,3,1,10,1)
    face({{x+3,level-12,z+13},{x+13,level-12,z+13},{x+13,level-12,z+3},{x+3,level-12,z+3}},16,.5)
    face({{x+3,level-12,z+3},{x+13,level-12,z+3},{x+13,level,z+3},{x+3,level,z+3}},22,.7)
    face({{x+3,level-12,z+13},{x+3,level-12,z+3},{x+3,level,z+3},{x+3,level,z+13}},22,.7)
    face({{x+13,level-12,z+3},{x+13,level-12,z+13},{x+13,level,z+13},{x+13,level,z+3}},22,.7)
   else
    face({{x,level,z+16},{x+16,level,z+16},{x+16,level,z},{x,level,z}},1,1)
   end
   -- Two rails and independent rungs remain readable from either side.
   box(x+3,bottom,z+4,1,top-bottom,2,40,true)
   box(x+12,bottom,z+4,1,top-bottom,2,40,true)
   for y=bottom+2,top-1,4 do box(x+4,y,z+4,8,1,2,40,true)end
  end
 end
end
return L
