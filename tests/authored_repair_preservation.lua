local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/tests/')
local current=dofile(root..'/data/voxel_heights.lua')
local before=assert(arg[1],'supply pre-repair profile')
before=dofile(before)
local function same(a,b)
 assert(type(a)==type(b),'field type changed')
 if type(a)~='table'then assert(a==b,'unrelated authored field changed');return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,'unexpected field')end
end
local count,roofs=0,0
for ts,list in pairs(before.buildings)do
 assert(#current.buildings[ts]==#list,'asset removed')
 for i,a in ipairs(list)do
  local b=current.buildings[ts][i];assert(a.id==b.id)
  if ts=='TILESET_KANTO'and(a.tiles[1][1]==5 or a.tiles[1][1]==76 or a.id=='kanto_west_gate'or a.id=='kanto_east_gate')and a.voxelEdits then
   same(a.tiles,b.tiles);same(a.surfaces,b.surfaces)
   if a.tiles[1][1]==5 then
    local edge,center=-math.huge,-math.huge;local w=#a.tiles[1]*8
    for _,v in ipairs(b.voxelEdits)do if not v.remove then
     if v.x==0 then edge=math.max(edge,v.y)end
     if v.x==math.floor(w/2)then center=math.max(center,v.y)end
    end end
    assert(center>edge,'pitched house still has a flat slab roof');roofs=roofs+1
   end
  elseif a.id=='mansion_filing_cabinet'then
   assert(b.surfaces[1].orientation=='horizontal'and b.surfaces[1].height==5,'bed is standing upright or floating')
   local grounded=false;for _,v in ipairs(b.voxelEdits)do grounded=grounded or v.y==0 end
   assert(grounded,'bed has no floor support');same(a.tiles,b.tiles)
  elseif a.id=='mansion_workdesk'then
   local minY,maxY=100,-100
   for _,v in ipairs(b.voxelEdits)do if not v.remove then minY=math.min(minY,v.y);maxY=math.max(maxY,v.y)end end
   assert(minY==0 and maxY==25,'desk/CRT lost its ground support or full monitor')
   same(a.tiles,b.tiles)
  else same(a,b)end
  count=count+1
 end
end
same(before.tilesets,current.tilesets);same(before.classes,current.classes)
assert(count>=441 and roofs>0)
print('Authored repair: '..count..' assets retained; unrelated assets and classes unchanged; '..roofs..' pitched roofs PASS')
