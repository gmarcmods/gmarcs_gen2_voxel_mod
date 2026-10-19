-- Headless metadata only. Never writes cache/assets or copies a ROM.
-- luajit voxel_mod/tools/spanish/export.lua ENGINE EN_ROM ES_ROM OUTPUT_JSON
local engine,en,es,output=assert(arg[1]),assert(arg[2]),assert(arg[3]),assert(arg[4])
package.path=engine..'/?.lua;'..package.path
local J=require('src.link.Json');local E=require('src.import.RomExtractorGen2')
local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local edition=arg[5] or 'gold'
assert(edition=='gold' or edition=='silver' or edition=='crystal')
local manifest=assert(J.decode(read(engine..'/tools/rom_manifest_'..edition..'.json')))
local result={}
for _,pair in ipairs({{'en',en},{'es',es}}) do
 local extractor=E.new(read(pair[2]),manifest,nil,pair[1]=='en' and arg[6] or nil)
 extractor.extractRoofs=function() end
 extractor.write=function() end
 local maps=extractor:extractMaps()
 for _,map in pairs(maps) do
  -- Json arrays would discard zero-based scene 0; export as an object.
  local scenes={};for id,scene in pairs(map.sceneScripts or {}) do scenes[tostring(id)]=scene end
  map.sceneScripts=scenes
 end
 result[pair[1]]=maps
 result[pair[1]..'_std']=extractor:extractStdScripts()
end
local ops={};for id,info in pairs(require('src.script.gen2.Opcodes').forEdition(edition)) do if type(id)=='number' then ops[tostring(id)]=info end end
result.opcodes=ops
local f=assert(io.open(output,'wb'));assert(f:write(J.encode(result)));assert(f:close())
