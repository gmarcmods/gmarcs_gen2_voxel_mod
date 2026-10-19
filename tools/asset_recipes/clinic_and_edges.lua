local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local batch={tilesets={}}
for _,name in ipairs({'clinic_details','low_route_edges'})do
 for id,change in pairs(dofile(dir..'/'..name..'.lua').tilesets)do batch.tilesets[id]=change end
end
return batch
