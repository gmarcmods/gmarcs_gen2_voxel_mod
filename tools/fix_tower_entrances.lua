local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local input,output=assert(arg[1]),assert(arg[2]);assert(input~=output)
local p=assert(loadfile(input))();dofile(dir..'/asset_recipes/tower_entrance_repairs.lua').apply(p)
local E=dofile(dir..'/EditorModel.lua');local text=E.new(p):serialize(p)
local function equal(a,b)
 assert(type(a)==type(b));if type(a)~='table'then assert(a==b);return end
 for k,v in pairs(a)do equal(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local f=assert(io.open(output,'wx'));assert(f:write(text));assert(f:close());equal(p,assert(loadfile(output))())
print('Tower partitions, anchored columns and complete stair flights written and reloaded; full profile verified')
