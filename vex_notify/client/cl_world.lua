local overheadEntries = {}

local function removeOverhead(id)
    overheadEntries[id] = nil
end

local function resolveEntity(entry)
    if entry.entity
        and DoesEntityExist(entry.entity)
    then
        return entry.entity
    end

    if entry.netId
        and NetworkDoesEntityExistWithNetworkId(entry.netId)
    then
        local entity = NetworkGetEntityFromNetworkId(entry.netId)

        if entity ~= 0 and DoesEntityExist(entity) then
            entry.entity = entity
            return entity
        end
    end

    return nil
end

local function drawWorldText(x, y, text)
    -- Native text rendering is deliberately isolated here so any RedM-specific
    -- font/native adjustments affect no other vex_notify subsystem.

    SetTextScale(Config.World.text.scale, Config.World.text.scale)
    SetTextColor(240, 226, 196, Config.World.text.alpha)
    SetTextCentre(true)

    DisplayText(
        CreateVarString(10, 'LITERAL_STRING', text),
        x,
        y
    )
end

RegisterNetEvent('vex_notify:client:world', function(payload)
    if not Config.World.enabled then
        return
    end

    if type(payload) ~= 'table'
        or payload.type ~= 'overhead'
        or type(payload.id) ~= 'string'
        or type(payload.message) ~= 'string'
    then
        return
    end

    local duration = tonumber(payload.duration)
        or Config.World.defaultDuration

    overheadEntries[payload.id] = {
        id = payload.id,
        message = payload.message:sub(1, 256),

        entity = payload.entity,
        netId = payload.netId,

        coords = payload.coords,
        offsetZ = tonumber(payload.offsetZ)
            or Config.World.defaultOffsetZ,

        expiresAt = GetGameTimer() + duration
    }
end)

RegisterNetEvent('vex_notify:client:clear', function(notificationId)
    removeOverhead(notificationId)
end)

CreateThread(function()
    while true do
        if next(overheadEntries) == nil then
            Wait(500)
        else
            Wait(0)

            local now = GetGameTimer()
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            for id, entry in pairs(overheadEntries) do
                if now >= entry.expiresAt then
                    removeOverhead(id)
                else
                    local entity = resolveEntity(entry)

                    local worldCoords = nil

                    if entity then
                        worldCoords = GetEntityCoords(entity)
                    elseif type(entry.coords) == 'vector3' then
                        worldCoords = entry.coords
                    end

                    if not worldCoords then
                        removeOverhead(id)
                    else
                        local distance = #(
                            playerCoords - worldCoords
                        )

                        if not Config.World.distanceCull
                            or distance <= Config.World.maxDistance
                        then
                            local onScreen, screenX, screenY =
                                GetScreenCoordFromWorldCoord(
                                    worldCoords.x,
                                    worldCoords.y,
                                    worldCoords.z + entry.offsetZ
                                )

                            if onScreen then
                                drawWorldText(
                                    screenX,
                                    screenY,
                                    entry.message
                                )
                            end
                        end
                    end
                end
            end
        end
    end
end)