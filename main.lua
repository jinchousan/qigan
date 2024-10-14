local field = require("field")
local title = require("title")
currentState = title

function love.load()
    -- ゲーム画面の設定
    love.window.setMode(1280, 720)
    love.window.setTitle("Qigan")

    field.load()
    title.load(field)
end

function love.update(dt)
    currentState.update(dt)
end

function love.draw()
    currentState.draw()
end

function love.keypressed(key, scancode, isrepeat)
    currentState.keypressed(key, scancode, isrepeat)
end