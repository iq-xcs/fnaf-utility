local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lp  = Players.LocalPlayer
local pg  = lp:WaitForChild("PlayerGui")
local cam = workspace.CurrentCamera

-- ══════════════════════════════════════════════════
--  СОСТОЯНИЕ
-- ══════════════════════════════════════════════════

local returnPos     = Vector3.new(0, 5, 0)
local marker        = nil
local cleaning      = false
local musicboxAuto  = false
local autoEscape    = false
local ragdollBlock  = false
local customSpeed   = nil
local customFOV     = nil
local espAnimOn     = false
local espPlayersOn  = false
local pickupEnabled = false   -- подбор без кд (E зажато)

local escapeConn    = nil
local ragdollConn   = nil
local eHeldConn     = nil

-- ══════════════════════════════════════════════════
--  ЦВЕТА АНИМАТРОНИКОВ
-- ══════════════════════════════════════════════════

local ANIM_COLORS = {
    ["Freddy"]         = Color3.fromRGB(139, 90,  43),   -- коричневый
    ["Bonnie"]         = Color3.fromRGB(60,  80,  200),  -- синий
    ["Chica"]          = Color3.fromRGB(230, 200, 30),   -- жёлтый
    ["Foxy"]           = Color3.fromRGB(210, 100, 30),   -- оранжевый
    ["Toy Freddy"]     = Color3.fromRGB(180, 120, 60),   -- светло-коричневый
    ["Toy Bonnie"]     = Color3.fromRGB(100, 160, 230),  -- голубой
    ["Toy Chica"]      = Color3.fromRGB(255, 220, 60),   -- ярко-жёлтый
    ["Withered Freddy"]= Color3.fromRGB(100, 65,  30),   -- тёмно-коричневый
    ["Withered Foxy"]  = Color3.fromRGB(160, 75,  20),   -- тёмно-оранжевый
    ["Puppet"]         = Color3.fromRGB(200, 200, 200),  -- белый
    ["Feddy"]          = Color3.fromRGB(139, 90,  43),
    DEFAULT            = Color3.fromRGB(200, 200, 200),
}

local function getAnimColor(name)
    return ANIM_COLORS[name] or ANIM_COLORS.DEFAULT
end

-- ══════════════════════════════════════════════════
--  УТИЛИТЫ
-- ══════════════════════════════════════════════════

local function getHRP()
    local c = lp.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = lp.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function teleportTo(pos)
    local hrp = getHRP()
    if hrp then hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end
end

local function w2s(pos)
    local sp, inView = cam:WorldToViewportPoint(pos)
    return Vector2.new(sp.X, sp.Y), inView, sp.Z
end

-- ══════════════════════════════════════════════════
--  ESP АНИМАТРОНИКИ — квадратики по размеру модели
-- ══════════════════════════════════════════════════

local animESPFolder = Instance.new("Folder")
animESPFolder.Name  = "AnimESP"
animESPFolder.Parent = pg

local animESPData = {}  -- [model] = { box, nameLabel, lines={} }

-- рисуем 2D bounding box через Drawing
-- 8 точек куба → проецируем → находим min/max на экране

local function getModelBoundingBox(model)
    local ok, cf, sz = pcall(function() return model:GetBoundingBox() end)
    if not ok then return nil, nil end
    return cf, sz
end

local function makeAnimESP(model)
    if animESPData[model] then return end
    local color = getAnimColor(model.Name)

    -- 4 линии для прямоугольника
    local lines = {}
    for i = 1, 4 do
        local l = Drawing.new("Line")
        l.Thickness  = 1.5
        l.Color      = color
        l.Transparency = 1
        l.Visible    = false
        l.ZIndex     = 2
        lines[i] = l
    end

    -- имя
    local nameLabel = Drawing.new("Text")
    nameLabel.Text     = model.Name
    nameLabel.Color    = color
    nameLabel.Size     = 14
    nameLabel.Font     = Drawing.Fonts.UI
    nameLabel.Outline  = true
    nameLabel.OutlineColor = Color3.new(0,0,0)
    nameLabel.Visible  = false
    nameLabel.ZIndex   = 3

    animESPData[model] = { lines=lines, nameLabel=nameLabel, color=color }
end

local function removeAnimESP(model)
    local data = animESPData[model]
    if not data then return end
    for _, l in ipairs(data.lines) do pcall(function() l:Remove() end) end
    pcall(function() data.nameLabel:Remove() end)
    animESPData[model] = nil
end

local function clearAllAnimESP()
    for model in pairs(animESPData) do removeAnimESP(model) end
end

local function refreshAnimESP()
    clearAllAnimESP()
    if not espAnimOn then return end
    local folder = workspace:FindFirstChild("Animatronics")
    if not folder then return end
    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") then
            makeAnimESP(model)
        end
    end
end

