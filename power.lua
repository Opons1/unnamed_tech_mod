--i am so gonna forget how i did most of this, probably should have documented better and not done late night coding
unnamed_tech_mod.network_types = {}
local storage = core.get_mod_storage()

--stores the different network types, not really that important, and you can register new types below(you dont need to register any types though)
function unnamed_tech_mod.register_network_type(def)
    def = table.copy(def) or {}
    def.description = def.description or def.name
    unnamed_tech_mod.network_types[def.name] = def
end
--stores all the networks
local networks = {}
--connects individual node positions(made with core.hash_node_pos) to networks
local postonetwork = {}
--the nodes in each network above
local networknodes = {}
--the next index added to in networks
local nextnetworkid = 0
--saves the networks to mod storage, runs on shutdown or on-command
local function save_networks()
    storage:set_string("networks", core.serialize(networks))
    storage:set_int("nextnetworkid", nextnetworkid)

    for netid, nodes in pairs(networknodes) do
        storage:set_string(
            "networknodes_" .. netid,
            core.serialize(nodes)
        )
    end
end

--loads networks from mod storage
local function load_networks()
    local saved = storage:get_string("networks")

    if saved == "" then return end

    networks = core.deserialize(saved) or {}
    nextnetworkid = storage:get_int("nextnetworkid")

    networknodes = {}
    postonetwork = {}

    for netid in pairs(networks) do
        local nodes_saved = storage:get_string(
            "networknodes_" .. netid
        )

        local nodes = core.deserialize(nodes_saved) or {}
        networknodes[netid] = nodes

        for hash in pairs(nodes) do
            postonetwork[hash] = netid
        end
    end
end
--6 directions to check, for get_adjecent_networks


