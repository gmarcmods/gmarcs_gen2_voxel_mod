-- Native healing timeline; cached solid balls fixed to the horizontal tray.
local V=...
local F={}
local placements=setmetatable({},{__mode='k'})
local grid={{28,29,30,31},{44,45,46,47},{60,61,61,63},{76,77,78,79}}
function F.slots(map)
 if not(map and map.tileset and map.tileset.id=='TILESET_POKECENTER')then return nil end
 if placements[map]~=nil then return placements[map]or nil end
 for y=0,map.def.height*4-4 do for x=0,map.def.width*4-4 do
  local matches=true
  for r,row in ipairs(grid)do for c,t in ipairs(row)do
   if map:tileAt(x+c-1,y+r-1)~=t then matches=false;break end
  end;if not matches then break end end
  if matches then
   local slots={}
   for _,z in ipairs({10,18,26})do for _,sx in ipairs({9,22})do
    slots[#slots+1]={x=x*8+sx+.5,y=10,z=y*8+z+.5}
   end end
   placements[map]=slots;return slots
  end
 end end
 placements[map]=false
end
local faces={
 {1,0,0,.8,{{1,0,0},{1,1,0},{1,1,1},{1,0,1}}},
 {-1,0,0,.8,{{0,0,1},{0,1,1},{0,1,0},{0,0,0}}},
 {0,1,0,1,{{0,1,0},{0,1,1},{1,1,1},{1,1,0}}},
 {0,-1,0,.6,{{0,0,1},{0,0,0},{1,0,0},{1,0,1}}},
 {0,0,1,.92,{{1,0,1},{1,1,1},{0,1,1},{0,0,1}}},
 {0,0,-1,.92,{{0,0,0},{0,1,0},{1,1,0},{1,0,0}}}}
function F.geometry()
 local cells,occupied={},{}
 local function key(x,y,z)return x..','..y..','..z end
 for x=-3,2 do for y=0,5 do for z=-3,2 do
  if (x+.5)^2+(y-2.5)^2+(z+.5)^2<=9 then
   cells[#cells+1]={x,y,z};occupied[key(x,y,z)]=true
  end
 end end end
 local vertices,indices={},{}
 for _,c in ipairs(cells)do for _,f in ipairs(faces)do
  if not occupied[key(c[1]+f[1],c[2]+f[2],c[3]+f[3])]then
   local n=#vertices
   -- Native ball tile occupies the right half of the 16x8 FX sheet.
   -- The native icon is offset inside its tile; sampling the unused margin
   -- would put a white cap over the ball. Use its red, belt and white texels.
   local u,v=13.5/16,4.5/8
   if c[2]==2 then u,v=10.5/16,5.5/8
   elseif c[2]<2 then u,v=8.5/16,.5/8 end
   for _,q in ipairs(f[5])do vertices[#vertices+1]={c[1]+q[1],c[2]+q[2],c[3]+q[3],u,v,f[4]}end
   for _,i in ipairs({1,2,3,1,3,4})do indices[#indices+1]=n+i end
  end
 end end
 return {vertices=vertices,indices=indices}
end
local mesh,source,paletteKey
local textures={}
local function texture(world)
 local Assets=require('src.render.Assets')
 local Palette=require('src.render.GbcPalette')
 local gfx=world.game.data.gen2MenuGfx
 local spec=gfx and gfx.healMachine
 if not spec then return nil end
 local colors=Palette.resolve(world.healMachinePalette)
 if not colors then return nil end
 local key=spec.sheet..':'..Palette.mode
 for _,c in ipairs(colors)do key=key..':'..table.concat(c,',')end
 if paletteKey~=key then
  for _,img in pairs(textures)do img:release()end
  textures={};source=Assets.imageData(spec.sheet);paletteKey=key
 end
 local rotation=world.healAnim.rotation or 0
 if not textures[rotation]then
  local iw,ih=source:getDimensions();local out=love.image.newImageData(iw,ih)
  for y=0,ih-1 do for x=0,iw-1 do
   local r,_,_,a=source:getPixel(x,y)
   local shade=math.max(0,math.min(3,math.floor((1-r)*3+.5)))
   local c=colors[(shade+rotation)%4+1]
   -- Solid geometry owns the silhouette, including the native white cap.
   out:setPixel(x,y,c[1]/255,c[2]/255,c[3]/255,1)
  end end
  local img=love.graphics.newImage(out);out:release();img:setFilter('nearest','nearest')
  textures[rotation]=img
 end
 return textures[rotation]
end
function F.draw(world)
 local ha=world.healAnim
 if not ha or ha.hof or not world.healMachineImage then return end
 local slots=F.slots(world.map)
 if not slots or (ha.lit or 0)==0 then return end
 local tex=texture(world);if not tex then return end
 local renderer=V.require('Voxel3D')
 if not mesh then local g=F.geometry();mesh=renderer.newMesh(g.vertices,g.indices)end
 local Mat4=V.require('Mat4')
 for i=1,math.min(ha.lit,#slots)do
  local p=slots[i];renderer.draw(mesh,tex,Mat4.translate(p.x,p.y,p.z))
 end
end
return F
