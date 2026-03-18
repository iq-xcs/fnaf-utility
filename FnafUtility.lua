-- ══════════════════════════════════════════════════
--   FNAF Utility Script
--   RightShift — показать/скрыть меню
-- ══════════════════════════════════════════════════

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local lp  = Players.LocalPlayer
local pg  = lp:WaitForChild("PlayerGui")
local cam = workspace.CurrentCamera

-- ══════════════════════════════════════════════════
--  НАСТРОЙКИ
-- ══════════════════════════════════════════════════

local CFG = {
    RETURN_POS       = Vector3.new(34, 4, 372),
    MUSIC_WARN_TIME  = 30,   -- секунд до предупреждения о марионетке
    DEFAULT_SPEED    = 16,
    DEFAULT_FOV      = 80,
    MENU_KEY         = Enum.KeyCode.RightShift,
}

-- ══════════════════════════════════════════════════
--  СОСТОЯНИЕ
-- ══════════════════════════════════════════════════

local ST = {
    returnPos     = CFG.RETURN_POS,
    customSpeed   = nil,
    customFOV     = nil,
    -- toggles
    cleaning      = false,
    pickupEnabled = false,
    musicboxAuto  = false,
    autoEscape    = false,
    ragdollBlock  = false,
    powerboxAuto  = false,
    fuseboxAuto   = false,
    espAnim       = false,
    espPlayers    = false,
    menuVisible   = true,
}

-- соединения
local CONN = {}

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

local function tpTo(pos, offset)
    local hrp = getHRP(); if not hrp then return end
    hrp.CFrame = CFrame.new(pos + (offset or Vector3.new(0, 3, 0)))
end

local function w2s(pos)
    local sp, inView = cam:WorldToViewportPoint(pos)
    return Vector2.new(sp.X, sp.Y), inView, sp.Z
end

local function disconnectAll(tbl)
    for k, c in pairs(tbl) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
        tbl[k] = nil
    end
end

local function getPromptPos(pp)
    local p = pp.Parent
    if p:IsA("BasePart") then return p.Position end
    if p:IsA("Model") then
        local ok, pos = pcall(function() return p:GetPivot().Position end)
        if ok then return pos end
    end
    return nil
end

local function tpAndFire(pp, offset)
    local pos = getPromptPos(pp)
    if pos then tpTo(pos, offset or Vector3.new(0, 3, 2)); task.wait(0.08) end
    pcall(function() fireproximityprompt(pp) end)
end

-- ══════════════════════════════════════════════════
--  СКОРОСТЬ / FOV
-- ══════════════════════════════════════════════════

CONN.speedFov = RunService.Heartbeat:Connect(function()
    if ST.customSpeed then
        local h = getHum(); if h then h.WalkSpeed = ST.customSpeed end
    end
    if ST.customFOV then
        cam.FieldOfView = ST.customFOV
    end
end)

lp.CharacterAdded:Connect(function()
    task.wait(0.5)
    if ST.customSpeed then local h=getHum(); if h then h.WalkSpeed=ST.customSpeed end end
end)

-- ══════════════════════════════════════════════════
--  RAGDOLL BLOCK
-- ══════════════════════════════════════════════════

local function hookRagdoll()
    local c = lp.Character; if not c then return end
    local values = c:FindFirstChild("Values")
    if not values then
        c.ChildAdded:Connect(function(ch)
            if ch.Name == "Values" then task.wait(0.1); hookRagdoll() end
        end)
        return
    end
    local ragVal = values:FindFirstChild("Ragdoll")
    if not ragVal then
        values.ChildAdded:Connect(function(ch)
            if ch.Name == "Ragdoll" then task.wait(0.05); hookRagdoll() end
        end)
        return
    end
    if CONN.ragdoll then CONN.ragdoll:Disconnect() end
    CONN.ragdoll = ragVal.Changed:Connect(function(val)
        if not ST.ragdollBlock or val ~= true then return end
        ragVal.Value = false
        local h = getHum()
        if h then h.PlatformStand=false; h:ChangeState(Enum.HumanoidStateType.GettingUp) end
    end)
    if ragVal.Value then ragVal.Value = false end
end

-- Heartbeat страховка
CONN.ragdollHB = RunService.Heartbeat:Connect(function()
    if not ST.ragdollBlock then return end
    local c=lp.Character; if not c then return end
    local v=c:FindFirstChild("Values"); if not v then return end
    local r=v:FindFirstChild("Ragdoll"); if not r then return end
    if r.Value then
        r.Value=false
        local h=getHum()
        if h then h.PlatformStand=false; h:ChangeState(Enum.HumanoidStateType.GettingUp) end
    end
end)

lp.CharacterAdded:Connect(function()
    task.wait(0.5); if ST.ragdollBlock then hookRagdoll() end
end)

-- ══════════════════════════════════════════════════
--  МАРКЕР ТОЧКИ ВОЗВРАТА
-- ══════════════════════════════════════════════════

local marker = nil

local function removeMarker()
    if marker and marker.Parent then marker:Destroy() end; marker=nil
end

