local pendingChoices = {}

local function clearPendingChoice(source)
    pendingChoices[source] = nil
end

local function normalizeButtons(buttons)
    if buttons == nil then
        local result = {}

        for index, button in ipairs(Config.Choice.defaultButtons) do
            result[index] = {
                label = tostring(button.label),
                value = button.value
            }
        end

        return result
    end

    if type(buttons) ~= 'table' then
        return nil
    end

    if #buttons < 1 or #buttons > Config.Choice.maxButtons then
        return nil
    end

    local normalized = {}

    for index, button in ipairs(buttons) do
        if type(button) ~= 'table'
            or type(button.label) ~= 'string'
            or button.value == nil
        then
            return nil
        end

        normalized[index] = {
            label = button.label:sub(1, 64),
            value = button.value
        }
    end

    return normalized
end

local function normalizeChoiceOptions(options)
    options = options or {}

    if type(options) ~= 'table' then
        return nil
    end

    local buttons = normalizeButtons(options.buttons)

    if not buttons then
        return nil
    end

    local timeout = tonumber(options.timeout)
        or Config.Choice.defaultTimeout
        or GetVexNotifyDefaultDuration('choice')

    timeout = math.floor(timeout)

    timeout = math.max(
        Config.DurationLimits.minimum,
        math.min(Config.DurationLimits.maximum, timeout)
    )

    return {
        timeout = timeout,
        buttons = buttons,
        dismissOnDamage = options.dismissOnDamage == true
    }
end

-- Dispatches one independent choice modal to a single validated source.
-- Never called with an unvalidated source -- normalizeTargets() gates entry
-- above. Returns true on successful dispatch, or nil, errorReason.
-- `cb` is always invoked as cb(source, accepted, extraData) so a multi-target
-- call can tell which player produced which answer.
local function dispatchChoiceToSource(source, title, text, cb, normalizedOptions)
    if pendingChoices[source] then
        VexNotifyDebug(
            'Skipping choice dispatch, already pending for source:',
            source
        )

        return nil, 'choice_already_pending'
    end

    local modalId = VexNotifyServer.NextNotificationId('chc')

    pendingChoices[source] = {
        id = modalId,
        createdAt = os.time()
    }

    local resolved = false

    local function resolveOnce(accepted, extraData)
        if resolved then
            return
        end

        resolved = true
        clearPendingChoice(source)

        local safeAccepted = accepted == true

        local ok, err = pcall(cb, source, safeAccepted, extraData or {
            reason = safeAccepted and 'accepted' or 'declined'
        })

        if not ok then
            print(('[vex_notify] Choice callback error (source %s): %s'):format(
                tostring(source),
                tostring(err)
            ))
        end
    end

    local payload = {
        id = modalId,
        title = title,
        message = text,
        buttons = normalizedOptions.buttons,
        timeout = normalizedOptions.timeout,
        dismissOnDamage = normalizedOptions.dismissOnDamage
    }

    local ok, dispatchResult, dispatchError = pcall(function()
        -- This signature follows the export contract established in the supplied
        -- architecture. If vex_callback changes its public contract, adapt only
        -- this boundary rather than implementing transport inside vex_notify.
        return exports['vex_callback']:TriggerClientCallback(
            'vex_notify:resolveChoice',
            source,
            function(result)
                if type(result) ~= 'table' then
                    resolveOnce(false, {
                        reason = 'transport_failure'
                    })

                    return
                end

                if result.timeout == true then
                    resolveOnce(false, {
                        reason = 'timeout'
                    })

                    return
                end

                resolveOnce(result.accepted == true, {
                    reason = result.reason
                        or (result.accepted == true and 'accepted' or 'declined'),

                    value = result.value,
                    id = modalId
                })
            end,
            payload,
            normalizedOptions.timeout
        )
    end)

    if not ok or dispatchResult == nil then
        clearPendingChoice(source)

        return nil, dispatchError
            or tostring(dispatchResult)
            or 'callback_dispatch_failed'
    end

    return true
end

-- target: single source (number), list of sources (table), or -1 (broadcast).
-- cb: function(source, accepted, extraData) -- called independently, once
-- per target that successfully receives a modal. A target skipped up front
-- (invalid id, or already has a pending choice) never fires cb at all --
-- there is no answer to report for a modal that was never shown.
--
-- Broadcast/list targets are capped (Config.Choice.maxBroadcastTargets,
-- default 32) to prevent a single call from opening hundreds of concurrent
-- vex_callback coroutines. This is a hard ceiling, not a silent truncation:
-- exceeding it fails the whole call so the caller notices and scopes down,
-- rather than quietly serving only some of the intended recipients.
exports('ShowChoiceModal', function(target, title, text, cb, options)
    if type(title) ~= 'string' or title == '' then
        return nil, 'invalid_title'
    end

    if type(text) ~= 'string' or text == '' then
        return nil, 'invalid_text'
    end

    if type(cb) ~= 'function' then
        return nil, 'invalid_callback'
    end

    local targets, targetErr = VexNotifyServer.NormalizeTargets(target)

    if not targets then
        return nil, targetErr
    end

    local maxBroadcastTargets = (Config.Choice and Config.Choice.maxBroadcastTargets)
        or 32

    if #targets > maxBroadcastTargets then
        return nil, 'too_many_targets'
    end

    local normalizedOptions = normalizeChoiceOptions(options)

    if not normalizedOptions then
        return nil, 'invalid_options'
    end

    local safeTitle = title:sub(1, 128)
    local safeText = text:sub(1, 1024)

    local dispatchedCount = 0
    local skipped = {}

    for _, source in ipairs(targets) do
        local ok, err = dispatchChoiceToSource(
            source,
            safeTitle,
            safeText,
            cb,
            normalizedOptions
        )

        if ok then
            dispatchedCount = dispatchedCount + 1
        else
            skipped[#skipped + 1] = { source = source, reason = err }
        end
    end

    if dispatchedCount == 0 then
        return nil, 'no_modals_dispatched'
    end

    return true, { dispatched = dispatchedCount, skipped = skipped }
end)

AddEventHandler('playerDropped', function()
    local source = source

    if not pendingChoices[source] then
        return
    end

    clearPendingChoice(source)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    pendingChoices = {}
end)