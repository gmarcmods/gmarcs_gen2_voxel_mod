local root = (... and ... ~= '' and ...) or 'mods/gen2/new_mod_ex'
local F = assert(loadfile(root .. '/lib/FenceRails.lua'))()
local function quad(x0,x1,y0,y1,z0,z1)
  return {{x0,y0,z0},{x1,y0,z0},{x1,y1,z0},{x0,y1,z0}}
end
local function scene(cy)
  local S={objectQuads={},skip={keep=true},ground={keep=17}}
  local prefix=quad(-1,0,0,1,0,1); S.objectQuads[1]=prefix
  local map={id='ROUTE_39',tileset={imageWidth=128,imageHeight=128,perRow=16},tileAt=function(_,x,y)
    if (y==cy*2 or y==(cy+1)*2) and (x==0 or x==1 or x==2 or x==3) then return 74 end
  end}
  local reg={minX=0,minY=cy*2,tiles={{0,cy*2},{1,cy*2}}}
  assert(F.buildCell(S,map,reg,function(x,y)return x..':'..y end,1))
  assert(S.objectQuads[1]==prefix and S.skip.keep and S.ground.keep==17)
  assert(#S.objectQuads<=43,'at most 42 replacement quads plus prefix')
  for i=2,#S.objectQuads do
    for v=1,4 do
      assert(S.objectQuads[i][v][1]>=0 and S.objectQuads[i][v][1]<=16,'geometry stays within collision-cell width')
      assert(S.objectQuads[i][v][3]>=cy*16 and S.objectQuads[i][v][3]<=(cy+1)*16,'geometry stays within collision-cell depth')
    end
  end
  return S.objectQuads
end
local a,b=scene(3),scene(4)
local function railEnds(qs)
  local out={}
  for _,q in ipairs(qs) do
    local ymin,ymax=math.huge,-math.huge
    for i=1,4 do ymin=math.min(ymin,q[i][2]);ymax=math.max(ymax,q[i][2]) end
    if ymax-ymin==2 and (ymin==5 or ymin==11) then
      local lo,hi=math.huge,-math.huge
      for i=1,4 do lo=math.min(lo,q[i][3]);hi=math.max(hi,q[i][3]) end
      if hi>lo then out[ymin]=out[ymin] or {};out[ymin][#out[ymin]+1]={lo,hi} end
    end
  end
  return out
end
for _,qs in ipairs({a,b}) do
  local ends=railEnds(qs)
  for _,y in ipairs({5,11}) do assert(ends[y] and #ends[y]>=1,'both rail bands exist') end
end
-- Neighbor cell ranges meet at their shared boundary without a gap or overlap.
for _,y in ipairs({5,11}) do
  local ae,be=railEnds(a)[y],railEnds(b)[y]
  local aa,bb=ae[#ae],be[1]
  assert(aa[2]==bb[1] or bb[2]==aa[1],'adjacent rails share exact seam endpoint')
end
-- Only route 39 with a north/south neighboring tile-74 cell is eligible.
local function unchanged(id, northSouth)
  local S={objectQuads={quad(0,1,0,1,0,1)},skip={},ground={}}
  local before=S.objectQuads[1]
  local map={id=id,tileset={},tileAt=function(_,x,y) if northSouth and y==0 then return 74 end end}
  local ok=F.buildCell(S,map,{minX=0,minY=2,tiles={{0,2}}},function()end,1)
  assert(not ok and #S.objectQuads==1 and S.objectQuads[1]==before)
end
unchanged('ROUTE_39',false);unchanged('ROUTE_38',true)
print('FENCE RAILS PASS')