local function placeMarker(pos)
    removeMarker()
    marker = Instance.new("Part")
    marker.Name="ReturnMarker"; marker.Size=Vector3.new(3,0.1,3)
    marker.CFrame=CFrame.new(pos.X, pos.Y-2.9, pos.Z)
    marker.Anchored=true; marker.CanCollide=false; marker.CanQuery=false
    marker.Material=Enum.Material.Neon
    marker.Color=Color3.fromRGB(80,200,255)
    marker.Transparency=0.3; marker.Parent=workspace

    local sel=Instance.new("SelectionBox",marker)
    sel.Adornee=marker; sel.Color3=Color3.fromRGB(80,200,255)
    sel.LineThickness=0.04; sel.SurfaceTransparency=1

    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not marker or not marker.Parent then conn:Disconnect(); return end
        marker.Transparency = 0.3 + 0.25*math.abs(math.sin(tick()*2))
    end)
end

placeMarker(ST.returnPos)

-- ══════════════════════════════════════════════════
--  МУСОР — авто уборка с телепортом
-- ══════════════════════════════════════════════════

local function getTrashFolder()
    local ok, f = pcall(function() return workspace.Map.Trash.CurrentTrash end)
    return ok and f or nil
end

local function getAllTrash()
    local results = {}
    local folder = getTrashFolder(); if not folder then return results end
    for _, obj in ipairs(folder:GetChildren()) do
        local pp = obj:FindFirstChild("CleanPrompt")
        if pp and pp:IsA("ProximityPrompt") then
            local pos
            if obj:IsA("BasePart") then pos=obj.Position
            elseif obj:IsA("Model") then pcall(function() pos=obj:GetPivot().Position end) end
            if pos then table.insert(results, {obj=obj, prompt=pp, pos=pos}) end
        end
    end
    return results
end

local function equipCleanTool()
    local hum=getHum(); if not hum then return end
    local tool = lp.Backpack:FindFirstChild("Cleaning tool")
        or (lp.Character and lp.Character:FindFirstChild("Cleaning tool"))
    if tool then hum:EquipTool(tool); task.wait(0.15) end
end

local function cleanAllTP()
    local hrp=getHRP(); if not hrp then return end
    equipCleanTool()
    local trash = getAllTrash()
    if #trash == 0 then print("[Trash] Нет мусора"); tpTo(ST.returnPos); return end
    table.sort(trash, function(a,b) return (a.pos-hrp.Position).Magnitude < (b.pos-hrp.Position).Magnitude end)
    for _, e in ipairs(trash) do
        if not ST.cleaning then break end
        if not e.obj or not e.obj.Parent then continue end
        tpTo(e.pos); task.wait(0.08)
        for i=1,5 do pcall(function() fireproximityprompt(e.prompt) end); task.wait(0.05) end
        task.wait(0.08)
    end
    print("[Trash] Готово"); tpTo(ST.returnPos)
end

local function startCleanLoop()
    task.spawn(function()
        while ST.cleaning do cleanAllTP(); task.wait(1.5) end
    end)
end

-- ══════════════════════════════════════════════════
--  МУСОР — подбор рядом без кд (E зажато)
-- ══════════════════════════════════════════════════

local function fireNearbyTrash()
    local hrp=getHRP(); if not hrp then return end
    for _, e in ipairs(getAllTrash()) do
        if (e.pos-hrp.Position).Magnitude <= e.prompt.MaxActivationDistance+3 then
            pcall(function() fireproximityprompt(e.prompt) end)
        end
    end
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp or not ST.pickupEnabled then return end
    if input.KeyCode == Enum.KeyCode.E then
        if CONN.eHeld then return end
        CONN.eHeld = RunService.Heartbeat:Connect(function()
            if not ST.pickupEnabled then
                CONN.eHeld:Disconnect(); CONN.eHeld=nil; return
            end
            fireNearbyTrash()
        end)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.E and CONN.eHeld then
        CONN.eHeld:Disconnect(); CONN.eHeld=nil
    end
end)

-- ══════════════════════════════════════════════════
--  МАРИОНЕТКА + ПРЕДУПРЕЖДЕНИЕ
-- ══════════════════════════════════════════════════

local musicLastWind  = 0   -- tick() последнего завода
local warnShown      = false
local warnGui        = nil

local function getMusicPrompt()
    local ok,pp=pcall(function() return workspace.Map.ImportantSpots.MusicBox.Prompt.Prompt end)
    if ok and pp and pp:IsA("ProximityPrompt") then return pp end
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.ActionText=="Wind" then return obj end
    end
end

local function windMusicBox()
    local hrp=getHRP(); if not hrp then return end
    local pp=getMusicPrompt(); if not pp then return end
    tpAndFire(pp)
    for i=1,19 do pcall(function() fireproximityprompt(pp) end); task.wait(0.05) end
    musicLastWind = tick()
    warnShown     = false
    if warnGui then warnGui:Destroy(); warnGui=nil end
    print("[MusicBox] Заведено")
end

-- предупреждение на экране
local function showMusicWarn()
    if warnShown then return end
    warnShown = true

    warnGui = Instance.new("ScreenGui")
    warnGui.Name="MusicWarn"; warnGui.ResetOnSpawn=false; warnGui.Parent=pg

    local frame = Instance.new("Frame", warnGui)
    frame.Size=UDim2.new(0,260,0,44)
    frame.Position=UDim2.new(0.5,-130,0,12)
    frame.BackgroundColor3=Color3.fromRGB(180,50,50)
    frame.BorderSizePixel=0

    local lbl = Instance.new("TextLabel", frame)
    lbl.Size=UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency=1
    lbl.Text="⚠ МАРИОНЕТКА! Заведи музыкальную шкатулку!"
    lbl.TextColor3=Color3.fromRGB(255,255,255)
    lbl.TextSize=13; lbl.Font=Enum.Font.SourceSansBold
    lbl.TextWrapped=true

    -- мигание
    local conn2
    conn2 = RunService.Heartbeat:Connect(function()
        if not warnGui or not warnGui.Parent then conn2:Disconnect(); return end
        frame.BackgroundTransparency = 0.3+0.3*math.abs(math.sin(tick()*3))
    end)
