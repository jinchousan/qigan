local object = {}

local _minHeight = 1
local _maxHeight = 5

local function generateKey(posX, posY)
    return tostring(posX) .. "," .. tostring(posY)
end

function object.player(posX, posY, direction)
    local self = {
        posX = posX,
        posY = posY,
        direction = direction
    }

    function self.tostring()
        return "player at (" .. self.posX .. ", " .. self.posY .. ") in direlction " .. self.direction
    end

    return self
end

function object.panel(posX, posY, height)
    local self = {
        posX = posX,
        posY = posY,
        height = height
    }

    if (height < _minHeight) or (height > _maxHeight) then
        error("mygame->panel | too large or too small height: " .. height)
    end

    function self.tostring()
        return "panel at (" .. self.posX .. ", " .. self.posY .. ") in height " .. self.height
    end

    return self
end

function object.world(presetTrail, presetSize)
    local self = {
        trail = {}
    }

    local size = 0

    if (presetTrail == nil) then self.trail = {} else self.trail = presetTrail end
    if (presetSize  == nil) then size = 0  else size = presetSize end

    function self.getSize()
        return size
    end

    function self.addPanel(panel, mode)
        local key = generateKey(panel.posX, panel.posY)
        if (mode == "force") or (self.trail[key] == nil) then
            self.trail[key] = panel.height
            size = size + 1
            return true
        else
            return false
        end
    end

    function self.mergeChunk(chunk, mode)
        for _,v in pairs(chunk) do
            self.addPanel(v, mode)
        end
    end

    function self.max()
        local m = _minHeight - 1 -- こう書くの嫌だ...
        for _,v in pairs(self.trail) do
            m = math.max(m, v)
        end
        return m
    end

    function self.min()
        local m = _maxHeight + 1 -- こう書くの嫌だ...
        for _,v in pairs(self.trail) do
            m = math.min(m, v)
        end
        return m
    end

    function self.getHeight(posX, posY)
        return self.trail[generateKey(posX, posY)]
    end

    function self.getPanel(posX, posY)
        local h = self.getHeight(posX, posY)
        if (h == nil) then
            return nil
        else
            return object.panel(posX, posY, h)
        end
    end

    function self.mergeWorld(world)
        for k,v in pairs(world.trail) do
            self.trail[k] = v
        end
        size = size + world.getSize()
    end

    function self.removePanel(posX, posY)
        self.trail[generateKey(posX, posY)] = nil
        size = size - 1
    end

    function self.removePanelByKey(key)
        self.trail[key] = nil
        size = size - 1
    end

    return self
end

