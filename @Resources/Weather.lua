-- Weather.lua ¡ª¡ª ÌìÆø + ³ÇÊÐÇÐ»»£¨µØÀí±àÂë£©
local ICONS = {
    [0] = 'Çç', [1] = 'ÉÙÔÆ', [2] = '¶àÔÆ', [3] = 'Òõ',
    [45] = 'Îí', [48] = 'ÎíÚ¡', [51] = 'Ã«Ã«Óê', [53] = 'Ã«Ã«Óê', [55] = 'Ã«Ã«Óê',
    [56] = '¶³Ã«Ã«Óê', [57] = '¶³Ã«Ã«Óê', [61] = 'Ð¡Óê', [63] = 'ÖÐÓê', [65] = '´óÓê',
    [66] = '¶³Óê', [67] = '¶³Óê', [71] = 'Ð¡Ñ©', [73] = 'ÖÐÑ©', [75] = '´óÑ©', [77] = 'Ã×Ñ©',
    [80] = 'ÕóÓê', [81] = 'ÕóÓê', [82] = 'Ç¿ÕóÓê', [85] = 'ÕóÑ©', [86] = 'Ç¿ÕóÑ©',
    [95] = 'À×±©', [96] = 'À×±©±ù±¢', [99] = 'À×±©±ù±¢'
}
local CITY_FILE, CITY_ALT
local function resolveCity()
    local base = tostring(SKIN and SKIN:GetVariable('CURRENTPATH') or '')
    local d = base .. '@Resources\\'
    CITY_FILE = d .. 'city.txt'
    CITY_ALT = d .. 'city_alt.txt'
end
pcall(resolveCity)
local savedText = nil

