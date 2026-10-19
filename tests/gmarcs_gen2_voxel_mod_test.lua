-- Standalone: luajit mods/gen2/new_mod_ex/tests/gmarcs_gen2_voxel_mod_test.lua
-- Loads the mod through the real headless loader and asserts it boots clean.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = require("src.core.Data")
Data:load()

local run = T.sdk.loadMod("mods/voxel_mod", { data = Data, generation = 2 })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")
T.eq(run.mod and run.mod.state, "loaded", "reached the loaded state")

run.release()
T.finish("gmarcs_gen2_voxel_mod")
