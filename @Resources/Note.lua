-- FatFishNote.lua v3 —— 列=日期 / 翻页 / 主题 / AI 导入 / 日天气
local MAXN = 30
local B_CARD_W, B_GAP_X, B_MARGIN, B_HEADER, B_GAP_Y, B_BOTTOM, B_CARD_H = 240, 24, 28, 104, 8, 16, 124
local MAX_COLS = 6
local PAGE_MAX = 4
-- 数据文件放在皮肤的 @Resources 下，跟随安装位置（不再写死 C:\Windows\Temp）
local MAIN, BAK, AIIN, MAIN_ALT, BAK_ALT, AI_ALT

local function resDir()
    local base = tostring(SKIN and SKIN:GetVariable('CURRENTPATH') or '')
    if base == '' then base = tostring(SKIN:GetVariable('PROGRAMPATH') or '') end
    return base .. '@Resources\\'
end

local function resolvePaths()
    local d = resDir()
    MAIN = d .. 'notes.txt'
    BAK = d .. 'notes.bak'
    AIIN = d .. 'ai_drop.txt'
    MAIN_ALT = d .. 'notes_alt.txt'
    BAK_ALT = d .. 'notes_alt.bak'
    AI_ALT = d .. 'ai_drop_alt.txt'
end

pcall(resolvePaths)

local POOL = { '★', '◆', '●', '▲', '☆', '◇', '○', '△', '■', '□', '◎', '※' }
local WEEK = { '周日', '周一', '周二', '周三', '周四', '周五', '周六' }
local namePtr = 1
local autoskips = {}
local booted = false

local THEMES = {
    { g1 = '180 | 40,36,70,220;0 | 58,48,104,220;0.55 | 44,62,110,220;1',
      g2 = '180 | 58,50,104,245;0 | 86,70,146,245;0.55 | 60,84,146,245;1',
      card = '38,34,68,240', stroke = '176,158,255,45', accent = '176,158,255', head = '235,238,245,204' },
    { g1 = '180 | 18,32,58,220;0 | 28,58,104,220;0.55 | 22,72,118,220;1',
      g2 = '180 | 26,42,74,245;0 | 38,74,130,245;0.55 | 30,96,150,245;1',
      card = '24,40,70,240', stroke = '120,180,255,50', accent = '120,180,255', head = '225,236,250,204' },
    { g1 = '180 | 14,42,46,220;0 | 22,70,70,220;0.55 | 20,82,76,220;1',
      g2 = '180 | 18,52,54,245;0 | 30,92,90,245;0.55 | 24,104,96,245;1',
      card = '20,46,46,240', stroke = '90,220,200,55', accent = '90,220,200', head = '224,246,240,204' },
    { g1 = '180 | 54,34,24,220;0 | 84,50,30,220;0.55 | 74,60,32,220;1',
      g2 = '180 | 66,40,30,245;0 | 110,62,36,245;0.55 | 96,78,40,245;1',
      card = '62,40,26,240', stroke = '255,170,90,55', accent = '255,170,90', head = '250,238,225,204' },
}

local notes = {}
local count = 0
local cols = 2
local gridRows = 1
local scale = 1.0
local page = 0
local theme = 1
local sel = -1
local editIdx = -1
local editMode = 0
local dragIdx = -1
local dragTo = 1
local grabDX, grabDY = 0, 0
local ghostX, ghostY = 0, 0
local pending = false
local downX, downY = 0, 0
local pitch, cardH, rows = 0, 0, 1
local scaling = false
local lastGrid = ''
local dragNew = false
local newGrabDX, newGrabDY = 0, 0
local scaleStart, scaleDownX, scaleDownY = 1, 0, 0
local hintValid = true
local baseDate = ''
local colLists = {}
local toloday = ''

local function num(k) return tonumber(SKIN:GetVariable(k)) or 0 end
local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end
local function rnd(v) return math.floor(v + 0.5) end

local function clean(s)
    s = tostring(s or '')
    s = s:gsub('[\r\n\t]', ' ')
    s = s:gsub('"', '')
    if #s > 300 then s = s:sub(1, 300) end
    return s
end
local function charLen(s) local i, n = 1, 0 while i <= #s do local b = string.byte(s, i) if b and b >= 128 then i = i + 2 else i = i + 1 end n = n + 1 end return n end
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
local function cleanName(s)
    s = tostring(s or '')
    s = s:gsub('[\r\n\t]', ' ')
    s = s:gsub('"', '')
    s = s:gsub('^%s+', ''):gsub('%s+$', '')
    if s == '' then return '' end
    return cutChars(s, 12)
end

local function todayStr() return os.date('%Y-%m-%d') end
local function todayTime()
    local t = os.date('*t')
    return os.time({ year = t.year, month = t.month, day = t.day, hour = 12 })
end
local function dateAdd(str, n)
    local y, m, d = str:match('(%d+)-(%d+)-(%d+)')
    if not y then return str end
    return os.date('%Y-%m-%d', os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }) + n * 86400)
end
local function dateDiff(a, b)
    local ay, am, ad = a:match('(%d+)-(%d+)-(%d+)')
    local by, bm, bd = b:match('(%d+)-(%d+)-(%d+)')
    if not ay or not by then return 0 end
    local ta = os.time({ year = tonumber(ay), month = tonumber(am), day = tonumber(ad), hour = 12 })
    local tb = os.time({ year = tonumber(by), month = tonumber(bm), day = tonumber(bd), hour = 12 })
    return math.floor((tb - ta) / 86400 + 0.5)
end
local function dateLabel(str)
    local y, m, d = str:match('(%d+)-(%d+)-(%d+)')
    if not y then return str end
    local t = os.date('*t', os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }))
    return string.format('%d/%d', t.month, t.day)
end

local function path()
    local p = SELF:GetOption('NotesPath')
    if not p or p == '' then p = MAIN end
    if not p then pcall(resolvePaths); p = MAIN end
    return p
end
local function setOpt(meter, opt, val) SKIN:Bang('!SetOption', meter, opt, tostring(val)) end
local function show(m) SKIN:Bang('!ShowMeter', m) end
local function hide(m) SKIN:Bang('!HideMeter', m) end
local function log(s, lvl) SKIN:Bang('!Log', s, lvl or 'Notice') end

local function readFile(p)
    -- 只读传入的路径，绝不回退到 notes.txt（曾导致把便签内容当成 AI 便签导入）
    if not p then return nil end
    local f = io.open(p, 'rb')
    if not f then return nil end
    local d = f:read('*a'); f:close()
    return d
end
local function readAll()
    local d = readFile(path())
    if not d then d = readFile(MAIN_ALT) end
    return d
end
local function readBak()
    local d = readFile(BAK)
    if not d then d = readFile(BAK_ALT) end
    return d
end

local function usedName(n)
    for i = 1, count do if notes[i] and notes[i].name == n then return true end end
    return false
end
local function defaultName()
    for _ = 1, #POOL * 2 do
        local n = POOL[namePtr]
        namePtr = namePtr % #POOL + 1
        if not usedName(n) then return n end
    end
    return POOL[1]
end

local function serialize()
    local body = '#FatFishNote v3\r\n'
    local rw = math.max(1, rows or 1)
    body = body .. string.format('#grid cols=%d rows=%d scale=%.2f\r\n', cols, rw, scale)
    body = body .. string.format('#theme %d\r\n#page %d\r\n', theme, page)
    for d in pairs(autoskips) do body = body .. '#autoskip ' .. d .. '\r\n' end
    for i = 1, count do
        local n = notes[i]
        body = body .. n.date .. '\t' .. clean(n.name) .. '\t' .. clean(n.text) .. '\t' .. ((n.src == 'ai' and 'ai') or (n.src == 'auto' and 'auto') or 'user') .. '\t' .. tostring(clamp(tonumber(n.theme) or 1, 1, 4)) .. '\r\n'
    end
    return body
end

local function writeRaw(body)
    local f = io.open(path(), 'wb')
    if not f then f = io.open(MAIN_ALT, 'wb') end
    if not f then return false end
    f:write(body); f:close()
    return true
end