end

-- таймер предупреждения
CONN.musicWarnTimer = RunService.Heartbeat:Connect(function()
    if musicLastWind == 0 then return end
    local elapsed = tick() - musicLastWind
    if elapsed >= CFG.MUSIC_WARN_TIME and not warnShown then
        showMusicWarn()
    end
end)

local function startMusicLoop()
    task.spawn(function()
        while ST.musicboxAuto do windMusicBox(); task.wait(2) end
    end)
end

-- ══════════════════════════════════════════════════
--  POWERBOX
-- ══════════════════════════════════════════════════

local function getPowerPrompt()
    local ok,pp=pcall(function() return workspace.Map.ImportantSpots.PowerBox.Prompt.ProximityPrompt end)
    if ok and pp and pp:IsA("ProximityPrompt") then return pp end
end

local function repairPower()
    local pp=getPowerPrompt()
    if not pp or not pp.Enabled then return false end
    tpAndFire(pp)
    print("[PowerBox] Починен"); return true
end

local function startPowerWatch()
    if CONN.power then CONN.power:Disconnect() end
    local t=0
    CONN.power = RunService.Heartbeat:Connect(function(dt)
        if not ST.powerboxAuto then CONN.power:Disconnect(); CONN.power=nil; return end
        t+=dt; if t<1 then return end; t=0
        local pp=getPowerPrompt()
        if pp and pp.Enabled then repairPower() end
    end)
end

-- ══════════════════════════════════════════════════
--  FUSEBOXES
-- ══════════════════════════════════════════════════

local function getAllFuses()
    local results={}
    local ok,folder=pcall(function() return workspace.Map.ImportantSpots.FuseBoxes end)
    if not ok or not folder then return results end
    for _,child in ipairs(folder:GetChildren()) do
        for _,pp in ipairs(child:GetDescendants()) do
            if pp:IsA("ProximityPrompt") and pp.ActionText=="Turn On" and pp.Enabled then
                local part=pp.Parent
                if part:IsA("BasePart") then
                    table.insert(results, {prompt=pp, pos=part.Position, name=child.Name})
                end
            end
        end
    end
    return results
end

