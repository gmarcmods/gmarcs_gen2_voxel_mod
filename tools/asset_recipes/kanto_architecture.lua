-- Kanto's facades, doors and roof atlas differ from both Johto sheets.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local patterns=dofile(dir..'/kanto_building_patterns.lua')
local out={}
local names={ [1]='kanto_department_store',[20]='kanto_lavender_radio',
 [22]='kanto_pewter_museum',[24]='kanto_power_plant',[25]='kanto_league_gate',[30]='kanto_silph_co'}
local function put(a,x,y,z,i,remove) a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=i,region=1,remove=remove} end
for n,p in ipairs(patterns) do
 local a={id=names[n] or p.id,tiles=p.tiles,surfaces={{rect={0,0,1,1},orientation='vertical',depth=1}},voxelEdits={{x=0,y=0,z=0,remove=true}}}
 out[#out+1]=a
 if p.claimOnly then
  a.claimOnly=true;a.surfaces=nil;a.voxelEdits=nil
 else
 local W,H=#a.tiles[1]*8,#a.tiles*8;local h=p.wallHeight or H-p.roofRows
 local doors={};for c,t in ipairs(a.tiles[#a.tiles-1]) do if t==11 then doors[#doors+1]=(c-1)*8 end end
 local function door(x,y) for _,d in ipairs(doors) do if x>=d+2 and x<d+14 and y<14 then return true end end end
 for y=0,h-1 do
  local sy=y<H and H-1-y or (H-1-y)%16
  for x=0,W-1 do
   local tile=a.tiles[math.floor(sy/8)+1][math.floor(x/8)+1]
   local pane=y>=H and (tile==10 or tile==50) and x%8>=1 and x%8<=6 and sy%8>=1 and sy%8<=6
   put(a,x,y,door(x,y) and H-4 or pane and H-2 or H-1,sy*W+x)
   if y>=H and (tile==10 or tile==50) and sy%8==7 then put(a,x,y,H,sy*W+x) end
   put(a,x,y,0,math.min(H-1,p.roofRows+4)*W+x)
  end
  for z=1,H-2 do
   local i=sy*W+8+z%8;put(a,0,y,z,i);put(a,W-1,y,z,i)
  end
 end
 for _,d in ipairs(doors) do for z=H-4,H-2 do
  for y=0,13 do put(a,d+1,y,z,(H-1-y)*W+d+1);put(a,d+14,y,z,(H-1-y)*W+d+14) end
  for x=d+2,d+13 do put(a,x,14,z,(H-15)*W+x) end
 end end
 local back=p.roofRows==0 and -32 or 0
 -- Hollow shells keep large buildings editable without storing invisible
 -- solid roof layers. The top and three-pixel fascia form a level deck.
 for x=0,W-1 do for z=back,H-1 do
  local sy=math.min(p.roofRows-1,math.floor(z/H*p.roofRows))
  local i=p.roofRows==0 and 1 or sy*W+x
  put(a,x,h+2,z,i)
  if x==0 or x==W-1 or z==back or z==H-1 then put(a,x,h,z,i);put(a,x,h+1,z,i) end
 end end
 -- Original window pixels stay intact behind their frame and sill.
 for r,row in ipairs(a.tiles) do for c,t in ipairs(row) do if (t==10 or t==50) and (r-1)*8>=p.roofRows then
  local x0,sy0=(c-1)*8,(r-1)*8
  for py=1,6 do for px=1,6 do
   local x,y=x0+px,H-1-sy0-py;local i=(sy0+py)*W+x
   put(a,x,y,H-1,nil,true);put(a,x,y,H-2,i)
  end end
  for px=0,7 do local x=x0+px;put(a,x,H-1-sy0-7,H,(sy0+7)*W+x) end
 end end end
 end
end
return out
