Phone = Phone or {}

local function state(name)
    return GetResourceState(name)
end

local function sdPhonePresent()
    local s = state('sd-phone')
    return s ~= 'missing' and s ~= 'unknown'
end

---Returns the phone resource name to use, or nil if none is ready yet.
---@return string|nil
function Phone.GetResource()
    local preferred = Config.Phone or 'auto'

    if preferred == 'sd-phone' then
        return state('sd-phone') == 'started' and 'sd-phone' or nil
    end

    if preferred == 'lb-phone' then
        if state('sd-phone') == 'started' then
            return 'sd-phone'
        end
        if sdPhonePresent() then
            return nil
        end
        return state('lb-phone') == 'started' and 'lb-phone' or nil
    end

    if state('sd-phone') == 'started' then
        return 'sd-phone'
    end
    if sdPhonePresent() then
        return nil
    end
    if state('lb-phone') == 'started' then
        return 'lb-phone'
    end
    return nil
end

---@return string
function Phone.WaitForStart()
    while true do
        local phone = Phone.GetResource()
        if phone then return phone end
        Wait(500)
    end
end

---@return boolean
function Phone.IsSd()
    return Phone.GetResource() == 'sd-phone'
end

---Client: local phone banner for this app.
---@param title string
---@param content string
function Phone.Notify(title, content)
    local phone = Phone.GetResource()
    if phone == 'sd-phone' then
        exports['sd-phone']:showNotification({
            app   = Config.AppIdentifier,
            appId = Config.AppIdentifier,
            title = title,
            body  = content,
        })
        return
    end
    if phone == 'lb-phone' then
        exports['lb-phone']:SendNotification({
            app = Config.AppIdentifier,
            title = title,
            content = content,
        })
    end
end

---Server: phone banner to a player for this app.
---@param source number
---@param title string
---@param content string
function Phone.NotifyPlayer(source, title, content)
    local phone = Phone.GetResource()
    if phone == 'sd-phone' then
        exports['sd-phone']:notify(source, {
            app   = Config.AppIdentifier,
            appId = Config.AppIdentifier,
            title = title,
            body  = content,
        })
        return
    end
    if phone == 'lb-phone' then
        exports['lb-phone']:SendNotification(source, {
            app = Config.AppIdentifier,
            title = title,
            content = content,
        })
    end
end
