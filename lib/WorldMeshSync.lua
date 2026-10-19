-- Native reloads restore blocks by writing the source buffer directly.
-- Observe that boundary without modifying engine files or save semantics.
local M={}
function M.install(World,changed)
 local dispatch=World.__voxelRestoreBlocks
 if not dispatch then
  dispatch={original=World.restoreBlocks};World.__voxelRestoreBlocks=dispatch
  World.restoreBlocks=function(self,...)
   local edits={}
   for id,rows in pairs(self.blockEdits or{})do
    for index,original in pairs(rows)do edits[#edits+1]={id=id,index=index,block=original}end
   end
   local result=dispatch.original(self,...)
   for _,edit in ipairs(edits)do dispatch.changed(self,edit)end
   return result
  end
 end
 dispatch.changed=changed
end
return M