local function activateFuses()
    local hrp=getHRP(); if not hrp then return end
    local fuses=getAllFuses()
    if #fuses==0 then return end
    print("[FuseBox] Включаем:", #fuses)
    for _,e in ipairs(fuses) do
        if not ST.fuseboxAuto then break end
        tpTo(e.pos); task.wait(0.08)
        pcall(function() fireproximityprompt(e.prompt) end)
        task.wait(0.08)
        print("[FuseBox]", e.name)
    end
    tpTo(ST.returnPos)
end

local function startFuseWatch()
    if CONN.fuse then CONN.fuse:Disconnect() end
    local t=0
    CONN.fuse = RunService.Heartbeat:Connect(function(dt)
        if not ST.fuseboxAuto then CONN.fuse:Disconnect(); CONN.fuse=nil; return end
        t+=dt; if t<2 then return end; t=0
        if #getAllFuses()>0 then task.spawn(activateFuses) end
    end)
end

-- ══════════════════════════════════════════════════
--  АВТО ВЫХОД
-- ══════════════════════════════════════════════════

local function getEndPrompt()
    local ok,pp=pcall(function() return workspace.Map.ImportantSpots.EndPos.ProximityPrompt end)
    if ok and pp and pp:IsA("ProximityPrompt") then return pp end
end

local function tryEscape()
    local pp=getEndPrompt(); if not pp or pp.Enabled==false then return false end
    tpAndFire(pp, Vector3.new(0,3,4))
    print("[Escape] Выход!"); return true
end

local function startEscapeWatch()
    if CONN.escape then CONN.escape:Disconnect() end
    local t=0
    CONN.escape = RunService.Heartbeat:Connect(function(dt)
        if not ST.autoEscape then CONN.escape:Disconnect(); CONN.escape=nil; return end
        t+=dt; if t<1 then return end; t=0
        local pp=getEndPrompt()
        if pp and pp.Enabled~=false then tryEscape() end
    end)
end

-- ══════════════════════════════════════════════════
--  ESP АНИМАТРОНИКИ
-- ══════════════════════════════════════════════════

local ANIM_COLORS = {
    Freddy          = Color3.fromRGB(139, 90,  43),
    Bonnie          = Color3.fromRGB(60,  80,  200),
    Chica           = Color3.fromRGB(230, 200, 30),
    Foxy            = Color3.fromRGB(210, 100, 30),
    ["Toy Freddy"]  = Color3.fromRGB(180, 120, 60),
    ["Toy Bonnie"]  = Color3.fromRGB(100, 160, 230),
    ["Toy Chica"]   = Color3.fromRGB(255, 220, 60),
    ["Withered Freddy"] = Color3.fromRGB(100, 65, 30),
    ["Withered Foxy"]   = Color3.fromRGB(160, 75, 20),
    Puppet          = Color3.fromRGB(220, 220, 220),
    Feddy           = Color3.fromRGB(139, 90,  43),
}
local ANIM_DEFAULT_COLOR = Color3.fromRGB(200,200,200)

local animESPData = {}  -- [model] = { lines={}, nameLabel }

local function makeAnimESP(model)
    if animESPData[model] then return end
    local color = ANIM_COLORS[model.Name] or ANIM_DEFAULT_COLOR

    local lines={}
    for i=1,4 do
        local l=Drawing.new("Line")
        l.Thickness=1.5; l.Color=color; l.Transparency=1
        l.Visible=false; l.ZIndex=2
        lines[i]=l
    end

    local txt=Drawing.new("Text")
    txt.Text=model.Name; txt.Color=color; txt.Size=14
    txt.Font=Drawing.Fonts.UI; txt.Outline=true
    txt.OutlineColor=Color3.new(0,0,0); txt.Visible=false; txt.ZIndex=3

    animESPData[model]={lines=lines, nameLabel=txt, color=color}
end

local function removeAnimESP(model)
    local d=animESPData[model]; if not d then return end
    for _,l in ipairs(d.lines) do pcall(function() l:Remove() end) end
    pcall(function() d.nameLabel:Remove() end)
    animESPData[model]=nil
end

local function clearAnimESP()
    for m in pairs(animESPData) do removeAnimESP(m) end
end

local function refreshAnimESP()
    clearAnimESP()
    if not ST.espAnim then return end
    local folder=workspace:FindFirstChild("Animatronics"); if not folder then return end
    for _,m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") then makeAnimESP(m) end
    end
end

CONN.animESP = RunService.Heartbeat:Connect(function()
    if not ST.espAnim then
        for _,d in pairs(animESPData) do
            for _,l in ipairs(d.lines) do l.Visible=false end
            d.nameLabel.Visible=false
        end
        return
    end
    for model, d in pairs(animESPData) do
        if not model or not model.Parent then removeAnimESP(model); continue end
        local ok, cf, sz = pcall(function() return model:GetBoundingBox() end)
        if not ok then continue end
        local c=cf.Position
        local hx,hy,hz=sz.X/2,sz.Y/2,sz.Z/2
        local corners={
            c+Vector3.new( hx, hy, hz), c+Vector3.new(-hx, hy, hz),
            c+Vector3.new( hx,-hy, hz), c+Vector3.new(-hx,-hy, hz),
            c+Vector3.new( hx, hy,-hz), c+Vector3.new(-hx, hy,-hz),
            c+Vector3.new( hx,-hy,-hz), c+Vector3.new(-hx,-hy,-hz),
        }
        local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
        local anyVis=false
        for _,corner in ipairs(corners) do
            local sp,inView,depth=w2s(corner)
            if inView and depth>0 then
                anyVis=true
                if sp.X<minX then minX=sp.X end; if sp.Y<minY then minY=sp.Y end
                if sp.X>maxX then maxX=sp.X end; if sp.Y>maxY then maxY=sp.Y end
            end
        end
        if not anyVis then
            for _,l in ipairs(d.lines) do l.Visible=false end
            d.nameLabel.Visible=false; continue
        end
        local x0,y0,x1,y1=minX-2,minY-2,maxX+2,maxY+2
        local sides={{Vector2.new(x0,y0),Vector2.new(x1,y0)},{Vector2.new(x0,y1),Vector2.new(x1,y1)},
                     {Vector2.new(x0,y0),Vector2.new(x0,y1)},{Vector2.new(x1,y0),Vector2.new(x1,y1)}}
        for i,s in ipairs(sides) do
            d.lines[i].From=s[1]; d.lines[i].To=s[2]
            d.lines[i].Color=d.color; d.lines[i].Visible=true
        end
        d.nameLabel.Position=Vector2.new((x0+x1)/2-#model.Name*3.5, y0-18)
        d.nameLabel.Visible=true
    end
end)

local animFolder=workspace:FindFirstChild("Animatronics")
if animFolder then
    animFolder.ChildAdded:Connect(function(o) if ST.espAnim and o:IsA("Model") then makeAnimESP(o) end end)
    animFolder.ChildRemoved:Connect(function(o) removeAnimESP(o) end)
end

-- ══════════════════════════════════════════════════
--  ESP ИГРОКИ
-- ══════════════════════════════════════════════════

local hlFolder=Instance.new("Folder"); hlFolder.Name="PlayerESP"; hlFolder.Parent=pg
local playerESP={}
local P_COLOR=Color3.fromRGB(80,200,255)

local function makePlayerHL(char)
    local h=Instance.new("Highlight")
    h.Adornee=char; h.OutlineColor=P_COLOR; h.FillColor=P_COLOR
    h.FillTransparency=0.7; h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent=hlFolder; return h
end

local function makePlayerBB(p,char)
    local head=char:FindFirstChild("Head") or char:FindFirstChildWhichIsA("BasePart")
    if not head then return nil end
    local bg=Instance.new("BillboardGui")
    bg.Adornee=head; bg.Size=UDim2.new(0,120,0,50)
    bg.StudsOffset=Vector3.new(0,3.5,0); bg.AlwaysOnTop=true
    bg.ResetOnSpawn=false; bg.Parent=hlFolder

    local icon=Instance.new("ImageLabel",bg)
    icon.Size=UDim2.new(0,30,0,30); icon.Position=UDim2.new(0,0,0.5,-15)
    icon.BackgroundColor3=Color3.fromRGB(20,20,20); icon.BorderSizePixel=1
    icon.BorderColor3=P_COLOR
    local ok,thumb=pcall(function()
        return Players:GetUserThumbnailAsync(p.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size60x60)
    end)
    icon.Image=ok and thumb or ""

    local function lbl(props)
        local l=Instance.new("TextLabel",bg)
        for k,v in pairs(props) do l[k]=v end
        l.BackgroundTransparency=1; l.TextStrokeTransparency=0.4
        l.TextStrokeColor3=Color3.new(0,0,0); return l
    end
    local nameLbl=lbl{Size=UDim2.new(1,-36,0,18),Position=UDim2.new(0,34,0,5),
        Text=p.DisplayName,TextColor3=P_COLOR,TextSize=13,Font=Enum.Font.SourceSansBold,
        TextXAlignment=Enum.TextXAlignment.Left}
    local distLbl=lbl{Size=UDim2.new(1,-36,0,14),Position=UDim2.new(0,34,0,24),
        Text="",TextColor3=Color3.fromRGB(180,180,180),TextSize=11,Font=Enum.Font.SourceSans,
        TextXAlignment=Enum.TextXAlignment.Left}
    return {gui=bg,distLbl=distLbl}
end

local function buildPlayerESP(p)
    if playerESP[p] or p==lp then return end
    local char=p.Character; if not char then return end
    local data={hl=makePlayerHL(char)}
    local bb=makePlayerBB(p,char)
    if bb then data.gui=bb.gui; data.distLbl=bb.distLbl end
    playerESP[p]=data
end

local function destroyPlayerESP(p)
    local d=playerESP[p]; if not d then return end
    if d.hl  then d.hl:Destroy()  end
    if d.gui then d.gui:Destroy() end
    playerESP[p]=nil
end

local function rebuildPlayerESP()
    for p in pairs(playerESP) do destroyPlayerESP(p) end
    if not ST.espPlayers then return end
    for _,p in ipairs(Players:GetPlayers()) do buildPlayerESP(p) end
end

CONN.playerESP = RunService.Heartbeat:Connect(function()
    if not ST.espPlayers then return end
    local myHRP=getHRP()
    for p,d in pairs(playerESP) do
        if not p or not p.Parent then destroyPlayerESP(p); continue end
        local char=p.Character; if not char then continue end
        if not d.hl or not d.hl.Parent or d.hl.Adornee~=char then
            if d.hl then d.hl:Destroy() end
            d.hl=makePlayerHL(char)
        end
        if d.distLbl and myHRP then
            local hrp=char:FindFirstChild("HumanoidRootPart")
            if hrp then d.distLbl.Text=math.floor((hrp.Position-myHRP.Position).Magnitude).." st" end
        end
    end
end)

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.3); destroyPlayerESP(p)
        if ST.espPlayers then buildPlayerESP(p) end
    end)
