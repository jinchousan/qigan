local field = {}

local gameState = require("gameState")
local polygons = require("polygons")
local window = require("window")

-- クオータービューのように描画するためのサブルーチン
function drawPolygons(polygonsList, rotationZ, rotationX, offset)
  for _,p in ipairs(polygonsList) do
    local rvs = {}
    for _,v in ipairs(p.vertices) do
      rv = polygons.translate(polygons.rotateXAxis(polygons.rotateZAxis(v, rotationZ), rotationX), offset)
      table.insert(rvs, rv.x)
      table.insert(rvs, rv.y)
    end
    love.graphics.setColor(p.color)
    love.graphics.polygon("fill", rvs)
  end
end

function computeScore(table, inventory)
  local score = 0
  for k,v in pairs(inventory) do
    score = score + table[k]*v
  end
  return score - (gameState.getSteps() * 500)
end


-- ゲーム内定数の予告
local _rotationZ, _rotationX
local _offset

local _panelWidth, _panelHeight
local _panelTopColors, _panelLeftColor, _panelRightColor

local _playerWidth, _playerDepth, _playerHeight
local _playerTopColor, _playerBottomColor

local _flat2x2QiganPattern
local _flat2x2CommonPattern
local _ichimatsuPattern
local _totemPattern

local _rarityTable

local _foundQiganTopColor, _foundQiganLeftColor, _foundQiganRightColor

local _scrollInterval

local _poleWidth, _poleHeight, _poleLeftColor, _poleRightColor


-- ゲーム内グローバル変数の予告
local scrollOffset


function field.load()
  -- ゲーム内定数の定義
  _rotationZ = math.pi / 4
  _rotationX = - math.pi / 4

  _offset = polygons.vertex(630, 1260, 0)

  _panelWidth = 120
  _panelHeight = 20

  --- love 11.0以降、rgbaの各値のレンジは0~1になりました。
  _panelTopColors = {
    {0,  51/255, 0, 1},
    {0,  77/255, 0, 1},
    {0, 102/255, 0, 1},
    {0, 141/255, 0, 1},
    {0, 179/255, 0, 1}
  } -- 基本的に緑色だが、階層によって色分け。最高層(=5)が最も明るく、後はHSV相当で10%ずつ明度を落とした場合の値
  _panelLeftColor = {240/255, 190/255, 100/255, 1} -- うす茶色
  _panelRightColor = {140/255, 110/244, 60/255, 1} -- 茶色 （つまり左上に光源）

  _playerWidth = 60
  _playerDepth = 80
  _playerHeight = 10
  
  _playerTopColor = {1, 0, 0, 1} -- 真っ赤
  _playerBottomColor = {128/255, 0, 0, 1}

  --- Qiganの設定。この設定順は、そのままパターンマッチのときに発見の優先順位となる。
  _flat2x2QiganPattern = {{"-", "-", "-", "-"}, {"-", "a", "a", "-"}, {"-", "a", "a", "-"}, {"-", "-", "-", "-"}}
  local qs = gameState.setPanelsQiganByIntention("Significantly Flat", 4, _flat2x2QiganPattern)

  _flat2x2CommonPattern = {{"*", "~", "~", "*"}, {"~", "a", "a", "~"},  {"~", "a", "a", "~"}, {"*", "~", "~", "*"}}
  local qc = gameState.setPanelsQiganByIntention("Commonly Flat", 4, _flat2x2CommonPattern)

  _ichimatsuPattern = {{"_", "b", "_"},{"b", "_", "b"},{"_", "b", "_"}}
  local ic = gameState.setPanelsQiganByIntention("Ichimatsu", 3, _ichimatsuPattern)

  _totemPattern = {{"_", "_", "_"},{"_", "a", "_"}, {"_", "_", "_"}}
  local tp = gameState.setPanelsQiganByIntention("Totem", 3, _totemPattern, 3)
  
  _rarityTable = {}
  _rarityTable[qs.name] = qs.computeRarity()
  _rarityTable[qc.name] = qc.computeRarity()
  _rarityTable[ic.name] = ic.computeRarity()
  _rarityTable[tp.name] = tp.computeRarity()
 
  _foundQiganTopColor = {0 ,102/255,204/255, 1} -- 青
  _foundQiganLeftColor = {0, 128/255, 1, 1}
  _foundQiganRightColor = {51/255, 153/255, 1, 1}

  _scrollInterval = 0.5 -- updateのdtは秒単位なので

  _poleWidth = 40
  _poleHeight = 100
  _poleLeftColor = {0, 0, 1, 1}
  _poleRightColor = {0, 0, 204/255, 1}

  -- ゲームの初期化/ゲーム内グローバル変数の初期化
  gameState.load(gameState.getInitialState())
  scrollOffset = polygons.vertex(0, 0, 0)

