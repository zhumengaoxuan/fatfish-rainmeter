local CITY, AUTO
local function resolvePaths()
    local base = tostring(SKIN and SKIN:GetVariable('CURRENTPATH') or '')
    local d = base .. '..\\@Resources\\'
    CITY = d .. 'city.txt'
    AUTO = d .. 'autonote.txt'
end
pcall(resolvePaths)
local PAL = { text='235,238,245', textDim='220,215,240', accent='176,158,255', accentBlue='120,220,255', buttonBg='72,87,150', white='255,255,255' }
local function loadPal()
    PAL.text = SKIN:GetVariable('TextMain') or PAL.text
    PAL.textDim = SKIN:GetVariable('TextDim') or PAL.textDim
    PAL.accent = SKIN:GetVariable('Accent') or PAL.accent
    PAL.accentBlue = SKIN:GetVariable('AccentBlue') or PAL.accentBlue
    PAL.buttonBg = SKIN:GetVariable('ButtonBg') or PAL.buttonBg
    PAL.white = SKIN:GetVariable('LineWhite') or PAL.white
end
local PRESETS = { { '北京', 39.9042, 116.4074 }, { '大同', 40.0902, 113.3001 }, { '太原', 37.8706, 112.5489 }, { '上海', 31.2304, 121.4737 }, { '广州', 23.1291, 113.2644 }, { '成都', 30.5728, 104.0668 } }
local mode = 'cycle'
local MODE_KEYS = { 'cycle', 'interval', 'date', 'monthly' }
local modeOn = { cycle = true, interval = false, date = false, monthly = false }
local panelMode = 'cycle'

