local RESOURCE_NAME = GetCurrentResourceName()

local notificationSequence = 0

local allowedGenericTypes = {
    toast = true,
    anchor = true,
    alert = true,
    overhead = true
}

local function nextNotificationId(prefix)
    notificationSequence = notificationSequence + 1

    if notificationSequence > 2147483647 then
        notificationSequence = 1
    end

    return ('%s_%x_%x'):format(
        prefix or 'ntf',
        os.time(),
        notificationSequence
    )
end

local function isValidSource(source)
    if type(source) ~= 'number' then
        return false
    end

    if source <= 0 then
        return false
    end

    return GetPlayerName(source) ~= nil
end

-- Resolves `target` into a de-duplicated list of validated player sources.
-- Accepts: a single source (number), a list of sources (table), or -1 (all
-- connected players). Invalid entries inside a batch are skipped and logged
-- rather than failing the whole call -- a stale/disconnected id in a list of
-- 30 shouldn't block the other 29. A fully-empty or fully-invalid result is
-- still a hard failure (fail-closed), never a silent no-op.
local function normalizeTargets(target)
    if target == -1 then
        local sources = {}

        for _, playerId in ipairs(GetPlayers()) do
            sources[#sources + 1] = tonumber(playerId)
        end

        if #sources == 0 then
            return nil, 'no_players_online'
        end

        return sources
    end

    if type(target) == 'number' then
        if not isValidSource(target) then
            return nil, 'invalid_target'
        end

        return { target }
    end

    if type(target) == 'table' then
        local seen = {}
        local sources = {}

        for _, candidate in ipairs(target) do
            local numericCandidate = tonumber(candidate)

            if numericCandidate
                and not seen[numericCandidate]
                and isValidSource(numericCandidate)
            then
                seen[numericCandidate] = true
                sources[#sources + 1] = numericCandidate
            else
                VexNotifyDebug(
                    'Skipping invalid/duplicate target in batch dispatch:',
                    tostring(candidate)
                )
            end
        end

        if #sources == 0 then
            return nil, 'no_valid_targets'
        end

        return sources
    end

    return nil, 'invalid_target'
end

local function normalizeDuration(notificationType, duration)
    local definition = GetVexNotifyType(notificationType)

    if not definition then
        return nil
    end

    if definition.lifecycle == 'manual' then
        return nil
    end

    if duration == nil then
        return GetVexNotifyDefaultDuration(notificationType)
    end

    duration = tonumber(duration)

    if not duration then
        return nil
    end

    duration = math.floor(duration)

    return math.max(
        Config.DurationLimits.minimum,
        math.min(Config.DurationLimits.maximum, duration)
    )
end

local function normalizeMessage(message)
    if type(message) ~= 'string' then
        return nil
    end

    message = message:sub(1, 1024)

    if message == '' then
        return nil
    end

    return message
end

VexNotifyServer = VexNotifyServer or {}

VexNotifyServer.IsValidSource = isValidSource
VexNotifyServer.NextNotificationId = nextNotificationId
VexNotifyServer.NormalizeDuration = normalizeDuration
VexNotifyServer.NormalizeMessage = normalizeMessage
VexNotifyServer.NormalizeTargets = normalizeTargets

function VexNotifyServer.DispatchScreen(source, payload)
    TriggerClientEvent('vex_notify:client:screen', source, payload)
end

function VexNotifyServer.DispatchWorld(source, payload)
    TriggerClientEvent('vex_notify:client:world', source, payload)
end

-- target: single source (number), list of sources (table), or -1 (broadcast).
-- Every entry is validated server-side via normalizeTargets before anything
-- crosses the network boundary -- an unvalidated id never reaches
-- TriggerClientEvent.
--
-- Return contract:
--   success (1 target)   -> notificationId, { targetCount = 1 }
--   success (N targets)  -> notificationId, { targetCount = N }
--     (the same notificationId is safe to reuse across targets -- it's only
--     ever resolved against each client's own local NUI/world state, so
--     there's no cross-client collision risk)
--   failure              -> nil, errorReason
exports('ShowNotification', function(target, message, notificationType, duration)
    if not IsValidVexNotifyType(notificationType) then
        return nil, 'invalid_type'
    end

    if not allowedGenericTypes[notificationType] then
        return nil, 'use_dedicated_export'
    end

    local targets, targetErr = normalizeTargets(target)

    if not targets then
        return nil, targetErr
    end

    message = normalizeMessage(message)

    if not message then
        return nil, 'invalid_message'
    end

    local definition = GetVexNotifyType(notificationType)

    if definition.lifecycle == 'manual' and duration ~= nil then
        VexNotifyDebug(
            'Ignoring duration for manual notification type:',
            notificationType
        )
    end

    local notificationId = nextNotificationId('ntf')
    local resolvedDuration = normalizeDuration(notificationType, duration)

    for _, playerSource in ipairs(targets) do
        if definition.subsystem == 'screen' then
            VexNotifyServer.DispatchScreen(playerSource, {
                action = 'notify',
                type = notificationType,
                id = notificationId,
                message = message,
                duration = resolvedDuration,
                meta = {}
            })
        else
            VexNotifyServer.DispatchWorld(playerSource, {
                action = 'show',
                type = notificationType,
                id = notificationId,
                message = message,
                duration = resolvedDuration
                    or Config.World.defaultDuration
            })
        end
    end

    return notificationId, { targetCount = #targets }
end)

exports('ClearNotification', function(source, notificationId)
    if not isValidSource(source) then
        return nil, 'invalid_source'
    end

    if type(notificationId) ~= 'string' or notificationId == '' then
        return nil, 'invalid_notification_id'
    end

    TriggerClientEvent(
        'vex_notify:client:clear',
        source,
        notificationId
    )

    return true
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    VexNotifyDebug('Server initialized.')
end)