-- Repair placement without replacing the user's sculpted radio or desk.
local function copy(v)
  if type(v)~='table' then return v end
  local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r
end
return function(profile)
  local assets={}
  -- The desk begins at map pixel z=32. Computer and radio sprites begin
  -- at z=8 and z=16 respectively; their geometry must move onto its top.
  for _,a in ipairs(assert(profile.buildings.TILESET_PLAYERS_ROOM)) do
    local dz=({players_room_computer=24,radio=16})[a.id]
    if dz then
      local n=copy(a)
      if not n.playersRoomDeskAligned then
        for _,s in ipairs(n.surfaces) do s.height=(s.height or 0)+8;s.z=(s.z or 0)+dz end
        for _,e in ipairs(n.voxelEdits or {}) do e.y=e.y+8;e.z=e.z+dz end
        n.playersRoomDeskAligned=true
      end
      assets[#assets+1]=n
    end
  end
  -- Match full columns first; the remaining singles are the upper row
  -- above the computer/cabinet. Both start at the same map depth and have
  -- the same 2px thickness. Repeat the wall texels to retain its 32px height.
  for _,count in ipairs({2,1}) do
    local a={id=count==2 and 'players_room_wall_pair' or 'players_room_wall_single',tiles={},surfaces={}}
    for i=1,count do a.tiles[i]={2} end
    a.surfaces={{rect={0,0,8,8},orientation='vertical',height=0,depth=2,z=0}}
    a.voxelEdits={}
    -- A source pixel belongs to only one surface; repeated wall courses
    -- therefore use explicit copied texels, as furniture's rear legs do.
    for y=8,31 do for x=0,7 do for z=0,1 do
      a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=(7-y%8)*8+x,region=1}
    end end end
    assets[#assets+1]=a
  end
  return {tilesets={TILESET_PLAYERS_ROOM={assets=assets}}}
end
