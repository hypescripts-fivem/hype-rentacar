---@diagnostic disable: duplicate-set-field
if Framework.Name ~= 'es_extended' then return end

Framework.Client = {}

local ESX <const> = exports.es_extended:getSharedObject()

--- Returns the name of the active framework.
---@return string Always returns "es_extended".
function Framework.Client.GetFrameworkName()
    return 'es_extended'
end

-- Player Actions

--- Returns the full player data object for the local player.
---@return table|nil The ESX PlayerData table containing job, accounts, inventory, etc.
function Framework.Client.GetPlayerData()
    return ESX.GetPlayerData() or nil
end

exports('GetPlayerData', Framework.Client.GetPlayerData)

return Framework
