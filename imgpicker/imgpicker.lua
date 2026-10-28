function log(m) SKIN:Bang('!Log', 'PICK ' .. tostring(m), 'Notice') end

local function resDir()
    return SKIN:GetVariable('CURRENTPATH') .. '..\\@Resources\\'
end

local function readFile(p)
    local f = io.open(p, 'rb')
    if not f then return nil end
    local d = f:read('*a'); f:close(); return d
end

local function writeFile(p, s)
    local f = io.open(p, 'wb')
    if not f then return false end
    f:write(s); f:close(); return true
end

local NAMES = {}
local TARGET, CUR, CURTHEME, LOCKED = 0, nil, 1, nil

local SWATCH = { '120,165,255', '86,212,196', '186,150,255', '255,140,176' }
local function loadSwatches(d)
    for k = 1, 4 do
        local v = d and d:match('#sw' .. k .. '%s+([%d,%s]+)')
        if v then SWATCH[k] = (v:gsub('%s', '')) end
    end
end

function loadList()
    NAMES = {}
    local d = readFile(resDir() .. 'img\\list.txt') or ''
    for line in d:gmatch('[^\r\n]+') do
        local n = line:match('^%s*(.-)%s*$')
        if n ~= '' then NAMES[#NAMES + 1] = n end
    end
    if #NAMES == 0 then
        NAMES = { 'happy', 'note', 'cat', 'rice', 'snack', 'dance',
                  'dove', 'flute', 'gift', 'leaves', 'pumpkin', 'snowman' }
    end
end

local function boxShape(k, active)
    local fill = active and '255,255,255,40' or '255,255,255,12'
    local stroke = active and '210,196,255,255' or '150,140,220,60'
    return 'Rectangle 0,0,64,64,8 | Fill Color ' .. fill ..
        ' | StrokeWidth ' .. (active and 2 or 1) .. ' | Stroke Color ' .. stroke
end

function renderSwatch()
    for k = 1, 4 do
        local on = (k == CURTHEME)
        SKIN:Bang('!SetOption', 'Sw' .. k, 'Shape',
            'Ellipse 9,9,8,8 | Fill Color ' .. SWATCH[k] .. ',255 | StrokeWidth '
            .. (on and 3 or 1) .. ' | Stroke Color 255,255,255,' .. (on and 230 or 40))
        SKIN:Bang('!UpdateMeter', 'Sw' .. k)
    end
end

function render()
    for k = 0, 11 do
        local name = NAMES[k + 1]
        if name then
            SKIN:Bang('!SetOption', 'PickImg' .. k, 'ImageName',
                resDir() .. 'img\\' .. name .. '.png')
            SKIN:Bang('!SetOption', 'PickBox' .. k, 'Shape', boxShape(k, name == CUR))
            SKIN:Bang('!ShowMeter', 'PickBox' .. k)
            SKIN:Bang('!ShowMeter', 'PickImg' .. k)
        else
            SKIN:Bang('!HideMeter', 'PickBox' .. k)
            SKIN:Bang('!HideMeter', 'PickImg' .. k)
        end
        SKIN:Bang('!UpdateMeter', 'PickBox' .. k)
        SKIN:Bang('!UpdateMeter', 'PickImg' .. k)
    end
    SKIN:Bang('!SetOption', 'PickHint', 'Text', '共 ' .. #NAMES .. ' 张')
    SKIN:Bang('!UpdateMeter', 'PickHint')
    renderSwatch()
    SKIN:Bang('!Redraw')
end

function boot()
    local d = readFile(resDir() .. 'ui_state.txt') or ''
    local i = d:match('#imgpick%s+(%d+)') or '?'
    TARGET = tonumber(i) or 0
    local name = d:match('#name%s+([^\r\n]+)') or ''
    local cur = d:match('#img%s+([^\r\n]+)')
    CUR = (cur and cur ~= '-' and cur) or nil
    local lk = d:match('#locked%s+(%d+)')
    LOCKED = (lk == '1')
    if LOCKED then SKIN:Bang('!ShowMeter', 'LockBtn') else SKIN:Bang('!HideMeter', 'LockBtn') end
    local th = d:match('#theme%s+(%d+)')
    CURTHEME = tonumber(th) or 1

    local px, py = d:match('#pos%s+(%d+)%s+(%d+)')
    if px and py then SKIN:Bang('!Move', tonumber(px), tonumber(py)) end
    SKIN:Bang('!ZPos', '1')

    loadList()
    loadSwatches(d)
    SKIN:Bang('!SetOption', 'PickTitle', 'Text', '给「' .. (name ~= '' and name or '便签 ' .. i) .. '」设置')
    SKIN:Bang('!UpdateMeter', 'PickTitle')
    render()
    log('open note=' .. i .. ' cur=' .. tostring(CUR) .. ' theme=' .. CURTHEME .. ' pool=' .. #NAMES)
end

function hoverIn(k)
    if NAMES[k + 1] == CUR then return end
    SKIN:Bang('!SetOption', 'PickBox' .. k, 'Shape', boxShape(k, false))
    SKIN:Bang('!UpdateMeter', 'PickBox' .. k)
    SKIN:Bang('!Redraw')
end

function hoverOut(k)
    hoverIn(k)
end

function pickIdx(k)
    local name = NAMES[k + 1]
    if not name or TARGET < 1 then return end
    writeFile(resDir() .. 'imgpick_result.txt', TARGET .. '\timg:' .. name .. '\r\n')
    CUR = name
    render()
    log('result ' .. TARGET .. ' -> img:' .. name)
end

function pick(name)
    if TARGET < 1 then return end
    writeFile(resDir() .. 'imgpick_result.txt', TARGET .. '\t' .. name .. '\r\n')
    CUR = (name ~= '-' and name) or nil
    render()
    log('result ' .. TARGET .. ' -> ' .. name)
end

function pickTheme(k)
    if TARGET < 1 then return end
    writeFile(resDir() .. 'imgpick_result.txt', TARGET .. '\ttheme:' .. k .. '\r\n')
    CURTHEME = k
    renderSwatch()
    SKIN:Bang('!Redraw')
    log('result ' .. TARGET .. ' -> theme:' .. k)
end

function unlock()
    if TARGET < 1 then return end
    writeFile(resDir() .. 'imgpick_result.txt', TARGET .. '\tlock:0\r\n')
    LOCKED = false
    SKIN:Bang('!HideMeter', 'LockBtn')
    SKIN:Bang('!Redraw')
    log('unlock ' .. TARGET)
end

function rescan()
    SKIN:Bang('["powershell.exe" "-NoProfile" "-ExecutionPolicy" "Bypass" "-WindowStyle" "Hidden" "-File" "#@#img.ps1"]')
    log('rescan started')
end

function close()
    SKIN:Bang('!DeactivateConfig')
end
