-- Authored from the installed Gold sprites and actual map grids, not from
-- atlas adjacency. Every recipe uses the editor's normal surfaces/voxel edits.
local function surface(rect,orientation,height,depth,z)
  return {rect=rect,orientation=orientation,height=height,depth=depth,z=z or 0}
end
local function cabinet(id,tiles,top,depth)
  local W,H=#tiles[1]*8,#tiles*8
  return {id=id,tiles=tiles,surfaces={
    surface({0,0,W,top},'horizontal',H-top,1,0),
    surface({0,top,W,H-top},'vertical',0,depth,0)},voxelEdits={}}
end
local function healingMachine(id,tiles)
  local a=cabinet(id,tiles,8,8)
  -- Recess the dark treatment chamber behind the frame, preserving every
  -- source texel; no silhouette detection can turn its sides into towers.
  for x=6,25 do for sy=12,25 do for z=6,7 do
    a.voxelEdits[#a.voxelEdits+1]={x=x,y=31-sy,z=z,remove=true}
  end end end
  return a
end
-- Tables repeat their two drawn front legs at the rear, retaining source
-- texels. The source floor below/between the legs never becomes geometry.
local function tableAsset(id,tiles,top,apron,legX,legW,legRows)
  local W=#tiles[1]*8
  local a={id=id,tiles=tiles,surfaces={surface({0,0,W,top},'horizontal',apron+legRows,1),
    surface({0,top,W,apron},'vertical',legRows,top)},voxelEdits={}}
  for _,x0 in ipairs(legX) do
    local region=#a.surfaces+1
    a.surfaces[region]=surface({x0,top+apron,legW,legRows},'vertical',0,2,top-2)
    for x=x0,x0+legW-1 do for y=0,legRows-1 do for z=0,1 do
      local corner=y==0 and (x==x0 or x==x0+legW-1)
      if corner then a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=top-2+z,remove=true}
      else a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=(top+apron+legRows-1-y)*W+x,region=region} end
    end end end
  end
  return a
end
local labTable=tableAsset('lab_worktable',{{5,6,6,6,6,7},{21,22,22,22,22,23},{37,38,38,38,38,39}},16,3,{1,41},6,3)
labTable.support=7 -- the three starter balls sit on the authored tabletop
local bed={id='players_room_bed',tiles={{3,4},{19,20},{35,36},{51,52}},surfaces={
  surface({0,0,16,8},'vertical',4,2,0), -- headboard stands behind the pillow
  surface({0,8,16,16},'horizontal',4,2,2), -- mattress/pillow lie down
  surface({0,24,16,8},'vertical',0,2,18)},voxelEdits={}}
