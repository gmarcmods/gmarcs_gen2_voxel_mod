-- Targeted post-audit corrections. Only these assets and terrain settings
-- replace their authored equivalents; all other project work is retained.
local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local batch={tilesets={}}
for _,name in ipairs({'johto','johto_modern','kanto'})do
 local source=dofile(root..'/'..name..'.lua')
 for id,ts in pairs(source.tilesets)do
  local change={mountain=ts.mountain,assets={}}
  for _,a in ipairs(ts.assets)do
   if a.id=='johto_tree' or a.id=='modern_tree' then change.assets[#change.assets+1]=a end
  end
  if name=='kanto' then change.pins={kanto_cliff={18}} end
  batch.tilesets[id]=change
 end
end
local source=dofile(root..'/lighthouse.lua').tilesets.TILESET_LIGHTHOUSE
local change={assets={}}
for _,a in ipairs(source.assets)do
 if a.id=='lighthouse_window' or a.id=='lighthouse_moss_course' then
  change.assets[#change.assets+1]=a
 end
end
batch.tilesets.TILESET_LIGHTHOUSE=change
return batch
