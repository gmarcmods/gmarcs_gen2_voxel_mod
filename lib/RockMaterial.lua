-- Johto's mountain drawing separates ground (60), stone rim (76),
-- and rock body (54 rows 2..7). East-edge dithering is a 2D shadow.
local M={};local shapes=setmetatable({},{__mode='k'});local bands={}
function M.shape(map,s)
 if not s or map.tileset.id~='TILESET_JOHTO'or
  (s.class~='johto_cliff'and s.class~='johto_plateau'and s.class~='coastal_platform')then return s end
 local result=shapes[s]
 if not result then
  result={};for k,v in pairs(s)do result[k]=v end
  result.topTile=60;result.rockMaterial=true;shapes[s]=result
 end
 return result
end
function M.bands(bottom,top)
 local key=bottom..':'..top;local result=bands[key]
 if result then return result end
 result={};local y=top
 if y>bottom then
  local h=math.min(8,y-bottom)
  result[#result+1]={y0=y-h,y1=y,tile=76,v0=0,v1=h};y=y-h
 end
 while y>bottom do
  local h=math.min(6,y-bottom)
  result[#result+1]={y0=y-h,y1=y,tile=54,v0=2,v1=2+h};y=y-h
 end
 bands[key]=result;return result
end
return M
