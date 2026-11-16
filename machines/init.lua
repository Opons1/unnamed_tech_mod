local function df(file)
    dofile(core.get_modpath(core.get_current_modname()) .. "/machines/" .. file)
end
df("recipe.lua")
--df("basic_machine.lua")
df("LV/init.lua")


local function run_expiration_tests()
    local function log(message)
        core.chat_send_all("[Network Tests] " .. message)
    end

    local function check(condition, message)
        if not condition then
            error("[Network Tests] FAILED: " .. message, 2)
        end
        log("PASS: " .. message)
    end

    local function close(a, b)
        return math.abs(a - b) < 0.001
    end

    local function get_totals(pos)
        local id, net = unnamed_tech_mod.get_network_at(pos)
        assert(id and net, "Expected network at test position")
        return net.supply, net.demand
    end

    local base = {x = 10000, y = 100, z = 10000}

    local function pos(offset)
        return {x = base.x + offset, y = base.y, z = base.z}
    end

    local positions = {
        pos(0),
        pos(1),
    }

    unnamed_tech_mod.add_node(positions[1], "TEST", 0, 0)
    unnamed_tech_mod.add_node(positions[2], "TEST", 0, 0)

    local hash = core.hash_node_position(positions[1])

    -- Test 1: Initial power.
    unnamed_tech_mod.set_node_power(hash, 100, 20)

    local supply, demand = get_totals(positions[1])
    check(close(supply, 100) and close(demand, 20),
        "Initial power accounting")

    -- Test 2: Set temporary power.
    unnamed_tech_mod.set_node_power(hash, 100, 50, 5)

    supply, demand = get_totals(positions[1])
    check(close(supply, 100) and close(demand, 50),
        "Temporary power applied")

    -- Test 3: Reschedule before original expiration.
    core.after(2, function()
        unnamed_tech_mod.set_node_power(hash, 100, 30, 5)

        local s, d = get_totals(positions[1])
        check(close(s, 100) and close(d, 30),
            "Power updated before expiration")

        -- Test 4: Original expiration must not clear new power.
        core.after(4, function()
            local s2, d2 = get_totals(positions[1])
            check(close(s2, 100) and close(d2, 30),
                "Old expiration does not clear rescheduled power")
        end)

        -- Test 5: New expiration must clear power.
        core.after(6, function()
            local s3, d3 = get_totals(positions[1])
            check(close(s3, 0) and close(d3, 0),
                "Rescheduled expiration clears power")

            log("All expiration tests completed.")
        end)
    end)
end


core.register_chatcommand("network_test", {
    description = "Run network expiration tests",
    privs = {server = true},
    func = function()
        run_expiration_tests()
        return true, "Network expiration tests started."
    end,
})
