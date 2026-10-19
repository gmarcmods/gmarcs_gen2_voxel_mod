local L={};L.__index=L
function L.new(world,palettes,changed)
 return setmetatable({world=world,palettes=palettes,changed=changed},L)
end
function L:available()
 local w=self.world
 return w.map and self.palettes.daytimeFor and self.palettes.daytimeFor(w.map.def,w.hour and w:hour() or 12,false)=='DARK'
end
function L:toggle()
 if not self:available() then return false end
 local w=self.world;w.flashUsed=not w.flashUsed
 w:applyPalettes();w:refreshMapImages()
 if self.changed then self.changed() end
 return true
end
return L
