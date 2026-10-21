local scriptName <const> = "hype-rentacar"

if GetCurrentResourceName() ~= scriptName then
    print(("^1[%s] The resource folder was renamed; please rename it back to %s.^0"):format(GetCurrentResourceName(), scriptName))
    StopResource(GetCurrentResourceName())
    return
end

if not Framework.Name then return end

local Config <const> = require "config.config"

local TABLE <const> = "hype_rentacar_rentals"
local REMOTE_LOCATION <const> = "remote"
local MIN_REMAINING <const> = 60 -- Rentals this close to expiry can no longer be collected or respawned

---@class Rental
---@field id number
---@field identifier string Owner's character identifier (citizenid / ESX identifier), stored in the `citizenid` column
---@field location string
---@field label string
---@field model string
---@field plate string
---@field payment string
---@field deposit number
---@field hours number
---@field expiresAt number
---@field pickedUp boolean Phone rentals stay false until they are collected at an office
---@field vehicle number?
---@field warned boolean?

---@type table<number, Rental>
local rentals = {}
---@type table<number, true> Players with a request in progress
local pending = {}
---@type table<number, number> Player source to os.time of the last successful action
local lastAction = {}

local locations, vehicles, durations = {}, {}, {}
for _, location in ipairs(Config.Locations) do locations[location.id] = location end
for _, vehicle in ipairs(Config.Vehicles) do vehicles[vehicle.model] = vehicle end
for _, duration in ipairs(Config.Durations) do durations[duration.hours] = duration end

local accounts = {}
for _, account in ipairs(Config.PaymentAccounts) do accounts[account] = true end

Debug("info", "rentacar server loaded: %d locations, %d vehicles, %d durations, license=%s (%s), remote=%s, respawn=%s",
    #Config.Locations, #Config.Vehicles, #Config.Durations, Config.License.required, Config.License.check or "any",
    Config.Remote.enabled, Config.Respawn.enabled)

---Sends a notification to a player through the notify module.
---@param source number Player server id
---@param description string Notification text
---@param notifyType string? "success" | "error" | "warning" | "inform"
---@return nil
local function notify(source, description, notifyType)
    Modules.Server.Notify.SendNotify(source, Config.CompanyName, description, 5000, notifyType or "inform")
end

---Tells the player's client that their rentals changed, so hype-rentacar-app refreshes.
---@param source number? Player server id
---@return nil
local function pushUpdate(source)
    if source then TriggerClientEvent("hype-rentacar:client:updated", source) end
end

---Logs an invalid or suspicious request. Printed even with Debug off when Config.Security.logSuspicious is set.
---@param source number Player server id
---@param message string Format string
---@param ... any Format arguments
---@return nil
local function suspicious(source, message, ...)
    if not Config.Security.logSuspicious then return Debug("warning", message, ...) end

    local ok, text = pcall(string.format, message, ...)
    print(("^3[%s] Suspicious request from ^7%s (%s): %s^0"):format(scriptName, GetPlayerName(source) or "?", source, ok and text or message))
end

---Deletes an entity when it still exists.
---@param entity number? Entity handle
---@return nil
local function deleteEntity(entity)
    if entity and DoesEntityExist(entity) then DeleteEntity(entity) end
end

---Whether the rental's vehicle is still in the world.
---@param rental Rental
---@return boolean
local function vehicleExists(rental)
    return rental.vehicle ~= nil and DoesEntityExist(rental.vehicle)
end

---Builds the player info shown in the UI.
---@param source number Player server id
---@return { id: number, firstname: string, lastname: string, cash: number, bank: number }
local function getPlayerInfo(source)
    local firstname, lastname = Framework.Server.GetCharacterName(source, true)

    return {
        id = source,
        firstname = firstname or GetPlayerName(source),
        lastname = lastname or "",
        cash = Framework.Server.GetPlayerMoney(source, "cash"),
        bank = Framework.Server.GetPlayerMoney(source, "bank"),
    }
end

---Whether the player carries the license item.
---@param source number Player server id
---@return boolean
local function hasLicenseItem(source)
    if not Config.License.item then return false end
    local ok, count = pcall(Modules.Server.Inventory.GetItemCount, source, Config.License.item)
    return ok and (tonumber(count) or 0) > 0
end

---Whether the player holds the license in the framework (metadata / esx_license).
---@param source number Player server id
---@return boolean
local function hasLicenseMetadata(source)
    if not Config.License.metadata then return false end
    local ok, result = pcall(Framework.Server.HasLicense, source, Config.License.metadata)
    return ok and result == true