end)
Players.PlayerRemoving:Connect(function(p) destroyPlayerESP(p) end)
for _,p in ipairs(Players:GetPlayers()) do
    p.CharacterAdded:Connect(function()
        task.wait(0.3); destroyPlayerESP(p)
        if ST.espPlayers then buildPlayerESP(p) end
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

Instance.new("UIListLayout",win).SortOrder=Enum.SortOrder.LayoutOrder

-- hotkey показа/скрытия
UserInputService.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode==CFG.MENU_KEY then
        ST.menuVisible=not ST.menuVisible
        win.Visible=ST.menuVisible
    end
end)

-- ── GUI helpers ───────────────────────────────────

local function mk(class,props,parent)
    local o=Instance.new(class,parent)
    for k,v in pairs(props) do o[k]=v end
    return o
end

local function mkCat(order,text)
    local f=mk("Frame",{LayoutOrder=order,Size=UDim2.new(1,0,0,18),
        BackgroundColor3=Color3.fromRGB(22,22,22),BorderSizePixel=0},win)
    mk("TextLabel",{Size=UDim2.new(1,-8,1,0),Position=UDim2.new(0,8,0,0),
        BackgroundTransparency=1,Text=text,TextColor3=Color3.fromRGB(105,105,105),
        TextSize=11,Font=Enum.Font.SourceSansBold,
        TextXAlignment=Enum.TextXAlignment.Left},f)
    mk("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),
        BackgroundColor3=Color3.fromRGB(50,50,50),BorderSizePixel=0},f)
end

local function mkSep(order)
    mk("Frame",{LayoutOrder=order,Size=UDim2.new(1,0,0,1),
        BackgroundColor3=Color3.fromRGB(50,50,50),BorderSizePixel=0},win)
end

