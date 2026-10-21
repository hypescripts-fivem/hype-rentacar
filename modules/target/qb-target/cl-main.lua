---@diagnostic disable: duplicate-set-field
local resourceName = "qb-target"
if GetResourceState(resourceName) == 'missing' then return end
if GetResourceState("ox_target") ~= 'missing' then return end

local qb_target <const> = exports['qb-target']

Debug("info", "target module bound to %s", resourceName)

--- Adds target interaction options to a local (non-networked) entity. ox_target style options
--- are converted: `onSelect` becomes the qb-target `action` and the largest option distance is used.
---@param entity number The entity handle.
---@param options table Array of target options (name, icon, label, distance, canInteract, onSelect).
---@return nil
function Modules.Client.Target.AddLocalEntity(entity, options)
    local distance = 0

    for _, option in ipairs(options) do
        option.action = option.action or option.onSelect
        distance = math.max(distance, option.distance or 0)
    end

    qb_target:AddTargetEntity(entity, {
        options = options,
        distance = distance > 0 and distance or 2.0,
    })
end

exports("AddLocalEntity", Modules.Client.Target.AddLocalEntity)

--- Removes every target interaction option of a local entity.
---@param entity number The entity handle.
---@return nil
function Modules.Client.Target.RemoveLocalEntity(entity)
    qb_target:RemoveTargetEntity(entity)
end

exports("RemoveLocalEntity", Modules.Client.Target.RemoveLocalEntity)
