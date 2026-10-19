-- Standalone: luajit mods/gen2/new_mod_ex/tests/gmarcs_gen2_voxel_mod_test.lua
-- Loads the mod through the real headless loader and asserts its stated effect.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = require("src.core.Data")
Data:load()

local run = T.sdk.loadMod("mods/voxel_mod", { data = Data, generation = 2 })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")
T.eq(run.mod and run.mod.state, "loaded", "reached the loaded state")
T.eq(run.mod.manifest.id, "gmarcs_gen2_voxel_mod", "mod id is gmarcs_gen2_voxel_mod")

local P = require("src.render.Pipelines")
local hasVoxel, hasTilt = false, false
for _, e in ipairs(P.list()) do
  if e.id == "voxel" then hasVoxel = true end
  if e.id == "tiltshift" then hasTilt = true end
end
T.check(hasVoxel, "registers the voxel render pipeline")
T.check(hasTilt, "registers the tiltshift post-process pipeline")

run.release()
T.finish("gmarcs_gen2_voxel_mod")
