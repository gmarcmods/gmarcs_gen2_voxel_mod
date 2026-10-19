return function(game)
 io.stdout:setvbuf('no');local function frames(n)for _=1,n do coroutine.yield()end end;frames(60)
 local V=assert(game.mods.exports.gmarcs_gen2_voxel_mod).lib;local C,R,F,Scene=V.require('ChunkMesher'),V.require('Voxel3D'),V.require('FirstPerson'),V.require('VoxelScene')
 local companion=game.mods.exports.gmarcs_gen2_johto_in_first_person;if companion and companion.runtime then companion.runtime:detach()end
 local P=require('src.render.Pipelines');V.require('DayNight').setting:setIndex(2,game);V.require('AntiAlias').setting:setValue(0,game);love.window.setMode(800,600)
 local out=os.getenv('POKEPORT_SHOT_DIR')or V.mod.path..'/dist/tower-audit';os.execute('mkdir -p '..require('src.core.HostShell').quote(out))
 local log=assert(io.open(out..'/audit.txt','w'))
 local function line(...)local row={}for i=1,select('#',...)do row[i]=tostring(select(i,...))end;log:write(table.concat(row,'\t')..'\n');log:flush()end
 local function png(data,name)local f=assert(io.open(out..'/'..name..'.png','wb'));assert(f:write(data:encode('png'):getString()));assert(f:close());data:release()end
 local function tex(image,name)local g=love.graphics;local c=g.newCanvas(image:getDimensions());g.push('all');c:renderTo(function()g.origin();g.setShader();g.setColor(1,1,1,1);g.clear();g.draw(image)end);g.pop();png(c:newImageData(),name);c:release()end
 local rig;F.frame=function()R.camera=rig;return rig,rig.focus[1],rig.focus[3]end
 local Sel=dofile(V.mod.path..'/tools/ObjectSelection.lua');local profile=V.data('voxel_heights')
 for _,id in ipairs({'TIN_TOWER_3F','TIN_TOWER_4F','TIN_TOWER_5F'})do
  P.setLevel('voxel',0);P.syncOptions(game.save.options);game.world.mapScenes[id]=1;game.world:setMap(id,4,7,'down');assert(game.world.map.id==id);frames(2)
  local map=game.world.map
  local T=V.require('TileShape');local shapes=T.forMap(map);local ramps=V.require('TinTowerInterior')
  local count=0
  for y=0,map.heightCells*2-1 do for x=0,map.widthCells*2-1 do
   local tile=map:tileAt(x,y)
   if tile==27 then assert(T.at(map,shapes,tile,x,y).h==-32,'loaded renderer still raises the pit')end
   if ramps.rampAt(map,x,y)then count=count+1 end
  end end
  assert(count>0,'native jump ramps missing')
  line('RAMPS',id,count)
  local w,h=map.def.width*32,map.def.height*32
  rig={eye={w/2,h*.9,h*1.2},focus={w/2,0,h/2},up={0,1,0},fov=math.rad(50),curve=0}
  P.setLevel('voxel',3);P.syncOptions(game.save.options)
  for _=1,3600 do if Scene.prefetch(game.world)and C.pending()==0 then break end;C.pump(true);frames(1)end
  assert(C.pending()==0);line('MAP',id,map.tileset.id,w,h)
  tex(game.world.mapImage,id..'-flat');tex(V.require('Gen2').goldAtlas(game.world,map),id..'-atlas')
  for y=0,map.def.height*4-1 do local row={}for x=0,map.def.width*4-1 do row[#row+1]=map:tileAt(x,y)end;line('TILES',y,table.concat(row,','))end
  local structure=V.require('Structures').forMap(map)
  for _,a in ipairs(profile.buildings[map.tileset.id]or{})do for _,p in ipairs(Sel.placements(map,a.tiles))do
   line('ASSET',a.id,p.x,p.y,p.w,p.h)
   if a.id=='tower_stairs_up'or a.id=='tower_stairs_down'or a.id=='traditional_tower_stairs_down'then
    for y=p.y,p.y+p.h-1 do for x=p.x,p.x+p.w-1 do
     local key=(y+64)*4096+x+64
     assert(structure.skip[key]and structure.shapeAt[key].authored,'whole stair flight did not replace native tile chunks')
     if a.cutFloor then assert(structure.ground[key]==nil,'synthesized floor hides the descending stair flight')end
    end end
   end
  end end
  for y=0,map.heightCells-1 do local row={}for x=0,map.widthCells-1 do row[#row+1]=map:cellCollision(x,y)end;line('COLL',y,table.concat(row,','))end
  local ctx=V.require('Gen2').worldCtx(game.world,3)
  for _,view in ipairs({'overview','north','south','ramp-first','ramp-third'})do
   if view=='north'then rig={eye={w/2,36,h*.6},focus={w/2,18,32},up={0,1,0},fov=math.rad(65),curve=0}
   elseif view=='south'then rig={eye={w/2,36,h*.3},focus={w/2,12,h-32},up={0,1,0},fov=math.rad(65),curve=0}
   elseif view=='ramp-first'then rig={eye={132,14,40},focus={170,0,40},up={0,1,0},fov=math.rad(65),curve=0}
   elseif view=='ramp-third'then rig={eye={106,36,65},focus={152,0,40},up={0,1,0},fov=math.rad(65),curve=0}end
   local canvas=assert(Scene.render(ctx.state,800,600,ctx.vw,ctx.vh,ctx.paletteFor));png(canvas:newImageData(),id..'-'..view)
  end
  print('TOWER AUDIT',id)
 end
 log:close();print('TIN TOWER JUMP VISUAL PASS');love.event.quit()
end
