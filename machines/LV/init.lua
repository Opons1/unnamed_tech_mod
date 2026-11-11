unnamed_tech_mod.register_power_node("unnamed_tech_mod:lv_machine", {
    description = "LV Machine",
    tiles = {"default_steel_block.png"},
    groups = {
        cracky = 2,
    },

    net_type = "LV",

    supply = 0,
    demand = 20,
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