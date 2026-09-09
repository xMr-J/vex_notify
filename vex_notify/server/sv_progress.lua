local activeProgress = {}

local function getPlayerRegistry(source)
    activeProgress[source] = activeProgress[source] or {}

    return activeProgress[source]
end

local function normalizeProgressOptions(options)
    options = options or {}

    if type(options) ~= 'table' then
        return nil
    end

    return {
        dismissOnDamage = Config.Progress.allowDamageCancellation
            and options.dismissOnDamage == true,

        dismissOnMove = Config.Progress.allowMoveCancellation
            and options.dismissOnMove == true
    }
end

-- Starts a progress bar for a single validated source. Internal only --
-- never called with an unvalidated source.
local function startProgressForSource(source, message, duration, normalizedOptions)
    local registry = getPlayerRegistry(source)

    -- Progress uses a single slot per player according to the type matrix.
    for progressId in pairs(registry) do
        TriggerClientEvent('vex_notify:client:screen', source, {
            action = 'notifyUpdate',
            id = progressId,
            op = 'cancel',
            reason = 'replaced'
        })

        registry[progressId] = nil
    end

    local progressId = VexNotifyServer.NextNotificationId('prg')

    registry[progressId] = {
        id = progressId
    }

    VexNotifyServer.DispatchScreen(source, {
        action = 'notify',
        type = 'progress',
        id = progressId,
        message = message,
        duration = duration,
        meta = normalizedOptions
    })

    return progressId
end

-- target: single source (number), list of sources (table), or -1 (broadcast).
--
-- Return contract (kept backward-compatible with the single-target callers
-- this export originally shipped with):
--   single target  -> progressId (string)          -- unchanged shape
--   multi target   -> { [source] = progressId, ... } -- keyed by source,
--                      since each player gets an independently-tracked bar
--   failure        -> nil, errorReason
exports('StartProgress', function(target, message, duration, options)
    message = VexNotifyServer.NormalizeMessage(message)

    if not message then
        return nil, 'invalid_message'
    end

    duration = VexNotifyServer.NormalizeDuration('progress', duration)

    if not duration then
        return nil, 'invalid_duration'
    end

    local normalizedOptions = normalizeProgressOptions(options)

    if not normalizedOptions then
        return nil, 'invalid_options'
    end

    local targets, targetErr = VexNotifyServer.NormalizeTargets(target)

    if not targets then
        return nil, targetErr
    end

    if #targets == 1 then
        return startProgressForSource(
            targets[1],
            message,
            duration,
            normalizedOptions
        )
    end

    local results = {}

    for _, source in ipairs(targets) do
        results[source] = startProgressForSource(
            source,
            message,
            duration,
            normalizedOptions
        )
    end

    return results
end)

exports('UpdateProgress', function(source, progressId, message)
    if not VexNotifyServer.IsValidSource(source) then
        return nil, 'invalid_source'
    end

    local registry = activeProgress[source]

    if not registry or not registry[progressId] then
        return nil, 'progress_not_found'
    end

    message = VexNotifyServer.NormalizeMessage(message)

    if not message then
        return nil, 'invalid_message'
    end

    TriggerClientEvent('vex_notify:client:screen', source, {
        action = 'notifyUpdate',
        id = progressId,
        op = 'update',
        message = message
    })

    return true
end)

exports('CancelProgress', function(source, progressId, reason)
    if not VexNotifyServer.IsValidSource(source) then
        return nil, 'invalid_source'
    end

    local registry = activeProgress[source]

    if not registry or not registry[progressId] then
        return true
    end

    registry[progressId] = nil

    TriggerClientEvent('vex_notify:client:screen', source, {
        action = 'notifyUpdate',
        id = progressId,
        op = 'cancel',
        reason = type(reason) == 'string'
            and reason:sub(1, 128)
            or 'cancelled'
    })

    return true
end)

RegisterNetEvent('vex_notify:server:progressLifecycle', function(data)
    local source = source

    if type(data) ~= 'table'
        or type(data.id) ~= 'string'
    then
        return
    end

    local registry = activeProgress[source]

    if not registry then
        return
    end

    registry[data.id] = nil

    if next(registry) == nil then
        activeProgress[source] = nil
    end
end)

AddEventHandler('playerDropped', function()
    activeProgress[source] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    activeProgress = {}
end)