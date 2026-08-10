local RESOURCE = GetCurrentResourceName()
local Node7Core = rawget(_G, 'Node7RobbingServerCore') or exports['node7-core']:GetCoreObject()

local lastAttempts = {}
local reportedStates = {}

local function debugPrint(message)
    if Config.Debug then
        print(('[%s] %s'):format(RESOURCE, tostring(message)))
    end
end

local function notify(source, description, notifyType, title)
    Node7Core.Functions.Notify(source, {
        title = tostring(title or 'NODE7 ROBBING'),
        description = tostring(description or ''),
        type = tostring(notifyType or 'info'),
        duration = tonumber(Config.NotifyDuration) or 4500,
    })
end

local function truthy(value)
    return value == true or value == 1 or value == '1' or value == 'true'
end

local function getStateBag(source)
    local playerAccessor = rawget(_G, 'Player')
    if type(playerAccessor) ~= 'function' then return nil end

    local ok, player = pcall(playerAccessor, source)
    if not ok or not player or not player.state then return nil end
    return player.state
end

local function getDistance(source, targetId)
    local sourcePed = GetPlayerPed(source)
    local targetPed = GetPlayerPed(targetId)
    if sourcePed == 0 or targetPed == 0 then return nil end

    local sourceCoords = GetEntityCoords(sourcePed)
    local targetCoords = GetEntityCoords(targetPed)
    if not sourceCoords or not targetCoords then return nil end

    local dx = sourceCoords.x - targetCoords.x
    local dy = sourceCoords.y - targetCoords.y
    local dz = sourceCoords.z - targetCoords.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function metadataHasAny(metadata, keys)
    if type(metadata) ~= 'table' then return false end
    for _, key in ipairs(keys or {}) do
        if truthy(metadata[key]) then return true end
    end
    return false
end

local function isTargetRobbable(targetId, target)
    if not Config.Robbable.RequireTargetState then return true, 'not-required' end

    local state = getStateBag(targetId)
    if state and truthy(state[Config.Robbable.StateKey]) then
        local reason = tostring(state[Config.Robbable.ReasonStateKey] or 'statebag')
        if not Config.Robbable.RequireHandsUp or reason == 'handsup' then
            return true, reason
        end
    end

    local report = reportedStates[targetId]
    local now = GetGameTimer()
    if report and report.robbable and now - report.updatedAt <= (tonumber(Config.Robbable.ReportTimeoutMs) or 7000) then
        local reason = report.reason or 'client-report'
        if not Config.Robbable.RequireHandsUp or reason == 'handsup' then
            return true, reason
        end
    end

    if Config.Robbable.RequireHandsUp then
        return false, nil
    end

    local metadata = target.PlayerData.metadata or {}
    if Config.Robbable.AllowCoreMetadata and metadataHasAny(metadata, Config.Robbable.MetadataKeys) then
        return true, 'metadata'
    end

    if Config.Robbable.AllowDead then
        local ped = GetPlayerPed(targetId)
        if ped ~= 0 and type(IsEntityDead) == 'function' then
            local ok, dead = pcall(IsEntityDead, ped)
            if ok and dead then return true, 'dead' end
        end
    end

    return false, nil
end

local function robberIsUnavailable(player)
    local metadata = player.PlayerData.metadata or {}
    return truthy(metadata.isdead)
        or truthy(metadata.inlaststand)
        or truthy(metadata.ishandcuffed)
        or truthy(metadata.isHandcuffed)
        or truthy(metadata.hogtied)
        or truthy(metadata.ishogtied)
end

local function validateRobbery(source, targetId)
    source = tonumber(source)
    targetId = tonumber(targetId)

    if not source or source <= 0 then return false, 'Invalid robber.' end
    if not targetId or targetId <= 0 or targetId == source then return false, 'Invalid target player.' end
    local player = Node7Core.Functions.GetPlayer(source)
    local target = Node7Core.Functions.GetPlayer(targetId)
    if not player or not target then return false, 'The target player is unavailable.' end

    if robberIsUnavailable(player) then
        return false, 'You cannot rob someone in your current condition.'
    end

    if type(GetPlayerRoutingBucket) == 'function'
        and GetPlayerRoutingBucket(source) ~= GetPlayerRoutingBucket(targetId) then
        return false, 'The target player is unavailable.'
    end

    local distance = getDistance(source, targetId)
    local maximum = (tonumber(Config.MaxDistance) or 2.5) + (tonumber(Config.ServerDistanceTolerance) or 0.75)
    if not distance or distance > maximum then
        return false, 'The target player is too far away.'
    end

    local robbable, reason = isTargetRobbable(targetId, target)
    if not robbable then
        return false, Config.Robbable.RequireHandsUp and 'The target player must have their hands up.' or 'The target must be dead, incapacitated, restrained, or hogtied.'
    end

    return true, nil, player, target, distance, reason or 'unknown'
end

RegisterNetEvent('node7-robbing:server:reportRobbableState', function(robbable, reason)
    local src = source
    reportedStates[src] = {
        robbable = robbable == true,
        reason = robbable == true and tostring(reason or 'restrained') or nil,
        updatedAt = GetGameTimer(),
    }
end)

RegisterNetEvent('node7-robbing:server:requestRob', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    local now = GetGameTimer()
    local cooldown = tonumber(Config.AttemptCooldownMs) or 1500

    if lastAttempts[src] and now - lastAttempts[src] < cooldown then
        notify(src, 'Slow down before trying to rob another player.', 'warning')
        return
    end
    lastAttempts[src] = now

    local allowed, message, player, target, distance, reason = validateRobbery(src, targetId)
    if not allowed then
        notify(src, message, 'error')
        return
    end

    if GetResourceState('node7-inventory') ~= 'started' then
        notify(src, 'The inventory system is unavailable.', 'error')
        return
    end

    local ok, opened = pcall(function()
        return exports['node7-inventory']:OpenInventoryById(src, tonumber(targetId))
    end)

    if not ok then
        print(('^1[%s]^7 OpenInventoryById failed for %s -> %s: %s'):format(
            RESOURCE, tostring(src), tostring(targetId), tostring(opened)
        ))
        notify(src, 'The target inventory could not be opened.', 'error')
        return
    end

    if opened ~= true then
        notify(src, 'That inventory is already busy or unavailable.', 'error')
        return
    end

    local robberName = GetPlayerName(src) or ('Player %d'):format(src)
    local targetName = GetPlayerName(targetId) or ('Player %d'):format(targetId)

    if Config.NotifyTarget then
        notify(targetId, robberName .. ' is searching your inventory.', 'warning')
    end

    notify(src, 'Searching ' .. targetName .. '.', 'success')

    TriggerEvent('node7-log:server:CreateLog', 'playerinventory', 'Player Robbery', 'orange',
        ('**%s (id: %s)** opened **%s (id: %s)** inventory. Distance: %.2f. State: %s.'):format(
            robberName, src, targetName, targetId, distance or 0.0, tostring(reason)
        ))

    debugPrint(('%s robbed %s at %.2fm (%s)'):format(src, targetId, distance or 0.0, tostring(reason)))
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastAttempts[src] = nil
    reportedStates[src] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= RESOURCE then return end
    lastAttempts = {}
    reportedStates = {}
end)

exports('CanRobPlayer', function(source, targetId)
    local allowed, message = validateRobbery(source, targetId)
    return allowed, message
end)