end

---Checks the driver license as set in Config.License. Unknown check values behave like "any".
---@param source number Player server id
---@return boolean
local function hasLicense(source)
    local license = Config.License
    if not license.required then return true end

    if license.check == "metadata" then return hasLicenseMetadata(source) end
    if license.check == "item" then return hasLicenseItem(source) end
    return hasLicenseMetadata(source) or hasLicenseItem(source)
end

---Whether a model can be rented at a location.
---@param location table Config location
---@param model string Vehicle model
---@return boolean
local function isAllowedAt(location, model)
    if not vehicles[model] then return false end
    if not location.vehicles then return true end
    for _, allowed in ipairs(location.vehicles) do
        if allowed == model then return true end
    end
    return false
end

---Whether a model can be rented at any location (phone rentals).
---@param model string Vehicle model
---@return boolean
local function isAvailableAnywhere(model)
    for _, location in ipairs(Config.Locations) do
        if isAllowedAt(location, model) then return true end
    end
    return false
end

---@param source number Player server id
---@return vector3
local function getPedCoords(source)
    return GetEntityCoords(GetPlayerPed(source))
end

---Whether the player is within `distance` of the office clerk.
---@param source number Player server id
---@param location table Config location
---@param distance number? Defaults to location.maxDistance
---@return boolean
local function isNear(source, location, distance)
    return #(getPedCoords(source) - location.coords.xyz) <= (distance or location.maxDistance)
end

