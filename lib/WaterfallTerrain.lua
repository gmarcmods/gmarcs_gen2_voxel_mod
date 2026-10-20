-- Native waterfall collision supplies the footprint. Upper basins rise while
-- ordinary shores stay low; no collision or map data is changed.
local W={HEIGHT=48};local plans=setmetatable({},{__mode='k'})
function W.plan(map)
 if plans[map]then return plans[map]end
 local plan={};plans[map]=plan
 if not(map.tileset and map.tileset.generation==2 and map.cellCollision and map.isWaterCell)then return plan end
 local width,height=map.widthCells,map.heightCells
 local fall,upper={},{}
 local function key(x,y)return y*width+x end
 for y=0,height-1 do for x=0,width-1 do
  if map:cellCollision(x,y)==0x33 then fall[key(x,y)]=true end
 end end
 local queue={}
 for y=0,height-1 do for x=0,width-1 do local k=key(x,y)
  if fall[k]and not fall[key(x,y-1)]then
   local last=y;while last+1<height and fall[key(x,last+1)]do last=last+1 end
   for cy=y,last do plan[key(x,cy)]={first=y,last=last}end
   if y>0 and map:isWaterCell(x,y-1)then local u=key(x,y-1);if not upper[u]then upper[u]=true;queue[#queue+1]=u end end
  end
 end end
 local head=1
 while head<=#queue do
  local k=queue[head];head=head+1;local x,y=k%width,math.floor(k/width)
  plan[k]=W.HEIGHT
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do local nx,ny=x+d[1],y+d[2];local n=key(nx,ny)
   if nx>=0 and ny>=0 and nx<width and ny<height and not upper[n]and not fall[n]and map:isWaterCell(nx,ny)then
    upper[n]=true;queue[#queue+1]=n
   end
  end
 end
 -- An island enclosed by upper water belongs to that terrace. Never
 -- raise a connected landing shore or a path reaching the map boundary.
 if #queue>0 and map.isWalkableCell then
  local seen={}
  for y=0,height-1 do for x=0,width-1 do local start=key(x,y)
   if not seen[start]and not map:isWaterCell(x,y)and map:isWalkableCell(x,y)then
    local land={start};seen[start]=true;local at=1;local high,low,edge=false,false,false
    while at<=#land do
     local k=land[at];at=at+1;local cx,cy=k%width,math.floor(k/width)
     edge=edge or cx==0 or cy==0 or cx==width-1 or cy==height-1
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do local nx,ny=cx+d[1],cy+d[2];local n=key(nx,ny)
      if nx>=0 and ny>=0 and nx<width and ny<height then
       if map:isWaterCell(nx,ny)then
        high=high or upper[n]==true;low=low or not upper[n]and not fall[n]
       elseif not seen[n]and map:isWalkableCell(nx,ny)then seen[n]=true;land[#land+1]=n end
      end
     end
    end
    if high and not low and not edge then for _,k in ipairs(land)do plan[k]=W.HEIGHT end end
   end
  end end
 end
 -- Raise the rock containing the reservoir too, so water never floats
 -- above a low enclosing bank. Landing shores are not part of this set.
 local banks={};for k,v in pairs(plan)do if type(v)=='number'then banks[#banks+1]=k end end
 for _,k in ipairs(banks)do
  local x,y=k%width,math.floor(k/width)
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do local nx,ny=x+d[1],y+d[2]
   if nx>=0 and ny>=0 and nx<width and ny<height and map.isWalkableCell
    and not map:isWalkableCell(nx,ny)and not map:isWaterCell(nx,ny)then plan[key(nx,ny)]=W.HEIGHT end
  end
 end
 return plan
end
function W.at(map,shape,tx,ty)
 if not shape or not map.widthCells or tx<0 or ty<0 or tx>=map.widthCells*2 or ty>=map.heightCells*2 then return shape end
 local cx,cy=math.floor(tx/2),math.floor(ty/2)
 local elevation=W.plan(map)[cy*map.widthCells+cx]
 if not elevation then return shape end
 local out={};for k,v in pairs(shape)do out[k]=v end
 if type(elevation)=='number'then out.h=elevation+((shape.class=='water'or shape.base=='water')and -2 or 0)
 else
  local row=ty-elevation.first*2
  local length=(elevation.last-elevation.first+1)*2
  out.h=math.floor(W.HEIGHT*(1-row/length))-2
  out.class='waterfall';out.base='wall';out.art='flat';out.flat=true
  out.sideTile=map:tileAt(tx,ty)
 end
 out.authored=true
 return out
end
return W
