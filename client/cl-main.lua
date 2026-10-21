local Config <const> = require "config.config"

local isOpen = false
local currentLocation = nil
local cam = nil
local radarWasHidden = false

---@type table<string, number> Location id to clerk ped
local peds = {}

---Plays a frontend sound from the default HUD soundset.
---@param name string Sound name
---@return nil
local function playSound(name)
    PlaySoundFrontend(-1, name, "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
end

---Sends a notification through the notify module.
---@param description string Notification text
---@param notifyType string? "success" | "error" | "warning" | "inform"
---@return nil
local function notify(description, notifyType)
    Modules.Client.Notify.SendNotify(Config.CompanyName, description, 5000, notifyType or "success")
end

---Vehicles offered at a location, in the shape the UI expects.
---@param location table Config location
---@return table[]
local function getVehicles(location)
    local allowed
    if location.vehicles then
        allowed = {}
        for _, model in ipairs(location.vehicles) do allowed[model] = true end
    end

    local list = {}
    for _, vehicle in ipairs(Config.Vehicles) do
        if not allowed or allowed[vehicle.model] then
            list[#list + 1] = {
                model = vehicle.model,
                label = vehicle.label,
                category = vehicle.category,
                price = vehicle.price,
                deposit = vehicle.deposit or 0,
                image = vehicle.image or Config.ImageUrl:format(vehicle.model),
            }
        end
    end
    return list
end

---@return { hours: number, discount: number }[]
local function getDurations()
    local list = {}
    for i, duration in ipairs(Config.Durations) do
        list[i] = { hours = duration.hours, discount = duration.discount or 0 }
    end
    return list
end

---Points a scripted camera at the clerk and hides the player while the menu is open.
---@param location table Config location
---@return nil
local function createCamera(location)
    local ped = peds[location.id]
    if not Config.Camera or not ped or not DoesEntityExist(ped) then return end

    local camCfg = Config.Camera
    local camCoords = GetOffsetFromEntityInWorldCoords(ped, camCfg.offset.x, camCfg.offset.y, camCfg.offset.z)
    local pointCoords = GetOffsetFromEntityInWorldCoords(ped, camCfg.point.x, camCfg.point.y, camCfg.point.z)

    cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camCoords.x, camCoords.y, camCoords.z, 0.0, 0.0, 0.0, camCfg.fov, false, 2)
    PointCamAtCoord(cam, pointCoords.x, pointCoords.y, pointCoords.z)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, camCfg.transitionIn, true, true)

    local activeCam = cam
    CreateThread(function()
        while isOpen and cam == activeCam do
            SetEntityLocallyInvisible(cache.ped)
            Wait(0)
        end
    end)
end

---Blends back to the gameplay camera.
---@param instant boolean? Skip the transition
---@return nil
local function destroyCamera(instant)
    if not cam then return end

    local duration = instant and 0 or Config.Camera.transitionOut
    RenderScriptCams(false, not instant, duration, true, true)

    local oldCam = cam
    cam = nil

    SetTimeout(duration, function()
        if DoesCamExist(oldCam) then DestroyCam(oldCam, false) end
    end)
end

