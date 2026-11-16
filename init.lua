unnamed_tech_mod = {}

local mn = core.get_current_modname()
local mp = core.get_modpath(mn)
local df = function(file)
    return dofile(mp .. "/" .. file)
end

df("power.lua")
df("cables/init.lua")
df("machines/init.lua")

unnamed_tech_mod.register_power_node("unnamed_tech_mod:test_cable", {
    description = "Test Cable",
    net_type = "LV",
})

unnamed_tech_mod.register_power_node("unnamed_tech_mod:test_generator", {
    description = "Test Generator",
    net_type = "LV",
    supply = 100,
})

unnamed_tech_mod.register_power_node("unnamed_tech_mod:test_machine", {
    description = "Test Machine",
    net_type = "LV",
    demand = 40,
})