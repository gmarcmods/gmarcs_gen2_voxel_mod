-- Lighthouse stonework and the Fast Ship share this source tileset.
local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local P=dofile(root..'/historic_primitives.lua');local s=P.s;local assets={}
local function add(a) assets[#assets+1]=a;return a end
local bed=add({id='lighthouse_bed',tiles={{70,71},{86,87},{86,87},{59,60}},surfaces={
 s({0,0,16,8},'vertical',4,2),s({0,8,16,16},'horizontal',4,2,2),s({0,24,16,8},'vertical',0,2,18)},voxelEdits={}})
for _,x in ipairs({1,12}) do P.box(bed,x,0,1,3,4,2,x) end
local tableRows={{9,10,10,12},{25,26,44,28},{25,64,65,28},{25,80,81,28},{20,44,44,53},{11,59,60,11}}
add(P.table('lighthouse_table',tableRows))
add(P.table('ship_small_table',{{9,10,10,12},{20,26,44,53},{59,60,59,60}}))
add(P.table('ship_writing_table',{{9,10,10,10,10,12},{25,44,68,69,44,28},{20,44,44,44,44,53},{59,60,11,11,59,60}}))
-- Larger mess tables keep their entire serving pattern and four grounded legs.
add(P.table('ship_dining_table',{{9,10,10,12},{25,26,44,28},{20,44,44,53},{11,59,60,11}}))
add(P.table('ship_medium_table',{{9,10,10,12},{25,26,44,28},{25,64,65,28},{25,80,81,28},{25,44,26,28},{25,44,44,28},{20,44,44,53},{11,59,60,11}}))
local long={{9,10,10,12},{25,26,44,28},{25,64,65,28},{25,80,81,28},{25,44,26,28},{25,44,44,28},{25,64,65,28},{25,80,81,28},{20,44,44,53},{11,59,60,11}}
add(P.table('ship_mess_table',long))
add(P.cabinet('ship_cabinet',{{19,62},{54,43},{54,43},{59,60}},8,10))
local chair=add(P.blank('ship_chair',{{7,8},{23,24}}))
P.box(chair,3,4,3,10,2,8,function(x,y,z)return math.min(9,z)*16+x end)
P.box(chair,3,6,1,10,6,2,function(x,y,z)return (11-y)*16+x end)
for _,x in ipairs({3,11}) do for _,z in ipairs({3,9}) do P.box(chair,x,0,z,2,4,2,13*16+x) end end
local captain=add(P.blank('ship_captains_chair',{{84,85},{66,67},{23,24}}))
P.box(captain,2,6,1,12,10,2,function(x,y,z)return math.max(0,15-y)*16+x end)
P.box(captain,2,4,3,12,2,10,function(x,y,z)return (8+math.min(7,z-3))*16+x end)
for _,x in ipairs({2,12}) do for _,z in ipairs({2,11}) do P.box(captain,x,0,z,2,4,2,16*16+x) end end
-- The porthole is part of the continuous ship wall, with glass one voxel inset.
add(P.cabinet('ship_terminal',{{2,3},{45,61},{82,83},{92,93}},8,10))
local port=add({id='ship_porthole',tiles={{2,3},{18,18}},surfaces={s({0,0,16,16},'vertical',0,16)},voxelEdits={}})
for x=5,10 do for y=6,11 do if (x-7.5)^2+(y-8.5)^2<9 then port.voxelEdits[#port.voxelEdits+1]={x=x,y=y,z=15,remove=true} end end end
add({id='ship_porthole_strip',tiles={{2,3}},surfaces={s({0,0,16,8},'vertical',8,16)}})
add({id='ship_round_door',tiles={{14,15},{30,31}},surfaces={s({0,0,16,16},'vertical',0,12)}})
local bin=add(P.blank('ship_waste_bin',{{72,73},{88,89}}))
for y=0,12 do for x=0,15 do for z=0,15 do local r=(x-7.5)^2+(z-7.5)^2
 if r<=36 and (y==0 or r>=20) then P.put(bin,x,y,z,math.min(15,15-y)*16+x) end
end end end
-- Moss and windows belong to the drawn face. Repeating that face through
-- the full thickness painted green algae and blue glass onto every flank.
local function stonePanel(id,tiles,window)
 local a=add(P.blank(id,tiles))
 a.topRows={{74,75},{94,95}} -- plain stone artwork, independent of the moss palette
 for x=0,15 do for y=0,15 do for z=0,15 do
  if x==0 or x==15 or y==0 or y==15 or z==0 or z==15 then
   local face=z==15 and y<15 and x>0 and x<15
   local i=face and ((31-y)*16+x)
     or ((15-y)*16+(z%8)+(x>=8 and 8 or 0))
   local glass=window and face and y>=9 and y<=14
   P.put(a,x,y,glass and 14 or z,i)
  end
 end end end
 return a
end
stonePanel('lighthouse_window',{{78,78},{76,77}},true)
stonePanel('lighthouse_moss_course',{{90,91},{76,77}})
-- Whole furniture patterns claim before their reusable component sprites.
for i,a in ipairs(assets) do a._order=i end
table.sort(assets,function(a,b) local aa,bb=#a.tiles*#a.tiles[1],#b.tiles*#b.tiles[1];return aa==bb and a._order<b._order or aa>bb end)
for _,a in ipairs(assets) do a._order=nil end
return {tilesets={TILESET_LIGHTHOUSE={assets=assets,planter_spray=false,
 classes={lighthouse_wall={base='wall',height=16,art='flat'}},
 pins={ground={0,4,13,27,29,35,36,46,47,52,63}, -- deck, carpets, stone floor and thresholds
 void={1}, -- stairwell shafts and unused cabin space
 lighthouse_wall={5,6,16,17,18,21,22,32,33,34,37,38,48,49,50,51,74,75,76,77,78,90,91,94,95},
 stair_e={41,42,57,58}, -- silver flight rises toward its east landing
 stair_down_w={39,40,55,56}, -- dark flight descends west into the shaft
 },
 prop_ground={[7]=13,[8]=13,[23]=13,[24]=13},
}}}