local function rd(p) if not p then pcall(resolvePaths); p = CITY end; if not p then return nil end; local f = io.open(p, 'rb'); if not f then return nil end; local d = f:read('*a'); f:close(); return d end
local function wr(p, data) if not p then pcall(resolvePaths); end; if not p then return end; local f = io.open(p, 'wb'); if f then f:write(data); f:close() end end
local function lines(s) local t = {}; for v in tostring(s or ''):gmatch('[^\r\n]+') do t[#t + 1] = v end; return t end
local function status(s) SKIN:Bang('!SetOption', 'Status', 'Text', s); SKIN:Bang('!UpdateMeter', 'Status'); SKIN:Bang('!Redraw') end
local function setText(n, v)
    SKIN:Bang('!TextEdit:SetText', n, tostring(v))
    SKIN:Bang('!UpdateMeter', n)
    SKIN:Bang('!Redraw')
end

local function showRows(n)
    n = tonumber(n) or 2
    if n < 1 then n = 1 end
    if n > 7 then n = 7 end
    for i = 1, 7 do
        local visible = (i <= n)
        local rowY = 300 + (i - 1) * 32
        local y = visible and rowY or -200
        for _, pre in ipairs({ 'DayLabel', 'NBg', 'NBox', 'TBg', 'TBox' }) do
            SKIN:Bang('!SetOption', pre .. i, 'Hidden', visible and '0' or '1')
            -- DayLabel 用 RightCenter，Y 是垂直中心，需要 +12 才能与输入框对齐
            local yy = (pre == 'DayLabel') and (y + 6) or y
            SKIN:Bang('!SetOption', pre .. i, 'Y', tostring(yy))
        end
    end
    setHeight(n, false)
    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Redraw')
end

local function showTable(on)
    local hide = on and 1 or 0
    for i = 1, 7 do
        SKIN:Bang('!SetOption', 'DayLabel' .. i, 'Hidden', tostring(1 - hide))
        SKIN:Bang('!SetOption', 'NBox' .. i, 'Hidden', tostring(1 - hide))
        SKIN:Bang('!SetOption', 'TBox' .. i, 'Hidden', tostring(1 - hide))
    end
    SKIN:Bang('!SetOption', 'RuleHead', 'Hidden', tostring(1 - hide))
    if not on then
        for i = 1, 7 do
            for _, pre in ipairs({ 'DayLabel', 'NBg', 'NBox', 'TBg', 'TBox' }) do
                SKIN:Bang('!SetOption', pre .. i, 'Hidden', '1')
            end
        end
        for _, h in ipairs({ 'HeadDay', 'HeadName', 'HeadText' }) do SKIN:Bang('!SetOption', h, 'Hidden', '1') end
        setHeight(0, true)
    else
        for _, h in ipairs({ 'HeadDay', 'HeadName', 'HeadText' }) do SKIN:Bang('!SetOption', h, 'Hidden', '0') end
    end
    local inv = on and 0 or 1
    for _, n in ipairs({ 'CycleLabel', 'CycleInput', 'Cycle3', 'Cycle5', 'Cycle7' }) do
        SKIN:Bang('!SetOption', n, 'Hidden', tostring(1 - hide))
    end
    for _, n in ipairs({ 'IntervalLabel', 'IntervalInput', 'IntervalBg', 'TNameLabel', 'TNameInput', 'TNameBg', 'TTextLabel', 'TTextInput', 'TTextBg' }) do
        SKIN:Bang('!SetOption', n, 'Hidden', tostring(1 - inv))
    end
    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Redraw')
end

function boot()
    loadPal()
    pcall(resolvePaths)
    local c = lines(rd(CITY) or '')
    local name = '大同'
    if c[1] then name = c[1]:match('^([^|]+)') or name end
    SKIN:Bang('!SetVariable', 'cityInput', name)
    setText('CityInput', name)

    local ls = lines(rd(AUTO) or '')
    local cycle, base, interval, tn, tx = 2, '2026-01-01', 7, '交周报', '整理本周进度并发给组长'
    local rules = {}
    for _, l in ipairs(ls) do
        local m = l:match('^#mode%s+(%w+)')
        local cy = l:match('^#cycle%s+(%d+)')
        local b = l:match('^#base%s+([%d%-]+)')
        local iv = l:match('^#interval%s+(%d+)')
        local n1 = l:match('^#tname%s+(.+)$')
        local t1 = l:match('^#ttext%s+(.+)$')
        local mds = l:match('^#modes%s+([%a,]+)')
        if mds then
            for _, k in ipairs(MODE_KEYS) do modeOn[k] = false end
            for one in mds:gmatch('[^,]+') do if modeOn[one] ~= nil then modeOn[one] = true end end
        end
        if m then mode = m end
        if cy then cycle = tonumber(cy) end
        if b then base = b end
        if iv then interval = tonumber(iv) end
        if n1 then tn = n1 end
        if t1 then tx = t1 end
        local idx, nm, txt = l:match('^(%d+)\t([^\t]*)\t(.*)$')
        if idx then rules[tonumber(idx)] = { nm, txt } end
    end
    if not rules[1] then rules = { { '订货', '确认下单数量' }, { '到货', '核对到货清单' } } end
    SKIN:Bang('!SetVariable', 'baseInput', base)
    setText('BaseInput', base)
    SKIN:Bang('!SetVariable', 'cycleInput', tostring(cycle))
    setText('CycleInput', tostring(cycle))
    SKIN:Bang('!SetVariable', 'intervalInput', tostring(interval))
    setText('IntervalInput', tostring(interval))
    SKIN:Bang('!SetVariable', 'tnameInput', tn)
    setText('TNameInput', tn)
    SKIN:Bang('!SetVariable', 'ttextInput', tx)
    setText('TTextInput', tx)
    for i = 1, 7 do
        local r = rules[i]
        local nm = r and r[1] or ''
        local txt = r and r[2] or ''
        SKIN:Bang('!SetVariable', 'n' .. i, nm)
        SKIN:Bang('!SetVariable', 't' .. i, txt)
        setText('NBox' .. i, nm)
        setText('TBox' .. i, txt)
    end
    setMode(mode)
    SKIN:Bang('!CommandMeasure', 'RefillTimer', 'Execute 2')
    status('已载入：' .. name .. ' / ' .. (mode == 'cycle' and (cycle .. ' 天循环') or (mode == 'monthly' and '月内循环' or (interval .. ' 天间隔'))))
end

local function vis(n, on)
    SKIN:Bang('!SetOption', n, 'Hidden', on and '0' or '1')
end

function refill2()
    SKIN:Bang('!ShowMeter', 'CycleInput')
    setText('CycleInput', SKIN:GetVariable('cycleInput') or '2')
    setText('BaseInput', SKIN:GetVariable('baseInput') or '2026-01-01')
    setText('CityInput', SKIN:GetVariable('cityInput') or '')
end

function refill()
    local name = SKIN:GetVariable('cityInput') or ''
    setText('CityInput', name)
    setText('BaseInput', SKIN:GetVariable('baseInput') or '')
    local cv = tostring(SKIN:GetVariable('cycleInput') or '')
    if cv == '' then cv = '2' end
    setText('CycleInput', cv)
    setText('IntervalInput', SKIN:GetVariable('intervalInput') or '')
    setText('TNameInput', SKIN:GetVariable('tnameInput') or '')
    setText('TTextInput', SKIN:GetVariable('ttextInput') or '')
    for i = 1, 7 do
        setText('NBox' .. i, SKIN:GetVariable('n' .. i) or '')
        setText('TBox' .. i, SKIN:GetVariable('t' .. i) or '')
    end
end
function diagCycle()
    local m = SKIN:GetMeter('CycleInput')
    SKIN:Bang('!Log', 'CYCLE var=[' .. tostring(SKIN:GetVariable('cycleInput')) .. '] hidden=[' .. tostring(m and m:GetOption('Hidden')) .. '] x=[' .. tostring(m and m:GetX()) .. '] w=[' .. tostring(m and m:GetW()) .. ']', 'Notice')
end
function layoutBottom(rowBottom)
    local bt = rowBottom + 16 + 14
    local st = rowBottom + 60
    local h = rowBottom + 86
    SKIN:Bang('!SetVariable', 'panelH', tostring(h))
    SKIN:Bang('!SetOption', 'PanelBg', 'H', tostring(h))
    SKIN:Bang('!SetOption', 'Panel', 'Shape', 'Rectangle 0,0,420,' .. h .. ',14 | Fill LinearGradient 2 | StrokeWidth 1 | Stroke LinearGradient 1')
    local centers = { SaveAll = 0.18, OpenNote = 0.5, Close = 0.82 }
    for m, f in pairs(centers) do
        SKIN:Bang('!SetOption', m, 'X', tostring(math.floor(420 * f)))
        SKIN:Bang('!SetOption', m, 'Y', tostring(bt + 14))
    end
    SKIN:Bang('!SetOption', 'Status', 'Y', tostring(st))
    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Update')
    SKIN:Bang('!Redraw')
end

function setHeight(n, intervalMode)
    local rowBottom
    if intervalMode then
        rowBottom = 320
    else
        local k = math.max(2, math.min(7, tonumber(n) or 2))
        rowBottom = 300 + (k - 1) * 32 + 24
    end
    layoutBottom(rowBottom)
end
function pixelCheck()
    local names = { 'CityInput','SaveCity','P1','P2','P3','P4','P5','P6','BaseInput','BaseHint','CycleInput','Cycle3','Cycle5','Cycle7','NBg1','NBg2','TBg1','TBg2','SaveAll','OpenNote','Close','Status' }
    for _, n in ipairs(names) do
        local m = SKIN:GetMeter(n)
        if m then
            local y = m:GetY(true)
            local ok, h = pcall(function() return m:GetH() end)
            local hh = (ok and tonumber(h)) and tonumber(h) or 0
            SKIN:Bang('!Log', string.format('CHK %s y=%s h=%s mid=%.1f', n, tostring(y), tostring(hh), (tonumber(y) or 0) + hh / 2), 'Notice')
        end
    end
end
local function setBtn(n, on)
    SKIN:Bang('!SetOption', n, 'SolidColor', on and '' .. PAL.accent .. ',255' or '' .. PAL.buttonBg .. ',255')
    SKIN:Bang('!SetOption', n, 'FontColor', on and '36,30,62,255' or '' .. PAL.textDim .. ',255')
end


local function paintButtons()
    local btns = { { 'ModeCycle', 'cycle' }, { 'ModeInterval', 'interval' },
                   { 'ModeDate', 'date' }, { 'ModeMonth', 'monthly' } }
    for _, k in ipairs(btns) do
        local on = modeOn[k[2]]
        local fill = on and '' .. PAL.accent .. ',255' or '' .. PAL.buttonBg .. ',255'
        local stroke = on and '' .. PAL.accent .. ',120' or '' .. PAL.accent .. ',40'
        SKIN:Bang('!SetOption', k[1] .. 'Bg', 'Shape',
            'Rectangle 0,0,76,24,8 | Fill Color ' .. fill .. ' | StrokeWidth 1 | Stroke Color ' .. stroke)
        SKIN:Bang('!SetOption', k[1], 'FontColor', on and '30,26,54,255' or '' .. PAL.accent .. ',235')
    end
end

local function applyPanel()
    local isTable = (panelMode == 'cycle' or panelMode == 'monthly')
    showTable(isTable)

    -- 日期单发不需要起始日期
    local baseOn = (panelMode == 'cycle' or panelMode == 'interval')
    vis('BaseLabel', baseOn); vis('BaseBg', baseOn); vis('BaseInput', baseOn)
    vis('BaseHint', panelMode == 'cycle')
    vis('BaseFixed', panelMode == 'monthly')
    if panelMode == 'monthly' then
        local mm = tonumber(os.date('%m')) or 1
        SKIN:Bang('!SetOption', 'BaseFixed', 'Text', '起始日期固定为 ' .. mm .. '月1日')
    end

    for _, n in ipairs({ 'IntervalLabel', 'IntervalBg', 'IntervalInput' }) do vis(n, panelMode == 'interval') end
    for _, n in ipairs({ 'DDayLabel', 'DDayBg', 'DDayInput' }) do vis(n, panelMode == 'date') end

    local onText = (panelMode == 'interval' or panelMode == 'date')
    for _, n in ipairs({ 'TNameLabel', 'TNameBg', 'TNameInput',
                         'TTextLabel', 'TTextBg', 'TTextInput' }) do vis(n, onText) end

    -- 日期单发：整体上移一行（没有起始日期），正文收窄避开「清空」
    if panelMode == 'date' then
        local rows = { DDay = 200, TName = 232, TText = 264 }
        SKIN:Bang('!SetOption', 'DDayLabel', 'Y', rows.DDay)
        SKIN:Bang('!SetOption', 'DDayBg', 'Y', rows.DDay)
        SKIN:Bang('!SetOption', 'DDayInput', 'Y', rows.DDay)
        SKIN:Bang('!SetOption', 'TNameLabel', 'Y', rows.TName)
        SKIN:Bang('!SetOption', 'TNameBg', 'Y', rows.TName)
        SKIN:Bang('!SetOption', 'TNameInput', 'Y', rows.TName)
        SKIN:Bang('!SetOption', 'TTextLabel', 'Y', rows.TText)
        SKIN:Bang('!SetOption', 'TTextBg', 'Y', rows.TText)
        SKIN:Bang('!SetOption', 'TTextBg', 'Shape', 'Rectangle 0,0,180,24,8 | Fill Color ' .. PAL.buttonBg .. ',255 | StrokeWidth 1 | Stroke Color ' .. PAL.accent .. ',60')
        SKIN:Bang('!SetOption', 'TTextInput', 'Y', rows.TText)
        SKIN:Bang('!SetOption', 'TTextInput', 'W', 180)
    else
        local rows = { Interval = 232, TName = 264, TText = 296 }
        SKIN:Bang('!SetOption', 'IntervalLabel', 'Y', rows.Interval)
        SKIN:Bang('!SetOption', 'IntervalBg', 'Y', rows.Interval)
        SKIN:Bang('!SetOption', 'IntervalInput', 'Y', rows.Interval)
        SKIN:Bang('!SetOption', 'TNameLabel', 'Y', rows.TName)
        SKIN:Bang('!SetOption', 'TNameBg', 'Y', rows.TName)
        SKIN:Bang('!SetOption', 'TNameInput', 'Y', rows.TName)
        SKIN:Bang('!SetOption', 'TTextLabel', 'Y', rows.TText)
        SKIN:Bang('!SetOption', 'TTextBg', 'Y', rows.TText)
        SKIN:Bang('!SetOption', 'TTextBg', 'Shape', 'Rectangle 0,0,286,24,8 | Fill Color ' .. PAL.buttonBg .. ',255 | StrokeWidth 1 | Stroke Color ' .. PAL.accent .. ',60')
        SKIN:Bang('!SetOption', 'TTextInput', 'Y', rows.TText)
        SKIN:Bang('!SetOption', 'TTextInput', 'W', 286)
    end

    for _, n in ipairs({ 'CycleLabel', 'CycleBg', 'CycleInput', 'Cycle3', 'Cycle5', 'Cycle7',
                         'Cycle3Bg', 'Cycle5Bg', 'Cycle7Bg' }) do
        vis(n, isTable)
    end

    if isTable then
        showRows(tonumber(SKIN:GetVariable('cycleInput')) or 2)
    else
        layoutBottom(320)
    end
    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Redraw')
end


local function modeLabel(m)
    return ({ cycle = '周期循环', interval = '间隔单发', ['date'] = '日期单发', monthly = '月内循环' })[m] or m
end

local function enabledList()
    local out = {}
    for _, k in ipairs(MODE_KEYS) do if modeOn[k] then out[#out + 1] = k end end
    return out
end

-- 单击：开关该模式；双击：切换到该模式的配置项
function toggleMode(m)
    modeOn[m] = not modeOn[m]
    panelMode = m
    paintButtons(); applyPanel()
    local names = {}
    for _, k in ipairs(enabledList()) do names[#names + 1] = modeLabel(k) end
    status('已启用：' .. table.concat(names, ' + '))
end

function openMode(m)
    panelMode = m
    paintButtons(); applyPanel()
    status('正在编辑：' .. modeLabel(m) .. '（单击按钮开关该模式）')
end

function setMode(m)
    if m == 'cycle' or m == 'interval' or m == 'date' or m == 'monthly' then
        openMode(m)
    end
end

function saveAll()
    pcall(resolvePaths)
    local base = tostring(SKIN:GetVariable('baseInput') or '')
    base = base:gsub('%s+', '')
    local needBase = modeOn.cycle or modeOn.interval or modeOn.date
    if needBase then
        local y, m, d = base:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
        local ok = false
        if y and m and d then
            local mm, dd = tonumber(m), tonumber(d)
            ok = (mm >= 1 and mm <= 12 and dd >= 1 and dd <= 31)
        end
        if not ok then
            SKIN:Bang('!SetOption', 'Status', 'FontColor', '255,120,120,255')
            status('起始日期格式应为 YYYY-MM-DD')
            return
        end
    end

    local list = enabledList()
    local out = { '#modes ' .. table.concat(list, ','), '#mode ' .. (list[1] or 'none') }

    local cycle = math.max(1, math.min(7, tonumber(SKIN:GetVariable('cycleInput')) or 2))
    out[#out + 1] = '#cycle ' .. cycle
    if base ~= '' then out[#out + 1] = '#base ' .. base end
    for i = 1, 7 do
        local nm = SKIN:GetVariable('n' .. i) or ''
        local tx = SKIN:GetVariable('t' .. i) or ''
        if nm ~= '' then out[#out + 1] = i .. '\t' .. nm .. '\t' .. tx end
    end
    out[#out + 1] = '#interval ' .. math.max(1, tonumber(SKIN:GetVariable('intervalInput')) or 7)
    out[#out + 1] = '#tname ' .. (SKIN:GetVariable('tnameInput') or '')
    out[#out + 1] = '#ttext ' .. (SKIN:GetVariable('ttextInput') or '')
    out[#out + 1] = '#dday ' .. math.max(1, math.min(31, tonumber(SKIN:GetVariable('ddayInput')) or 1))
    out[#out + 1] = '#dname ' .. (SKIN:GetVariable('tnameInput') or '')
    out[#out + 1] = '#dtext ' .. (SKIN:GetVariable('ttextInput') or '')

    wr(AUTO, table.concat(out, '\r\n') .. '\r\n')
    SKIN:Bang('!CommandMeasure', 'NoteLua', 'reloadAuto()', 'FatFishNote')
    SKIN:Bang('!CommandMeasure', 'NoteLua', 'clearAllSkips()', 'FatFishNote')
    SKIN:Bang('!Refresh', 'FatFishNote')
    SKIN:Bang('!SetOption', 'Status', 'FontColor', '200,200,220,200')
    status(#list > 0 and ('已保存：' .. table.concat(list, ' + ')) or '已保存：未启用任何模式')
    SKIN:Bang('!UpdateMeter', 'Status')
    SKIN:Bang('!Redraw')
end

local function setVar(k, v) SKIN:Bang('!SetVariable', k, tostring(v)) end

function clearMode(m)
    m = m or panelMode
    if m == 'cycle' or m == 'monthly' then
        for i = 1, 7 do
            setVar('n' .. i, ''); setVar('t' .. i, '')
            setText('NBox' .. i, ''); setText('TBox' .. i, '')
        end
        setVar('cycleInput', '2'); setText('CycleInput', '2')
        showRows(2)
    elseif m == 'interval' then
        setVar('intervalInput', '7'); setText('IntervalInput', '7')
        setVar('tnameInput', ''); setText('TNameInput', '')
        setVar('ttextInput', ''); setText('TTextInput', '')
    else
        setVar('ddayInput', '1'); setText('DDayInput', '1')
        setVar('tnameInput', ''); setText('TNameInput', '')
        setVar('ttextInput', ''); setText('TTextInput', '')
    end
    status('已清空「' .. modeLabel(m) .. '」的配置（保存后生效）')
    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Redraw')
end

function preset(i)
    local p = PRESETS[i]
    if not p then return end
    pcall(resolvePaths)
    SKIN:Bang('!SetVariable', 'cityInput', p[1])
    setText('CityInput', p[1])
    wr(CITY, p[1] .. '|' .. p[2] .. '|' .. p[3] .. '\r\n')
    SKIN:Bang('!CommandMeasure', 'WeatherLua', "lookup('" .. p[1] .. "')", 'FatFishNote')
    SKIN:Bang('!Refresh', 'FatFishNote')
    status('城市已切换为 ' .. p[1])
end

function saveCity()
    local name = tostring(SKIN:GetVariable('cityInput') or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then status('请输入城市名'); return end
    pcall(resolvePaths)
    -- 预设城市直接写经纬度，避免中文地理编码失败
    local la, lo = '0', '0'
    for _, p in ipairs(PRESETS) do
        if p[1] == name then la, lo = tostring(p[2]), tostring(p[3]) end
    end
    wr(CITY, name .. '|' .. la .. '|' .. lo .. '\r\n')
    SKIN:Bang('!CommandMeasure', 'WeatherLua', "lookup('" .. name .. "')", 'FatFishNote')
    SKIN:Bang('!Refresh', 'FatFishNote')
    if la == '0' then
        status('已保存：' .. name .. '（自定义城市依赖在线地理编码）')
    else
        status('已保存并刷新：' .. name)
    end
end

function setCycle(n)
    n = tonumber(n) or 2
    n = math.max(1, math.min(7, n))
    SKIN:Bang('!SetVariable', 'cycleInput', tostring(n))
    setText('CycleInput', tostring(n))
    showRows(n)
    status('循环天数：' .. tostring(n))
    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Redraw')
end

-- TextEdit 提交/失焦时把内容写回变量
function syncVar(k, v)
    v = tostring(v or '')
    SKIN:Bang('!SetVariable', k, v)
end
