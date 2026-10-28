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

function boot()
    local d = readFile(resDir() .. 'ui_state.txt') or ''
    local i = d:match('#imgpick%s+(%d+)') or d:match('imgpick=(%d+)') or '?'
    local name = d:match('#name%s+([^\r\n]+)') or ''
    local px, py = d:match('#pos%s+(%d+)%s+(%d+)')
    if px and py then
        SKIN:Bang('!Move', tonumber(px), tonumber(py))
    end
    SKIN:Bang('!ZPos', '1')
    SKIN:Bang('!SetOption', 'PickTitle', 'Text', '¸ø¡¸' .. (name ~= '' and name or '±ãÇ© ' .. i) .. '¡¹ÉèÖÃ')
    SKIN:Bang('!UpdateMeter', 'PickTitle')
    SKIN:Bang('!Redraw')
    log('open for note ' .. i .. ' / ' .. name)
end

function pick(name)
    local d = readFile(resDir() .. 'ui_state.txt') or ''
    local i = d:match('#imgpick%s+(%d+)') or d:match('imgpick=(%d+)')
    if not i then log('no target'); return end
    writeFile(resDir() .. 'imgpick_result.txt', i .. '\t' .. name .. '\r\n')
    log('result ' .. i .. ' -> ' .. name)
end

function close()
    SKIN:Bang('!DeactivateConfig')
end
