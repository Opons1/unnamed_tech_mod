local storage = core.get_mod_storage()
--debugging hell revealed that i should not trust tostring
local function hash_to_string(hash)
    return string.format("%.0f", hash)
end
--network types
unnamed_tech_mod.network_types = {}
--register a new network type, for now def just needs the name(desc optional)
function unnamed_tech_mod.register_network_type(def)
    def = table.copy(def) or {}
    def.description = def.description or def.name
    unnamed_tech_mod.network_types[def.name] = def
end
--network data
local networks = {}
--network id to iteratable table of hashes
local networknodes = {}
--hashed pos to supply, demand, and expiration
local nodedata = {}
--postions to network
local postonetwork = {}
--next id of the network
local nextnetworkid = 0
--creates a network
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

--when was last updated
local last_network_update = storage:get_int("last_network_update")
if last_network_update == 0 then
    last_network_update = os.time()
end
--stores the nodes whose power will be cleared in the future, indexed by the time
local powerclear = {}
--stores the current time
local current_time = os.time()
local function update_time()
    current_time = os.time()
end
--schedules a machines power to be cleared(time is seconds in the future)
local function schedule_clear(time, hash)
    local target_time = current_time + math.ceil(time)
    --creativity running low, it is called hashes since it is an table of hashes
    local hashes = powerclear[target_time]
    if hashes then
        hashes[hash] = true
    else 
        powerclear[target_time] = {[hash] = true}
    end
    return target_time
end
--sets a nodes power use
function unnamed_tech_mod.set_node_power(hash, supply, demand, time)
    local node = nodedata[hash]
    local networkid = postonetwork[hash]
    local network = networks[networkid]

    if not network then return end
    --creates the node if it does not exist
    if not node then
        node = {
            supply = 0,
            demand = 0,
        }
        nodedata[hash] = node
    end

    local old_supply = node.supply or 0
    local old_demand = node.demand or 0
    local old_time = node.time
    if old_time then
        local hashes = powerclear[old_time]
        if hashes then
            hashes[hash] = nil

            if not next(hashes) then
                powerclear[old_time] = nil
            end
        end
    end

    supply = supply or old_supply
    demand = demand or old_demand

    node.supply = supply
    node.demand = demand
    --schedules the node for clearing if not cleared already
    if time then
        node.time = schedule_clear(time, hash)
    else
        node.time = nil
    end

    network.supply = network.supply + supply - old_supply
    network.demand = network.demand + demand - old_demand
    unnamed_tech_mod.save(hash)
end
--simple helper function to make clearing easier
local function clear_node_power(hash)
    local node = nodedata[hash]
    local network = networks[postonetwork[hash]]
    if node and network then
        network.supply = network.supply - node.supply
        network.demand = network.demand - node.demand

        node.supply = 0
        node.demand = 0
        node.time = nil
        unnamed_tech_mod.save(hash)
    end
end
--clears the power
local function clear_power()
    if current_time - last_network_update > 200 then
        --200 second gap
        for timestamp, hashes in pairs(powerclear) do
            if timestamp <= current_time then
                for hash in pairs(hashes) do
                    clear_node_power(hash)
                end

                powerclear[timestamp] = nil
            end
        end
    else
        --less than 200 second gap
        for i = last_network_update, current_time do
            local target = powerclear[i]

            if target then
                for hash in pairs(target) do
                    clear_node_power(hash)
                end

                powerclear[i] = nil
            end
        end
    end

    last_network_update = current_time
    storage:set_int("last_network_update", last_network_update)
end
--vector offsets
local dirs = {
    {x =  1, y =  0, z =  0},
    {x = -1, y =  0, z =  0},
    {x =  0, y =  1, z =  0},
    {x =  0, y = -1, z =  0},
    {x =  0, y =  0, z =  1},
    {x =  0, y =  0, z = -1},
}
--gets adjacent networks
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

