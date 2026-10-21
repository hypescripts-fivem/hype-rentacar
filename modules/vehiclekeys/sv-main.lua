-- Checked in this order when Config.VehicleKeys is "auto".
local SUPPORTED <const> = {
    'qbx_vehiclekeys',
    'qb-vehiclekeys',
    'wasabi_carlock',
    'MrNewbVehicleKeys',
    'qs-vehiclekeys',
    'Renewed-Vehiclekeys',
}

--- Gives keys through each supported resource's server API.
---@type table<string, fun(playerId: number, vehicle: number, plate: string, model: string)>
local HANDLERS <const> = {
    ['qbx_vehiclekeys'] = function(playerId, vehicle)
        exports.qbx_vehiclekeys:GiveKeys(playerId, vehicle, true)
    end,
    ['qb-vehiclekeys'] = function(playerId, _, plate)
        TriggerClientEvent('vehiclekeys:client:SetOwner', playerId, plate)
    end,
    ['wasabi_carlock'] = function(playerId, _, plate)
        exports.wasabi_carlock:GiveKey(playerId, plate)
    end,
    ['MrNewbVehicleKeys'] = function(playerId, _, plate)
        exports.MrNewbVehicleKeys:GiveKeysByPlate(playerId, plate)
    end,
    ['qs-vehiclekeys'] = function(playerId, _, plate, model)
        exports['qs-vehiclekeys']:GiveServerKeys(playerId, plate, model, true)
    end,
    ['Renewed-Vehiclekeys'] = function(playerId, _, plate)
        exports['Renewed-Vehiclekeys']:addKey(playerId, plate)
    end,
}

--- Returns the active vehicle keys resource, honouring Config.VehicleKeys.
---@return string|nil The resource name, or nil when keys are disabled or none is running.
local function provider()
    local configured = Config.VehicleKeys
    if configured == nil then configured = "auto" end
    if not configured then return nil end

    if configured ~= "auto" then
        return GetResourceState(configured) == "started" and HANDLERS[configured] and configured or nil
    end

    for _, name in ipairs(SUPPORTED) do
        if GetResourceState(name) == "started" then return name end
    end

    return nil
end

--- Gives a player the keys of a vehicle using the configured vehicle keys resource.
--- Supports: qbx_vehiclekeys, qb-vehiclekeys, wasabi_carlock, MrNewbVehicleKeys,
--- qs-vehiclekeys, Renewed-Vehiclekeys. Does nothing when none is running.
---@param playerId number The server-side player source ID.
---@param vehicle number The vehicle entity handle.
---@param plate string|nil The vehicle plate. Read from the vehicle when omitted.
---@param model string|nil The vehicle model name, used by qs-vehiclekeys.
---@return boolean True when a keys resource accepted the call.
function Modules.Server.VehicleKeys.GiveKeys(playerId, vehicle, plate, model)
    local resource = provider()
    if not resource then
        Debug("warning", "no vehicle keys resource found, skipping keys for %s", tostring(plate))
        return false
    end

    plate = plate or GetVehicleNumberPlateText(vehicle)

    local ok, err = pcall(HANDLERS[resource], playerId, vehicle, plate, model)
    if not ok then
        Debug("error", "giving keys through %s failed: %s", resource, tostring(err))
        return false
    end

    Debug("info", "keys for %s given to %s through %s", plate, playerId, resource)
    return true
end

exports("GiveKeys", Modules.Server.VehicleKeys.GiveKeys)