local function mkToggle(order,label,init,cb)
    local ON=Color3.fromRGB(78,170,78); local ONB=Color3.fromRGB(28,65,28)
    local OF=Color3.fromRGB(170,52,52); local OFB=Color3.fromRGB(64,20,20)
    local row=mk("Frame",{LayoutOrder=order,Size=UDim2.new(1,0,0,28),
        BackgroundColor3=Color3.fromRGB(36,36,36),BorderSizePixel=0},win)
    mk("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),
        BackgroundColor3=Color3.fromRGB(62,62,62),BorderSizePixel=0},row)
    local dot=mk("Frame",{Size=UDim2.new(0,6,0,6),Position=UDim2.new(0,8,0.5,-3),
        BackgroundColor3=init and ON or OF,BorderSizePixel=0},row)
    mk("TextLabel",{Size=UDim2.new(1,-110,1,0),Position=UDim2.new(0,22,0,0),
        BackgroundTransparency=1,Text=label,TextColor3=Color3.fromRGB(215,215,215),
        TextSize=13,Font=Enum.Font.SourceSans,
        TextXAlignment=Enum.TextXAlignment.Left},row)
    local btn=mk("TextButton",{Size=UDim2.new(0,54,0,17),Position=UDim2.new(1,-62,0.5,-8),
        BackgroundColor3=init and ONB or OFB,BorderColor3=init and ON or OF,
        BorderSizePixel=1,Text=init and "ON" or "OFF",TextColor3=init and ON or OF,
        TextSize=11,Font=Enum.Font.SourceSansBold,AutoButtonColor=false},row)
    row.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseMovement then
            row.BackgroundColor3=Color3.fromRGB(44,44,44) end end)
    row.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseMovement then
            row.BackgroundColor3=Color3.fromRGB(36,36,36) end end)
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
    local btn=mk("TextButton",{LayoutOrder=order,Size=UDim2.new(1,0,0,28),
        BackgroundColor3=Color3.fromRGB(36,36,36),BorderSizePixel=0,
        Text="",AutoButtonColor=false},win)
    mk("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),
        BackgroundColor3=Color3.fromRGB(62,62,62),BorderSizePixel=0},btn)
    mk("TextLabel",{Size=UDim2.new(0,14,1,0),Position=UDim2.new(0,8,0,0),
        BackgroundTransparency=1,Text=">",TextColor3=Color3.fromRGB(190,150,50),
        TextSize=13,Font=Enum.Font.SourceSansBold},btn)
    mk("TextLabel",{Size=UDim2.new(1,-26,1,0),Position=UDim2.new(0,22,0,0),
        BackgroundTransparency=1,Text=label,TextColor3=Color3.fromRGB(215,215,215),
        TextSize=13,Font=Enum.Font.SourceSans,
        TextXAlignment=Enum.TextXAlignment.Left},btn)
    btn.MouseEnter:Connect(function() btn.BackgroundColor3=Color3.fromRGB(44,44,44) end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3=Color3.fromRGB(36,36,36) end)
    btn.MouseButton1Click:Connect(cb)
end

local function mkSlider(order,label,min,max,default,unit,cb)
    local row=mk("Frame",{LayoutOrder=order,Size=UDim2.new(1,0,0,44),
        BackgroundColor3=Color3.fromRGB(36,36,36),BorderSizePixel=0},win)
    mk("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),
        BackgroundColor3=Color3.fromRGB(62,62,62),BorderSizePixel=0},row)
    mk("Frame",{Size=UDim2.new(0,6,0,6),Position=UDim2.new(0,8,0,9),
        BackgroundColor3=Color3.fromRGB(190,150,50),BorderSizePixel=0},row)
    mk("TextLabel",{Size=UDim2.new(1,-80,0,16),Position=UDim2.new(0,22,0,3),
        BackgroundTransparency=1,Text=label,TextColor3=Color3.fromRGB(215,215,215),
        TextSize=13,Font=Enum.Font.SourceSans,
        TextXAlignment=Enum.TextXAlignment.Left},row)
    local valLbl=mk("TextLabel",{Size=UDim2.new(0,54,0,16),Position=UDim2.new(1,-60,0,3),
        BackgroundTransparency=1,Text=tostring(default)..(unit or ""),
        TextColor3=Color3.fromRGB(190,150,50),TextSize=12,Font=Enum.Font.SourceSansBold,
        TextXAlignment=Enum.TextXAlignment.Right},row)
    local track=mk("Frame",{Size=UDim2.new(1,-20,0,5),Position=UDim2.new(0,12,0,32),
        BackgroundColor3=Color3.fromRGB(20,20,20),
        BorderColor3=Color3.fromRGB(65,65,65),BorderSizePixel=1},row)
    local p0=math.clamp((default-min)/(max-min),0,1)
    local fill=mk("Frame",{Size=UDim2.new(p0,0,1,0),
        BackgroundColor3=Color3.fromRGB(190,150,50),BorderSizePixel=0},track)
    local knob=mk("Frame",{Size=UDim2.new(0,2,1,4),Position=UDim2.new(p0,-1,0,-2),
        BackgroundColor3=Color3.fromRGB(210,210,210),BorderSizePixel=0,ZIndex=3},track)
    local cur=default; local drag=false
    local function upd(mx)
        local ap=track.AbsolutePosition; local as=track.AbsoluteSize
        local p=math.clamp((mx-ap.X)/as.X,0,1)
        cur=math.floor(min+p*(max-min))
        fill.Size=UDim2.new(p,0,1,0); knob.Position=UDim2.new(p,-1,0,-2)
        valLbl.Text=tostring(cur)..(unit or ""); if cb then cb(cur) end
    end
    local hit=mk("TextButton",{Size=UDim2.new(1,0,4,0),Position=UDim2.new(0,0,-1.5,0),
        BackgroundTransparency=1,Text="",ZIndex=5},track)
    hit.MouseButton1Down:Connect(function(x) drag=true; upd(x) end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then upd(i.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
    end)
end

local function mkCoordRow(order,axis,initVal,onChange)
    local axCol = axis=="X" and Color3.fromRGB(220,80,80)
        or axis=="Y" and Color3.fromRGB(80,200,80)
        or Color3.fromRGB(80,120,220)
    local row=mk("Frame",{LayoutOrder=order,Size=UDim2.new(1,0,0,28),
        BackgroundColor3=Color3.fromRGB(36,36,36),BorderSizePixel=0},win)
    mk("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),
        BackgroundColor3=Color3.fromRGB(62,62,62),BorderSizePixel=0},row)
    mk("Frame",{Size=UDim2.new(0,6,0,6),Position=UDim2.new(0,8,0.5,-3),
        BackgroundColor3=axCol,BorderSizePixel=0},row)
    mk("TextLabel",{Size=UDim2.new(0,18,1,0),Position=UDim2.new(0,20,0,0),
        BackgroundTransparency=1,Text=axis,TextColor3=axCol,
        TextSize=13,Font=Enum.Font.SourceSansBold},row)
    local box=mk("TextBox",{Size=UDim2.new(1,-80,0,17),Position=UDim2.new(0,40,0.5,-8),
        BackgroundColor3=Color3.fromRGB(20,20,20),BorderColor3=Color3.fromRGB(65,65,65),
        BorderSizePixel=1,Text=tostring(math.floor(initVal)),
        TextColor3=Color3.fromRGB(215,215,215),TextSize=12,Font=Enum.Font.SourceSans,
        ClearTextOnFocus=false},row)
    local getBtn=mk("TextButton",{Size=UDim2.new(0,32,0,17),Position=UDim2.new(1,-36,0.5,-8),
        BackgroundColor3=Color3.fromRGB(30,55,30),BorderColor3=Color3.fromRGB(60,110,60),
        BorderSizePixel=1,Text="Get",TextColor3=Color3.fromRGB(100,200,100),
        TextSize=10,Font=Enum.Font.SourceSansBold,AutoButtonColor=false},row)
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
    local r=ST.returnPos
    if axis=="X" then ST.returnPos=Vector3.new(val,r.Y,r.Z)
    elseif axis=="Y" then ST.returnPos=Vector3.new(r.X,val,r.Z)
    else ST.returnPos=Vector3.new(r.X,r.Y,val) end
    placeMarker(ST.returnPos)
