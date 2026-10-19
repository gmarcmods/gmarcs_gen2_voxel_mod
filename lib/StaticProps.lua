-- Native field objects remain live NPCs (push/smash/event logic is untouched),
-- but their static sprite is reconstructed as a cached solid voxel prop.
local V=...
local P={};local cache={}
local kinds={SPRITE_BOULDER='strength',SPRITE_ROCK='smash',SPRITE_SUDOWOODO='tree'}
function P.handles(def)return def and kinds[def.id]~=nil end
local faces={
 {1,0,0,.78,{{1,0,0},{1,1,0},{1,1,1},{1,0,1}}},
 {-1,0,0,.78,{{0,0,1},{0,1,1},{0,1,0},{0,0,0}}},
 {0,1,0,1,{{0,1,0},{0,1,1},{1,1,1},{1,1,0}}},
 {0,-1,0,.55,{{0,0,1},{0,0,0},{1,0,0},{1,0,1}}},
 {0,0,1,.92,{{1,0,1},{1,1,1},{0,1,1},{0,0,1}}},
 {0,0,-1,.92,{{0,0,0},{0,1,0},{1,1,0},{1,0,0}}}}
function P.geometry(def,data)
 local iw,ih=data:getDimensions();local kind=assert(kinds[def.id]);local cells,occupied={},{}
 local function key(x,y,z)return (y*32+z+16)*32+x end
 -- Find the lowest ink row independently of palette baking.
 local lowest=0;for sy=0,15 do for x=0,15 do local r,_,_,a=data:getPixel(x,sy);if a>0 and (def.trueColor or r<.84)then lowest=math.max(lowest,sy)end end end
 local depth=kind=='strength'and 16 or kind=='smash'and 8 or 6
 for sy=0,lowest do
  local lo,hi=16,-1
  for x=0,15 do local r,_,_,a=data:getPixel(x,sy);if a>0 and (def.trueColor or r<.84)then lo=math.min(lo,x);hi=math.max(hi,x)end end
  if hi>=lo then
   local cx,rx=(lo+hi)/2,(hi-lo+1)/2
   for x=lo,hi do
    local r,_,_,a=data:getPixel(x,sy)
    if a>0 and (def.trueColor or r<.84)then
     local radius=kind=='tree'and(depth/2)or depth/2*rx/8
     local chord=math.max(.5,radius*math.sqrt(math.max(0,1-((x-cx)/(rx+.01))^2)))
     for z=math.ceil(-chord),math.floor(chord-.01)do
      local y=kind=='smash'and math.floor((lowest-sy)*.65)or lowest-sy
      -- A shallow zigzag cleft breaks the upper front, rather than making
      -- a second round boulder. Keep native sprite texels and integer voxels.
      local cleft=kind=='smash'and y>=math.floor(lowest*.3)
        and x==7+math.floor(y/3)%2 and z>=math.floor(chord-.01)
      local k=key(x,y,z)
      if not cleft and not occupied[k]then
       local c={x=x,y=y,z=z,sx=x,sy=sy};cells[#cells+1]=c;occupied[k]=true
      end
     end
    end
   end
  end
 end
 local verts,indices={},{}
 for _,c in ipairs(cells)do for _,f in ipairs(faces)do
  if not occupied[key(c.x+f[1],c.y+f[2],c.z+f[3])]then
   local u,v=(c.sx+.5)/iw,(c.sy+.5)/ih;local b=#verts
   for _,q in ipairs(f[5])do verts[#verts+1]={c.x+q[1],c.y+q[2],c.z+q[3],u,v,f[4]}end
   for _,i in ipairs({1,2,3,1,3,4})do indices[#indices+1]=b+i end
  end
 end end
 return {vertices=verts,indices=indices,depth=depth,ymin=0}
end
function P.mesh(def)
 if not P.handles(def)then return nil end
 local key=def.id..':'..def.image
 if cache[key]==nil then
  local ok,mesh=pcall(function()
   local data=require('src.render.Assets').imageData(def.image);local g=P.geometry(def,data)
   return V.require('Voxel3D').newMesh(g.vertices,g.indices)
  end)
  cache[key]=ok and mesh or false
 end
 return cache[key]or nil
end
function P.matrix(px,py,height)return V.require('Mat4').translate(px,height,py+8)end
function P.invalidate()for _,mesh in pairs(cache)do if mesh and mesh.release then mesh:release()end end;cache={}end
local ok,Assets=pcall(require,'src.render.Assets')
if ok and Assets.register then Assets.register(P.invalidate)end
return P
