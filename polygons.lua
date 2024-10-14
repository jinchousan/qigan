local polygons = {}

function polygons.translate(vertex, moving)
  local a = polygons.vertex(0, 0, 0)
  for k, v in pairs({"x", "y", "z"}) do
    a[v] = vertex[v] + moving[v]
  end
  return a
end

function polygons.rotateZAxis(vertex, rotation)
  local a = polygons.vertex(0, 0, 0)
  a.x = vertex.x * math.cos(rotation) + vertex.y * math.sin(rotation)
  a.y = (-vertex.x * math.sin(rotation)) + vertex.y * math.cos(rotation)
  a.z = vertex.z
  return a
end

function polygons.rotateYAxis(vertex, rotation)
  local a = polygons.vertex(0, 0, 0)
  a.x = vertex.x * math.cos(rotation) - vertex.z * math.sin(rotation)
  a.y = vertex.y
  a.z = vertex.z * math.sin(rotation) + vertex.z * math.cos(rotation)
  return a
end

function polygons.rotateXAxis(vertex, rotation)
  local a = polygons.vertex(0, 0, 0)
  a.x = vertex.x
  a.y = vertex.y * math.cos(rotation) + vertex.z * math.sin(rotation)
  a.z = (- vertex.y) * math.sin(rotation) + vertex.z * math.cos(rotation)
  return a
end

function polygons.vertex(x, y, z)
  local self = {
    x = x,
    y = y,
    z = z
  }

  function self.tostring()
    return "vertex (" .. self.x .. ", " .. self.y .. ", " .. self.z .. ")"
  end

  return self
end

function polygons.polygon()
  local self = {
    color = {},
    vertices = {}
  }

  function self.append(vertex)
    table.insert(self.vertices, vertex)
  end

  return self
end

function polygons.panel(orgX, orgY, orgZ, width, height, topColor, leftColor, rightColor)
  -- 初期化ルーチン
  local _initialize = function()
    local s = {}
    for _, v in pairs({"d", "u"}) do
      s[v] = {}
    end
    return s
  end

  local initSpace = _initialize()
  local panelSpace = _initialize()

  -- コードのわかりやすさのため、panelの中心を原点として頂点を定義する。
  --- panelの下側平面の頂点
  initSpace["d"][1] = polygons.vertex(-(width/2), width/2, 0)
  initSpace["d"][2] = polygons.vertex(  width/2 , width/2, 0)
  initSpace["d"][3] = polygons.vertex(  width/2 ,  -(width/2), 0)
  initSpace["d"][4] = polygons.vertex(-(width/2),  -(width/2), 0)

  --- panelの上側平面の頂点
  initSpace["u"][1] = polygons.vertex(-(width/2), width/2, height)
  initSpace["u"][2] = polygons.vertex(  width/2 , width/2, height)
  initSpace["u"][3] = polygons.vertex(  width/2 ,   -(width/2) , height)
  initSpace["u"][4] = polygons.vertex(-(width/2),   -(width/2) , height)

  -- 座標系の変更
  local offset = polygons.vertex(orgX, orgY, orgZ)
  for _, h in pairs({"d", "u"}) do
    for l = 1, 4 do
      panelSpace[h][l] = polygons.translate(initSpace[h][l], offset)
    end
  end

  -- ポリゴン生成
  local upperSurface = polygons.polygon()
  upperSurface.color = topColor
  upperSurface.append(panelSpace["u"][1])
  upperSurface.append(panelSpace["u"][2])
  upperSurface.append(panelSpace["u"][3])
  upperSurface.append(panelSpace["u"][4])

  local leftSurface = polygons.polygon()
  leftSurface.color = leftColor
  leftSurface.append(panelSpace["u"][1])
  leftSurface.append(panelSpace["u"][4])
  leftSurface.append(panelSpace["d"][4])
  leftSurface.append(panelSpace["d"][1])

  local rightSurface = polygons.polygon()
  rightSurface.color = rightColor
  rightSurface.append(panelSpace["u"][1])
  rightSurface.append(panelSpace["u"][2])
  rightSurface.append(panelSpace["d"][2])
  rightSurface.append(panelSpace["d"][1])

  return {upperSurface, leftSurface, rightSurface}
end

function polygons.player(direction, orgX, orgY, orgZ, depth, width, height, topColor, shadowColor)
  -- 初期化ルーチン
  local _initialize = function()
    local s = {}
    for _, v in pairs({"d", "u"}) do
      s[v] = {}
    end
    return s
  end

  local lips = _initialize()
  local lrps = _initialize()
  local ips = _initialize()

  --自機中心を原点とする局所座標系による頂点の定義
  --- 下面
  lips["d"][1] = polygons.vertex(        0 ,   depth/2 , 0)
  lips["d"][2] = polygons.vertex(  width/2 ,  -depth/2 , 0)
  lips["d"][3] = polygons.vertex(-(width/2),  -depth/2 , 0)

  --- 上面
  lips["u"][1] = polygons.vertex(        0 ,   depth/2 , height)
  lips["u"][2] = polygons.vertex(  width/2 ,  -depth/2 , height)
  lips["u"][3] = polygons.vertex(-(width/2),  -depth/2 , height)

  -- そして回転
  for _, h in pairs({"d", "u"}) do
    for l = 1, 3 do
      local pr
      if (direction == "east") then
        pr = math.pi/2
      elseif (direction == "south") then
        pr = 0
      elseif (direction == "west") then
        pr = -math.pi/2
      elseif (direction == "north") then
        pr = math.pi
      else
        error(string.format("polygons->playerPolygons | unknown player direction value: %s", player.drc))
      end

      lrps[h][l] = polygons.rotateZAxis(lips[h][l], pr)
    end
  end

  -- 座標系の変更
  local offset = polygons.vertex(orgX, orgY, orgZ)
  for _, h in pairs({"d", "u"}) do
    for l = 1, 3 do
      ips[h][l] = polygons.translate(lrps[h][l], offset)
    end
  end

  -- ポリゴン出力
  local shadow = polygons.polygon()
  shadow.color = shadowColor
  shadow.append(ips["d"][1])
  shadow.append(ips["d"][2])
  shadow.append(ips["d"][3])

  local surface = polygons.polygon()
  surface.color = topColor
  surface.append(ips["u"][1])
  surface.append(ips["u"][2])
  surface.append(ips["u"][3])

  return {shadow, surface}
end

function polygons.pole(orgX, orgY, orgZ, width, height, leftColor, rightColor)
  -- ポール中心を原点とする局所座標系による頂点の定義
  local summit = polygons.vertex(0, 0, height)
  local b = {}
  b[1] = polygons.vertex(-(width/2), width/2, 0)
  b[2] = polygons.vertex(  width/2 , width/2, 0)
  b[3] = polygons.vertex(  width/2 ,  -(width/2), 0)
  b[4] = polygons.vertex(-(width/2),  -(width/2), 0)

  -- 座標系の変更
  local offset = polygons.vertex(orgX, orgY, orgZ)
  summit = polygons.translate(summit, offset)
  for i = 1, 4 do
      b[i] = polygons.translate(b[i], offset)
  end

  -- ポリゴン生成
  local leftSide = polygons.polygon()
  leftSide.color = leftColor
  leftSide.append(summit)
  leftSide.append(b[1])
  leftSide.append(b[4])

  local rightSide = polygons.polygon()
  rightSide.color = rightColor
  rightSide.append(summit)
  rightSide.append(b[1])
  rightSide.append(b[2])

  return {leftSide, rightSide}
end

return polygons