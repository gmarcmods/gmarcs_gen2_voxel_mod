-- Launcher-validated optional ROM -> installation-scoped generated models.
-- Alternating commit records keep the previous installation readable if a
-- cache write is interrupted. The ROM itself is never written by this mod.
local V=...
local Pack=V.require('StadiumPack')
local I={COUNT=151,REV=2,MD5='ed1378bc12115f71209a77844965ba50',
 status={state='missing',done=0,total=151}}
local cache=V.mod.cache
local function decodeRecord(bytes)
 local format,rev,count,md5,generation=bytes:match('^(DSM%d+) (%d+) (%d+) (%x+) (%d+)\n$')
 if not format then return nil end
 generation=tonumber(generation)
 return {format=format,rev=tonumber(rev),count=tonumber(count),md5=md5,
  generation=generation,root='stadium/g'..generation}
end
local function valid(m)
 if type(m)~='table' or m.format~='DSM3' or m.rev~=I.REV or m.count~=I.COUNT
    or m.md5~=I.MD5 or type(m.generation)~='number' or m.generation<1
    or m.generation%1~=0 or m.root~='stadium/g'..m.generation then return false end
 for dex=1,I.COUNT do
  local info=cache:info(('%s/%03d.dsm'):format(m.root,dex))
  if not info or (info.size or 0)<6 then return false end
 end
 return true
end
function I.ready()return I.active~=nil end
function I.restore()
 if not cache then return false end
 local best
 for slot=0,1 do
  local bytes=cache:read('stadium/slot-'..slot..'.info')
  if bytes then
   local ok,m=pcall(decodeRecord,bytes)
   if ok and valid(m) and (not best or m.generation>best.generation) then best=m end
  end
 end
 local previous=I.active
 I.active=best
 if not best then
  if previous then Pack.setReader(nil) end
  return false
 end
 Pack.setReader(function(dex)return cache:read(('%s/%03d.dsm'):format(best.root,dex))end)
 I.status.state='ready';I.status.done=best.count
 return true
end
local function clean(root)
 if root and cache.delete then
  for dex=1,I.COUNT do cache:delete(('%s/%03d.dsm'):format(root,dex))end
 end
end
local function abort(state,err)
 clean(I.staging and I.staging.root)
 I.job=nil;I.staging=nil
 I.status.state=state;I.status.error=err
