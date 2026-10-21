local QB_STYLE <const> = {
    ['qb-inventory'] = true,
    ['ps-inventory'] = true,
}

local SUPPORTED <const> = {
    'ox_inventory',
    'qb-inventory',
    'ps-inventory',
    'codem-inventory',
    'core_inventory',
    'jpr-inventory',
    'origen_inventory',
    'tgiann-inventory',
}

local resolved = nil
local warned = false

--- Returns the name of the running inventory resource, cached once one is found.
--- Returns nil when none is running, in which case the framework fallback is used.
--- A miss is not cached, so an inventory that starts later is still picked up.
---@return string|nil The inventory resource name, or nil for the framework fallback.
local function inventory()
    if resolved then return resolved end

    for _, name in ipairs(SUPPORTED) do
        if GetResourceState(name) == 'started' then
            resolved = name
            Debug("info", "inventory module bound to %s", name)
            return resolved
        end
    end

    if not warned then
        warned = true
        Debug("warning", "no supported inventory found, falling back to the framework inventory")
    end
    return nil
end

--- Reads an item through the framework, the last resort when no inventory resource runs.
---@param playerId number The server-side player source ID.
---@param itemName string The internal name of the item to find.
---@return table|nil A table with name, slot, count and metadata, or nil when unavailable.
local function frameworkItem(playerId, itemName)
    if not Framework.Server.GetInventoryItem then
        Debug("error", "no framework bridge is active, cannot read the inventory")
        return nil
    end

    return Framework.Server.GetInventoryItem(playerId, itemName)
end

--- Checks whether a player has the specified item(s) in their inventory.
--- Supports: codem-inventory, core_inventory, jpr-inventory, origen_inventory,
--- ox_inventory, ps-inventory, qb-inventory, tgiann-inventory, plus the framework fallback.
---@param playerId number The server-side player source ID.
---@param items string|table A single item name (string) or a key-value table of { [itemName] = requiredCount }.
---@param count number|nil The required quantity when `items` is a string. Ignored when `items` is a table.
---@return boolean True if the player has the required item(s), false otherwise.
function Modules.Server.Inventory.HasItem(playerId, items, count)
    count = count or 1
    local name = inventory()

    if name == 'ox_inventory' then
        if type(items) == 'table' then
            for itemName, itemCount in pairs(items) do
                if exports.ox_inventory:GetItemCount(playerId, itemName) < itemCount then return false end
            end

            return true
        end

        return exports.ox_inventory:GetItemCount(playerId, items) >= count
    elseif name == 'origen_inventory' then
        if type(items) == 'table' then
            for itemName, itemCount in pairs(items) do
                if not exports.origen_inventory:HasItem(playerId, itemName, itemCount) then return false end
            end

            return true
        end

        return exports.origen_inventory:HasItem(playerId, items, count)
    elseif name == 'core_inventory' then
        return exports['core_inventory']:hasItem(playerId, items, count)
    elseif name then
        return exports[name]:HasItem(playerId, items, count)
    end

    if type(items) == 'table' then
        for itemName, itemCount in pairs(items) do
            local item = frameworkItem(playerId, itemName)
            if not item or item.count < itemCount then return false end
        end

        return true
    end

    local item = frameworkItem(playerId, items)
    return item ~= nil and item.count >= count
end

exports('HasItem', Modules.Server.Inventory.HasItem)

--- Returns how many of an item a player carries.
--- Inventories without a count export fall back to a presence check, so they
--- report 1 instead of the real amount.
---@param playerId number The server-side player source ID.
---@param itemName string The internal name of the item to count.
---@return number The amount carried, or 0 when the player has none.
function Modules.Server.Inventory.GetItemCount(playerId, itemName)
    local name = inventory()

    if name == 'ox_inventory' then
        return exports.ox_inventory:GetItemCount(playerId, itemName) or 0
    elseif QB_STYLE[name] then
        local item = exports[name]:GetItemByName(playerId, itemName)
        return item and (item.amount or item.count or 0) or 0
    elseif name then
        return Modules.Server.Inventory.HasItem(playerId, itemName, 1) and 1 or 0
    end

    local item = frameworkItem(playerId, itemName)
    return item and item.count or 0
end

exports('GetItemCount', Modules.Server.Inventory.GetItemCount)
