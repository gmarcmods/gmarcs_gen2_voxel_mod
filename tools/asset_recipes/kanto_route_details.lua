-- Preserve landmarks, forest assets and low jump faces. Improve shared route
-- rock/fence geometry and add piers only beneath Route 24's native bridge.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local P=dofile(dir..'/historic_primitives.lua')
local rock=P.blank('kanto_boundary_post',{{42,43},{58,59}});rock.border=true
for y=0,10 do for x=0,15 do for z=0,15 do
 if ((x-7.5)/7.5)^2+((z-7.5)/7.5)^2+(y/10.5)^2<=1 then
  P.put(rock,x,y,z,math.max(3,math.min(12,13-y))*16+x)
 end
end end end
local fence=P.blank('kanto_fence_post',{{14},{85}})
P.box(fence,2,0,5,4,13,4,function(x,y)return(15-y)*8+x end)
for _,y in ipairs({7,10})do P.box(fence,0,y,5,8,1,2,13*8+3)end
local bridge={id='kanto_nugget_bridge_span',map='ROUTE_24',groundTile=20,support=2,tiles={{75,75},{75,75}},
 surfaces={P.s({0,0,16,16},'horizontal',0,2)},voxelEdits={}}
for _,x in ipairs({2,12})do for _,z in ipairs({2,12})do
 P.box(bridge,x,-5,z,2,6,2,7*16+7)
end end
return {tilesets={TILESET_KANTO={
 mountain={classes={'kanto_cliff'},rise=2,maxHeight=48,sideTile=17,topTile=17},
 assets={rock,fence,bridge},
}}}
