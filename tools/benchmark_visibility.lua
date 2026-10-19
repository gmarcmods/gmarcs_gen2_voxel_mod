-- Run with luajit, then luajit -joff. CPU microbenchmark, not a frame/FPS test.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local M=dofile(dir..'/../lib/MeshVisibility.lua')
local matrix={.003,0,0,-.5,0,.005,0,-.2,0,0,.003,-.5,0,0,0,1}
local boxes={};for z=0,15 do for x=0,15 do boxes[#boxes+1]={x*64,0,z*64,x*64+64,48,z*64+64}end end
local function measure(prepared)
 local sum=0;local start=os.clock()
 for _=1,2000 do
  local planes=prepared and M.planes(matrix)
  for _,b in ipairs(boxes)do
   local visible=prepared and M.visiblePrepared(b,planes)or not prepared and M.visible(b,matrix)
   if visible then sum=sum+1 end
  end
 end
 return(os.clock()-start)*1000,sum
end
measure(false);measure(true)
local results={{},{}}
for _=1,9 do for i=1,2 do local ms,sum=measure(i==2);assert(sum==128000);results[i][#results[i]+1]=ms end end
for i,r in ipairs(results)do table.sort(r);print(i==1 and'original_ms'or'prepared_ms',r[5])end
print('JIT',jit and jit.status()or false,'production_prepared',M.prepared)
