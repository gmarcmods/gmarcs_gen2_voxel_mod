return function(game)
 io.stdout:setvbuf('no')
 local function frames(n)for _=1,n do coroutine.yield()end end
 frames(60);game.stack:clear();game.input:reset();game.input.pollPads=function()end
 local V=assert(game.mods.exports.gmarcs_gen2_voxel_mod).lib
 local C,R,F,Scene=V.require('ChunkMesher'),V.require('Voxel3D'),V.require('FirstPerson'),V.require('VoxelScene')
 local companion=game.mods.exports.gmarcs_gen2_johto_in_first_person
 if companion and companion.runtime then companion.runtime:detach()end
 local P=require('src.render.Pipelines');V.require('DayNight').setting:setIndex(2,game)
 V.require('AntiAlias').setting:setValue(0,game);love.window.setMode(800,600)
 local out=assert(os.getenv('POKEPORT_SHOT_DIR'))
 local log=assert(io.open(out..'/audit.txt','w'))
 local function png(data,name)local f=assert(io.open(out..'/'..name..'.png','wb'));f:write(data:encode('png'):getString());f:close();data:release()end
 local function tex(image,name)
  local g=love.graphics;local c=g.newCanvas(image:getDimensions());g.push('all')
  c:renderTo(function()g.origin();g.setShader();g.setColor(1,1,1,1);g.clear();g.draw(image)end)
  g.pop();png(c:newImageData(),name);c:release()
 end
 local rig;F.frame=function()R.camera=rig;return rig,rig.focus[1],rig.focus[3]end
 local ids={'TOHJO_FALLS','MOUNT_MORTAR_1F_OUTSIDE','WILLS_ROOM','KOGAS_ROOM','BRUNOS_ROOM','KARENS_ROOM','LANCES_ROOM','BLACKTHORN_GYM_1F','TIN_TOWER_9F','TIN_TOWER_ROOF','ROUTE_6','ROUTE_16','ROUTE_17','SILPH_CO_1F','CELADON_MANSION_1F','CELADON_MANSION_2F','CELADON_MANSION_3F','CELADON_MANSION_ROOF_HOUSE','VERMILION_CITY','SAFFRON_CITY','ROUTE_41'}
 local selected=os.getenv('VOXEL_AUDIT_MAPS');if selected then ids={};for id in selected:gmatch('[^,]+')do ids[#ids+1]=id end end
 local Sel=dofile(V.mod.path..'/tools/ObjectSelection.lua');local profile=V.data('voxel_heights')
 for _,id in ipairs(ids)do
  P.setLevel('voxel',0);P.syncOptions(game.save.options);game.world.mapScenes[id]=1
  assert(game.world:setMap(id,4,7,'down')~=false,id);frames(3)
  local m=game.world.map
  game.world.flashUsed=true;game.world:applyPalettes();game.world:refreshMapImages();frames(3)
  local w,h=m.widthCells*16,m.heightCells*16
  rig={eye={w/2,math.max(w,h)*.8,h*1.25},focus={w/2,0,h/2},up={0,1,0},fov=math.rad(55),curve=0}
  P.setLevel('voxel',3);P.syncOptions(game.save.options)
  for _=1,3600 do if Scene.prefetch(game.world)and C.pending()==0 then break end;C.pump(true);frames(1)end
  assert(C.pending()==0,'meshing '..id)
  if id=='TIN_TOWER_ROOF'then local T=V.require('TileShape');assert(T.at(m,T.forMap(m),80,18,4).h==48,'walking ridge is below the roof')end
  if id:match('ROOM$')then
   local arena=V.require('GoldBattle').arenaFor(game.world,false,true)
   assert(arena,'no safe battle arena '..id)
   for _,cell in ipairs({arena.playerCell,arena.enemyCell})do assert(V.require('BattleArena').openCell(m,cell[1],cell[2],false),'battle actor on stairs')end
   print('BATTLE FLOOR PASS',id,arena.playerCell[1],arena.playerCell[2],arena.enemyCell[1],arena.enemyCell[2])
  end
  tex(game.world.mapImage,id..'-flat');tex(V.require('Gen2').goldAtlas(game.world,m),id..'-atlas')
  log:write('MAP ',id,' ',m.tileset.id,'\n')
  local T=V.require('TileShape');local shapes=T.forMap(m)
  for y=0,m.heightCells*2-1 do
   local row={};for x=0,m.widthCells*2-1 do local tile=m:tileAt(x,y);local s=T.at(m,shapes,tile,x,y);row[#row+1]=tile..':'..s.h end
   log:write('ROW ',y,' ',table.concat(row,','),'\n')
  end
  for _,a in ipairs(profile.buildings[m.tileset.id]or{})do for _,p in ipairs(Sel.placements(m,a.tiles))do
   log:write('ASSET ',a.id,' ',p.x,',',p.y,' ',p.w,'x',p.h,'\n')
  end end
  for _,view in ipairs({'overview','north','south'})do
   if view=='north'then rig={eye={w/2,24,h*.75},focus={w/2,16,h*.2},up={0,1,0},fov=math.rad(72),curve=0}
   elseif view=='south'then rig={eye={w/2,24,h*.25},focus={w/2,16,h*.8},up={0,1,0},fov=math.rad(72),curve=0}end
   local ctx=V.require('Gen2').worldCtx(game.world,3)
   png(assert(Scene.render(ctx.state,800,600,ctx.vw,ctx.vh,ctx.paletteFor)):newImageData(),id..'-'..view)
  end
  if id=='VERMILION_CITY'then
   local found
   for _,npc in ipairs(game.world.npcs or{})do if npc.bigObject and npc.sprite and npc.sprite.def.id=='SPRITE_BIG_SNORLAX'then
    print('SNORLAX DEFINITION',npc.sprite.def.id,npc.sprite.def.image,npc.sprite.def.frames,npc.px,npc.py,V.require('VoxelScene').groundAt(m,npc.cellX,npc.cellY))
    tex(npc.sprite:resolveImage(),'snorlax-live-sheet')
    found=true;local x,z=npc.px+16,npc.py+16
    rig={eye={x+50,40,z+78},focus={x,14,z},up={0,1,0},fov=math.rad(55),curve=0}
    local ctx=V.require('Gen2').worldCtx(game.world,3)
    png(assert(Scene.render(ctx.state,800,600,ctx.vw,ctx.vh,ctx.paletteFor)):newImageData(),'snorlax-complete')
   end end
   assert(found,'native Snorlax absent from visual fixture')
  end
  local A=V.require('WaterAnimation');local specs=A.specs(m.tileset)
  for _,spec in ipairs(specs)do log:write('ANIM ',spec.tile,' ',spec.kind,' ',A.phase(spec),'\n')end
  if #specs>0 then
   local function pixels()
    local img=V.require('Gen2').goldAtlas(game.world,m);local g=love.graphics
    local c=g.newCanvas(img:getDimensions());g.push('all')
    c:renderTo(function()g.origin();g.setShader();g.setColor(1,1,1,1);g.clear();g.draw(img)end);g.pop()
    local data=c:newImageData();local bytes=data:getString();data:release();c:release();return bytes
   end
   local saved=game.world.animTimer;game.world.animTimer=0;local first=pixels();local changed=false
   for timer=1,7 do game.world.animTimer=timer;if pixels()~=first then changed=true;break end end
   game.world.animTimer=saved
   assert(changed,'GPU atlas animation stayed frozen in '..id)
   print('GPU ATLAS ANIMATION PASS',id,#specs)
  end
  log:flush();print('TERRAIN AUDIT',id)
 end
 log:close();assert(#game.mods.errors==0,'mod errors');love.event.quit()
end