end
function I.begin()
 if I.job then return nil,'model conversion is already running' end
 local imports=V.mod.imports
 if not (cache and imports) then return nil,'this engine has no mod import/cache API' end
 I.restore()
 local info,err=imports:info('stadium')
 if not info then return nil,err end
 if info.md5~=I.MD5 or info.size~=33554432 then return nil,'needs Pokemon Stadium US 1.0' end
 local chunks={}
 for offset=0,info.size-1,8*1024*1024 do
  local n=math.min(8*1024*1024,info.size-offset)
  local bytes,why=imports:read('stadium',offset,n)
  if not bytes or #bytes~=n then return nil,why or 'short ROM read' end
  chunks[#chunks+1]=bytes
 end
 local rom,why=V.require('StadiumRom').open(table.concat(chunks))
 chunks=nil
 if not rom then return nil,why end
 if rom:modelCount()<I.COUNT then return nil,'ROM has no complete model archive' end
 local generation=(I.active and I.active.generation or 0)+1
 local staging={format='DSM3',rev=I.REV,count=I.COUNT,md5=I.MD5,
  generation=generation,root='stadium/g'..generation}
 I.staging=staging
 I.job=V.require('StadiumBuild').job(rom,function(dex,bytes)
  if type(dex)~='number' or dex%1~=0 or dex<1 or dex>I.COUNT
     or type(bytes)~='string' or #bytes<6 or bytes:sub(1,4)~='DSM3'
     or bytes:byte(5)+256*bytes:byte(6)~=dex then
   return nil,'extractor returned an invalid model'
  end
  return cache:write(('%s/%03d.dsm'):format(staging.root,dex),bytes)
 end,I.COUNT)
 I.status={state='building',done=0,total=I.COUNT}
 return true
end
function I.step()
 local job=I.job
 if not job then return false end
 local ok,more=pcall(job.step,job)
 I.status.done=job.done or 0
 if not ok then abort('failed',tostring(more));return false end
 if more then return true end
 if job.error or #(job.failed or {})>0 or job.done~=I.COUNT then
  abort('failed',job.error or job.lastError or 'incomplete model conversion');return false
 end
 if not valid(I.staging) then abort('failed','incomplete generated model cache');return false end
 local slot=I.staging.generation%2
 local path='stadium/slot-'..slot..'.info'
 local previousBytes=cache:read(path)
 local replaced=previousBytes and decodeRecord(previousBytes)
 local previousRoot=I.active and I.active.root
 local record=('DSM3 %d %d %s %d\n'):format(I.REV,I.COUNT,I.MD5,I.staging.generation)
 local newRoot=I.staging.root
 local wrote,err=cache:write(path,record)
 if not wrote then abort('failed',err or 'could not commit model cache');return false end
 I.job=nil;I.staging=nil
 if not I.restore() or I.active.root~=newRoot then
  clean(newRoot);I.status.state='failed';I.status.error='could not verify committed model cache'
  return false
 end
 if replaced and valid(replaced) and replaced.root~=previousRoot
     and replaced.root~=I.active.root then clean(replaced.root) end
 return false
end
function I.cancel()
 if I.job then abort(I.ready() and 'ready' or 'cancelled')end
end
function I.open(game)
 local Strings=require('src.core.Strings')
 local Chrome=require('src.ui.gen2.Chrome')
 local Font=require('src.render.Font')
 local ok,err
 if I.ready() then ok=true else ok,err=I.begin() end
 if not ok and V.mod.log then V.mod.log:info('Stadium import: %s',tostring(err)) end
 local state={isOpaque=true}
 function state:update()
  if game.input:wasPressed('b') then I.cancel();game.stack:pop();return end
  if I.status.state=='building' then
   I.step()
   if I.status.state=='ready' and V.refreshSettings then V.refreshSettings()end
  elseif game.input:wasPressed('select') then ok,err=I.begin()
  elseif game.input:wasPressed('a') then game.stack:pop()end
 end
 local function draw()
  local function lines(text,x,y)
   for line in text:gmatch('[^\n]+')do Font.draw(line,x,y);y=y+16 end
  end
  Chrome.paletteFill(0,0,160,144)
  Font.draw(Strings('STADIUM MODELS'),8,8)
  if not ok then
   lines(Strings('Import Pokemon\nStadium US 1.0 in\nthe launcher MODS\nimports panel.'),8,40)
  elseif I.status.state=='building' then
   Font.draw(Strings('BUILDING MODELS'),8,40)
   Font.draw(('%d/%d'):format(I.status.done,I.COUNT),8,64)
  elseif I.status.state=='ready' then
   Font.draw(Strings('MODELS READY'),8,40)
   Font.draw(Strings('SELECT:REBUILD'),8,112)
  else
   lines(Strings('Model build failed.\nCheck free storage\nand import again.'),8,40)
  end
  Font.draw(I.status.state=='building' and Strings('B:CANCEL') or Strings('A/B:BACK'),8,128)
 end
 function state:draw()draw()end
 function state:drawsWidescreen()return true end
 function state:drawWidescreen(w,h)
  Chrome.withPanel(w,h,1,1,1,draw,Chrome.fitScale(w,h))
 end
 game.stack:push(state)
 return state
end
function I.row()
 local Strings=require('src.core.Strings')
 return {id='GEN2_VOXEL:stadiumImport',label=Strings('STADIUM MODELS'),
  value=function()return I.ready() and Strings('READY') or Strings('BUILD')end,
  activate=I.open}
end
return I
