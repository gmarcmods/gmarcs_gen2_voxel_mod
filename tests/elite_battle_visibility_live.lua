return function(game)
 io.stdout:setvbuf('no')
 local function frames(n)for _=1,n do coroutine.yield()end end
 local function tap()game.input.pressQueue[#game.input.pressQueue+1]='a';frames(3)end
 frames(60);game.stack:clear();game.input:reset();game.input.pollPads=function()end
 local V=assert(game.mods.exports.gmarcs_gen2_voxel_mod).lib
 local B=V.require('GoldBattle');local C=V.require('ChunkMesher')
 local Mon=require('src.battle.gen2.Mon');local Trainers=require('src.world.gen2.Trainers')
 local P=require('src.render.Pipelines');local w=game.world
 local out=assert(os.getenv('POKEPORT_SHOT_DIR'));love.window.setMode(960,540)
 local function shot(name)
  game.capturePath=out..'/'..name..'.png'
  for _=1,120 do if not game.capturePath then return end;frames(1)end;error('capture '..name)
 end
 for _,row in ipairs({{'WILLS_ROOM','WILL'},{'KOGAS_ROOM','KOGA'},{'BRUNOS_ROOM','BRUNO'},{'KARENS_ROOM','KAREN'},{'LANCES_ROOM','CHAMPION'}})do
  game.stack:clear();P.setLevel('voxel',0);P.syncOptions(game.save.options)
  w.mapScenes[row[1]]=1;assert(w:setMap(row[1],4,10,'up'));frames(10)
  game.save.party={Mon.new(game.data,'TYPHLOSION',80)}
  P.setLevel('voxel',7);P.syncOptions(game.save.options)
  for _=1,2400 do if V.require('VoxelScene').prefetch(w)and C.pending()==0 then break end;C.pump(true);frames(1)end
  local index=assert(game.data.trainers.classes[row[2]],row[2]).index
  local trainer=assert(w:trainerParty(index,1));trainer.party=Trainers.party(game.data,trainer)
  B.setting:setValue(true,game);assert(w:startBattle({trainer=trainer}))
  local state
  for _=1,1200 do local top=game.stack:top();if top and top.battle then state=top;break end;frames(1)end
  assert(state,'battle did not open')
  for _=1,300 do if state.showEnemyTrainer and(not state.slideFrame or state.slideFrame>=72)then break end;tap()end
  assert(state.showEnemyTrainer,'native trainer never appeared');frames(3);shot(row[1]..'-trainer')
  for _=1,600 do if state.phase=='menu'then break end;tap()end
  assert(state.phase=='menu','battle menu not reached');frames(15)
  assert(B.active()==state and B.lastShot(state).enemy,'enemy did not enter 3D battle')
  local arena=assert(B.arenaFor(w,false,true))
  local structure=V.require('Structures').forMap(w.map)
  for _,cell in ipairs({arena.playerCell,arena.enemyCell})do
   for dy=0,1 do for dx=0,1 do
    assert(not(structure.battleBlocked or{})[(cell[2]*2+dy+64)*4096+cell[1]*2+dx+64],'battle actor inside authored staircase')
   end end
  end
  shot(row[1]..'-pokemon')
  print('ELITE NATIVE BATTLE VISIBLE',game.save.version,row[1],arena.enemyCell[1],arena.enemyCell[2])
  state.battle.outcome='run';state:finishBattle()
  for _=1,500 do if not w.battleActive then break end;frames(1)end
  assert(not w.battleActive,'battle did not exit');frames(10)
 end
 assert(#game.mods.errors==0,'mod errors');love.event.quit()
end