-- обновление позиций квадратиков каждый кадр
RunService.Heartbeat:Connect(function()
    if not espAnimOn then
        for _, data in pairs(animESPData) do
            for _, l in ipairs(data.lines) do l.Visible=false end
            data.nameLabel.Visible = false
        end
        return
    end

    for model, data in pairs(animESPData) do
        if not model or not model.Parent then
            removeAnimESP(model); continue
        end

        local cf, sz = getModelBoundingBox(model)
        if not cf or not sz then
            for _, l in ipairs(data.lines) do l.Visible=false end
            data.nameLabel.Visible=false
            continue
        end

        local center = cf.Position

        -- 8 углов bounding box
        local hx, hy, hz = sz.X/2, sz.Y/2, sz.Z/2
        local corners = {
            center + Vector3.new( hx,  hy,  hz),
            center + Vector3.new(-hx,  hy,  hz),
            center + Vector3.new( hx, -hy,  hz),
            center + Vector3.new(-hx, -hy,  hz),
            center + Vector3.new( hx,  hy, -hz),
            center + Vector3.new(-hx,  hy, -hz),
            center + Vector3.new( hx, -hy, -hz),
            center + Vector3.new(-hx, -hy, -hz),
        }

        -- проецируем все углы
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        local anyVisible = false
        for _, corner in ipairs(corners) do
            local sp, inView, depth = w2s(corner)
            if inView and depth > 0 then
                anyVisible = true
                if sp.X < minX then minX = sp.X end
                if sp.Y < minY then minY = sp.Y end
                if sp.X > maxX then maxX = sp.X end
                if sp.Y > maxY then maxY = sp.Y end
            end
        end

        if not anyVisible then
            for _, l in ipairs(data.lines) do l.Visible=false end
            data.nameLabel.Visible=false
            continue
        end

        -- отступ
        local pad = 2
        local x0,y0,x1,y1 = minX-pad, minY-pad, maxX+pad, maxY+pad

        -- 4 стороны прямоугольника
        -- top, bottom, left, right
        local rects = {
            {Vector2.new(x0,y0), Vector2.new(x1,y0)},
            {Vector2.new(x0,y1), Vector2.new(x1,y1)},
            {Vector2.new(x0,y0), Vector2.new(x0,y1)},
            {Vector2.new(x1,y0), Vector2.new(x1,y1)},
        }

        for i, rect in ipairs(rects) do
            local l = data.lines[i]
            l.From    = rect[1]
            l.To      = rect[2]
            l.Color   = data.color
            l.Visible = true
        end

        -- имя над боксом
        data.nameLabel.Position = Vector2.new((x0+x1)/2 - #model.Name*3.5, y0 - 18)
        data.nameLabel.Visible  = true
    end
end)

-- слушаем появление новых аниматроников
workspace:WaitForChild("Animatronics").ChildAdded:Connect(function(obj)
    if espAnimOn and obj:IsA("Model") then makeAnimESP(obj) end
end)
workspace:WaitForChild("Animatronics").ChildRemoved:Connect(function(obj)
    removeAnimESP(obj)
end)

-- ══════════════════════════════════════════════════
--  ESP ИГРОКИ — имя + иконка скина + highlight
-- ══════════════════════════════════════════════════

local hlFolder = Instance.new("Folder")
hlFolder.Name  = "PlayerESP"
hlFolder.Parent = pg

local playerESPData = {}  -- [player] = { hl, billboard }

local PLAYER_COLOR = Color3.fromRGB(80, 200, 255)

local function makePlayerHL(char)
    local h = Instance.new("Highlight")
    h.Adornee          = char
    h.OutlineColor     = PLAYER_COLOR
    h.FillColor        = PLAYER_COLOR
    h.FillTransparency = 0.7
    h.DepthMode        = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent           = hlFolder
    return h
end

local function makePlayerBillboard(p, char)
    local head = char:FindFirstChild("Head") or char:FindFirstChildWhichIsA("BasePart")
    if not head then return nil end

    local bg = Instance.new("BillboardGui")
    bg.Adornee      = head
    bg.Size         = UDim2.new(0, 120, 0, 50)
    bg.StudsOffset  = Vector3.new(0, 3.5, 0)
    bg.AlwaysOnTop  = true
    bg.ResetOnSpawn = false
    bg.Parent       = hlFolder

    -- иконка скина
    local icon = Instance.new("ImageLabel", bg)
    icon.Size               = UDim2.new(0, 30, 0, 30)
    icon.Position           = UDim2.new(0, 0, 0.5, -15)
    icon.BackgroundColor3   = Color3.fromRGB(20,20,20)
    icon.BorderSizePixel    = 1
    icon.BorderColor3       = PLAYER_COLOR
    -- загружаем thumbnail
    local ok, thumb = pcall(function()
        return Players:GetUserThumbnailAsync(
            p.UserId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size60x60
        )
    end)
    icon.Image = ok and thumb or ""

    -- имя
    local nameLbl = Instance.new("TextLabel", bg)
    nameLbl.Size                   = UDim2.new(1,-36,0,18)
    nameLbl.Position               = UDim2.new(0,34,0,5)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text                   = p.DisplayName
    nameLbl.TextColor3             = PLAYER_COLOR
    nameLbl.TextSize               = 13
    nameLbl.Font                   = Enum.Font.SourceSansBold
    nameLbl.TextStrokeTransparency = 0.4
    nameLbl.TextStrokeColor3       = Color3.new(0,0,0)
    nameLbl.TextXAlignment         = Enum.TextXAlignment.Left

    -- дистанция
    local distLbl = Instance.new("TextLabel", bg)
    distLbl.Size                   = UDim2.new(1,-36,0,14)
    distLbl.Position               = UDim2.new(0,34,0,24)
    distLbl.BackgroundTransparency = 1
    distLbl.Text                   = ""
    distLbl.TextColor3             = Color3.fromRGB(180,180,180)
    distLbl.TextSize               = 11
    distLbl.Font                   = Enum.Font.SourceSans
    distLbl.TextStrokeTransparency = 0.5
    distLbl.TextStrokeColor3       = Color3.new(0,0,0)
    distLbl.TextXAlignment         = Enum.TextXAlignment.Left

    return { gui=bg, distLbl=distLbl }
end

local function buildPlayerESP(p)
    if playerESPData[p] or p == lp then return end
    local char = p.Character; if not char then return end
    local data = {}
    data.hl = makePlayerHL(char)
    local bb = makePlayerBillboard(p, char)
    if bb then data.gui=bb.gui; data.distLbl=bb.distLbl end
    playerESPData[p] = data
end

local function destroyPlayerESP(p)
    local data = playerESPData[p]; if not data then return end
    if data.hl  then data.hl:Destroy() end
    if data.gui then data.gui:Destroy() end
    playerESPData[p] = nil
end

local function rebuildPlayerESP()
    for p in pairs(playerESPData) do destroyPlayerESP(p) end
    if not espPlayersOn then return end
    for _, p in ipairs(Players:GetPlayers()) do buildPlayerESP(p) end
end

-- обновление дистанции
RunService.Heartbeat:Connect(function()
    if not espPlayersOn then return end
    local myHRP = getHRP()
    for p, data in pairs(playerESPData) do
        if not p or not p.Parent then destroyPlayerESP(p); continue end
        local char = p.Character
        if not char then continue end
        -- пересоздаём highlight если сломан
        if not data.hl or not data.hl.Parent or data.hl.Adornee ~= char then
            if data.hl then data.hl:Destroy() end
            data.hl = makePlayerHL(char)
        end
        -- дистанция
        if data.distLbl and myHRP then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                data.distLbl.Text = math.floor((hrp.Position - myHRP.Position).Magnitude).." st"
            end
        end
    end
end)

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.3); destroyPlayerESP(p)
        if espPlayersOn then buildPlayerESP(p) end
    end)
