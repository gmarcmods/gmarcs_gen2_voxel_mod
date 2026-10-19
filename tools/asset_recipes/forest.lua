-- Ilex Forest: complete sprite arrangements, with editable surface geometry.
local function s(r,o,h,d,z) return {rect=r,orientation=o,height=h,depth=d,z=z or 0} end
local tree={id='forest_tree',border=true,tiles={{12,13,14,15},{28,29,30,31},{44,45,46,47},{60,61,62,63}},
 surfaces={s({12,24,8,8},'vertical',0,8,12)},voxelEdits={}}
local sapling={id='forest_sapling',tiles={{38,39},{54,55}}}
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local nativeTree=dofile(dir..'/native_tree_shape.lua')
nativeTree(tree);nativeTree(sapling)
local cut=nativeTree({id='forest_cut_tree',tiles={{40,57},{56,58}}})
local sign={id='forest_sign',tiles={{1,6},{21,22}},surfaces={
 s({0,0,16,9},'vertical',7,2,7),s({2,9,2,7},'vertical',0,2,7),s({12,9,2,7},'vertical',0,2,7)}}
local shrine={id='forest_shrine',tiles={{16,18},{48,50},{21,22}},surfaces={
 s({0,16,16,8},'vertical',0,10),s({0,8,16,8},'vertical',6,8)}}
for x=0,15 do
 shrine.surfaces[#shrine.surfaces+1]=s({x,0,1,8},'horizontal',12+math.floor(7.5-math.abs(x-7.5)),2)
end
local function gate(id,door)
 local a={id=id,tiles={},surfaces={s({0,48,96,48},'vertical',0,40,4)}}
 for row=1,12 do
  local r={}
  for x=1,12 do
   if row==1 then r[x]=x==1 and 16 or x==12 and 18 or 17
   elseif row<6 then r[x]=x==1 and 32 or x==12 and 34 or 33
   elseif row==6 then r[x]=x==1 and 48 or x==12 and 50 or 49
   elseif row<12 then r[x]=x==1 and 35 or x==12 and 37 or 36
   else r[x]=x==1 and 51 or x==12 and 53 or 52 end
  end
  a.tiles[row]=r
 end
 for _,x in ipairs({2,3,6,7,10,11}) do a.tiles[8][x]=4 end
 if door then a.tiles[11][3]=7;a.tiles[11][4]=8;a.tiles[12][3]=23;a.tiles[12][4]=24 end
 for sy=0,47 do
  a.surfaces[#a.surfaces+1]=s({0,sy,96,1},'horizontal',48+math.floor((23.5-math.abs(sy-23.5))*.45),2,sy)
 end
 return dofile(dir..'/ilex_gate_alignment.lua')(a)
end
local ground={[40]=5,[57]=5,[56]=5,[58]=5}
for _,t in ipairs({12,13,14,15,28,29,30,31,44,45,46,47,60,61,62,63,38,39,54,55}) do ground[t]=5 end
-- Both compressed gatehouse footprints expose soil, never a flower carpet.
for _,t in ipairs({16,17,18,32,33,34,48,49,50,35,36,37,4,51,52,53,7,8,23,24}) do ground[t]=5 end
return {tilesets={TILESET_FOREST={
 classes={forest_bank={base='ledge',height=4,art='flat'}},
 pins={ground={0,2,5}, -- bare soil and speckled leaf litter stay at walking height
 flower={3}, -- blossoms above the forest floor
 water={20}, -- pond fill below its stone bank
 forest_bank={9,10,11,25,26,27,41,42,43,57,58}, -- pond rim and low rock boundaries
 },prop_ground=ground,planter_spray=false,
 assets={tree,sapling,cut,sign,shrine,gate('forest_gate_north',true),gate('forest_gate_south',false)},
}}}
