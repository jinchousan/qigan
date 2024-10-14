local window = {}

local windowList = {}
local snackbarQueue = {}
local modalSlot = nil
local snackbarIntervalRemaining = 0

local _snackbarDuration = 3 -- 秒単位
local _snackbarInterval = 0.5 

function window.createWindow(x, y, width, height, foregroundColor, shadowColor)
    local w = window.plainWindow(x, y, width, height, foregroundColor, shadowColor)
    table.insert(windowList, w)
    return w, #windowList
end

function window.createSnackbar(x, y, width, height, foregroundColor, shadowColor)
    local s = window.snackbar(x, y, width, height, foregroundColor, shadowColor)
    table.insert(snackbarQueue, {snackbar=s, durationRemaining=_snackbarDuration})
    return s
end

function window.createModalWindow(x, y, width, height, foregroundColor, shadowColor)
    local m = window.modalWindow(x, y, width, height, foregroundColor, shadowColor)
    modalSlot = m
    return m
end

function window.update(dt)
    if (snackbarIntervalRemaining <= 0) then
        local sb = snackbarQueue[1]
        if (sb ~= nil) then
            if (sb.durationRemaining <= 0) then
                table.remove(snackbarQueue, 1)
                snackbarIntervalRemaining = _snackbarInterval
            else
                sb.durationRemaining = sb.durationRemaining - dt
            end
        end
    else
        snackbarIntervalRemaining = snackbarIntervalRemaining - dt
    end
end

function window.draw()
    if (modalSlot ~= nil) then modalSlot.draw() end

    for _,v in pairs(windowList) do
        v.draw()
    end

    if (snackbarIntervalRemaining <= 0) then
        local sb = snackbarQueue[1]
        if (sb ~= nil) then
            sb.snackbar.draw()
        end
    end
end

function window.keypressed(key, scancode, isrepeat)
    if (modalSlot ~= nil) then
        for k,v in pairs(modalSlot.keyHandlers) do
            if (k == key) then
                v()
                modalSlot = nil
                return true
            end
        end

        return true
    end

    return false
end

function window.removeWindow(wid)
    -- luaのgabage collectorに任せる
    windowList[wid] = nil
end

function window.plainWindow(x, y, width, height, foregroundColor, shadowColor)
    local self = {
        --- public field
        x = x,
        y = y,
        width = width,
        height = height,
        foregroundColor = foregroundColor,
        shadowColor = shadowColor
    }

    --- private field
    local drawables = {}
    local shadowOffset = 3

    function self.appendDrawable(innerX, innerY, drawable, color)
        local dw = {}
        dw.innerX = innerX
        dw.innerY = innerY
        dw.drawable = drawable
        if (color == nil) then
            dw.color = {0, 0, 0, 1}
        else
            dw.color = color
        end
        table.insert(drawables, dw)
    end

    function self.draw()
        -- 影の描写
        love.graphics.setColor(self.shadowColor)
        love.graphics.polygon("fill",
            self.x+shadowOffset, self.y+shadowOffset,
            self.x+self.width+shadowOffset, self.y+shadowOffset,
            self.x+self.width+shadowOffset, self.y+self.height+shadowOffset,
            self.x+shadowOffset, self.y+self.height+shadowOffset
        )

        -- フォアグラウンドの描写
        love.graphics.setColor(self.foregroundColor)
        love.graphics.polygon("fill",
            self.x, self.y,
            self.x+self.width, self.y,
            self.x+self.width, self.y+self.height,
            self.x, self.y+self.height
        )

        -- ウインドウ内の描写
        for _,v in pairs(drawables) do
            love.graphics.setColor(v.color)
            love.graphics.draw(v.drawable, self.x+v.innerX, self.y+v.innerY)
        end
    end

    return self
end

function window.snackbar(x, y, width, height, foregroundColor, shadowColor)
    local self = window.plainWindow(x, y, width, height, foregroundColor, shadowColor)

    return self
end

function window.modalWindow(x, y, width, height, foregroundColor, shadowColor)
    local self = window.plainWindow(x, y, width, height, foregroundColor, shadowColor)
    self.keyHandlers = {}

    function self.appendKeyHandler(key, handler)
        self.keyHandlers[key] = handler
    end

    return self
end

return window