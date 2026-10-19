-- National Park and its contest layout share their original source drawings.
local function s(r,o,h,d,z) return {rect=r,orientation=o,height=h,depth=d,z=z or 0} end
local assets={};local function add(a) assets[#assets+1]=a;return a end
local function blank(id,tiles) return add({id=id,tiles=tiles,surfaces={s({0,0,1,1},'vertical',0,1)},voxelEdits={{x=0,y=0,z=0,remove=true}}}) end
local function put(a,x,y,z,i) a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=i,region=1} end
-- Park foliage occupies the first sixteen sprite rows; its lower half is
-- trunk/ground, unlike Ilex's taller leaf drawing. Keep that art off the crown.
local tree=blank('park_tree',{{12,13,14,15},{28,29,30,31},{44,45,46,47},{60,61,62,63}});tree.border=true
local recipeDir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
dofile(recipeDir..'/native_tree_shape.lua')(tree)
local bench=add({id='park_bench',tiles={{7,8,9,10},{23,24,25,26},{39,40,41,42}},surfaces={
 s({0,0,32,8},'vertical',7,2),s({0,8,32,8},'horizontal',5,2,2)},voxelEdits={}})
-- The source's bottom row supplies the four metal feet, leaving air below.
for _,x0 in ipairs({2,27}) do for _,z0 in ipairs({2,7}) do for x=x0,x0+2 do for z=z0,z0+1 do for y=0,4 do put(bench,x,y,z,17*32+x) end end end end end
blank('park_bin',{{90,91},{19,95}})
add({id='park_sign',tiles={{69,70},{85,86}},surfaces={s({0,0,16,12},'vertical',4,2,7),s({2,12,2,4},'vertical',0,2,7),s({12,12,2,4},'vertical',0,2,7)}})
local fence=blank('park_fence_north',{{35,36},{51,52}})
for x=0,15 do for y=0,15 do local q=((x-7.5)/6)^2+((y-9)/6)^2
 if y<3 or (q<=1 and q>.55) or (x==2 or x==13) and y<10 then for z=6,8 do put(fence,x,y,z,(15-y)*16+x) end end
end end
local south=blank('park_fence_south',{{37,38},{53,54}})
for _,v in ipairs(fence.voxelEdits) do if not v.remove then put(south,v.x,v.y,v.z,v.i) end end
local side=blank('park_fence_side',{{5}})
for x=2,5 do for z=0,7 do for y=0,9 do if y<3 or y>=7 or z<2 or z>=6 then put(side,x,y,z,math.min(7,y)*8+x) end end end end
-- Side ornament tiles are narrow uprights, never full-height wall blocks.
for _,t in ipairs({27,67,83}) do add({id='park_fence_detail_'..t,tiles={{t}},surfaces={s({2,0,4,8},'vertical',3,2,3)}}) end
-- Raised flower beds keep the flowers above a low timber rim.
add({id='park_flowerbed',tiles={{55,56,56,56,56,56,56,56,56,56,56,56,56,56,56,56,56,56,56,57},{71,3,1,3,3,3,1,3,3,3,1,3,3,3,1,3,1,3,3,73},{71,3,3,3,3,1,3,3,3,1,3,3,3,1,3,3,3,1,3,73},{87,88,88,88,88,88,88,88,88,88,88,88,88,88,88,88,88,88,88,89}},surfaces={s({0,0,160,32},'horizontal',0,4)}})
-- Both boundary gatehouses have the same complete 12x12-tile pattern.
local grid={};for row=1,12 do grid[row]={};for x=1,12 do
 local l,m,r;if row==1 then l,m,r=16,17,18 elseif row<6 then l,m,r=32,33,34 elseif row==6 then l,m,r=48,49,50 elseif row<12 then l,m,r=64,65,66 else l,m,r=80,81,82 end
 grid[row][x]=x==1 and l or x==12 and r or m
end end
blank('park_gatehouse',grid)
local fountain=blank('park_fountain',{{76,77,78},{92,93,94}})
for x=0,23 do for z=0,15 do local q=((x-11.5)/12)^2+((z-7.5)/8)^2
 if q<=1 then for y=0,3 do put(fountain,x,y,z,z*24+x) end end
 if q>.65 and q<=1 then for y=4,6 do put(fountain,x,y,z,12*24+x) end end
 if q<.08 then for y=4,16 do put(fountain,x,y,z,4*24+12) end end
end end
local repair=dofile(recipeDir..'/park_repairs.lua')
for _,a in ipairs(assets)do repair(a)end
local ground={};for _,a in ipairs(assets) do for _,r in ipairs(a.tiles) do for _,t in ipairs(r) do ground[t]=a==tree and 1 or 0 end end end
return {tilesets={TILESET_PARK={assets=assets,planter_spray=false,prop_ground=ground,
 classes={park_bank={base='ledge',height=2,art='flat'}},pins={
 ground={0,1,2,6,22,43,79}, -- lawns, sand, paths, gate carpet and existing ground shadows
 grass={4,58,59,74,75}, -- normal and tall encounter grass remain traversable
 water={20},park_bank={21}, -- stone pond edging is a low continuous curb
 flower={3}, -- small planted flower patches retain their original colors
 }}}}
