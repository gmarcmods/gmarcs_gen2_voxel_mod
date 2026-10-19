-- luajit export_cache.lua ENGINE GOLD_CACHE OUTPUT_JSON
package.path = arg[1] .. "/?.lua;" .. package.path
local Json = require("src.link.Json")
local base = arg[2] .. "/data/" .. "generated/"
local output = assert(io.open(arg[3], "w"))
output:write(Json.encode({dialogue = dofile(base .. "text.lua"), rom_text = dofile(base .. "rom_text.lua"), items = dofile(base .. "items.lua"), moves = dofile(base .. "moves.lua")}))
output:close()
