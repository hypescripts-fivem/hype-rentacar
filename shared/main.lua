lib.locale()

--- The config is also exposed as a global, because the framework bridge and the
--- modules read Config.Framework, Config.Notifications, Config.VehicleKeys and Config.Fuel directly.
Config = require "config.config"
