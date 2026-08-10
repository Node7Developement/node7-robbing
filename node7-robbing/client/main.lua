local RESOURCE = GetCurrentResourceName()
local Node7Core = rawget(_G, 'Node7RobbingCore') or exports['node7-core']:GetCoreObject()

local radialHandle
local externalRobbable = false
local externalReason
local externalGeneration = 0
local lastReplicatedState
local lastHeartbeat = 0

local function debugPrint(message)
    if Config.Debug then
        print(('[%s] %s'):format(RESOURCE, tostring(message)))
    end
end

local function notify(description, notifyType, title)
    exports['node7-core']:Notify({
        title = tostring(title or 'NODE7 ROBBING'),
        description = tostring(description or ''),
        type = tostring(notifyType or 'info'),
        duration = tonumber(Config.NotifyDuration) or 4500,
    })
end

local function getClosestPlayer(maxDistance)
    local ownPlayer = PlayerId()
    local ownPed = PlayerPedId()
    if ownPed == 0 or not DoesEntityExist(ownPed) then return nil, nil end

    local ownCoords = GetEntityCoords(ownPed)
    local closestPlayer
    local closestDistance = tonumber(maxDistance) or Config.MaxDistance

    for _, player in ipairs(GetActivePlayers()) do
        if player ~= ownPlayer then
            local ped = GetPlayerPed(player)
            if ped ~= 0 and DoesEntityExist(ped) then
                local distance = #(ownCoords - GetEntityCoords(ped))
                if distance <= closestDistance then
                    closestPlayer = player
                    closestDistance = distance
                end
            end
        end
    end

    return closestPlayer, closestDistance
end

local function readCoreMetadata()
    local playerData = Node7Core.Functions.GetPlayerData()
    return type(playerData) == 'table' and type(playerData.metadata) == 'table' and playerData.metadata or {}
end

local function truthy(value)
    return value == true or value == 1 or value == '1' or value == 'true'
end

local function metadataSaysRobbable()
    if not Config.Robbable.AllowCoreMetadata then return false end
    local metadata = readCoreMetadata()
    for _, key in ipairs(Config.Robbable.MetadataKeys or {}) do
        if truthy(metadata[key]) then return true end
    end
    return false
end

local function isPedHogtiedSafe(ped)
    if not Config.Robbable.AllowHogtied then return false end

    if type(IsPedHogtied) == 'function' then
        local ok, result = pcall(IsPedHogtied, ped)
        if ok and truthy(result) then return true end
    end

    local ok, result = pcall(Citizen.InvokeNative, 0x3AA24CCC0D451379, ped)
    return ok and truthy(result)
end

local function isPedHandsUp(ped)
    if ped == 0 or not DoesEntityExist(ped) then return false end

    local dict = tostring(Config.Robbable.HandsUpAnimDict or '')
    local anim = tostring(Config.Robbable.HandsUpAnim or '')
    if dict == '' or anim == '' then return false end

    return IsEntityPlayingAnim(ped, dict, anim, 25) == true
end

local function calculateRobbableState()
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then return false, nil end

    if isPedHandsUp(ped) then
        return true, 'handsup'
    end

    if Config.Robbable.RequireHandsUp then
        return false, nil
    end

    if Config.Robbable.AllowDead and IsEntityDead(ped) then
        return true, 'dead'
    end

    if metadataSaysRobbable() then
        return true, 'restrained'
    end

    if isPedHogtiedSafe(ped) then
        return true, 'hogtied'
    end

    if externalRobbable then
        return true, externalReason or 'restrained'
    end

    return false, nil
end

local function replicateRobbableState(force)
    local state, reason = calculateRobbableState()
    local now = GetGameTimer()
    local heartbeatDue = now - lastHeartbeat >= (tonumber(Config.Robbable.HeartbeatMs) or 3000)

    if not force and state == lastReplicatedState and not heartbeatDue then return end

    lastReplicatedState = state
    lastHeartbeat = now

    pcall(function()
        LocalPlayer.state:set(Config.Robbable.StateKey, state, true)
        LocalPlayer.state:set(Config.Robbable.ReasonStateKey, reason or '', true)
    end)

    TriggerServerEvent('node7-robbing:server:reportRobbableState', state, reason)
end

local function removeRadialOption()
    if not radialHandle or GetResourceState('node7-radialmenu') ~= 'started' then
        radialHandle = nil
        return
    end

    pcall(function()
        exports['node7-radialmenu']:RemoveOption(radialHandle)
    end)
    radialHandle = nil
end

local radialRegistrationGeneration = 0

