local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage:FindFirstChild('Packages'):FindFirstChild('Matter'))
local Components = require(ReplicatedStorage:FindFirstChild('Components'))
local States = require(ReplicatedStorage:FindFirstChild("States"))

local StateTemplate = {
    name = "Name",
    layer = "layer",
    priority = 2, -- future maybe if multiple states of same layer are in effect, whichever is lower priority is accepted

    mustFollow = {"list of states, one of which this state must follow, in the future allow a table of states if they all have to be enabled"},
    cannotFollow = {"list of states this state can not follow"},

    components = {
        ComponentName = {
            StartData = {},
            UpdateData = function(value)
                return {}
            end
        }
    }
}

return function(world)
    for id, record in world:queryChanged(Components.State) do
        --if state added then add components
        --if state changed then add new components then remove old non-shared components
        --if state removed then remove components

        local oldStates = record.old or {}
        local newStates = record.new or {}

        local log = {
            Add = {},
            Remove = {}
        }
        for key, stateName in pairs(newStates) do
            local oldState = oldStates[key]
            local newState = States[stateName]

            if not oldState then
                --state added
                if #newState.mustFollow > 0 then
                    continue
                end
                table.insert(log.Add, stateName)
            elseif oldState ~= stateName then
                --state changed
                if #newState.mustFollow > 0 and not table.find(newState.mustFollow, stateName) or table.find(newState.cannotFollow, oldState) then
                    continue
                end
                table.insert(log.Add, stateName)
            end
        end

        for key, stateName in pairs(oldStates) do
            local newState = newStates[key]
            if not newState then
                --state removed
                table.insert(log.Remove, stateName)
            end
        end

        for i, stateName in ipairs(log.Remove) do
            local state = States[stateName]

            for componentName, _ in pairs(state.components) do
                local toBeContinued = false
                for layer, name in pairs(newStates) do
                    local state2 = States[name]
                    if state2.components[componentName] then
                        toBeContinued = true
                        break
                    end
                end
                if toBeContinued then
                    continue
                end

                world:remove(id, Components[componentName])
            end
        end

        for i, stateName in ipairs(log.Add) do
            local state = States[stateName]

            for componentName, dataOptions in pairs(state.components) do
                local existingComponent = world:get(id, Components[componentName])

                local data = dataOptions.StartData
                if existingComponent and dataOptions.UpdateData then
                    data = dataOptions.UpdateData(existingComponent)
                    world:insert(id, existingComponent:patch(data))
                    continue
                end
                
                world:insert(id, Components[componentName](data))
            end
        end
    end
end