local root=arg[1]or'mods/gen2/new_mod_ex'
local loads,finds=0,0
local ready=false
local bundled={apiVersion=2,capabilities={contract='national-dex-battle-sprites'},
 status=function()return {ready=ready,reason='not imported'}end,
 frame=function()return {image='imported-BW',width=40,height=48}end}
local V={mod={find=function()finds=finds+1;return nil end}}
V.require=function(name)
 if name=='ModSetting'then return {new=function(_,_,values,labels)
  return {get=function()return 'gen5_bw'end,values=values,labels=labels}
 end}end
 assert(name=='ImportedBattleSprites');loads=loads+1;return bundled
end
local B=assert(loadfile(root..'/lib/BattleSprites.lua'))(V)
assert(loads==0,'native module loading must not open imported packs')
assert(B.unavailableReason():find('Black / White',1,true),'missing import should be explained')
assert(loads==1 and finds==0,'engine import must not require a separate mod')
ready=true;assert(B.unavailableReason()==nil,'imported pack must be detected')
local state={game={data={pokemon={PIKACHU={dex=25}}}},activeMon=function()return {species='PIKACHU'}end}
assert(B.frame(state,'enemy').image=='imported-BW','standalone voxel mod must use imported sprites')
assert(loads==1 and finds==0,'provider must be reused without companion lookup')
print('BUNDLED BATTLE SPRITES PASS')