end)
Players.PlayerRemoving:Connect(function(p) destroyPlayerESP(p) end)
for _, p in ipairs(Players:GetPlayers()) do
    p.CharacterAdded:Connect(function()
        task.wait(0.3); destroyPlayerESP(p)
        if espPlayersOn then buildPlayerESP(p) end
    end)
end

-- ══════════════════════════════════════════════════
--  ПОДБОР МУСОРА БЕЗ КД — зажать E
-- ══════════════════════════════════════════════════

local function getAllTrashPrompts()
    local results = {}
    local ok, folder = pcall(function() return workspace.Map.Trash.CurrentTrash end)
    if not ok or not folder then return results end
    for _, obj in ipairs(folder:GetChildren()) do
        local prompt = obj:FindFirstChild("CleanPrompt")
        if prompt and prompt:IsA("ProximityPrompt") then
            local pos
            if obj:IsA("BasePart") then pos=obj.Position
            elseif obj:IsA("Model") then pcall(function() pos=obj:GetPivot().Position end) end
            if pos then table.insert(results, {prompt=prompt, pos=pos}) end
        end
    end
    return results
end

local function fireNearbyTrash()
    local hrp = getHRP(); if not hrp then return end
    for _, entry in ipairs(getAllTrashPrompts()) do
        local dist = (entry.pos - hrp.Position).Magnitude
        if dist <= entry.prompt.MaxActivationDistance + 3 then
            pcall(function() fireproximityprompt(entry.prompt) end)
        end
    end
end

-- зажатие E
UserInputService.InputBegan:Connect(function(input, gp)
    if gp or not pickupEnabled then return end
    if input.KeyCode == Enum.KeyCode.E then
        if eHeldConn then return end
        eHeldConn = RunService.Heartbeat:Connect(function()
            if not pickupEnabled then
                eHeldConn:Disconnect(); eHeldConn=nil; return
            end
            fireNearbyTrash()
        end)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.E then
        if eHeldConn then eHeldConn:Disconnect(); eHeldConn=nil end
    end
end)

-- ══════════════════════════════════════════════════
--  СКОРОСТЬ И FOV
-- ══════════════════════════════════════════════════

RunService.Heartbeat:Connect(function()
    if customSpeed then
        local hum=getHum(); if hum then hum.WalkSpeed=customSpeed end
    end
    if customFOV then
        workspace.CurrentCamera.FieldOfView=customFOV
    end
end)

lp.CharacterAdded:Connect(function()
    task.wait(0.5)
    if customSpeed then local hum=getHum(); if hum then hum.WalkSpeed=customSpeed end end
end)

-- ══════════════════════════════════════════════════
--  RAGDOLL BLOCK
-- ══════════════════════════════════════════════════

local function startRagdollBlock()
    local function hook()
        local c=lp.Character; if not c then return end
        local values=c:FindFirstChild("Values")
        if not values then
            c.ChildAdded:Connect(function(ch) if ch.Name=="Values" then task.wait(0.1); hook() end end)
            return
        end
        local ragVal=values:FindFirstChild("Ragdoll")
        if not ragVal then
            values.ChildAdded:Connect(function(ch) if ch.Name=="Ragdoll" then task.wait(0.05); hook() end end)
            return
        end
        if ragdollConn then ragdollConn:Disconnect() end
        ragdollConn=ragVal.Changed:Connect(function(val)
            if not ragdollBlock then return end
            if val==true then
                ragVal.Value=false
                local hum=getHum()
                if hum then hum.PlatformStand=false; hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
            end
        end)
        if ragVal.Value==true then ragVal.Value=false end
        print("[Ragdoll] Блок установлен")
    end
    hook()
end

RunService.Heartbeat:Connect(function()
    if not ragdollBlock then return end
    local c=lp.Character; if not c then return end
    local values=c:FindFirstChild("Values"); if not values then return end
    local ragVal=values:FindFirstChild("Ragdoll"); if not ragVal then return end
    if ragVal.Value==true then
        ragVal.Value=false
        local hum=getHum()
        if hum then hum.PlatformStand=false; hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
    end
end)

