-- Reviewed native rock islands. Their walkable collision cells are a flat
-- platform, not a mountain. Never mutate a shared tileset or its collision.
local C={}
local masks=setmetatable({},{__mode='k'})
local shapes=setmetatable({},{__mode='k'})
local dirs={{1,0},{-1,0},{0,1},{0,-1}}
local function island(map,x,y)
 local cache=masks[map]
 if not cache then cache={};masks[map]=cache end
 local width=map.widthCells or map.def.width*2
 local function key(a,b)return b*width+a end
 local start=key(x,y)
 if cache[start]~=nil then return cache[start]end
 if map:isWaterCell(x,y)then cache[start]=false;return false end
 local seen={[start]=true};local queue={{x,y}};local enclosed=true;local walkable=false;local head=1
 while queue[head]do
  local p=queue[head];head=head+1
  walkable=walkable or map:isWalkableCell(p[1],p[2])
  for _,d in ipairs(dirs)do
   local nx,ny=p[1]+d[1],p[2]+d[2]
   if not map:inBounds(nx,ny)then enclosed=false
   elseif not map:isWaterCell(nx,ny)then
    local k=key(nx,ny)
    if not seen[k]then seen[k]=true;queue[#queue+1]={nx,ny}end
   end
  end
  if #queue>64 then enclosed=false;break end
 end
 enclosed=enclosed and walkable
 for k in pairs(seen)do cache[k]=enclosed end
 return enclosed
end
function C.at(map,profile,s,tile,tx,ty)
 if map.id~='CHERRYGROVE_CITY'or not profile.mountain then return s end
 local rock=profile.edges and s.class==profile.edges.shoreClass or false
 for _,name in ipairs(profile.mountain.classes)do if s.class==name then rock=true;break end end
 local cx,cy=math.floor(tx/2),math.floor(ty/2)
 -- The native blocked rock patch on the island is still a mountain. Only
 -- cells the game permits walking on become the low landing platform.
 if not rock or not map:isWalkableCell(cx,cy)or not island(map,cx,cy)then return s end
 local byTile=shapes[s]
 if not byTile then byTile={};shapes[s]=byTile end
 if not byTile[tile]then
  byTile[tile]={class='coastal_platform',base='ground',h=0,art='flat',flat=true,
   authored=true,topTile=tile,sideTile=tile}
 end
 return byTile[tile]
end
return C
