local root = arg[1] or "mods/gen2/new_mod_ex"
package.preload["src.core.Strings"] = function() return function(s) return s end end
local stored, available = "gen5_b2w2", false
local provider = {apiVersion=2, capabilities={contract="national-dex-battle-sprites"},
 frame=function() end,
 status=function(source) assert(source=="gen5_bw"); return {ready=available} end}
local V={mod={options={get=function() return stored end},find=function() return {exports=provider} end}}
V.require=function(name) if name=="ImportedBattleSprites"then return provider end;return assert(loadfile(root.."/lib/"..name..".lua"))(V) end
local B=V.require("BattleSprites")
assert(#B.setting.values==2, "unsupported B2W2 must not be offered")
assert(B.setting:get()=="native", "stale B2W2 settings migrate to native")
assert(B.register("gen5_b2w2", "unsupported", provider)==false, "registration must not restore B2W2")
B.setting:setValue("gen5_bw")
local row=B.setting:row()
assert(row.value():find("IMPORT",1,true), "OPTIONS must explain missing BW import")
local schema=B.setting:schema("Optional artwork.")
assert(schema.help:find("IMPORTERS",1,true) and schema.help:find("Black / White",1,true),
 "mod configuration explains which ROM to import and where")
assert(schema.choices[2][1]:find("IMPORT",1,true), "choice itself identifies missing import")
available=true
assert(row.value()=="BLACK/WHITE", "imported BW choice has its normal label")
assert(B.setting:schema("").choices[2][1]=="BLACK/WHITE", "schema updates after importing")
V.mod.find=function() error("must not need a companion")end
assert(B.unavailableReason()==nil,"import works without a companion")
print("battle sprite configuration tests passed")
