-- Native house roofs must reach a ridge, rather than an eight-pixel plateau.
local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/tests/')
local profile=dofile(root..'/data/voxel_heights.lua')
local generated={}
for _,a in ipairs(dofile(root..'/tools/asset_recipes/kanto_architecture.lua'))do generated[a.id]=a end
local count=0
for _,a in ipairs(profile.buildings.TILESET_KANTO)do if a.tiles[1][1]==5 and a.voxelEdits then
 local w,d=#a.tiles[1]*8,#a.tiles*8;local tops={}
 for _,v in ipairs(a.voxelEdits)do if not v.remove and v.z>=0 and v.z<d then
  local k=v.z*w+v.x;local old=tops[k];if not old or v.y>old.y then tops[k]=v end
 end end
 local recipe=assert(generated[a.id]);local recipeTops={}
 for _,v in ipairs(recipe.voxelEdits)do if not v.remove then
  local k=v.z*w+v.x;local old=recipeTops[k];if not old or v.y>old.y then recipeTops[k]=v end
 end end
 local eave=assert(tops[0]).y
 for x=0,w-1 do for z=0,d-1 do
  local v=assert(tops[z*w+x],a.id..' roof hole')
  assert(v.y==eave+math.min(x,w-1-x,z,d-1-z),a.id..' slope flattens before reaching its ridge at '..x..','..z)
  local g=assert(recipeTops[z*w+x]);assert(g.y==v.y and g.i==v.i,a.id..' recipe differs from installed roof')
  local opposite=tops[(d-1-z)*w+x]
  assert(math.floor(v.i/w)==math.floor(opposite.i/w),a.id..' opposing slopes use different roof bands')
  assert(v.i%w>=16 and v.i%w<24,a.id..' hip samples flat-sprite background/outline')
 end end
 count=count+1
end end
assert(count==13,'pitched roof coverage changed')
if arg[1]then
 local old=dofile(arg[1])
 local function same(a,b)
  assert(type(a)==type(b),'authored field type changed')
  if type(a)~='table'then assert(a==b,'unrelated authored field changed');return end
  for k,v in pairs(a)do same(v,b[k])end
  for k in pairs(b)do assert(a[k]~=nil,'unexpected authored field')end
 end
 for key,v in pairs(old)do if key~='buildings'then same(v,profile[key])end end
 local total=0
 for ts,list in pairs(old.buildings)do
  assert(#profile.buildings[ts]==#list)
  for n,a in ipairs(list)do
   local b=profile.buildings[ts][n]
   if ts=='TILESET_KANTO'and a.tiles[1][1]==5 and a.voxelEdits then
    for key,v in pairs(a)do if key~='voxelEdits'then same(v,b[key])end end
    assert(#a.voxelEdits==#b.voxelEdits,'roof adds hidden solid layers')
    local eave=-math.huge
    for _,v in ipairs(a.voxelEdits)do if not v.remove and v.x==0 and v.z==0 then eave=math.max(eave,v.y)end end
    for i,v in ipairs(a.voxelEdits)do
     local q=b.voxelEdits[i]
     if v.remove or v.y<eave-2 then same(v,q)
     else
      for key,t in pairs(v)do if key~='y'and key~='i'then same(t,q[key])end end
     end
    end
   else same(a,b)end
   total=total+1
  end
 end
 assert(total==441);print('All 441 assets retained; facades, flat roofs, classes and unrelated geometry unchanged PASS')
end
print('Kanto roofs: '..count..' continuous hollow hip roofs, symmetric native textures PASS')
