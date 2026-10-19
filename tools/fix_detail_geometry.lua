-- Apply only the named detail repairs to a separate complete authored profile.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local input,output=assert(arg[1]),assert(arg[2]);assert(input~=output)
local p=assert(loadfile(input))();local D=dofile(dir..'/asset_recipes/detail_geometry.lua')
local statues={tower_gym_statue=true,game_gym_statue=true,port_gym_statue=true,station_gym_statue=true,
 underground_gym_statue=true,elite_orb_pedestal=true}
local n=0
for _,list in pairs(p.buildings)do for _,a in ipairs(list)do
 if statues[a.id]then D.southCell(a);n=n+1
 elseif a.id=='tower_lantern'then D.bellsprout(a);n=n+1
 elseif a.id=='johto_fruit_tree' or a.id=='kanto_sapling'then D.cutTree(a);n=n+1 end
end end
p.classes.elite_void.height=-16
local E=dofile(dir..'/EditorModel.lua');local text=E.new(p):serialize(p)
local f=assert(io.open(output,'w'));f:write(text);f:close()
print('Targeted detail geometry:',n,'assets; all other profile fields retained')