function object.panelsQiganByIntention(name)
    local self = {
        name = name,
        size = 0,
        pattern = {},
        gap = 1 -- "~", "-", "_", "^" 指定のときの必要ギャップ（以上）
    }

    function self.setPattern(size, array, gap) -- gapを指定しない場合のデフォルト値は1
        self.pattern = array
        self.size = size
        if (gap ~= nil) then self.gap = gap end
    end

    function self.isMatched(world, posX, posY)
        function _exist(array, value, gap)
            for _,v in ipairs(array) do
                if (math.abs(v - value) < gap) then return true end
            end
            return false
        end

        -- パターン文字ごとに当該箇所のパネルを抽出する
        local filtered = {}
        local m = 1
        local n = 1
        for j = posY, posY-(self.size-1), -1 do
            for i = posX, posX+(self.size-1) do
                local p = world.getPanel(i, j)
                if (p == nil) then
                    error("mygame->panelsQiganByIntention->isMatched | panel is null in (" .. i .. ", " .. j .. ")")
                end
                local c = self.pattern[n][m]
                if (filtered[c] == nil) then filtered[c] = object.world() end
                filtered[c].addPanel(p)
                m = m + 1
            end
            m = 1
            n = n + 1
        end

        -- パターン文字ごとに、抽出したパネルがパターンの条件に合うか判定する
        local alph = {}
        local range = {}
        local maximal = _minHeight - 1
        local minimal = _maxHeight + 1

        --- 数字とアルファベットの場合の判定
        for k,w in pairs(filtered) do
            if (string.match(k, "%d") ~= nil) then -- 数字（数字が直接heightを示す）の場合
                local h = tonumber(k)
                if (w.min() ~= h or w.max() ~= h) then
                    return false
                end
                maximal = math.max(maximal, h)
                minimal = math.min(minimal, h)
                table.insert(range, h)
            elseif (string.match(k, "%l") ~= nil) then -- アルファベット（同じアルファベットは同じheightであることを示す。アルファベット順に高い）の場合
                if (w.min() ~= w.max()) then -- すべての値が同じか
                    return false
                end
                local h = w.min()
                if (alph[h] == nil) then alph[h] = "" end
                alph[h] = alph[h] .. k -- ah を後で料理する
                maximal = math.max(maximal, h)
                minimal = math.min(minimal, h)
                table.insert(range, h)
            end
        end

        ---- アルファベット・追試
        local lastc = ""
        local lastch = 0
        for k,v in pairs(alph) do -- pairsの場合、配列のインデックスの入れ方がぐちゃぐちゃだったり、飛び飛びだったりしても、数字順にイテレーションされるようだが...？
            if (string.len(v) ~= 1) then
                return false
            end
            if (lastc ~= "") and (string.byte(lastc)-string.byte(v) ~= lastch-k) then
                return false
            end
            lastc = v
            lastch = k
        end

        --- その他の文字の判定
        for k,w in pairs(filtered) do
            if (string.match(k, "%^") ~= nil) then -- ハット（他のどの数字/アルファベット箇所よりも高いことを示す）の場合
                if (w.min() - maximal < self.gap) then
                    return false
                end
            elseif (string.match(k, "_") ~= nil) then -- アンダーバー（他のどの数字/アルファベット箇所よりも低いことを示す）の場合
                if (minimal - w.max() < self.gap) then
                    return false
                end
            elseif (string.match(k, "%-") ~= nil) then -- ハイフン（ハットまたはアンダーバーいずれかの条件を満たすことを示す）の場合
                if (w.min() - maximal < self.gap) and (minimal - w.max() < self.gap) then
                    return false
                end
            elseif (string.match(k, "~") ~= nil) then -- チルダ（他のどの数字/アルファベット箇所と同じ高さでない）の場合
                for _,v in pairs(w.trail) do
                    if _exist(range, v, self.gap) then
                        return false
                    end
                end
            elseif (string.match(k, "%*") ~= nil) then -- アスタリスク（なんでもいい）の場合
                -- なんもしない
            end
        end
        
        return true
    end

    function self.tostring()
        local out = ""
        for _,v in ipairs(self.pattern) do
            out = out .. table.concat(v)
            out = out .. "\n"
        end

        return out
    end

    function self.computeRarity()
        -- べき乗の計算をする関数
        local function _power(a, n)
            local p = 1
            if (n < 0) then
                error("mygame->panelsQiganByIntention->computeRarity->_power | the given multiplier is negative : " .. n)
            elseif (n == 0) then
                return 1
            end
            for i=1,n do
                p = p * a
            end
            return p
        end

        -- 集合から、その要素が昇順になっている配列を作る関数
        local function _set2orderedArray(s)
            local a = {}
            for k,_ in pairs(s) do
                table.insert(a, k)
            end
            table.sort(a)
            return a
        end

        -- ２つの集合の和を取る関数
        local function _unionSets(s1, s2)
            local su = {}
            for k,_ in pairs(s1) do
                su[k] = true
            end
            for k,_ in pairs(s2) do
                su[k] = true
            end
            return su
        end

        -- 正またはゼロだったらその値、負だったらゼロを返す関数
        local function _nonNegative(n)
            if (n < 0) then
                return 0
            else
                return n
            end
        end

        -- 必要な要素の抽出
        local constSet = {}
        local alphSet = {}
        local wilds = {}
        for _,v in pairs({"^", "-", "_", "~", "*"}) do
            wilds[v] = 0
        end
        for i = 1, self.size do
            for j = 1, self.size do
                local char = self.pattern[i][j]
                if (string.match(char, "%d") ~= nil) then  -- 数字を拾う
                    constSet[tonumber(char)] = true
                elseif (string.match(char, "%l") ~= nil) then -- アルファベットを拾う
                    alphSet[char] = true
                elseif (string.match(char, "[%^_%-~%*]") ~= nil) then -- ワイルドカードを拾ってその数を数える
                    wilds[char] = wilds[char] + 1
                end
            end
        end

        local constList = _set2orderedArray(constSet)
        local alphList = _set2orderedArray(alphSet)

        local ptnsTotal = 0
        local dist
        if (#alphList == 0) then
            dist = _maxHeight-_minHeight
        else
            dist = string.byte(alphList[#alphList]) - string.byte(alphList[1])
        end
        for i = _minHeight, _maxHeight-dist do
            local rangeSet = _unionSets({}, constSet)

            -- アルファベット群に高さをアサインする
            local preAlph = ""
            local j = 0
            for _,v in pairs(alphList) do
                if (preAlph == "") then
                    j = i
                else
                    j = j + (string.byte(v)-string.byte(preAlph))
                end
                rangeSet[j] = true
                preAlph = v
            end

            -- アサインされた結果と数字とを両方とも勘案して、gapから、下域、中域、上域の取りうる数字の数を数える
            local rangeList = _set2orderedArray(rangeSet)

            local lower, upper, middle -- 下域、上域、中域の数
            if (#rangeList ~= 0) then
                rangeMax = rangeList[#rangeList]
                rangeMin = rangeList[1]

                lower = _nonNegative((rangeMin-self.gap) - _minHeight)

                upper = _nonNegative(_maxHeight - (rangeMax+self.gap))

                middle = 0
                for j = 1, #rangeList-1 do
                    middle = middle + _nonNegative(rangeList[j+1] - (rangeList[j]+self.gap))
                end
            else
                lower =  _maxHeight - _minHeight + 1
                upper =  _maxHeight - _minHeight + 1
                middle = _maxHeight - _minHeight + 1
            end
            
            -- 数えた数字から、_、^、-、~の組み合わせの数を決定し、合計する
            ptnsTotal = ptnsTotal + _power(lower, wilds["_"]) * _power(upper, wilds["^"]) * _power(lower+upper, wilds["-"]) * _power(lower+upper+middle, wilds["~"]) * _power((_maxHeight-_minHeight+1), wilds["*"])
        end

        if (ptnsTotal == 0) then
            return math.huge
        else
            return math.floor(_power((_maxHeight - _minHeight) + 1, _power(self.size, 2)) / ptnsTotal)
        end
    end

    return self
end

return object