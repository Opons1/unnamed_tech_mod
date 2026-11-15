local function df(file)
    dofile(core.get_modpath(core.get_current_modname()) .. "/machines/" .. file)
end
df("recipe.lua")
df("basic_machine.lua")
df("LV/init.lua")