if Config.Framework ~= 'qbcore' then return end

local QBCore = exports['qb-core']:GetCoreObject()

if IsDuplicityVersion() then
    function Bridge.GetPlayer(source)
        return QBCore.Functions.GetPlayer(source)
    end

    function Bridge.GetPlayerIdentifier(Player)
        return Player.PlayerData.citizenid
    end

    function Bridge.GetSourceByCitizenId(citizenid)
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            local Player = QBCore.Functions.GetPlayer(src)
            if Player and Player.PlayerData.citizenid == citizenid then
                return src
            end
        end
        return nil
    end

    function Bridge.Notify(source, message, ntype)
        TriggerClientEvent('QBCore:Notify', source, message, ntype or 'primary')
    end

    function Bridge.GetMoney(source, account)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return 0 end
        return Player.Functions.GetMoney(account) or 0
    end

    function Bridge.RemoveMoney(source, account, amount, reason)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player or amount <= 0 then return false end
        return Player.Functions.RemoveMoney(account, amount, reason or 'cityrentals')
    end

    function Bridge.AddMoney(source, account, amount, reason)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player or amount <= 0 then return false end
        return Player.Functions.AddMoney(account, amount, reason or 'cityrentals')
    end
else
    function Bridge.Notify(message, ntype)
        QBCore.Functions.Notify(message, ntype or 'primary')
    end
end
