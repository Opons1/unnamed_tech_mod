function unnamed_tech_mod.register_cable(name, data)

    unnamed_tech_mod.register_power_node(":" .. name, {
        description = data.description,
        tiles = data.tiles,
        inventory_image = data.inventory_image,
        is_cable = true,
        connects_to = {"group:machine_" .. data.type},
        drawtype = "nodebox",
        node_box = {
            type = "connected",
            fixed          = {-0.125, -0.125, -0.125, 0.1,  0.1, 0.1},
            connect_top    = {-0.125, -0.125, -0.125, 0.1,  0.5,  0.1},
            connect_bottom = {-0.125, -0.5,  -0.125, 0.1,  0.1, 0.1},
            connect_front  = {-0.125, -0.125, -0.5,  0.1,  0.1, 0.1},
            connect_back   = {-0.125, -0.125,  0.1, 0.1,  0.1, 0.5 },
            connect_left   = {-0.5,  -0.125, -0.125, 0.1,  0.1, 0.1},
            connect_right  = {-0.125, -0.125, -0.125, 0.5,   0.1, 0.1},
        },
        is_ground_content = false,
        sunlight_propagates = true,
        paramtype = "light",
        net_type = data.type,
        groups = data.groups
    })
end

unnamed_tech_mod.register_cable("unnamed_tech_mod:cable_lv", {
    description = "Copper Cable (LV)",
    tiles = {"cable_copper.png"},
    type = "LV",
    groups = {oddly_breakable_by_hand = 2},

})