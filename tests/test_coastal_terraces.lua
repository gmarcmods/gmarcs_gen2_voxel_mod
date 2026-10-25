local root=arg[1]or'mods/gen2/new_mod_ex'

local fixture={
 tiles={{43,44,44,45},{59,60,60,61},{59,60,60,61},{75,76,76,77}},
 placements={{8,20},{0,16},{28,28}},
 runs={{x=0,y=0,z=0,len=1,i=1,delta=1}},height=16,
}
local dataPath=root..'/data/cherrygrove_terraces.lua'
local function copy(v)
 if type(v)~='table'then return v end
 local out={};for k,value in pairs(v)do out[k]=copy(value)end;return out
end
local dataCalls=0
local loaded=assert(loadfile(dataPath))()

local meshCalls=0
local built={}
local quads={{tag='shared terrace quad'}}
local V={}
V.data=function(name)
 assert(name=='cherrygrove_terraces');dataCalls=dataCalls+1
 return loaded
end
V.require=function(name)
 if name=='TerraceMesh'then
  return {build=function(spec,atlasW,atlasH,perRow)
   meshCalls=meshCalls+1;built.spec=spec;built.atlasW=atlasW;built.atlasH=atlasH;built.perRow=perRow
   return quads
  end}
 end
 error('unexpected module '..tostring(name))
end
local C=assert(loadfile(root..'/lib/CoastalTerraces.lua'))(V)
local data=V.data('cherrygrove_terraces')

local function placementXY(p)return p.x or p[1],p.y or p[2]end
local tiles=data.tiles
assert(#tiles==4 and #tiles[1]==4,'native terrace footprint must be 4×4 tiles')
assert(data.height==8 and type(data.runs)=='table','native terrace geometry config is incomplete')
local placements={}
for _,p in ipairs(data.placements)do local x,y=placementXY(p);placements[#placements+1]={x,y}end
assert(#placements==3,'Cherrygrove native map has three reviewed terrace placements')
for i,p in ipairs({{8,20},{0,16},{28,28}})do
 assert(placements[i][1]==p[1]and placements[i][2]==p[2],'terrace placement coordinates changed')
end

local function key(x,y)return (y+64)*4096+x+64 end
local function scene(id,opts)
 opts=opts or{}
 local locations={}
 for _,p in ipairs(placements)do locations[#locations+1]={x=p[1],y=p[2]}end
 local m={id=id,def={width=20,height=9},tileset={id='TILESET_JOHTO'},
  isWalkableCell=function(_,x,y)
   local wx,wy=opts.walkableX,opts.walkableY
   if wx==nil then return false end
   return x==wx and y==wy
  end,
  tileAt=function(_,tx,ty)
   for _,p in ipairs(locations)do
    local x,y=p.x,p.y
    if tx>=x and tx<x+4 and ty>=y and ty<y+4 then
     if opts.mismatchX==tx and opts.mismatchY==ty then return 99 end
     return tiles[ty-y+1][tx-x+1]
    end
   end
  end}
 local S={skip={},ground={},assetStamps={}}
 if opts.claim then
  local x,y=opts.claim[1],opts.claim[2];S.skip[key(x,y)]='existing owner';S.ground[key(x,y)]=91
 end
 return S,m
end

local beforeDataCalls=dataCalls
local other,route=scene('ROUTE_41')
assert(C.build(other,route,data,16,key)==0,'Cherrygrove terrace leaked onto another map')
assert(dataCalls==beforeDataCalls,'other maps should not load Cherrygrove terrace data')
assert(#other.assetStamps==0 and next(other.skip)==nil,'other map received terrace claims')

local S,map=scene('CHERRYGROVE_CITY')
local count=C.build(S,map,data,16,key)
assert(count==3,'all three native rocky platforms must build')
assert(meshCalls==1 and built.spec==data and built.perRow==16,'one shared mesh must be built per data object')
assert(built.atlasW==128 and built.atlasH==48,'native atlas fallback dimensions incorrect')
assert(#S.assetStamps==3,'each native placement must receive an asset stamp')
for i,p in ipairs(placements)do
 local stamp=S.assetStamps[i]
 assert(stamp.quads==quads,'placements must reuse the same generated terrace quads')
 assert(stamp.mx==p[1]*8 and stamp.mz==p[2]*8 and stamp.own==true,'terrace stamp transform is incorrect')
end
local claimed=0
for _,p in ipairs(placements)do for y=p[2],p[2]+3 do for x=p[1],p[1]+3 do
 local k=key(x,y);assert(S.skip[k]and S.ground[k]==data.materials.topTile,'native terrace tile was not claimed with rock ground')
 claimed=claimed+1
end end end
assert(claimed==48,'exactly 48 native tiles must be claimed')

local mismatch,mm=scene('CHERRYGROVE_CITY',{mismatchX=9,mismatchY=20})
assert(C.build(mismatch,mm,copy(data),16,key)==2,'one mismatched native tile must disable only its placement')
assert(#mismatch.assetStamps==2,'matching formations must remain enabled after a local tile mismatch')

local walking,wm=scene('CHERRYGROVE_CITY',{walkableX=4,walkableY=10})
assert(C.build(walking,wm,copy(data),16,key)==2,'walkable native cells must disable only their own terrace')
assert(#walking.assetStamps==2,'walkable first platform must not disable other formations')

local owned,om=scene('CHERRYGROVE_CITY',{claim={8,20}})
assert(C.build(owned,om,copy(data),16,key)==2,'an already claimed tile must disable only its own terrace')
assert(owned.skip[key(8,20)]=='existing owner'and owned.ground[key(8,20)]==91,
 'an existing tile owner must be preserved')
assert(#owned.assetStamps==2,'unclaimed formations must still build around an existing owner')

print('CHERRYGROVE COASTAL TERRACES PASS')
