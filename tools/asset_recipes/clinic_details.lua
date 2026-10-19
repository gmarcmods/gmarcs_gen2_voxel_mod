-- Complete Elm's furniture from its actual map tiles, retaining other assets.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local H=dofile(dir..'/public_interior_shapes.lua');local s=H.s
local computer={id='lab_computer_desk',tiles={{10,11,12,13},{26,27,28,29},{37,38,38,39}},surfaces={
 -- A thick CRT at the left, tower at the right, and a horizontal keyboard.
 s({0,0,14,3},'horizontal',21,1,0),
 s({0,3,14,10},'vertical',11,9,0),
 s({0,13,14,3},'horizontal',10,1,8),
 s({14,0,18,4},'horizontal',18,1,0),
 s({14,4,18,12},'vertical',6,11,0),
 s({0,16,32,3},'horizontal',6,2,0),
 s({0,19,32,2},'vertical',4,14,0)},voxelEdits={}}
-- Recess the glass, without removing the monitor's outer frame.
for x=3,10 do for y=14,18 do for z=7,8 do computer.voxelEdits[#computer.voxelEdits+1]={x=x,y=y,z=z,remove=true}end end end
-- Reuse the two source desk feet at all four corners; omit the floor gap.
for _,x0 in ipairs({1,27})do for _,z0 in ipairs({1,11})do
 for x=x0,x0+3 do for z=z0,z0+1 do for y=0,3 do H.put(computer,x,y,z,(23-y)*32+x)end end end
end end
local bin=H.blank('lab_paper_bin',{{14,15},{30,31}})
for x=0,15 do for z=0,15 do
 local r=math.sqrt((x-7.5)^2+(z-7.5)^2)
 for y=0,9 do
  local radius=4.6+y*.12
  if r<=radius and (r>=radius-1.3 or y==0)then H.put(bin,x,y,z,(14-math.floor(y*.5))*16+math.max(3,math.min(12,x)))end
 end
 if r>=4.8 and r<=6.7 then for y=10,11 do H.put(bin,x,y,z,3*16+math.max(3,math.min(12,x)))end end
end end
local machine=H.blank('lab_healing_machine',{{66,67,68,69},{82,83,84,85},{70,71,71,73},{86,87,88,89}})
for x=0,31 do for z=0,13 do for y=0,31 do
 local inset=math.max(0,y-28)
 if x>=inset and x<32-inset and (x<5 or x>26 or y>23 or y<5 or z<3)then
  H.put(machine,x,y,z,(31-y)*32+x)
 end
end end end
for x=2,29 do for z=14,23 do for y=0,5 do H.put(machine,x,y,z,(26+math.floor((z-14)*6/10))*32+x)end end end
local ground={};for _,a in ipairs({computer,bin,machine})do for _,r in ipairs(a.tiles)do for _,tile in ipairs(r)do ground[tile]=16 end end end
return {tilesets={TILESET_LAB={assets={computer,bin,machine},prop_ground=ground}}}