local dirs = {
    {x =  1, y =  0, z =  0},
    {x = -1, y =  0, z =  0},
    {x =  0, y =  1, z =  0},
    {x =  0, y = -1, z =  0},
    {x =  0, y =  0, z =  1},
    {x =  0, y =  0, z = -1},
}
--gets the adjacent networks
local function get_adjacent_networks(pos, type)
    local found = {}
    local seen = {}

    for _, dir in ipairs(dirs) do
        local postocheck = vector.add(pos, dir)
        local hash = core.hash_node_position(postocheck)
        local netid = postonetwork[hash]

        if netid and not seen[netid] and networks[netid] and networks[netid].type == type then
            seen[netid] = true
            found[#found + 1] = netid
        end
    end

    return found
end

--creates a network of the given type, creating the type if it does not exist
local function create_network(type)
    if not unnamed_tech_mod.network_types[type] then
        unnamed_tech_mod.register_network_type({ name = type })
        core.log("warning", "Created network " .. type .. "which does not exist")
    end
    nextnetworkid = nextnetworkid + 1
    networks[nextnetworkid] = {
        type = type,
        supply = 0,
        demand = 0,
    }
    networknodes[nextnetworkid] = {}
    return nextnetworkid
end

--merges two networks
local function merge_networks(net1id, net2id)
    --the same network twice
    if net1id == net2id then return end

    local net1 = networks[net1id]
    local net2 = networks[net2id]
    if not net1 or not net2 then return end

    net1.supply = net1.supply + net2.supply
    net1.demand = net1.demand + net2.demand

    for index in pairs(networknodes[net2id]) do
        postonetwork[index] = net1id
        networknodes[net1id][index] = true
    end

    networks[net2id] = nil
    networknodes[net2id] = nil
end
--adds a node to the network
function unnamed_tech_mod.add_node(pos, type, supply, demand)
    local hash = core.hash_node_position(pos)
    --if there is already a connection
    if postonetwork[hash] then return postonetwork[hash] end 

    supply = supply or 0
    demand = demand or 0

    local adjacent = get_adjacent_networks(pos, type)
    local netid
    --create new network if here is none adjacent of the required type
    if #adjacent == 0 then
        netid = create_network(type)
    else
        netid = adjacent[1]
        for i = 2, #adjacent do
            merge_networks(netid, adjacent[i])
        end
    end

    postonetwork[hash] = netid
    networknodes[netid][hash] = true

    networks[netid].supply = networks[netid].supply + supply
    networks[netid].demand = networks[netid].demand + demand

    return netid
end
--gets connected components
local function get_connected_component(start_hash, target_netid, visited)
    local component = {}
    local queue = {start_hash}
    local head = 1
    visited[start_hash] = true

    while head <= #queue do
        local curr_hash = queue[head]
        head = head + 1
        component[#component + 1] = curr_hash

        local curr_pos = core.get_position_from_hash(curr_hash)
        for _, dir in ipairs(dirs) do
            local adj_pos = vector.add(curr_pos, dir)
            local adj_hash = core.hash_node_position(adj_pos)

            if not visited[adj_hash] and postonetwork[adj_hash] == target_netid then
                visited[adj_hash] = true
                queue[#queue + 1] = adj_hash
            end
        end
    end

    return component
end

--called when a networks connection to the network is changed
local function notify_network_change(pos, netid)
    local node = core.get_node_or_nil(pos)
    if not node then return end

    local def = core.registered_nodes[node.name]
    if def and def._on_network_change then
        def._on_network_change(pos, netid)
    end
end
--removes the node from the network
function unnamed_tech_mod.remove_node(pos, supply, demand)
    local hash = core.hash_node_position(pos)
    local netid = postonetwork[hash]
    if not netid then return end

    supply = supply or 0
    demand = demand or 0

    local net = networks[netid]

    postonetwork[hash] = nil
    if networknodes[netid] then
        networknodes[netid][hash] = nil
    end

    if not net then return end

    local same_net_neighbors = {}
    for _, dir in ipairs(dirs) do
        local adj_pos = vector.add(pos, dir)
        local adj_hash = core.hash_node_position(adj_pos)
        if postonetwork[adj_hash] == netid then
            same_net_neighbors[#same_net_neighbors + 1] = adj_hash
        end
    end

    if #same_net_neighbors == 0 then
        networks[netid] = nil
        networknodes[netid] = nil
        return
    end

    if #same_net_neighbors == 1 then
        net.supply = net.supply - supply
        net.demand = net.demand - demand
        return
    end

    local visited = {}
    local components = {}
    for _, neighbor_hash in ipairs(same_net_neighbors) do
        if not visited[neighbor_hash] then
            components[#components + 1] = get_connected_component(neighbor_hash, netid, visited)
        end
    end

    if #components == 1 then
        net.supply = net.supply - supply
        net.demand = net.demand - demand
        return
    end


    local old_type = net.type
    networks[netid] = nil
    networknodes[netid] = nil

    for _, component in ipairs(components) do
        local new_id = create_network(old_type)
        local new_nodes = networknodes[new_id]

        for _, node_hash in ipairs(component) do
            postonetwork[node_hash] = new_id
            new_nodes[node_hash] = true

            local node_pos = core.get_position_from_hash(node_hash)
            notify_network_change(node_pos, new_id)
        end
    end
end
--edits the supply/demand of the network
function unnamed_tech_mod.add_power(netid, supply, demand)
    local net = networks[netid]
    if not net then return end
    net.supply = net.supply + (supply or 0)
    net.demand = net.demand + (demand or 0)
end

function unnamed_tech_mod.get_network_at(pos)
    local hash = core.hash_node_position(pos)
    local netid = postonetwork[hash]
    if not netid or not networks[netid] then
        return nil, nil
    end
    return netid, networks[netid]
end

core.register_craftitem("unnamed_tech_mod:network_inspector", {
    description = "Network Inspector",
    on_place = function(itemstack, user, pointed_thing)
        if type(user) ~= "userdata" then return end
        local playername = user:get_player_name()
        local target = pointed_thing.under
        local netid, net = unnamed_tech_mod.get_network_at(target)
        if not netid then
            core.chat_send_player(playername, "No network exists at the position")
        else

            local count = 0
            for _ in pairs(networknodes[netid] or {}) do
                count = count + 1
            end

            core.chat_send_player(playername, "Id: " .. netid .. " Supply: " .. net.supply .. " Demand: " .. net.demand .. " Type: " .. net.type .. " count: " .. count)
        end
    end
})


function unnamed_tech_mod.register_power_node(name, def)
    def.net_type = def.net_type or "LV"
    local base_supply = def.supply or 0
    local base_demand = def.demand or 0

    local is_cable = def.is_cable

    local on_construct = def.on_construct
    local on_destruct = def.on_destruct
    if not def.groups then def.groups = {} end
    def.groups["machine_" .. def.net_type] = 1

    def.on_construct = function(pos)
        local meta = core.get_meta(pos)
        if base_supply > 0 then meta:set_int("supply", base_supply) end
        if base_demand > 0 then meta:set_int("demand", base_demand) end

        unnamed_tech_mod.add_node(pos, def.net_type, base_supply, base_demand)
        return on_construct and on_construct(pos) or nil
    end

    def.on_destruct = function(pos)
        local meta = core.get_meta(pos)
        unnamed_tech_mod.remove_node(pos, meta:get_int("supply"), meta:get_int("demand"))
        return on_destruct and on_destruct(pos) or nil
    end
    if not is_cable then
        def._on_network_change = def._on_network_change or function(pos, new_netid)
            local meta = core.get_meta(pos)
            unnamed_tech_mod.add_power(new_netid, meta:get_int("supply"), meta:get_int("demand"))
        end
    end

    core.register_node(name, def)
end

function unnamed_tech_mod.set_node_power(pos, new_supply, new_demand)
    local meta = core.get_meta(pos)
    local old_supply = meta:get_int("supply")
    local old_demand = meta:get_int("demand")

    new_supply = new_supply or old_supply
    new_demand = new_demand or old_demand

    meta:set_int("supply", new_supply)
    meta:set_int("demand", new_demand)

    local netid = postonetwork[core.hash_node_position(pos)]
    if netid then
        unnamed_tech_mod.add_power(netid, new_supply - old_supply, new_demand - old_demand)
    end
end
--run a modified network save over time
local time = 0

core.register_globalstep(function(dtime)
    if time > 30 then
        storage:set_string("networks", core.serialize(networks))
        storage:set_int("nextnetworkid", nextnetworkid)
        
        local stagger = 0
        for netid, nodes in pairs(networknodes) do
            core.after(stagger, function()
                if networknodes[netid] then
                    storage:set_string(
                        "networknodes_" .. netid,
                        core.serialize(networknodes[netid])
                    )
                else
                    storage:set_string("networknodes_" .. netid, "")
                end
            end)
            stagger = stagger + 0.1
        end
        time = 0
    end
    time = time + dtime
end)

core.register_on_shutdown(save_networks)
--load the networks after this is done loading
load_networks()