-- Usage: luajit tools/fill_forest_canopies.lua INPUT_PROFILE OUTPUT_PROFILE
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local input,output=assert(arg[1]),assert(arg[2]);assert(input~=output)
local p=assert(loadfile(input))()
local stretch=dofile(dir..'/asset_recipes/canopy_depth.lua')
local specs={TILESET_JOHTO={'johto_tree',25,8,23},TILESET_JOHTO_MODERN={'modern_tree',25,8,23},
 TILESET_FOREST={'forest_tree',24,4,27},TILESET_PARK={'park_tree',16,2,29}}
local count=0
for tileset,s in pairs(specs) do
 for _,a in ipairs(p.buildings[tileset]) do if a.id==s[1] then
  stretch(a,s[2],s[3],s[4],0,31);count=count+1
 end end
end
assert(count==4,'all four native forest assets must exist')
local E=dofile(dir..'/EditorModel.lua');local text=E.new(p):serialize(p)
local decoded=assert(loadstring(text,'@canopy-verification'))()
local function equal(a,b)
 assert(type(a)==type(b));if type(a)~='table' then assert(a==b);return end
 for k,v in pairs(a) do equal(v,b[k]) end
 for k in pairs(b) do assert(a[k]~=nil) end
end
equal(p,decoded)
local f=assert(io.open(output,'wx'));assert(f:write(text));assert(f:close())
print('Verified all profile fields; expanded only four existing forest crowns within their native footprints')
