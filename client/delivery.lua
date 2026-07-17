Delivery = {}
local active = nil
local deliveryBlip = nil

local function LoadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return hash
end

local function UnloadModel(hash)
    if hash then SetModelAsNoLongerNeeded(hash) end
end

local function GetRoadCoords(x, y, z)
    local found, pos, heading = GetClosestVehicleNodeWithHeading(x, y, z, 1, 3.0, 0)
    if found then
        return pos.x, pos.y, pos.z, heading
    end
    return x, y, z, 0.0
end

local function FindSpawnCoords(destX, destY, destZ)
    local cfg = Config.Delivery
    local minD = cfg.spawnDistanceMin or 80.0
    local maxD = cfg.spawnDistanceMax or 140.0
    local dist = minD + math.random() * (maxD - minD)
    local angle = math.random() * math.pi * 2.0
    local sx = destX + math.cos(angle) * dist
    local sy = destY + math.sin(angle) * dist
    return GetRoadCoords(sx, sy, destZ)
end

local function RemoveDeliveryBlip()
    if deliveryBlip and DoesBlipExist(deliveryBlip) then
        RemoveBlip(deliveryBlip)
    end
    deliveryBlip = nil
end

local function SetDeliveryBlip(ped)
    RemoveDeliveryBlip()
    if not ped or not DoesEntityExist(ped) then return end

    local cfg = Config.Delivery
    deliveryBlip = AddBlipForEntity(ped)
    SetBlipSprite(deliveryBlip, cfg.blipSprite or 326)
    SetBlipColour(deliveryBlip, cfg.blipColor or 3)
    SetBlipScale(deliveryBlip, cfg.blipScale or 0.85)
    SetBlipAsShortRange(deliveryBlip, false)
    SetBlipFlashes(deliveryBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(T('blip_delivery'))
    EndTextCommandSetBlipName(deliveryBlip)
end

local function CleanupDelivery(deleteVehicle)
    RemoveDeliveryBlip()
    if not active then return end
    if active.ped and DoesEntityExist(active.ped) then
        DeleteEntity(active.ped)
    end
    if deleteVehicle and active.vehicle and DoesEntityExist(active.vehicle) then
        DeleteEntity(active.vehicle)
    end
    active = nil
end

local function NotifyLb(content)
    Phone.Notify(T('notify_app_title'), content)
end

local function PedSayDelivery(ped)
    if not ped or not DoesEntityExist(ped) then return end

    local lines = {
        T('delivery_speech_1'),
        T('delivery_speech_2'),
        T('delivery_speech_3'),
    }
    local line = lines[math.random(#lines)]

    PlayAmbientSpeech1(ped, 'GENERIC_THANKS', 'SPEECH_PARAMS_FORCE_NORMAL_CLEAR')
    Wait(400)

    BeginTextCommandPrint('STRING')
    AddTextComponentSubstringPlayerName(line)
    EndTextCommandPrint(4500)

    Bridge.Notify(line, 'inform')
end

local function PlayKeyHandoff(ped, vehicle)
    local cfg = Config.Delivery
    TaskLeaveVehicle(ped, vehicle, 0)
    local timeout = GetGameTimer() + 8000
    while GetGameTimer() < timeout do
        if not IsPedInVehicle(ped, vehicle, false) then break end
        Wait(100)
    end

    PedSayDelivery(ped)

    local dict = cfg.keyAnimDict or 'mp_common'
    local anim = cfg.keyAnimName or 'givetake1_a'
    RequestAnimDict(dict)
    local t = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end

    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, cfg.keyAnimMs or 2500, 0, 0, false, false, false)
    Wait(cfg.keyAnimMs or 2500)

    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleEngineOn(vehicle, false, true, false)
end

local function FallbackTeleport(vehicle, ped, destX, destY, destZ)
    if not Config.Delivery.fallbackTeleport then return false end
    local x, y, z, h = GetRoadCoords(destX, destY, destZ)
    SetEntityCoords(vehicle, x, y, z, false, false, false, false)
    SetEntityHeading(vehicle, h)
    SetVehicleOnGroundProperly(vehicle)
    if ped and DoesEntityExist(ped) then
        TaskLeaveVehicle(ped, vehicle, 0)
        Wait(500)
        TaskGoToCoordAnyMeans(ped, destX, destY, destZ, 1.2, 0, false, 786603, 0.0)
    end
    return true
end

function Delivery.IsActive()
    return active ~= nil
end

function Delivery.Cancel(rentalId)
    if not active or active.rentalId ~= rentalId then return end
    if active.vehicle and DoesEntityExist(active.vehicle) then
        DeleteEntity(active.vehicle)
    end
    CleanupDelivery(false)
end

function Delivery.Start(payload, onComplete, onFailed)
    if active then
        if onFailed then onFailed(T('err_delivery_busy')) end
        return
    end

    local cfg = Config.Delivery
    local destX, destY, destZ = payload.delivery.x, payload.delivery.y, payload.delivery.z
    local spawnX, spawnY, spawnZ, spawnH = FindSpawnCoords(destX, destY, destZ)

    local vehHash = LoadModel(payload.vehicleModel)
    local pedHash = LoadModel(cfg.pedModel)
    if not vehHash or not pedHash then
        if onFailed then onFailed(T('err_models_failed')) end
        return
    end

    local vehicle = CreateVehicle(vehHash, spawnX, spawnY, spawnZ, spawnH, true, false)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleNumberPlateText(vehicle, payload.plate)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetEntityHeading(vehicle, spawnH)

    local ped = CreatePed(4, pedHash, spawnX, spawnY, spawnZ, spawnH, true, false)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedIntoVehicle(ped, vehicle, -1)
    SetDriverAbility(ped, 1.0)
    SetDriverAggressiveness(ped, 0.0)

    active = {
        rentalId = payload.id,
        ped = ped,
        vehicle = vehicle,
        plate = payload.plate,
        dest = vector3(destX, destY, destZ),
    }

    SetDeliveryBlip(ped)

    UnloadModel(vehHash)
    UnloadModel(pedHash)

    TaskVehicleDriveToCoord(
        ped, vehicle,
        destX, destY, destZ,
        cfg.driveSpeed or 22.0,
        0, GetEntityModel(vehicle),
        786603,
        5.0, true
    )

    CreateThread(function()
        local startTime = GetGameTimer()
        local maxMs = (cfg.maxDriveSeconds or 180) * 1000
        local arriveDist = cfg.arriveDistance or 12.0
        local lastPos = GetEntityCoords(vehicle)
        local stuckSince = nil

        while active and active.rentalId == payload.id do
            Wait(500)

            if not DoesEntityExist(vehicle) or not DoesEntityExist(ped) then
                CleanupDelivery(false)
                if onFailed then onFailed(T('err_delivery_failed')) end
                return
            end

            local vehCoords = GetEntityCoords(vehicle)
            local dist = #(vehCoords - active.dest)

            if dist <= arriveDist then
                break
            end

            if GetGameTimer() - startTime > maxMs then
                FallbackTeleport(vehicle, ped, destX, destY, destZ)
                Wait(1500)
                break
            end

            local moved = #(vehCoords - lastPos)
            if moved < (cfg.stuckMoveThreshold or 4.0) then
                if not stuckSince then stuckSince = GetGameTimer() end
                if GetGameTimer() - stuckSince > (cfg.stuckCheckSeconds or 25) * 1000 then
                    if FallbackTeleport(vehicle, ped, destX, destY, destZ) then
                        Wait(1500)
                        break
                    end
                    stuckSince = nil
                end
            else
                stuckSince = nil
                lastPos = vehCoords
            end
        end

        if not active then return end

        PlayKeyHandoff(ped, vehicle)
        RemoveDeliveryBlip()

        local ok, msg, rental = lib.callback.await('cityrentals:completeDelivery', false, {
            rentalId = payload.id,
        })

        if not ok then
            CleanupDelivery(true)
            if onFailed then onFailed(msg or T('err_complete_delivery')) end
            return
        end

        Bridge.GiveKeys(payload.plate, vehicle)
        SetVehicleEngineOn(vehicle, true, true, false)

        NotifyLb(T('notify_delivered'))

        if ped and DoesEntityExist(ped) then
            TaskWanderStandard(ped, 10.0, 10)
            SetTimeout(cfg.despawnPedAfterMs or 8000, function()
                if DoesEntityExist(ped) then DeleteEntity(ped) end
            end)
        end

        active = nil

        if onComplete then
            onComplete(vehicle, rental)
        end
    end)
end
