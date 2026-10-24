local root=arg[1]or'mods/gen2/new_mod_ex'
local before=dofile(root..'/../../../archive/voxel-profile-before-native-polish-1.0.9.lua')
local actual=dofile(root..'/data/voxel_heights.lua')
local trees=dofile(root..'/tools/asset_recipes/small_tree_cleanup.lua')
local roofs=dofile(root..'/tools/asset_recipes/pagoda_roof_materials.lua')
local n,t,r=0,0,0
for _,list in pairs(before.buildings)do for _,a in ipairs(list)do
 n=n+1;if trees(a)then t=t+1 end;if roofs(a)then r=r+1 end
end end
assert(n==441 and t==5 and r==3)
local function equal(a,b)
 assert(type(a)==type(b),'unrelated authored type changed')
 if type(a)~='table'then assert(a==b,'unrelated authored value changed');return end
 for k,v in pairs(a)do equal(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,'unexpected authored field')end
end
equal(before,actual)
print('NATIVE POLISH PRESERVATION PASS: all 441 assets; only five tree cleanups and three roof materials changed')
