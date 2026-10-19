-- Component CPU cost only; use luajit and luajit -joff. No GPU/FPS claim.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local M=dofile(dir..'/../lib/MeshVisibility.lua')
print('production_cache',M.cacheEnabled)
M.cacheEnabled=true
local baseline=arg[1]and dofile(arg[1])or M
local matrix={.003,0,0,-.5,0,.005,0,-.2,0,0,.003,-.5,0,0,0,1}
local shadow={.003,0,0,-.6,0,.005,0,-.2,0,0,.003,-.5,0,0,0,1}
local groups={};for z=0,15 do for x=0,15 do groups[#groups+1]={first=#groups*6+1,count=6,bounds={x*64,0,z*64,x*64+64,48,z*64+64}}end end
local mesh={setDrawRange=function()end}
love={graphics={draw=function()end}}
M.register(mesh,groups);baseline.register(mesh,groups)
local function measure(module,moving)
 local start=os.clock();local sum=0
 for i=1,5000 do
  matrix[4]=-.5+(moving and i%100*.0001 or 0)
  shadow[4]=-.6+(moving and i%100*.0001 or 0)
  sum=sum+module.draw(mesh,matrix)+module.draw(mesh,shadow)
 end
 return(os.clock()-start)*1000,sum
end
for _,moving in ipairs({false,true})do
 local results={{},{}}
 measure(baseline,moving);measure(M,moving)
 for _=1,7 do
  for i,module in ipairs({baseline,M})do local ms,sum=measure(module,moving);results[i][#results[i]+1]=ms;assert(sum>0)end
 end
 for i,r in ipairs(results)do table.sort(r);print(moving and'moving'or'stationary',i==1 and'baseline_ms'or'cached_ms',r[4])end
end
