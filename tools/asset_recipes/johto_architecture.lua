-- Authored planes and shells replace the automatic per-column roof folding.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local patterns=dofile(dir..'/johto_building_patterns.lua')
local towers=dofile(dir..'/johto_tower_patterns.lua')
local windows=dofile(dir..'/johto_windows.lua')
local backs=dofile(dir..'/building_backs.lua')
local out={}
local function new(id,tiles)
 local a={id=id,tiles=tiles,surfaces={{rect={0,0,1,1},orientation='vertical',height=0,depth=1,z=0}},voxelEdits={{x=0,y=0,z=0,remove=true}}}
 out[#out+1]=a;return a
end
local function put(a,x,y,z,i) a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=i,region=1} end
local function tex(a,id,x,y)
 local W=#a.tiles[1]*8
 for r,row in ipairs(a.tiles) do for c,t in ipairs(row) do if t==id then return ((r-1)*8+y%8)*W+(c-1)*8+x%8 end end end
 return 0
end
local function ordinary(p)
 local a=new(p.id,p.tiles);local W,H=#a.tiles[1]*8,#a.tiles*8;local h=H-p.roofRows
 local doors={}
 for c,t in ipairs(a.tiles[#a.tiles-1]) do if t==55 or t==39 then doors[#doors+1]=(c-1)*8 end end
 local function recessed(x,y) for _,d in ipairs(doors) do if x>=d+2 and x<d+14 and y<14 then return true end end end
 for y=0,h-1 do
  local sy=H-1-y
  for x=0,W-1 do
   put(a,x,y,recessed(x,y) and H-4 or H-1,sy*W+x)
   put(a,x,y,0,math.min(H-1,p.roofRows+4)*W+x)
  end
  for z=1,H-2 do
   local sx=8+z%8
   put(a,0,y,z,sy*W+sx);put(a,W-1,y,z,sy*W+sx)
  end
 end
 for _,d in ipairs(doors) do for z=H-4,H-2 do
  for y=0,13 do put(a,d+1,y,z,(H-1-y)*W+d+1);put(a,d+14,y,z,(H-1-y)*W+d+14) end
  for x=d+2,d+13 do put(a,x,14,z,(H-15)*W+x) end
 end end
 -- Three-pixel eave, one continuous level roof. The texture preserves the
 -- source roof drawing; no neighbouring column can bend it into a wave.
 for x=0,W-1 do for z=p.roofBack or 0,H-1 do
  local sy=math.min(p.roofRows-1,math.floor(z/H*p.roofRows))
  local i=p.roofSource or sy*W+x
  if p.roofBorder and (x==0 or x==W-1 or z==(p.roofBack or 0) or z==H-1) then i=p.roofBorder end
  put(a,x,h,z,i)
  put(a,x,h+1,z,i)
  put(a,x,h+2,z,i)
 end end
 windows(a,H-1)
 backs(a,p.roofRows)
 return a
end
local function pagoda(id,tiles,levels,burned)
 local a=new(id,tiles);local W,H=#tiles[1]*8,#tiles*8
 local inset=burned and 8 or 0;local front=H-1-(burned and 8 or 0);local back=front-39
 local wood=function(x,y) return tex(a,82,x,y) end
 local wall=function(x,y) return tex(a,27,x,y) end
 local doorX=burned and 24 or 16;local eave=burned and 8 or 12
 for level=0,levels-1 do
  -- Each Gold exterior floor is a real-height storey. The broad eaves occupy
  -- the last four voxels, leaving a solid 24px wall instead of a thin shelf.
  local base=level*28;local trim=math.min(level*2,16)
  local left,right=inset+6+trim,W-inset-7-trim
  local z0,z1=back+trim,front-trim
  local center=math.floor((left+right)/2)
  for y=0,23 do
   for x=left,right do
    -- Restrained timber framing: corner columns and one central post support
    -- broad plaster panels; a repeated 12px lattice made the intact tower
    -- read like an open scaffold from the map camera.
    local beam=y<2 or y>=22 or x-left<2 or right-x<2
      or math.abs(x-center)<=1
    local i=beam and wood(x,y) or wall(x,y)
    local door=level==0 and x>=doorX+2 and x<doorX+14 and y<14
    if door then
     local tile=x<doorX+8 and (y<8 and 41 or 39) or (y<8 and 42 or 40)
     i=tex(a,tile,x-doorX,15-y)
    end
    -- Broken upper-storey wall openings expose structural posts.
    local brokenOpening=burned and level==levels-1
      and x>left+8 and x<right-8 and y>6
    if not brokenOpening then
     put(a,x,base+y,door and z1-3 or z1,i)
     put(a,x,base+y,z0,i)
    end
   end
   for z=z0+1,z1-1 do
    local beam=y<2 or y>=22 or math.abs(z-math.floor((z0+z1)/2))<=1
    local i=beam and wood(z,y) or wall(z,y)
    if not (burned and level==levels-1 and z>z0+8 and z<z1-8 and y>6) then
     put(a,left,base+y,z,i);put(a,right,base+y,z,i)
    end
   end
  end
  if level==0 then for z=z1-3,z1-1 do for y=0,14 do
   put(a,doorX+1,y,z,wood(1,y));put(a,doorX+14,y,z,wood(1,y))
  end end end
  -- Four stepped roof courses make the eaves broad and legible at distance.
  -- The upper courses draw inward toward the next storey like a pagoda roof.
  for course=0,3 do
   local overhang=math.max(2,eave-course*2)
   for x=left-overhang,right+overhang do for z=z0-overhang,z1+overhang do
    local cx= x>center-7 and x<center+7
    local cz= z>z0+8 and z<z1-8
    local broken=burned and level==levels-1 and cx and cz
    if not broken then
     put(a,x,base+24+course,z,wood(x,z))
    end
   end end
  end
  -- Balustrade on upper galleries: open below its rail, with corner posts.
  if level>0 and not (burned and level==levels-1) then
   for x=left,right do put(a,x,base+6,z1+3,wood(x,2)) end
   for x=left,right,8 do for y=0,6 do put(a,x,base+y,z1+3,wood(1,y)) end end
  end
 end
 local top=levels*28
 if burned then
  -- Unequal surviving rafters, visibly open at the damaged roof centre.
  for _,x in ipairs({inset+16,W-inset-17}) do for y=top-8,top+12 do put(a,x,y,front-18,wood(1,y)) end end
  for x=inset+16,W-inset-17 do put(a,x,top+6,front-18,wood(x,2)) end
  a.keep={0,5,6,43,44,45,54,59,60,61,75,76,77}
 else
  -- Compact ridge cap and a stepped finial make the tower readable at a distance.
  local cx=math.floor(W/2);local cz=math.floor((front+back)/2)
  for z=cz-10,cz+10 do for x=cx-2,cx+2 do for y=top+2,top+4 do put(a,x,y,z,wood(x,y)) end end end
  for y=top+5,top+16 do put(a,cx,y,cz,wood(1,y));put(a,cx+1,y,cz,wood(1,y)) end
 end
 return a
end
pagoda('johto_tin_tower',towers.tin,9,false)
pagoda('johto_burned_tower',towers.burned,3,true)
-- Sprout Tower uses the same small original tower drawing as Burned Tower,
-- but the latter's unique surrounding footprint takes precedence above.
pagoda('johto_sprout_tower',patterns[6].tiles,3,false)
for _,p in ipairs(patterns) do
 if p.id~='johto_building_6' and p.id~='johto_building_14' and p.id~='johto_building_5' then ordinary(p) end
end
-- Mahogany's northern exit house has only its facade in the map. Its
-- roof extends north without requiring nonexistent roof tiles to match.
-- Use the dark door-frame texel for the missing, plain roof surface.
ordinary({id='johto_mahogany_north_house',roofRows=0,roofBack=-16,roofSource=18*64+18,roofBorder=17*64+18,
 tiles={{26,27,27,27,27,27,27,28},{26,27,27,27,27,38,38,28},
 {26,27,55,56,27,27,27,28},{1,2,57,58,2,2,2,22}}})
-- Dragon's Den: a low shrine on a stone plinth, a veranda with timber posts,
-- a clear recessed entrance and a shallow, single-plane overhanging roof.
local shrine=new('johto_dragon_shrine',patterns[5].tiles)
local W,H=64,64
for x=0,63 do for z=24,63 do for y=0,3 do put(shrine,x,y,z,tex(shrine,82,x,y)) end end end
for y=4,35 do
 for x=6,57 do
  local opening=x>=24 and x<=39 and y<24
  put(shrine,x,y,opening and 51 or 55,opening and tex(shrine,82,3,3) or tex(shrine,27,x,y))
  put(shrine,x,y,28,tex(shrine,27,x,y))
 end
 for z=29,54 do put(shrine,6,y,z,tex(shrine,27,z,y));put(shrine,57,y,z,tex(shrine,27,z,y)) end
end
for _,x in ipairs({4,20,43,59}) do for y=4,37 do for z=58,60 do put(shrine,x,y,z,tex(shrine,65,2,y)) end end end
for x=-3,66 do for z=20,66 do put(shrine,x,38,z,tex(shrine,83,x,z));put(shrine,x,39,z,tex(shrine,83,x,z)) end end
for x=27,36 do for z=28,58 do put(shrine,x,40,z,tex(shrine,82,x,z)) end end
for _,a in ipairs(dofile(dir..'/route_gate.lua').tilesets.TILESET_JOHTO.assets) do out[#out+1]=a end
return out