local function registerRadialOption()
    if GetResourceState('node7-radialmenu') ~= 'started' then return false end

    removeRadialOption()
    pcall(function()
        exports['node7-radialmenu']:RemoveOption(Config.Radial.Handle)
        exports['node7-radialmenu']:RemoveOption(Config.Radial.ItemId)
    end)

    local ok, handle = pcall(function()
        return exports['node7-radialmenu']:AddOption({
            id = Config.Radial.ItemId,
            title = Config.Radial.Title,
            icon = Config.Radial.Icon,
            type = 'client',
            event = 'node7-robbing:client:attemptRob',
            shouldClose = true,
            requiredResource = { 'node7-core', 'node7-inventory', 'node7-robbing' },
        }, Config.Radial.Handle)
    end)

    if ok and handle then
        radialHandle = handle
        debugPrint(('Registered standalone root radial option: %s'):format(handle))
        return true
    end

    debugPrint(('Failed to register standalone root radial option: %s'):format(tostring(handle)))
    return false
end

local function scheduleRadialRegistration(delay)
    radialRegistrationGeneration = radialRegistrationGeneration + 1
    local generation = radialRegistrationGeneration

    CreateThread(function()
        Wait(tonumber(delay) or 0)

        for _ = 1, 40 do
            if generation ~= radialRegistrationGeneration then return end
            if registerRadialOption() then
                TriggerEvent('node7-radialmenu:client:refresh')
                return
            end
            Wait(250)
        end
    end)
end

RegisterNetEvent('node7-radialmenu:client:ready', function()
    scheduleRadialRegistration(0)
end)

RegisterNetEvent('node7-radialmenu:client:requestRegistration', function()
    scheduleRadialRegistration(0)
end)

RegisterNetEvent('node7-robbing:client:attemptRob', function()
    local targetPlayer, distance = getClosestPlayer(Config.MaxDistance)
    if not targetPlayer then
        notify('No player is close enough to rob.', 'error')
        return
    end

    local targetPed = GetPlayerPed(targetPlayer)
    if Config.Robbable.RequireHandsUp and not isPedHandsUp(targetPed) then
        notify('The target player must have their hands up.', 'error')
        return
    end

    local targetId = GetPlayerServerId(targetPlayer)
    if not targetId or targetId <= 0 then
        notify('The target player is unavailable.', 'error')
        return
    end

    TriggerServerEvent('node7-robbing:server:requestRob', targetId, distance)
end)

local function setRobbable(state, reason, duration)
    externalGeneration = externalGeneration + 1
    local generation = externalGeneration

    externalRobbable = state == true
    externalReason = externalRobbable and tostring(reason or 'restrained') or nil
    replicateRobbableState(true)

    duration = tonumber(duration)
    if externalRobbable and duration and duration > 0 then
        CreateThread(function()
            Wait(math.floor(duration))
            if externalGeneration ~= generation then return end
            externalRobbable = false
            externalReason = nil
            replicateRobbableState(true)
        end)
    end

    return true
end

RegisterNetEvent('node7-robbing:client:setRobbable', function(state, reason, duration)
    setRobbable(state, reason, duration)
end)

exports('SetRobbable', setRobbable)

exports('IsRobbable', function()
    return calculateRobbableState()
end)

RegisterCommand(Config.Command, function()
    TriggerEvent('node7-robbing:client:attemptRob')
end, false)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == RESOURCE then
        replicateRobbableState(true)
        scheduleRadialRegistration(500)
    elseif resourceName == 'node7-radialmenu' then
        radialHandle = nil
        scheduleRadialRegistration(250)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == 'node7-radialmenu' then
        radialHandle = nil
        radialRegistrationGeneration = radialRegistrationGeneration + 1
    elseif resourceName == RESOURCE then
        radialRegistrationGeneration = radialRegistrationGeneration + 1
        removeRadialOption()
        pcall(function()
            LocalPlayer.state:set(Config.Robbable.StateKey, false, true)
            LocalPlayer.state:set(Config.Robbable.ReasonStateKey, '', true)
        end)
    end
end)

RegisterNetEvent('Node7Core:Client:OnPlayerLoaded', function()
    replicateRobbableState(true)
    scheduleRadialRegistration(250)
end)

RegisterNetEvent('Node7Core:Client:OnPlayerUnload', function()
    externalRobbable = false
    externalReason = nil
    replicateRobbableState(true)
end)

CreateThread(function()
    while true do
        replicateRobbableState(false)
        Wait(math.max(250, tonumber(Config.Robbable.PollIntervalMs) or 500))
    end
end)

