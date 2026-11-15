unnamed_tech_mod = {}

local mn = core.get_current_modname()
local mp = core.get_modpath(mn)
local df = function(file)
    return dofile(mp .. "/" .. file)
end

df("power.lua")
df("cables/init.lua")
df("machines/init.lua")

