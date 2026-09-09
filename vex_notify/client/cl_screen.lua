local activeScreenNotifications = {}
local activeChoiceId = nil

VexNotifyClient = VexNotifyClient or {}

local function setFocus(enabled)
    SetNuiFocus(enabled == true, enabled == true)
end

local function send(payload)
    SendNUIMessage(payload)
end

function VexNotifyClient.Send(payload)
    send(payload)
end

function VexNotifyClient.SetChoiceFocus(id)
    activeChoiceId = id
    setFocus(id ~= nil)
end

function VexNotifyClient.ClearChoiceFocus(id)
    if id ~= nil
        and activeChoiceId ~= nil
        and id ~= activeChoiceId
    then
        return
    end

    activeChoiceId = nil
    setFocus(false)
end

RegisterNetEvent('vex_notify:client:screen', function(payload)
    if type(payload) ~= 'table' then
        return
    end

    if type(payload.action) ~= 'string' then
        return
    end

    if payload.id then
        activeScreenNotifications[payload.id] = payload.type or true
    end

    send(payload)
end)

RegisterNetEvent('vex_notify:client:clear', function(notificationId)
    if type(notificationId) ~= 'string' then
        return
    end

    activeScreenNotifications[notificationId] = nil

    send({
        action = 'notifyUpdate',
        id = notificationId,
        op = 'cancel',
        reason = 'cleared'
    })
end)

RegisterNUICallback('vex_notify:lifecycleEvent', function(data, cb)
    local success, err = pcall(function()
        if type(data) ~= 'table' then
            return
        end

        if type(data.id) ~= 'string' then
            return
        end

        activeScreenNotifications[data.id] = nil

        if data.event == 'completed'
            or data.event == 'cancelled'
        then
            TriggerServerEvent(
                'vex_notify:server:progressLifecycle',
                {
                    id = data.id,
                    event = data.event
                }
            )
        end
    end)

    if not success then
        VexNotifyDebug('NUI lifecycle callback failed:', err)
    end

    cb({
        ok = success
    })
end)

exports('Show', function(message, notificationType, duration)
    notificationType = notificationType or 'toast'

    if not IsValidVexNotifyType(notificationType) then
        return nil, 'invalid_type'
    end

    local definition = GetVexNotifyType(notificationType)

    if definition.subsystem ~= 'screen' then
        return nil, 'world_type_requires_world_renderer'
    end

    if notificationType == 'choice'
        or notificationType == 'progress'
    then
        return nil, 'use_dedicated_export'
    end

    if type(message) ~= 'string' or message == '' then
        return nil, 'invalid_message'
    end

    local notificationId = (
        'local_%x_%x'
    ):format(
        GetGameTimer(),
        math.random(0x1000, 0xFFFF)
    )

    send({
        action = 'notify',
        type = notificationType,
        id = notificationId,
        message = message:sub(1, 1024),
        duration = duration
            or GetVexNotifyDefaultDuration(notificationType),
        meta = {}
    })

    return notificationId
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    -- Critical fail-safe from the architecture:
    -- never leave the player trapped in NUI focus after a restart.
    activeChoiceId = nil

    SetNuiFocus(false, false)

    SendNUIMessage({
        action = 'reset'
    })
end)