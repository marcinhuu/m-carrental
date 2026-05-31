if Bridge.VehicleKeys ~= 'wasabi_carlock' then return end

function Bridge.GiveKeys(plate, vehicle)
    if not plate or plate == '' then return end
    exports.wasabi_carlock:GiveKey(plate)
end
