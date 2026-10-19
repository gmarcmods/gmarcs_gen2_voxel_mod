-- Lower service worktops and anchor projected sprites to their occupied cell.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')
local H=dofile(dir..'/public_interior_shapes.lua')
local counters={center_counter_return=0,pokecenter_counter=0,pokecenter_ball_counter=0,pokecenter_counter_edge=8,center_short_counter_edge=8,mart_counter=0,mart_counter_end=0}
return function(a)
 local z0=counters[a.id]
 if z0 then
  local W,Ht=#a.tiles[1]*8,#a.tiles*8
  if a.id=='mart_counter'then a.tiles={{62,63},{62,63}};Ht=16 end
  a.surfaces={{rect={0,0,1,1},orientation='vertical',height=0,depth=1,z=0}}
  a.voxelEdits={{x=0,y=0,z=0,remove=true}}
  for x=0,W-1 do for z=0,15 do for y=0,6 do
   -- Native top band wraps onto the worktop; front preserves the blue/wood trim.
   local sy=y==6 and math.floor(z/2) or math.max(0,Ht-1-y)
   H.put(a,x,y,z0+z,sy*W+x)
  end end end
 elseif a.id=='center_computer'then
  for _,s in ipairs(a.surfaces)do s.z=(s.z or 0)+8 end
  for _,e in ipairs(a.voxelEdits)do e.z=e.z+8 end
  a.surfaces[4].depth=16
  -- Four short feet support the cabinet; no long runners projecting forward.
  local edits={}
  for _,e in ipairs(a.voxelEdits)do if e.remove or e.y>3 then edits[#edits+1]=e end end
  a.voxelEdits=edits
  for _,x0 in ipairs({1,12})do for _,z0 in ipairs({8,21})do
   for x=x0,x0+2 do for z=z0,z0+2 do for y=0,3 do H.put(a,x,y,z,23*16+x)end end end
  end end
 elseif a.id=='mart_register'then
  for _,s in ipairs(a.surfaces)do s.height=math.max(0,s.height-3)end
  for _,e in ipairs(a.voxelEdits)do e.y=math.min(e.y,6)end
 elseif a.id=='ruins_statue'then
  local rows={
   '......#..#......','.....##..##.....','.....##..##.....','.....######.....',
   '....########....','...##########...','..############..','..############..',
   '...##########...','...##########...','....########....','....########....',
   '.....######.....','.....######.....','....########....','...##########...',
  }
  a.surfaces={{rect={0,0,1,1},orientation='vertical',height=0,depth=1,z=0}}
  a.voxelEdits={{x=0,y=0,z=0,remove=true}}
  for sy=0,31 do
   local row=rows[sy+1]or(sy==31 and '..############..'or'...##########...')
   for x=0,15 do if row:sub(x+1,x+1)=='#'then
    local radius=sy<16 and 6 or 7
    local chord=sy<16 and math.max(1,math.floor(radius*math.sqrt(math.max(0,1-((x-7.5)/7.5)^2))))or radius
    for z=math.max(16,24-chord),math.min(31,23+chord)do H.put(a,x,31-sy,z,sy*16+x)end
   end end
  end
 end
 return a
end
