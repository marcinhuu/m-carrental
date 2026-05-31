local APP_ID = Config.AppIdentifier
local trackedVehicle = nil
local trackedPlate = nil
local activeRental = nil

local function AddApp()
    local added, err = exports['lb-phone']:AddCustomApp({
        identifier  = APP_ID,
        name        = Config.AppName,
        description = Config.AppDescription,
        developer   = Config.AppDeveloper,
        defaultApp  = false,
        size        = math.floor(Config.AppSize * 1024),
        images      = {
            'https://cfx-nui-' .. GetCurrentResourceName() .. '/ui/assets/icon.svg',
        },
        ui   = GetCurrentResourceName() .. '/ui/index.html',
        icon = 'https://cfx-nui-' .. GetCurrentResourceName() .. '/ui/assets/icon.svg',
        fixBlur = true,
    })
    if not added then
        print('^1[cityrentals] Could not register app: ' .. tostring(err) .. '^0')
    end
end

while GetResourceState('lb-phone') ~= 'started' do Wait(500) end
AddApp()
AddEventHandler('onResourceStart', function(res)
    if res == 'lb-phone' then AddApp() end
end)

local function ServerCall(name, data, cb)
    lib.callback(name, false, cb, data or {})
end

local function GetPlayerCoords()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local function FindRentalVehicle(plate)
    if not plate then return nil end
    local vehicles = GetGamePool('CVehicle')
    for _, veh in ipairs(vehicles) do
        if DoesEntityExist(veh) then
            local p = GetVehicleNumberPlateText(veh)
            if p and p:gsub('%s+', '') == plate:gsub('%s+', '') then
                return veh
            end
        end
    end
    return nil
end

