-- Close views of native Kanto house roofs, with the companion disabled.
return function(game)
 io.stdout:setvbuf("no");print("KANTO ROOF DRIVER START")
 local function frames(n)for _=1,n do coroutine.yield()end end
 frames(60);game.stack:clear();game.input:reset();game.input.pollPads=function()end
 local V=assert(game.mods.exports.gmarcs_gen2_voxel_mod).lib
 local C,R,F,S=V.require('ChunkMesher'),V.require('Voxel3D'),V.require('FirstPerson'),V.require('VoxelScene')
 local j=game.mods.exports.gmarcs_gen2_johto_in_first_person;if j and j.runtime then j.runtime:detach()end
 local P=require('src.render.Pipelines');V.require('DayNight').setting:setIndex(2,game)
 V.require('AntiAlias').setting:setValue(0,game);love.window.setMode(800,600)
 local dir=assert(os.getenv('POKEPORT_SHOT_DIR'));local rig
 F.frame=function()R.camera=rig;return rig,rig.focus[1],rig.focus[3]end
 local patterns=dofile(V.mod.path..'/tools/asset_recipes/kanto_building_patterns.lua')
 for _,index in ipairs({6,9,18,22})do
  local a=patterns[index];local id=a.example.map
  P.setLevel('voxel',0);P.syncOptions(game.save.options);game.world.mapScenes[id]=1
  assert(game.world:setMap(id,4,7,'down')~=false);frames(3)
  game.world:applyPalettes();game.world:refreshMapImages();frames(3)
  local w,d=#a.tiles[1]*8,#a.tiles*8;local x,z=a.example.x*8+w/2,a.example.y*8+d/2
  local y=a.wallHeight or d-a.roofRows;local dist=math.max(w,d)*1.3
  rig={eye={x+dist*.6,y+dist*.65,z+dist},focus={x,y+8,z},up={0,1,0},fov=math.rad(55),curve=0}
  P.setLevel('voxel',3);P.syncOptions(game.save.options)
  for _=1,3600 do if S.prefetch(game.world)and C.pending()==0 then break end;C.pump(true);frames(1)end
  assert(C.pending()==0)
  for _,view in ipairs({'front','back'})do
   if view=='back'then rig.eye={x-dist*.6,y+dist*.65,z-dist}end
   local ctx=V.require('Gen2').worldCtx(game.world,3)
   local image=assert(S.render(ctx.state,800,600,ctx.vw,ctx.vh,ctx.paletteFor)):newImageData()
   local f=assert(io.open(dir..'/'..index..'-'..view..'.png','wb'));f:write(image:encode('png'):getString());f:close();image:release()
  end
  print('KANTO ROOF CAPTURE',index,id)
 end
 assert(#game.mods.errors==0);love.event.quit()
end
