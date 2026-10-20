local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/tests/')
local R=dofile(root..'/lib/RoomGeometry.lua')
for _,id in ipairs({'ROUTE_6','ROUTE_3','ROUTE_4','ROUTE_9','ROUTE_22','PEWTER_CITY','CERULEAN_CITY','VIRIDIAN_CITY','FUCHSIA_CITY'})do
 local map={id=id,tileset={id='TILESET_KANTO',imageWidth=128,imageHeight=64},widthCells=2,heightCells=2,
 tileAt=function(_,x,y)return y==1 and(x==1 and 4 or 55)or 44 end,
 isWalkableCell=function()return true end}
 assert(R.at(map,{class='ledge',h=3},55).h==4,id..' jump border is not aligned with steps')
 local cliff={class='kanto_cliff',h=16};assert(R.at(map,cliff,55)==cliff,id..' solid cliff was lowered')
 local S={skip={},ground={},objectQuads={}};R.build(S,map,function(x,y)return y*8+x end)
 assert(S.skip[9]and #S.objectQuads==16,id..' walkable gap has no four-tread staircase')
 local heights={};for _,q in ipairs(S.objectQuads)do heights[q[1][2]]=true end
 assert(heights[1]and heights[4],id..' stairs do not bridge the lip')
 assert(S.ground[9]==44,id..' stair opening retains ledge art on the ground')
end
local blocked={id='ROUTE_9',tileset={id='TILESET_KANTO'},widthCells=1,heightCells=1,
 tileAt=function()return 4 end,isWalkableCell=function()return false end}
local blockedState={skip={},ground={},objectQuads={}}
R.build(blockedState,blocked,function(x,y)return y*8+x end)
assert(#blockedState.objectQuads==0,'solid native cells became stair openings')
local claimed={skip={[0]=true},ground={},objectQuads={}}
blocked.isWalkableCell=function()return true end
R.build(claimed,blocked,function(x,y)return y*8+x end)
assert(#claimed.objectQuads==3*16,'authored claimed cells were overwritten')
local S={skip={},ground={},objectQuads={}}
R.build(S,{id='OTHER',tileset={id='TILESET_JOHTO'}},function()end)
assert(#S.objectQuads==0,'Kanto correction leaked into another tileset')
print('Kanto native access gaps: visible four treads, low borders, solid cliffs preserved PASS')
