local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/tools/asset_recipes/') or '.'
local align=dofile(root..'/tools/asset_recipes/players_room_alignment.lua')
local function copy(v)
 if type(v)~='table' then return v end
 local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r
end
return function(profile)
 local aligned={}
 for _,a in ipairs(align(profile).tilesets.TILESET_PLAYERS_ROOM.assets) do aligned[a.id]=a end
 local assets={}
 -- This complete central table must win before its shared bottom-row pattern.
 for _,a in ipairs(profile.buildings.TILESET_PLAYERS_ROOM) do
  if a.id=='players_room_table' then assets[#assets+1]=copy(a) end
 end
 for _,a in ipairs(profile.buildings.TILESET_PLAYERS_ROOM) do
  if a.id=='players_room_computer' or a.id=='radio' or a.id=='table_legs' then
   local n=copy(aligned[a.id] or a)
   if not n.playersRoomWallDesk then
    -- Desk source is at z=32; the thin wall ends at z=2.
    for _,s in ipairs(n.surfaces) do s.z=(s.z or 0)-30 end
    for _,e in ipairs(n.voxelEdits or {}) do e.z=e.z-30 end
    if n.id=='players_room_computer' then
     local lid,monitor,keyboard,base=unpack(n.surfaces)
     monitor.depth=10;keyboard.z=monitor.z+10;base.depth=16
     n.voxelEdits=n.voxelEdits or {}
     -- Continue the lid's last source row over the deeper CRT enclosure.
     for z=lid.z+4,lid.z+9 do for x=0,15 do
      n.voxelEdits[#n.voxelEdits+1]={x=x,y=lid.height,z=z,i=48+x,region=1}
     end end
    end
    n.playersRoomWallDesk=true
   end
   assets[#assets+1]=n
  end
 end
 return {tilesets={TILESET_PLAYERS_ROOM={assets=assets}}}
end