lp.CharacterAdded:Connect(function()
    task.wait(0.5); if ragdollBlock then startRagdollBlock() end
end)

-- ══════════════════════════════════════════════════
--  АВТО ВЫХОД
-- ══════════════════════════════════════════════════

local function getEndPrompt()
    local ok,pp=pcall(function() return workspace.Map.ImportantSpots.EndPos.ProximityPrompt end)
    if ok and pp and pp:IsA("ProximityPrompt") then return pp end
    return nil
end

local function tryEscape()
    local pp=getEndPrompt(); if not pp or pp.Enabled==false then return false end
    local hrp=getHRP(); if not hrp then return false end
    local parent=pp.Parent
    local pos
    if parent:IsA("BasePart") then pos=parent.Position
    elseif parent:IsA("Model") then pos=parent:GetPivot().Position end
    if pos then hrp.CFrame=CFrame.new(pos+Vector3.new(0,3,2)); task.wait(0.1) end
    pcall(function() fireproximityprompt(pp) end)
    print("[Escape] Вышел!"); return true
end

local function startEscapeWatch()
    if escapeConn then escapeConn:Disconnect() end
    local t=0
    escapeConn=RunService.Heartbeat:Connect(function(dt)
        if not autoEscape then escapeConn:Disconnect(); escapeConn=nil; return end
        t+=dt; if t<1 then return end; t=0
        local pp=getEndPrompt()
        if pp and pp.Enabled~=false then tryEscape() end
    end)
end

-- ══════════════════════════════════════════════════
--  МАРКЕР
-- ══════════════════════════════════════════════════

local function removeMarker()
    if marker and marker.Parent then marker:Destroy() end; marker=nil
end

local function placeMarker(pos)
    removeMarker()
    marker=Instance.new("Part")
    marker.Name="ReturnMarker"; marker.Size=Vector3.new(3,0.1,3)
    marker.CFrame=CFrame.new(pos.X,pos.Y-2.9,pos.Z)
    marker.Anchored=true; marker.CanCollide=true; marker.CanQuery=true
    marker.Material=Enum.Material.Neon; marker.Color=Color3.fromRGB(80,200,255)
    marker.Transparency=0.3; marker.Parent=workspace
    local border=Instance.new("SelectionBox")
    border.Adornee=marker; border.Color3=Color3.fromRGB(80,200,255)
    border.LineThickness=0.04; border.SurfaceTransparency=1; border.Parent=marker
    local conn
    conn=RunService.Heartbeat:Connect(function()
        if not marker or not marker.Parent then conn:Disconnect(); return end
        marker.Transparency=0.3+0.25*math.abs(math.sin(tick()*2))
    end)
end

-- ══════════════════════════════════════════════════
--  CLEANING TOOL + МУСОР
-- ══════════════════════════════════════════════════

local function equipCleaningTool()
    local hum=getHum(); if not hum then return end
    local tool=lp.Backpack:FindFirstChild("Cleaning tool")
    if not tool then local c=lp.Character; if c then tool=c:FindFirstChild("Cleaning tool") end end
    if tool then hum:EquipTool(tool); task.wait(0.15) end
end

local function getAllTrash()
    local results={}
    local ok,folder=pcall(function() return workspace.Map.Trash.CurrentTrash end)
    if not ok or not folder then return results end
    for _,obj in ipairs(folder:GetChildren()) do
        local prompt=obj:FindFirstChild("CleanPrompt")
        if prompt and prompt:IsA("ProximityPrompt") then
            local pos
            if obj:IsA("BasePart") then pos=obj.Position
            elseif obj:IsA("Model") then pcall(function() pos=obj:GetPivot().Position end) end
            if pos then table.insert(results,{obj=obj,prompt=prompt,pos=pos}) end
        end
    end
    return results
end

local function cleanAllTrashTP()
    local hrp=getHRP(); if not hrp then return end
    equipCleaningTool()
    local trash=getAllTrash()
    if #trash==0 then print("[Trash] Нет мусора"); teleportTo(returnPos); return end
    table.sort(trash,function(a,b) return (a.pos-hrp.Position).Magnitude<(b.pos-hrp.Position).Magnitude end)
    for _,entry in ipairs(trash) do
        if not cleaning then break end
        if not entry.obj or not entry.obj.Parent then continue end
        teleportTo(entry.pos); task.wait(0.08)
        for i=1,5 do pcall(function() fireproximityprompt(entry.prompt) end); task.wait(0.05) end
        task.wait(0.1)
    end
    print("[Trash] Готово → возврат"); teleportTo(returnPos)
end

local function startCleanLoop()
    task.spawn(function()
        while cleaning do cleanAllTrashTP(); task.wait(1.5) end
    end)
end

-- ══════════════════════════════════════════════════
--  POWERBOX + FUSEBOXES
-- ══════════════════════════════════════════════════

local powerboxAuto = false
local fuseboxAuto  = false
local powerConn    = nil
local fuseConn     = nil

-- PowerBox — Repair (включается когда Enabled=true, т.е. сломан)
local function getPowerBoxPrompt()
    local ok, pp = pcall(function()
        return workspace.Map.ImportantSpots.PowerBox.Prompt.ProximityPrompt
    end)
    if ok and pp and pp:IsA("ProximityPrompt") then return pp end
    return nil
end

