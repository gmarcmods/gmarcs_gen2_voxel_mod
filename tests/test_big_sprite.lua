local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/tests/')
package.loaded['src.render.Assets']={image=function()return {getDimensions=function()return 16,48 end}end,register=function()end}
local renderer=assert(loadfile(root..'/lib/Voxel3D.lua'))({require=function(n)if n=='Mat4'then return dofile(root..'/lib/Mat4.lua')end;return{}end})
renderer.newMesh=function(v,i)
 for _,index in ipairs(i)do assert(index>=1 and index<=#v,'big sprite has invalid triangle indices')end
 return {vertices=v,indices=i}
end
local V={require=function()return renderer end}
local B=assert(loadfile(root..'/lib/SpriteBillboards.lua'))(V)
local mesh=assert(B.mesh({id='SPRITE_BIG_SNORLAX',image='snorlax',frames=3},0))
assert(#mesh.vertices==16,'big Snorlax must include both stacked frames and their mirrored halves')
local minX,maxX,maxY=100,0,0
for _,p in ipairs(mesh.vertices)do minX=math.min(minX,p[1]);maxX=math.max(maxX,p[1]);maxY=math.max(maxY,p[2])end
assert(maxX-minX==32 and maxY==32,'Snorlax lost its native 32px silhouette')
assert(mesh.vertices[5][4]>mesh.vertices[6][4],'right half must mirror the source art')
print('Big Snorlax: full native symmetric 32x32 sprite PASS')

local x,z=B.anchor({id='SPRITE_BIG_SNORLAX'},100,200)
assert(x==108 and z==216,'large NPC still pivots from the north cell and leans through the cave behind it')
