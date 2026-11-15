local function make_formspec(input_slots, output_slots)
    local input_size = input_slots > 4 and 3 or input_slots > 1 and 2 or 1
    local output_size = output_slots > 4 and 3 or output_slots > 1 and 2 or 1

    local function centered(size, origin)
        return origin + (5 - (size * 1.25 - 0.25)) / 2
    end

    return [[
        formspec_version[4]
        size[10,10]
        no_prepend[]
        listcolors[#88a9a6;#366663;#091716]
        bgcolor[#000000]
        box[0.05,0.05;9.9,9.9;#474753FF]
    ]]
    .. "list[context;src;"
    .. centered(input_size, 0) .. "," .. centered(input_size, 0)
    .. ";" .. input_size .. "," .. input_size .. ";]"
    .. "list[context;dst;"
    .. centered(output_size, 5) .. "," .. centered(output_size, 0)
    .. ";" .. output_size .. "," .. output_size .. ";]"
    .. "list[current_player;main;0.125,5.125;8,4;]"
end

--functions to make this respect protections
local function allow_metadata_inventory_move(pos, from_list, from_index, to_list, to_index, count, player)
    if core.is_protected(pos, player:get_name()) then
        return 0
    end
    return count
end

local function allow_metadata_inventory_take(pos, listname, index, stack, player)
    if core.is_protected(pos, player:get_name()) then
        return 0
    end
    return stack:get_count()
end

local function allow_metadata_inventory_put(pos, listname, index, stack, player)
    if core.is_protected(pos, player:get_name()) then
        return 0
    end
    return stack:get_count()
end

local function can_dig(pos)
    local inv = core.get_meta(pos):get_inventory()
    if inv:is_empty("src") and inv:is_empty("dst") then
        return true
    end
    return false
end

--notify when something is put in or out
local function notify_change(pos)
    core.get_meta(pos):set_int("changed", 1)
end

local function on_metadata_inventory_put(pos, listname, index, stack, player)
    notify_change(pos)
end

local function on_metadata_inventory_take(pos, listname, index, stack, player)
    notify_change(pos)
end

--processing functions
local function get_single_input_recipe(src, recipe_type)
end

local function get_multi_input_recipe(src, recipe_type)
end

local function is_space_for_multi_items(dst, list)
end

local function is_space_for_single_item(dst, item)
end
--registers a machine that takes x input, x power, and gives x output
--{power draw, type, recipe type, name, description, tiles, active tiles}
function unnamed_tech_mod.register_basic_machine(name, data)
    local recipe_type = data.recipe_type
    data.recipe_type = nil

    local recipedata = unnamed_tech_mod.recipe_types[recipe_type]
    local input_slots = recipedata.input_slots
    local output_slots = recipedata.output_slots

    data.on_construct = function(pos)
        local meta = core.get_meta(pos)
        local inv = meta:get_inventory()
        inv:set_size("src", input_slots)
        inv:set_size("dst", output_slots)
        core.get_meta(pos):set_string("formspec", make_formspec(input_slots, output_slots))

        local timer = core.get_node_timer(pos)
        timer:start(4)
    end

    --protection stuff
    data.allow_metadata_inventory_put = allow_metadata_inventory_put
    data.allow_metadata_inventory_take = allow_metadata_inventory_take
    data.allow_metadata_inventory_move = allow_metadata_inventory_move
    data.can_dig = can_dig
    --notify changes to make the machine check more often
    data.on_metadata_inventory_put = on_metadata_inventory_put
    data.on_metadata_inventory_take = on_metadata_inventory_take




    



    unnamed_tech_mod.register_power_node(name, data)

end
--[[
unnamed_tech_mod.register_basic_machine("unnamed_tech_mod:lv_machine_but_better", {
    description = "LV Machine but better",
    tiles = {"default_steel_block.png"},
    groups = {
        cracky = 2,
    },

    net_type = "LV",

    supply = 0,
    demand = 20,
})
]]