for _,x0 in ipairs({0,14}) do for x=x0,x0+1 do for y=0,3 do for z=0,1 do
  bed.voxelEdits[#bed.voxelEdits+1]={x=x,y=y,z=z,i=x,region=1}
end end end end
local bookcase=cabinet('players_room_bookcase',{{5,6},{21,22},{37,38},{53,54}},8,8)
-- Two shelves are inset a voxel behind the face frame.
for _,band in ipairs({{10,13},{18,21}}) do for sy=band[1],band[2] do for x=3,12 do
  bookcase.voxelEdits[#bookcase.voxelEdits+1]={x=x,y=31-sy,z=7,remove=true}
end end end
local computer={id='players_room_computer',tiles={{11,12},{27,28},{43,44}},surfaces={
  surface({0,0,16,4},'horizontal',14,1,0),
  surface({0,4,16,12},'vertical',2,6,0),
  surface({0,16,16,5},'horizontal',2,1,6),
  surface({0,21,16,3},'vertical',0,12,0)}}
local stool={id='house_stool',tiles={{2,3},{18,19}},surfaces={},voxelEdits={}}
-- The stool's seat is a rounded top, bounded by its drawn silhouette. Thin
-- strips keep the floor outside the outline out of the voxel model.
for row,span in ipairs({{6,4},{4,8},{3,10},{2,12},{2,12},{2,12},{2,12},{3,10}}) do
  stool.surfaces[#stool.surfaces+1]=surface({span[1],row+1,span[2],1},'horizontal',4,2,row-1)
end
stool.surfaces[#stool.surfaces+1]=surface({4,10,8,2},'vertical',2,8)
for _,x0 in ipairs({3,10}) do
  local region=#stool.surfaces+1
  stool.surfaces[region]=surface({x0,12,3,2},'vertical',0,2,6)
  for x=x0,x0+2 do for y=0,1 do for z=0,1 do
    stool.voxelEdits[#stool.voxelEdits+1]={x=x,y=y,z=z,i=(13-y)*16+x,region=region}
  end end end
end
local centerSeat={id='center_seat',tiles={{72,73},{88,89}},surfaces={
  surface({0,0,16,10},'horizontal',4,2),
  surface({0,10,16,3},'vertical',1,10),
  surface({1,13,4,3},'vertical',0,2,8),surface({11,13,4,3},'vertical',0,2,8)},voxelEdits={}}
for _,x0 in ipairs({1,11}) do for x=x0,x0+3 do for y=0,2 do for z=0,1 do
  centerSeat.voxelEdits[#centerSeat.voxelEdits+1]={x=x,y=y,z=z,i=(15-y)*16+x,region=3}
end end end end
local commonStool={id='common_house_stool',tiles={{2,3},{18,19}},surfaces={},voxelEdits={}}
for row,span in ipairs({{5,6},{3,10},{2,12},{2,12},{2,12},{2,12}}) do
  commonStool.surfaces[#commonStool.surfaces+1]=surface({span[1],row+4,span[2],1},'horizontal',4,2,row-1)
end
commonStool.surfaces[#commonStool.surfaces+1]=surface({2,11,12,1},'vertical',3,6)
for _,x0 in ipairs({2,11}) do
  local region=#commonStool.surfaces+1
  commonStool.surfaces[region]=surface({x0,12,3,4},'vertical',0,2,4)
  for x=x0,x0+2 do for y=0,3 do for z=0,1 do
    commonStool.voxelEdits[#commonStool.voxelEdits+1]={x=x,y=y,z=z,i=(15-y)*16+x,region=region}
  end end end
end
return {tilesets={
  TILESET_PLAYERS_ROOM={assets={bed,bookcase,computer}},
  TILESET_PLAYERS_HOUSE={pins={ground={1},wall={17}},assets={
    stool,
    tableAsset('house_dining_table',{{35,34,34,36},{37,21,21,53},{37,21,21,53},{51,50,50,52},{28,64,64,29}},32,2,{1,26},5,4),
    cabinet('house_fridge',{{10,11},{26,27},{42,43}},4,8),
    -- The stove/hob and sink are drawn from above; their lower rows are doors.
    cabinet('house_stove',{{80,81},{82,83}},8,8),
    cabinet('house_sink',{{67,69},{24,25}},8,8),
  }},
  TILESET_HOUSE={pins={ground={1},wall={0},
    -- Full potted-plant drawings: use the existing planter revolve/mask,
    -- which leaves their floor background empty rather than extruding it.
    planter={10,11,8,9,26,27,24,25}},assets={
    commonStool,
    tableAsset('common_house_table',{{38,39,39,41},{54,47,47,57},{5,47,47,21},{60,58,58,59}},24,3,{0,26},6,4),
    cabinet('house_bookshelf',{{50,51},{48,49},{14,15},{60,59}},4,8),
    cabinet('house_cabinet',{{50,51},{14,15},{14,15},{30,31}},4,8),
    cabinet('common_house_tv',{{6,7},{22,23},{30,31}},4,6),
    cabinet('common_house_radio',{{12,13},{28,29},{30,31}},4,6),
  }},
  TILESET_LAB={pins={ground={16},wall={1,17}},assets={
    labTable,
    cabinet('lab_bookcase',{{5,7},{3,4},{3,4},{19,20}},8,8),
    healingMachine('lab_healing_machine',{{66,67,68,69},{82,83,84,85},{70,71,71,73},{86,87,88,89}}),
  }},
  TILESET_MART={pins={ground={72},
    -- Register, countertop runs and corner turns are one low service desk.
    counter={17,42,43,62,63,32,33,48,49,30,47,26,25},
    backrest={38,39,54,55,40,41,56,57}},assets={
    cabinet('mart_shelf',{{12,13},{80,81},{80,81},{94,95}},8,8),
    cabinet('mart_glass_cabinet',{{12,13},{86,87},{88,89},{90,91}},8,8),
    cabinet('mart_display',{{64,65,66,43},{80,81,82,69},{67,68,92,93},{83,84,31,85}},8,8),
  }},
  TILESET_POKECENTER={pins={ground={1,17},wall={2},
    -- Beige/blue desk and its vertical return; not room-height walls.
    counter={3,15,19,37,53,70,71,52,36,12}},assets={
    centerSeat,
    {id='center_counter_return',tiles={{15},{15}},surfaces={
      surface({0,0,8,16},'horizontal',0,8)}},
    cabinet('center_computer',{{32,33},{48,49},{64,65}},4,6),
    cabinet('center_storage_unit',{{4,5},{20,21},{10,11},{26,27}},8,8),
    healingMachine('center_healing_machine',{{28,29,30,31},{44,45,46,47},{60,61,61,63},{76,77,78,79}}),
  }},
}}
