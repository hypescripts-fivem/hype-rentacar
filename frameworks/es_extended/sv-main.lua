---@diagnostic disable: duplicate-set-field
if Framework.Name ~= 'es_extended' then return end

Framework.Server = {}

local ESX <const> = exports.es_extended:getSharedObject()

-- ESX calls the cash account "money".
local ACCOUNTS <const> = { cash = 'money', bank = 'bank' }

--- Maps a script account name to the ESX account name.
---@param type string The account, e.g. "cash" or "bank".
---@return string The ESX account name.
local function account(type)
    return ACCOUNTS[type] or type
end

--- Returns the name of the active framework.
---@return string Always returns "es_extended".
function Framework.Server.GetFrameworkName()
    return 'es_extended'
end

-- Player Actions

--- Returns the framework player object.
---@param playerId number The player's server id.
---@return table|nil The xPlayer object, or nil when the player is not loaded.
function Framework.Server.GetPlayer(playerId)
    local Player = ESX.GetPlayerFromId(playerId)
    return Player and Player or nil
end

exports('GetPlayer', Framework.Server.GetPlayer)

--- Returns the unique character identifier of a player.
---@param playerId number The player's server id.
---@return string|nil The identifier, or nil when the player is not loaded.
function Framework.Server.GetPlayerIdentifier(playerId)
    local Player = Framework.Server.GetPlayer(playerId)
    if not Player then return nil end
    return Player.identifier or (Player.getIdentifier and Player.getIdentifier()) or nil
end

exports('GetPlayerIdentifier', Framework.Server.GetPlayerIdentifier)

--- Returns the server id of an online player by character identifier.
---@param identifier string The ESX identifier.
---@return number|nil The player's server id, or nil when the character is offline.
function Framework.Server.GetSourceFromIdentifier(identifier)
    local Player = ESX.GetPlayerFromIdentifier(identifier)
    return Player and Player.source or nil
end

exports('GetSourceFromIdentifier', Framework.Server.GetSourceFromIdentifier)

--- Returns the character name of a player.
--- Uses the firstName / lastName fields and falls back to splitting the display name.
---@param playerId number The player's server id.
---@param split boolean|nil True to return firstname and lastname separately.
---@return string|nil name The full name, or the firstname when `split` is true.
---@return string|nil lastname Only returned when `split` is true.
function Framework.Server.GetCharacterName(playerId, split)
    local Player = Framework.Server.GetPlayer(playerId)
    if not Player then return nil end

    local firstname, lastname = Player.get and Player.get('firstName'), Player.get and Player.get('lastName')
    if not firstname then
        local name = Player.getName and Player.getName() or nil
        if not name then return nil end

        firstname, lastname = name:match("^(%S+)%s+(.*)$")
        firstname = firstname or name
    end

    if split then
        return firstname, lastname
    end

    if not lastname or lastname == "" then return firstname end
    return firstname .. " " .. lastname
end

exports('GetCharacterName', Framework.Server.GetCharacterName)

-- Money Actions

--- Returns the balance of one of a player's accounts.
---@param playerId number The player's server id.
---@param type string The account, e.g. "cash" or "bank" ("cash" maps to "money").
---@return number The balance, or 0 when the player or account is unknown.
function Framework.Server.GetPlayerMoney(playerId, type)
    local Player = Framework.Server.GetPlayer(playerId)
    local data = Player and Player.getAccount(account(type))
    return data and tonumber(data.money) or 0
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
    if not Player then return false end

    local before = Framework.Server.GetPlayerMoney(playerId, type)
    if before < amount then return false end

    Player.removeAccountMoney(account(type), amount, reason)
    return Framework.Server.GetPlayerMoney(playerId, type) <= before - amount
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

    Player.addAccountMoney(account(type), amount, reason)
    return true
end

exports('AddPlayerMoney', Framework.Server.AddPlayerMoney)

-- License Actions

--- Checks an esx_license license (user_licenses table).
---@param playerId number The player's server id.
---@param license string The license type, e.g. "drive".
---@return boolean True when the player holds the license.
function Framework.Server.HasLicense(playerId, license)
    local identifier = Framework.Server.GetPlayerIdentifier(playerId)
    if not identifier then return false end

    local ok, result = pcall(MySQL.scalar.await, 'SELECT 1 FROM `user_licenses` WHERE `type` = ? AND `owner` = ? LIMIT 1', { license, identifier })
    if not ok then
        Debug("warning", "license check failed, is esx_license installed? (%s)", tostring(result))
        return false
    end

    return result ~= nil
end

exports('HasLicense', Framework.Server.HasLicense)

-- Vehicle Actions

--- Checks whether a plate belongs to an owned vehicle (owned_vehicles).
---@param plate string The plate to look up.
---@return boolean True when an owned vehicle already uses the plate.
function Framework.Server.IsPlateTaken(plate)
    local ok, result = pcall(MySQL.scalar.await, 'SELECT 1 FROM `owned_vehicles` WHERE `plate` = ? LIMIT 1', { plate })
    return ok and result ~= nil
end

exports('IsPlateTaken', Framework.Server.IsPlateTaken)

-- Inventory Fallback
-- Only used when no supported inventory resource is running, i.e. the built-in ESX inventory.

--- Framework-level inventory lookup, used only without a supported inventory resource.
--- The built-in ESX inventory has no slots or metadata, so only the count is real.
---@param playerId number The player's server id.
---@param itemName string The item to look for.
---@return table|nil A table with name, slot, count and metadata, or nil when not carried.
function Framework.Server.GetInventoryItem(playerId, itemName)
    local Player = Framework.Server.GetPlayer(playerId)
    if not Player then return nil end

    local item = Player.getInventoryItem(itemName)
    if not item or (item.count or 0) < 1 then return nil end

    return {
        name     = item.name,
        slot     = nil,
        count    = item.count,
        metadata = {},
    }
end

exports('GetInventoryItem', Framework.Server.GetInventoryItem)

return Framework
