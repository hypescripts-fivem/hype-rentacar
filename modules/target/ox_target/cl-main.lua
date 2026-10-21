---@diagnostic disable: duplicate-set-field
local resourceName = "ox_target"
if GetResourceState(resourceName) == 'missing' then return end

local ox_target <const> = exports.ox_target

Debug("info", "target module bound to %s", resourceName)

--- Adds target interaction options to a local (non-networked) entity.
---@param entity number The entity handle.
---@param options table Array of target options (name, icon, label, distance, canInteract, onSelect).
---@return nil
function Modules.Client.Target.AddLocalEntity(entity, options)
    ox_target:addLocalEntity(entity, options)
end

exports("AddLocalEntity", Modules.Client.Target.AddLocalEntity)

--- Removes every target interaction option of a local entity.
---@param entity number The entity handle.
---@return nil
function Modules.Client.Target.RemoveLocalEntity(entity)
    ox_target:removeLocalEntity(entity)
end

exports("RemoveLocalEntity", Modules.Client.Target.RemoveLocalEntity)
