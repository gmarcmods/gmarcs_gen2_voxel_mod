local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/tests/')or'.'
local W=assert(loadfile(root..'/lib/WaterAnimation.lua'))({})
love={timer={getTime=function()return 1 end}}
assert(W.frame({tileset={generation=2}})==60,'Gen 2 waves need a live clock without Gen 1 renderer ticks')
love.timer.getTime=function()return 2 end
assert(W.frame({tileset={generation=2}})==120)
local assets={imageData=function()return{}end}
local module=assert(loadfile(root..'/lib/WaterAnimation.lua'))
setfenv(module,setmetatable({require=function()return assets end},{__index=_G}))
W=module({})
love.image={newImageData=function()return{paste=function()end}end}
local world={animTimer=0,tilesets={waterFrames='native-water'},waterFrameFor=function(t)return({1,2,3,4,1,2,3,4})[t+1]end}
W.bind(world)
local ts={generation=2,anim={frames={{func='AnimateWaterTile',tile=20}}}}
local specs=W.specs(ts);assert(#specs==1 and specs[1].tile==20 and #specs[1].frameData==4)
world.animTimer=3;assert(W.phase(specs[1])==3,'atlas uses the native Gen 2 water-frame mapping')
assert(#W.specs({generation=2,anim={frames={}}})==0,'dry tilesets must not acquire water')
print('Gen 2 water: moving wave clock, native source frames/phase, dry tilesets preserved PASS')

world.map={tileset={generation=2}}
local modules={WaterAnimation=W,TerrainAtlas={_animFrame=function()return 0 end},
 ModSetting={new=function()return{}end},Sky={},DayNight={},ShadowMap={},Mat4=dofile(root..'/lib/Mat4.lua')}
local water=assert(loadfile(root..'/lib/Water.lua'))({require=function(n)return assert(modules[n],n)end})
local first=water._waveTime();love.timer.getTime=function()return 3 end
assert(water._waveTime()>first,'actual wave shader clock must advance when Gen 1 tile clock is frozen')
print('Water shader: Gen 2 wave phase advances independently of frozen Gen 1 counter PASS')

local extra={generation=2,anim={frames={
 {func='AnimateWhirlpoolTile',tile=48,sheet='swirl',frames=4},
 {func='AnimateLavaBubbleTile1',tile=56,sheet='lava',frames=4},
 {func='AnimateTowerPillarTile',tile=46,sheet='pillar',frames=5},
 {func='WriteTileFromAnimBuffer',tile=23,scroll={v=1}}}}}
world.animRow=function(_,layer)return layer.kind=='tower'and 5 or 3 end
local all=W.specs(extra);local by={};for _,spec in ipairs(all)do by[spec.tile]=spec end
assert(by[48]and by[56]and by[46]and by[23],'native whirlpool/lava/pillar/waterfall animations missing')
assert(W.phase(by[46])==4 and W.phase(by[48])==2,'native animation phase mapping was lost')
assert(by[23].kind=='scroll'and by[23].scroll.v==1,'waterfall must scroll vertically')
print('Native whirlpool, lava, pillar and waterfall animation routing PASS')
