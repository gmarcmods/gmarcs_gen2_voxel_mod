-- A single authoring transaction for the requested interior/scenery pass.
-- Loading each source recipe keeps its focused tests and independent edits.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local batch={tilesets={}}
for _,name in ipairs({'house','lighthouse','mansion','mart','park','pokecenter',
 'port','radio_tower','ruins_of_alph','tower','traditional_house',
 'train_station','underground'}) do
 local part=dofile(dir..'/'..name..'.lua')
 for id,change in pairs(part.tilesets) do
  assert(not batch.tilesets[id],'duplicate tileset recipe: '..id)
  batch.tilesets[id]=change
 end
end
return batch
