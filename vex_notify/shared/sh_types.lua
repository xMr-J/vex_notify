VexNotifyTypes = {
    toast = {
        subsystem = 'screen',
        renderMode = 'queue',
        lifecycle = 'timed',
        defaultDuration = 4000,
        stacking = 'vertical_stack',
        priority = 1,
        requiresFocus = false,
        dismissible = false
    },

    anchor = {
        subsystem = 'screen',
        renderMode = 'persistent',
        lifecycle = 'manual',
        defaultDuration = nil,
        stacking = 'single_slot',
        priority = 2,
        requiresFocus = false,
        dismissible = false
    },

    alert = {
        subsystem = 'screen',
        renderMode = 'interrupt',
        lifecycle = 'timed',
        defaultDuration = 6000,
        stacking = 'single_slot',
        priority = 4,
        requiresFocus = false,
        dismissible = false
    },

    choice = {
        subsystem = 'screen',
        renderMode = 'modal',
        lifecycle = 'user_input',
        defaultDuration = 15000,
        stacking = 'exclusive',
        priority = 5,
        requiresFocus = true,
        dismissible = false
    },

    progress = {
        subsystem = 'screen',
        renderMode = 'persistent',
        lifecycle = 'durational',
        defaultDuration = 5000,
        stacking = 'single_slot',
        priority = 3,
        requiresFocus = false,
        dismissible = 'cancelable'
    },

    overhead = {
        subsystem = 'world',
        renderMode = 'world_anchor',
        lifecycle = 'timed_or_bound',
        defaultDuration = 3000,
        stacking = 'per_entity',
        priority = 2,
        requiresFocus = false,
        dismissible = false
    }
}

local function freezeTable(tbl)
    return setmetatable(tbl, {
        __newindex = function()
            error('VexNotifyTypes is read-only.', 2)
        end,

        __metatable = false
    })
end

for _, definition in pairs(VexNotifyTypes) do
    freezeTable(definition)
end

freezeTable(VexNotifyTypes)

function IsValidVexNotifyType(notificationType)
    return type(notificationType) == 'string'
        and VexNotifyTypes[notificationType] ~= nil
end

function GetVexNotifyType(notificationType)
    if not IsValidVexNotifyType(notificationType) then
        return nil
    end

    return VexNotifyTypes[notificationType]
end

function GetVexNotifyDefaultDuration(notificationType)
    local definition = GetVexNotifyType(notificationType)

    if not definition then
        return nil
    end

    if Config
        and Config.Durations
        and Config.Durations[notificationType] ~= nil
    then
        return Config.Durations[notificationType]
    end

    return definition.defaultDuration
end