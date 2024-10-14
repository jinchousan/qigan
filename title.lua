local title = {}

local window = require("window")

function title.load(nextState)
    local titleWindow = window.createModalWindow(200, 200, 880, 320, {1,1,1,1}, {0,0,0,1})
    local titleFont = love.graphics.newFont(40)
    local titleText = love.graphics.newText(titleFont, "Qigan")
    local promptFont = love.graphics.newFont(20)
    local promptText = love.graphics.newText(promptFont, "press space key to start")
    titleWindow.appendDrawable(10, 10, titleText, {0,0,0,1})
    titleWindow.appendDrawable(10, 100, promptText, {0,0,0,1})
    titleWindow.appendKeyHandler("space", function ()
        currentState = nextState
    end)
end

function title.draw()
    window.draw()
end

function title.update(dt)
    window.update(dt)
end

function title.keypressed(key, scancode, isrepeat)
    window.keypressed(key, scancode, isrepeat)
end

return title