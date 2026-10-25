local root=arg[1]or'mods/gen2/new_mod_ex'
local s=dofile(root..'/data/cherrygrove_terraces.lua')
local mesh=dofile(root..'/lib/TerraceMesh.lua').build(s,128,128,16)
assert(mesh.voxels==s.voxels and #mesh<2000,'shared static model must remain bounded')
local seen={}
for _,q in ipairs(mesh)do
 local x,y=q.texel%32,math.floor(q.texel/32);seen[q.face]=true
 assert(q.u>0 and q.u<1 and q.v>0 and q.v<1)
 for _,p in ipairs(q)do assert(p[1]>=0 and p[1]<=32 and p[2]>=0 and p[2]<=s.height and p[3]>=0 and p[3]<=32)end
 if q.face~='top'then assert(y>=24 and y<32,'sides must use the stone border, never the dithered shadow')
 elseif q[1][2]==s.height then assert(y>=32 and y<40 and x<8,'plateau cap must use native ground texels at 1:1 scale')end
end
for _,f in ipairs({'top','south','north','west','east'})do assert(seen[f],'missing terrace face')end
local height={}
for _,r in ipairs(s.runs)do for dx=0,r[4]-1 do local k=r[3]*32+r[1]+dx;height[k]=math.max(height[k]or 0,r[2]+1)end end
assert(height[16*32+16]==s.height and height[16*32]==2,'flat cap and tapered rim lost')
assert(not height[0],'native corner bevel must not become a full cube')
print('TERRACE MATERIALS PASS: separate ground and rim UVs, no repeated side texture, bounded native mesh')
