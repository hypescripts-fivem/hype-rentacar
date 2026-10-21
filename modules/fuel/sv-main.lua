-- Checked in this order when Config.Fuel.system is "auto".
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

--- Sets the fuel level of a freshly spawned vehicle.
--- The `fuel` state bag is always set (ox_fuel reads it). Resources that only offer a client
--- export (LegacyFuel, cdn-fuel, ps-fuel, lc_fuel) are called on the player's client.
---@param playerId number The server-side player source ID that receives the vehicle.
---@param vehicle number The vehicle entity handle.
---@param level number|nil The fuel level (0-100). Defaults to Config.Fuel.level.
---@return nil
function Modules.Server.Fuel.SetFuel(playerId, vehicle, level)
    level = level or (Config.Fuel and Config.Fuel.level) or 100.0
    if not vehicle or not DoesEntityExist(vehicle) then return end

    Entity(vehicle).state:set("fuel", level, true)

    local resource = provider()
    if not resource or resource == "ox_fuel" then
        return Debug("info", "fuel set to %.1f through the state bag (%s)", level, resource or "no fuel resource")
    end

    TriggerClientEvent("hype-rentacar:client:set-fuel", playerId, NetworkGetNetworkIdFromEntity(vehicle), level)
    Debug("info", "fuel set to %.1f through %s on client %s", level, resource, playerId)
end

exports("SetFuel", Modules.Server.Fuel.SetFuel)
