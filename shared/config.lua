Config = {}

Config.Framework = 'esx'

Config.Locale = 'en'

Config.AppIdentifier = 'lb-phone-cityrentals'
Config.AppName = 'CityRentals'
Config.AppDescription = 'Rent vehicles delivered to your location'
Config.AppDeveloper = 'CityRentals'
Config.AppSize = 3.8

-- Max concurrent active rentals per player
Config.MaxActiveRentals = 1

-- Billing units shown in the app
Config.DurationUnits = {
    { id = 'minute', label = 'Minutes', multiplier = 1 },
    { id = 'hour',   label = 'Hours',   multiplier = 60 },
    { id = 'day',    label = 'Days',    multiplier = 1440 },
}

Config.Categories = {
    { id = 'all',      label = 'All',      icon = 'grid' },
    { id = 'economy',  label = 'Economy',  icon = 'car' },
    { id = 'sport',    label = 'Sport',    icon = 'gauge' },
    { id = 'luxury',   label = 'Luxury',   icon = 'gem' },
    { id = 'offroad',  label = 'Offroad',  icon = 'mountain' },
    { id = 'super',    label = 'Super',    icon = 'bolt' },
}

Config.PaymentMethods = { 'bank', 'cash' }

-- Fees (0.0 - 1.0 = percent of rental price)
Config.DamageFeePercent = 0.15
Config.LateFeePercent = 0.10
Config.LateGraceMinutes = 5

Config.ExpiryWarningMinutes = 10
Config.RenewalReminderMinutes = 5

-- NPC delivery
Config.Delivery = {
    pedModel = 's_m_m_postal_02',
    blipSprite = 326,
    blipColor = 3,
    blipScale = 0.85,
    spawnDistanceMin = 80.0,
    spawnDistanceMax = 140.0,
    arriveDistance = 12.0,
    driveSpeed = 22.0,
    maxDriveSeconds = 180,
    stuckCheckSeconds = 25,
    stuckMoveThreshold = 4.0,
    fallbackTeleport = true,
    keyAnimDict = 'mp_common',
    keyAnimName = 'givetake1_a',
    keyAnimMs = 2500,
    despawnPedAfterMs = 8000,
}

-- Optional NPC pickup on return (extra fee)
Config.PickupReturn = {
    enabled = true,
    fee = 50,
    pedModel = 's_m_m_postal_01',
    arriveDistance = 10.0,
}

-- Abandoned rental vehicle (player far away)
Config.Abandoned = {
    enabled = true,
    distanceMeters = 120.0,
    minutes = 12,
}

Config.Vehicles = {
    blista = {
        model = 'blista',
        label = 'Dinka Blista',
        category = 'economy',
        image = 'https://docs.fivem.net/vehicles/blista.webp',
        prices = { minute = 6, hour = 150, day = 900 },
    },
    asea = {
        model = 'asea',
        label = 'Declasse Asea',
        category = 'economy',
        image = 'https://docs.fivem.net/vehicles/asea.webp',
        prices = { minute = 5, hour = 120, day = 750 },
    },
    fugitive = {
        model = 'fugitive',
        label = 'Cheval Fugitive',
        category = 'sport',
        image = 'https://docs.fivem.net/vehicles/fugitive.webp',
        prices = { minute = 12, hour = 320, day = 1800 },
    },
    elegy2 = {
        model = 'elegy2',
        label = 'Annis Elegy RH8',
        category = 'sport',
        image = 'https://docs.fivem.net/vehicles/elegy2.webp',
        prices = { minute = 18, hour = 480, day = 2600 },
    },
    schafter2 = {
        model = 'schafter2',
        label = 'Benefactor Schafter',
        category = 'luxury',
        image = 'https://docs.fivem.net/vehicles/schafter2.webp',
        prices = { minute = 22, hour = 580, day = 3200 },
    },
    cognoscenti = {
        model = 'cognoscenti',
        label = 'Enus Cognoscenti',
        category = 'luxury',
        image = 'https://docs.fivem.net/vehicles/cognoscenti.webp',
        prices = { minute = 28, hour = 720, day = 4000 },
    },
    rebel2 = {
        model = 'rebel2',
        label = 'Karin Rebel',
        category = 'offroad',
        image = 'https://docs.fivem.net/vehicles/rebel2.webp',
        prices = { minute = 14, hour = 360, day = 2000 },
    },
    kamacho = {
        model = 'kamacho',
        label = 'Kamacho',
        category = 'offroad',
        image = 'https://docs.fivem.net/vehicles/kamacho.webp',
        prices = { minute = 20, hour = 520, day = 2900 },
    },
    adder = {
        model = 'adder',
        label = 'Truffade Adder',
        category = 'super',
        image = 'https://docs.fivem.net/vehicles/adder.webp',
        prices = { minute = 45, hour = 1200, day = 6500 },
    },
    t20 = {
        model = 't20',
        label = 'Progen T20',
        category = 'super',
        image = 'https://docs.fivem.net/vehicles/t20.webp',
        prices = { minute = 50, hour = 1400, day = 7500 },
    },
}