-- 清理超过 5 天的记录（今天-4 之前）
local function prune()
    local cut = dateAdd(todayStr(), -4)
    local removed, kept = 0, {}
    for i = 1, #notes do
        if notes[i].date and notes[i].date >= cut then
            kept[#kept + 1] = notes[i]
        else
            removed = removed + 1
        end
    end
    if removed > 0 then
        notes = kept
        log('清理 ' .. removed .. ' 条超过 5 天的记录')
    end
    return removed
end

local function normalize()
    for a = 2, #notes do
        local k = notes[a]
        local b = a - 1
        while b >= 1 and (notes[b].date or '') > (k.date or '') do
            notes[b + 1] = notes[b]
            b = b - 1
        end
        notes[b + 1] = k
    end
end
local function writeAll()
    prune()
    count = #notes
    local cur = readAll()
    if cur and #cur > 0 then
        local bf = io.open(BAK, 'wb')
        if not bf then bf = io.open(BAK_ALT, 'wb') end
        if bf then bf:write(cur); bf:close() end
    end
    return writeRaw(serialize())
end

local function parse(data)
    local list = {}
    local version = 'v3'
    local gcols, grows, gscale, gtheme, gpage = nil, nil, nil, nil, nil
    for line in (data .. '\n'):gmatch('([^\r\n]*)\r?\n') do
        local l = line
        if l:sub(1, 1) == '#' then
            if l:find('FatFishNote') then
                if l:find('v1') then version = 'v1'
                elseif l:find('v2') then version = 'v2'
                else version = 'v3' end
            end
            local c, r = l:match('#grid cols=(%d+) rows=(%d+)')
            if c then gcols, grows = tonumber(c), tonumber(r) end
            local sc = l:match('#grid .*scale=([%d%.]+)')
            if sc then gscale = tonumber(sc) end
            local th = l:match('#theme%s+(%d+)')
            if th then gtheme = tonumber(th) end
            local pg = l:match('#page%s+(%d+)')
            local sk = l:match('#autoskip%s+(%d%d%d%d%-%d%d%-%d%d)')
            if sk then autoskips[sk] = true end
            if pg then gpage = tonumber(pg) end
        elseif l ~= '' then
            if #list < MAXN then
                local d, n, t, s, th = l:match('^(%d%d%d%d%-%d%d%-%d%d)\t([^\t]*)\t([^\t]*)\t?(%a*)\t?(%d*)$')
                if d and n and t then
                    list[#list + 1] = { date = d, name = n, text = t, src = (s == 'ai' and 'ai') or (s == 'auto' and 'auto') or 'user', theme = tonumber(th) or 1 }
                else
                    local name, txt = l:match('^([^\t]*)\t(.*)$')
                    if version == 'v1' or not name then name, txt = nil, l end
                    list[#list + 1] = { date = todayStr(), name = name, text = txt, src = 'user' }
                end
            end
        end
    end
    return list, gcols, grows, gscale, gtheme, gpage
end

-- 节气（2026/2027，按需求给定表，不推算）
local cnCache = {}

local function monthKeyOf(date) return date:sub(1, 7) end

local function currentMonthKey()
    return string.format('%04d-%02d', tonumber(SKIN:GetVariable('Y')) or 2026, tonumber(SKIN:GetVariable('M')) or 10)
end



local TRAD = { '春节', '元宵', '端午', '中秋', '重阳', '寒衣', '腊八', '除夕', '七夕', '中元', '龙抬头', '小年', '清明' }
local TERMS = { '立春','雨水','惊蛰','春分','谷雨','立夏','小满','芒种','夏至','小暑','大暑','立秋','处暑','白露','秋分','寒露','霜降','立冬','小雪','大雪','冬至','小寒','大寒' }

local function isDotDay(t)
    if not t or t == '' then return false end
    for _, k in ipairs(TERMS) do if t:find(k, 1, true) then return true end end
    for _, k in ipairs(TRAD) do if t:find(k, 1, true) then return true end end
    return false
end

function dumpDots()
    local mk = currentMonthKey()
    for d = 1, 31 do
        local mm = SKIN:GetMeasure('CN' .. d)
        local v = mm and mm:GetStringValue() or ''
        if v ~= '' then
            SKIN:Bang('!Log', string.format('CALDOT %s-%02d cn=%s dot=%s', mk, d, v, tostring(isDotDay(v))), 'Notice')
        end
    end
end

local function isFestivalText(t)
    if not t or t == '' then return false end
    local n = #t
    if n == 4 then
        local b = t:sub(1, 2)
        if b == string.char(179, 245) then return false end
        if b == string.char(202, 174) then return false end
        if b == string.char(216, 165) then return false end
        if t == string.char(200, 253, 202, 174) then return false end
    elseif n == 6 then
        if t:sub(1, 2) == string.char(182, 254) and t:sub(3, 4) == string.char(202, 174) then return false end
    end
    return true
end

local function cnFor(monthKey, day)
    local cache = cnCache[monthKey]
    if not cache then
        if monthKey ~= currentMonthKey() then return '' end
        cache = {}
        for d = 1, 31 do
            local m = SKIN:GetMeasure('CN' .. d)
            cache[d] = m and m:GetStringValue() or ''
        end
        cnCache[monthKey] = cache
    end
    local v = cache[day] or ''
    return isFestivalText(v) and v or ''
end

local function holidayOf(date)
    local d = tonumber(date:sub(9, 10))
    if not d then return '' end
    return cnFor(monthKeyOf(date), d)
end

local function metrics()
    local s = scale
    return rnd(B_MARGIN * s), rnd(B_CARD_W * s), rnd(B_GAP_X * s),
        rnd(144 * s), rnd(B_GAP_Y * s), rnd(B_BOTTOM * s), rnd(B_CARD_H * s)
end
local function baseW(c) return B_MARGIN * 2 + c * B_CARD_W + (c - 1) * B_GAP_X end
local function baseH(r) return B_HEADER + 24 + r * B_CARD_H + (r - 1) * B_GAP_Y + B_BOTTOM end
local function maxScaleFor(r)
    local sw, sh = num('screenW'), num('screenH')
    if sw <= 0 then sw = 2560 end
    if sh <= 0 then sh = 1440 end
    local m = 2.0
    if baseW(cols) > 0 then m = math.min(m, sw / baseW(cols)) end
    if baseH(r) > 0 then m = math.min(m, sh / baseH(r)) end
    if m < 0.6 then m = 0.6 end
    return m
end
local function computePitch(r, ch, header, bottom, gapY)
    local scr = num('screenH'); if scr <= 0 then scr = 1440 end
    local fit = math.floor((scr - header - bottom - gapY * (r - 1)) / r)
    local p = math.min(rnd(132 * scale), fit)
    local minP = rnd(96 * scale)
    if p < minP then p = minP end
    if header + r * p - gapY + bottom > scr then p = math.max(fit, 72) end
    return p
end

local function buildColumns()
    local dragging = (dragIdx and dragIdx >= 1) or NEW_DRAG or (FAVUI and (FAVUI.drag or FAVUI.dropping))
    if not dragging then
        -- 只裁尾部空行列；中间空列代表「该日无便签」，必须保留，否则日期错位
        local lastCol = 0
        for i = 1, count do
            local dc = dateDiff(baseDate, notes[i].date or baseDate)
            if dc + 1 > lastCol then lastCol = dc + 1 end
        end
        cols = lastCol
        if cols < 2 then cols = 2 end
        if cols > MAX_COLS then cols = MAX_COLS end
    end
    colLists = {}
    for c = 1, cols do colLists[c] = {} end
    for i = 1, count do
        local dc = dateDiff(baseDate, notes[i].date or baseDate)
        if dc >= 0 and dc < cols then table.insert(colLists[dc + 1], i) end
    end
    local mx = 1
    for c = 1, cols do if #colLists[c] > mx then mx = #colLists[c] end end
    rows = math.max(1, mx)
    if dragging and gridRows > rows then rows = gridRows end
end

local function slotPos(r, c)
    local margin, cardW, gapX, header = metrics()
    return margin + (c - 1) * (cardW + gapX), header + (r - 1) * pitch
end

local function colDate(c) return dateAdd(baseDate, c - 1) end

local function targetCell(x, y)
    local margin, cardW, gapX, header, gapY, bottom, ch = metrics()
    local c = math.floor((x - margin) / (cardW + gapX)) + 1
    local r = math.floor((y - header) / pitch) + 1
    if c < 1 then c = 1 end
    if r < 1 then r = 1 end
    if c > cols then
        if c <= MAX_COLS and baseW(c) * scale <= num('screenW') then
            cols = c
            buildColumns()
            pitch = computePitch(rows, ch, header, bottom, gapY)
            cardH = pitch - gapY
            return -1, -1, true
        end
        return -1, -1, false
    end
    if r > rows then
        if baseH(r) * scale <= num('screenH') then
            gridRows = r; buildColumns()
            pitch = computePitch(rows, ch, header, bottom, gapY)
            cardH = pitch - gapY
            return -1, -1, true
        end
        return -1, -1, false
    end
    return c, r, true
end

local hoverIdx = -1

local function ring()
    local target = (dragIdx and dragIdx >= 1) and dragIdx or (hoverIdx >= 0 and hoverIdx + 1 or -1)
    if target and target >= 1 and target <= count and dragIdx < 1 then
        local c, r, x, y = 1, 1
        for cc = 1, cols do
            for rr, idx in ipairs(colLists[cc] or {}) do
                if idx == target then c, r = cc, rr end
            end
        end
        x, y = slotPos(r, c)
        local _, cw2, _, _, gapY2, _, _ = metrics()
        local ch2 = pitch - gapY2
        -- 光圈跟随该便签自己的配色
        local nth = (notes[target] and tonumber(notes[target].theme)) or 1
        local th = THEMES[clamp(nth, 1, 4)]
        local inset = rnd(2 * scale)
        hide('SelRing')
        setOpt('SelRing', 'X', x - inset); setOpt('SelRing', 'Y', y - inset)
        setOpt('SelRing', 'Shape', 'Rectangle 0,0,' .. (cw2 + inset * 2) .. ',' .. (ch2 + inset * 2) .. ',' .. rnd(13 * scale) .. ' | Fill Color 0,0,0,0 | StrokeWidth ' .. math.max(1, rnd(2 * scale)) .. ' | Stroke Color ' .. th.accent .. ',255')
        show('SelRing')
    else
        hide('SelRing')
    end
end

local function hideCard(i)
    local m = i - 1
    for _, p in ipairs({ 'Card', 'Head', 'Name', 'Del', 'Text' }) do hide(p .. m) end

end

local function themeColors() return THEMES[clamp(theme, 1, 4)] end

local function cardShape(m, isAI, th)
    local margin, cardW, gapX, header, gapY, bottom, ch = metrics()
    th = th or themeColors()
    local rr = rnd(12 * scale)
    local fill, stroke = th.card, th.stroke
    if isAI then fill, stroke = '26,58,74,240', '120,220,255,95' end
    setOpt('Card' .. m, 'Shape', 'Rectangle 0,0,' .. cardW .. ',' .. cardH .. ',' .. rr .. ' | Fill Color ' .. fill .. ' | StrokeWidth ' .. math.max(1, rnd(1 * scale)) .. ' | Stroke Color ' .. stroke)
    setOpt('Head' .. m, 'Shape', 'Rectangle 0,0,' .. (cardW - 2) .. ',' .. rnd(26 * scale) .. ',' .. rnd(10 * scale) .. ' | Fill Color 176,158,255,24')
    setOpt('Name' .. m, 'FontSize', rnd(8 * scale))
    setOpt('Name' .. m, 'FontColor', isAI and '120,220,255,255' or (th.accent .. ',235'))
    setOpt('Del' .. m, 'FontSize', rnd(12 * scale))
    setOpt('Text' .. m, 'FontSize', rnd(10 * scale))
    setOpt('Text' .. m, 'FontColor', th.head)
    setOpt('Text' .. m, 'W', math.max(20, cardW - rnd(28 * scale)))
    setOpt('Text' .. m, 'H', math.max(20, cardH - rnd(48 * scale)))
end


-- 只有一套配色点：悬停哪张就移到哪张
local SWATCH_COLORS = { '176,158,255', '120,180,255', '110,220,190', '255,180,120' }

local function placeSwatches(m)
    local _, cardW = metrics()
    local cc, rr = nil, nil
    for c = 1, cols do
        for r2, idx in ipairs(colLists[c] or {}) do
            if idx - 1 == m then cc, rr = c, r2 end
        end
    end
    if not cc then return false end
    local x, y = slotPos(rr, cc)
    local rad = math.max(3, rnd(7 * scale))
    -- 先隐藏再位移，避免看到跳格
    for k = 1, 4 do hide('Sw_' .. k) end
    -- 先全部移动 + 更新，再统一显示，避免旧位置闪一下
    for k = 1, 4 do
        local n = 'Sw_' .. k
        setOpt(n, 'Shape', 'Ellipse ' .. rad .. ',' .. rad .. ',' .. rad .. ',' .. rad .. ' | Fill Color ' .. SWATCH_COLORS[k] .. ',255 | StrokeWidth 0')
        setOpt(n, 'X', x + cardW - rnd((24 + 18 * (5 - k)) * scale) - rad)
        setOpt(n, 'Y', y + rnd(14 * scale) - rad)
    end
    for k = 1, 4 do
        local n = 'Sw_' .. k
        show(n)
        SKIN:Bang('!UpdateMeter', n)
    end
    return true
end

function hoverCard(m)
    if boardLocked() then return end
    -- 正在拖某张便签时，其它卡片的悬浮一律不响应（否则会残留选中框/色板，卡片还会闪一下）
    if (dragIdx and dragIdx >= 1) or NEW_DRAG then return end
    m = tonumber(m) or -1
    hoverIdx = m
    SKIN:Bang('!CommandMeasure', 'SwTimer', 'Stop 1')
    placeSwatches(m)
    ring()
    SKIN:Bang('!Redraw')
end

function swatchHover()
    SKIN:Bang('!CommandMeasure', 'SwTimer', 'Stop 1')
end

function leaveCard(mx, my)
    if boardLocked() then return end
    if (dragIdx and dragIdx >= 1) or NEW_DRAG then return end
    swHidePending()
end

function swHide(m) leaveCard() end

function swHidePending()
    for k = 1, 4 do hide('Sw_' .. k) end
    hoverIdx = -1
    ring()
    SKIN:Bang('!Redraw')
end

function swatchClick(k)
    -- favOpen 是后声明的 local，这里的自由变量会解析成全局，必须走函数查询
    if favIsOpen() then
        setFavTheme(k)
    elseif hoverIdx >= 0 then
        setCardTheme(hoverIdx, k)
    end
end

local cardNote = {}

function setCardTheme(m, k)
    local i = cardNote[tonumber(m)]
    if not i or not notes[i] then return end
    notes[i].theme = clamp(tonumber(k) or 1, 1, 4)
    writeAll()
    SKIN:Bang('!CommandMeasure', 'NoteLua', 'relayoutWeather()')
    placeSwatches(m)
end

local function updateCard(i, c, r)
    i = tonumber(i)
    if not i or i < 1 or i > count then return end
    local margin, cardW, gapX, header = metrics()
    local m = i - 1
    cardNote[m] = i
    local x, y = slotPos(r, c)
    local nth = THEMES[clamp(tonumber(notes[i].theme) or 1, 1, 4)]
    cardShape(m, notes[i].src == 'ai', nth)
    setOpt('Card' .. m, 'X', x); setOpt('Card' .. m, 'Y', y)
    setOpt('Head' .. m, 'X', x + 1); setOpt('Head' .. m, 'Y', y + 1)
    setOpt('Name' .. m, 'X', x + rnd(14 * scale)); setOpt('Name' .. m, 'Y', y + rnd(8 * scale))
    setOpt('Del' .. m, 'X', x + cardW - rnd(24 * scale)); setOpt('Del' .. m, 'Y', y + rnd(14 * scale))
    setOpt('Text' .. m, 'X', x + rnd(14 * scale)); setOpt('Text' .. m, 'Y', y + rnd(40 * scale))
    setOpt('Name' .. m, 'Text', notes[i].name)
    setOpt('Text' .. m, 'Text', notes[i].text)
    for _, pfx in ipairs({ 'Card', 'Head', 'Name', 'Del', 'Text' }) do
        SKIN:Bang('!UpdateMeter', pfx .. m)
    end
    show('Card' .. m); show('Head' .. m); show('Name' .. m); show('Del' .. m)

    if i == editIdx and editMode == 0 then hide('Text' .. m) else show('Text' .. m) end
    if i == editIdx and editMode == 1 then hide('Name' .. m) else show('Name' .. m) end
end

local function wxFor(c)
    local idx = dateDiff(todayStr(), colDate(c))
    if idx < 0 or idx > 6 then return '—' end
    local v = SKIN:GetVariable('wx' .. idx)
    if not v or v == '' then return '--' end
    return v
end

local function colLabel(c)
    local d = colDate(c)
    local idx = dateDiff(todayStr(), d)
    if idx == 0 then return '今天 ' .. dateLabel(d) end
    if idx == 1 then return '明天 ' .. dateLabel(d) end
    local wd = WEEK[tonumber(os.date('%w', os.time({ year = tonumber(d:sub(1,4)), month = tonumber(d:sub(6,7)), day = tonumber(d:sub(9,10)), hour = 12 }))) + 1] or ''
    return dateLabel(d) .. ' ' .. wd
end

local function applyTheme()
    local th = themeColors()
    setOpt('WeatherText', 'FontColor', th.accent .. ',255')
    setOpt('AddBtn', 'Shape', 'Ellipse ' .. rnd(17 * scale) .. ',' .. rnd(17 * scale) .. ',' .. rnd(17 * scale) .. ' | Fill Color ' .. th.accent .. ',45 | StrokeWidth 1 | Stroke Color ' .. th.accent .. ',150')
    setOpt('Handle', 'Shape', 'Ellipse ' .. rnd(8 * scale) .. ',' .. rnd(8 * scale) .. ',' .. rnd(8 * scale) .. ' | Fill Color 255,255,255,90 | StrokeWidth 1 | Stroke Color ' .. th.accent .. ',190')
    for i = 0, 5 do setOpt('ColHead' .. i, 'FontColor', th.head); setOpt('ColHead' .. i, 'InlineSetting', 'Color | ' .. th.accent .. ',255'); setOpt('ColHead' .. i, 'InlinePattern', '·.*') end
    for i = 0, 5 do setOpt('ColWx' .. i, 'FontColor', '235,238,245,150') end
end

local function layout()
    local margin, cardW, gapX, header, gapY, bottom, ch = metrics()
    baseDate = dateAdd(todayStr(), -page)
    buildColumns()
    pitch = computePitch(rows, ch, header, bottom, gapY)
    cardH = pitch - gapY
    local w = margin * 2 + cols * cardW + (cols - 1) * gapX
    local h = header + rows * cardH + (rows - 1) * gapY + bottom
    SKIN:Bang('!SetVariable', 'SH', h)
    SKIN:Bang('!SetVariable', 'SW', w)
    SKIN:Bang('!SetVariable', 'rows', rows)
    SKIN:Bang('!SetVariable', 'cols', cols)
    applyTheme()
    setOpt('Panel', 'Shape', 'Rectangle 0,0,' .. (w - 1) .. ',' .. (h - 1) .. ',' .. rnd(16 * scale) .. ' | Fill LinearGradient 2 | StrokeWidth 1 | Stroke LinearGradient 1')
    local mg = rnd(28 * scale)
    setOpt('TitleText', 'X', w / 2); setOpt('TitleText', 'Y', rnd(24 * scale)); setOpt('TitleText', 'FontSize', rnd(17 * scale)); setOpt('TitleText', 'StringAlign', 'CenterCenter')
    setOpt('FavBtn', 'X', rnd(w / 2 + 96 * scale)); setOpt('FavBtn', 'Y', rnd(24 * scale)); setOpt('FavBtn', 'FontSize', rnd(21 * scale))


    setOpt('ClockText', 'X', w - rnd(28 * scale)); setOpt('ClockText', 'StringAlign', 'RightTop'); setOpt('ClockText', 'Y', rnd(3 * scale)); setOpt('ClockText', 'FontSize', rnd(26 * scale)); setOpt('ClockText', 'StringAlign', 'RightTop'); setOpt('ClockText', 'W', rnd(140 * scale))
    setOpt('DateText', 'X', w - rnd(28 * scale)); setOpt('DateText', 'Y', rnd(50 * scale)); setOpt('DateText', 'FontSize', rnd(9 * scale)); setOpt('DateText', 'StringAlign', 'RightTop'); setOpt('DateText', 'W', rnd(140 * scale))
    setOpt('AddBtn', 'X', w - rnd(61 * scale)); setOpt('AddBtn', 'Y', rnd(15 * scale)); hide('AddBtn'); hide('AddText')
    setOpt('AddText', 'X', w - rnd(44 * scale)); setOpt('AddText', 'Y', rnd(31 * scale)); setOpt('AddText', 'FontSize', rnd(15 * scale))
    setOpt('PrevBtn', 'X', rnd(42 * scale)); setOpt('PrevBtn', 'Y', rnd(116 * scale)); setOpt('PrevBtn', 'FontSize', rnd(14 * scale))
    setOpt('NextBtn', 'X', w - rnd(42 * scale)); setOpt('NextBtn', 'Y', rnd(116 * scale)); setOpt('NextBtn', 'FontSize', rnd(14 * scale))
    setOpt('PrevBtn', 'FontColor', page < PAGE_MAX and '235,238,245,230' or '235,238,245,102')
    setOpt('NextBtn', 'FontColor', page > 0 and '235,238,245,230' or '235,238,245,102')
    setOpt('PrevHit', 'X', rnd(28 * scale)); setOpt('PrevHit', 'Y', rnd(104 * scale))
    setOpt('NextHit', 'X', w - rnd(52 * scale)); setOpt('NextHit', 'Y', rnd(104 * scale))
    setOpt('PrevHit', 'Shape', 'Rectangle 0,0,' .. rnd(24 * scale) .. ',' .. rnd(24 * scale) .. ' | Fill Color 0,0,0,1 | StrokeWidth 0')
    setOpt('NextHit', 'Shape', 'Rectangle 0,0,' .. rnd(24 * scale) .. ',' .. rnd(24 * scale) .. ' | Fill Color 0,0,0,1 | StrokeWidth 0')
    show('PrevHit'); show('NextHit')
    setOpt('TopDivider', 'Shape', 'Rectangle 0,0,' .. (w - rnd(56 * scale)) .. ',1 | Fill Color 255,255,255,18 | StrokeWidth 0')
    setOpt('TopDivider', 'X', mg); setOpt('TopDivider', 'Y', rnd(104 * scale))
    show('TopDivider')
    show('TopDivider')
    -- 缩放/布局
    setOpt('Handle', 'X', w - rnd(26 * scale)); setOpt('Handle', 'Y', h - rnd(26 * scale))
    show('Handle')
    -- 顶部农历行：强制按「今天」重算，不受翻页/选中日期影响
    SKIN:Bang('!UpdateMeasure', 'LunarParent')
    SKIN:Bang('!UpdateMeasure', 'LunarDate')
    SKIN:Bang('!UpdateMeasure', 'LunarTerm')
    local lunar = SKIN:GetMeasure('LunarDate'):GetStringValue()
    local fest = holidayOf(os.date('%Y-%m-%d'))
    local term = SKIN:GetMeasure('LunarTerm'):GetStringValue()
    term = tostring(term or ''):gsub('%s*第%d+天%s*', ''):gsub('%s+$', '')
    local extra = ''
    if fest ~= '' and term ~= '' and fest ~= term then extra = fest .. ' · ' .. term
    elseif fest ~= '' then extra = fest
    else extra = term end
    local lunarText = (lunar or '') .. (extra ~= '' and (' · ' .. extra) or '')
    setOpt('LunarLine', 'Text', lunarText)
    SKIN:Bang('!SetVariable', 'lunarText', lunarText)
    marqueeMeasure()
    SKIN:Bang('!UpdateMeter', 'WeatherText')
    show('LunarLine')
    -- 月历：固定尺寸（格 26x15，间距 2，7 列）
    local first = tonumber(SKIN:GetMeasure('LunarFirst'):GetStringValue()) or 1
    local last = tonumber(SKIN:GetMeasure('LunarLast'):GetStringValue()) or 30
    if last > 31 then last = 31 end
    local blanks = (first - 1) % 7
    local nrows = math.ceil((blanks + last) / 7)
    local cw, ch, gap = 22, 15, 2
    local hdrH = 12
    local y0
    if nrows >= 6 then
        hdrH = 8
        ch = 11
        gap = 1
        y0 = 10
    else
        if nrows == 5 then ch = 14 end
        local H0 = hdrH + nrows * ch + (nrows - 1) * gap
        if nrows == 5 then
            y0 = 10
        else
            y0 = math.floor((104 - H0) / 2)
            if y0 < 6 then y0 = 6 end
        end
        if y0 + H0 > 104 then y0 = 104 - H0 end
    end
    local totalH = hdrH + nrows * ch + (nrows - 1) * gap
    local x0 = 28
    if nrows >= 6 then
        SKIN:Bang('!Log', string.format('CAL6 nrows=%d blanks=%d last=%d cw=%d ch=%d hdrH=%d gap=%d totalH=%d y0=%d', nrows, blanks, last, cw, ch, hdrH, gap, totalH, y0), 'Notice')
    end
    local today = tonumber(SKIN:GetVariable('D')) or 1
    local marks = {}
    local names = { '一', '二', '三', '四', '五', '六', '日' }
    for i = 0, 6 do
        setOpt('CalW' .. i, 'X', rnd((x0 + i * (cw + gap) + cw / 2) * scale))
        setOpt('CalW' .. i, 'Y', rnd((y0 + hdrH / 2) * scale))
        setOpt('CalW' .. i, 'FontSize', rnd(7 * scale))
        setOpt('CalW' .. i, 'Text', names[i + 1])
        show('CalW' .. i)
    end
    for d = 1, 31 do
        local m = 'CalDay' .. (d - 1)
        if d <= last then
            local pos = blanks + d - 1
            local col = pos % 7
            local row = math.floor(pos / 7)
            local dx = (x0 + col * (cw + gap) + cw / 2) * scale
            local dy = (y0 + hdrH + row * (ch + gap) + ch / 2) * scale
            local isToday = (d == today)
            setOpt(m, 'X', rnd(dx)); setOpt(m, 'Y', rnd(dy))
            setOpt(m, 'FontSize', rnd(8 * scale))
            setOpt(m, 'FontColor', isToday and '36,30,62,255' or '235,238,245,220')
            setOpt(m, 'Text', tostring(d))
            show(m)
            local hol = cnFor(currentMonthKey(), d)
            if isToday then
                local dia = math.min(cw, ch) - 2
                local rr = ((ch + 4) / 2) * scale
                marks[#marks + 1] = 'Ellipse ' .. rnd(dx) .. ',' .. rnd(dy - 1 * scale) .. ',' .. rnd(rr) .. ',' .. rnd(rr) .. ' | Fill Color ' .. themeColors().accent .. ',255 | StrokeWidth 0'
            end
        else
            hide(m)
        end
    end
    for i = 1, 40 do local key = (i == 1) and 'Shape' or ('Shape' .. i); setOpt('CalMarks', key, i <= #marks and marks[i] or '') end
    show('CalMarks')
    if nrows >= 6 then
        local w0 = SKIN:GetMeter('CalW0')
        SKIN:Bang('!Log', string.format('CAL6 CalW0 x=%s y=%s expectX=%d expectY=%d winH=%s', tostring(w0:GetX(true)), tostring(w0:GetY(true)), rnd((x0 + cw / 2) * scale), rnd((y0 + hdrH / 2) * scale), tostring(SKIN:GetVariable('SH'))), 'Notice')
    end
    -- 列头与线
    local chh = rnd(40 * scale)
    local topBar = rnd(104 * scale)
    for i = 0, 5 do
        local m = 'ColHead' .. i
        local wm = 'ColWx' .. i
        if i < cols then
            local cx = margin + i * (cardW + gapX) + cardW / 2
            setOpt(m, 'X', cx); setOpt(m, 'Y', topBar + rnd(12 * scale))
            setOpt(m, 'FontSize', rnd(9 * scale))
            local hol = holidayOf(colDate(i + 1))
            setOpt(m, 'Text', colLabel(i + 1) .. (hol ~= '' and (' · ' .. hol) or ''))
            if colDate(i + 1) == todayStr() then setOpt(m, 'FontColor', themeColors().accent .. ',255') else setOpt(m, 'FontColor', '235,238,245,204') end
            setOpt(wm, 'X', cx); setOpt(wm, 'Y', topBar + rnd(30 * scale))
            setOpt(wm, 'FontSize', rnd(8 * scale))
            setOpt(wm, 'Text', wxFor(i + 1))
            show(m); show(wm)
            hide('ColFest' .. i)
        else
            hide(m); hide(wm); hide('ColFest' .. i)
        end
    end
    for i = 0, 4 do
        local m = 'Divider' .. i
        if i < cols - 1 then
            local dh = h - bottom - header
            if dh < 1 then dh = 1 end
            setOpt(m, 'Shape', 'Rectangle 0,0,1,' .. dh .. ' | Fill Color 255,255,255,20')
            setOpt(m, 'X', margin + (i + 1) * (cardW + gapX) - math.floor(gapX / 2))
            setOpt(m, 'Y', header)
            show(m)
        else
            hide(m)
        end
    end
    -- 卡片
    for i = 1, MAXN do hideCard(i) end
    for cc = 1, cols do
        for rr, idx in ipairs(colLists[cc] or {}) do
            if idx == dragIdx and not pending then hideCard(idx) else updateCard(idx, cc, rr) end
        end
    end
    if count == 0 then
        setOpt('EmptyHint', 'X', w / 2); setOpt('EmptyHint', 'Y', header + cardH / 2)
        setOpt('EmptyHint', 'FontSize', rnd(11 * scale))
        show('EmptyHint')
    else
        hide('EmptyHint')
    end
    setOpt('Hint', 'X', w / 2); setOpt('Hint', 'Y', h - rnd(14 * scale)); setOpt('Hint', 'FontSize', rnd(8 * scale))
    -- ＋ 按钮状态：30 张满 / 历史页 禁用
    if count >= MAXN or page > 0 then
        setOpt('AddBtn', 'Shape', 'Ellipse ' .. rnd(17 * scale) .. ',' .. rnd(17 * scale) .. ',' .. rnd(17 * scale) .. ' | Fill Color 110,110,120,30 | StrokeWidth 1 | Stroke Color 150,150,160,90')
        setOpt('AddText', 'FontColor', '120,120,130,140')
    else
        setOpt('AddText', 'FontColor', '235,238,245,255')
    end
    -- 标题下的新建区
    local zw = rnd(160 * scale)
    local calRight = rnd((28 + 7 * 22 + 6 * 2 + 12) * scale)
    local zx = math.max(calRight, rnd(w / 2 - zw / 2))
    if zx + zw > w - rnd(28 * scale) then zx = w - rnd(28 * scale) - zw end
    local zy = rnd(58 * scale)
    setOpt('NewZone', 'X', zx); setOpt('NewZone', 'Y', zy)
    setOpt('NewZone', 'Shape', 'Rectangle 0,0,' .. zw .. ',' .. rnd(40 * scale) .. ',6 | Fill Color 0,0,0,1 | StrokeWidth 1 | Stroke Color 255,255,255,30')
    setOpt('NewZoneText', 'X', zx + zw / 2); setOpt('NewZoneText', 'Y', zy + rnd(20 * scale))
    setOpt('NewZoneHint', 'X', w / 2); setOpt('NewZoneHint', 'Y', zy + rnd(25 * scale)); setOpt('NewZoneHint', 'FontSize', rnd(7 * scale))
    setOpt('NewZoneText', 'FontSize', rnd(8 * scale))
    hide('NewZoneHint')
    lastZone = { x = zx, y = zy, w = zw, h = rnd(40 * scale) }
    if page == 0 then show('NewZone'); show('NewZoneText') else hide('NewZone'); hide('NewZoneText') end
    -- 右栏两行（时钟下方，右对齐）
    -- 右栏定位由 marqueeApply 统一处理
    ring()
    local gk = cols .. 'x' .. rows
    if gk ~= lastGrid then lastGrid = gk; writeAll() end
    SKIN:Bang('!Update')
    SKIN:Bang('!Redraw')
end


-- 数据层重载：外部改了 notes.txt 之后调用，不用刷新皮肤
function reloadNotes()
    local d = readAll()
    if d then
        local list, gc, gr, gs, gt, gp = parse(d)
        notes = list; count = #notes
        if gc then cols = clamp(gc, 2, MAX_COLS) end
        if gr then gridRows = math.max(1, gr) end
        if gs then scale = clamp(gs, 0.6, 2.0) end
        if gt then theme = clamp(gt, 1, 4) end
        if gp then page = clamp(gp, 0, PAGE_MAX) end
    end
    layout()
    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Redraw')
    return count
end

function boot()
    resolvePaths()
    loadAuto()
    notes = {}; count = 0; cols = 2; gridRows = 1; scale = 1; page = 0; theme = 1
    local d = readAll()
    if d then
        local list, gc, gr, gs, gt, gp = parse(d)
        notes = list; count = #notes
        if gc then cols = clamp(gc, 2, MAX_COLS) end
        if gr then gridRows = math.max(1, gr) end
        if gs then scale = clamp(gs, 0.6, 2.0) end
        if gt then theme = clamp(gt, 1, 4) end
        if gp then page = clamp(gp, 0, PAGE_MAX) end
    end
    if count == 0 and (not d or not d:find('#FatFishNote')) then
        local b = readBak()
        if b then
            local lb = parse(b)
            if #lb > 0 then
                notes = lb; count = #lb
                writeRaw(serialize())
                log('notes.txt 为空或格式非法，已从 notes.bak 恢复 ' .. count .. ' 条')
            end
        end
    end
    local pruned = prune()
    count = #notes
    if pruned > 0 then writeRaw(serialize()) end
    for i = 1, count do
        if not notes[i].date or notes[i].date == '' then notes[i].date = todayStr() end
        if not notes[i].name or notes[i].name == '' then notes[i].name = defaultName() end
        if not notes[i].text or notes[i].text == '' then notes[i].text = '(空)' end
        if notes[i].src ~= 'ai' and notes[i].src ~= 'auto' then notes[i].src = 'user' end
    end
    -- 首次迁移 v1/v2 → v3 写回
    if d and not d:find('v3') then writeAll() end
    sel = count > 0 and 1 or -1
    dragIdx = -1; editIdx = -1; scaling = false
    toloday = todayStr()
    scale = clamp(scale, 0.6, maxScaleFor(math.max(1, math.ceil(count / cols), gridRows)))
    booted = true
    -- 立即启用并抓取天气，避免首屏停在 --°
    SKIN:Bang('!EnableMeasure', 'MeasureWeather')
    SKIN:Bang('!CommandMeasure', 'MeasureWeather', 'Update')
    layout()
    SKIN:Bang('!CommandMeasure', 'AutoTimer', 'Execute 1')
end

local function canEdit() return page == 0 end

function add()
    if count >= MAXN or not canEdit() then return end
    count = count + 1
    notes[count] = { date = todayStr(), name = defaultName(), text = '新便签', src = 'user' }
    sel = count
    writeAll()
    layout()
    edit(count)
end

function del(i)
    i = tonumber(i) or sel
    if not canEdit() then return end
    if i < 1 or i > count then return end
    if notes[i].src == 'auto' then autoskips[notes[i].date] = true end
    table.remove(notes, i)
    count = count - 1
    gridRows = math.max(1, math.ceil(count / cols))
    if count == 0 then sel = -1 else sel = math.min(i, count) end
    editIdx = -1
    writeAll()
    layout()
end

function copy(i)
    i = tonumber(i) or sel
    if not canEdit() then return end
    if i < 1 or i > count or count >= MAXN then return end
    count = count + 1
    table.insert(notes, i + 1, { date = notes[i].date, name = defaultName(), text = notes[i].text, src = notes[i].src })
    sel = i + 1
    writeAll(); layout()
end

function top(i)
    i = tonumber(i) or sel
    if not canEdit() then return end
    if i < 1 or i > count or i == count then return end
    local t = table.remove(notes, i)
    notes[count] = t
    sel = count
    writeAll(); layout()
end

function raise(i)
    i = tonumber(i) or sel
    if not canEdit() then return end
    if i < 1 or i >= count then return end
    notes[i], notes[i + 1] = notes[i + 1], notes[i]
    sel = i + 1
    writeAll(); layout()
end

function lower(i)
    i = tonumber(i) or sel
    if not canEdit() then return end
    if i < 2 or i > count then return end
    notes[i], notes[i - 1] = notes[i - 1], notes[i]
    sel = i - 1
    writeAll(); layout()
end

function select(i)
    i = tonumber(i) or -1
    if i < 1 or i > count then return end
    sel = i
    ring()
    SKIN:Bang('!Redraw')
end

function pagePrev()
    if boardLocked() then return end
    if page < PAGE_MAX then page = page + 1; writeAll(); layout(); autoGen() end
end
function pageNext()
    if boardLocked() then return end
    if page > 0 then page = page - 1; writeAll(); layout(); autoGen() end
end

function setTheme(n)
    n = tonumber(n) or 1
    theme = clamp(n, 1, 4)
    writeAll(); layout()
end

-- 鼠标悬停在便签名框上时显示配色点
local SWCOL = { '176,158,255', '120,180,255', '110,220,190', '255,180,120' }
local swPending = nil

function swHideNow(m) end

function swShow(m) hoverCard(m) end

function swHide(m)
    swPending = m
    SKIN:Bang('!CommandMeasure', 'SwTimer', 'Execute 1')
end



function menuTheme1() setTheme(1) end
function menuTheme2() setTheme(2) end
function menuTheme3() setTheme(3) end
function menuTheme4() setTheme(4) end

-- ===== 拖拽 =====
local function showGhost(i)
    setOpt('GhostName', 'Text', notes[i].name)
    setOpt('GhostText', 'Text', notes[i].text)
    setOpt('GhostCard', 'X', ghostX); setOpt('GhostCard', 'Y', ghostY)
    setOpt('GhostName', 'X', ghostX + rnd(14 * scale)); setOpt('GhostName', 'Y', ghostY + rnd(8 * scale))
    setOpt('GhostText', 'X', ghostX + rnd(14 * scale)); setOpt('GhostText', 'Y', ghostY + rnd(40 * scale))
    show('GhostCard'); show('GhostName'); show('GhostText')
end
local function hideGhost()
    hide('GhostCard'); hide('GhostName'); hide('GhostText')
    setOpt('GhostCard', 'Shape', 'Rectangle 0,0,1,1 | Fill Color 0,0,0,1 | StrokeWidth 0')
    local m = SKIN:GetMeter('GhostCard')
    if m and tostring(m:GetOption('Hidden')) ~= '1' then
        SKIN:Bang('!Log', 'GhostCard still visible after drop', 'Warning')
    end
end

local function normalize()
    for a = 2, #notes do
        local k = notes[a]
        local b = a - 1
        while b >= 1 and (notes[b].date or '') > (k.date or '') do
            notes[b + 1] = notes[b]
            b = b - 1
        end
        notes[b + 1] = k
    end
end

local function insertAt(date, row, note)
    local same = {}
    for i = 1, #notes do if notes[i].date == date then same[#same + 1] = i end end
    local pos
    if row >= 1 and row <= #same then pos = same[row]
    elseif #same == 0 then pos = #notes + 1
    else pos = same[#same] + 1 end
    table.insert(notes, pos, note)
    count = #notes
    normalize()
end

function beginNewDrag(mname, mx, my)
    if FAVUI and FAVUI.drag then
        FAVUI.drag = nil
        hideGhost(); hide('DropHint'); newZoneReset()
    end
    if boardLocked() then return end
    if page > 0 then return end
    NEW_DRAG = true
    local m = SKIN:GetMeter(tostring(mname))
    local ax, ay = 0, 0
    if m then ax = m:GetX(true) or 0; ay = m:GetY(true) or 0 end
    downX, downY = ax + (tonumber(mx) or 0), ay + (tonumber(my) or 0)
    local _, cardW = metrics()
    newGrabDX, newGrabDY = rnd(80 * scale), rnd(13 * scale)
    pending = true
    ghostX, ghostY = downX - newGrabDX, downY - newGrabDY
    dragIdx = -1
end
function beginDrag(i, mname, mx, my)
    if boardLocked() then return end
    -- 防御：上一次收藏拖出没走完就关了面板，这里先清干净
    if FAVUI and FAVUI.drag then
        FAVUI.drag = nil
        hideGhost(); hide('DropHint'); newZoneReset()
    end
    i = tonumber(i); mx = tonumber(mx) or 0; my = tonumber(my) or 0
    if not canEdit() then return end
    if not i or i < 1 or i > count then return end
    if editIdx == i then cancel() end
    local m = SKIN:GetMeter(tostring(mname))
    local ax, ay = 0, 0
    if m then ax = m:GetX(true) or 0; ay = m:GetY(true) or 0 end
    downX, downY = ax + mx, ay + my
    local c, r = 1, 1
    for cc = 1, cols do
        for rr, idx in ipairs(colLists[cc] or {}) do
            if idx == i then c, r = cc, rr end
        end
    end
    local x, y = slotPos(r, c)
    grabDX, grabDY = downX - x, downY - y
    dragIdx = i; dragTo = 1; sel = i; pending = true
    ghostX, ghostY = x, y
    -- 起拖瞬间清掉其它卡片留下的选中框与色板
    for k = 1, 4 do hide('Sw_' .. k) end
    hide('SelRing')
    hoverIdx = -1
    setOpt('NewZoneText', 'Text', '拖入收藏')
    ring()
end

function beginScale(mname, mx, my)
    scaling = true
    scaleStart = scale
    local m = SKIN:GetMeter(tostring(mname))
    local ax, ay = 0, 0
    if m then ax = m:GetX(true) or 0; ay = m:GetY(true) or 0 end
    scaleDownX, scaleDownY = ax + (tonumber(mx) or 0), ay + (tonumber(my) or 0)
    dragIdx = -1
    hide('DropHint')
end

function drag(x, y)
    x = tonumber(x); y = tonumber(y)
    if not x or not y then return end
    lastDragX, lastDragY = x, y
    if FAVUI and FAVUI.drag then
        dragFav(x, y)
        return
    end
    if NEW_DRAG then
        if pending then
            local ddx, ddy = x - downX, y - downY
            if math.sqrt(ddx * ddx + ddy * ddy) < 6 then return end
            pending = false
            setOpt('GhostCard', 'Shape', 'Rectangle 0,0,' .. rnd(160 * scale) .. ',' .. rnd(40 * scale) .. ',' .. rnd(6 * scale) .. ' | Fill Color 40,36,70,210 | StrokeWidth 1 | Stroke Color 120,220,255,170')
            setOpt('GhostName', 'Text', '新便签')
            hide('GhostText')
            show('GhostCard'); show('GhostName')


        end
        ghostX, ghostY = x - newGrabDX, y - newGrabDY
        setOpt('GhostCard', 'X', ghostX); setOpt('GhostCard', 'Y', ghostY)
        setOpt('GhostName', 'X', ghostX + rnd(80 * scale)); setOpt('GhostName', 'Y', ghostY + rnd(20 * scale)); setOpt('GhostName', 'StringAlign', 'CenterCenter'); setOpt('GhostName', 'FontSize', rnd(9 * scale))
        setOpt('GhostText', 'X', ghostX + rnd(14 * scale)); setOpt('GhostText', 'Y', ghostY + rnd(40 * scale))
        local c, r, ok = targetCell(x, y)
        if ok and c and r then
            local _, cardW = metrics()
            setOpt('DropHint', 'Shape', 'Rectangle 0,0,' .. cardW .. ',' .. cardH .. ',' .. rnd(12 * scale) .. ' | Fill Color 120,220,255,28 | StrokeWidth 2 | Stroke Color 120,220,255,190')
            local hx, hy = slotPos(r, c)
            setOpt('DropHint', 'X', hx); setOpt('DropHint', 'Y', hy)
            show('DropHint')
            hintValid = true
            dragCol = c
            dragRow = r
        else
            hide('DropHint')
            hintValid = false
        end
        SKIN:Bang('!Redraw')
        return
    end
    if scaling then
        local maxS = maxScaleFor(math.max(1, math.ceil(count / cols), gridRows))
        local ns = clamp(scaleStart + ((x - scaleDownX) + (y - scaleDownY)) / 500, 0.6, maxS)
        if math.abs(ns - scale) > 0.004 then scale = ns; layout() end
        return
    end
    if dragIdx < 1 then return end
    if pending then
        local dx, dy = x - downX, y - downY
        if math.sqrt(dx * dx + dy * dy) < 6 then return end
        pending = false
        hideCard(dragIdx)
        showGhost(dragIdx)
    end
    local c, r, ok = targetCell(x, y)
    if ok and c < 1 then
        layout()
        c, r, ok = targetCell(x, y)
    end
    if ok then
        dragTo = r
        dragCol = c
        local margin, cardW, gapX = metrics()
        local hx, hy = slotPos(r, c)
        setOpt('DropHint', 'Shape', 'Rectangle 0,0,' .. cardW .. ',' .. cardH .. ',' .. rnd(12 * scale) .. ' | Fill Color 120,220,255,28 | StrokeWidth 2 | Stroke Color 120,220,255,190')
        setOpt('DropHint', 'X', hx); setOpt('DropHint', 'Y', hy)
        show('DropHint')
        hintValid = true
    else
        hide('DropHint')
        hintValid = false
    end
    local margin, cardW, gapX, header, gapY, bottom, ch = metrics()
    local gx = clamp(x - grabDX, 4, margin * 2 + cols * cardW + (cols - 1) * gapX - cardW - 4)
    local gy = clamp(y - grabDY, 4, header + rows * pitch - gapY - 4)
    if gx ~= ghostX or gy ~= ghostY then
        ghostX, ghostY = gx, gy
        setOpt('GhostCard', 'X', gx); setOpt('GhostCard', 'Y', gy)
        setOpt('GhostName', 'X', gx + rnd(14 * scale)); setOpt('GhostName', 'Y', gy + rnd(8 * scale))
        setOpt('GhostText', 'X', gx + rnd(14 * scale)); setOpt('GhostText', 'Y', gy + rnd(40 * scale))
    end
    SKIN:Bang('!Redraw')
end

function drop(mx, my)
    if FAVUI and FAVUI.drag then
        favDrop(mx, my)
        return
    end
    -- 兜底：任何一次松手都把新建区文字复原
    if not (dragIdx and dragIdx >= 1) then setOpt('NewZoneText', 'Text', '拖出新便签') end
    -- 点在卡片标题条右侧的四个色点上：切换配色，不进拖拽逻辑
    mx, my = tonumber(mx), tonumber(my)
    -- 拖到「拖出新便签」框 = 收进收藏库
    local cx, cy = mx, my
    if (not cx or not cy) then cx, cy = lastDragX, lastDragY end
    if cx and cy and dragIdx and dragIdx >= 1 and lastZone then
        local z = lastZone
        if cx >= z.x and cx <= z.x + z.w and cy >= z.y and cy <= z.y + z.h then
            -- 关键：先清掉拖拽状态，否则 favAdd 里的 layout() 会把「拖拽中的那张」跳过更新，
            -- 导致索引移位后的某张卡片停在隐藏状态，直到下一次 layout 才恢复
            local dragI = dragIdx
            dragIdx = -1
            pending = false
            favAdd(dragI)
            hideGhost(); hide('DropHint')
            setOpt('NewZoneText', 'Text', '拖出新便签')
            dragIdx = -1; pending = false
            return
        end
    end

    if mx and my and dragIdx and dragIdx >= 1 then
        local m = dragIdx - 1
        for k = 1, 4 do
            local sw = SKIN:GetMeter('Sw' .. m .. '_' .. k)
            if sw then
                local sx, sy = sw:GetX(), sw:GetY()
                if sx and sy and mx >= sx - 3 and mx <= sx + 13 and my >= sy - 3 and my <= sy + 15 then
                    dragIdx = -1; pending = false
                    hide('DropHint'); hideGhost()
                    setTheme(k)
                    return
                end
            end
        end
    end

    if NEW_DRAG then
        NEW_DRAG = false
        hide('DropHint')
        hideGhost()
        local c, r, ok = dragCol, dragRow, hintValid
        hintValid = false
        pending = false
        dragCol = nil
        dragRow = nil
        if ok and c and r then
            local d = colDate(c)
            insertAt(d, r, { date = d, name = defaultName(), text = '新便签', src = 'user' })
            sel = -1
            writeAll()
        end
        layout()
        -- 新日期列出现后，按配置页规则补齐自动便签
        if ok then autoGen(); layout() end
        return
    end
    if scaling then
        scaling = false
        writeAll(); layout()
        return
    end
    if dragIdx < 1 then pending = false; return end
    local wasDragging = not pending
    local from = dragIdx
    -- snapshot old dates by reference (index shifts are safe)
    local snap = {}
    for i = 1, count do snap[i] = { note = notes[i], date = notes[i].date } end
    hide('DropHint')
    if wasDragging and hintValid and dragCol and dragCol >= 1 then
        local list = colLists[dragCol] or {}
        local pos = dragTo
        if list[pos] and list[pos] ~= from then
            -- 交换两张的内容（含日期与来源）
            local a, b = notes[from], notes[list[pos]]
            notes[from], notes[list[pos]] = b, a
            sel = list[pos]
        else
            notes[from].date = colDate(dragCol)
            local t = table.remove(notes, from)
            table.insert(notes, #notes + 1, t)
            count = #notes
            sel = count
        end
        writeAll()
    end
    -- an auto note dragged off its date counts as deleting it: suppress that date
    for _, s in ipairs(snap) do
        if s.note and s.note.src == 'auto' and s.note.date ~= s.date then
            autoskips[s.date] = true
        end
    end
    hideGhost()
    setOpt('NewZoneText', 'Text', '拖出新便签')
    dragIdx = -1; pending = false; dragCol = nil
    writeAll()
    layout()
    -- 拖动已有便签到新日期后，同样为新日期补齐自动便签
    autoGen()
    layout()
    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Redraw')
end

-- ===== 编辑 =====
function focusBox()
    SKIN:Bang('!UpdateMeter', 'EditBox')
    SKIN:Bang('!TextEdit:Focus', 'EditBox')
    SKIN:Bang('!TextEdit:SelectAll', 'EditBox')
    SKIN:Bang('!Redraw')
end
local function openBox(x, y, w, h, text)
    setOpt('EditBox', 'X', x); setOpt('EditBox', 'Y', y)
    setOpt('EditBox', 'W', w); setOpt('EditBox', 'H', h)
    setOpt('EditBox', 'FontSize', rnd(10 * scale))
    setOpt('EditBox', 'InitialText', text)
    show('EditBox')
    SKIN:Bang('!UpdateMeter', 'EditBox')
    SKIN:Bang('!Redraw')
    SKIN:Bang('!CommandMeasure', 'FocusTimer', 'Execute 1')
end
local function locate(i)
    for cc = 1, cols do
        for rr, idx in ipairs(colLists[cc] or {}) do
            if idx == i then return cc, rr end
        end
    end
    return 1, 1
end

function edit(i)
    i = tonumber(i) or sel
    if not canEdit() then return end
    if i < 1 or i > count then return end
    sel = i; editIdx = i; editMode = 0
    local margin, cardW, gapX, header = metrics()
    local c, r = locate(i)
    local x, y = slotPos(r, c)
    hide('Text' .. (i - 1))
    openBox(x + rnd(12 * scale), y + rnd(36 * scale), cardW - rnd(26 * scale), rnd(24 * scale), notes[i].text)
    ring()
end

function rename(i)
    i = tonumber(i) or sel
    if not canEdit() then return end
    if i < 1 or i > count then return end
    if editIdx == i then cancel() end
    sel = i; editIdx = i; editMode = 1
    local margin, cardW, gapX, header = metrics()
    local c, r = locate(i)
    local x, y = slotPos(r, c)
    hide('Name' .. (i - 1))
    openBox(x + rnd(12 * scale), y + rnd(2 * scale), rnd(170 * scale), rnd(20 * scale), notes[i].name)
    ring()
end

function commit(v)
    hide('EditBox')
    local i, mode = editIdx, editMode
    editIdx = -1; editMode = 0
    if mode == 2 then
        local nm = cleanName(v)
        if nm ~= '' then SKIN:Bang('!CommandMeasure', 'WeatherLua', "lookup('" .. nm .. "')") end
        layout(); return
    end
    if i < 1 or i > count then layout(); return end
    if mode == 1 then
        local n = cleanName(v)
        if n == '' then n = defaultName() end
        notes[i].name = n
    else
        notes[i].text = clean(v)
        if notes[i].text == '' then notes[i].text = '(空)' end
    end
    writeAll(); layout()
end

function cancel()
    hide('EditBox')
    editIdx = -1; editMode = 0
    layout()
end

function menuCopy() if sel >= 1 then copy(sel) end end
function menuTop() if sel >= 1 then top(sel) end end
function menuRaise() if sel >= 1 then raise(sel) end end
function menuLower() if sel >= 1 then lower(sel) end end
function menuDel() if sel >= 1 then del(sel) end end
function menuEdit() if sel >= 1 then edit(sel) end end
function menuRename() if sel >= 1 then rename(sel) end end

-- ===== 日期 / AI / 天气 =====
function dateTick()
    if not booted then return end
    local d = todayStr()
    if d ~= toloday then
        toloday = d
        layout()
        autoGen()
    end
end

local function readAI()
    local d = readFile(AIIN)
    if not d then d = readFile(AI_ALT) end
    return d
end

function aiTick()
    local d = readAI()
    if not d or d == '' then return end
    local n = 0
    local cut = dateAdd(todayStr(), -4)
    for line in (d .. '\n'):gmatch('([^\r\n]*)\r?\n') do
        if line ~= '' and line:sub(1, 1) ~= '#' then
            local ds, nm, tx = line:match('^(%d%d%d%d%-%d%d%-%d%d)\t([^\t]*)\t(.*)$')
            if ds and tx and ds >= cut and ds <= dateAdd(todayStr(), 1) and count < MAXN then
                count = count + 1
                notes[count] = { date = ds, name = (nm ~= '' and nm) or defaultName(), text = tx, src = 'ai' }
                n = n + 1
            end
        end
    end
    -- 清空文件
    local f = io.open(AIIN, 'wb')
    if not f then f = io.open(AI_ALT, 'wb') end
    if f then f:write(''); f:close() end
    if n > 0 then
        log('导入 AI 便签 ' .. n .. ' 条')
        writeAll()
        layout()
    end
end

function relayoutWeather()
    layout()
end
local AUTO_FILE, AUTO_ALT
local function autoPaths()
    local d = resDir()
    AUTO_FILE = d .. 'autonote.txt'
    AUTO_ALT = d .. 'autonote_alt.txt'
end
pcall(autoPaths)
local autoRules, autoCycle, autoBase = nil, 2, '2026-01-01'
local autoMode, autoInterval, autoTName, autoTText = 'cycle', 7, '交周报', ''
local autoDDay, autoDName, autoDText = 1, '月报', '汇总本月情况'

function loadAuto()
    if not AUTO_FILE then pcall(autoPaths) end
    if autoRules then return end
    autoRules = {}
    autoCycle = 2
    autoBase = '2026-01-01'
    local data = readFile(AUTO_FILE) or readFile(AUTO_ALT)
    if data then
        for line in tostring(data):gmatch('[^\r\n]+') do
            local c = line:match('^#cycle%s+(%d+)')
            local b = line:match('^#base%s+(%d%d%d%d%-%d%d%-%d%d)')
            local mds = line:match('^#modes%s*([%a,]*)')
            if mds then
                autoModes = {}
                for one in mds:gmatch('[^,]+') do autoModes[#autoModes + 1] = one end
            end
            local md = line:match('^#mode%s+(%a+)')
            local iv = line:match('^#interval%s+(%d+)')
            local tn = line:match('^#tname%s+(.+)$')
            local tx = line:match('^#ttext%s+(.+)$')
            if md then autoMode = md end
            local dd = line:match('^#dday%s+(%d+)')
            local dn = line:match('^#dname%s+(.+)$')
            local dt = line:match('^#dtext%s+(.+)$')
            if dd then autoDDay = math.max(1, math.min(31, tonumber(dd))) end
            if dn then autoDName = dn end
            if dt then autoDText = dt end
            if iv then autoInterval = math.max(1, tonumber(iv)) end
            if tn then autoTName = tn end
            if tx then autoTText = tx end
            if c then autoCycle = math.max(1, math.min(7, tonumber(c))) end
            if b then autoBase = b end
            local idx, nm, tx = line:match('^(%d+)\t([^\t]*)\t(.*)$')
            if idx then autoRules[tonumber(idx)] = { name = nm, text = tx } end
        end
    end
    if not autoModes then
        autoModes = { autoMode or 'cycle' }
    end
    if not autoRules[1] then
        autoRules = { { name = '订货', text = '订货：确认下单数量' }, { name = '到货', text = '到货：核对到货清单' } }
    end
end

function reloadAuto()
    autoRules = nil
    loadAuto()
    autoGen()
end

-- ===== 自动便签配置接口（配置页 / agent 共用） =====
local AUTO_KEYS = { modes=1, mode=1, cycle=1, base=1, interval=1,
                    tname=1, ttext=1, dday=1, dname=1, dtext=1 }

local function autoFile()
    if not AUTO_FILE then pcall(autoPaths) end
    return AUTO_FILE or AUTO_ALT
end

local function autoRaw()
    local f = autoFile()
    if not f then return '' end
    return readFile(f) or ''
end

function autoDump()
    local out = {}
    for line in tostring(autoRaw()):gmatch('[^\r\n]+') do
        if line:match('%S') then out[#out + 1] = line end
    end
    return table.concat(out, ' | ')
end

-- spec 形如 "modes=monthly;interval=7"，value 留空表示删掉该键
function autoWrite(spec)
    local f = autoFile()
    if not f then return 'no-file' end
    local kv = {}
    for pair in tostring(spec or ''):gmatch('[^;]+') do
        local k, v = pair:match('^%s*([%w_]+)%s*=%s*(.-)%s*$')
        if k and AUTO_KEYS[k] then kv[k] = v end
    end
    if not next(kv) then return 'no-valid-key' end

    local old = autoRaw()
    if old ~= '' then
        local b = io.open(f .. '.bak', 'wb')
        if b then b:write(old); b:close() end
    end

    local lines, rules = {}, {}
    for line in tostring(old):gmatch('[^\r\n]+') do
        local k = line:match('^#([%w_]+)')
        if k and AUTO_KEYS[k] then
            if kv[k] ~= nil then
                if kv[k] ~= '' then lines[#lines + 1] = '#' .. k .. ' ' .. kv[k] end
                kv[k] = nil
            else
                lines[#lines + 1] = line
            end
        elseif line:match('%S') then
            rules[#rules + 1] = line
        end
    end
    for k, v in pairs(kv) do
        if v ~= '' then lines[#lines + 1] = '#' .. k .. ' ' .. v end
    end

    local out = table.concat(lines, '\r\n')
    if #rules > 0 then out = out .. '\r\n' .. table.concat(rules, '\r\n') end
    out = out .. '\r\n'

    local h = io.open(f, 'wb')
    if not h then return 'write-failed' end
    h:write(out)
    h:close()

    autoRules = nil
    loadAuto()
    autoGen()
    layout()
    return 'ok'
end

function autoGen()
    if not booted then return end
    local dates = {}
    for c = 1, cols do dates[#dates + 1] = colDate(c) end

    loadAuto()
    if not autoModes or #autoModes == 0 then return end
    local added = 0
    for _, d in ipairs(dates) do
        if not autoskips[d] then
            local dc0 = dateDiff(autoBase, d)
            local day = tonumber(d:sub(9, 10)) or 1
            local cands = {}

            for _, m in ipairs(autoModes) do
                local name, text
                if m == 'interval' then
                    if ((dc0 % autoInterval) + autoInterval) % autoInterval == 0 then
                        name, text = autoTName, autoTText
                    end
                elseif m == 'date' then
                    if day == autoDDay then name, text = autoDName, autoDText end
                elseif m == 'monthly' then
                    local ridx = ((day - 1) % autoCycle) + 1
                    local rule = autoRules[ridx] or autoRules[1]
                    name, text = rule.name, rule.text
                else
                    local ridx = ((dc0 % autoCycle) + autoCycle) % autoCycle + 1
                    local rule = autoRules[ridx] or autoRules[1]
                    name, text = rule.name, rule.text
                end
                if name and name ~= '' then
                    local dup = false
                    for _, c2 in ipairs(cands) do if c2.name == name then dup = true end end
                    for i2 = 1, count do
                        if notes[i2].date == d and notes[i2].name == name and notes[i2].src == 'auto' then dup = true end
                    end
                    if not dup then cands[#cands + 1] = { name = name, text = text } end
                end
            end

            for _, c2 in ipairs(cands) do
                if count < MAXN then
                    count = count + 1
                    notes[count] = { date = d, name = c2.name, text = c2.text, src = 'auto' }
                    added = added + 1
                end
            end
        end
    end
    if added > 0 then
        -- 同一日期里让自动便签排在用户便签之前（置顶）
        for a = 2, count do
            local k = notes[a]
            local b = a - 1
            while b >= 1 do
                local prev = notes[b]
                local swap = false
                if (prev.date or '') > (k.date or '') then
                    swap = true
                elseif (prev.date or '') == (k.date or '')
                    and prev.src ~= 'auto' and k.src == 'auto' then
                    swap = true
                end
                if not swap then break end
                notes[b + 1] = prev
                b = b - 1
            end
            notes[b + 1] = k
        end
        writeAll()
        layout()
        log('自动生成主题便签 ' .. added .. ' 条')
    end
end

function clearAllSkips()
    -- 配置变更后：清抑制 + 清掉旧的自动便签，让它们按新规则重生成
    autoskips = {}
    local keep = {}
    for i = 1, count do
        if notes[i].src ~= 'auto' then keep[#keep + 1] = notes[i] end
    end
    notes = keep
    count = #notes
    sel = -1
    editIdx = -1
    writeAll()
    autoGen()
    layout()
end

function editCity()
    editMode = 2
    editIdx = -1
    openBox(rnd(28 * scale), rnd(34 * scale), rnd(200 * scale), rnd(22 * scale), SKIN:GetVariable('city') or '')
end

function menuCity() editCity() end
-- 清除当前可见日期的「不再自动生成」标记，并立即补齐
function clearSkip()
    for c = 1, cols do
        autoskips[colDate(c)] = nil
    end
    writeAll()
    autoGen()
    layout()
    SKIN:Bang('!Log', 'clearSkip: 已恢复可见日期的自动便签', 'Notice')
end

function menuCity1() SKIN:Bang('!CommandMeasure', 'WeatherLua', "lookup('北京')") end
function menuCity2() SKIN:Bang('!CommandMeasure', 'WeatherLua', "lookup('大同')") end
function menuCity3() SKIN:Bang('!CommandMeasure', 'WeatherLua', "lookup('太原')") end
function menuCity4() SKIN:Bang('!CommandMeasure', 'WeatherLua', "lookup('上海')") end
function menuCity5() SKIN:Bang('!CommandMeasure', 'WeatherLua', "lookup('广州')") end
function menuCity6() SKIN:Bang('!CommandMeasure', 'WeatherLua', "lookup('成都')") end
function dumpLunar()
    local f = io.open(resDir() .. 'lunar_debug.txt', 'wb')
    local names = { 'LunarDate', 'LunarFest', 'LunarTerm', 'LunarFirst', 'LunarLast' }
    for _, n in ipairs(names) do
        local m = SKIN:GetMeasure(n)
        f:write(n .. '=[' .. tostring(m and m:GetStringValue()) .. ']' .. '\r\n')
    end
    for d = 1, 5 do
        local m = SKIN:GetMeasure('CN' .. d)
        f:write('CN' .. d .. '=[' .. tostring(m and m:GetStringValue()) .. ']' .. '\r\n')
    end
    f:write('Y=' .. tostring(SKIN:GetVariable('Y')) .. ' M=' .. tostring(SKIN:GetVariable('M')) .. ' D=' .. tostring(SKIN:GetVariable('D')) .. '\r\n')
    f:close()
end
function dumpCN24()
    local m = SKIN:GetMeasure('CN24')
    local v = m and m:GetStringValue() or ''
    local f = io.open(resDir() .. 'cn24_debug.txt', 'wb')
    local hex = {}
    for i = 1, #v do hex[#hex+1] = string.format('%02X', string.byte(v, i)) end
    f:write(v .. '\r\n' .. table.concat(hex, ' ') .. '\r\nfest=' .. tostring(isFestivalText(v)))
    f:close()
end
function dumpRight()
    for _, n in ipairs({ 'WeatherText', 'LunarLine', 'ClockText' }) do
        local m = SKIN:GetMeter(n)
        if m then
            local x = m:GetX(true) or -1
            local y = m:GetY(true) or -1
            local ww = nil
            local ok, v = pcall(function() return m:GetW() end)
            if ok then ww = v end
            SKIN:Bang('!Log', string.format('RIGHT %s x=%s y=%s w=%s align=%s text=%s', n, tostring(x), tostring(y), tostring(ww), tostring(m:GetOption('StringAlign')), tostring(m:GetOption('Text'))), 'Notice')
        end
    end
end
local WX = { ww = 0, wl = 0, sW = 1, sL = 1 }

local function charCount(s)
    local i, n = 1, 0
    while i <= #s do
        local b = string.byte(s, i)
        if b and b >= 0xA1 then
            local b2 = string.byte(s, i + 1)
            if b2 and b2 >= 0xA1 then i = i + 2 else i = i + 1 end
        else
            i = i + 1
        end
        n = n + 1
    end
    return n
end

local function sliceGBK(s, startChar, lenChar)
    local i, n = 1, 0
    while i <= #s and n < startChar - 1 do
        local b = string.byte(s, i)
        if b and b >= 0xA1 and string.byte(s, i + 1) and string.byte(s, i + 1) >= 0xA1 then i = i + 2 else i = i + 1 end
        n = n + 1
    end
    local from = i
    local cnt = 0
    while i <= #s and cnt < lenChar do
        local b = string.byte(s, i)
        if b and b >= 0xA1 and string.byte(s, i + 1) and string.byte(s, i + 1) >= 0xA1 then i = i + 2 else i = i + 1 end
        cnt = cnt + 1
    end
    return s:sub(from, i - 1)
end

local function estimateW(s, fs)
    s = tostring(s or '')
    local han, half, punct = 0, 0, 0
    local i = 1
    while i <= #s do
        local b = string.byte(s, i)
        if b and b >= 0xA1 and string.byte(s, i + 1) and string.byte(s, i + 1) >= 0xA1 then
            han = han + 1; i = i + 2
        elseif b == 32 then
            punct = punct + 1; i = i + 1
        elseif b and ((b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122)) then
            half = half + 1; i = i + 1
        else
            punct = punct + 1; i = i + 1
        end
    end
    return (han * 1.30 + half * 0.62 + punct * 0.68) * (fs or 9)
end

function marqueeMeasure()
    local fs = rnd(9 * scale)
    local tW = tostring(SKIN:GetVariable('weatherText') or '')
    local tL = tostring(SKIN:GetVariable('lunarText') or '')
    WX.ww = estimateW(tW, fs)
    WX.wl = estimateW(tL, fs)
    marqueeApply()
end

local function bandGeometry()
    local w = tonumber(SKIN:GetVariable('SW')) or 560
    local mw = tonumber(SKIN:GetVariable('mw')) or 180
    local calRight = rnd(194 * scale)
    local bandW = rnd(mw * scale)
    local tries = 0
    while (w - rnd(28 * scale) - bandW) < calRight + rnd(12 * scale) and tries < 2 do
        mw = mw - 10
        bandW = rnd(mw * scale)
        tries = tries + 1
    end
    return w - rnd(16 * scale) - bandW, bandW
end

local function fitChars(full, bandW)
    local n = charCount(full)
    local m = n
    while m > 2 and estimateW(sliceGBK(full, 1, m)) > bandW - 8 do m = m - 1 end
    return n, m
end

function marqueeApply()
    local bandX, bandW = bandGeometry()
    local fs = rnd(9 * scale)
    local gap = '   ·   '

    -- 两端各留 LP/RP 像素做渐隐；文字区（LP..LP+bandW）完全在渐隐区之外
    local LP = rnd(10 * scale)
    local RP = rnd(13 * scale)
    local totalW = LP + bandW + RP
    setOpt('RightClip', 'X', bandX - LP)
    setOpt('RightClip', 'Y', rnd(66 * scale))
    setOpt('RightClip', 'Shape', 'Rectangle 0,0,' .. totalW .. ',' .. rnd(68 * scale) .. ' | StrokeWidth 0 | Fill LinearGradient 1')
    -- 手册：0=右到左, 90=下到上, 180=左到右, 270=上到下；水平渐隐用 180
    setOpt('RightClip', '1', '180 | 72,87,150,0;0'
        .. ' | 72,87,150,255;' .. string.format('%.4f', LP / totalW)
        .. ' | 72,87,150,255;' .. string.format('%.4f', 1 - RP / totalW)
        .. ' | 72,87,150,0;1')
    show('RightClip')
    show('LunarLine')

    local rows = {
        { name = 'WeatherText', y = 0,                 text = tostring(SKIN:GetVariable('weatherText') or ''), a = 'aW', st = 'stW' },
        { name = 'LunarLine',   y = rnd(16 * scale),   text = tostring(SKIN:GetVariable('lunarText') or ''),   a = 'aL', st = 'stL' }
    }

    for _, r in ipairs(rows) do
        local unit = r.text .. gap
        -- 用隐藏的实测量米特取真实像素宽，避免估算误差
        setOpt('RowMeasure', 'FontSize', fs)
        setOpt('RowMeasure', 'Text', r.text)
        SKIN:Bang('!UpdateMeter', 'RowMeasure')
        local textW = math.max(1, rnd(SKIN:GetMeter('RowMeasure'):GetW()))
        setOpt('RowMeasure', 'Text', unit)
        SKIN:Bang('!UpdateMeter', 'RowMeasure')
        local unitW = math.max(1, rnd(SKIN:GetMeter('RowMeasure'):GetW()))
        setOpt(r.name, 'Container', 'RightClip')
        setOpt(r.name, 'Y', r.y)
        setOpt(r.name, 'FontSize', fs)
        setOpt(r.name, 'W', bandW)
        setOpt(r.name, 'ClipString', '0')
        if textW <= bandW - 6 then
            WX[r.a] = 0
            WX[r.st] = 0
            setOpt(r.name, 'StringAlign', 'RightTop')
            setOpt(r.name, 'X', LP + bandW - RP)
            setOpt(r.name, 'Text', r.text)
        else
            WX[r.a] = 1
            local off = (tonumber(WX[r.st]) or 0) % unitW
            WX[r.st] = off
            setOpt(r.name, 'StringAlign', 'LeftTop')
            setOpt(r.name, 'X', LP + bandW - RP - off)
            setOpt(r.name, 'Text', unit .. unit .. unit)
        end
    end

    SKIN:Bang('!UpdateMeter', 'WeatherText')
    SKIN:Bang('!UpdateMeter', 'LunarLine')
    SKIN:Bang('!Redraw')
end

-- ★ 的呼吸效果：FontColor 里的节变量在 String 上不刷新，改由 Lua 每 tick 设置
function favPulseTick()
    if FAVUI and FAVUI.dimTop then return end
    local a = math.floor(165 + 90 * math.sin(os.clock() * 2 * math.pi / 3.2))
    if a < 75 then a = 75 elseif a > 255 then a = 255 end
    setOpt('FavBtn', 'FontColor', '205,195,255,' .. a)
    SKIN:Bang('!UpdateMeter', 'FavBtn')
end

function marqueeAdvance()
    local step = math.max(1, rnd(2 * scale))
    local moved = false
    if WX.aW == 1 then WX.stW = (tonumber(WX.stW) or 0) + step; moved = true end
    if WX.aL == 1 then WX.stL = (tonumber(WX.stL) or 0) + step; moved = true end
    if moved then marqueeApply() end
end
function dumpMarquee()
    SKIN:Bang('!Log', string.format('MARQ ww=%s wl=%s SW=%s dxW=%s dxL=%s', tostring(WX.ww), tostring(WX.wl), tostring(SKIN:GetVariable('SW')), tostring(WX.dxW), tostring(WX.dxL)), 'Notice')
end
function wincheck()
    local skinW = tonumber(SKIN:GetVariable('SW')) or 560
    local names = { 'Panel', 'TitleText', 'WeatherText', 'LunarLine', 'ClockText', 'DateText', 'NewZone', 'NewZoneText', 'NewZoneHint', 'Handle', 'CalMarks', 'TopDivider', 'GhostCard', 'SelRing', 'DropHint' }
    for _, n in ipairs(names) do
        local m = SKIN:GetMeter(n)
        if m then
            local x = m:GetX(true) or 0
            local y = m:GetY(true) or 0
            local ww = 0
            local ok, v = pcall(function() return m:GetW() end)
            if ok and tonumber(v) then ww = tonumber(v) end
            local sum = x + ww
            if sum > skinW then
                SKIN:Bang('!Log', string.format('WINCHK %s x=%s w=%s sum=%s skinW=%s vis=%s', n, tostring(x), tostring(ww), tostring(sum), tostring(skinW), tostring(m:GetOption('Hidden'))), 'Notice')
            end
        end
    end
end
function diagAuto()
end
function diagW()
    local m, cw, gx, hd, gy, bt, ch = metrics()
end
function dumpMq()
    SKIN:Bang('!Log', string.format('MQ ww=%s wl=%s aW=%s aL=%s offW=%s offL=%s wtext=[%s]', tostring(WX.ww), tostring(WX.wl), tostring(WX.aW), tostring(WX.aL), tostring(WX.offW), tostring(WX.offL), tostring(SKIN:GetVariable('weatherText'))), 'Notice')
end

-- 预览：把右栏两行替换成长文本，观察滚动与渐隐
function previewLong()
    local w = '大同 6° 晴 · 明天小雨 4~11° · 后天多云转晴 3~13° · 西北风 4 级 · 湿度 46% · 空气质量 良 · 紫外线中等'
    local l = '农历九月十五 · 霜降 · 重阳节 · 世界卒中日 · 宜出行 忌动土 · 冲兔煞东 · 值神金匮'
    SKIN:Bang('!SetVariable', 'weatherText', w)
    SKIN:Bang('!SetVariable', 'lunarText', l)
    WX.ww = estimateW(w, rnd(9 * scale))
    WX.wl = estimateW(l, rnd(9 * scale))
    marqueeApply()
end

-- ===== 收藏库 =====
local FAV_FILE, FAV_ALT
local function favPaths()
    local d = resDir()
    FAV_FILE = d .. 'favorites.txt'
    FAV_ALT = d .. 'favorites_alt.txt'
end
pcall(favPaths)

local FAV_MAX = 50
local FAV_PER = 6
local favorites = nil
local favPage = 0
local favOpen = false
FAVUI = { ui = 'normal', hover = -1, rect = {} }

function boardLocked()
    return favOpen
end

local function favFile()
    if not FAV_FILE then pcall(favPaths) end
    return FAV_FILE or FAV_ALT
end

local function favRead()
    local f = favFile()
    local data = f and readFile(f) or ''
    local list = {}
    for line in tostring(data):gmatch('[^\r\n]+') do
        if not line:match('^#') then
            local nm, tx, th, at = line:match('^([^\t]*)\t([^\t]*)\t(%d)\t?(.*)$')
            if nm and nm ~= '' then
                list[#list + 1] = { name = nm, text = tx, theme = tonumber(th) or 1, at = at }
            end
        end
    end
    return list
end

local function favWrite(list)
    local f = favFile()
    local out = { '#FatFishNote favorites v1' }
    for _, v in ipairs(list) do
        out[#out + 1] = v.name .. '\t' .. v.text .. '\t' .. tostring(v.theme or 1) .. '\t' .. (v.at or '')
    end
    if f then
        local fd = io.open(f, 'wb')
        if fd then
            fd:write(table.concat(out, '\r\n') .. '\r\n')
            fd:close()
        end
    end
    favorites = list
end

function favLoad()
    if not favorites then favorites = favRead() end
    return favorites
end

function favCount() return #favLoad() end

local function favHideAll()
    hide('FavMask'); hide('FavPanel'); hide('FavTitle'); hide('FavHint')
    hide('FavPrev'); hide('FavNext'); hide('FavClose'); hide('FavEmpty'); hide('FavBlocker')
    for i = 0, FAV_PER - 1 do
        hide('FavShape' .. i); hide('FavText' .. i)
    end
end


-- 遮罩与拦截层跟随当前窗口尺寸（新建列导致窗口变宽时调用）
function favMaskFit()
    local w = tonumber(SKIN:GetVariable('SW')) or 560
    local h = tonumber(SKIN:GetVariable('SH')) or 380
    setOpt('FavMask', 'X', 0); setOpt('FavMask', 'Y', 0)
    setOpt('FavMask', 'Shape', 'Rectangle 0,0,' .. (w - 1) .. ',' .. (h - 1) .. ',' .. rnd(16 * scale) .. ' | Fill Color 8,10,18,170 | StrokeWidth 0')
    setOpt('FavBlocker', 'X', 0); setOpt('FavBlocker', 'Y', 0)
    setOpt('FavBlocker', 'W', w); setOpt('FavBlocker', 'H', h)
    SKIN:Bang('!UpdateMeter', 'FavMask')
    SKIN:Bang('!UpdateMeter', 'FavBlocker')
end

function favRender()
    local w = tonumber(SKIN:GetVariable('SW')) or 560
    local h = tonumber(SKIN:GetVariable('SH')) or 380
    local list = favLoad()
    local pages = math.max(1, math.ceil(#list / FAV_PER))
    if favPage > pages - 1 then favPage = pages - 1 end
    if favPage < 0 then favPage = 0 end

    if FAVUI.hover < 0 then
        hide('SelRing')
        for k = 1, 4 do hide('Sw_' .. k) end
    end
    local shown = math.min(FAV_PER, math.max(0, #list - favPage * FAV_PER))
    local pw = math.min(rnd(380 * scale), w - rnd(48 * scale))
    local rowH = rnd(44 * scale)
    local ph = rnd(74 * scale) + math.max(1, shown) * rowH + rnd(30 * scale)
    if #list == 0 then ph = rnd(140 * scale) end
    local px = rnd((w - pw) / 2)
    local py = rnd((h - ph) / 2)
    FAVUI.panel = { x = px, y = py, w = pw, h = ph }

    show('FavBlocker')
    favMaskFit()
    show('FavMask')

    setOpt('FavPanel', 'X', px); setOpt('FavPanel', 'Y', py)
    setOpt('FavPanel', 'Shape', 'Rectangle 0,0,' .. pw .. ',' .. ph .. ',' .. rnd(14 * scale)
        .. ' | Fill Color 30,34,54,250 | StrokeWidth 1 | Stroke Color 176,158,255,70')
    show('FavPanel')

    setOpt('FavTitle', 'X', px + rnd(18 * scale)); setOpt('FavTitle', 'Y', py + rnd(16 * scale))
    setOpt('FavTitle', 'FontSize', rnd(11 * scale))
    setOpt('FavTitle', 'Text', '收藏 · ' .. #list .. ' 条')
    show('FavTitle')

    setOpt('FavClose', 'X', px + pw - rnd(20 * scale)); setOpt('FavClose', 'Y', py + rnd(18 * scale))
    setOpt('FavClose', 'FontSize', rnd(10 * scale))
    show('FavClose')

    setOpt('FavHint', 'X', px + pw / 2); setOpt('FavHint', 'Y', py + ph - rnd(20 * scale))
    setOpt('FavHint', 'FontSize', rnd(7 * scale))
    setOpt('FavHint', 'Text', '点击恢复 · 右键删除 · 点空白关闭')
    show('FavHint')

    if #list == 0 then
        setOpt('FavEmpty', 'X', px + pw / 2); setOpt('FavEmpty', 'Y', py + ph / 2)
        setOpt('FavEmpty', 'FontSize', rnd(9 * scale))
        setOpt('FavEmpty', 'Text', '还没有收藏的便签')
        show('FavEmpty')
    else
        hide('FavEmpty')
    end

    for i = 0, FAV_PER - 1 do
        local idx = favPage * FAV_PER + i + 1
        local it = list[idx]
        if it then
            local ry = py + rnd(52 * scale) + i * rowH
            local rw = pw - rnd(24 * scale)
            local rh = rowH - rnd(6 * scale)
            FAVUI.rect[i] = { x = px + rnd(12 * scale), y = ry, w = rw, h = rh,
                              theme = clamp(tonumber(it.theme) or 1, 1, 4) }
            local th = THEMES[FAVUI.rect[i].theme]
            setOpt('FavShape' .. i, 'X', FAVUI.rect[i].x); setOpt('FavShape' .. i, 'Y', ry)
            setOpt('FavShape' .. i, 'Shape', 'Rectangle 0,0,' .. rw .. ',' .. rh
                .. ',' .. rnd(8 * scale) .. ' | Fill Color ' .. th.card .. ' | StrokeWidth 1 | Stroke Color ' .. th.stroke .. ')')
            show('FavShape' .. i)
            local label = 'FavText' .. i
            setOpt(label, 'X', FAVUI.rect[i].x + rnd(10 * scale)); setOpt(label, 'Y', ry + rnd(5 * scale))
            setOpt(label, 'W', rw - rnd(16 * scale))
            setOpt(label, 'H', rh - rnd(8 * scale))
            setOpt(label, 'FontSize', rnd(8 * scale))
            setOpt(label, 'FontColor', th.head)
            setOpt(label, 'ClipString', '1')
            setOpt(label, 'Text', '[' .. it.name .. ']' .. '\n' .. it.text)
            show(label)
        else
            hide('FavShape' .. i); hide('FavText' .. i)
        end
    end

    if pages > 1 then
        setOpt('FavPrev', 'X', px + pw - rnd(64 * scale)); setOpt('FavPrev', 'Y', py + rnd(18 * scale))
        setOpt('FavPrev', 'Text', '▲'); setOpt('FavPrev', 'FontSize', rnd(9 * scale))
        setOpt('FavPrev', 'FontColor', favPage > 0 and '235,238,245,230' or '235,238,245,70')
        show('FavPrev')
        setOpt('FavNext', 'X', px + pw - rnd(46 * scale)); setOpt('FavNext', 'Y', py + rnd(18 * scale))
        setOpt('FavNext', 'Text', '▼'); setOpt('FavNext', 'FontSize', rnd(9 * scale))
        setOpt('FavNext', 'FontColor', favPage < pages - 1 and '235,238,245,230' or '235,238,245,70')
        show('FavNext')
    else
        hide('FavPrev'); hide('FavNext')
    end

    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Redraw')
end

function placeFavSwatches(i)
    -- 只负责摆位置（不显示）；显示与更新由调用方统一批量做
    local r = FAVUI.rect[i]
    if not r then return end
    local rad = math.max(3, rnd(7 * scale))
    for k = 1, 4 do hide('Sw_' .. k) end
    for k = 1, 4 do
        local n = 'Sw_' .. k
        setOpt(n, 'Shape', 'Ellipse ' .. rad .. ',' .. rad .. ',' .. rad .. ',' .. rad
            .. ' | Fill Color ' .. SWATCH_COLORS[k] .. ',255 | StrokeWidth 0')
        setOpt(n, 'X', r.x + r.w - rnd((24 + 18 * (5 - k)) * scale) - rad)
        setOpt(n, 'Y', r.y + rnd(10 * scale) - rad)
    end
end

function hoverFav(i)
    if not favOpen then return end
    -- 面板刚打开的 0.35 秒内忽略悬浮（鼠标多半已经压在某个条目上），
    -- 之后正常响应，不再吞掉用户的第一次移动
    if FAVUI.skipUntil and os.clock() < FAVUI.skipUntil then return end
    i = tonumber(i) or 0
    local r = FAVUI.rect[i]
    if not r then return end
    FAVUI.hover = i
    local th = THEMES[clamp(r.theme or 1, 1, 4)]
    local inset = rnd(2 * scale)
    -- 1) 先藏
    hide('SelRing')
    for k = 1, 4 do hide('Sw_' .. k) end
    -- 2) 再改几何
    setOpt('SelRing', 'X', r.x - inset); setOpt('SelRing', 'Y', r.y - inset)
    setOpt('SelRing', 'Shape', 'Rectangle 0,0,' .. (r.w + inset * 2) .. ',' .. (r.h + inset * 2)
        .. ',' .. rnd(10 * scale) .. ' | Fill Color 0,0,0,0 | StrokeWidth ' .. math.max(1, rnd(2 * scale))
        .. ' | Stroke Color ' .. th.accent .. ',255')
    placeFavSwatches(i)
    -- 3) 批量更新一次，再统一显示
    SKIN:Bang('!UpdateMeter', '*')
    show('SelRing')
    for k = 1, 4 do show('Sw_' .. k) end
    SKIN:Bang('!Redraw')
end

function leaveFav()
    FAVUI.hover = -1
    for k = 1, 4 do hide('Sw_' .. k) end
    hide('SelRing')
    SKIN:Bang('!Redraw')
end

function setFavTheme(k)
    if not favOpen or not FAVUI.hover or FAVUI.hover < 0 then return end
    local list = favLoad()
    local idx = favPage * FAV_PER + FAVUI.hover + 1
    if not list[idx] then return end
    list[idx].theme = clamp(tonumber(k) or 1, 1, 4)
    favWrite(list)
    favRender()
    hoverFav(FAVUI.hover)
end

function favIsOpen() return favOpen end

-- ===== 收藏拖出：拖到列 = 恢复，拖到新建框 = 直接删除 =====
local 
-- 靠近窗口右边缘时，把落点推到「下一列」，不用精确越过列边界
function favEdgeX(x)
    local w = tonumber(SKIN:GetVariable('SW')) or 560
    if x and x > w - rnd(40 * scale) then
        local margin, cardW, gapX = metrics()
        return margin + cols * (cardW + gapX) + rnd(4)
    end
    return x
end

function favZoneHit(x, y)
    local z = lastZone
    return z and x >= z.x and x <= z.x + z.w and y >= z.y and y <= z.y + z.h
end

local 
-- 新建区恢复成默认样式（颜色 + 文字），关闭面板和结束拖拽都要调
function newZoneReset()
    if not lastZone then return end
    -- 面板开着时保持压暗，别把颜色顶回高亮
    local dim = FAVUI and FAVUI.dimTop
    local strokeA = dim and 12 or 30
    local textA = dim and 90 or 255
    setOpt('NewZone', 'Shape', 'Rectangle 0,0,' .. lastZone.w .. ',' .. lastZone.h .. ',6 | Fill Color 0,0,0,1 | StrokeWidth 1 | Stroke Color 255,255,255,' .. strokeA)
    setOpt('NewZoneText', 'Text', '拖出新便签')
    setOpt('NewZoneText', 'FontColor', '235,238,245,' .. textA)
    SKIN:Bang('!UpdateMeter', 'NewZone')
    SKIN:Bang('!UpdateMeter', 'NewZoneText')
end

function favZonePaint(active)
    if active then
        setOpt('NewZone', 'Shape', 'Rectangle 0,0,' .. lastZone.w .. ',' .. lastZone.h .. ',6 | Fill Color 200,60,60,40 | StrokeWidth 2 | Stroke Color 255,90,90,240')
        setOpt('NewZoneText', 'Text', '直接删除')
        setOpt('NewZoneText', 'FontColor', '255,150,150,255')
    else
        newZoneReset()
    end
    SKIN:Bang('!UpdateMeter', 'NewZone')
    SKIN:Bang('!UpdateMeter', 'NewZoneText')
end

function favDragStart(i)
    if not favOpen then return end
    i = tonumber(i) or 0
    local r = FAVUI.rect[i]
    if not r then return end
    local list = favLoad()
    local idx = favPage * FAV_PER + i + 1
    local it = list[idx]
    if not it then return end
    FAVUI.drag = i
    FAVUI.grabDX = nil
    FAVUI.grabDY = nil
    FAVUI.originX = nil
    FAVUI.originY = nil
    FAVUI.visited = false
    FAVUI.moved = false
    FAVUI.dragText = it.text
    FAVUI.dragName = it.name
    setOpt('GhostCard', 'Shape', 'Rectangle 0,0,' .. rnd(160 * scale) .. ',' .. rnd(40 * scale) .. ',' .. rnd(6 * scale) .. ' | Fill Color 40,36,70,210 | StrokeWidth 1 | Stroke Color 176,158,255,170')
    setOpt('GhostName', 'Text', it.name)
    setOpt('GhostText', 'Text', it.text)
    setOpt('GhostName', 'X', lastDragX and (lastDragX - rnd(60 * scale)) or 200)
    setOpt('GhostName', 'Y', lastDragY and (lastDragY - rnd(30 * scale)) or 200)
    setOpt('GhostName', 'StringAlign', 'CenterCenter')
    setOpt('GhostName', 'FontSize', rnd(9 * scale))
    show('GhostCard'); show('GhostName')
    hide('GhostText')
    -- 起拖瞬间就把上面的新建区改成「直接删除」的红色态
    favZonePaint(true)
end

function dragFav(x, y)
    if not FAVUI.visited then
        FAVUI.originX, FAVUI.originY = x, y
        FAVUI.visited = true
    end
    local dx, dy = x - FAVUI.originX, y - FAVUI.originY
    if math.sqrt(dx * dx + dy * dy) > 8 then FAVUI.moved = true end
    -- 预览框固定贴在指针右下，位置只由指针决定，不受历史状态影响
    local r0 = FAVUI.rect[FAVUI.drag]
    local gw = r0 and r0.w or rnd(240 * scale)
    local gh = r0 and r0.h or rnd(50 * scale)
    local gx = x + rnd(12 * scale)
    local gy = y + rnd(12 * scale)
    local ex = favEdgeX(x)
    local z = favZoneHit(x, y)
    if z then
        favZonePaint(true)
        setOpt('GhostCard', 'Shape', 'Rectangle 0,0,' .. gw .. ',' .. gh .. ',' .. rnd(6 * scale) .. ' | Fill Color 60,30,40,210 | StrokeWidth 1 | Stroke Color 255,110,110,220')
        hide('DropHint')
        show('GhostCard'); show('GhostName'); show('GhostText')
        setOpt('GhostCard', 'X', gx); setOpt('GhostCard', 'Y', gy)
        setOpt('GhostName', 'X', gx + rnd(14 * scale)); setOpt('GhostName', 'Y', gy + rnd(8 * scale))
        setOpt('GhostText', 'X', gx + rnd(14 * scale)); setOpt('GhostText', 'Y', gy + rnd(40 * scale))
        SKIN:Bang('!UpdateMeter', 'GhostCard')
        SKIN:Bang('!UpdateMeter', 'GhostName')
        SKIN:Bang('!UpdateMeter', 'GhostText')
        SKIN:Bang('!Redraw')
        return
    end
    favZonePaint(true)
    setOpt('GhostCard', 'Shape', 'Rectangle 0,0,' .. gw .. ',' .. gh .. ',' .. rnd(6 * scale) .. ' | Fill Color 40,36,70,210 | StrokeWidth 1 | Stroke Color 176,158,255,170')
    local c, r, ok = targetCell(ex, y)
    if ok and (not c or c < 1) then
        layout()
        favMaskFit()
        c, r, ok = targetCell(ex, y)
    end
    if ok and c and c >= 1 then
        -- 和拖便签一致：高亮目标格，而不是整列
        local _, cardW = metrics()
        local hx, hy = slotPos(r, c)
        setOpt('DropHint', 'Shape', 'Rectangle 0,0,' .. cardW .. ',' .. cardH .. ',' .. rnd(12 * scale) .. ' | Fill Color 120,220,255,28 | StrokeWidth 2 | Stroke Color 120,220,255,190')
        setOpt('DropHint', 'X', hx); setOpt('DropHint', 'Y', hy)
        show('DropHint')
        SKIN:Bang('!UpdateMeter', 'DropHint')
        FAVUI.dropCol = c
    else
        hide('DropHint')
        FAVUI.dropCol = nil
    end
    setOpt('GhostCard', 'X', gx); setOpt('GhostCard', 'Y', gy)
    setOpt('GhostName', 'X', gx + rnd(14 * scale)); setOpt('GhostName', 'Y', gy + rnd(8 * scale))
    setOpt('GhostText', 'X', gx + rnd(14 * scale)); setOpt('GhostText', 'Y', gy + rnd(40 * scale))
    SKIN:Bang('!UpdateMeter', 'GhostCard')
    SKIN:Bang('!UpdateMeter', 'GhostName')
    SKIN:Bang('!UpdateMeter', 'GhostText')
    SKIN:Bang('!Redraw')
end

function favDrop(x, y)
    local i = FAVUI.drag
    if not i then return end
    x = tonumber(x) or lastDragX
    y = tonumber(y) or lastDragY
    SKIN:Bang('!CommandMeasure', 'MeasureMouse', 'Stop')
    hide('DropHint')
    hide('GhostCard'); hide('GhostName'); hide('GhostText')
    favZonePaint(false)
    FAVUI.drag = nil
    FAVUI.dropping = true          -- 落点计算期间仍算「拖拽中」，否则 buildColumns 会裁掉新列
    FAVUI.justDropped = os.clock()
    local list = favLoad()
    local idx = favPage * FAV_PER + i + 1
    local pnl = FAVUI.panel
    local inPanel = pnl and x and y and x >= pnl.x and x <= pnl.x + pnl.w and y >= pnl.y and y <= pnl.y + pnl.h
    if not FAVUI.moved or inPanel then
        -- 只是轻拖或在面板内松手：不改变收藏状态
        FAVUI.dropping = nil
        newZoneReset()
        if favOpen then favRender() end
        SKIN:Bang('!Redraw')
        return
    end
    if not list[idx] then favRender(); return end
    if x and y and favZoneHit(x, y) then
        favDelete(idx)                    -- 写回收记录后删除
    else
        local ex = favEdgeX(x or 0)
        local c, r, ok = targetCell(ex, y or 0)
        if ok and (not c or c < 1) then
            -- 刚建的列就是目标列；列宽会随列数变化，不能拿旧 ex 重算
            layout()
            favMaskFit()
            c = cols
            r = math.max(1, r or 1)
            ok = true
        end
        if ok and c and c >= 1 then
            favRestore(idx, colDate(c), r)   -- 落到目标列的那一格
        end
    end
    FAVUI.dropping = nil
    -- 落点确定后按「非拖拽」重排一次，让 buildColumns 裁掉尾部空列、窗口缩回去
    layout()
    favMaskFit()
    newZoneReset()
    if favOpen then favRender() end
    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Redraw')
end


-- 收藏面板打开时统一关掉底层米特的 tooltip（ToolTipHidden=1），关闭时恢复

-- 面板打开时，把位于遮罩之上的节点（新建区文字/边框、★）压成半透明，视觉上被盖住
function favDimTop(on)
    FAVUI.dimTop = on and true or false
    if on then
        setOpt('NewZoneText', 'FontColor', '235,238,245,90')
        setOpt('NewZoneHint', 'FontColor', '235,238,245,50')
        setOpt('FavBtn', 'FontColor', '205,195,255,90')
        setOpt('NewZone', 'Shape', 'Rectangle 0,0,' .. (lastZone and lastZone.w or 178) .. ',' .. (lastZone and lastZone.h or 44) .. ',6 | Fill Color 0,0,0,1 | StrokeWidth 1 | Stroke Color 255,255,255,12')
    else
        setOpt('NewZoneText', 'FontColor', '235,238,245,255')
        setOpt('NewZoneHint', 'FontColor', '235,238,245,110')
        setOpt('NewZone', 'Shape', 'Rectangle 0,0,' .. (lastZone and lastZone.w or 178) .. ',' .. (lastZone and lastZone.h or 44) .. ',6 | Fill Color 0,0,0,1 | StrokeWidth 1 | Stroke Color 255,255,255,30')
        setOpt('FavBtn', 'FontColor', '205,195,255,255')
    end
    for _, n in ipairs({ 'NewZone', 'NewZoneText', 'NewZoneHint', 'FavBtn' }) do
        SKIN:Bang('!UpdateMeter', n)
    end
end

function favTipsHidden(hide)
    local names = {}
    for i = 0, MAXN - 1 do
        names[#names + 1] = 'Name' .. i
        names[#names + 1] = 'Del' .. i
        names[#names + 1] = 'Text' .. i
    end
    for k = 1, 4 do names[#names + 1] = 'Sw_' .. k end
    names[#names + 1] = 'NewZone'
    names[#names + 1] = 'FavBtn'
    for _, n in ipairs(names) do
        local m = SKIN:GetMeter(n)
        if m then setOpt(n, 'ToolTipHidden', hide and '1' or '0') end
    end
    SKIN:Bang('!UpdateMeter', '*')
end

function favToggle()
    favOpen = not favOpen
    if favOpen then
        FAVUI.ui = 'fav'
        FAVUI.hover = -1
        FAVUI.skipUntil = os.clock() + 0.35
        -- 遮罩挡不住下层命中（实测），用 ToolTipHidden 统一关掉底层提示
        favTipsHidden(true)
        favDimTop(true)
        hoverIdx = -1
        for k = 1, 4 do hide('Sw_' .. k) end
        hide('SelRing')
        favRender()
    else
        FAVUI.ui = 'normal'
        FAVUI.drag = nil
        hideGhost(); hide('DropHint')
        newZoneReset()
        favTipsHidden(false)
        favDimTop(false)
        leaveFav()
        favHideAll()
        SKIN:Bang('!Redraw')
    end
end

function favClose()
    FAVUI.drag = nil
    hideGhost(); hide('DropHint')
    newZoneReset()
    favTipsHidden(false)
    favOpen = false
    FAVUI.hover = -1
    FAVUI.ui = 'normal'
    leaveFav()
    favHideAll()
    SKIN:Bang('!Redraw')
end

function favPageBy(d)
    favPage = favPage + (tonumber(d) or 0)
    favRender()
end

function favAdd(i)
    i = tonumber(i)
    if not i or not notes[i] then return false end
    local list = favLoad()
    if #list >= FAV_MAX then
        SKIN:Bang('!Log', '收藏库已满（' .. FAV_MAX .. '）', 'Notice')
        return false
    end
    local n = notes[i]
    list[#list + 1] = { name = n.name, text = n.text, theme = n.theme or 1, at = todayStr() }
    favWrite(list)
    table.remove(notes, i)
    count = #notes
    writeAll()
    layout()
    if favOpen then favRender() end
    return true
end

function favDelete(idx)
    idx = tonumber(idx)
    local list = favLoad()
    if not idx or not list[idx] then return end
    local it = list[idx]
    -- 删除前留一份回收记录，手误还能捞回来
    local f = favFile()
    if f then
        local delPath = f:gsub('favorites%.txt$', 'favorites_deleted.txt')
        local fd = io.open(delPath, 'ab')
        if fd then
            fd:write(os.date('%Y-%m-%d %H:%M:%S') .. '\t' .. it.name .. '\t' .. it.text .. '\t' .. tostring(it.theme or 1) .. '\r\n')
            fd:close()
        end
    end
    table.remove(list, idx)
    favWrite(list)
    favRender()
end

function favRestore(idx, date, row)
    idx = tonumber(idx)
    local list = favLoad()
    if not idx or not list[idx] then return end
    local it = table.remove(list, idx)
    date = date or todayStr()
    local note = { date = date, name = it.name, text = it.text, src = 'user', theme = it.theme or 1 }
    -- 指定了目标格就用 insertAt，和拖卡片落点一致
    if row then
        insertAt(date, tonumber(row) or 1, note)
    else
        local ins = #notes + 1
        for i = 1, #notes do
            if (notes[i].date or '') > date then ins = i break end
        end
        table.insert(notes, ins, note)
    end
    count = #notes
    favWrite(list)
    writeAll()
    layout()
    favRender()
end

function favClick(n)
    if (FAVUI.drag) then return end
    if FAVUI.justDropped and os.clock() - FAVUI.justDropped < 0.4 then return end
    local idx = favPage * FAV_PER + (tonumber(n) or 0) + 1
    favRestore(idx)
end

function favRight(n)
    local idx = favPage * FAV_PER + (tonumber(n) or 0) + 1
    favDelete(idx)
end
