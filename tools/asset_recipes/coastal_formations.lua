-- Exact native island patterns; cached surface shells instead of solid boxes.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')
local P=dofile(dir..'/historic_primitives.lua')
local R={}
local rock={};for _,t in ipairs({43,44,45,59,60,61,75,76,77,70,71,86,87})do rock[t]=true end
local function island(id,tiles)
 local a=P.blank(id,tiles);a.map='ROUTE_41';a.groundTile=6
 local W,D=#tiles[1]*8,#tiles*8;local mask,dist,heights={}, {}, {};local keep={};local donor;local entrances={}
 for ry,row in ipairs(tiles)do for rx,t in ipairs(row)do
  if t==60 and not donor then donor={x=(rx-1)*8,y=(ry-1)*8}end
  if t==70 then entrances[#entrances+1]={x=(rx-1)*8,z=(ry-1)*8}end
  if not rock[t]or t==70 or t==71 or t==86 or t==87 then keep[t]=true end
  if rock[t]then for z=(ry-1)*8,ry*8-1 do for x=(rx-1)*8,rx*8-1 do mask[z*W+x]=true end end end
 end end
 donor=assert(donor,'formation requires native rock-face material')
 a.keep={};for t in pairs(keep)do a.keep[#a.keep+1]=t end;table.sort(a.keep)
 local function at(t,x,z)return x>=0 and x<W and z>=0 and z<D and t[z*W+x]or 0 end
 for z=0,D-1 do for x=0,W-1 do if mask[z*W+x]then
  dist[z*W+x]=1+math.min(at(dist,x-1,z),at(dist,x,z-1))
 end end end
 for z=D-1,0,-1 do for x=W-1,0,-1 do if mask[z*W+x]then
  local k=z*W+x;dist[k]=math.min(dist[k],1+at(dist,x+1,z),1+at(dist,x,z+1))
  local nx=(x+.5-W/2)/(W/2);local nz=(z+.5-D/2)/(D/2)
  local crown=3+23*math.sqrt(math.max(0,1-nx*nx-nz*nz))
  local h=math.floor(math.min(3+dist[k]*2.8,crown))
  for _,e in ipairs(entrances)do
   local outside=math.max(0,e.x-x,x-(e.x+15),e.z-z,z-(e.z+15))
   h=math.max(h,18-2*math.floor(outside/3))
  end
  heights[k]=h
 end end end
 for z=0,D-1 do for x=0,W-1 do local top=heights[z*W+x]
  if top then
   local low=math.min(at(heights,x-1,z),at(heights,x+1,z),at(heights,x,z-1),at(heights,x,z+1))-1
   low=math.min(top-1,low)
   for _,e in ipairs(entrances)do if x>=e.x and x<e.x+16 and z>=e.z and z<e.z+16 then low=math.min(low,16)end end
   for y=math.max(-2,low),top do
    local passage=false
    for _,e in ipairs(entrances)do if x>=e.x and x<e.x+16 and z>=e.z and z<e.z+16 and y<16 then passage=true end end
    if not passage then
     -- Small patches of actual stone, avoiding the painted black outline
     -- and sand pixels; world shading supplies the face orientation.
     local sx=donor.x+(x+math.floor(z/8)*3)%8
     local sy=donor.y+(z+top-y+math.floor(x/16)*3)%8
     P.put(a,x,y,z,sy*W+sx)
    end
   end
  end
 end end
 return a
end
local function cluster(id)
 local a=P.blank(id,{{88,88},{88,88}});a.groundTile=20
 for x=0,15 do for z=0,15 do
  -- Joined, unequal shoulders replace the repeating grid of four pearls.
  local r1=1-((x-5)/5.8)^2-((z-6)/5.8)^2
  local r2=1-((x-11)/3.8)^2-((z-11)/4)^2
  local h=math.max(6*math.sqrt(math.max(0,r1)),4*math.sqrt(math.max(0,r2)))
  if r1>0 or r2>0 then for y=-4,math.floor(h)do
   P.put(a,x,y,z,(3+math.floor((x+z)/3)%2)*16+4+math.floor((x+y)/3)%2)
  end end
 end end
 return a
end
function R.batch()
 local assets,seen={},{}
 for _,p in ipairs(dofile(dir..'/coastal_patterns.lua'))do
  local rows={};for _,r in ipairs(p.tiles)do rows[#rows+1]=table.concat(r,',')end
  local signature=table.concat(rows,';')
  if not seen[signature]then
   seen[signature]=true;assets[#assets+1]=island('whirl_coastal_formation_'..(#assets+1),p.tiles)
  end
 end
 -- A small shoulder can also occur within a complete island pattern.
 -- Claim complete formations before their repeating four-tile outcrops.
 table.sort(assets,function(a,b)return #a.tiles*#a.tiles[1]>#b.tiles*#b.tiles[1]end)
 assets[#assets+1]=cluster('johto_sea_rock_cluster')
 return {tilesets={TILESET_JOHTO={assets=assets},TILESET_JOHTO_MODERN={assets={cluster('modern_sea_rock_cluster')}}}}
end
return R
