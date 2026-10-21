---@diagnostic disable: duplicate-set-field
if Framework.Name ~= 'qbx_core' then return end

Framework.Server = {}

local QBX <const> = exports.qbx_core

--- Returns the name of the active framework.
---@return string Always returns "qbx_core".
function Framework.Server.GetFrameworkName()
    return 'qbx_core'
end

-- Player Actions

--- Returns the framework player object.
---@param playerId number The player's server id.
---@return table|nil The qbx player object, or nil when the player is not loaded.
function Framework.Server.GetPlayer(playerId)
    local Player = QBX:GetPlayer(playerId)
    return Player and Player or nil
end

exports('GetPlayer', Framework.Server.GetPlayer)

--- Returns the unique character identifier of a player.
---@param playerId number The player's server id.
---@return string|nil The citizenid, or nil when the player is not loaded.
function Framework.Server.GetPlayerIdentifier(playerId)
    local Player = Framework.Server.GetPlayer(playerId)
    return Player and Player.PlayerData and Player.PlayerData.citizenid or nil
end

exports('GetPlayerIdentifier', Framework.Server.GetPlayerIdentifier)

--- Returns the server id of an online player by character identifier.
---@param identifier string The citizenid.
---@return number|nil The player's server id, or nil when the character is offline.
function Framework.Server.GetSourceFromIdentifier(identifier)
    local Player = QBX:GetPlayerByCitizenId(identifier)
    return Player and Player.PlayerData and Player.PlayerData.source or nil
end

exports('GetSourceFromIdentifier', Framework.Server.GetSourceFromIdentifier)

--- Returns the character name of a player.
---@param playerId number The player's server id.
---@param split boolean|nil True to return firstname and lastname separately.
---@return string|nil name The full name, or the firstname when `split` is true.
---@return string|nil lastname Only returned when `split` is true.
function Framework.Server.GetCharacterName(playerId, split)
    local Player = Framework.Server.GetPlayer(playerId)
    if not Player or not Player.PlayerData or not Player.PlayerData.charinfo then return nil end

    local firstname = Player.PlayerData.charinfo.firstname
    local lastname  = Player.PlayerData.charinfo.lastname

    if split then
        return firstname, lastname
    end

    if not firstname or not lastname then return nil end
    return firstname .. " " .. lastname
end

exports('GetCharacterName', Framework.Server.GetCharacterName)

-- Money Actions

--- Returns the balance of one of a player's accounts.
---@param playerId number The player's server id.
---@param type string The account, e.g. "cash" or "bank".
---@return number The balance, or 0 when the player or account is unknown.
function Framework.Server.GetPlayerMoney(playerId, type)
    local Player = Framework.Server.GetPlayer(playerId)
    if not Player or not Player.PlayerData or not Player.PlayerData.money then return 0 end
    return tonumber(Player.PlayerData.money[type]) or 0
end

exports('GetPlayerMoney', Framework.Server.GetPlayerMoney)

--- Removes money from one of a player's accounts.
---@param playerId number The player's server id.
---@param type string The account, e.g. "cash" or "bank".
---@param amount number The amount to remove.
---@param reason string|nil The reason stored in the money log.
---@return boolean True when the money was removed.
function Framework.Server.RemovePlayerMoney(playerId, type, amount, reason)
    local Player = Framework.Server.GetPlayer(playerId)
    if not Player or Framework.Server.GetPlayerMoney(playerId, type) < amount then return false end
    return Player.Functions.RemoveMoney(type, amount, reason) == true
end

exports('RemovePlayerMoney', Framework.Server.RemovePlayerMoney)

--- Adds money to one of a player's accounts.
---@param playerId number The player's server id.
---@param type string The account, e.g. "cash" or "bank".
---@param amount number The amount to add.
---@param reason string|nil The reason stored in the money log.
---@return boolean True when the money was added.
function Framework.Server.AddPlayerMoney(playerId, type, amount, reason)
    local Player = Framework.Server.GetPlayer(playerId)
    if not Player then return false end
    return Player.Functions.AddMoney(type, amount, reason) == true
end

exports('AddPlayerMoney', Framework.Server.AddPlayerMoney)

-- License Actions

--- Checks a license stored in the player's metadata (metadata.licences.<license>).
---@param playerId number The player's server id.
---@param license string The license key, e.g. "driver".
---@return boolean True when the player holds the license.
function Framework.Server.HasLicense(playerId, license)
    local Player = Framework.Server.GetPlayer(playerId)
    if not Player or not Player.PlayerData or not Player.PlayerData.metadata then return false end

    local licences = Player.PlayerData.metadata.licences or {}
    return licences[license] == true
end

exports('HasLicense', Framework.Server.HasLicense)

-- Vehicle Actions

--- Checks whether a plate belongs to an owned vehicle (qbx_vehicles).
---@param plate string The plate to look up.
---@return boolean True when an owned vehicle already uses the plate.
function Framework.Server.IsPlateTaken(plate)
    if GetResourceState('qbx_vehicles') ~= 'started' then return false end

    local ok, result = pcall(MySQL.scalar.await, 'SELECT 1 FROM `player_vehicles` WHERE `plate` = ? LIMIT 1', { plate })
    return ok and result ~= nil
end

exports('IsPlateTaken', Framework.Server.IsPlateTaken)

-- Inventory Fallback
-- Only used when no supported inventory resource is running. qbx_core always ships
-- with ox_inventory, so the inventory module handles it and this stays unsupported.

--- Framework-level inventory lookup, used only without a supported inventory resource.
---@param playerId number The player's server id.
---@param itemName string The item to look for.
---@return table|nil Always nil on qbx_core.
function Framework.Server.GetInventoryItem(playerId, itemName)
    warn("qbx_core requires ox_inventory; no framework inventory fallback is available")
    return nil
end

exports('GetInventoryItem', Framework.Server.GetInventoryItem)

return Framework
