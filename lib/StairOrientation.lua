-- Rotate an eastward flight within its 16px cell to run northward.
-- A quarter turn preserves face winding, UV ownership and tread heights.
return {north=function(p,mx,mz)
 return {mx+p[3]-mz,p[2],mz+16-(p[1]-mx)}
end}
