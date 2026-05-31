if Bridge.VehicleKeys ~= 'qbx_vehiclekeys' then return end

function Bridge.GiveKeys(plate, vehicle)
    if vehicle and DoesEntityExist(vehicle) then
        lib.callback.await('qbx_vehiclekeys:server:giveKeys', false, VehToNet(vehicle))
    end
end
