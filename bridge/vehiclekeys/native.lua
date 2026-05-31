if Bridge.VehicleKeys ~= 'native' then return end

function Bridge.GiveKeys(plate, vehicle)
    if vehicle and DoesEntityExist(vehicle) then
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleNeedsToBeHotwired(vehicle, false)
    end
end