end

-- ══ ЗАПОЛНЕНИЕ МЕНЮ ═══════════════════════════════

-- шапка
local hdr=mk("Frame",{LayoutOrder=0,Size=UDim2.new(1,0,0,22),
    BackgroundColor3=Color3.fromRGB(45,45,45),BorderSizePixel=0},win)
mk("TextLabel",{Size=UDim2.new(1,-8,1,0),Position=UDim2.new(0,6,0,0),
    BackgroundTransparency=1,Text="[FL] FNAF Utility  ["..tostring(CFG.MENU_KEY.Name).."]",
    TextColor3=Color3.fromRGB(215,215,215),TextSize=13,Font=Enum.Font.SourceSansBold,
    TextXAlignment=Enum.TextXAlignment.Left},hdr)
mk("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,0),
    BackgroundColor3=Color3.fromRGB(62,62,62),BorderSizePixel=0},hdr)

-- live позиция
local posRow=mk("Frame",{LayoutOrder=1,Size=UDim2.new(1,0,0,16),
    BackgroundColor3=Color3.fromRGB(20,20,20),BorderSizePixel=0},win)
local posLbl=mk("TextLabel",{Size=UDim2.new(1,-8,1,0),Position=UDim2.new(0,6,0,0),
    BackgroundTransparency=1,Text="Pos: 0, 0, 0",TextColor3=Color3.fromRGB(80,200,255),
    TextSize=10,Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Left},posRow)
mk("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),
    BackgroundColor3=Color3.fromRGB(50,50,50),BorderSizePixel=0},posRow)

local posTimer=0
CONN.posUpdate=RunService.Heartbeat:Connect(function(dt)
    posTimer+=dt; if posTimer<0.2 then return end; posTimer=0
    local hrp=getHRP()
    if hrp then
        local p=hrp.Position
        posLbl.Text=string.format("Pos: %.0f, %.0f, %.0f",p.X,p.Y,p.Z)
    end
end)

local ord=2

-- ── 1. ESP ────────────────────────────────────────
mkSep(ord) ord+=1
mkCat(ord,"  1. ESP") ord+=1
mkToggle(ord,"Аниматроники ESP",false,function(v)
    ST.espAnim=v; refreshAnimESP()
end) ord+=1
mkToggle(ord,"Игроки ESP",false,function(v)
    ST.espPlayers=v; rebuildPlayerESP()
end) ord+=1

-- ── 2. МУСОР ─────────────────────────────────────
mkSep(ord) ord+=1
mkCat(ord,"  2. Мусор") ord+=1
mkToggle(ord,"Авто уборка + ТП",false,function(v)
    ST.cleaning=v; if v then task.spawn(startCleanLoop) end
end) ord+=1
mkButton(ord,"Убрать 1 раз",function() task.spawn(cleanAllTP) end) ord+=1
mkToggle(ord,"Подбор рядом [E]",false,function(v)
    ST.pickupEnabled=v
    if not v and CONN.eHeld then CONN.eHeld:Disconnect(); CONN.eHeld=nil end
end) ord+=1

-- ── 3. ТОЧКА ВОЗВРАТА ─────────────────────────────
mkSep(ord) ord+=1
mkCat(ord,"  3. Точка возврата") ord+=1
local coordInfoRow=mk("Frame",{LayoutOrder=ord,Size=UDim2.new(1,0,0,16),
    BackgroundColor3=Color3.fromRGB(20,20,20),BorderSizePixel=0},win) ord+=1
local coordLbl=mk("TextLabel",{Size=UDim2.new(1,-8,1,0),Position=UDim2.new(0,6,0,0),
    BackgroundTransparency=1,
    Text=string.format("Return: %.0f, %.0f, %.0f",ST.returnPos.X,ST.returnPos.Y,ST.returnPos.Z),
    TextColor3=Color3.fromRGB(80,200,255),TextSize=10,Font=Enum.Font.Code,
    TextXAlignment=Enum.TextXAlignment.Left},coordInfoRow)