local function repairPowerBox()
    local pp = getPowerBoxPrompt()
    if not pp or not pp.Enabled then return false end
    local hrp = getHRP(); if not hrp then return false end
    local parent = pp.Parent
    local pos
    if parent:IsA("BasePart") then pos = parent.Position
    elseif parent:IsA("Model") then
        local ok2, p2 = pcall(function() return parent:GetPivot().Position end)
        if ok2 then pos = p2 end
    end
    if pos then
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 2))
        task.wait(0.1)
    end
    pcall(function() fireproximityprompt(pp) end)
    print("[PowerBox] Починен")
    return true
end

local function startPowerWatch()
    if powerConn then powerConn:Disconnect() end
    local t = 0
    powerConn = RunService.Heartbeat:Connect(function(dt)
        if not powerboxAuto then powerConn:Disconnect(); powerConn=nil; return end
        t += dt; if t < 1 then return end; t = 0
        local pp = getPowerBoxPrompt()
        if pp and pp.Enabled then repairPowerBox() end
    end)
end

-- FuseBoxes — Turn On все которые Enabled
local function getAllFusePrompts()
    local results = {}
    local ok, folder = pcall(function()
        return workspace.Map.ImportantSpots.FuseBoxes
    end)
    if not ok or not folder then return results end
    for _, child in ipairs(folder:GetChildren()) do
        for _, pp in ipairs(child:GetDescendants()) do
            if pp:IsA("ProximityPrompt") and pp.ActionText == "Turn On" and pp.Enabled then
                local part = pp.Parent
                local pos
                if part:IsA("BasePart") then pos = part.Position end
                if pos then
                    table.insert(results, { prompt=pp, pos=pos, name=child.Name })
                end
            end
        end
    end
    return results
end