---Returns a player's active rentals, oldest first.
---@param identifier string Character identifier
---@return Rental[]
local function getPlayerRentals(identifier)
    local list = {}
    for _, rental in pairs(rentals) do
        if rental.identifier == identifier then list[#list + 1] = rental end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

---@param source number Player server id
---@return boolean ok
---@return string? error
local function checkCooldown(source)
    local last = lastAction[source]
    if last and os.time() - last < Config.Security.cooldown then return false, "cooldown" end
    return true
end

---@param vehicle table Config vehicle
---@param duration table Config duration
---@return number price
---@return number discount
local function calculatePrice(vehicle, duration)
    local discount = math.max(0, math.min(100, duration.discount or 0))
    local price = math.floor(vehicle.price * duration.hours * (100 - discount) / 100 + 0.5)
    return price, discount
end

---Deposit refund, reduced by vehicle damage when Config.Deposit.damageDeduction is on.
---@param rental Rental
---@return number refund
local function calculateRefund(rental)
    if rental.deposit <= 0 then return 0 end
    if not Config.Deposit.damageDeduction then return rental.deposit end
    if not vehicleExists(rental) then return 0 end

    local engine = math.max(0.0, GetVehicleEngineHealth(rental.vehicle))
    local body = math.max(0.0, GetVehicleBodyHealth(rental.vehicle))
    local ratio = math.min(1.0, math.min(engine, body) / 1000.0)

    return math.floor(rental.deposit * ratio)
end

---@param model string Vehicle model
---@return string url
local function getImage(model)
    local vehicle = vehicles[model]
    return vehicle and vehicle.image or Config.ImageUrl:format(model)
end

---Converts a rental to the shape the UI and the phone app expect.
---@param rental Rental
---@param location table? Office the player is at, used for `vehicleNear`
---@return table
local function serializeRental(rental, location)
    local exists = vehicleExists(rental)
    local coords = exists and GetEntityCoords(rental.vehicle) or nil
    local home = locations[rental.location]

    return {
        id = rental.id,
        model = rental.model,
        label = rental.label,
        plate = rental.plate,
        hours = rental.hours,
        deposit = rental.deposit,
        payment = rental.payment,
        location = rental.location,
        locationLabel = home and home.label or nil,
        image = getImage(rental.model),
        remaining = math.max(0, rental.expiresAt - os.time()),
        pickedUp = rental.pickedUp,
        vehicleExists = exists,
        vehicleNear = location and coords and #(coords - location.coords.xyz) <= location.returnRadius or false,
        coords = coords and { x = coords.x, y = coords.y } or nil,
    }
end

---Player info, license state and active rentals.
---@param source number Player server id
---@param identifier string Character identifier
---@param location table? Office the player is at
---@return { player: table, license: boolean, rentals: table[] }
local function getData(source, identifier, location)
    local list = {}
    for i, rental in ipairs(getPlayerRentals(identifier)) do
        list[i] = serializeRental(rental, location)
    end

    return {
        player = getPlayerInfo(source),
        license = hasLicense(source),
        rentals = list,
    }
end

---Whether no vehicle stands within 3 m of a spawn point.
---@param coords vector3|vector4
---@return boolean
local function isSpawnFree(coords)
    for _, vehicle in ipairs(GetAllVehicles()) do
        if #(GetEntityCoords(vehicle) - coords.xyz) < 3.0 then return false end
    end
    return true
end

---@param location table Config location
---@return vector4? spawn First free spawn point
local function findSpawn(location)
    for _, spawn in ipairs(location.spawns) do
        if isSpawnFree(spawn) then return spawn end
    end
    Debug("warning", "every spawn point at %s is blocked", location.id)
end

---Whether a plate is used by an active rental or an owned vehicle.
---@param plate string
---@return boolean
local function isPlateTaken(plate)
    for _, rental in pairs(rentals) do
        if rental.plate == plate then return true end
    end
    if MySQL.scalar.await(("SELECT 1 FROM `%s` WHERE `plate` = ? AND `status` = 'active' LIMIT 1"):format(TABLE), { plate }) then return true end
    return Framework.Server.IsPlateTaken(plate)
end

---@return string plate A free plate (prefix + 4 digits, max 8 characters)
local function generatePlate()
    for _ = 1, 20 do
        local plate = ("%s%04d"):format(Config.PlatePrefix, math.random(0, 9999)):sub(1, 8)
        if not isPlateTaken(plate) then return plate end
    end
    Debug("warning", "no free plate found after 20 tries, using a random one")
    return ("%s%04d"):format(Config.PlatePrefix, math.random(0, 9999)):sub(1, 8)
end

---Gives the player keys through the vehicle keys module.
---@param source number Player server id
---@param vehicle number Vehicle entity
---@param rental { plate: string, model: string }
---@return nil
local function giveKeys(source, vehicle, rental)
    Modules.Server.VehicleKeys.GiveKeys(source, vehicle, rental.plate, rental.model)
end

---Spawns a rental vehicle server side and sets its plate and fuel.
---@param source number Player server id who receives the vehicle
---@param model string Vehicle model
---@param plate string
---@param spawn vector4
---@return number? entity
local function spawnVehicle(source, model, plate, spawn)
    local data = vehicles[model]
    local entity = CreateVehicleServerSetter(joaat(model), data and data.type or "automobile", spawn.x, spawn.y, spawn.z, spawn.w)

    local exists = pcall(lib.waitFor, function()
        if DoesEntityExist(entity) then return true end
    end, nil, 5000)

    if not exists then
        Debug("error", "vehicle %s (%s) did not spawn within 5 seconds", model, plate)
        return
    end

    SetVehicleNumberPlateText(entity, plate)
    Modules.Server.Fuel.SetFuel(source, entity, Config.Fuel and Config.Fuel.level)
    Debug("info", "spawned %s (%s) at %.1f, %.1f, %.1f", model, plate, spawn.x, spawn.y, spawn.z)
    return entity
end

---Charges a fee from the preferred account first, then from the other payment accounts.
---@param source number Player server id
---@param preferred string Account to try first
---@param amount number
---@param reason string
---@return string|false account The account that was charged, or false when none had enough money
local function chargeFee(source, preferred, amount, reason)
    if amount <= 0 then return preferred end

    local order = { preferred }
    for _, name in ipairs(Config.PaymentAccounts) do
        if name ~= preferred then order[#order + 1] = name end
    end

    for _, name in ipairs(order) do
        if accounts[name] and Framework.Server.GetPlayerMoney(source, name) >= amount and Framework.Server.RemovePlayerMoney(source, name, amount, reason) then
            return name
        end
    end
    return false
end

---Removes a rental from memory, deletes its vehicle and closes it in the database.
---@param rental Rental
---@param status "returned"|"expired"
---@param refund number Deposit paid back
---@return nil
local function finishRental(rental, status, refund)
    rentals[rental.id] = nil
    deleteEntity(rental.vehicle)

    MySQL.update.await(("UPDATE `%s` SET `status` = ?, `deposit_refund` = ?, `ended_at` = NOW() WHERE `id` = ?"):format(TABLE), {
        status, refund, rental.id,
    })
end

---Returns a rental only when it belongs to the player.
---@param source number Player server id
---@param identifier string Character identifier
---@param rentalId any Rental id sent by the client
---@return Rental? rental
---@return string? error
local function getOwnedRental(source, identifier, rentalId)
    local id = math.tointeger(tonumber(rentalId))
    local rental = id and rentals[id]

    if not rental then return nil, "no_rental" end
    if rental.identifier ~= identifier then
        suspicious(source, "tried to access someone else's rental (#%s)", tostring(rentalId))
        return nil, "no_rental"
    end
    return rental
end

--[[ Renting ]]

---Rents a vehicle at an office, or from the phone (the vehicle is collected at an office later).
---@param source number Player server id
---@param locationId string? Office id, nil for phone rentals
---@param data { model: string, hours: number, payment: string }
---@param remote boolean True for phone rentals
---@return boolean success
---@return string|table result Error code, or { id, plate, label, hours }
local function rent(source, locationId, data, remote)
    local identifier = Framework.Server.GetPlayerIdentifier(source)
    if not identifier then return false, "no_player" end

    -- Never trust client values: validate types and config entries
    if type(data) ~= "table" or type(data.model) ~= "string" or type(data.payment) ~= "string" then
        suspicious(source, "invalid rental data")
        return false, "invalid"
    end

    local vehicle = vehicles[data.model]
    local hours = math.tointeger(tonumber(data.hours))
    local duration = hours and durations[hours]
    local account = data.payment

    if not vehicle then
        suspicious(source, "tried to rent a vehicle that is not in the config (%s)", data.model)
        return false, "invalid"
    end
    if not duration then
        suspicious(source, "duration not in the config (%s)", tostring(data.hours))
        return false, "invalid"
    end
    if not accounts[account] then
        suspicious(source, "invalid payment account (%s)", account)
        return false, "invalid"
    end

    local location
    if remote then
        if not Config.Remote.enabled then return false, "remote_disabled" end
        if not isAvailableAnywhere(vehicle.model) then return false, "invalid" end
    else
        location = locations[locationId]
        if not location then return false, "invalid" end
        if not isNear(source, location) then
            suspicious(source, "tried to rent far from the office (%s)", tostring(locationId))
            return false, "too_far"
        end
        if not isAllowedAt(location, vehicle.model) then
            suspicious(source, "vehicle not offered at this office (%s @ %s)", vehicle.model, location.id)
            return false, "invalid"
        end
    end

    if not hasLicense(source) then return false, "no_license" end

    if #getPlayerRentals(identifier) >= Config.MaxActiveRentals then return false, "max_rentals" end

    local ok, err = checkCooldown(source)
    if not ok then return false, err end

    -- The price is always calculated on the server from the config
    local price, discount = calculatePrice(vehicle, duration)
    local deposit = vehicle.deposit or 0
    local fee = remote and (Config.Remote.fee or 0) or 0
    local total = price + deposit + fee

    if Framework.Server.GetPlayerMoney(source, account) < total then return false, "no_money" end

    local spawn
    if not remote then
        spawn = findSpawn(location)
        if not spawn then return false, "spawn_blocked" end
    end

    if total > 0 and not Framework.Server.RemovePlayerMoney(source, account, total, "rentacar-rent") then return false, "no_money" end

    ---Pays the full amount back when the rental cannot be completed.
    ---@return nil
    local function refund()
        if total > 0 then Framework.Server.AddPlayerMoney(source, account, total, "rentacar-refund") end
        Debug("warning", "rental of %s for %s refunded (%d)", vehicle.model, source, total)
    end

    local plate = generatePlate()
    local entity

    if spawn then
        entity = spawnVehicle(source, vehicle.model, plate, spawn)
        if not entity then
            refund()
            return false, "spawn_failed"
        end
    end

    local id = MySQL.insert.await(([[
        INSERT INTO `%s` (`citizenid`, `location`, `model`, `label`, `plate`, `hours`, `price_per_hour`, `discount`, `rent_price`, `deposit`, `payment`, `picked_up`, `expires_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR))
    ]]):format(TABLE), {
        identifier, location and location.id or REMOTE_LOCATION, vehicle.model, vehicle.label, plate, duration.hours, vehicle.price,
        discount, price + fee, deposit, account, remote and 0 or 1, duration.hours,
    })

    if not id then
        Debug("error", "could not insert the rental of %s into the database", vehicle.model)
        deleteEntity(entity)
        refund()
        return false, "invalid"
    end

    rentals[id] = {
        id = id,
        identifier = identifier,
        location = location and location.id or REMOTE_LOCATION,
        label = vehicle.label,
        model = vehicle.model,
        plate = plate,
        payment = account,
        deposit = deposit,
        hours = duration.hours,
        expiresAt = os.time() + duration.hours * 3600,
        pickedUp = not remote,
        vehicle = entity,
    }

    lastAction[source] = os.time()

    if entity then
        SetPedIntoVehicle(GetPlayerPed(source), entity, -1)
        giveKeys(source, entity, rentals[id])
    end
    pushUpdate(source)

    Debug("success", "%s rented %s (#%d, %d hours, %s, total %d, plate %s%s)", GetPlayerName(source), vehicle.model, id, duration.hours, account, total, plate, remote and ", phone" or "")

    return true, { id = id, plate = plate, label = vehicle.label, hours = duration.hours }
end

--[[ Collecting a phone rental at an office ]]

---Spawns a phone rental at the office the player is at.
---@param source number Player server id
---@param locationId string Office id
---@param rentalId any Rental id sent by the client
---@return boolean success
---@return string|table result Error code, or { id, plate, label, location }
local function pickup(source, locationId, rentalId)
    local identifier = Framework.Server.GetPlayerIdentifier(source)
    if not identifier then return false, "no_player" end

    local location = locations[locationId]
    if not location then return false, "invalid" end

    -- The modal opens within pickupRadius; the server checks again with some tolerance
    if not isNear(source, location, math.max(location.maxDistance, Config.Remote.pickupRadius + 5.0)) then
        suspicious(source, "tried to collect a rental far from the office (%s)", tostring(locationId))
        return false, "too_far"
    end

    local rental, err = getOwnedRental(source, identifier, rentalId)
    if not rental then return false, err end

    if rental.pickedUp then
        suspicious(source, "tried to collect an already collected rental (#%d)", rental.id)
        return false, "already_picked_up"
    end
    if rental.expiresAt - os.time() <= MIN_REMAINING then return false, "almost_expired" end
    if not isAllowedAt(location, rental.model) then return false, "not_available_here" end

    local ok, cooldownErr = checkCooldown(source)
    if not ok then return false, cooldownErr end

    local spawn = findSpawn(location)
    if not spawn then return false, "spawn_blocked" end

    local entity = spawnVehicle(source, rental.model, rental.plate, spawn)
    if not entity then return false, "spawn_failed" end

    rental.vehicle = entity
    rental.pickedUp = true
    rental.location = location.id
    lastAction[source] = os.time()

    MySQL.update.await(("UPDATE `%s` SET `picked_up` = 1, `location` = ? WHERE `id` = ?"):format(TABLE), { location.id, rental.id })

    SetPedIntoVehicle(GetPlayerPed(source), entity, -1)
    giveKeys(source, entity, rental)
    pushUpdate(source)

    Debug("success", "%s collected phone rental #%d (%s) at %s", GetPlayerName(source), rental.id, rental.plate, location.id)

    return true, { id = rental.id, plate = rental.plate, label = rental.label, location = location.label }
end

--[[ Respawning a lost vehicle ]]

---Respawns a collected rental whose vehicle no longer exists.
---@param source number Player server id
---@param rentalId any Rental id sent by the client
---@param locationId string? Office id, nil for a phone respawn
---@param spawnPoint table? Phone respawn: a point next to the player (suggested by the client, verified here). nil = office
---@return boolean success
---@return string|table result Error code, or { id, plate, label, fee, coords }
local function respawn(source, rentalId, locationId, spawnPoint)
    if not Config.Respawn.enabled then return false, "respawn_disabled" end

    local identifier = Framework.Server.GetPlayerIdentifier(source)
    if not identifier then return false, "no_player" end

    local rental, err = getOwnedRental(source, identifier, rentalId)
    if not rental then return false, err end

    -- Phone rentals that were not collected yet can only be collected at an office
    if not rental.pickedUp then return false, "not_picked_up" end
    if rental.expiresAt - os.time() <= MIN_REMAINING then return false, "almost_expired" end
    if vehicleExists(rental) then return false, "vehicle_exists" end

    local spawn, location
    if spawnPoint ~= nil then
        if not Config.Respawn.remote then return false, "respawn_disabled" end

        local x, y, z, w = tonumber(spawnPoint.x), tonumber(spawnPoint.y), tonumber(spawnPoint.z), tonumber(spawnPoint.w)
        if not (x and y and z and w) then
            suspicious(source, "invalid spawn point")
            return false, "invalid"
        end

        spawn = vec4(x, y, z, w)
        if #(getPedCoords(source) - spawn.xyz) > Config.Respawn.maxDistance then
            suspicious(source, "spawn point too far from the player (%.1f m)", #(getPedCoords(source) - spawn.xyz))
            return false, "invalid"
        end
        if not isSpawnFree(spawn) then return false, "spawn_blocked" end
    else
        location = locations[locationId]
        if not location then return false, "invalid" end
        if not isNear(source, location) then
            suspicious(source, "tried to respawn far from the office (%s)", tostring(locationId))
            return false, "too_far"
        end
        spawn = findSpawn(location)
        if not spawn then return false, "spawn_blocked" end
    end

    local ok, cooldownErr = checkCooldown(source)
    if not ok then return false, cooldownErr end

    local fee = Config.Respawn.fee or 0
    local account = chargeFee(source, accounts[rental.payment] and rental.payment or Config.PaymentAccounts[1], fee, "rentacar-respawn")
    if not account then return false, "no_money" end

    local entity = spawnVehicle(source, rental.model, rental.plate, spawn)
    if not entity then
        if fee > 0 then Framework.Server.AddPlayerMoney(source, account, fee, "rentacar-refund") end
        return false, "spawn_failed"
    end

    rental.vehicle = entity
    lastAction[source] = os.time()

    if location then SetPedIntoVehicle(GetPlayerPed(source), entity, -1) end
    giveKeys(source, entity, rental)
    pushUpdate(source)

    Debug("success", "%s respawned rental #%d (%s) %s, fee %d from %s", GetPlayerName(source), rental.id, rental.plate, location and ("at " .. location.id) or "next to the player", fee, account)

    return true, {
        id = rental.id,
        plate = rental.plate,
        label = rental.label,
        fee = fee,
        coords = { x = spawn.x, y = spawn.y },
    }
end

---Short description of client rental data for the debug log.
---@param data any Rental data sent by the client
---@return string
local function describe(data)
    if type(data) ~= "table" then return tostring(data) end
    return ("%s, %s hours, %s"):format(tostring(data.model), tostring(data.hours), tostring(data.payment))
end

---Runs one request per player at a time (double clicks etc.) and logs failures.
---@param source number Player server id
---@param action string Action name for the debug log
---@param fn function Handler returning success, result
---@param ... any Handler arguments
---@return boolean success
---@return any result
local function locked(source, action, fn, ...)
    if pending[source] then
        Debug("warning", "%s from %s ignored, another request is in progress", action, source)
        return false, "busy"
    end
    pending[source] = true

    local ok, success, result = pcall(fn, ...)
    pending[source] = nil

    if not ok then
        Debug("error", "%s from %s threw an error: %s", action, source, success)
        return false, "invalid"
    end

    if not success then Debug("warning", "%s from %s failed: %s", action, source, tostring(result)) end
    return success, result
end

--[[ Office callbacks ]]

---@param source number Player server id
---@param locationId string Office id
---@return table? data Player info, license state and rentals
lib.callback.register("hype-rentacar:server:getData", function(source, locationId)
    local identifier = Framework.Server.GetPlayerIdentifier(source)
    local location = locations[locationId]
    Debug("info", "getData from %s @ %s", source, tostring(locationId))
    if not identifier or not location then return end

    return getData(source, identifier, location)
end)

---@param source number Player server id
---@param locationId string Office id
---@param data { model: string, hours: number, payment: string }
---@return boolean success
---@return string|table result
lib.callback.register("hype-rentacar:server:rent", function(source, locationId, data)
    Debug("info", "rent from %s @ %s: %s", source, tostring(locationId), describe(data))
    return locked(source, "rent", rent, source, locationId, data, false)
end)

---@param source number Player server id
---@param locationId string Office id
---@param rentalId number
---@return boolean success
---@return string|table|nil result Error code, or the refreshed player data
lib.callback.register("hype-rentacar:server:respawn", function(source, locationId, rentalId)
    Debug("info", "respawn from %s @ %s: #%s", source, tostring(locationId), tostring(rentalId))
    local success, result = locked(source, "respawn", respawn, source, rentalId, locationId, nil)
    if not success then return false, result end

    local identifier = Framework.Server.GetPlayerIdentifier(source)
    return true, identifier and getData(source, identifier, locations[locationId]) or nil
end)

---Phone rentals waiting to be collected, asked for when the player talks to the clerk.
---@param source number Player server id
---@param locationId string Office id
---@return table[] list
lib.callback.register("hype-rentacar:server:getPendingPickups", function(source, locationId)
    local identifier = Framework.Server.GetPlayerIdentifier(source)
    local location = locations[locationId]
    if not identifier or not location then return {} end

    local list = {}
    for _, rental in ipairs(getPlayerRentals(identifier)) do
        if not rental.pickedUp and rental.expiresAt - os.time() > MIN_REMAINING then
            list[#list + 1] = {
                id = rental.id,
                model = rental.model,
                label = rental.label,
                plate = rental.plate,
                hours = rental.hours,
                image = getImage(rental.model),
                remaining = rental.expiresAt - os.time(),
                available = isAllowedAt(location, rental.model),
            }
        end
    end

    Debug("info", "getPendingPickups from %s @ %s: %d pending", source, location.id, #list)
    return list
end)

---@param source number Player server id
---@param locationId string Office id
---@param rentalId number
---@return boolean success
---@return string|table result
lib.callback.register("hype-rentacar:server:pickup", function(source, locationId, rentalId)
    Debug("info", "pickup from %s @ %s: #%s", source, tostring(locationId), tostring(rentalId))
    return locked(source, "pickup", pickup, source, locationId, rentalId)
end)

---Returns a rental at the office and pays back the deposit.
---@param source number Player server id
---@param locationId string Office id
---@param rentalId number
---@return boolean success
---@return string|table result Error code, or the refreshed player data with a `returned` summary
lib.callback.register("hype-rentacar:server:return", function(source, locationId, rentalId)
    Debug("info", "return from %s @ %s: #%s", source, tostring(locationId), tostring(rentalId))

    local identifier = Framework.Server.GetPlayerIdentifier(source)
    if not identifier then return false, "no_player" end

    local location = locations[locationId]
    if not location then return false, "invalid" end
    if not isNear(source, location) then
        Debug("warning", "return from %s refused: too far from %s", source, location.id)
        return false, "too_far"
    end

    local rental, err = getOwnedRental(source, identifier, rentalId)
    if not rental then return false, err end

    local exists = vehicleExists(rental)
    if exists and #(GetEntityCoords(rental.vehicle) - location.coords.xyz) > location.returnRadius then
        Debug("warning", "return of #%d refused: vehicle is too far from %s", rental.id, location.id)
        return false, "vehicle_far"
    end

    -- A phone rental returned before collection gets the full deposit back, the vehicle was never used
    local refund = rental.pickedUp and calculateRefund(rental) or rental.deposit
    finishRental(rental, "returned", refund)

    if refund > 0 then Framework.Server.AddPlayerMoney(source, rental.payment, refund, "rentacar-deposit") end
    pushUpdate(source)

    Debug("success", "%s returned %s (#%d, deposit %d/%d%s)", GetPlayerName(source), rental.plate, rental.id, refund, rental.deposit, rental.pickedUp and not exists and ", vehicle missing" or "")

    local result = getData(source, identifier, location)
    result.returned = { label = rental.label, plate = rental.plate, deposit = rental.deposit, refund = refund, missing = rental.pickedUp and not exists }

    return true, result
end)

AddEventHandler("playerDropped", function()
    pending[source] = nil
    lastAction[source] = nil
end)

--[[ Exports for other resources (hype-rentacar-app) ]]

---Vehicles, durations, offices and rules for the phone app.
---@return table catalog
local function getCatalog()
    local list = {}
    for _, vehicle in ipairs(Config.Vehicles) do
        if isAvailableAnywhere(vehicle.model) then
            list[#list + 1] = {
                model = vehicle.model,
                label = vehicle.label,
                category = vehicle.category,
                price = vehicle.price,
                deposit = vehicle.deposit or 0,
                image = getImage(vehicle.model),
            }
        end
    end

    local durationList = {}
    for i, duration in ipairs(Config.Durations) do
        durationList[i] = { hours = duration.hours, discount = duration.discount or 0 }
    end

    local locationList = {}
    for i, location in ipairs(Config.Locations) do
        locationList[i] = { id = location.id, label = location.label, coords = { x = location.coords.x, y = location.coords.y } }
    end

    return {
        company = Config.CompanyName,
        ui = Config.UI,
        vehicles = list,
        durations = durationList,
        locations = locationList,
        accounts = Config.PaymentAccounts,
        requireLicense = Config.License.required == true,
        maxRentals = Config.MaxActiveRentals,
        remote = { enabled = Config.Remote.enabled, fee = Config.Remote.fee or 0 },
        respawn = { enabled = Config.Respawn.enabled and Config.Respawn.remote, fee = Config.Respawn.fee or 0 },
    }
end

exports("GetCatalog", getCatalog)

---Player info, license state and rentals of a player, outside of any office.
---@param source number Player server id
---@return table? data
local function getPlayerData(source)
    local identifier = Framework.Server.GetPlayerIdentifier(source)
    if not identifier then return end
    return getData(source, identifier)
end

exports("GetPlayerData", getPlayerData)

---Phone rental: no vehicle is spawned, the player collects it at any office.
---@param source number Player server id
---@param data { model: string, hours: number, payment: string }
---@return boolean success
---@return string|table result
local function rentRemote(source, data)
    Debug("info", "phone rent from %s: %s", source, describe(data))
    return locked(source, "phone rent", rent, source, nil, data, true)
end

exports("Rent", rentRemote)

---Phone respawn: spawns a collected but lost rental next to the player.
---@param source number Player server id
---@param rentalId number
---@param spawnPoint { x: number, y: number, z: number, w: number }
---@return boolean success
---@return string|table result
local function respawnRemote(source, rentalId, spawnPoint)
    Debug("info", "phone respawn from %s: #%s", source, tostring(rentalId))
    if type(spawnPoint) ~= "table" then return false, "invalid" end
    return locked(source, "phone respawn", respawn, source, rentalId, nil, spawnPoint)
end

exports("Respawn", respawnRemote)

--[[ Startup and expiry check ]]

MySQL.ready(function()
    local expired = MySQL.update.await(("UPDATE `%s` SET `status` = 'expired', `deposit_refund` = 0, `ended_at` = NOW() WHERE `status` = 'active' AND `expires_at` <= NOW()"):format(TABLE))

    local rows = MySQL.query.await(([[
        SELECT `id`, `citizenid`, `location`, `model`, `label`, `plate`, `hours`, `deposit`, `payment`, `picked_up`,
            UNIX_TIMESTAMP(`expires_at`) - UNIX_TIMESTAMP() AS `remaining`
        FROM `%s` WHERE `status` = 'active'
    ]]):format(TABLE)) or {}

    local now = os.time()
    for _, row in ipairs(rows) do
        rentals[row.id] = {
            id = row.id,
            identifier = row.citizenid,
            location = row.location,
            label = row.label,
            model = row.model,
            plate = row.plate,
            payment = row.payment,
            deposit = row.deposit,
            hours = row.hours,
            expiresAt = now + math.max(0, math.floor(row.remaining)),
            pickedUp = row.picked_up == 1 or row.picked_up == true,
        }
    end

    Debug("info", "%d active rentals loaded, %d expired while the resource was stopped", #rows, tonumber(expired) or 0)
end)

CreateThread(function()
    Debug("info", "expiry loop started, checking every %d seconds", Config.CheckInterval)

    while true do
        Wait(Config.CheckInterval * 1000)

        local now = os.time()
        for _, rental in pairs(rentals) do
            local remaining = rental.expiresAt - now

            if remaining <= 0 then
                local refund = Config.Deposit.refundOnExpire and calculateRefund(rental) or 0
                finishRental(rental, "expired", refund)

                local source = Framework.Server.GetSourceFromIdentifier(rental.identifier)
                if refund > 0 then
                    if not source or not Framework.Server.AddPlayerMoney(source, rental.payment, refund, "rentacar-deposit") then
                        Debug("warning", "deposit of rental #%d could not be refunded (owner %s)", rental.id, source and "online, payment failed" or "offline")
                    end
                end
                if source then
                    notify(source, locale("notify.expired", rental.label, rental.plate), "error")
                    pushUpdate(source)
                end

                Debug("info", "rental #%d expired (%s, refund %d, owner %s)", rental.id, rental.plate, refund, source and "online" or "offline")
            elseif not rental.warned and remaining <= Config.ExpireWarning * 60 then
                rental.warned = true

                local source = Framework.Server.GetSourceFromIdentifier(rental.identifier)
                if source then notify(source, locale("notify.expiring", rental.label, math.ceil(remaining / 60)), "warning") end

                Debug("info", "rental #%d expires in %d minutes, owner %s", rental.id, math.ceil(remaining / 60), source and "warned" or "offline")
            end
        end
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= cache.resource then return end
    for _, rental in pairs(rentals) do deleteEntity(rental.vehicle) end
end)