mk("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),
    BackgroundColor3=Color3.fromRGB(50,50,50),BorderSizePixel=0},coordInfoRow)

local function refreshCoordLbl()
    coordLbl.Text=string.format("Return: %.0f, %.0f, %.0f",ST.returnPos.X,ST.returnPos.Y,ST.returnPos.Z)
end

mkCoordRow(ord,"X",ST.returnPos.X,function(v) setCoord("X",v); refreshCoordLbl() end) ord+=1
mkCoordRow(ord,"Y",ST.returnPos.Y,function(v) setCoord("Y",v); refreshCoordLbl() end) ord+=1
mkCoordRow(ord,"Z",ST.returnPos.Z,function(v) setCoord("Z",v); refreshCoordLbl() end) ord+=1
mkButton(ord,"Взять мою позицию",function()
    local hrp=getHRP(); if not hrp then return end
    ST.returnPos=hrp.Position; refreshCoordLbl(); placeMarker(ST.returnPos)
end) ord+=1
mkButton(ord,"ТП на точку",function() tpTo(ST.returnPos) end) ord+=1
mkButton(ord,"Убрать маркер",function() removeMarker() end) ord+=1

-- ── 4. МАРИОНЕТКА ─────────────────────────────────
mkSep(ord) ord+=1
mkCat(ord,"  4. Марионетка (Music Box)") ord+=1
mkToggle(ord,"Авто завод",false,function(v)
    ST.musicboxAuto=v; if v then task.spawn(startMusicLoop) end
end) ord+=1
mkButton(ord,"Завести 1 раз",function() task.spawn(windMusicBox) end) ord+=1

-- ── 5. ВЫХОД ──────────────────────────────────────
mkSep(ord) ord+=1
mkCat(ord,"  5. Выход из пиццерии (6AM)") ord+=1
mkToggle(ord,"Авто выход",false,function(v)
    ST.autoEscape=v; if v then startEscapeWatch() end
end) ord+=1
mkButton(ord,"Выйти сейчас",function() task.spawn(tryEscape) end) ord+=1

-- ── 6. ГЕНЕРАТОР / ПРЕДОХРАНИТЕЛИ ─────────────────
mkSep(ord) ord+=1
mkCat(ord,"  6. Генератор и предохранители") ord+=1
mkToggle(ord,"Авто починка PowerBox",false,function(v)
    ST.powerboxAuto=v; if v then startPowerWatch() end
end) ord+=1
mkButton(ord,"Починить PowerBox (1 раз)",function() task.spawn(repairPower) end) ord+=1
mkToggle(ord,"Авто включение FuseBox",false,function(v)
    ST.fuseboxAuto=v; if v then startFuseWatch() end
end) ord+=1
mkButton(ord,"Включить все FuseBox (1 раз)",function() task.spawn(activateFuses) end) ord+=1

-- ── 7. ИГРОК ──────────────────────────────────────
mkSep(ord) ord+=1
mkCat(ord,"  7. Игрок") ord+=1
mkSlider(ord,"WalkSpeed",4,150,CFG.DEFAULT_SPEED,"",function(v)
    ST.customSpeed=v; local h=getHum(); if h then h.WalkSpeed=v end
end) ord+=1
mkSlider(ord,"FOV",60,120,CFG.DEFAULT_FOV,"°",function(v)
    ST.customFOV=v; cam.FieldOfView=v
end) ord+=1
mkToggle(ord,"Block Ragdoll",false,function(v)
    ST.ragdollBlock=v; if v then hookRagdoll() end
end) ord+=1

-- ── 8. СИСТЕМА ────────────────────────────────────
mkSep(ord) ord+=1
mkCat(ord,"  8. Система") ord+=1

local unloadBtn=mk("TextButton",{LayoutOrder=ord,Size=UDim2.new(1,0,0,26),
    BackgroundColor3=Color3.fromRGB(55,18,18),BorderSizePixel=0,
    Text="[ UNLOAD ]",TextColor3=Color3.fromRGB(200,60,60),
    TextSize=12,Font=Enum.Font.SourceSansBold,AutoButtonColor=false},win)
unloadBtn.MouseEnter:Connect(function() unloadBtn.BackgroundColor3=Color3.fromRGB(85,22,22) end)
unloadBtn.MouseLeave:Connect(function() unloadBtn.BackgroundColor3=Color3.fromRGB(55,18,18) end)
unloadBtn.MouseButton1Click:Connect(function()
    -- сбрасываем всё
    for k in pairs(ST) do
        if type(ST[k])=="boolean" then ST[k]=false end
    end
    ST.customSpeed=nil; ST.customFOV=nil

    cam.FieldOfView=CFG.DEFAULT_FOV
    local h=getHum(); if h then h.WalkSpeed=CFG.DEFAULT_SPEED end

    disconnectAll(CONN)
    clearAnimESP()
    for p in pairs(playerESP) do destroyPlayerESP(p) end
    removeMarker()
    if warnGui then warnGui:Destroy(); warnGui=nil end
    hlFolder:Destroy()
    sg:Destroy()
    print("[Script] Выгружен.")
end)

print("[Script] Загружен. "..tostring(CFG.MENU_KEY.Name).." — меню")
print("[Script] Точка возврата: 34, 4, 372")
