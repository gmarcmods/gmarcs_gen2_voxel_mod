-- Keep native sprite roofs separate from unchanged authored facades.
local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/tests/')
local profile=dofile(root..'/data/voxel_heights.lua')
local generated={}
for _,a in ipairs(dofile(root..'/tools/asset_recipes/kanto_architecture.lua'))do generated[a.id]=a end
local count=0
local function same(a,b)
 assert(type(a)==type(b),'field type changed')
 if type(a)~='table'then assert(a==b,'field changed');return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,'unexpected field')end
end
for _,a in ipairs(profile.buildings.TILESET_KANTO)do if a.tiles[1][1]==5 and a.voxelEdits then
 local c=assert(a.spriteRoof,a.id..' lacks sprite roof')
 assert(c.rows>=16 and c.slab==4 and c.overhang==4,a.id..' lost Gen 1 roof rules')
 same(c,assert(generated[a.id]).spriteRoof)
 for _,v in ipairs(a.voxelEdits)do
  assert(v.remove or v.y<c.wallHeight,a.id..' retains an old roof underneath the new roof')
 end
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
    local walls={}
    for _,v in ipairs(a.voxelEdits)do if v.remove or v.y<b.spriteRoof.wallHeight then walls[#walls+1]=v end end
    same(walls,b.voxelEdits)

   else same(a,b)end
   total=total+1
  end
 end
 assert(total==441);print('All 441 assets retained; facades, flat roofs, classes and unrelated geometry unchanged PASS')
end
print('Kanto roofs: '..count..' sprite-silhouette roofs, old roof geometry removed PASS')
