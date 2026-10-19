-- Native Johto tile 88: low rounded sea rocks with native rock-face colors.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local P=dofile(dir..'/historic_primitives.lua')
return function(id)
 local a=P.blank(id,{{88}})
 local radii={[-3]=1.8,[-2]=2.5,[-1]=3,[0]=3,[1]=2.7,[2]=2,[3]=1.2}
 for y=-3,3 do
  local r=radii[y]
  for x=2,7 do for z=1,6 do
   if ((x-4.5)/r)^2+((z-3.5)/r)^2<=1 then
    -- Pick from the two shaded inner rows of the actual rock. Its outer
    -- black outline and the surrounding white foam are not flank textures.
    local sy=3+(x+z+y)%2;local sx=4+(x+2*z+y)%2
    P.put(a,x,y,z,sy*8+sx)
   end
  end end
 end
 return a
end
