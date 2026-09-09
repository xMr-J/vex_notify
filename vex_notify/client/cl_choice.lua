local activeChoice = nil
local localChoiceWaiters = {}

local function clearChoice(id)
    if activeChoice and activeChoice.id == id then
        activeChoice = nil
    end

    VexNotifyClient.ClearChoiceFocus(id)
end

local function showChoice(payload)
    if activeChoice then
        return false, 'choice_already_pending'
    end

    if type(payload) ~= 'table'
        or type(payload.id) ~= 'string'
        or type(payload.title) ~= 'string'
        or type(payload.message) ~= 'string'
        or type(payload.buttons) ~= 'table'
    then
        return false, 'invalid_payload'
    end

    activeChoice = {
        id = payload.id
    }

    VexNotifyClient.SetChoiceFocus(payload.id)

    VexNotifyClient.Send({
        action = 'notify',
        type = 'choice',
        id = payload.id,
        title = payload.title,
        message = payload.message,
        buttons = payload.buttons,
        timeout = payload.timeout
    })

    return true
end

-- This follows the callback export contract established by the architecture.
exports['vex_callback']:RegisterClientCallback(
    'vex_notify:resolveChoice',
    function(payload)
        local success, reason = showChoice(payload)

        if not success then
            return {
                accepted = false,
                reason = reason
            }
        end

        local promiseHandle = promise.new()

        localChoiceWaiters[payload.id] = promiseHandle

        local result = Citizen.Await(promiseHandle)

        localChoiceWaiters[payload.id] = nil

        clearChoice(payload.id)

        if type(result) ~= 'table' then
            return {
                accepted = false,
                reason = 'client_resolution_failure'
            }
        end

        return result
    end
)

RegisterNUICallback('vex_notify:choiceResult', function(data, cb)
    local success, err = pcall(function()
        if type(data) ~= 'table'
            or type(data.id) ~= 'string'
        then
            return
        end

        if not activeChoice or activeChoice.id ~= data.id then
            return
        end

        local waiter = localChoiceWaiters[data.id]

        if waiter then
            waiter:resolve({
                accepted = data.value == true,
                value = data.value,
                reason = data.reason
                    or (data.value == true and 'accepted' or 'declined')
            })
        end

        clearChoice(data.id)
    end)

    if not success then
        VexNotifyDebug('Choice NUI callback failed:', err)

        if activeChoice then
            local waiter = localChoiceWaiters[activeChoice.id]

            if waiter then
                waiter:resolve({
                    accepted = false,
                    reason = 'nui_callback_error'
                })
            end

            clearChoice(activeChoice.id)
        end
    end

    cb({
        ok = success
    })
end)

exports('ShowChoiceLocal', function(title, text, options)
    if activeChoice then
        return false, {
            reason = 'choice_already_pending'
        }
    end

    options = options or {}

    local id = (
        'local_chc_%x_%x'
    ):format(
        GetGameTimer(),
        math.random(0x1000, 0xFFFF)
    )

    local buttons = options.buttons
        or Config.Choice.defaultButtons

    local timeout = tonumber(options.timeout)
        or Config.Choice.defaultTimeout

    local success, reason = showChoice({
        id = id,
        title = tostring(title or ''),
        message = tostring(text or ''),
        buttons = buttons,
        timeout = timeout
    })

    if not success then
        return false, {
            reason = reason
        }
    end

    local waiter = promise.new()
    localChoiceWaiters[id] = waiter

    SetTimeout(timeout, function()
        if not localChoiceWaiters[id] then
            return
        end

        localChoiceWaiters[id]:resolve({
            accepted = false,
            reason = 'timeout'
        })
    end)

    local result = Citizen.Await(waiter)

    localChoiceWaiters[id] = nil

    VexNotifyClient.Send({
        action = 'notifyUpdate',
        id = id,
        op = 'cancel',
        reason = result.reason or 'resolved'
    })

    clearChoice(id)

    return result.accepted == true, result
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    for id, waiter in pairs(localChoiceWaiters) do
        waiter:resolve({
            accepted = false,
            reason = 'resource_stopped'
        })

        localChoiceWaiters[id] = nil
    end

    activeChoice = nil

    SetNuiFocus(false, false)
end)