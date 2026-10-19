-- Tin Tower's lattice is a shaft below the floor, not a raised roof.
-- White ledge art is a short launch ramp. Native collision owns direction.
local Permissions=require('src.world.gen2.Permissions')
local T={DEPTH=-32}
local pits={[3]=true,[11]=true,[26]=true,[27]=true,[70]=true,[71]=true,[86]=true,[87]=true}
local pit={class='tin_tower_pit',h=-32,art='flat',authored=true,topTile=1}
local floor={class='ground',h=0,art='flat',flat=true,authored=true,sideTile=27}
function T.enabled(map)
 local n=tonumber((map.id or''):match('^TIN_TOWER_(%d+)F$'))
 return map.tileset and map.tileset.id=='TILESET_TOWER' and n and n>=2 and n<=9
end
function T.at(map,original,tile,tx,ty)
 if not T.enabled(map)or tx<0 or ty<0 or tx>=map.widthCells*2 or ty>=map.heightCells*2 then return original end
 if pits[tile]then return pit end
 if tile==2 then return floor end
 return original
end
function T.rampAt(map,tx,ty)
 if not T.enabled(map)then return nil end
 local tile=map:tileAt(tx,ty)
 local cx,cy=math.floor(tx/2),math.floor(ty/2)
 local function jump(x,y,dir)
  if x<0 or y<0 or x>=map.widthCells or y>=map.heightCells then return false end
  local faces=Permissions.ledgeFacings(map:cellCollision(x,y))
  return faces and faces[dir]
 end
 if (tile==71 or tile==87)and tx%2==0 and jump(cx-1,cy,'right')then return 'right' end
 if (tile==70 or tile==86)and tx%2==1 and jump(cx+1,cy,'left')then return 'left' end
 if tile==3 and ty%2==0 and jump(cx,cy-1,'down')then return 'down' end
end
function T.build(S,map,key)
 if not T.enabled(map)then return end
 local aw,ah=map.tileset.imageWidth or 128,map.tileset.imageHeight or 48
 local perRow=map.tileset.tilesPerRow or 16
 local function face(points,tile,shade,uv)
  local q={uv={},shade=shade or 1}
  local default={{.05,7.95},{7.95,7.95},{7.95,.05},{.05,.05}}
  for i,p in ipairs(points)do
   local t=(uv or default)[i]
   q[i]=p;q.uv[i]={((tile%perRow)*8+t[1])/aw,(math.floor(tile/perRow)*8+t[2])/ah}
  end
  S.objectQuads[#S.objectQuads+1]=q
 end
 for ty=0,map.heightCells*2-1 do for tx=0,map.widthCells*2-1 do
  local dir=T.rampAt(map,tx,ty)
  if dir then
   local k=key(tx,ty)
   -- Keep authored furniture claims intact. These native white ledge tiles
   -- have no authored object in the shipped project.
   if not S.skip[k]then
    S.skip[k]=true;S.ground[k]=nil
    local x,z,tile=tx*8,ty*8,map:tileAt(tx,ty)
    face({{x,-32,z},{x+8,-32,z},{x+8,-32,z+8},{x,-32,z+8}},1,1)
    -- Local (along,cross) axes orient both texture and steps in map space.
    local function point(a,b,h)
     if dir=='right'then return {x+a,h,z+b}
     elseif dir=='left'then return {x+8-a,h,z+b}
     else return {x+b,h,z+a}end
    end
    local function top(a,b,h)
     local x0,z0,x1,z1
     if dir=='right'then x0,z0,x1,z1=a,0,b,8
     elseif dir=='left'then x0,z0,x1,z1=8-b,0,8-a,8
     else x0,z0,x1,z1=0,a,8,b end
     local uv={{x0+.025,z0+.025},{x1-.025,z0+.025},{x1-.025,z1-.025},{x0+.025,z1-.025}}
     face({{x+x0,h,z+z0},{x+x1,h,z+z0},{x+x1,h,z+z1},{x+x0,h,z+z1}},tile,1,uv)
    end
    local function cross(a,bottom,height,source,shade)
     face({point(a,0,bottom),point(a,8,bottom),point(a,8,height),point(a,0,height)},source,shade)
    end
    -- Timber shaft wall directly below the launch edge, continuous with
    -- the surrounding floor's ordinary recessed-neighbour faces.
    for h=-32,-8,8 do cross(0,h,h+8,27,.65)end
    cross(0,-1,0,tile,.8)
    for step=0,3 do
     local a,b=step*2,step*2+2
     top(a,b,step)
     if step>0 then cross(a,step-1,step,tile,.85)end
     face({point(a,0,-1),point(b,0,-1),point(b,0,step),point(a,0,step)},tile,.75)
     face({point(b,8,-1),point(a,8,-1),point(a,8,step),point(b,8,step)},tile,.75)
    end
    cross(8,-1,3,tile,.85)
   end
  end
 end end
end
return T
