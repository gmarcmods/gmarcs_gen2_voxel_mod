-- Native access openings, with the presentation companion detached.
return function(game)
 io.stdout:setvbuf('no')
 local function frames(n)for _=1,n do coroutine.yield()end end
 frames(60);game.stack:clear();game.input:reset();game.input.pollPads=function()end
 local V=assert(game.mods.exports.gmarcs_gen2_voxel_mod).lib
 local C,R,F,S=V.require('ChunkMesher'),V.require('Voxel3D'),V.require('FirstPerson'),V.require('VoxelScene')
 local j=game.mods.exports.gmarcs_gen2_johto_in_first_person;if j and j.runtime then j.runtime:detach()end
 local P=require('src.render.Pipelines');V.require('DayNight').setting:setIndex(2,game)
 V.require('AntiAlias').setting:setValue(0,game);love.window.setMode(800,600)
 local dir=assert(os.getenv('POKEPORT_SHOT_DIR'));local rig
 F.frame=function()R.camera=rig;return rig,rig.focus[1],rig.focus[3]end
 local G=V.require('RoomGeometry');local Map=require('src.world.gen2.Map')
 local total,maps=0,0
 for id,def in pairs(game.world.maps)do if def.tileset=='TILESET_KANTO'then
  local m=Map.new(def,game.world.tilesets[def.tileset]);local expected=0
  for y=0,m.heightCells*2-1 do for x=0,m.widthCells*2-1 do
   if m:tileAt(x,y)==4 then
    assert(m:isWalkableCell(math.floor(x/2),math.floor(y/2)),id..' gap is not walkable')
    expected=expected+1
   end
  end end
  local state={skip={},ground={},objectQuads={}};G.build(state,m,function(x,y)return y*1024+x end)
  assert(#state.objectQuads==expected*16,id..' missing native access steps')
  if expected>0 then total=total+expected;maps=maps+1;print('NATIVE KANTO STEPS',id,expected)end
 end end
 assert(maps>=21 and total>=120,'native survey lost coverage')
 print('KANTO ACCESS COVERAGE PASS',maps,total)
 for _,id in ipairs({'ROUTE_6','ROUTE_3','ROUTE_4','ROUTE_9','ROUTE_22','PEWTER_CITY','CERULEAN_CITY','VIRIDIAN_CITY'})do
  P.setLevel('voxel',0);P.syncOptions(game.save.options);game.world.mapScenes[id]=1
  assert(game.world:setMap(id,4,7,'down')~=false);frames(3)
  game.world:applyPalettes();game.world:refreshMapImages();frames(3)
  local m=game.world.map;local x,z
  for y=0,m.heightCells*2-1 do for tx=0,m.widthCells*2-1 do if not x and m:tileAt(tx,y)==4 then x,z=tx*8+8,y*8+4 end end end
  assert(x,'missing fixture '..id)
  rig={eye={x+28,30,z+45},focus={x,1,z},up={0,1,0},fov=math.rad(55),curve=0}
  P.setLevel('voxel',3);P.syncOptions(game.save.options)
  for _=1,3600 do if S.prefetch(game.world)and C.pending()==0 then break end;C.pump(true);frames(1)end
  assert(C.pending()==0)
  for _,view in ipairs({'angled','eye'})do
   if view=='eye'then rig.eye={x+14,16,z+30}end
   local ctx=V.require('Gen2').worldCtx(game.world,3)
   local image=assert(S.render(ctx.state,800,600,ctx.vw,ctx.vh,ctx.paletteFor)):newImageData()
   local f=assert(io.open(dir..'/'..id..'-'..view..'.png','wb'));f:write(image:encode('png'):getString());f:close();image:release()
  end
  print('KANTO ACCESS CAPTURE',id)
 end
 assert(#game.mods.errors==0);love.event.quit()
end
