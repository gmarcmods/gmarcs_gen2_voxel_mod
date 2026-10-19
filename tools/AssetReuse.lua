-- Reuse authored geometry only for pixel-identical complete source sprites.
-- Palette differences are allowed; geometry and source-pixel ownership are not.
local R={}
local function copy(t)
  if type(t)~='table' then return t end
  local r={};for k,v in pairs(t) do r[k]=copy(v) end;return r
end
local function gridKey(tiles)
  local rows={};for _,row in ipairs(tiles) do rows[#rows+1]=table.concat(row,',') end
  return table.concat(rows,'/')
end
function R.signatures(data)
  local W,H=data:getDimensions();local perRow=math.floor(W/8);local result={}
  for ty=0,math.floor(H/8)-1 do for tx=0,perRow-1 do
    local bytes={}
    for y=0,7 do for x=0,7 do
      local r,g,b,a=data:getPixel(tx*8+x,ty*8+y)
      bytes[#bytes+1]=string.char(math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5),math.floor(a*255+.5))
    end end
    result[ty*perRow+tx]=table.concat(bytes)
  end end
  return result
end
function R.expand(world,batch,signaturesFor,mapFor)
  local result=copy(batch);local sources,signatures={},{}
  local function signaturesOf(ts)
    if not signatures[ts] then signatures[ts]=signaturesFor(ts) end
    return signatures[ts]
  end
  for ts,change in pairs(batch.tilesets) do for _,asset in ipairs(change.assets or {}) do
    sources[#sources+1]={ts=ts,asset=asset}
  end end
  table.sort(sources,function(a,b) return a.ts..':'..a.asset.id<b.ts..':'..b.asset.id end)
  local existing,ids={},{}
  for ts,change in pairs(result.tilesets) do
    existing[ts]={};ids[ts]={}
    for _,a in ipairs(change.assets or {}) do existing[ts][gridKey(a.tiles)]=true;ids[ts][a.id]=true end
  end
  local maps={};for id in pairs(world.maps) do maps[#maps+1]=id end;table.sort(maps)
  local report={assets=0,placements=0,tilesets={}}
  for _,id in ipairs(maps) do
    local def=world.maps[id];local ts=def.tileset
    if ts and world.tilesets[ts] then
      local map=mapFor(id);local tw,th=map.def.width*4,map.def.height*4
      local target=signaturesOf(ts);local candidates={}
      for y=0,th-1 do for x=0,tw-1 do
        local sig=target[map:tileAt(x,y)]
        if sig then candidates[sig]=candidates[sig] or {};candidates[sig][#candidates[sig]+1]={x,y} end
      end end
      existing[ts]=existing[ts] or {};ids[ts]=ids[ts] or {}
      for _,source in ipairs(sources) do if source.ts~=ts then
        local a=source.asset;local sourceSigs=signaturesOf(source.ts)
        for _,p in ipairs(candidates[sourceSigs[a.tiles[1][1]]] or {}) do
          local x,y=p[1],p[2];local matches=x+#a.tiles[1]<=tw and y+#a.tiles<=th
          local tiles={}
          if matches then
            for row,sourceRow in ipairs(a.tiles) do
              tiles[row]={}
              for col,tile in ipairs(sourceRow) do
                local actual=map:tileAt(x+col-1,y+row-1);tiles[row][col]=actual
                if target[actual]~=sourceSigs[tile] then matches=false;break end
              end
              if not matches then break end
            end
          end
          if matches then
            local key=gridKey(tiles)
            if not existing[ts][key] then
              local reused=copy(a);reused.tiles=tiles
              local suffix=1
              while ids[ts][reused.id] do suffix=suffix+1;reused.id=a.id..'_'..suffix end
              reused.sourceAsset={tileset=source.ts,id=a.id}
              result.tilesets[ts]=result.tilesets[ts] or {}
              local change=result.tilesets[ts];change.assets=change.assets or {}
              change.assets[#change.assets+1]=reused
              existing[ts][key]=true;ids[ts][reused.id]=true
              report.assets=report.assets+1;report.tilesets[ts]=true
              report.placements=report.placements+1
            end
          end
        end
      end end
    end
  end
  return result,report
end
return R
