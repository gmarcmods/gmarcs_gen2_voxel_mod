-- Targeted merge: retain all unrelated hand-edited assets in the project.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local batch=dofile(dir..'/route_gate.lua')
local function select(file,tileset,ids)
 local source=dofile(dir..'/'..file..'.lua').tilesets[tileset]
 local target={assets={}};batch.tilesets[tileset]=target
 for _,a in ipairs(source.assets)do if ids[a.id] then target.assets[#target.assets+1]=a end end
end
select('interiors','TILESET_LAB',{lab_worktable=true})
select('pokecenter','TILESET_POKECENTER',{center_computer=true,center_healing_machine=true})
return batch
