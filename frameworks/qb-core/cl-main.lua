---@diagnostic disable: duplicate-set-field
if Framework.Name ~= 'qb-core' then return end

Framework.Client = {}

local QBCore <const> = exports['qb-core']:GetCoreObject()

--- Returns the name of the active framework.
---@return string Always returns "qb-core".
function Framework.Client.GetFrameworkName()
    return 'qb-core'
end

-- Player Actions

--- Returns the full player data object for the local player.
---@return table|nil The PlayerData table containing job, gang, money, charinfo, metadata, etc.
function Framework.Client.GetPlayerData()
    return QBCore.Functions.GetPlayerData() or nil
end

exports('GetPlayerData', Framework.Client.GetPlayerData)

return Framework
