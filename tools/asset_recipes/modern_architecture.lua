-- Modern buildings use their own atlas, including metalwork and brick facades.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local patterns=dofile(dir..'/modern_building_patterns.lua')
local special=dofile(dir..'/modern_special_patterns.lua')
local windows=dofile(dir..'/johto_windows.lua')
local backs=dofile(dir..'/building_backs.lua')
local out={}
local function new(id,tiles)
 local a={id=id,tiles=tiles,surfaces={{rect={0,0,1,1},orientation='vertical',height=0,depth=1}},voxelEdits={{x=0,y=0,z=0,remove=true}}}
 out[#out+1]=a;return a
end
local function put(a,x,y,z,i) a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=i,region=1} end
local function tex(a,id,x,y)
 local W=#a.tiles[1]*8
 for r,row in ipairs(a.tiles) do for c,t in ipairs(row) do if t==id then return ((r-1)*8+y%8)*W+(c-1)*8+x%8 end end end
 error('missing source tile '..id..' for '..a.id)
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
-- The drawing contains the tall broadcast shaft, lower annex and a small
-- neighbouring house. Keep the house's texels available to its own asset.
local radio=new('modern_radio_tower',special.radio.tiles)
radio.keep={6,16,17,18,10,11,12,26,27,28,1,2,22}
local function shaft(x0,x1,top)
 for y=0,top-1 do
  for x=x0,x1 do
   local door=x>=16 and x<32 and y<24
   put(radio,x,y,door and 187 or 191,(191-y)*64+x)
   put(radio,x,y,160,tex(radio,29,x,y))
  end
  for z=161,190 do
   put(radio,x0,y,z,tex(radio,29,z,y));put(radio,x1,y,z,tex(radio,33,z,y))
  end
 end
 for x=x0,x1 do for z=160,191 do
  put(radio,x,top,z,tex(radio,29,x,z))
 end end
end
shaft(0,31,176);shaft(32,63,80)
for _,p in ipairs({{16,184},{48,88}}) do
 for x=p[1]-8,p[1]+7 do for y=p[2]-8,p[2]+7 do for z=168,183 do
  if ((x-p[1]+.5)/8)^2+((y-p[2]+.5)/8)^2+((z-175.5)/8)^2<=1 then
   put(radio,x,y,z,tex(radio,86,x,y))
  end
 end end end
 for y=p[2]+8,p[2]+24 do put(radio,p[1],y,176,tex(radio,80,1,y)) end
 for x=p[1]-6,p[1]+6 do put(radio,x,p[2]+17,176,tex(radio,33,x,2)) end
end
windows(radio,191)
for _,p in ipairs(patterns) do
 if p.id=='modern_building_12' then p.id='modern_department_store' end
 ordinary(p)
end
ordinary({id='modern_north_house',tiles=special.north_house.tiles,roofRows=0,roofBack=-16,roofSource=18*64+18,roofBorder=17*64+18})
for _,side in ipairs({'west_gate','east_gate'}) do ordinary({id='modern_'..side,tiles=special[side].tiles,roofRows=32}) end
-- Slowpoke Well: a stone arch with a recessed dark passage and open mouth.
local well=new('modern_slowpoke_well',special.well.tiles)
for x=0,47 do for z=8,31 do for y=0,31 do
 local outer=y<=18+13*math.sqrt(1-((x-23.5)/24)^2)
 local passage=x>=16 and x<32 and y<18
 if outer and not passage and (x<16 or x>=32 or y>=18) then
  local sy=31-y
  local i=z==31 and sy*48+x or tex(well,x<24 and 41 or 42,z,y)
  if y>=18 and z<31 then i=tex(well,41,x,z) end
  put(well,x,y,z,i)
 end
end end end
for x=16,31 do for y=0,17 do put(well,x,y,8,tex(well,53,0,0)) end end
for x=16,31 do for z=9,31 do put(well,x,0,z,tex(well,53,0,0)) end end
local repair=dofile(dir..'/azalea_repairs.lua')
for _,a in ipairs(out)do repair(a)end
local radioDetails=dofile(dir..'/radio_details.lua')
for _,a in ipairs(out)do radioDetails.repair(a)end
return out
