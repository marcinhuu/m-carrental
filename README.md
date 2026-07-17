# CityRentals (m-carrental)

Vehicle rentals with NPC delivery — works with **lb-phone** and **sd-phone**.

## Requirements

| Dependency | Required |
|---|---|
| lb-phone **or** sd-phone | One of these |
| oxmysql | Yes |
| ox_lib | Yes |
| QBCore / Qbox / ESX | One of these |

## Installation

```cfg
ensure oxmysql
ensure ox_lib
ensure sd-phone   # or: ensure lb-phone
ensure m-carrental
```

## Config (`shared/config.lua`)

```lua
Config.Phone = 'sd-phone'   -- 'auto' | 'lb-phone' | 'sd-phone'
Config.Framework = 'qbcore' -- 'qbcore' | 'esx'
Config.Locale = 'en'        -- en | pt
Config.DefaultApp = false
```

On start you should see: `[cityrentals] Registered on sd-phone`
