-- Actual update/input loop: D-pad forward must follow the visible camera.
return function(game)
 io.stdout:setvbuf('no');game.speedOverride=1
 local function frames(n)for i=1,n do coroutine.yield()end end
 local V=assert(game.mods.exports.gmarcs_gen2_voxel_mod).lib
 local F,S=V.require('FirstPerson'),V.require('VoxelState')
 local P=require('src.render.Pipelines');local Input=require('src.core.Input');local w=game.world
 w.mapScenes.ROUTE_17=1;w:setMap('ROUTE_17',7,40,'down');w.pendingSceneScript=false
 local map=w.map;local sx,sy
 for y=2,map.heightCells-3 do for x=2,map.widthCells-3 do
  local open=true
  for dy=-1,1 do for dx=-1,1 do
   if map:cellCollision(x+dx,y+dy)~=0 or w:npcAt(x+dx,y+dy) then open=false end
  end end
  if open then sx,sy=x,y;break end
 end if sx then break end end
 assert(sx,'need a clear non-forced 3x3 patch for movement test')
 local p=w.player;local cases=0
 w.playerState=require('src.world.gen2.FieldMoves').PLAYER_BIKE;game.save.onBike=true
 assert(w:downhill(),'Cycling Road native downhill flag missing')
 for _,level in ipairs({S.FP_LEVEL,S.TP_LEVEL})do
  P.setLevel('voxel',level);P.syncOptions(game.save.options);frames(40)
  assert(F.driving(w),'camera-relative movement gate is closed in free camera')
  for _,yaw in ipairs({0,math.pi/4,math.pi/2,math.pi,-math.pi/2,-math.pi/4})do
   p.moving=false;p.turnTimer=0;p.turnArmed=false;p.bumpFrames=nil;p.voxelFreeWalk=nil
   p.cellX,p.cellY=sx,sy;p.px,p.py=sx*16,sy*16
   V.require('FreeMove').drop();F.yaw=yaw;frames(1)
   local x,y=p.px,p.py;local lx,lz=F.lookFlat()
   Input:overlayPressed('up');frames(6);Input:overlayReleased('up')
   local dx,dz=p.px-x,p.py-y
   assert(dx*lx+dz*lz>0,'forward did not follow camera bearing')
   assert(math.abs(dx*lz-dz*lx)<.001,'D-pad up moved along game north instead of camera forward')
   assert(not p.moving,'free camera unexpectedly fell back to a native grid step')
   cases=cases+1
  end
 end
 -- Coasting is south in world space; braking stops it at any heading.
 p.moving=false;p.px,p.py=sx*16,sy*16;p.cellX,p.cellY=sx,sy
 V.require('FreeMove').drop();F.yaw=math.pi/2
 local x,z=p.px,p.py;frames(4)
 assert(p.py>z and math.abs(p.px-x)<.001,'native bike did not coast south on Cycling Road')
 Input:overlayPressed('b');frames(1);x,z=p.px,p.py;frames(4)
 assert(p.px==x and p.py==z,'B did not brake downhill drift')
 Input:overlayReleased('b')
 -- A menu must still own input; angled mode must keep the native grid walk.
 game.stack:push({});assert(not F.driving(w),'menu must block free camera movement');game.stack:pop()
 P.setLevel('voxel',3);P.syncOptions(game.save.options);frames(10)
 p.moving=false;p.turnTimer=0;p.turnArmed=false;p.facing='up'
 Input:overlayPressed('up');frames(2);Input:overlayReleased('up')
 assert(p.moving,'angled mode must retain the native grid walk')
 print('CYCLING CAMERA RELATIVE LIVE PASS',cases,'first/third-person D-pad headings, menu gate and native grid fallback')
 love.event.quit()
end
