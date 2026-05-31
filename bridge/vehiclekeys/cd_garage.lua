if Bridge.VehicleKeys ~= 'cd_garage' then return end

local function ResolvePlate(plate, vehicle)
    if vehicle and DoesEntityExist(vehicle) then
        local ok, resolved = pcall(function()
            return exports['cd_garage']:GetPlate(vehicle)
        end)
        if ok and resolved and resolved ~= '' then
            return resolved
        end
    end
    return plate
end

function Bridge.GiveKeys(plate, vehicle)
    TriggerEvent('cd_garage:AddKeys', ResolvePlate(plate, vehicle))
end
