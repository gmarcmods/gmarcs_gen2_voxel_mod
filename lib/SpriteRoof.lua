-- Gen 1 Buildings.measure/model roof rules over an authored Gen 2 facade.
-- Native silhouette controls the sloped ends; depth cycles material courses.
local Roof={}
function Roof.build(base,sp,c)
 local W,D,rows=sp.W,sp.H,c.rows
 -- Window sills may protrude past the facade; they do not deepen the roof.
 local ground=rows
 for y=sp.H-1,rows,-1 do
  local drawn=false
  for x=0,W-1 do if sp.inside[y*W+x]then drawn=true;break end end
  if drawn then ground=y+1;break end
 end
 -- The sprite's last row may be open ground, rather than the threshold.
 -- Use its measured ground line, as Gen 1 does, without moving the facade.
 local slab=c.slab or 4;local peak=c.wallHeight-1+slab-(sp.H-ground)
 local top,paint,first,last={},{},nil,nil
 local shades={}
 for i=0,sp.W*sp.H-1 do if sp.inside[i]and not shades[sp.col[i]]then shades[sp.col[i]]=i end end
 for shade=0,3 do shades[shade]=shades[shade]or shades[3]or 0 end
 for x=0,W-1 do
  local y=0;while y<rows and not sp.inside[y*W+x]do y=y+1 end
  top[x]=y
  if y<rows then first=first or x;last=x end
  local p=y;while p<rows and sp.inside[p*W+x]and sp.col[p*W+x]==3 do p=p+1 end
  paint[x]=p<rows and sp.inside[p*W+x]and p or y
 end
 local zmax=D-1+(c.overhang or 0)
 local cycle0,cycle1=c.cycle[1],c.cycle[2]
 local function at(x,y,z)
  if x<0 or x>=W or y<0 or z<0 or z>zmax then return nil end
  local tx=peak-top[x]
  if top[x]<rows and y>tx-slab then
   if y>tx then return nil end
   if y==tx and x>first and x<last and z>0 and z<zmax then
    local df,db=z,zmax-z;local sy
    if df<c.back then sy=df
    elseif db<c.front then sy=rows-1-db
    else sy=cycle0+(df-cycle0)%(cycle1-cycle0+1)end
    return math.max(sy,paint[x])*W+x
   end
   local outer=x==first or x==last or z==0 or z==zmax
   if outer and(y==tx or y==tx-slab+1)then return shades[3]end
   return shades[2]
  end
  return base.at(x,y,z)
 end
 return{W=W,xmin=base.xmin or 0,xmax=base.xmax or W-1,ymin=base.ymin or 0,
  ytop=math.max(base.ytop,peak),zmin=base.zmin or 0,zmax=zmax,at=at}
end
return Roof
