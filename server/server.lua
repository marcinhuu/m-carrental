local ActiveRentals = {}

local function InitDatabase()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'cityrentals.sql')
    if not sql or sql == '' then
        print('^1[cityrentals] cityrentals.sql not found^0')
        return false
    end
    for statement in sql:gmatch('[^;]+') do
        statement = statement:match('^%s*(.-)%s*$')
        if statement and statement ~= '' then
            MySQL.query.await(statement)
        end
    end
    print('^2[cityrentals] Database ready^0')
    return true
end

MySQL.ready(function()
    InitDatabase()
end)

local function GetCitizenId(source)
    local Player = Bridge.GetPlayer(source)
    if not Player then return nil end
    return Bridge.GetPlayerIdentifier(Player)
end

local function GetVehicleConfig(key)
    return Config.Vehicles[key]
end

local function DurationToMinutes(durationType, durationValue)
    durationValue = math.max(1, math.floor(tonumber(durationValue) or 1))
    for _, unit in ipairs(Config.DurationUnits) do
        if unit.id == durationType then
            return durationValue * unit.multiplier
        end
    end
    return durationValue
end

local function CalculatePrice(vehicleCfg, durationType, durationValue)
    local prices = vehicleCfg.prices or {}
    local unitPrice = prices[durationType] or prices.minute or 0
    return math.floor(unitPrice * math.max(1, tonumber(durationValue) or 1))
end

local function GeneratePlate()
    local plate = ('RENT%04d'):format(math.random(1000, 9999))
    local exists = MySQL.scalar.await('SELECT id FROM cityrentals_rentals WHERE plate = ? LIMIT 1', { plate })
    if exists then return GeneratePlate() end
    return plate
end

local function FormatRental(row)
    if not row then return nil end
    return {
        id = row.id,
        vehicleKey = row.vehicle_key,
        vehicleModel = row.vehicle_model,
        vehicleLabel = row.vehicle_label,
        category = row.category,
        plate = row.plate,
        durationType = row.duration_type,
        durationValue = row.duration_value,
        pricePaid = row.price_paid,
        damageFee = row.damage_fee,
        lateFee = row.late_fee,
        paymentMethod = row.payment_method,
        status = row.status,
        delivery = { x = row.delivery_x, y = row.delivery_y, z = row.delivery_z },
        startsAt = row.starts_at,
        expiresAt = row.expires_at,
        createdAt = row.created_at,
    }
end

local function CountActiveRentals(citizenid)
    return MySQL.scalar.await([[
        SELECT COUNT(*) FROM cityrentals_rentals
        WHERE citizenid = ? AND status IN ('pending_delivery', 'delivering', 'active')
    ]], { citizenid }) or 0
end

local function SendPhoneNotification(source, title, content)
    exports['lb-phone']:SendNotification(source, {
        app = Config.AppIdentifier,
        title = title,
        content = content,
    })
end

local function SetRentalExpired(rentalId, citizenid, source)
    MySQL.update.await(
        "UPDATE cityrentals_rentals SET status = 'expired' WHERE id = ? AND citizenid = ?",
        { rentalId, citizenid }
    )
    ActiveRentals[citizenid] = nil
    if source then
        SendPhoneNotification(source, T('notify_app_title'), T('notify_expired'))
    end
end

CreateThread(function()
    while true do
        Wait(60000)
        local expiring = MySQL.query.await([[
            SELECT id, citizenid, plate, vehicle_label, expires_at
            FROM cityrentals_rentals
            WHERE status = 'active' AND expires_at IS NOT NULL
              AND expires_at <= NOW()
        ]]) or {}

        for _, row in ipairs(expiring) do
            local src = Bridge.GetSourceByCitizenId(row.citizenid)
            if src then
                SendPhoneNotification(src, T('notify_app_title'), T('notify_rental_ended', row.vehicle_label, row.plate))
            end
            MySQL.update.await("UPDATE cityrentals_rentals SET status = 'expired' WHERE id = ?", { row.id })
            ActiveRentals[row.citizenid] = nil
        end

        local warnMin = Config.ExpiryWarningMinutes or 10
        local warning = MySQL.query.await([[
            SELECT id, citizenid, vehicle_label, expires_at
            FROM cityrentals_rentals
            WHERE status = 'active'
              AND expires_at BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL ? MINUTE)
              AND expires_at > DATE_ADD(NOW(), INTERVAL ? MINUTE)
        ]], { warnMin + 1, warnMin - 1 }) or {}

        for _, row in ipairs(warning) do
            local src = Bridge.GetSourceByCitizenId(row.citizenid)
            if src then
                SendPhoneNotification(src, T('notify_app_title'), T('notify_expiring', row.vehicle_label, warnMin))
            end
        end
    end
end)