---Opens the rental menu of an office.
---@param location table Config location
---@return nil
function OpenRental(location)
    if isOpen or cache.vehicle then return end

    local data = lib.callback.await("hype-rentacar:server:getData", false, location.id)
    if not data then return Debug("error", "could not load the player data for %s", location.id) end

    isOpen = true
    currentLocation = location
    radarWasHidden = IsRadarHidden()
    DisplayRadar(false)

    createCamera(location)
    playSound("SELECT")

    SendNUIMessage({
        action = "nui/open",
        payload = {
            locales = lib.getLocales(),
            ui = Config.UI,
            company = { name = Config.CompanyName, location = location.label },
            player = data.player,
            license = data.license,
            requireLicense = Config.License.required == true,
            maxRentals = Config.MaxActiveRentals,
            rentals = data.rentals,
            vehicles = getVehicles(location),
            durations = getDurations(),
            accounts = Config.PaymentAccounts,
        }
    })
    SetNuiFocus(true, true)

    Debug("info", "rental menu opened at %s (%d active rentals, license %s)", location.id, #(data.rentals or {}), tostring(data.license))
end

---Closes the rental menu.
---@param instant boolean? Skip the camera transition
---@return nil
function CloseRental(instant)
    if not isOpen then return end
    isOpen = false

    local location = currentLocation
    currentLocation = nil

    SetNuiFocus(false, false)
    SendNUIMessage({ action = "nui/hide" })

    destroyCamera(instant)
    DisplayRadar(not radarWasHidden)

    Debug("info", "rental menu closed at %s", location and location.id or "?")
end

---@param _ any
---@param cb function NUI response callback
RegisterNUICallback("nui/close", function(_, cb)
    cb({ success = true })
    playSound("BACK")
    CloseRental()
end)

---@param data { type: string }?
---@param cb function NUI response callback
RegisterNUICallback("nui/sound", function(data, cb)
    cb({ success = true })
    playSound(data?.type == "select" and "SELECT" or "NAV_UP_DOWN")
end)

---@param data { model: string, hours: number, payment: string }
---@param cb function NUI response callback
RegisterNUICallback("nui/rent", function(data, cb)
    if not currentLocation then return cb({ success = false, error = "invalid" }) end

    local success, result = lib.callback.await("hype-rentacar:server:rent", false, currentLocation.id, data)
    cb({ success = success, data = success and result or nil, error = not success and result or nil })
    if not success then return Debug("warning", "rent failed: %s", tostring(result)) end

    Debug("success", "rented %s (%s) for %d hours", result.label, result.plate, result.hours)
    PlaySoundFrontend(-1, "PURCHASE", "HUD_LIQUOR_STORE_SOUNDSET", true)
    CloseRental(true)
    notify(locale("notify.rented", result.label, result.plate, result.hours), "success")
end)

---@param data { id: number }
---@param cb function NUI response callback
RegisterNUICallback("nui/return", function(data, cb)
    if not currentLocation then return cb({ success = false, error = "invalid" }) end

    local success, result = lib.callback.await("hype-rentacar:server:return", false, currentLocation.id, data?.id)
    cb({ success = success, data = success and result or nil, error = not success and result or nil })
    if not success then return Debug("warning", "return of #%s failed: %s", tostring(data?.id), tostring(result)) end

    Debug("success", "returned #%s, refund %s", tostring(data?.id), tostring(result.returned and result.returned.refund))
    playSound("SELECT")
end)

---@param data { id: number }
---@param cb function NUI response callback
RegisterNUICallback("nui/respawn", function(data, cb)
    if not currentLocation then return cb({ success = false, error = "invalid" }) end

    local success, result = lib.callback.await("hype-rentacar:server:respawn", false, currentLocation.id, data?.id)
    cb({ success = success, data = success and result or nil, error = not success and result or nil })
    if not success then return Debug("warning", "respawn of #%s failed: %s", tostring(data?.id), tostring(result)) end

    Debug("success", "respawned #%s at %s", tostring(data?.id), currentLocation.id)
    PlaySoundFrontend(-1, "PURCHASE", "HUD_LIQUOR_STORE_SOUNDSET", true)
    CloseRental(true)
end)

--[[ Collecting phone rentals ]]

local pickupLocation = nil

---Closes the pickup modal.
---@return nil
local function closePickup()
    if not pickupLocation then return end

    Debug("info", "pickup modal closed at %s", pickupLocation.id)
    pickupLocation = nil

    SetNuiFocus(false, false)
    SendNUIMessage({ action = "nui/pickup:hide" })
end

---Opens the pickup modal when phone rentals are waiting. The vehicle only spawns once the player confirms.
---@param location table Config location
---@return boolean opened
local function openPendingPickups(location)
    local list = lib.callback.await("hype-rentacar:server:getPendingPickups", false, location.id)
    if not list or #list == 0 or isOpen or pickupLocation then return false end

    pickupLocation = location
    playSound("SELECT")

    SendNUIMessage({
        action = "nui/pickup",
        payload = {
            locales = lib.getLocales(),
            ui = Config.UI,
            company = { name = Config.CompanyName, location = location.label },
            rentals = list,
        }
    })
    SetNuiFocus(true, true)

    Debug("info", "pickup modal opened at %s (%d pending)", location.id, #list)
    return true
end

local interacting = false

---Clerk interaction: the pickup modal when a phone rental is waiting, otherwise the rental menu.
---@param location table Config location
---@return nil
local function interact(location)
    if interacting or isOpen or pickupLocation or cache.vehicle or IsNuiFocused() then return end
    interacting = true

    if not (Config.Remote.enabled and openPendingPickups(location)) then OpenRental(location) end

    interacting = false
end

-- Closing the pickup modal without collecting opens the same office's rental menu
---@param _ any
---@param cb function NUI response callback
RegisterNUICallback("nui/pickup:close", function(_, cb)
    cb({ success = true })
    local location = pickupLocation
    closePickup()
    if location then OpenRental(location) end
end)

-- Called from the pickup modal and from the active rental card in the office menu
---@param data { id: number }
---@param cb function NUI response callback
RegisterNUICallback("nui/pickup", function(data, cb)
    local location = pickupLocation or currentLocation
    if not location then return cb({ success = false, error = "invalid" }) end

    local success, result = lib.callback.await("hype-rentacar:server:pickup", false, location.id, data?.id)
    cb({ success = success, data = success and result or nil, error = not success and result or nil })
    if not success then return Debug("warning", "pickup of #%s failed: %s", tostring(data?.id), tostring(result)) end

    Debug("success", "collected %s (%s) at %s", result.label, result.plate, location.id)
    PlaySoundFrontend(-1, "PURCHASE", "HUD_LIQUOR_STORE_SOUNDSET", true)
    closePickup()
    CloseRental(true)
    notify(locale("notify.picked_up", result.label, result.plate), "success")
end)

--[[ Clerks, interaction and blips ]]

---Interaction type of a location. "target" falls back to "textui" when no target resource runs.
---@param location table Config location
---@return string? interaction "target" | "textui"
local function getInteraction(location)
    if location.interaction == "target" and not Modules.Client.Target.AddLocalEntity then
        Debug("warning", "no target resource found, %s uses textui instead", location.id)
        return "textui"
    end
    return location.interaction
end

local interactions = {}
for _, location in ipairs(Config.Locations) do interactions[location.id] = getInteraction(location) end

---Spawns the clerk of a location and registers its target options.
---@param location table Config location
---@return nil
local function spawnPed(location)
    if peds[location.id] and DoesEntityExist(peds[location.id]) then return end

    local coords = location.coords
    lib.requestModel(location.model, 5000)

    local ped = CreatePed(4, location.model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
    SetModelAsNoLongerNeeded(location.model)

    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if location.scenario then TaskStartScenarioInPlace(ped, location.scenario, 0, true) end

    if interactions[location.id] == "target" then
        Modules.Client.Target.AddLocalEntity(ped, {
            {
                name = "hype-rentacar:open",
                icon = "fa-solid fa-car",
                label = locale("interact_label"),
                distance = location.interactDistance,
                canInteract = function() return not cache.vehicle end,
                onSelect = function() interact(location) end,
            },
        })
    end

    peds[location.id] = ped
    Debug("info", "clerk spawned at %s", location.id)
end

---Removes the clerk of a location and its target options.
---@param location table Config location
---@return nil
local function deletePed(location)
    local ped = peds[location.id]
    if not ped then return end
    if interactions[location.id] == "target" then Modules.Client.Target.RemoveLocalEntity(ped) end
    if DoesEntityExist(ped) then DeleteEntity(ped) end
    peds[location.id] = nil
    Debug("info", "clerk removed at %s", location.id)
end

local textUiShown = nil

for _, location in ipairs(Config.Locations) do
    local point = lib.points.new({ coords = location.coords.xyz, distance = 50.0 })

    ---@return nil
    function point:onEnter() spawnPed(location) end

    ---@return nil
    function point:onExit()
        deletePed(location)
        if textUiShown == location.id then lib.hideTextUI(); textUiShown = nil end
    end

    if interactions[location.id] == "textui" then
        ---Shows the [E] prompt in range and opens the clerk interaction on key press.
        ---@return nil
        function point:nearby()
            local inRange = self.currentDistance <= location.interactDistance and not isOpen and not pickupLocation and not cache.vehicle
            local shown = textUiShown == location.id

            if inRange ~= shown then
                textUiShown = inRange and location.id or nil
                if inRange then lib.showTextUI(locale("interact_text")) else lib.hideTextUI() end
            end

            if inRange and IsControlJustPressed(0, 38) then CreateThread(function() interact(location) end) end
        end
    end

    if location.blip.enabled then
        local blip = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
        SetBlipSprite(blip, location.blip.sprite)
        SetBlipColour(blip, location.blip.color)
        SetBlipScale(blip, location.blip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(locale("blip_name"))
        EndTextCommandSetBlipName(blip)
    end
end

Debug("info", "rentacar client loaded: %d locations", #Config.Locations)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= cache.resource then return end
    closePickup()
    CloseRental(true)
    for _, location in ipairs(Config.Locations) do deletePed(location) end
    if textUiShown then lib.hideTextUI() end
end)

---@return boolean isOpen Whether the rental menu is open
exports("IsOpen", function() return isOpen end)

---Closes the rental menu.
---@return nil
exports("Close", function() CloseRental() end)