end

function field.update(dt)
  -- フィールドをスクロールさせるための処理
  for _,v in ipairs({"x", "y", "z"}) do
    local c
    if (scrollOffset[v] > 0) then
      c = scrollOffset[v] - _panelWidth*(dt/_scrollInterval)
      if (c * scrollOffset[v] < 0) then -- つまり、符号が変わったなら
        scrollOffset[v] = 0
      else
        scrollOffset[v] = c
      end
    elseif (scrollOffset[v] < 0) then
      c = scrollOffset[v] + _panelWidth*(dt/_scrollInterval)
      if (c * scrollOffset[v] < 0) then -- つまり、符号が変わったなら
        scrollOffset[v] = 0
      else
        scrollOffset[v] = c
      end
    end
  end

  -- windowのupdate処理
  window.update(dt)
end

function field.draw()
  local foundQigans = gameState.getFoundQigans()
  local world = gameState.getWorld()
  local player = gameState.getPlayer()
  local poles = gameState.getPoles()
  local steps = gameState.getSteps()
 
  -- panelとplayerの描画処理
  for _,v in pairs(gameState.getCurrentSight()) do
    local panelPolygons
    local playerPolygons
    local topColor
    local leftColor
    local rightColor
    local polePolygons

    -- panelポリゴンの作成
    --- 通常のpanelか発見済みのqiganかで色を変えて表示する。
    local pnlHeight
    if (foundQigans.getHeight(v.posX, v.posY) ~= nil) then
      topColor = _foundQiganTopColor
      leftColor = _foundQiganLeftColor
      rightColor = _foundQiganRightColor
      pnlHeight = foundQigans.getHeight(v.posX, v.posY)
    else
      pnlHeight = world.getHeight(v.posX, v.posY)
      topColor = _panelTopColors[pnlHeight]
      leftColor = _panelLeftColor
      rightColor = _panelRightColor
    end
    panelPolygons = polygons.panel((v.dispX-1)*_panelWidth+scrollOffset.x, -((v.dispY-1)*_panelWidth+scrollOffset.y), 0, _panelWidth, pnlHeight*_panelHeight, topColor, leftColor, rightColor)
    drawPolygons(panelPolygons, _rotationZ, _rotationX, _offset)
    
    -- playerポリゴンの作成
    local pdispX
    local pdispY
    local pheight
    if (player.posX == v.posX and player.posY == v.posY) then
      pdispX = v.dispX
      pdispY = v.dispY
      pheight = world.getHeight(v.posX, v.posY)
      playerPolygons =  polygons.player(player.direction, (pdispX-1)*_panelWidth+scrollOffset.x, -((pdispY-1)*_panelWidth+scrollOffset.y), pheight*_panelHeight, _playerDepth, _playerWidth, _playerHeight, _playerTopColor, _playerBottomColor)
      drawPolygons(playerPolygons, _rotationZ, _rotationX, _offset)
    end

    -- poleポリゴンの作成
    for _,p in pairs(poles) do
      if (p.posX == v.posX and p.posY == v.posY) then
        polePolygons = polygons.pole((v.dispX-1)*_panelWidth+scrollOffset.x, -((v.dispY-1)*_panelWidth+scrollOffset.y), world.getHeight(v.posX, v.posY)*_panelHeight, _poleWidth, _poleHeight, _poleLeftColor, _poleRightColor)
        drawPolygons(polePolygons, _rotationZ, _rotationX, _offset)
      end
    end
  end

  -- デバッグ情報の表示
  --- このwindowの使い方は少し特殊。このようにdraw内で毎回内容がリフレッシュされるウインドウを表示したいときはこう書くと楽。
  local debugInfoTextString = " position: (%d, %d) \n direction: %s \n height: %d \n steps: %d \n world size: %d"
  local debugInfoTextFont = love.graphics.newFont(14)
  local debugInfoText = love.graphics.newText(
    debugInfoTextFont,
    string.format(debugInfoTextString, player.posX, player.posY, player.direction, world.getHeight(player.posX, player.posY), steps, world.getSize())
  )
  local debugInfoWindow = window.plainWindow(10, 10, 200, 100, {1, 1, 1, 1}, {0, 0, 0, 1})
  debugInfoWindow.appendDrawable(3, 3, debugInfoText)
  debugInfoWindow.draw()

  -- 現在スコアの表示
  local scoreFont = love.graphics.newFont(30)
  local scoreWindow = window.plainWindow(870, 10, 400, 40, {1, 1, 0, 1}, {0, 0, 0, 1})
  scoreWindow.appendDrawable(3, 3, love.graphics.newText(scoreFont, "Your Score: " .. computeScore(_rarityTable, gameState.getInventory())), {0,0,0,1})
  scoreWindow.draw()

  -- windowのdraw処理
  window.draw()

