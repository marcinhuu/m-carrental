Bridge = {}
Bridge.VehicleKeys = 'none'

local function InitFramework()
    if GetResourceState('qb-core') == 'started' or GetResourceState('qbx_core') == 'started' then
        Config.Framework = 'qbcore'
        return true
    elseif GetResourceState('es_extended') == 'started' then
        Config.Framework = 'esx'
        return true
    end
    return false
end

local function InitVehicleKeys()
    if GetResourceState('qb-vehiclekeys') == 'started' then
        Bridge.VehicleKeys = 'qb-vehiclekeys'
    elseif GetResourceState('qbx_vehiclekeys') == 'started' then
        Bridge.VehicleKeys = 'qbx_vehiclekeys'
    elseif GetResourceState('cd_garage') == 'started' then
        Bridge.VehicleKeys = 'cd_garage'
    elseif GetResourceState('wasabi_carlock') == 'started' then
        Bridge.VehicleKeys = 'wasabi_carlock'
    else
        Bridge.VehicleKeys = 'native'
    end
end

if not InitFramework() then
    print('^1[cityrentals] No compatible framework found!^0')
else
    print('^2[cityrentals] Framework: ' .. Config.Framework .. '^0')
end

InitVehicleKeys()
print('^2[cityrentals] Vehicle keys: ' .. Bridge.VehicleKeys .. '^0')

if IsDuplicityVersion() then
    function Bridge.GetPlayer(source) return nil end
    function Bridge.GetPlayerIdentifier(Player) return nil end
    function Bridge.GetSourceByCitizenId(citizenid) return nil end
    function Bridge.Notify(source, message, ntype) end
    function Bridge.GetMoney(source, account) return 0 end
    function Bridge.RemoveMoney(source, account, amount, reason) return false end
    function Bridge.AddMoney(source, account, amount, reason) return false end
else
    function Bridge.Notify(message, ntype) end
    function Bridge.GiveKeys(plate, vehicle) end
end
