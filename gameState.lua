local gameState = {}

local object = require("object")

-- モジュール内定数
local _playerInitialPositionX = 0
local _playerInitialPositionY = 0
local _sightRadius = 7
local _minHeight = 1
local _maxHeight = 5

-- モジュール内private field
local player = {}
local world = {}
local steps = 0
local qigans = {}
local foundQigans = {}
local poles = {}
local inventory = {}

function gameState.getPlayer()
    return player
end

function gameState.getWorld()
    return world
end

function gameState.getSteps()
    return steps
end

function gameState.getQigans()
    return qigans
end

function gameState.getFoundQigans()
    return foundQigans
end

function gameState.getPoles()
    return poles
end

function gameState.getInventory()
    return inventory
end

function gameState.load(state)
    player = object.player(state.player.posX, state.player.posY, state.player.direction)
    world = object.world(state.world.cords, state.world.size)
    steps = state.steps
    foundQigans = object.world(state.foundQigans.cords, state.foundQigans.size)
    poles = state.poles
    inventory = state.inventory

    gameState.makeStep(player.direction, 0)
end

function gameState.save()
    local state = {}
    state.player = {}
    state.player.posX = player.posX
    state.player.posY = player.posY
    state.player.direction = player.direction
    state.world = {}
    state.world.cords = world.trail
    state.world.size = world.getSize()
    state.steps = steps
    state.foundQigans = {}
    state.foundQigans.cords = foundQigans.trail
    state.foundQigans.size = foundQigans.getSize()
    state.poles = poles
    state.inventory = inventory
    return state
end

function gameState.makeStep(direction, distance)
    local windowEvents = {}

    player.direction = direction
    steps = steps + 1
    if (direction == "north") then
        player.posY = player.posY + distance
    elseif (direction == "south") then
        player.posY = player.posY - distance
    elseif (direction == "east") then
        player.posX = player.posX + distance
    elseif (direction == "west") then
        player.posX = player.posX - distance
    end

    local currentSight = gameState.createWorldIterationList(player.posX, player.posY, _sightRadius)

    -- 未踏の地を視界内に捉えている場合、chunkを起こしてマージする
    for _,v in pairs(currentSight) do
      if (world.getHeight(v.posX, v.posY) == nil) then
        world.mergeChunk(gameState.generatePanelChunk("random", player.posX, player.posY, _sightRadius))
      end
    end

    -- 視界内のパターン発見の処理
    for _,q in pairs(qigans) do
        for j = player.posY+_sightRadius, player.posY-_sightRadius+q.size, -1 do
            for i = player.posX-_sightRadius, player.posX+_sightRadius-q.size do
                if q.isMatched(world, i, j) and (poles[gameState.generateKey(i, j)] == nil) then
                    local sw, lum = gameState.scanWorldInPattern(world, q, i, j)
                    foundQigans.mergeWorld(sw)
                    local pl = {}
                    pl.posX = lum.posX
                    pl.posY = lum.posY
                    pl.name = q.name
                    pl.sw = sw
                    poles[gameState.generateKey(i, j)] = pl
                end
            end
        end
    end

    -- playerがpoleに到達したかどうかの判定処理
    for kp,p in pairs(poles) do
        if (player.posX == p.posX) and (player.posY == p.posY) then
            table.insert(windowEvents, {name=p.name, posX=p.posX, posY=p.posY, steps=steps})
            poles[kp] = nil
            if (inventory[p.name] == nil) then
                inventory[p.name] = 1
            else
                inventory[p.name] = inventory[p.name] + 1
            end
            for k,v in pairs(p.sw.trail) do
                world.trail[k] = math.random(_maxHeight)
                foundQigans.removePanelByKey(k)
            end
        end
    end

    return windowEvents
end

function gameState.setPanelsQiganByIntention(name, size, array, gap)
    local newQ = object.panelsQiganByIntention(name)
    newQ.setPattern(size, array, gap)
    table.insert(qigans, newQ)
    return newQ
end

function gameState.getInitialState()
    local state = {}
    state.player = {}
    state.player.posX = _playerInitialPositionX
    state.player.posY = _playerInitialPositionY
    state.player.direction = "north"
    state.world = {}
    state.world.cords = {}
    state.world.size = 0
    state.steps = 0
    state.foundQigans = {}
    state.foundQigans.cords = {}
    state.foundQigans.size = 0
    state.poles = {}
    state.inventory = {}
    return state
end

function gameState.getCurrentSight()
    return gameState.createWorldIterationList(player.posX, player.posY, _sightRadius)
end

function gameState.generateKey(posX, posY)
    return tostring(posX) .. "," .. tostring(posY)
end

function gameState.generatePanelChunk(mode, orgX, orgY, radius)
    local chunk = {}

    for i = orgX-radius, orgX+radius do
        for j = orgY-radius, orgY+radius do
            local h

            if (mode == "flat") then
                h = _minHeight
            elseif (mode == "random") then
                h = math.random(_maxHeight)
            else
                error("gameState->generateChunk | undefined mode: " .. mode)
            end
            table.insert(chunk, object.panel(i, j, h))
        end
    end

    return chunk
end

-- クオータービューにする際に必要となる描写順の調整までやる関数なので、本来ここにあってよいかどうかは...
function gameState.createWorldIterationList(orgX, orgY, radius)
    local l = {}
    local n = 2*radius + 1
    local m = 2*radius + 1

    for i = orgX+radius, orgX-radius, -1 do
        for j = orgY+radius, orgY-radius, -1 do
            local k = {}
            k.key = gameState.generateKey(i, j)
            k.posX = i
            k.posY = j
            k.dispX = n
            k.dispY = m
            table.insert(l, k)
            m = m - 1
        end
        n = n - 1
        m = 2*radius + 1
    end

    return l
end

function gameState.scanWorldInPattern(world, qigan, posX, posY)
    local subWorld = object.world()
    local m = 1
    local n = 1
    local lum = {}
    for j = posY, posY-(qigan.size-1), -1 do
        for i = posX, posX+(qigan.size-1) do
            if (string.match(qigan.pattern[n][m], "%d") ~= nil) or (string.match(qigan.pattern[n][m], "%l") ~= nil) then
                if (lum.posX == nil) then
                    lum.posX = i
                    lum.posY = j
                end
                subWorld.addPanel(world.getPanel(i, j))
            end
            m = m + 1
        end
        m = 1
        n = n + 1
    end
    return subWorld, lum
end

return gameState