local function GetDamagePercent(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return 0 end
    local body = GetVehicleBodyHealth(vehicle)
    local engine = GetVehicleEngineHealth(vehicle)
    local avg = (body + engine) / 2.0
    if avg >= 900.0 then return 0 end
    return math.min(1.0, (1000.0 - avg) / 1000.0)
end

local function DeleteTrackedVehicle()
    if trackedVehicle and DoesEntityExist(trackedVehicle) then
        SetEntityAsMissionEntity(trackedVehicle, true, true)
        DeleteEntity(trackedVehicle)
    end
    trackedVehicle = nil
    trackedPlate = nil
end

local function NotifyPhone(content)
    exports['lb-phone']:SendNotification({
        app = APP_ID,
        title = T('notify_app_title'),
        content = content,
    })
end

local function SyncActiveRental()
    ServerCall('cityrentals:getActiveRental', {}, function(rental)
        activeRental = rental
        if rental and rental.plate then
            trackedPlate = rental.plate
            if rental.status == 'active' then
                trackedVehicle = FindRentalVehicle(rental.plate)
            end
        else
            activeRental = nil
        end
    end)
end

CreateThread(function()
    Wait(2000)
    SyncActiveRental()
end)

CreateThread(function()
    while true do
        Wait(30000)
        if not activeRental or activeRental.status ~= 'active' then goto continue end

        ServerCall('cityrentals:getActiveRental', {}, function(rental)
            if not rental then
                DeleteTrackedVehicle()
                activeRental = nil
                NotifyPhone(T('notify_expired'))
                return
            end
            activeRental = rental
        end)

        ::continue::
    end
end)

CreateThread(function()
    local cfg = Config.Abandoned
    if not cfg.enabled then return end

    while true do
        Wait(60000)
        if not activeRental or activeRental.status ~= 'active' or not trackedPlate then goto skip end

        local veh = trackedVehicle or FindRentalVehicle(trackedPlate)
        if not veh or not DoesEntityExist(veh) then goto skip end

        trackedVehicle = veh
        local ped = PlayerPedId()
        local dist = #(GetEntityCoords(ped) - GetEntityCoords(veh))

        if dist > (cfg.distanceMeters or 120.0) then
            if not activeRental._abandonSince then
                activeRental._abandonSince = GetGameTimer()
            elseif GetGameTimer() - activeRental._abandonSince > (cfg.minutes or 12) * 60000 then
                DeleteTrackedVehicle()
                lib.callback.await('cityrentals:expireRental', false, { rentalId = activeRental.id })
                activeRental = nil
                NotifyPhone(T('notify_impounded'))
            end
        else
            activeRental._abandonSince = nil
        end

        ::skip::
    end
end)

RegisterNUICallback('cityrentals:getLocales', function(_, cb)
    cb({ locales = Locale[Config.Locale] or Locale['en'] or {} })
end)

RegisterNUICallback('cityrentals:getCatalog', function(_, cb)
    local data = lib.callback.await('cityrentals:getCatalog', false)
    if data and data.vehicles then
        cb(data)
        return
    end
    cb({
        vehicles = {},
        categories = Config.Categories,
        durationUnits = Config.DurationUnits,
        paymentMethods = Config.PaymentMethods,
        pickupReturn = Config.PickupReturn,
        maxActive = Config.MaxActiveRentals,
    })
end)

RegisterNUICallback('cityrentals:getActiveRental', function(_, cb)
    ServerCall('cityrentals:getActiveRental', {}, function(rental)
        activeRental = rental
        cb(rental)
    end)
end)

RegisterNUICallback('cityrentals:getHistory', function(data, cb)
    ServerCall('cityrentals:getHistory', data, function(rows)
        cb(rows or {})
    end)
end)

RegisterNUICallback('cityrentals:getPlayerCoords', function(_, cb)
    cb(GetPlayerCoords())
end)

RegisterNUICallback('cityrentals:createRental', function(data, cb)
    data = data or {}
    data.coords = GetPlayerCoords()

    ServerCall('cityrentals:createRental', data, function(ok, msg, payload)
        if not ok then
            cb({ success = false, message = msg })
            return
        end

        cb({ success = true, message = msg, rental = payload })

        Delivery.Start(payload, function(vehicle, rental)
            trackedVehicle = vehicle
            trackedPlate = payload.plate
            activeRental = rental
        end, function(errMsg)
            lib.callback.await('cityrentals:cancelDelivery', false, { rentalId = payload.id })
            NotifyPhone(errMsg or T('err_delivery_failed'))
        end)
    end)
end)

RegisterNUICallback('cityrentals:returnVehicle', function(data, cb)
    local rental = activeRental
    local rentalId = tonumber(data and data.rentalId) or (rental and rental.id)
    if not rentalId then
        cb({ success = false, message = 'No active rental' })
        return
    end

    local plate = (rental and rental.plate) or trackedPlate
    local veh = trackedVehicle or FindRentalVehicle(plate)
    local damagePercent = GetDamagePercent(veh)
    local late = false

    if veh and DoesEntityExist(veh) then
        DeleteTrackedVehicle()
    end

    ServerCall('cityrentals:returnVehicle', {
        rentalId = rentalId,
        damagePercent = damagePercent,
        late = late,
        pickup = false,
    }, function(ok, msg, extra)
        if ok then
            if activeRental and activeRental.id == rentalId then
                activeRental = nil
            end
            trackedPlate = nil
            trackedVehicle = nil
        end
        cb({ success = ok, message = msg, fees = extra })
    end)
end)

RegisterNUICallback('cityrentals:renewRental', function(data, cb)
    ServerCall('cityrentals:renewRental', data, function(ok, msg, rental)
        if ok and rental then activeRental = rental end
        cb({ success = ok, message = msg, rental = rental })
    end)
end)

RegisterNUICallback('cityrentals:cancelDelivery', function(data, cb)
    if data and data.rentalId then
        Delivery.Cancel(data.rentalId)
    end
    ServerCall('cityrentals:cancelDelivery', data, function(ok, msg)
        cb({ success = ok, message = msg })
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    DeleteTrackedVehicle()
end)