end

function field.keypressed(key, scancode, isrepeat)
  local windowEvents = {}

  if (not window.keypressed(key, scancode, isrepeat)) then
    if (key == "w") then
      windowEvents = gameState.makeStep("north", 1)
      scrollOffset.y = _panelWidth
    elseif (key == "s") then
      windowEvents = gameState.makeStep("south", 1)
      scrollOffset.y = -_panelWidth
    elseif (key == "d") then
      windowEvents = gameState.makeStep("east", 1)
      scrollOffset.x = _panelWidth
    elseif (key == "a") then
      windowEvents = gameState.makeStep("west", 1)
      scrollOffset.x = -_panelWidth
    elseif (key == "f") then
      local qw = window.createModalWindow(30, 30, 1220, 660, {1, 1, 1, 1}, {0, 0, 0, 1})
      qw.appendKeyHandler("escape", function () end) -- つまり何もしないで閉じる
      local font = love.graphics.newFont(30)
      local i = 1
      for k,v in pairs(gameState.getInventory()) do
        local qwtext = love.graphics.newText(font, string.format("%s [Rarity = %d] : %d pc(s)", k, _rarityTable[k], v))
        qw.appendDrawable(10, 10+30*(i-1), qwtext, {0, 0, 0, 1})
        i = i + 1
      end
      if (i == 1) then -- つまり、インベントリが空だったら
        local qwtext = love.graphics.newText(font, "It seems nothing has been found.")
        qw.appendDrawable(10, 10, qwtext, {0, 0, 0, 1})
      end
    elseif (key == "escape") then
      local qd = window.createModalWindow(500, 300, 280, 120, {1, 1, 1, 1}, {0, 0, 0, 1})
      qd.appendKeyHandler("escape", function () end)
      qd.appendKeyHandler("y", function() 
        love.event.quit()
      end)
      local font = love.graphics.newFont(20)
      qd.appendDrawable(10, 10, love.graphics.newText(font, "Do you really quit?\n(Yes = y, No = Esc)"), {0, 0, 0, 1})
    end
  end

  for _,v in pairs(windowEvents) do
    local sb = window.createSnackbar(10, 660, 1260, 50, {1, 178/255, 102/255, 1}, {51/255, 25/255, 0, 1})
    local font = love.graphics.newFont(30)
    local sbText = love.graphics.newText(font, string.format("You found a \"%s\" at (%d, %d) in %d steps!", v.name, v.posX, v.posY, v.steps))
    sb.appendDrawable(3, 3, sbText, {0, 0, 0, 1})
  end
end

return field