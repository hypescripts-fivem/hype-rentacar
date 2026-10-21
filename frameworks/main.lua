Framework = {
    Name = nil,
    Server = {},
    Client = {}
}

local RESOURCES <const> = {
    qbx = 'qbx_core',
    qb = 'qb-core',
    esx = 'es_extended',
}

-- qbx_core provides 'qb-core', so it has to be checked first.
local CANDIDATES <const> = { 'qbx_core', 'qb-core', 'es_extended' }

--- Resolves the framework resource, honouring Config.Framework ("auto" detects it).
---@return string|nil The framework resource name, or nil when none is running.
local function detect()
    local configured = Config.Framework or 'auto'
    if configured ~= 'auto' then return RESOURCES[configured] or configured end

    for _, resource in ipairs(CANDIDATES) do
        local state = GetResourceState(resource)
        if state == 'started' or state == 'starting' then return resource end
    end

    return nil
end

Framework.Name = detect()

if Framework.Name then
    Debug('info', 'framework bridge: %s', Framework.Name)
else
    print('^1[hype-rentacar] No supported framework found. Start qbx_core, qb-core or es_extended, or set Config.Framework.^0')
end

--- Returns the framework bridge for the current side.
--- Exported as `GetFrameworkObject` for use by other resources.
---@return table The Framework.Server table on the server, Framework.Client on the client.
if IsDuplicityVersion() then
    exports('GetFrameworkObject', function()
        return Framework.Server
    end)
else
    exports('GetFrameworkObject', function()
        return Framework.Client
    end)
end
