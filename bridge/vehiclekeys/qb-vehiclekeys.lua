if Bridge.VehicleKeys ~= 'qb-vehiclekeys' then return end

function Bridge.GiveKeys(plate, vehicle)
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
end
