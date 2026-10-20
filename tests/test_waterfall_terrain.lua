local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/tests/')
local W=assert(loadfile(root..'/lib/WaterfallTerrain.lua'))()
local map={widthCells=3,heightCells=5,tileset={generation=2},
 cellCollision=function(_,x,y)return x==1 and(y==1 or y==2)and 0x33 or 0 end,
 isWaterCell=function(_,x,y)return x==1 end,tileAt=function()return 64 end}
local water={class='water',h=-2,art='flat'}
local source=W.at(map,water,2,0);local top=W.at(map,water,2,2);local bottom=W.at(map,water,2,5)
assert(source.h==46 and top.h>bottom.h and bottom.h>water.h,'waterfall lacks a real upper reservoir and vertical drop')
assert(top.base=='wall'and top.sideTile==64,'fall faces must use the animated waterfall texels')
assert(W.at(map,water,2,8)==water,'lower pond was raised')
print('Waterfall upper basin, cascading elevation, animated side material and low landing PASS')
local island={widthCells=7,heightCells=7,tileset={generation=2},
 cellCollision=function(_,x,y)return x==3 and(y==3 or y==4)and 0x33 or 0 end,
 isWaterCell=function(_,x,y)return(y==1 or y==2)and x>=2 and x<=4 and not(x==3 and y==1)or x==3 and y>=3 end,
 isWalkableCell=function(_,x,y)return x==3 and y==1 end,tileAt=function()return 20 end}
assert(W.at(island,{class='ground',h=0},6,2).h==48,'upper basin island drops below its surrounding water')
print('Land enclosed by the upper reservoir shares its elevation PASS')
