-- Sprout/Tin Tower timber, stone lanterns, altars and burned remnants.
local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local P=dofile(root..'/historic_primitives.lua');local s=P.s;local assets={}
local function add(a) assets[#assets+1]=a;return a end
add(P.column('tower_stone_pillar',{{34,35},{50,51},{18,19},{54,55}},32))
add(P.column('tower_pillar_cap',{{34,35},{50,51}},20))
add(P.column('tower_gym_pillar',{{38,39},{54,55}},20))
local central=add(P.blank('tower_central_timber',{{45,46,46,47},{61,62,62,63},{60,62,1,44},{77,78,78,79},{77,78,78,79},{93,94,94,95}}))
-- Sprout's central trunk has a round section and broad floor footing.
for y=0,63 do local r=y<4 and 15 or 11
 for x=0,31 do for z=0,31 do if (x-15.5)^2+(z-15.5)^2<=r*r then
 -- The black upper source opening is ceiling void, not trunk bark.
 local sy=y<4 and 45 or 32+y%8
 P.put(central,x,y,z,sy*32+x)
 end end end
end
local broken=add(P.blank('tower_broken_beam',{{4,5},{20,21}}))
-- A snapped log leans above scattered fragments, not a full square wall.
for x=0,15 do for z=0,15 do
 local h=math.max(1,math.floor(12-math.abs(x-7)*.7-math.abs(z-6)*.9))
 for y=0,h do if x>1 and x<14 and z>1 and z<14 then P.put(broken,x,y,z,math.min(15,15-y)*16+x) end end
end end
local function lantern(id,t)
 local a=add(P.blank(id,t));P.box(a,2,0,2,12,3,12,30*16+4)
 P.box(a,5,3,5,6,9,6,25*16+6)
 P.box(a,2,12,2,12,2,12,17*16+6)
 P.ellipsoid(a,7.5,20,7.5,6,7,6,function(x,y,z)return math.max(0,math.min(15,27-y))*16+x end)
 return a
end
lantern('tower_lantern',{{74,75},{90,91},{76,92},{54,55}})
lantern('tower_altar_lantern',{{66,67},{90,91},{76,92},{54,55}})
local statue=add(P.blank('tower_gym_statue',{{40,41},{56,57},{42,43},{58,59}}))
P.box(statue,2,0,2,12,5,12,29*16+6)
P.ellipsoid(statue,7.5,12,7.5,5,8,5,function(x,y,z)return math.max(8,math.min(23,26-y))*16+x end)
P.ellipsoid(statue,7.5,23,7.5,7,6,6,function(x,y,z)return math.max(0,29-y)*16+x end)
add({id='tower_altar_scroll',tiles={{17,72,73,17},{33,88,89,33}},surfaces={s({0,0,32,16},'vertical',16,3)}})
-- Thin posts and rails retain clear floor between the timber members.
local rail=add(P.blank('tower_timber_rail',{{17,17},{33,33}}))
for _,x in ipairs({2,10}) do P.box(rail,x,0,5,3,16,5,function(xx,y,z)return (15-y)*16+xx end) end
P.box(rail,0,11,6,16,3,3,function(x,y,z)return (15-y)*16+x end)
local side=add(P.blank('tower_timber_rail_side',{{65,49},{65,49}}))
for _,z in ipairs({2,10}) do P.box(side,5,0,z,5,16,3,function(x,y,zz)return zz*16+math.min(15,y) end) end
P.box(side,6,11,0,3,3,16,function(x,y,z)return z*16+x end)
-- Whole furniture patterns claim before their reusable component sprites.
for i,a in ipairs(assets) do a._order=i end
table.sort(assets,function(a,b) local aa,bb=#a.tiles*#a.tiles[1],#b.tiles*#b.tiles[1];return aa==bb and a._order<b._order or aa>bb end)
for _,a in ipairs(assets) do a._order=nil end
local detail=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/detail_geometry.lua')
for _,a in ipairs(assets)do if a.id=='tower_gym_statue' then detail.southCell(a) elseif a.id=='tower_lantern' then detail.bellsprout(a) end end
local entrance=dofile(root..'/tower_entrance_repairs.lua')
for _,a in ipairs(assets)do entrance.repair(a)end
local extra=entrance.extras().TILESET_TOWER
for i=#extra,1,-1 do table.insert(assets,1,extra[i])end
return {tilesets={TILESET_TOWER={assets=assets,planter_spray=false,
 classes={tower_wall={base='wall',height=16,art='flat'},tower_roof={base='wall',height=24,art='flat'}},
 pins={ground={0,2,7,8,9,23,24,25,80}, -- wood floors, exit rugs, Tin Tower warp pads
 void={1}, -- openings in the tower floors remain empty
 tower_wall={94,3,10,11,17,26,27,32,33,49,64,65,70,71,86,87},
 tower_roof={6,22,36,37,52,53,81,82,83}, -- exposed roof course is a level timber platform
 stair_n={12,13,28,29}, -- light upper tread rises north
 stair_down_n={14,15,30,31,68,69,84,85}, -- stairwell and Burned Tower ladder descend north
 },prop_ground={[4]=2,[5]=2,[20]=2,[21]=2,[34]=2,[35]=2,[50]=2,[51]=2,[18]=2,[19]=2,[54]=2,[55]=2},
}}}