--removes the node from the network
function unnamed_tech_mod.remove_node(pos)

    local hash = core.hash_node_position(pos)
    local netid = postonetwork[hash]
    --the network was a figment of our imaginatiom
    if not netid then return end

    local node = nodedata[hash] or {supply = 0, demand = 0, time = 0}

    if node.time then
        local hashes = powerclear[node.time]
        if hashes then
            hashes[hash] = nil

            if not next(hashes) then
                powerclear[node.time] = nil
            end
        end
    end

    storage:set_string(hash_to_string(hash), "")

    local supply = node.supply or 0
    local demand = node.demand or 0

    nodedata[hash] = nil

    local net = networks[netid]

    postonetwork[hash] = nil

    if networknodes[netid] then
        networknodes[netid][hash] = nil
    end

    if not net then return end

    local same_net_neighbors = {}
    --gets number of neighbors from the same network
    for _, dir in ipairs(dirs) do
        local adj_pos = vector.add(pos, dir)
        local adj_hash = core.hash_node_position(adj_pos)
        if postonetwork[adj_hash] == netid then
            same_net_neighbors[#same_net_neighbors + 1] = adj_hash
        end
    end
    --none means it was the only one there
    if #same_net_neighbors == 0 then
        networks[netid] = nil
        networknodes[netid] = nil
        return
    end
    --one means it was at the end
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
        local new_net = networks[new_id]
        local new_nodes = networknodes[new_id]

        for _, node_hash in ipairs(component) do
            postonetwork[node_hash] = new_id
            new_nodes[node_hash] = true

            new_net.supply = new_net.supply + (nodedata[node_hash].supply or 0)
            new_net.demand = new_net.demand + (nodedata[node_hash].demand or 0)
        end
    end

end
--adds a node to the network(do not use anything past demand) 
function unnamed_tech_mod.add_node(pos, type, supply, demand, time)
    if time then
        time = time - current_time
        if time <= 0 then
            time = nil
            supply = 0
            demand = 0
        end
    end    
    local hash = core.hash_node_position(pos)
    --if there is already a connection
    if postonetwork[hash] then return postonetwork[hash] end 

    local supply = supply or 0
    local demand = demand or 0

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
    --power use
    nodedata[hash] = {
        type = type
    }
    unnamed_tech_mod.set_node_power(hash, supply, demand, time)
    return netid
end
--gets network at pos 
function unnamed_tech_mod.get_network_at(pos)
    local hash = core.hash_node_position(pos)
    local netid = postonetwork[hash]
    if not netid or not networks[netid] then
        return nil, nil
    end
    return netid, networks[netid]
end

function unnamed_tech_mod.register_power_node(name, def)
    def.net_type = def.net_type or "LV"
    local base_supply = def.supply or 0
    local base_demand = def.demand or 0

    local on_construct = def.on_construct
    local on_destruct = def.on_destruct
    if not def.groups then def.groups = {} end
    def.groups["machine_" .. def.net_type] = 1

    def.on_construct = function(pos)
        unnamed_tech_mod.add_node(pos, def.net_type, base_supply, base_demand)
        if on_construct then
            return on_construct(pos)
        end
    end

    def.on_destruct = function(pos)
        unnamed_tech_mod.remove_node(pos)
        if on_destruct then
            return on_destruct(pos)
        end
    end

    core.register_node(name, def)
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
--saving the network
function unnamed_tech_mod.save(hash)
    if hash then
        storage:set_string(hash_to_string(hash), core.serialize(nodedata[hash]))
    else
        local metadata = {
            fields = {}
        }
        for hash, data in pairs(nodedata) do
            metadata.fields[hash_to_string(hash)] = core.serialize(nodedata[hash])
        end
        storage:from_table(metadata)
        storage:set_int("last_network_update", last_network_update)

    end
end

function unnamed_tech_mod.load()
    local metadata = storage:to_table()
    for hashstring, datastring in pairs(metadata.fields) do
        local hash = tonumber(hashstring)
        if hash then
            local data = core.deserialize(datastring)
            local pos = core.get_position_from_hash(hash)
            local time 
            if data then
                if data.time and data.time > current_time then
                    time = data.time
                end
                unnamed_tech_mod.add_node(pos, data.type, data.supply, data.demand, time)
            end
        end
    end
end
--does all the globalstep stuff
core.register_globalstep(function(dtime)
    --update the time
    update_time()
    --clear expiration queue
    clear_power()
end)

core.register_on_mods_loaded(function()
    local time = os.time()
    unnamed_tech_mod.load()
    core.log("action", "loading networks took " .. (os.time() - time) .. " seconds")
end)