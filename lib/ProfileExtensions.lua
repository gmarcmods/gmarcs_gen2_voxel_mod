-- Additive region profiles. A companion owns new names, never native content.
local V = ...
local Classes = V.require('ClassDefinitions')
local Surface = V.require('AssetSurface')
local Extensions = {apiVersion=1}
local function copy(v)
  if type(v)~='table'then return v end
  local r={}for k,x in pairs(v)do r[k]=copy(x)end return r
end
local function integer(n,lo,hi)
  assert(type(n)=='number'and n==n and n%1==0 and n>=lo and n<=hi,'invalid voxel extension integer')
end
local function keys(t,allowed)
  assert(type(t)=='table','extension record must be a table')
  for k in pairs(t)do assert(allowed[k],'unknown extension field: '..tostring(k))end
end
local function prefix(value,p)
  return type(value)=='string'and value:sub(1,#p)==p
end
local function list(t)
  assert(type(t)=='table','expected extension list')
  local n=0 for k in pairs(t)do integer(k,1,65537);n=math.max(n,k)end
  for i=1,n do assert(t[i]~=nil,'extension list has holes')end
  return n
end
local function validateAsset(a)
  keys(a,{id=true,tiles=true,topRows=true,map=true,groundTile=true,surfaces=true,voxelEdits=true,cutFloor=true,support=true,border=true,lodTree=true})
  assert(type(a.id)=='string'and a.id~='','asset needs id')
  if a.map~=nil then assert(type(a.map)=='string'and a.map~='','invalid asset map')end
  local h=list(a.tiles);integer(h,1,32)
  local w=list(a.tiles[1]);integer(w,1,32)
  local function rows(t)
    for _,row in ipairs(t)do assert(list(row)==w,'uneven tile grid');for _,id in ipairs(row)do integer(id,0,255)end end
  end
  rows(a.tiles)
  local top=0
  if a.topRows then top=list(a.topRows);integer(top,1,32);rows(a.topRows)end
  local W,H=w*8,(h+top)*8;integer(H,1,256)
  if a.groundTile~=nil then integer(a.groundTile,0,255)end
  if a.cutFloor~=nil then assert(type(a.cutFloor)=='boolean','invalid cutFloor flag')end
  if a.support~=nil then integer(a.support,0,128)end
  if a.border~=nil then assert(type(a.border)=='boolean','invalid border flag')end
  if a.lodTree~=nil then assert(type(a.lodTree)=='boolean'and (not a.lodTree or a.border==true),'tree LOD requires border placement')end
  assert(list(a.surfaces)>0,'asset needs a surface')
  local candidates=0
  for _,s in ipairs(a.surfaces)do
    keys(s,{rect=true,orientation=true,height=true,depth=true,z=true})
    assert(list(s.rect)==4,'source rectangle needs four integers')
    integer(s.rect[1],0,W-1);integer(s.rect[2],0,H-1)
    integer(s.rect[3],1,W-s.rect[1]);integer(s.rect[4],1,H-s.rect[2])
    assert(s.orientation=='vertical'or s.orientation=='horizontal','invalid surface orientation')
    integer(s.height or 0,-128,128);integer(s.depth or 1,1,32);integer(s.z or 0,-128,128)
    candidates=candidates+s.rect[3]*s.rect[4]*(s.depth or 1)
    assert(candidates<=1000000,'surface work budget exceeded')
  end
  assert(list(a.voxelEdits or{})<=65537,'too many asset edits')
  for _,e in ipairs(a.voxelEdits or{})do
    keys(e,{x=true,y=true,z=true,i=true,remove=true,region=true})
    integer(e.x,-128,383);integer(e.y,-128,383);integer(e.z,-128,383)
    if e.remove~=nil then assert(type(e.remove)=='boolean','invalid remove flag')end
    if not e.remove then integer(e.i,0,W*H-1)end
    if e.region then integer(e.region,1,#a.surfaces)end
  end
  local model=Surface.build(W,H,a.surfaces,a.voxelEdits,false)
  assert(#model.cells>0 and #model.cells<=65536,'empty or oversized extension asset')
end

local CONFIG={heights=true,art=true,when_above=true,when_below=true,terrain_edges=true,mountain=true,
 border_blocks=true,prop_ground=true,prop_bg=true,planter_spray=true,bookcase_relief=true,bookcase_backfill=true}
local function config(entry,known)
 for field,value in pairs(entry)do if CONFIG[field]then
  if field=='heights'or field=='art'then
   assert(type(value)=='table','invalid '..field)
   for class,v in pairs(value)do
    assert(known(class),'unknown configured class')
    if field=='heights'then integer(v,-128,128)else assert(Classes.ART_MODES[v],'unknown art mode')end
   end
  elseif field=='terrain_edges'then
   local ok,err=V.require('TerrainEdges').validate(value);assert(ok,err);assert(known(value.shoreClass),'unknown shore class')
  elseif field=='mountain'then
   local ok,err=V.require('MountainShape').validate(value);assert(ok,err)
   for _,name in ipairs(value.classes)do assert(known(name),'unknown mountain class')end
  elseif field=='when_above'or field=='when_below'then
   assert(type(value)=='table','invalid contextual rules');local side=field=='when_above'and'above'or'below'
   for tile,rules in pairs(value)do
    integer(tile,0,255);list(rules)
    for _,rule in ipairs(rules)do
     keys(rule,{class=true,[side]=true});assert(known(rule.class),'unknown contextual class');list(rule[side])
     for _,neighbor in ipairs(rule[side])do integer(neighbor,0,255)end
    end
   end
  elseif field=='border_blocks'then
   assert(type(value)=='table','invalid border blocks')
   for map,block in pairs(value)do assert(type(map)=='string'and map~='','invalid border map');if block~=false then integer(block,0,255)end end
  elseif field=='prop_ground'then
   assert(type(value)=='table','invalid prop ground');for tile,ground in pairs(value)do integer(tile,0,255);integer(ground,0,255)end
  elseif field=='prop_bg'then
   list(value)
   for _,rule in ipairs(value)do
    keys(rule,{tiles=true,shades=true});list(rule.tiles);list(rule.shades)
    for _,tile in ipairs(rule.tiles)do integer(tile,0,255)end
    for _,shade in ipairs(rule.shades)do assert(shade=='black'or shade=='dark'or shade=='light'or shade=='white','invalid prop background shade')end
   end
  elseif field=='planter_spray'then assert(value==false,'set planter_spray=false to disable; omit for native default')
  elseif field=='bookcase_backfill'then assert(value==false or value=='above','invalid bookcase backfill')
  else assert(type(value)=='boolean','invalid '..field)end
 end end
end

function Extensions.new(base,builtins,invalidate)
  assert((type(base)=='table'or type(base)=='function')and type(builtins)=='table','base profile and builtin classes required')
  -- The authored profile is large. Share untouched immutable branches instead
  -- of cloning hundreds of thousands of native voxel edits for each addon.
  local original=type(base)=='table'and base or nil;local current=original;local entries={}
  local function ensureBase()
    if not original then
      original=base();assert(type(original)=='table','base loader must return a profile');current=original
    end
  end
  local self={apiVersion=1}
  local function compose(candidate)
    ensureBase()
    local result={}for k,v in pairs(original)do result[k]=v end
    for _,section in ipairs({'classes','tilesets','buildings'})do
      result[section]={}for k,v in pairs(original[section]or{})do result[section][k]=v end
    end
    local ids={}for id in pairs(candidate)do ids[#ids+1]=id end table.sort(ids)
    for _,id in ipairs(ids)do
      local spec=candidate[id]
      keys(spec,{schema=true,tilesetPrefix=true,classPrefix=true,classes=true,tilesets=true,buildings=true})
      assert(spec.schema=='voxel.extension.v1','unsupported voxel extension schema')
      assert(type(spec.tilesetPrefix)=='string'and spec.tilesetPrefix:match('^[%a_][%w_]*_$'),'tileset namespace must end in underscore')
      assert(type(spec.classPrefix)=='string'and spec.classPrefix:match('^[%a_][%w_]*_$'),'class namespace must end in underscore')
      assert(type(spec.classes)=='table'and type(spec.tilesets)=='table'and type(spec.buildings)=='table','extension sections required')
      for name,definition in pairs(spec.classes)do
        assert(prefix(name,spec.classPrefix)and not result.classes[name],'class ownership conflict: '..tostring(name))
        local ok,err=Classes.validate(name,definition,builtins);assert(ok,err)
        result.classes[name]=copy(definition)
      end
      local tilesets={}
      for ts in pairs(spec.tilesets)do tilesets[ts]=true end
      for ts in pairs(spec.buildings)do tilesets[ts]=true end
      for ts in pairs(tilesets)do
        assert(prefix(ts,spec.tilesetPrefix),'tileset outside extension namespace: '..tostring(ts))
        assert(result.tilesets[ts]==nil and result.buildings[ts]==nil,'tileset ownership conflict: '..ts)
        local pins=spec.tilesets[ts]or{};assert(type(pins)=='table','invalid class pins')
        local seenTiles={}
        local function known(name)return builtins[name]~=nil or spec.classes[name]~=nil end
        for class,tiles in pairs(pins)do
         if not CONFIG[class]then
          assert(known(class),'pin references unknown class: '..tostring(class))
          list(tiles)
          for _,tile in ipairs(tiles)do integer(tile,0,255);assert(not seenTiles[tile],'tile pinned twice');seenTiles[tile]=true end
         end
        end
        config(pins,known)
        local assets=spec.buildings[ts]or{};list(assets);local seen={}
        for _,a in ipairs(assets)do validateAsset(a);assert(not seen[a.id],'duplicate extension asset');seen[a.id]=true end
        result.tilesets[ts]=copy(pins);result.buildings[ts]=copy(assets)
      end
    end
    return result
  end
  local function commit(candidate)
    local merged=compose(candidate);local previous=current
    current=merged
    if invalidate then
      local ok,err=pcall(invalidate,merged)
      if not ok then current=previous;pcall(invalidate,previous);error(err,0)end
    end
    entries=candidate
  end
  function self:register(id,spec)
    assert(type(id)=='string'and id:match('^[%w_.-]+$'),'invalid extension id')
    local candidate=copy(entries);candidate[id]=copy(spec);commit(candidate);return true
  end
  function self:remove(id)
    if not entries[id]then return false end
    local candidate=copy(entries);candidate[id]=nil;commit(candidate);return true
  end
  function self:current()ensureBase();return current end
  function self:list()
    local ids={}for id in pairs(entries)do ids[#ids+1]=id end table.sort(ids);return ids
  end
  return self
end
return Extensions
