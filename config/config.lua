-- Units: durations are in seconds unless noted, distances in meters, money in whole dollars.
return {
    Debug = false,                         -- Print debug messages to the server/client console

    Framework = "auto",                    -- "auto" | "qbx" | "qb" | "esx" (auto detects qbx_core > qb-core > es_extended)
    Notifications = "auto",                -- "auto" | "ox_lib" | "okokNotify" | "ps-ui"
    VehicleKeys = "auto",                  -- "auto" | "qbx_vehiclekeys" | "qb-vehiclekeys" | "wasabi_carlock" | "MrNewbVehicleKeys" | "qs-vehiclekeys" | "Renewed-Vehiclekeys" | false

    Fuel = {
        system = "auto",                   -- "auto" | "ox_fuel" | "LegacyFuel" | "cdn-fuel" | "ps-fuel" | "lc_fuel" | false
        level = 100.0,                     -- Fuel level of every rented vehicle (0-100)
    },

    CompanyName = "Los Santos Rent a Car", -- Shown in the UI header and as the notification title

    UI = {
        accent = "#fafafa",                -- Main UI color (hex)
        numberLocale = "en-US",            -- Locale used to format money (Intl.NumberFormat)
        currency = "$",                    -- Currency symbol shown in the UI
    },

    ImageUrl = "https://docs.fivem.net/vehicles/%s.webp", -- Vehicle image, %s = model. A vehicle's own `image` overrides it (URL or nui://hype-rentacar/web/build/images/<file>)

    PaymentAccounts = { "cash", "bank" },  -- Accounts players can pay with, shown in this order (ESX: cash = "money")

    License = {                            -- Driver license requirement, for office and phone rentals
        required = true,                   -- false = no license check
        check = "any",                     -- "metadata" | "item" | "any" (either one is enough)
        metadata = "driver",               -- QBX/QB: metadata.licences.<key> = true | ESX: esx_license type (user_licenses table), set to "drive" on ESX
        item = "driver_license",           -- Inventory item that counts as a license
    },

    MaxActiveRentals = 1,                  -- Max rentals a player can have at the same time
    PlatePrefix = "RENT",                  -- Plate format: prefix + 4 digits (max 8 characters)
    CheckInterval = 30,                    -- How often expired rentals are checked
    ExpireWarning = 5,                     -- Players are warned this many minutes before a rental ends

    Deposit = {
        damageDeduction = true,            -- Deduct from the deposit by vehicle damage on return (engine/body health)
        refundOnExpire = false,            -- Refund the deposit when a rental expires without being returned
    },

    Respawn = {                            -- Respawn a collected rental whose vehicle was deleted while time is left
        enabled = true,                    -- Allow respawning at the office (at the office spawn point)
        remote = true,                     -- Allow respawning from the phone app (next to the player)
        fee = 250,                         -- Fee per respawn (rental account first, then the other accounts)
        maxDistance = 40.0,                -- Max distance between the player and a phone respawn point (server check)
    },

    Remote = {                             -- Phone rentals (hype-rentacar-app): collected later at any office
        enabled = true,                    -- Allow renting from the phone
        fee = 100,                         -- Service fee added to phone rentals
        pickupRadius = 15.0,               -- Max distance to the office when collecting a phone rental (server check)
    },

    Security = {
        cooldown = 5,                      -- Min time between rent / pickup / respawn actions per player
        logSuspicious = true,              -- Always log invalid or suspicious requests, even with Debug off
    },

    Durations = {                          -- Rental durations in real-time hours, discount in percent
        { hours = 1 },
        { hours = 2 },
        { hours = 4,  discount = 5 },
        { hours = 8,  discount = 10 },
        { hours = 24, discount = 20 },
    },

    -- price: base price per hour | deposit: paid back when the vehicle is returned
    -- category: UI tab (locales -> ui.categories.<category>)
    -- type: CreateVehicleServerSetter type (automobile, bike, boat, heli, plane...), defaults to automobile
    Vehicles = {
        { model = "panto",    label = "Benefactor Panto",     category = "compact",    price = 40,  deposit = 300 },
        { model = "asbo",     label = "Maxwell Asbo",         category = "compact",    price = 50,  deposit = 400 },
        { model = "blista",   label = "Dinka Blista",         category = "compact",    price = 60,  deposit = 400 },
        { model = "asea",     label = "Declasse Asea",        category = "sedan",      price = 70,  deposit = 500 },
        { model = "primo",    label = "Albany Primo",         category = "sedan",      price = 80,  deposit = 500 },
        { model = "tailgater", label = "Obey Tailgater",       category = "sedan",      price = 120, deposit = 800 },
        { model = "baller",   label = "Gallivanter Baller",   category = "suv",        price = 150, deposit = 1000 },
        { model = "granger",  label = "Declasse Granger",     category = "suv",        price = 140, deposit = 1000 },
        { model = "sultan",   label = "Karin Sultan",         category = "sport",      price = 220, deposit = 2000 },
        { model = "faggio",   label = "Pegassi Faggio",       category = "motorcycle", price = 25,  deposit = 200,  type = "bike" },
        { model = "bati",     label = "Pegassi Bati 801",     category = "motorcycle", price = 160, deposit = 1500, type = "bike" },
        { model = "speedo",   label = "Vapid Speedo",         category = "van",        price = 110, deposit = 800 },
    },

    Camera = {                             -- Camera facing the clerk while the menu is open (false = disabled)
        fov = 40.0,                        -- Field of view
        transitionIn = 1000,               -- Blend in time (ms)
        transitionOut = 800,               -- Blend out time (ms)
        offset = vec3(0.55, 1.7, 0.65),    -- Camera position relative to the ped
        point = vec3(-0.45, 0.0, 0.55),    -- Look-at point relative to the ped
    },

    Locations = {
        {
            id = "legion",                 -- Unique office id
            label = "Legion Square",       -- Office name shown in the UI
            coords = vec4(109.95, -1088.62, 29.30, 345.0), -- Clerk position and heading
            model = "a_m_y_business_02",   -- Clerk ped model
            scenario = "WORLD_HUMAN_CLIPBOARD", -- Clerk scenario (nil = none)
            interaction = "target",        -- "target" (ox_target / qb-target) | "textui" ([E] key)
            interactDistance = 2.5,        -- Interaction distance to the clerk
            maxDistance = 10.0,            -- Max player distance to the clerk while renting / returning (server check)
            returnRadius = 30.0,           -- Max vehicle distance to the clerk to return it
            blip = { enabled = true, sprite = 225, color = 5, scale = 0.75 },

            spawns = {                     -- Vehicle spawn points, the first free one is used
                vec4(111.37, -1081.27, 28.79, 340.0),
                vec4(107.46, -1079.87, 28.79, 340.0),
                vec4(103.62, -1078.53, 28.79, 340.0),
            },

            vehicles = nil,                -- Models rentable here, nil = every vehicle in Vehicles
        },
    },
}
