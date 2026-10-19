local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local input,output=assert(arg[1]),assert(arg[2]);assert(input~=output)
local p=assert(loadfile(input))()
local clean=dofile(dir..'/asset_recipes/clean_tree_shape.lua');local n=0
for _,list in pairs(p.buildings)do for _,a in ipairs(list)do if clean(a)then n=n+1 end end end
assert(n==4)
local E=dofile(dir..'/EditorModel.lua');local text=E.new(p):serialize(p)
local decoded=assert(loadstring(text))()
local function equal(a,b)
 assert(type(a)==type(b));if type(a)~='table'then assert(a==b);return end
 for k,v in pairs(a)do equal(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
equal(p,decoded)
local f=assert(io.open(output,'wx'));assert(f:write(text));assert(f:close());equal(p,assert(loadfile(output))())
print('Four clean native tree models; complete profile serialized and every decoded field verified')
