local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/tests/')
package.path=root..'/../../../gen1recomp/?.lua;'..package.path
local T=dofile(root..'/lib/TinTowerInterior.lua')
local function key(x,y)return (y+64)*4096+x+64 end
local function fixture(direction)
 local tiles,collision={},{}
 local m={id='TIN_TOWER_4F',def={},tileset={id='TILESET_TOWER'},widthCells=4,heightCells=4}
 function m:tileAt(x,y)return tiles[key(x,y)]or 27 end
 function m:cellCollision(x,y)return collision[key(x,y)]or 7 end
 local x,y,cx,cy,code
 if direction=='right'then x,y,cx,cy,code=4,2,1,1,0xa0;tiles[key(x,y)]=71;tiles[key(x,y+1)]=87
 elseif direction=='left'then x,y,cx,cy,code=3,2,2,1,0xa1;tiles[key(x,y)]=70;tiles[key(x,y+1)]=86
 else x,y,cx,cy,code=2,4,1,1,0xa3;tiles[key(x,y)]=3;tiles[key(x+1,y)]=3 end
 collision[key(cx,cy)]=code
 return m,x,y,collision
end
local old={class='tower_wall',h=16,art='flat',authored=true}
for _,dir in ipairs({'right','left','down'})do
 local m,x,y,coll=fixture(dir)
 assert(T.at(m,old,27,0,0).h==-32,'dark lattice must be below the walking floor')
 assert(T.at(m,old,27,0,0).topTile==1,'pit floor must not wear raised lattice art')
 assert(T.rampAt(m,x,y)==dir,'white ramp does not follow native jump direction')
 local before=m:cellCollision(math.floor(x/2),math.floor(y/2))
 local s={shapeAt={},tileAt={},skip={},ground={},objectQuads={}}
 T.build(s,m,key)
 assert(s.skip[key(x,y)]and not s.ground[key(x,y)],'native white tile still extrudes under ramp')
 local min,max=math.huge,-math.huge
 for _,q in ipairs(s.objectQuads)do for _,p in ipairs(q)do min=math.min(min,p[2]);max=math.max(max,p[2])end end
 assert(min==-32 and max==3,'ramp must join a recessed pit with a short voxel slope')
 assert(m:cellCollision(math.floor(x/2),math.floor(y/2))==before,'presentation changed jump collision')
 for k in pairs(coll)do coll[k]=0 end
 assert(not T.rampAt(m,x,y),'white art without a native jump became a ramp')
 m.id='SPROUT_TOWER_2F'
 assert(T.at(m,old,27,0,0)==old,'shared tower tiles changed another building')
 m.id='TIN_TOWER_1F';assert(T.at(m,old,27,0,0)==old,'entrance floor changed')
end
-- Optional actual decoded cartridge data: every launch direction must have
-- both halves of its white ramp, including the two-direction corner cells.
if arg and arg[1]then
 local cache=arg[1]
 local maps=dofile(cache..'/maps.lua');local sets=dofile(cache..'/tilesets.lua')
 local Map=require('src.world.gen2.Map');local Permissions=require('src.world.gen2.Permissions')
 for n=2,9 do
  local id='TIN_TOWER_'..n..'F';local map=Map.new(assert(maps[id]),sets.TILESET_TOWER)
  local ramps,expected=0,0
  for y=0,map.heightCells-1 do for x=0,map.widthCells-1 do
   local faces=Permissions.ledgeFacings(map:cellCollision(x,y))
   if faces then for _ in pairs(faces)do expected=expected+2 end end
  end end
  for y=0,map.heightCells*2-1 do for x=0,map.widthCells*2-1 do
   if T.rampAt(map,x,y)then ramps=ramps+1 end
  end end
  assert(ramps==expected,id..': missing/misdirected native jump ramp ('..ramps..'/'..expected..')')
 end
 print('Native Tin Tower floors 2–9: all jump directions and corner ramps PASS')
end
print('Tin Tower: recessed pits, native-direction voxel ramps, no hidden floor and unchanged collision/other towers PASS')
