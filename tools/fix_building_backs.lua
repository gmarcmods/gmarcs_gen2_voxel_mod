-- Usage: luajit tools/fix_building_backs.lua INPUT_PROFILE OUTPUT_PROFILE
-- Only source texels on existing ordinary rear-wall voxels are changed.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local input,output=assert(arg[1]),assert(arg[2])
assert(input~=output,'write a separate reviewable profile first')
local profile=assert(loadfile(input))()
local backs=dofile(dir..'/asset_recipes/building_backs.lua')
local count,changed,total=0,0,0
for _,spec in ipairs({{'TILESET_JOHTO','johto_building_patterns'}, {'TILESET_JOHTO_MODERN','modern_building_patterns'}}) do
 local rows={}
 for _,p in ipairs(dofile(dir..'/asset_recipes/'..spec[2]..'.lua')) do rows[p.id]=p.roofRows end
 rows.modern_department_store=rows.modern_building_12
 rows.johto_mahogany_north_house=0;rows.modern_north_house=0
 for _,a in ipairs(profile.buildings[spec[1]] or {}) do
  local roof=rows[a.id]
  if roof~=nil and a.surfaces and a.voxelEdits then
   local n=backs(a,roof)
   if n>0 then print(a.id..': '..n..' rear texels');count=count+1;changed=changed+n end
  end
 end
end
for _,assets in pairs(profile.buildings) do total=total+#assets end
assert(count>0,'no matching authored backs found')
local E=dofile(dir..'/EditorModel.lua')
local text=E.new(profile):serialize(profile)
local result=assert(loadstring(text,'@rear-wall-verification'))()
local function equal(a,b)
 assert(type(a)==type(b),'serialization type mismatch')
 if type(a)~='table' then assert(a==b,'serialization value mismatch');return end
 for k,v in pairs(a) do equal(v,b[k]) end
 for k in pairs(b) do assert(a[k]~=nil,'unexpected field') end
end
equal(profile,result)
local f=assert(io.open(output,'wx'));assert(f:write(text));assert(f:close())
print(('Verified all fields; %d assets retained, %d backs and %d texels changed.'):format(total,count,changed))
