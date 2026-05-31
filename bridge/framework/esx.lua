if Config.Framework ~= 'esx' then return end

local ESX = exports['es_extended']:getSharedObject()

if IsDuplicityVersion() then
    function Bridge.GetPlayer(source)
        return ESX.GetPlayerFromId(source)
    end

    function Bridge.GetPlayerIdentifier(Player)
        return Player.identifier
    end

    function Bridge.GetSourceByCitizenId(citizenid)
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer and xPlayer.identifier == citizenid then
                return src
            end
        end
        return nil
    end

    function Bridge.Notify(source, message, ntype)
        TriggerClientEvent('esx:showNotification', source, message)
    end

    function Bridge.GetMoney(source, account)
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return 0 end
        if account == 'cash' then
            return xPlayer.getMoney()
        end
        local acc = xPlayer.getAccount('bank')
        return acc and acc.money or 0
    end

    function Bridge.RemoveMoney(source, account, amount, reason)
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer or amount <= 0 then return false end
        if account == 'cash' then
            if xPlayer.getMoney() < amount then return false end
            xPlayer.removeMoney(amount, reason or 'cityrentals')
            return true
        end
        if xPlayer.getAccount('bank').money < amount then return false end
        xPlayer.removeAccountMoney('bank', amount, reason or 'cityrentals')
        return true
    end

    function Bridge.AddMoney(source, account, amount, reason)
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer or amount <= 0 then return false end
        if account == 'cash' then
            xPlayer.addMoney(amount, reason or 'cityrentals')
            return true
        end
        xPlayer.addAccountMoney('bank', amount, reason or 'cityrentals')
        return true
    end
else
    function Bridge.Notify(message, ntype)
        ESX.ShowNotification(message)
    end
end
