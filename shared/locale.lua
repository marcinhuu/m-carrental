Locale = Locale or {}

function T(key, ...)
    local locale = Locale[Config.Locale] or Locale['en'] or {}
    local str = locale[key] or Locale['en'] and Locale['en'][key] or key
    if select('#', ...) > 0 then
        return string.format(str, ...)
    end
    return str
end
