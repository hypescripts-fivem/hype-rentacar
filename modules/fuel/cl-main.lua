-- Checked in this order when Config.Fuel.system is "auto". ox_fuel uses the state bag set on the server.
local SUPPORTED <const> = { 'ox_fuel', 'LegacyFuel', 'cdn-fuel', 'ps-fuel', 'lc_fuel' }

--- Returns the active fuel resource, honouring Config.Fuel.system.
---@return string|nil The resource name, or nil when fuel is disabled or none is running.
local function provider()
    local configured = Config.Fuel and Config.Fuel.system
    if configured == nil then configured = "auto" end
    if not configured then return nil end

    if configured ~= "auto" then
        return GetResourceState(configured) == "started" and configured or nil
    end

    for _, name in ipairs(SUPPORTED) do
        if GetResourceState(name) == "started" then return name end
    end

    return nil
end

--- Sets the fuel level of a vehicle through the configured fuel resource's client export.
--- Supports: LegacyFuel, cdn-fuel, ps-fuel, lc_fuel. ox_fuel is handled by the server state bag.
---@param vehicle number The vehicle entity handle.
---@param level number The fuel level (0-100).
---@return boolean True when a fuel resource accepted the call.
function Modules.Client.Fuel.SetFuel(vehicle, level)
    local resource = provider()
    if not resource or resource == "ox_fuel" then return false end

    local ok, err = pcall(function() exports[resource]:SetFuel(vehicle, level + 0.0) end)
    if not ok then
        Debug("error", "setting fuel through %s failed: %s", resource, tostring(err))
        return false
    end

    Debug("info", "fuel set to %.1f through %s", level, resource)
    return true
end

exports("SetFuel", Modules.Client.Fuel.SetFuel)

RegisterNetEvent("hype-rentacar:client:set-fuel", function(netId, level)
    if type(netId) ~= "number" or type(level) ~= "number" then return end

    local ok, vehicle = pcall(lib.waitFor, function()
        if not NetworkDoesNetIdExist(netId) then return end

        local entity = NetToVeh(netId)
        if entity ~= 0 and DoesEntityExist(entity) then return entity end
    end, nil, 5000)

    if not ok or not vehicle then
        return Debug("warning", "vehicle %s did not stream in, fuel was not set", netId)
    end

    Modules.Client.Fuel.SetFuel(vehicle, level)
end)