lib.callback.register('cityrentals:getCatalog', function(source)
    local list = {}
    for key, veh in pairs(Config.Vehicles) do
        list[#list + 1] = {
            key = key,
            model = veh.model,
            label = veh.label,
            category = veh.category,
            image = veh.image,
            prices = veh.prices,
        }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return {
        vehicles = list,
        categories = Config.Categories,
        durationUnits = Config.DurationUnits,
        paymentMethods = Config.PaymentMethods,
        pickupReturn = Config.PickupReturn,
        maxActive = Config.MaxActiveRentals,
    }
end)

lib.callback.register('cityrentals:getActiveRental', function(source)
    local citizenid = GetCitizenId(source)
    if not citizenid then return nil end

    local row = MySQL.single.await([[
        SELECT * FROM cityrentals_rentals
        WHERE citizenid = ? AND status IN ('pending_delivery', 'delivering', 'active')
        ORDER BY id DESC LIMIT 1
    ]], { citizenid })

    return FormatRental(row)
end)

lib.callback.register('cityrentals:getHistory', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return {} end

    local limit = math.min(50, math.max(1, tonumber(data and data.limit) or 20))
    local rows = MySQL.query.await([[
        SELECT * FROM cityrentals_rentals
        WHERE citizenid = ?
        ORDER BY id DESC
        LIMIT ?
    ]], { citizenid, limit }) or {}

    local history = {}
    for _, row in ipairs(rows) do
        history[#history + 1] = FormatRental(row)
    end
    return history
end)

lib.callback.register('cityrentals:createRental', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return false, T('err_player_not_found') end

    if CountActiveRentals(citizenid) >= (Config.MaxActiveRentals or 1) then
        return false, T('err_active_rental_limit')
    end

    local vehicleKey = data and data.vehicleKey
    local vehicleCfg = GetVehicleConfig(vehicleKey)
    if not vehicleCfg then return false, T('err_invalid_vehicle') end

    local durationType = data.durationType or 'hour'
    local durationValue = tonumber(data.durationValue) or 1
    local paymentMethod = data.paymentMethod == 'cash' and 'cash' or 'bank'
    local coords = data.coords or {}
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then
        return false, T('err_invalid_location')
    end

    local price = CalculatePrice(vehicleCfg, durationType, durationValue)
    if price <= 0 then return false, T('err_invalid_price') end

    if Bridge.GetMoney(source, paymentMethod) < price then
        return false, T('err_insufficient_funds')
    end

    if not Bridge.RemoveMoney(source, paymentMethod, price, 'cityrentals-rent') then
        return false, T('err_payment_failed')
    end

    local plate = GeneratePlate()
    local minutes = DurationToMinutes(durationType, durationValue)

    local rentalId = MySQL.insert.await([[
        INSERT INTO cityrentals_rentals
        (citizenid, vehicle_key, vehicle_model, vehicle_label, category, plate,
         duration_type, duration_value, price_paid, payment_method, status,
         delivery_x, delivery_y, delivery_z)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'delivering', ?, ?, ?)
    ]], {
        citizenid,
        vehicleKey,
        vehicleCfg.model,
        vehicleCfg.label,
        vehicleCfg.category,
        plate,
        durationType,
        durationValue,
        price,
        paymentMethod,
        x, y, z,
    })

    ActiveRentals[citizenid] = rentalId

    return true, T('err_delivery_in_progress'), {
        id = rentalId,
        vehicleKey = vehicleKey,
        vehicleModel = vehicleCfg.model,
        vehicleLabel = vehicleCfg.label,
        category = vehicleCfg.category,
        plate = plate,
        durationMinutes = minutes,
        pricePaid = price,
        paymentMethod = paymentMethod,
        delivery = { x = x, y = y, z = z },
    }
end)

lib.callback.register('cityrentals:completeDelivery', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return false, T('err_player_not_found') end

    local rentalId = tonumber(data and data.rentalId)
    if not rentalId then return false, T('err_invalid_rental') end

    local row = MySQL.single.await([[
        SELECT * FROM cityrentals_rentals
        WHERE id = ? AND citizenid = ? AND status IN ('delivering', 'pending_delivery')
    ]], { rentalId, citizenid })

    if not row then return false, T('err_rental_not_found') end

    local minutes = DurationToMinutes(row.duration_type, row.duration_value)

    MySQL.update.await([[
        UPDATE cityrentals_rentals
        SET status = 'active',
            starts_at = NOW(),
            expires_at = DATE_ADD(NOW(), INTERVAL ? MINUTE)
        WHERE id = ?
    ]], { minutes, rentalId })

    SendPhoneNotification(source, T('notify_app_title'), T('notify_delivered'))

    return true, T('err_delivered'), FormatRental(MySQL.single.await('SELECT * FROM cityrentals_rentals WHERE id = ?', { rentalId }))
end)

