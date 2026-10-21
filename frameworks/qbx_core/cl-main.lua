---@diagnostic disable: duplicate-set-field
if Framework.Name ~= 'qbx_core' then return end

Framework.Client = {}

local QBX <const> = exports.qbx_core

--- Returns the name of the active framework.
---@return string Always returns "qbx_core".
function Framework.Client.GetFrameworkName()
    return 'qbx_core'
end

-- Player Actions

--- Returns the full player data object for the local player.
---@return table|nil The PlayerData table containing job, gang, money, charinfo, metadata, etc.
function Framework.Client.GetPlayerData()
    return QBX:GetPlayerData() or nil
end

exports('GetPlayerData', Framework.Client.GetPlayerData)

return Framework
