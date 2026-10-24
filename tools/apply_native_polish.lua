-- Reproducible offline repair; never read or edit the fallback profile.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')
local input,output=assert(arg[1]),assert(arg[2]);assert(input~=output)
local p=dofile(input)
local tree=dofile(dir..'/asset_recipes/small_tree_cleanup.lua')
local roof=dofile(dir..'/asset_recipes/pagoda_roof_materials.lua')
local n,r,total=0,0,0
local changed={}
for _,list in pairs(p.buildings)do for _,a in ipairs(list)do
 total=total+1;if tree(a)then n=n+1;changed[#changed+1]=a.id end;if roof(a)then r=r+1;changed[#changed+1]=a.id end
end end
assert(n==5 and r==3 and total==441,'unexpected authored inventory')
local E=dofile(dir..'/EditorModel.lua');local text=E.new(p):serialize(p)
-- Replace only the selected edit fields; retain unrelated hand formatting.
local f=assert(io.open(input,'rb'));local original=f:read('*a');f:close()
local function field(source,id)
 local at=assert(source:find('value["id"] = "'..id..'";',1,true),'missing asset '..id)
 local first=assert(source:find('value["voxelEdits"] = ',at,true))
 local _,last=assert(source:find('return v end)();',first,true))
 return first,last
end
local result=original
table.sort(changed)
for _,id in ipairs(changed)do
 local a,b=field(result,id);local c,d=field(text,id)
 result=result:sub(1,a-1)..text:sub(c,d)..result:sub(b+1)
end
text=result
local decoded=assert(loadstring(text))()
local function equal(a,b)
 assert(type(a)==type(b));if type(a)~='table'then assert(a==b);return end
 for k,v in pairs(a)do equal(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
equal(p,decoded)
local f=assert(io.open(output,'wx'));assert(f:write(text));assert(f:close())
print('NATIVE POLISH: five connected small trees, three roof material repairs, 441 assets preserved')
