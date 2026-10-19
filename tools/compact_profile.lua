-- Usage: luajit tools/compact_profile.lua INPUT.lua OUTPUT.lua
-- Writes a new file only; verifies every value before reporting success.
local dir=debug.getinfo(1,'S').source:gsub('^@',''):match('(.*/)') or './'
local E=dofile(dir..'EditorModel.lua')
local input,output=assert(arg[1],'input required'),assert(arg[2],'output required')
assert(input~=output,'choose a separate output file')
local start=os.clock()
local profile=assert(loadfile(input))()
print(string.format('loaded %.3fs, Lua %.1f MB',os.clock()-start,collectgarbage('count')/1024))
local text=E.new(profile):serialize(profile)
local decoded=assert((loadstring or load)(text,'@compact-verification'))()
local function equal(a,b)
 assert(type(a)==type(b),'type mismatch')
 if type(a)~='table' then assert(a==b,'value mismatch');return end
 for k,v in pairs(a) do equal(v,b[k]) end
 for k in pairs(b) do assert(a[k]~=nil,'unexpected key') end
end
equal(profile,decoded)
local f=assert(io.open(output,'wx'));assert(f:write(text));assert(f:close())
print(string.format('verified every field; wrote %d bytes in %.3fs',#text,os.clock()-start))
