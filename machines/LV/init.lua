unnamed_tech_mod.register_power_node("unnamed_tech_mod:lv_machine", {
    description = "LV Machine",
    tiles = {"default_steel_block.png"},
    groups = {
        cracky = 2,
    },

    net_type = "LV",

    supply = 0,
    demand = 0,
    on_construct = function(pos)
        local timer = core.get_node_timer(pos)
        timer:start(0.1)
        unnamed_tech_mod.set_node_power(core.hash_node_position(pos), 0, 20, 10)

    end,
    on_timer = function(pos)
        return true
    end
})

unnamed_tech_mod.register_power_node("unnamed_tech_mod:lv_generator", {
    description = "LV Generator",
    tiles = {"default_copper_block.png"},
    groups = {
        cracky = 2,
    },

    net_type = "LV",

    supply = 50,
    demand = 0,
})