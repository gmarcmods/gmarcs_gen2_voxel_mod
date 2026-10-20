local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/tests/')
local shape={class='stair_n',art='stair',h=16}
local map={widthCells=10,heightCells=12,inBounds=function()return true end,
 warpAtCell=function()end,isWarpTileCell=function()return false end,isWalkableCell=function()return true end,
 tileAt=function()return 1 end}
local blocked=false
local V={data=function()return{}end,require=function(name)
 if name=='Structures'then return {forMap=function()return {battleBlocked=blocked and {[(8+64)*4096+8+64]=true}or{}}end}end
 if name=='TileShape'then return {forMap=function()return{}end,at=function()return shape end}end
 return {}
end}
local B=assert(loadfile(root..'/lib/BattleArena.lua'))(V)
assert(not B.openCell(map,4,4,false),'battle actor may stand inside rendered staircase')
shape={class='ground',art='flat',h=0}
assert(B.openCell(map,4,4,false),'clear native floor rejected')
blocked=true
assert(not B.openCell(map,4,4,false),'authored staircase over native floor still hides a battle actor')
print('Battle arena excludes visual stair geometry on walkable native cells PASS')
blocked=false;map.id='WILLS_ROOM';map.def={environment='INDOOR'}
assert(B.find(map,4,10,false).cam=='wide','indoor battle camera is outside the room walls')
print('Indoor battle staging uses the short wide lens inside the room PASS')