lib.callback.register('cityrentals:cancelDelivery', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return false, T('err_player_not_found') end

    local rentalId = tonumber(data and data.rentalId)
    local row = MySQL.single.await([[
        SELECT * FROM cityrentals_rentals
        WHERE id = ? AND citizenid = ? AND status IN ('delivering', 'pending_delivery')
    ]], { rentalId, citizenid })

    if not row then return false, T('err_rental_not_found') end

    MySQL.update.await("UPDATE cityrentals_rentals SET status = 'cancelled' WHERE id = ?", { rentalId })
    Bridge.AddMoney(source, row.payment_method, row.price_paid, 'cityrentals-refund')
    ActiveRentals[citizenid] = nil

    return true, T('err_cancelled_refund')
end)

lib.callback.register('cityrentals:returnVehicle', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return false, T('err_player_not_found') end

    local rentalId = tonumber(data and data.rentalId)
    local damagePercent = math.min(1.0, math.max(0.0, tonumber(data and data.damagePercent) or 0))
    local late = data and data.late == true
    local pickup = data and data.pickup == true

    local row = MySQL.single.await([[
        SELECT * FROM cityrentals_rentals
        WHERE id = ? AND citizenid = ? AND status = 'active'
    ]], { rentalId, citizenid })

    if not row then return false, T('err_no_active_return') end

    local damageFee = 0
    local lateFee = 0

    if damagePercent > 0.05 then
        damageFee = math.floor(row.price_paid * (Config.DamageFeePercent or 0.15) * damagePercent)
    end
    if late then
        lateFee = math.floor(row.price_paid * (Config.LateFeePercent or 0.10))
    end

    local pickupFee = 0
    if pickup and Config.PickupReturn.enabled then
        pickupFee = Config.PickupReturn.fee or 0
    end

    local totalFee = damageFee + lateFee + pickupFee
    if totalFee > 0 then
        if Bridge.GetMoney(source, row.payment_method) < totalFee then
            return false, T('err_insufficient_fees')
        end
        Bridge.RemoveMoney(source, row.payment_method, totalFee, 'cityrentals-fees')
    end

    MySQL.update.await([[
        UPDATE cityrentals_rentals
        SET status = 'returned', damage_fee = ?, late_fee = ?
        WHERE id = ?
    ]], { damageFee, lateFee, rentalId })

    ActiveRentals[citizenid] = nil

    return true, T('err_vehicle_returned'), { damageFee = damageFee, lateFee = lateFee }
end)

lib.callback.register('cityrentals:renewRental', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return false, T('err_player_not_found') end

    local rentalId = tonumber(data and data.rentalId)
    local durationType = data.durationType or 'hour'
    local durationValue = tonumber(data.durationValue) or 1
    local paymentMethod = data.paymentMethod == 'cash' and 'cash' or 'bank'

    local row = MySQL.single.await([[
        SELECT * FROM cityrentals_rentals
        WHERE id = ? AND citizenid = ? AND status = 'active'
    ]], { rentalId, citizenid })

    if not row then return false, T('err_no_active_renew') end

    local vehicleCfg = GetVehicleConfig(row.vehicle_key)
    if not vehicleCfg then return false, T('err_vehicle_config') end

    local price = CalculatePrice(vehicleCfg, durationType, durationValue)
    if Bridge.GetMoney(source, paymentMethod) < price then
        return false, T('err_insufficient_funds')
    end
    if not Bridge.RemoveMoney(source, paymentMethod, price, 'cityrentals-renew') then
        return false, T('err_payment_failed')
    end

    local minutes = DurationToMinutes(durationType, durationValue)

    MySQL.update.await([[
        UPDATE cityrentals_rentals
        SET expires_at = DATE_ADD(COALESCE(expires_at, NOW()), INTERVAL ? MINUTE),
            price_paid = price_paid + ?,
            duration_type = ?,
            duration_value = ?
        WHERE id = ?
    ]], { minutes, price, durationType, durationValue, rentalId })

    SendPhoneNotification(source, T('notify_app_title'), T('notify_extended'))

    return true, T('err_renewed'), FormatRental(MySQL.single.await('SELECT * FROM cityrentals_rentals WHERE id = ?', { rentalId }))
end)

lib.callback.register('cityrentals:expireRental', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return false end

    local rentalId = tonumber(data and data.rentalId)
    local row = MySQL.single.await([[
        SELECT * FROM cityrentals_rentals
        WHERE id = ? AND citizenid = ? AND status = 'active'
    ]], { rentalId, citizenid })

    if not row then return false end

    MySQL.update.await("UPDATE cityrentals_rentals SET status = 'expired' WHERE id = ?", { rentalId })
    ActiveRentals[citizenid] = nil
    return true
end)
