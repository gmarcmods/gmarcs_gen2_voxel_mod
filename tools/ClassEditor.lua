-- A named class reuses a proven renderer primitive with authored dimensions.
local Dialog = {}
Dialog.__index = Dialog

function Dialog.new(model, selected, heights, editing)
  local spec = model:snapshot()
  local original = spec.classes and spec.classes[selected]
  local definition = original and model:deepcopy(original) or {
    base=model.isClass(selected) and selected or 'wall',
    height=heights[selected] or 16,
  }
  return setmetatable({
    original=editing and original and selected or nil,
    definition=definition, name={text=editing and selected or '',focused=true},
    base=definition.base, height=definition.height, art=definition.art,
    bases=model.allClasses(), replacement=definition.base,
  }, Dialog)
end

function Dialog:draw(ui, model, applied, close)
  local G=love.graphics
  local sw,sh=ui:modalOverlay()
  local w,h=math.min(560,sw-24),350
  local x,y=(sw-w)/2,(sh-h)/2
  G.setColor(0.12,0.14,0.18); G.rectangle('fill',x,y,w,h)
  G.setColor(0.9,0.9,0.9)
  G.print(self.deleting and 'Delete custom class' or
    (self.original and 'Edit custom class' or 'New custom class'),x+12,y+12)
  if self.deleting then
    G.printf('All uses of '..self.original..' will use '..self.replacement..'.',x+12,y+42,w-24)
    local choices={}
    for _,name in ipairs(model.allClasses(model:snapshot())) do
      if name~=self.original then choices[#choices+1]={label=name} end
    end
    local picked=ui:choiceList(choices,x+12,y+78,w-24,20,'class_replacement',150)
    if picked then self.replacement=choices[picked].label end
    if ui:button('Delete and reassign',x+12,y+h-34,150,22) then
      local ok,err=model:deleteClass(self.original,self.replacement)
      if ok then applied(self.replacement); close() else self.error=err end
    end
  else
    local committed
    self.name,committed=ui:textInput('Name',x+12,y+35,w-24,self.name)
    ui._textInputState=self.name
    G.setColor(0.9,0.9,0.9)
    G.print('Base shape: '..self.base,x+12,y+84)
    local choices={}
    for _,name in ipairs(self.bases) do choices[#choices+1]={label=name} end
    local picked=ui:choiceList(choices,x+12,y+105,185,20,'class_base',130)
    if picked then self.base=choices[picked].label end
    local value=ui:stepper('Height (voxels)',self.height,x+215,y+105,w-227)
    if value then self.height=math.max(self.base=="void" and -128 or -2,math.min(128,value)) end
    local modes={'default','upright','top','flat'}
    if ui:button('Texture: '..(self.art or 'default'),x+215,y+145,w-227,22) then
      local idx=1
      for i,mode in ipairs(modes) do if mode==self.art then idx=i end end
      self.art=modes[idx % #modes+1]
      if self.art=='default' then self.art=nil end
    end
    local function definition()
      local d=model:deepcopy(self.definition)
      d.base,d.height,d.art=self.base,self.height,self.art
      return d
    end
    if ui:button('Apply',x+12,y+h-34,75,22) or committed then
      local ok,err
      if self.original then
        ok,err=model:editClass(self.original,self.name.text,definition())
      else
        ok,err=model:defineClass(self.name.text,definition())
      end
      if ok then applied(self.name.text); close() else self.error=err end
    end
    if self.original then
      if ui:button('Duplicate',x+98,y+h-34,85,22) then
        local classes=model:snapshot().classes or {}
        local name=self.name.text..'_copy'
        while classes[name] do name=name..'_copy' end
        local ok,err=model:defineClass(name,definition())
        if ok then applied(name); close() else self.error=err end
      elseif ui:button('Delete class',x+194,y+h-34,95,22) then
        self.deleting=true
        self.name.focused=false
      end
    end
  end
  if ui:button('Cancel',x+w-90,y+h-34,78,22) then close() end
  if self.error then
    G.setColor(1,0.65,0.55); G.printf(tostring(self.error),x+12,y+h-85,w-24)
  end
end

return Dialog
