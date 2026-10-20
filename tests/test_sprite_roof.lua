-- Match the maintained Gen 1 roof algorithm while retaining authored walls.
local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/tests/')
local Roof=dofile(root..'/lib/SpriteRoof.lua')
local B=assert(loadfile(root..'/../../gen1/dramatic-shape/lib/Buildings.lua'))({require=function()return{tick=function()end}end})
local function up(fn,name)
 for i=1,100 do local n,v=debug.getupvalue(fn,i);if not n then break end;if n==name then return v end end
 error('Gen 1 reference no longer exposes '..name)
end
local measure,model=up(B.build,'measure'),up(B.build,'model')
for _,rows in ipairs({16,32,56})do
 local W,H=32,rows+24;local sp={W=W,H=H,col={},inside={}}
 for x=0,W-1 do
  local top=math.max(0,7-math.min(x,W-1-x))
  for y=0,H-1 do local i=y*W+x
   sp.inside[i]=y>=top and not(rows==32 and y==H-1);sp.col[i]=y==top and 3 or y%4==0 and 2 or 1
  end
 end
 local t={tiles={},roofRows=rows,roofBack=7,roofFront=8,roofCycle={5,rows==16 and 8 or 12},slab=4,frontEave=4}
 for _=1,H/8 do t.tiles[#t.tiles+1]={1,1,1,1}end
 local pr=measure(sp,t);local reference=model(sp,pr,t)
 local base={W=W,ymin=0,ytop=23,zmin=0,zmax=H,at=function(x,y,z)
  if x<0 or x>=W or y<0 or y>23 or z<0 or z>=H then return nil end
  return H*W-1
 end}
 local actual=Roof.build(base,sp,{rows=rows,wallHeight=24,back=7,front=8,cycle=t.roofCycle,slab=4,overhang=4})
 for x=0,W-1 do for z=0,H+3 do
  local top=pr.ytop-pr.top[x]
  for y=top-3,pr.ytop+2 do
   assert(actual.at(x,y,z)==reference.at(x,y,z),'roof differs from Gen 1 at '..x..','..y..','..z)
  end
  assert(actual.at(x,0,z)==(z<H and H*W-1 or nil),'authored floor changed')
 end end
end
print('Sprite roofs: Gen 1 silhouette, texture courses, rim, wall trimming and overhang agree PASS')
