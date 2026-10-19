-- The document's destination belongs to the session, not the running mod.
-- Inject dependencies so project transitions can be tested without LÖVE.
return function(Model, Storage)
  local Session = {}
  Session.__index = Session

  function Session.new(path, profile, label)
    local self = setmetatable({}, Session)
    self:activate(path, profile, label)
    return self
  end

  function Session:activate(path, profile, label)
    self.path = path
    self.label = label or path:match('([^/]+)/*$') or path
    self.model = Model.new(profile)
    self.saved = self.model.snapshot and self.model:snapshot() or self.model:serialize()
  end

  local function same(a,b,seen)
    if a==b then return true end
    if type(a)~='table' or type(b)~='table' then return false end
    seen=seen or {}
    if seen[a]==b then return true end
    seen[a]=b
    for k,v in pairs(a) do if not same(v,b[k],seen) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
  end

  function Session:isDirty()
    -- Saved snapshots are immutable. Compare content only after a document
    -- change; opening a project needs neither a copy nor encoded Lua source.
    local model=self.model
    if not model.snapshot then
      local ok,current=pcall(model.serialize,model)
      return not ok or current~=self.saved
    end
    local ok,spec=pcall(model.snapshot,model)
    if not ok then return true end
    local cache=self._dirtyCache
    if cache and cache.model==model and cache.spec==spec and cache.saved==self.saved then return cache.dirty end
    local compared,equal=pcall(same,spec,self.saved)
    local dirty=not compared or not equal
    self._dirtyCache={model=model,spec=spec,saved=self.saved,dirty=dirty}
    return dirty
  end

  function Session:save()
    local ok, spec = pcall(self.model.fuse, self.model)
    if not ok then return false, tostring(spec) end
    local encoded, content = pcall(self.model.serialize, self.model, spec)
    if not encoded then return false, tostring(content) end
    local called, saved, err = pcall(Storage.saveProfile, self.path, spec,
      function() return content end)
    if not called then return false, tostring(saved) end
    if not saved then return false, err end
    self.saved = self.model.snapshot and spec or content
    return true
  end

  function Session:open(path, discard, label)
    if self:isDirty() and not discard then return false, 'Unsaved changes' end
    local profile, err = Storage.loadProfile(path)
    if not profile then return false, err end
    -- Validate the new document before replacing the active one.
    local ok, prepared = pcall(Session.new, path, profile, label)
    if not ok then return false, tostring(prepared) end
    self.path, self.label = prepared.path, prepared.label
    self.model, self.saved = prepared.model, prepared.saved
    return true
  end

  function Session:create(parent, name, gameId, world, sourcePath, discard)
    if self:isDirty() and not discard then return false, 'Unsaved changes' end
    local path, err = Storage.createMod(parent, name, gameId, world, sourcePath)
    if not path then return false, err end
    return self:open(path, true, name)
  end

  function Session:createInDirectory(path, sourcePath, world, discard)
    if self:isDirty() and not discard then return false, 'Unsaved changes' end
    local created, err = Storage.createInDirectory(path, sourcePath, world)
    if not created then return false, err end
    return self:open(created, true)
  end

  function Session:saveAs(parent, name, gameId, world, sourcePath)
    -- Keep the original active if either scaffolding or writing fails.
    local profile = self.model:fuse()
    local path, err = Storage.createMod(parent, name, gameId, world, sourcePath)
    if not path then return false, err end
    local target = Session.new(path, profile, name)
    local ok
    ok, err = target:save()
    if not ok then return false, err end
    self.path, self.label = target.path, target.label
    self.model, self.saved = target.model, target.saved
    return true
  end

  function Session:saveAsInDirectory(selectedPath, sourcePath, world)
    -- Prepare and validate the complete edited document before creating the
    -- selected project.  A failed transition must leave this session intact.
    local prepared, content, spec = pcall(function()
      local spec = self.model:fuse()
      if type(spec) ~= "table" then error("fused profile must be a table") end
      local content = self.model:serialize(spec)
      if type(content) ~= "string" then error("serialized profile must be a string") end
      return content, spec
    end)
    if not prepared then return false, tostring(content) end
    local called, created, createErr = pcall(Storage.createInDirectory,
      selectedPath, sourcePath, world)
    if not called then return false, tostring(created) end
    if not created then return false, createErr or "cannot create project" end
    if type(created) ~= "string" then
      return false, "storage returned an invalid project path"
    end

    local saved, saveResult, saveErr = pcall(Storage.saveProfile, created, spec,
      function() return content end)
    if not saved then return false, tostring(saveResult) end
    if not saveResult then return false, saveErr or "cannot save project profile" end

    local label = created:match('([^/]+)/*$') or created
    local modelOk, nextModel = pcall(Model.new, spec)
    if not modelOk then return false, tostring(nextModel) end
    self.path, self.label = created, label
    self.model, self.saved = nextModel, nextModel.snapshot and spec or content
    return true
  end

  return Session
end