local function split(s)
    local t = {}
    for v in tostring(s or ''):gmatch('([^,]+)') do t[#t + 1] = tonumber(v) end
    return t
end

local function charLen(s)
    local i, n = 1, 0
    while i <= #s do
        local b = string.byte(s, i)
        if b and b >= 128 then i = i + 2 else i = i + 1 end
        n = n + 1
    end
    return n
end

local function cutChars(s, limit)
    local i, n = 1, 0
    while i <= #s do
        local b = string.byte(s, i)
        local step = (b and b >= 128) and 2 or 1
        n = n + 1
        if n >= limit then return s:sub(1, i + step - 1) end
        i = i + step
    end
    return s
end

local function weatherURL(lat, lon)
    return 'https://api.open-meteo.com/v1/forecast?latitude=' .. tostring(lat) ..
        '&longitude=' .. tostring(lon) ..
        '&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,weather_code&forecast_days=7&timezone=Asia%2FShanghai'
end

local function setText(s)
    SKIN:Bang('!SetVariable', 'weatherText', s)
    SKIN:Bang('!UpdateMeter', 'WeatherText')
    SKIN:Bang('!Redraw')
end

local function city() return SKIN:GetVariable('city') or '´óÍ¬' end

local function readCity()
    pcall(resolveCity)
    local f = io.open(CITY_FILE, 'rb')
    if not f then f = io.open(CITY_ALT, 'rb') end
    if not f then return nil end
    local d = f:read('*a'); f:close()
    if not d then return nil end
    local n, la, lo = d:match('^([^|\r\n]+)|([%d%.%-]+)|([%d%.%-]+)')
    if not n or not tonumber(la) or not tonumber(lo) then return nil end
    return n, la, lo
end

local function saveCity(n, la, lo)
    pcall(resolveCity)
    local f = io.open(CITY_FILE, 'wb')
    if not f then f = io.open(CITY_ALT, 'wb') end
    if f then f:write(n .. '|' .. la .. '|' .. lo .. '\r\n'); f:close() end
end

local function applyCity(n, la, lo, persist, doFetch)
    n = cutChars(n, 8)
    SKIN:Bang('!SetVariable', 'latitude', tostring(la))
    SKIN:Bang('!SetVariable', 'longitude', tostring(lo))
    SKIN:Bang('!SetVariable', 'city', n)
    SKIN:Bang('!SetVariable', 'queryCity', n)
    SKIN:Bang('!SetOption', 'MeasureWeather', 'URL', weatherURL(la, lo))
    if doFetch then
        SKIN:Bang('!EnableMeasure', 'MeasureWeather')
        SKIN:Bang('!CommandMeasure', 'MeasureWeather', 'Update')
    end
    setText(n .. ' --¡ã')
    if persist then saveCity(n, la, lo) end
end

function Initialize()
    local n, la, lo = readCity()
    if n then
        applyCity(n, la, lo, false, false)
    else
        local la0 = SKIN:GetVariable('latitude') or '40.0902'
        local lo0 = SKIN:GetVariable('longitude') or '113.3001'
        SKIN:Bang('!SetOption', 'MeasureWeather', 'URL', weatherURL(la0, lo0))
        setText(city() .. ' --¡ã')
    end
end

-- ³ÇÊÐ²éÑ¯
function lookup(name)
    pcall(resolveCity)
    name = tostring(name or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then return end
    savedText = SKIN:GetVariable('weatherText')
    SKIN:Bang('!SetVariable', 'queryCity', name)
    setText('²éÑ¯ÖÐ¡­')
    for _, m in ipairs({ 'GeoName', 'GeoLat', 'GeoLon' }) do
        SKIN:Bang('!EnableMeasure', m)
        SKIN:Bang('!CommandMeasure', m, 'Update')
    end
    SKIN:Bang('!CommandMeasure', 'CityTimer', 'Execute 1')
end

function geoApply()
    pcall(resolveCity)
    local n = SKIN:GetMeasure('GeoName'):GetStringValue()
    local la = tonumber(SKIN:GetMeasure('GeoLat'):GetStringValue())
    local lo = tonumber(SKIN:GetMeasure('GeoLon'):GetStringValue())
    if n and n ~= '' and la and lo then
        applyCity(n, la, lo, true, true)
        SKIN:Bang('!Log', 'ÇÐ»»³ÇÊÐ£º' .. n .. ' ' .. la .. ',' .. lo, 'Notice')
    else
        failCity()
    end
end

function failCity()
    setText('Î´ÕÒµ½¸Ã³ÇÊÐ')
    SKIN:Bang('!CommandMeasure', 'RestoreTimer', 'Execute 1')
end

function restoreCity()
    pcall(resolveCity)
    setText(savedText and savedText ~= '' and savedText or (city() .. ' --¡ã'))
end

-- ÌìÆøÊý¾Ý
function update()
    pcall(resolveCity)
    local t = SKIN:GetMeasure('MeasureTemp'):GetStringValue()
    local n = tonumber(t)
    if n then
        local c = tonumber(SKIN:GetMeasure('MeasureCode'):GetStringValue()) or -1
        local desc = ICONS[c] or '¶àÔÆ'
        SKIN:Bang('!SetVariable', 'weatherText', city() .. ' ' .. math.floor(n + 0.5) .. '¡ã ' .. desc)
        SKIN:Bang('!UpdateMeter', 'WeatherText')
    end
    local mx = split(SKIN:GetMeasure('MeasureMax'):GetStringValue())
    local mn = split(SKIN:GetMeasure('MeasureMin'):GetStringValue())
    local wc = split(SKIN:GetMeasure('MeasureWCode'):GetStringValue())
    for i = 0, 6 do
        if mx[i + 1] and mn[i + 1] and wc[i + 1] then
            local d = ICONS[wc[i + 1]] or '¶àÔÆ'
            SKIN:Bang('!SetVariable', 'wx' .. i, string.format('%s %d~%d¡ã', d, math.floor(mn[i + 1] + 0.5), math.floor(mx[i + 1] + 0.5)))
        else
            SKIN:Bang('!SetVariable', 'wx' .. i, '¡ª')
        end
    end
    SKIN:Bang('!SetVariable', 'retryCount', '0')
    SKIN:Bang('!CommandMeasure', 'RetryTimer', 'Stop 1')
    SKIN:Bang('!CommandMeasure', 'NoteLua', 'relayoutWeather()')
end

function fail()
    SKIN:Bang('!SetVariable', 'weatherText', city() .. ' --¡ã')
    for i = 0, 6 do SKIN:Bang('!SetVariable', 'wx' .. i, '--') end
    local r = tonumber(SKIN:GetVariable('retryCount')) or 0
    if r < 5 then
        SKIN:Bang('!SetVariable', 'retryCount', tostring(r + 1))
        SKIN:Bang('!CommandMeasure', 'RetryTimer', 'Execute 1')
    end
    SKIN:Bang('!CommandMeasure', 'NoteLua', 'relayoutWeather()')
end

function retry()
    local r = tonumber(SKIN:GetVariable('retryCount')) or 0
    if r <= 5 then
        SKIN:Bang('!CommandMeasure', 'MeasureWeather', 'Update')
    else
        SKIN:Bang('!CommandMeasure', 'RetryTimer', 'Stop 1')
    end
end