local function activateAllFuses()
    local hrp = getHRP(); if not hrp then return end
    local fuses = getAllFusePrompts()
    if #fuses == 0 then return end
    print("[FuseBox] Включаем", #fuses, "предохранителей")
    for _, entry in ipairs(fuses) do
        if not fuseboxAuto then break end
        hrp.CFrame = CFrame.new(entry.pos + Vector3.new(0, 3, 2))
        task.wait(0.08)
        pcall(function() fireproximityprompt(entry.prompt) end)
        task.wait(0.1)
        print("[FuseBox] Включён:", entry.name)
    end
    -- возвращаемся на точку возврата
    teleportTo(returnPos)
end

local function startFuseWatch()
    if fuseConn then fuseConn:Disconnect() end
    local t = 0
    fuseConn = RunService.Heartbeat:Connect(function(dt)
        if not fuseboxAuto then fuseConn:Disconnect(); fuseConn=nil; return end
        t += dt; if t < 2 then return end; t = 0
        local fuses = getAllFusePrompts()
        if #fuses > 0 then
            task.spawn(activateAllFuses)
        end
    end)
end

-- ══════════════════════════════════════════════════
--  МАРИОНЕТКА
-- ══════════════════════════════════════════════════

local function getMusicBoxPrompt()
    local ok,pp=pcall(function() return workspace.Map.ImportantSpots.MusicBox.Prompt.Prompt end)
    if ok and pp and pp:IsA("ProximityPrompt") then return pp end
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.ActionText=="Wind" then return obj end
    end
end

local function windMusicBox()
    local hrp=getHRP(); if not hrp then return end
    local pp=getMusicBoxPrompt(); if not pp then return end
    local pos
    local p=pp.Parent
    if p:IsA("BasePart") then pos=p.Position
    elseif p:IsA("Model") then pos=p:GetPivot().Position end
    if pos then hrp.CFrame=CFrame.new(pos+Vector3.new(0,3,2)); task.wait(0.1) end
    for i=1,20 do pcall(function() fireproximityprompt(pp) end); task.wait(0.05) end
end

local function startMusicLoop()
    task.spawn(function()
        while musicboxAuto do windMusicBox(); task.wait(2) end
    end)
end

-- ══════════════════════════════════════════════════
--  GUI
-- ══════════════════════════════════════════════════

local sg=Instance.new("ScreenGui")
sg.Name="FNAFScript"; sg.ResetOnSpawn=false; sg.Parent=pg

local win=Instance.new("Frame",sg)
win.Size=UDim2.new(0,265,0,0)
win.Position=UDim2.new(0,8,0,8)
win.BackgroundColor3=Color3.fromRGB(28,28,28)
win.BorderColor3=Color3.fromRGB(62,62,62); win.BorderSizePixel=1
win.AutomaticSize=Enum.AutomaticSize.Y
win.Active=true; win.Draggable=true

local wLayout=Instance.new("UIListLayout",win)
wLayout.SortOrder=Enum.SortOrder.LayoutOrder
wLayout.Padding=UDim.new(0,0)

local function mk(class,props,parent)
    local o=Instance.new(class,parent); for k,v in pairs(props) do o[k]=v end; return o
end

local function mkCat(order,text)
    local f=mk("Frame",{LayoutOrder=order,Size=UDim2.new(1,0,0,18),BackgroundColor3=Color3.fromRGB(22,22,22),BorderSizePixel=0},win)
    mk("TextLabel",{Size=UDim2.new(1,-8,1,0),Position=UDim2.new(0,8,0,0),BackgroundTransparency=1,Text=text,TextColor3=Color3.fromRGB(105,105,105),TextSize=11,Font=Enum.Font.SourceSansBold,TextXAlignment=Enum.TextXAlignment.Left},f)
    mk("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=Color3.fromRGB(50,50,50),BorderSizePixel=0},f)
end

local function mkSep(order)
    mk("Frame",{LayoutOrder=order,Size=UDim2.new(1,0,0,1),BackgroundColor3=Color3.fromRGB(50,50,50),BorderSizePixel=0},win)
end

local function mkToggle(order,label,init,cb)
    local ON=Color3.fromRGB(78,170,78); local ONB=Color3.fromRGB(28,65,28)
    local OF=Color3.fromRGB(170,52,52); local OFB=Color3.fromRGB(64,20,20)
    local row=mk("Frame",{LayoutOrder=order,Size=UDim2.new(1,0,0,28),BackgroundColor3=Color3.fromRGB(36,36,36),BorderSizePixel=0},win)
    mk("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=Color3.fromRGB(62,62,62),BorderSizePixel=0},row)
    local dot=mk("Frame",{Size=UDim2.new(0,6,0,6),Position=UDim2.new(0,8,0.5,-3),BackgroundColor3=init and ON or OF,BorderSizePixel=0},row)
    mk("TextLabel",{Size=UDim2.new(1,-110,1,0),Position=UDim2.new(0,22,0,0),BackgroundTransparency=1,Text=label,TextColor3=Color3.fromRGB(215,215,215),TextSize=13,Font=Enum.Font.SourceSans,TextXAlignment=Enum.TextXAlignment.Left},row)
    local btn=mk("TextButton",{Size=UDim2.new(0,54,0,17),Position=UDim2.new(1,-62,0.5,-8),BackgroundColor3=init and ONB or OFB,BorderColor3=init and ON or OF,BorderSizePixel=1,Text=init and "ON" or "OFF",TextColor3=init and ON or OF,TextSize=11,Font=Enum.Font.SourceSansBold,AutoButtonColor=false},row)
    row.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseMovement then row.BackgroundColor3=Color3.fromRGB(44,44,44) end end)
    row.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseMovement then row.BackgroundColor3=Color3.fromRGB(36,36,36) end end)
    local s=init
    btn.MouseButton1Click:Connect(function()
        s=not s
        dot.BackgroundColor3=s and ON or OF
        btn.Text=s and "ON" or "OFF"; btn.TextColor3=s and ON or OF
        btn.BackgroundColor3=s and ONB or OFB; btn.BorderColor3=s and ON or OF
        cb(s)
    end)
end

local function mkButton(order,label,cb)
    local btn=mk("TextButton",{LayoutOrder=order,Size=UDim2.new(1,0,0,28),BackgroundColor3=Color3.fromRGB(36,36,36),BorderSizePixel=0,Text="",AutoButtonColor=false},win)
    mk("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=Color3.fromRGB(62,62,62),BorderSizePixel=0},btn)
    mk("TextLabel",{Size=UDim2.new(0,14,1,0),Position=UDim2.new(0,8,0,0),BackgroundTransparency=1,Text=">",TextColor3=Color3.fromRGB(190,150,50),TextSize=13,Font=Enum.Font.SourceSansBold},btn)
    mk("TextLabel",{Size=UDim2.new(1,-26,1,0),Position=UDim2.new(0,22,0,0),BackgroundTransparency=1,Text=label,TextColor3=Color3.fromRGB(215,215,215),TextSize=13,Font=Enum.Font.SourceSans,TextXAlignment=Enum.TextXAlignment.Left},btn)
    btn.MouseEnter:Connect(function() btn.BackgroundColor3=Color3.fromRGB(44,44,44) end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3=Color3.fromRGB(36,36,36) end)
    btn.MouseButton1Click:Connect(cb)
end

local function mkSlider(order,label,min,max,default,unit,cb)
    local row=mk("Frame",{LayoutOrder=order,Size=UDim2.new(1,0,0,44),BackgroundColor3=Color3.fromRGB(36,36,36),BorderSizePixel=0},win)
    mk("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=Color3.fromRGB(62,62,62),BorderSizePixel=0},row)
    mk("Frame",{Size=UDim2.new(0,6,0,6),Position=UDim2.new(0,8,0,9),BackgroundColor3=Color3.fromRGB(190,150,50),BorderSizePixel=0},row)
    mk("TextLabel",{Size=UDim2.new(1,-80,0,16),Position=UDim2.new(0,22,0,3),BackgroundTransparency=1,Text=label,TextColor3=Color3.fromRGB(215,215,215),TextSize=13,Font=Enum.Font.SourceSans,TextXAlignment=Enum.TextXAlignment.Left},row)
    local valLbl=mk("TextLabel",{Size=UDim2.new(0,54,0,16),Position=UDim2.new(1,-60,0,3),BackgroundTransparency=1,Text=tostring(default)..(unit or ""),TextColor3=Color3.fromRGB(190,150,50),TextSize=12,Font=Enum.Font.SourceSansBold,TextXAlignment=Enum.TextXAlignment.Right},row)
    local track=mk("Frame",{Size=UDim2.new(1,-20,0,5),Position=UDim2.new(0,12,0,32),BackgroundColor3=Color3.fromRGB(20,20,20),BorderColor3=Color3.fromRGB(65,65,65),BorderSizePixel=1},row)
    local p0=math.clamp((default-min)/(max-min),0,1)
    local fill=mk("Frame",{Size=UDim2.new(p0,0,1,0),BackgroundColor3=Color3.fromRGB(190,150,50),BorderSizePixel=0},track)
    local knob=mk("Frame",{Size=UDim2.new(0,2,1,4),Position=UDim2.new(p0,-1,0,-2),BackgroundColor3=Color3.fromRGB(210,210,210),BorderSizePixel=0,ZIndex=3},track)
    local cur=default; local drag=false
    local function upd(mx)
        local ap=track.AbsolutePosition; local as=track.AbsoluteSize
        local p=math.clamp((mx-ap.X)/as.X,0,1)
        cur=math.floor(min+p*(max-min))
        fill.Size=UDim2.new(p,0,1,0); knob.Position=UDim2.new(p,-1,0,-2)
        valLbl.Text=tostring(cur)..(unit or ""); if cb then cb(cur) end
    end
    local hit=mk("TextButton",{Size=UDim2.new(1,0,4,0),Position=UDim2.new(0,0,-1.5,0),BackgroundTransparency=1,Text="",ZIndex=5},track)
    hit.MouseButton1Down:Connect(function(x) drag=true; upd(x) end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then upd(i.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
    end)
end

local function mkCoordRow(order,axis,initVal,onChange)
    local axCol=axis=="X" and Color3.fromRGB(220,80,80) or axis=="Y" and Color3.fromRGB(80,200,80) or Color3.fromRGB(80,120,220)
    local row=mk("Frame",{LayoutOrder=order,Size=UDim2.new(1,0,0,28),BackgroundColor3=Color3.fromRGB(36,36,36),BorderSizePixel=0},win)
    mk("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=Color3.fromRGB(62,62,62),BorderSizePixel=0},row)
    mk("Frame",{Size=UDim2.new(0,6,0,6),Position=UDim2.new(0,8,0.5,-3),BackgroundColor3=axCol,BorderSizePixel=0},row)
    mk("TextLabel",{Size=UDim2.new(0,18,1,0),Position=UDim2.new(0,20,0,0),BackgroundTransparency=1,Text=axis,TextColor3=axCol,TextSize=13,Font=Enum.Font.SourceSansBold},row)
    local box=mk("TextBox",{Size=UDim2.new(1,-80,0,17),Position=UDim2.new(0,40,0.5,-8),BackgroundColor3=Color3.fromRGB(20,20,20),BorderColor3=Color3.fromRGB(65,65,65),BorderSizePixel=1,Text=tostring(math.floor(initVal)),TextColor3=Color3.fromRGB(215,215,215),TextSize=12,Font=Enum.Font.SourceSans,ClearTextOnFocus=false},row)
    local getBtn=mk("TextButton",{Size=UDim2.new(0,32,0,17),Position=UDim2.new(1,-36,0.5,-8),BackgroundColor3=Color3.fromRGB(30,55,30),BorderColor3=Color3.fromRGB(60,110,60),BorderSizePixel=1,Text="Get",TextColor3=Color3.fromRGB(100,200,100),TextSize=10,Font=Enum.Font.SourceSansBold,AutoButtonColor=false},row)
    getBtn.MouseButton1Click:Connect(function()
        local hrp=getHRP(); if not hrp then return end
        local v=axis=="X" and hrp.Position.X or axis=="Y" and hrp.Position.Y or hrp.Position.Z
        box.Text=tostring(math.floor(v)); onChange(math.floor(v))
    end)
    box.FocusLost:Connect(function()
        local n=tonumber(box.Text)
        if n then onChange(n) else box.Text=tostring(math.floor(initVal)) end
    end)
end

local function setCoord(axis,val)
    if axis=="X" then returnPos=Vector3.new(val,returnPos.Y,returnPos.Z)
    elseif axis=="Y" then returnPos=Vector3.new(returnPos.X,val,returnPos.Z)
    else returnPos=Vector3.new(returnPos.X,returnPos.Y,val) end
    placeMarker(returnPos)
end

local function refreshCoordLbl(lbl)
    lbl.Text=string.format("Return: %.0f, %.0f, %.0f",returnPos.X,returnPos.Y,returnPos.Z)
end

-- ══ МЕНЮ ══════════════════════════════════════════

local hdr=mk("Frame",{LayoutOrder=0,Size=UDim2.new(1,0,0,22),BackgroundColor3=Color3.fromRGB(45,45,45),BorderSizePixel=0},win)
mk("TextLabel",{Size=UDim2.new(1,-8,1,0),Position=UDim2.new(0,6,0,0),BackgroundTransparency=1,Text="[FL] FNAF Utility",TextColor3=Color3.fromRGB(215,215,215),TextSize=13,Font=Enum.Font.SourceSansBold,TextXAlignment=Enum.TextXAlignment.Left},hdr)
mk("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,0),BackgroundColor3=Color3.fromRGB(62,62,62),BorderSizePixel=0},hdr)

local posRow=mk("Frame",{LayoutOrder=1,Size=UDim2.new(1,0,0,16),BackgroundColor3=Color3.fromRGB(20,20,20),BorderSizePixel=0},win)
local posLbl=mk("TextLabel",{Size=UDim2.new(1,-8,1,0),Position=UDim2.new(0,6,0,0),BackgroundTransparency=1,Text="Pos: 0, 0, 0",TextColor3=Color3.fromRGB(80,200,255),TextSize=10,Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Left},posRow)
mk("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=Color3.fromRGB(50,50,50),BorderSizePixel=0},posRow)

local posTimer=0
RunService.Heartbeat:Connect(function(dt)
    posTimer+=dt; if posTimer<0.2 then return end; posTimer=0
    local hrp=getHRP()
    if hrp then local p=hrp.Position; posLbl.Text=string.format("Pos: %.0f, %.0f, %.0f",p.X,p.Y,p.Z) end
end)

local ord=2

-- ── ESP ──────────────────────────────────────────
mkSep(ord) ord+=1
mkCat(ord,"  ESP") ord+=1
mkToggle(ord,"Аниматроники ESP",false,function(v)
    espAnimOn=v; refreshAnimESP()
end) ord+=1
mkToggle(ord,"Игроки ESP",false,function(v)
    espPlayersOn=v; rebuildPlayerESP()
end) ord+=1

-- ── МУСОР ────────────────────────────────────────
mkSep(ord) ord+=1
mkCat(ord,"  Мусор") ord+=1
mkToggle(ord,"Авто уборка + ТП",false,function(v)
    cleaning=v; if v then task.spawn(startCleanLoop) end
end) ord+=1
mkButton(ord,"Убрать 1 раз",function() task.spawn(cleanAllTrashTP) end) ord+=1
mkToggle(ord,"Подбор рядом [E зажать]",false,function(v)
    pickupEnabled=v
    if not v and eHeldConn then eHeldConn:Disconnect(); eHeldConn=nil end
end) ord+=1

-- ── ТОЧКА ВОЗВРАТА ────────────────────────────────
mkSep(ord) ord+=1
mkCat(ord,"  Точка возврата") ord+=1
local coordInfoRow=mk("Frame",{LayoutOrder=ord,Size=UDim2.new(1,0,0,16),BackgroundColor3=Color3.fromRGB(20,20,20),BorderSizePixel=0},win) ord+=1
local coordLbl2=mk("TextLabel",{Size=UDim2.new(1,-8,1,0),Position=UDim2.new(0,6,0,0),BackgroundTransparency=1,Text="Return: 0, 5, 0",TextColor3=Color3.fromRGB(80,200,255),TextSize=10,Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Left},coordInfoRow)
mk("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=Color3.fromRGB(50,50,50),BorderSizePixel=0},coordInfoRow)
mkCoordRow(ord,"X",returnPos.X,function(v) setCoord("X",v); refreshCoordLbl(coordLbl2) end) ord+=1
mkCoordRow(ord,"Y",returnPos.Y,function(v) setCoord("Y",v); refreshCoordLbl(coordLbl2) end) ord+=1
mkCoordRow(ord,"Z",returnPos.Z,function(v) setCoord("Z",v); refreshCoordLbl(coordLbl2) end) ord+=1
mkButton(ord,"Взять мою позицию",function()
    local hrp=getHRP(); if not hrp then return end
    returnPos=hrp.Position; refreshCoordLbl(coordLbl2); placeMarker(returnPos)
end) ord+=1
mkButton(ord,"ТП на точку",function() teleportTo(returnPos) end) ord+=1
mkButton(ord,"Убрать маркер",function() removeMarker() end) ord+=1

-- ── МАРИОНЕТКА ────────────────────────────────────
mkSep(ord) ord+=1
mkCat(ord,"  Марионетка") ord+=1
mkToggle(ord,"Авто завод",false,function(v)
    musicboxAuto=v; if v then task.spawn(startMusicLoop) end
end) ord+=1
mkButton(ord,"Завести 1 раз",function() task.spawn(windMusicBox) end) ord+=1

-- ── АВТО ВЫХОД ────────────────────────────────────
mkSep(ord) ord+=1
mkCat(ord,"  Выход (6AM)") ord+=1
mkToggle(ord,"Авто выход",false,function(v)
    autoEscape=v; if v then startEscapeWatch() end
end) ord+=1
mkButton(ord,"Выйти сейчас",function() task.spawn(tryEscape) end) ord+=1

-- ── ИГРОК ─────────────────────────────────────────
mkSep(ord) ord+=1
mkCat(ord,"  Игрок") ord+=1
mkSlider(ord,"WalkSpeed",4,150,16,"",function(v)
    customSpeed=v; local hum=getHum(); if hum then hum.WalkSpeed=v end
end) ord+=1
mkSlider(ord,"FOV",60,120,80,"°",function(v)
    customFOV=v; workspace.CurrentCamera.FieldOfView=v
end) ord+=1
mkToggle(ord,"Block Ragdoll",false,function(v)
    ragdollBlock=v; if v then startRagdollBlock() end
end) ord+=1

-- ── СИСТЕМА ───────────────────────────────────────
mkSep(ord) ord+=1
mkCat(ord,"  Система") ord+=1
local unloadBtn=mk("TextButton",{LayoutOrder=ord,Size=UDim2.new(1,0,0,26),BackgroundColor3=Color3.fromRGB(55,18,18),BorderSizePixel=0,Text="[ UNLOAD ]",TextColor3=Color3.fromRGB(200,60,60),TextSize=12,Font=Enum.Font.SourceSansBold,AutoButtonColor=false},win)
unloadBtn.MouseEnter:Connect(function() unloadBtn.BackgroundColor3=Color3.fromRGB(85,22,22) end)
unloadBtn.MouseLeave:Connect(function() unloadBtn.BackgroundColor3=Color3.fromRGB(55,18,18) end)
unloadBtn.MouseButton1Click:Connect(function()
    cleaning=false; musicboxAuto=false; autoEscape=false
    ragdollBlock=false; pickupEnabled=false; espAnimOn=false; espPlayersOn=false
    customSpeed=nil; customFOV=nil
    workspace.CurrentCamera.FieldOfView=80
    local hum=getHum(); if hum then hum.WalkSpeed=16 end
    if escapeConn then escapeConn:Disconnect() end
    if ragdollConn then ragdollConn:Disconnect() end
    if eHeldConn  then eHeldConn:Disconnect()  end
    clearAllAnimESP()
    for p in pairs(playerESPData) do destroyPlayerESP(p) end
    removeMarker()
    hlFolder:Destroy(); animESPFolder:Destroy()
    sg:Destroy()
    print("[Script] Выгружен.")
end)

placeMarker(returnPos)
print("[Script] Загружен.")
