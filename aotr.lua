-- ================================================================
-- Tekkit Hub | WindUI Edition
-- Rewritten: raw Instance UI → WindUI, all bugs fixed
-- ================================================================

-- Wait for game to load
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- ================================================================
-- Pre-flight checks: wait for character, titans, and refill
-- ================================================================
local function earlyNotify(title, text)
    game:GetService("StarterGui"):SetCore("SendNotification", { Title = title, Text = text })
end

-- Wait for character main part
while task.wait(1) do
    if not pcall(function()
        return game.Players.LocalPlayer.Character.Main.W
    end) then
        earlyNotify("Not in mission", "Player not found, join a mission.")
    else
        task.wait(0.2)
        break
    end
end

-- Wait for titans
while task.wait(1) do
    if not pcall(function()
        return game.Workspace.Titans:FindFirstChildOfClass("Model").Fake.Head.Header
    end) then
        earlyNotify("Not in mission", "Titans not found, join a mission.")
    else
        task.wait(0.2)
        break
    end
end

-- Wait for gas refill station
while task.wait(0.2) do
    if pcall(function()
        return game.Workspace.Unclimbable.Reloads:FindFirstChild("GasTanks"):FindFirstChild("Refill")
    end) then
        task.wait(0.2)
        break
    end
end

-- ================================================================
-- Load WindUI
-- ================================================================
local cloneref = (cloneref or clonereference or function(i) return i end)
local WindUI
do
    local ok, result = pcall(function() return require("./src/Init") end)
    if ok then
        WindUI = result
    elseif cloneref(game:GetService("RunService")):IsStudio() then
        WindUI = require(cloneref(
            game:GetService("ReplicatedStorage"):WaitForChild("WindUI"):WaitForChild("Init")
        ))
    else
        WindUI = loadstring(
            game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua")
        )()
    end
end

-- ================================================================
-- Game State Table
-- ================================================================
local lp = game.Players.LocalPlayer
local char = lp.Character

local v4 = {
    player          = lp,
    playerName      = lp.Name,
    character       = char,
    root            = char:WaitForChild("HumanoidRootPart"),
    humanoid        = char:FindFirstChildOfClass("Humanoid"),
    blade           = char:WaitForChild("Rig_" .. lp.Name):WaitForChild("LeftHand"):WaitForChild("Blade_1"),
    bladebox        = char:WaitForChild("Main"),
    injuryFolder    = char:WaitForChild("Injuries"),
    buttonsFolder   = lp:WaitForChild("PlayerGui"):WaitForChild("Interface"):WaitForChild("Buttons"),
    hotbar          = lp:WaitForChild("PlayerGui"):WaitForChild("Interface"):WaitForChild("HUD")
                        :WaitForChild("Main"):WaitForChild("Top"):WaitForChild("Hotbar"),
    titans          = game.Workspace:WaitForChild("Titans"),
    UIP             = game:GetService("UserInputService"),
    Mouse           = lp:GetMouse(),

    -- Feature toggles (defaults; overridden by saved data below)
    espEnabled      = false,
    extendEnabled   = false,
    napeVisible     = true,
    bladeEnabled    = false,
    injuryEnabled   = false,
    escapeEnabled   = false,
    ripperEnabled   = false,
    autofarmEnabled = false,
    oldfarmEnabled  = false,
    erenExtend      = false,
    extendMulti     = 1,

    -- Runtime refs
    hovering        = false,
    atmosphere      = game.Lighting.Atmosphere,
    attacktitan     = nil,
    marker          = nil,
    leftleg         = nil,
    rightleg        = nil,
    leftarm         = nil,
    rightarm        = nil,
    eyes            = nil,
    nape            = nil,
    cooldownT       = nil,
    cooldownS       = nil,
    cooldownR       = nil,

    -- Passed is always true (premium check)
    passed          = true,

    -- Remotes
    remotePost      = game.ReplicatedStorage.Assets.Remotes:WaitForChild("POST"),
    remoteGet       = game.ReplicatedStorage.Assets.Remotes:WaitForChild("GET"),
    refill          = game.Workspace.Unclimbable.Reloads:FindFirstChild("GasTanks"):FindFirstChild("Refill"),
}

-- ================================================================
-- Save / Load Variables
-- ================================================================
local SAVE_FOLDER = "workspace"

local function saveVariables(folder, data)
    if not writefile then
        warn("[TekkitHub] writefile is not available; settings won't persist.")
        return
    end
    writefile(folder .. "/savedVariables.txt", game:GetService("HttpService"):JSONEncode(data))
end

local function loadVariables(folder)
    local path = folder .. "/savedVariables.txt"
    if not isfile or not isfile(path) then return {} end
    if not readfile then return {} end
    local ok, result = pcall(function()
        return game:GetService("HttpService"):JSONDecode(readfile(path))
    end)
    if ok then return result end
    saveVariables(folder, {})
    return {}
end

if not isfolder(SAVE_FOLDER) and makefolder then
    makefolder(SAVE_FOLDER)
end

local saved = loadVariables(SAVE_FOLDER)

-- Apply saved values (fall back to defaults if nil)
local function applySaved(key, default)
    return saved[key] ~= nil and saved[key] or default
end

v4.espEnabled      = applySaved("espEnabled",      v4.espEnabled)
v4.extendEnabled   = applySaved("extendEnabled",   v4.extendEnabled)
v4.escapeEnabled   = applySaved("escapeEnabled",   v4.escapeEnabled)
v4.bladeEnabled    = applySaved("bladeEnabled",    v4.bladeEnabled)
v4.extendMulti     = applySaved("extendMulti",     v4.extendMulti)
v4.napeVisible     = applySaved("napeVisible",     v4.napeVisible)
v4.erenExtend      = applySaved("erenExtend",      v4.erenExtend)
v4.injuryEnabled   = applySaved("injuryEnabled",   v4.injuryEnabled)
v4.ripperEnabled   = applySaved("ripperEnabled",   v4.ripperEnabled)
v4.autofarmEnabled = applySaved("autofarmEnabled", v4.autofarmEnabled)
v4.oldfarmEnabled  = applySaved("oldfarmEnabled",  v4.oldfarmEnabled)

game.Players.PlayerRemoving:Connect(function(p)
    if p == v4.player then
        saveVariables(SAVE_FOLDER, {
            espEnabled      = v4.espEnabled,
            extendEnabled   = v4.extendEnabled,
            escapeEnabled   = v4.escapeEnabled,
            bladeEnabled    = v4.bladeEnabled,
            extendMulti     = v4.extendMulti,
            napeVisible     = v4.napeVisible,
            injuryEnabled   = v4.injuryEnabled,
            erenExtend      = v4.erenExtend,
            ripperEnabled   = v4.ripperEnabled,
            autofarmEnabled = v4.autofarmEnabled,
            oldfarmEnabled  = v4.oldfarmEnabled,
        })
    end
end)

-- Atmosphere tweak
if v4.atmosphere then
    v4.atmosphere.Density = 0.22
end

-- ================================================================
-- Notify helper (WindUI)
-- ================================================================
local function notify(title, text, duration)
    WindUI:Notify({
        Title    = title,
        Content  = text,
        Duration = duration or 4,
    })
end

-- ================================================================
-- Feature Logic Functions
-- ================================================================

-- Find nearest nape (fixed: no duplicate nape key, proper scope)
local function findNape()
    if not v4.titans then
        warn("[TekkitHub] Titans folder not found.")
        return
    end
    local nearest = math.huge
    for _, titan in ipairs(v4.titans:GetChildren()) do
        if titan:IsA("Model") and titan:FindFirstChildOfClass("Humanoid") then
            if not v4.titans:FindFirstChild("Attack_Titan") then
                -- Regular titan: find the closest nape
                local hitboxes = titan:FindFirstChild("Hitboxes")
                if hitboxes then
                    local hit = hitboxes:FindFirstChild("Hit")
                    if hit then
                        local nape = hit:FindFirstChild("Nape")
                        if nape then
                            local dist = (nape.Position - v4.root.Position).Magnitude
                            if dist < nearest then
                                nearest = dist
                                v4.nape = nape
                            end
                        end
                    end
                end
            elseif titan.Name == "Attack_Titan" then
                -- Attack Titan: target the marked weak point
                local hitboxes = titan:FindFirstChild("Hitboxes")
                if hitboxes and hitboxes:FindFirstChild("Hit") then
                    task.wait(0.1)
                    if not v4.titans:FindFirstChild("Attack_Titan") then return end
                    local marker = titan:FindFirstChild("Marker")
                    if marker and marker.Adornee and v4.oldfarmEnabled then
                        local a = marker.Adornee
                        if     a == v4.leftleg  then v4.nape = v4.leftleg
                        elseif a == v4.rightleg then v4.nape = v4.rightleg
                        elseif a == v4.leftarm  then v4.nape = v4.leftarm
                        elseif a == v4.rightarm then v4.nape = v4.rightarm
                        elseif a == v4.eyes     then v4.nape = v4.eyes
                        else
                            v4.nape = hitboxes.Hit:FindFirstChild("Nape")
                        end
                    end
                end
            end
        end
    end
end

-- Titan ESP
local function applyESP()
    if v4.espEnabled then
        local hl = Instance.new("Highlight")
        hl.Name             = "Highlight"
        hl.Parent           = v4.titans
        hl.OutlineTransparency = 0.1
        hl.OutlineColor     = Color3.new(1, 1, 1)
        hl.FillColor        = Color3.new(1, 1, 1)
        hl.FillTransparency = 0.9
        hl.Adornee          = v4.titans
        for _, titan in pairs(v4.titans:GetChildren()) do
            if titan:IsA("Model") then
                local head = titan:FindFirstChild("Fake") and titan.Fake:FindFirstChild("Head")
                local header = head and head:FindFirstChild("Header")
                if header then header.Enabled = true end
            end
        end
    else
        for _, child in pairs(v4.titans:GetChildren()) do
            if child:IsA("Model") then
                local head = child:FindFirstChild("Fake") and child.Fake:FindFirstChild("Head")
                local header = head and head:FindFirstChild("Header")
                if header then header.Enabled = false end
            elseif child:IsA("Highlight") then
                child:Destroy()
            end
        end
    end
end

-- Nape Extend
local function applyExtend()
    if v4.extendEnabled then
        for _, titan in pairs(v4.titans:GetChildren()) do
            if titan:IsA("Model") and titan.Name ~= "Attack_Titan" then
                local hitboxes = titan:FindFirstChild("Hitboxes")
                local nape = hitboxes and hitboxes:FindFirstChild("Hit") and hitboxes.Hit:FindFirstChild("Nape")
                if nape then
                    nape.Size        = Vector3.new(60, 60, 60) * v4.extendMulti
                    nape.Color       = Color3.new(1, 1, 1)
                    nape.Material    = Enum.Material.Neon
                    nape.Transparency = 0.96
                end
            end
        end
    else
        for _, titan in pairs(v4.titans:GetChildren()) do
            if titan:IsA("Model") then
                local hitboxes = titan:FindFirstChild("Hitboxes")
                local nape = hitboxes and hitboxes:FindFirstChild("Hit") and hitboxes.Hit:FindFirstChild("Nape")
                if nape then
                    nape.Size        = Vector3.new(15, 9, 11)
                    nape.Color       = Color3.new(1, 0, 0)
                    nape.Transparency = 1
                end
            end
        end
    end
end

-- Nape Visibility
local function applyNapeVisible()
    for _, titan in pairs(v4.titans:GetChildren()) do
        if titan:IsA("Model") then
            local hitboxes = titan:FindFirstChild("Hitboxes")
            local hit = hitboxes and hitboxes:FindFirstChild("Hit")
            local nape = hit and hit:FindFirstChild("Nape")
            if nape then
                nape.Transparency = v4.napeVisible and 0.96 or 1
            end
        end
    end
end

-- Eren Extend helpers
local function resetErenHitboxes()
    for _, part in pairs({ v4.leftleg, v4.rightleg, v4.leftarm, v4.rightarm, v4.eyes, v4.nape }) do
        if part then
            part.Size        = Vector3.new(10, 20, 10)
            part.Color       = Color3.new(1, 1, 1)
            part.Transparency = 1
        end
    end
end

local function expandPart(part)
    if part then
        part.Size        = Vector3.new(95, 95, 95)
        part.Color       = Color3.new(1, 1, 1)
        part.Material    = Enum.Material.Neon
        part.Transparency = 0.94
    end
end

local function updateErenTarget()
    task.wait(0.1)
    if not v4.titans:FindFirstChild("Attack_Titan") then
        warn("[TekkitHub] Attack Titan not found.")
        return
    end
    local marker = v4.titans.Attack_Titan:FindFirstChild("Marker")
    if not marker then return end
    local adornee = marker.Adornee
    if v4.erenExtend then
        resetErenHitboxes()
        task.wait(0.1)
        if     adornee == v4.leftleg  then expandPart(v4.leftleg)
        elseif adornee == v4.rightleg then expandPart(v4.rightleg)
        elseif adornee == v4.leftarm  then expandPart(v4.leftarm)
        elseif adornee == v4.rightarm then expandPart(v4.rightarm)
        elseif adornee == v4.eyes     then expandPart(v4.eyes)
        elseif adornee == v4.nape     then expandPart(v4.nape)
        else resetErenHitboxes() end
    else
        resetErenHitboxes()
    end
end

local function setupErenExtend()
    task.wait(0.1)
    v4.attacktitan = game.Workspace.Titans:FindFirstChild("Attack_Titan")
    if not v4.attacktitan then return end
    v4.marker = v4.attacktitan:WaitForChild("Marker")
    local hitboxes = v4.attacktitan:FindFirstChild("Hitboxes")
    if hitboxes and hitboxes:FindFirstChild("Hit") then
        v4.leftleg  = hitboxes.Hit:FindFirstChild("LeftLeg")
        v4.rightleg = hitboxes.Hit:FindFirstChild("RightLeg")
        v4.leftarm  = hitboxes.Hit:FindFirstChild("LeftArm")
        v4.rightarm = hitboxes.Hit:FindFirstChild("RightArm")
        v4.eyes     = hitboxes.Hit:FindFirstChild("Eyes")
        v4.nape     = hitboxes.Hit:FindFirstChild("Nape")
    end
    coroutine.wrap(updateErenTarget)()
    v4.marker:GetPropertyChangedSignal("Adornee"):Connect(updateErenTarget)
end

-- OP Autofarm (uses skills to clear missions)
local function runAutofarm()
    notify("Autofarm", "Clearing mission...")
    local t = tick()
    while tick() - t < 3.5 do
        v4.remoteGet:InvokeServer("S_Skills", "Usage", "108")
        task.wait(0.1)
        v4.remoteGet:InvokeServer("S_Skills", "Usage", "14")
        task.wait(2.5)
        v4.remoteGet:InvokeServer("S_Skills", "Usage", "23")
        task.wait(0.1)
        v4.remoteGet:InvokeServer("S_Skills", "Usage", "14")
        task.wait(0.5)
    end
end

-- WIP Autofarm: fly movement loop
local function runOldFarmMove()
    local bp = v4.root:FindFirstChild("BodyPosition") or Instance.new("BodyPosition", v4.root)
    bp.MaxForce = Vector3.new(0, 1000, 0)
    bp.D        = 1000
    bp.P        = 1000
    while v4.oldfarmEnabled and task.wait(0.15) do
        coroutine.wrap(findNape)()
        local dist = v4.titans:FindFirstChild("Attack_Titan") and 195 or 75
        if v4.nape then
            local bv     = v4.root:FindFirstChild("BV")
            local bg     = v4.root:FindFirstChild("BG")
            local target = v4.nape.Position + Vector3.new(0, dist, 0)
            local unit   = (target - v4.root.Position).Unit
            local mag    = math.min((target - v4.root.Position).Magnitude, 150)
            if bv then
                bv.MaxForce = Vector3.new(5500, 5500, 5500)
                bv.Velocity = unit * mag
            end
            bp.Position = Vector3.new(bp.Position.X, target.Y, bp.Position.Z)
            if bg then
                bg.CFrame = CFrame.new(v4.root.Position, v4.root.Position + unit)
            end
            -- Remove obstacles
            if game.Workspace:FindFirstChild("Climbable") then
                task.wait(3)
                local climbable = game.Workspace:FindFirstChild("Climbable")
                if climbable then climbable:Destroy() end
                local unclimbable = game.Workspace:FindFirstChild("Unclimbable")
                if unclimbable then
                    for _, c in pairs(unclimbable:GetChildren()) do
                        if c.Name ~= "Reloads" and c.Name ~= "Cutscene"
                        and c.Name ~= "Objective" and c.Name ~= "Reload" then
                            c:Destroy()
                        end
                    end
                end
            end
            -- Disable collisions while flying
            for _, part in pairs(v4.character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
end

-- WIP Autofarm: attack loop
local function runOldFarmAttack()
    local sets = lp.PlayerGui.Interface.HUD.Main.Top.Blade.Sets
    while v4.oldfarmEnabled and task.wait(1) do
        coroutine.wrap(findNape)()
        task.wait(0.05)
        if v4.nape then
            if game.Workspace.Titans:FindFirstChild("Attack_Titan") then
                if (v4.root.Position - v4.nape.Position).Magnitude <= 250 then
                    v4.remotePost:FireServer("Attacks", "Slash", true)
                    v4.remoteGet:InvokeServer("Hitboxes", "Register", v4.nape,
                        math.random(215, 230), math.random(10, 100))
                end
            elseif (v4.root.Position - v4.nape.Position).Magnitude <= 175 then
                v4.remotePost:FireServer("Attacks", "Slash", true)
                v4.remoteGet:InvokeServer("Hitboxes", "Register", v4.nape,
                    math.random(215, 230), math.random(10, 100))
            end
        end
        task.wait(0.05)
        -- Auto blade refill during old farm
        if string.find(sets.Text, "0") and v4.blade.Transparency == 1 then
            v4.remoteGet:InvokeServer("Blades", "Full_Reload", "Left",  v4.refill)
            v4.remoteGet:InvokeServer("Blades", "Full_Reload", "Right", v4.refill)
            sets.Text = "3 / 3"
        end
    end
end

-- Mission retry loop (shared by both autofarms)
local function runRetryLoop()
    local ok, retryBtn = pcall(function()
        return lp.PlayerGui.Interface.Rewards.Main.Info.Main.Buttons.Retry.Title
    end)
    if not ok then return end
    while task.wait(1) do
        if not string.find(retryBtn.Text, "(0/0)") then
            if v4.autofarmEnabled or v4.oldfarmEnabled then
                v4.remoteGet:InvokeServer("Functions", "Retry", "Add")
            end
            local started = false
            repeat
                task.wait(0.1)
                if string.find(retryBtn.Text, "STARTING") then
                    started = true
                elseif v4.autofarmEnabled or v4.oldfarmEnabled then
                    v4.remoteGet:InvokeServer("Functions", "Retry", "Add")
                end
            until started
            break
        end
    end
end

coroutine.wrap(runRetryLoop)()

-- Shadow-ban check
local function checkShadowBan()
    local ok, data = pcall(function()
        return v4.remoteGet:InvokeServer("Data", "Get")
    end)
    if not ok or not data then
        notify("Shadow Ban", "Could not retrieve data.")
        return
    end
    for key in pairs(data) do
        if key:lower():match("blacklist")
        and key ~= "Is_Blacklisted" and key ~= "Is_Blacklisted_NEW" then
            notify("Shadow Ban", "You are shadow banned :(")
            return
        end
    end
    notify("Shadow Ban", "You are safe :)")
end

-- ================================================================
-- Game Event Connections (blade reload, escape, injury, titans)
-- ================================================================

-- Auto blade reload
v4.blade:GetPropertyChangedSignal("Transparency"):Connect(function()
    task.wait(0.15)
    if v4.blade.Transparency ~= 1 or not v4.bladeEnabled then return end
    if v4.character:GetAttribute("IFrames") ~= nil then return end
    local sets = lp.PlayerGui.Interface.HUD.Main.Top.Blade.Sets
    if     sets.Text == "3 / 3" then sets.Text = "2 / 3"
    elseif sets.Text == "2 / 3" then sets.Text = "1 / 3"
    elseif sets.Text == "1 / 3" then sets.Text = "0 / 3"
    end
    local t = tick()
    while tick() - t < 30 and v4.blade.Transparency == 1 do
        task.wait(0.5)
        v4.remoteGet:InvokeServer("Blades", "Reload")
    end
end)

-- Auto grab escape
v4.buttonsFolder.ChildAdded:Connect(function(btn)
    if not v4.escapeEnabled then return end
    task.wait(0.15)
    v4.remotePost:FireServer("Attacks", "Slash_Escape")
    btn:Destroy()
    task.wait(0.3)
    coroutine.wrap(findNape)()
    if v4.nape then
        local bv = v4.root:FindFirstChild("BV")
        local mag = bv and bv.Velocity.Magnitude or 0
        v4.remotePost:FireServer("Attacks", "Slash", true)
        v4.remoteGet:InvokeServer("Hitboxes", "Register", v4.nape, mag, 0)
    end
end)

-- Anti-injury
v4.injuryFolder.ChildAdded:Connect(function()
    if not v4.injuryEnabled then return end
    task.wait(0.2)
    for _, child in pairs(v4.injuryFolder:GetChildren()) do
        child:Destroy()
    end
end)

-- Titan ripper (skill hitbox snap)
game.Workspace.ChildAdded:Connect(function(obj)
    if not obj:IsA("Part") then return end
    local ripperActive = v4.ripperEnabled and v4.passed
    local autofarmActive = v4.autofarmEnabled and v4.passed
    if not ripperActive and not autofarmActive then return end
    local suffix = "_Steel"
    local isSkill = obj.Name == v4.playerName .. "_Steel"
                 or obj.Name == v4.playerName .. "_Thrust"
                 or obj.Name == v4.playerName .. "_RIP"
    if not isSkill then return end

    local anim = v4.player.Character:FindFirstChildOfClass("Humanoid")
              or v4.player.Character:FindFirstChildOfClass("AnimationController")

    -- Snap all napes to skill part position
    for _, titan in pairs(v4.titans:GetChildren()) do
        if titan:IsA("Model") and titan.Name ~= "Attack_Titan" then
            local hitboxes = titan:FindFirstChild("Hitboxes")
            local nape = hitboxes and hitboxes:FindFirstChild("Hit") and hitboxes.Hit:FindFirstChild("Nape")
            if nape and nape:IsA("BasePart") then
                nape.Size        = Vector3.new(150, 150, 150)
                nape.Transparency = 1
                nape.Position    = obj.Position
            else
                return
            end
        end
    end

    obj.Size = Vector3.new(125, 125, 125)
    local t = tick()
    local activeTracks

    while true do
        if tick() - t < 2 then
            for _, titan in pairs(v4.titans:GetChildren()) do
                if titan:IsA("Model") and titan.Name ~= "Attack_Titan" then
                    local hitboxes = titan:FindFirstChild("Hitboxes")
                    local nape = hitboxes and hitboxes:FindFirstChild("Hit") and hitboxes.Hit:FindFirstChild("Nape")
                    if nape and nape:IsA("BasePart") then
                        activeTracks = anim:GetPlayingAnimationTracks()
                        for _, track in pairs(activeTracks or {}) do
                            track:AdjustSpeed(0)
                        end
                        nape.Position    = obj.Position
                        nape.Transparency = 1
                        task.wait(0.01)
                    else
                        return
                    end
                end
            end
        else
            -- Restore animation speeds
            for _, track in pairs(activeTracks or {}) do
                track:AdjustSpeed(1)
            end
            task.wait(0.5)
            for _, titan in pairs(v4.titans:GetChildren()) do
                if titan:IsA("Model") and titan.Name ~= "Attack_Titan" then
                    local hitboxes = titan:FindFirstChild("Hitboxes")
                    local nape = hitboxes and hitboxes:FindFirstChild("Hit") and hitboxes.Hit:FindFirstChild("Nape")
                    local fake  = titan:FindFirstChild("Fake")
                    local head  = fake and fake:FindFirstChild("Head")
                    if nape and nape:IsA("BasePart") and head then
                        nape.Position    = head.Position - Vector3.new(2, 5, 0)
                        nape.Transparency = v4.napeVisible and 0.96 or 1
                        task.wait(0.01)
                    else
                        return
                    end
                end
            end
            break
        end
    end
end)

-- New titan spawned event
v4.titans.ChildAdded:Connect(function(titan)
    if titan.Name == "Attack_Titan" then
        task.wait(0.2)
        coroutine.wrap(setupErenExtend)()
    elseif titan:IsA("Model") then
        task.wait(0.1)
        coroutine.wrap(applyExtend)()
    end
end)

-- Anti-idle (prevent Roblox auto-kick)
task.spawn(function()
    local getConns = getconnections or get_signal_cons
    if getConns then
        for _, conn in pairs(getConns(lp.Idled)) do
            if conn.Disable then conn:Disable()
            elseif conn.Disconnect then conn:Disconnect()
            end
        end
    else
        local vu = cloneref(game:GetService("VirtualUser"))
        lp.Idled:Connect(function()
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)
    end
end)

-- ================================================================
-- Skill Cooldown Detection (fixed: first-match-wins, not last)
-- ================================================================
task.wait(15)

local function detectCooldowns()
    for _, slot in pairs(v4.hotbar:GetChildren()) do
        if slot.Name:find("Skill") then
            local inner = slot:FindFirstChild("Inner")
            local icon  = inner and inner:FindFirstChild("Icon")
            local cd    = slot:FindFirstChild("Cooldown")
            if icon and cd then
                -- Steel skill
                if icon.Image == "rbxassetid://15215081865" and not v4.cooldownS then
                    v4.cooldownS = cd
                -- Thrust skill
                elseif icon.Image == "rbxassetid://15215073606" and not v4.cooldownT then
                    v4.cooldownT = cd
                -- Let-It-RIP skill
                elseif icon.Image == "rbxassetid://15216496277" and not v4.cooldownR then
                    v4.cooldownR = cd
                end
            end
        end
    end
    print("[TekkitHub] Cooldowns detected — T:", v4.cooldownT ~= nil,
          "S:", v4.cooldownS ~= nil, "R:", v4.cooldownR ~= nil)
end

if v4.passed then
    coroutine.wrap(detectCooldowns)()
end

-- Hook cooldown signals for OP autofarm
local function hookCooldown(cdRef)
    if cdRef then
        cdRef:GetPropertyChangedSignal("Visible"):Connect(function()
            if v4.passed and v4.autofarmEnabled and cdRef.Visible == false then
                coroutine.wrap(runAutofarm)()
            end
        end)
    end
end

hookCooldown(v4.cooldownT)
hookCooldown(v4.cooldownS)
hookCooldown(v4.cooldownR)

-- ================================================================
-- Apply saved states on startup
-- ================================================================
if v4.espEnabled      then coroutine.wrap(applyESP)() end
if v4.extendEnabled   then coroutine.wrap(applyExtend)() end
if v4.erenExtend      then coroutine.wrap(setupErenExtend)() end
if not v4.napeVisible then applyNapeVisible() end
if v4.injuryEnabled then
    for _, c in pairs(v4.injuryFolder:GetChildren()) do c:Destroy() end
end
if v4.autofarmEnabled and v4.passed then
    task.wait(1.5)
    coroutine.wrap(runAutofarm)()
end
if v4.oldfarmEnabled then
    coroutine.wrap(runOldFarmMove)()
    coroutine.wrap(runOldFarmAttack)()
end

-- ================================================================
-- WindUI: Create Window
-- ================================================================
local Window = WindUI:CreateWindow({
    Title        = "Tekkit Hub",
    Folder       = "TekkitHub",
    Icon         = "solar:shield-star-bold-duotone",
    NewElements  = true,
    HideSearchBar = true,
    Topbar = {
        Height      = 44,
        ButtonsType = "Mac",
    },
    OpenButton = {
        Title        = "Tekkit Hub",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 2,
        Enabled      = true,
        Draggable    = true,
        OnlyMobile   = false,
        Scale        = 0.5,
        Color        = ColorSequence.new(
            Color3.fromHex("#30FF6A"),
            Color3.fromHex("#00BFFF")
        ),
    },
})

-- Toggle with RightShift (same as original)
Window:SetToggleKey(Enum.KeyCode.RightShift)

-- Header tag
Window:Tag({
    Title  = "discord.gg/CXFxhXShwt",
    Icon   = "message-circle",
    Color  = Color3.fromHex("#5865F2"),
    Border = true,
})

-- ================================================================
-- Main Tab
-- ================================================================
local MainTab = Window:Tab({
    Title     = "Main",
    Icon      = "solar:sword-bold-duotone",
    IconColor = Color3.fromHex("#30FF6A"),
})

MainTab:Toggle({
    Title    = "Titan ESP",
    Desc     = "Highlights titan models through walls",
    Icon     = "eye",
    Value    = v4.espEnabled,
    Callback = function(state)
        v4.espEnabled = state
        coroutine.wrap(applyESP)()
    end,
})

MainTab:Space()

MainTab:Toggle({
    Title    = "Auto Grab Escape",
    Desc     = "Automatically escapes titan grabs and slashes",
    Icon     = "shield",
    Value    = v4.escapeEnabled,
    Callback = function(state)
        v4.escapeEnabled = state
    end,
})

MainTab:Space()

MainTab:Toggle({
    Title    = "Blade Refill",
    Desc     = "Auto-reloads blades whenever they break",
    Icon     = "zap",
    Value    = v4.bladeEnabled,
    Callback = function(state)
        v4.bladeEnabled = state
    end,
})

MainTab:Space()

MainTab:Toggle({
    Title    = "Nape Extend",
    Desc     = "Enlarges titan nape hitboxes for easier kills",
    Icon     = "maximize-2",
    Value    = v4.extendEnabled,
    Callback = function(state)
        v4.extendEnabled = state
        coroutine.wrap(applyExtend)()
    end,
})

MainTab:Space()

-- FIX: was a raw TextBox with broken `extendMulti` (missing `v4.`) — now a proper Slider
MainTab:Slider({
    Title    = "Nape Multiplier",
    Desc     = "Size multiplier applied by Nape Extend (0.0 – 2.0)",
    IsTooltip = true,
    Step     = 0.1,
    Value    = { Min = 0, Max = 2, Default = v4.extendMulti },
    Callback = function(val)
        v4.extendMulti = val
        if v4.extendEnabled then
            coroutine.wrap(applyExtend)()
        end
    end,
})

MainTab:Space()

MainTab:Toggle({
    Title    = "Nape Visible",
    Desc     = "Renders nape hitboxes as semi-transparent spheres",
    Icon     = "crosshair",
    Value    = v4.napeVisible,
    Callback = function(state)
        v4.napeVisible = state
        applyNapeVisible()
    end,
})

MainTab:Space()

MainTab:Toggle({
    Title       = "Titan Ripper",
    Desc        = "Snaps all napes onto your skill hitboxes instantly",
    Icon        = "star",
    Value       = v4.ripperEnabled,
    Locked      = not v4.passed,
    LockedTitle = "Premium — join the Discord.",
    Callback    = function(state)
        if v4.passed then
            v4.ripperEnabled = state
        else
            notify("Premium", "Feature locked — check the Discord.")
        end
    end,
})

MainTab:Space()

MainTab:Button({
    Title    = "TP to Gas Refill",
    Desc     = "Teleports you to the gas tank refill station",
    Icon     = "map-pin",
    Justify  = "Center",
    Callback = function()
        if not v4.refill then
            notify("Error", "Refill station not found.")
            return
        end
        local dest  = v4.refill.Position + Vector3.new(0, 2, 0)
        local dist  = (dest - v4.root.Position).Magnitude
        local info  = TweenInfo.new(dist / 225, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
        local tween = game:GetService("TweenService"):Create(v4.root, info, { CFrame = CFrame.new(dest) })
        v4.hovering = true
        tween.Completed:Connect(function() v4.hovering = false end)
        tween:Play()
    end,
})

-- ================================================================
-- Testing Tab
-- ================================================================
local TestingTab = Window:Tab({
    Title     = "Testing",
    Icon      = "solar:test-tube-bold-duotone",
    IconColor = Color3.fromHex("#FF6B6B"),
})

TestingTab:Section({
    Title           = "⚠️  These features are experimental and may increase ban risk. Use at your own risk.",
    TextSize        = 14,
    TextTransparency = 0.25,
})

TestingTab:Space()

TestingTab:Toggle({
    Title    = "WIP Autofarm",
    Desc     = "Flies to nearest titan nape and attacks automatically",
    Icon     = "repeat",
    Value    = v4.oldfarmEnabled,
    Callback = function(state)
        v4.oldfarmEnabled = state
        if state then
            coroutine.wrap(runOldFarmMove)()
            coroutine.wrap(runOldFarmAttack)()
        else
            local bp = v4.root:FindFirstChild("BodyPosition")
            if bp then bp:Destroy() end
        end
    end,
})

TestingTab:Space()

TestingTab:Toggle({
    Title       = "OP Autofarm",
    Desc        = "Uses equipped skills to automatically clear missions",
    Icon        = "star",
    Value       = v4.autofarmEnabled,
    Locked      = not v4.passed,
    LockedTitle = "Premium — join the Discord.",
    Callback    = function(state)
        if v4.passed then
            v4.autofarmEnabled = state
            if state then
                task.wait(0.2)
                coroutine.wrap(runAutofarm)()
            end
        else
            notify("Premium", "Feature locked — check the Discord.")
        end
    end,
})

TestingTab:Space()

TestingTab:Toggle({
    Title    = "Anti-Injury",
    Desc     = "Destroys injury debuff objects the instant they appear",
    Icon     = "heart",
    Value    = v4.injuryEnabled,
    Callback = function(state)
        v4.injuryEnabled = state
        if state then
            for _, c in pairs(v4.injuryFolder:GetChildren()) do
                c:Destroy()
            end
        end
    end,
})

TestingTab:Space()

TestingTab:Toggle({
    Title    = "Extend Eren Weakpoint",
    Desc     = "Expands the Attack Titan's currently marked weakpoint hitbox",
    Icon     = "target",
    Value    = v4.erenExtend,
    Callback = function(state)
        v4.erenExtend = state
        task.wait(0.1)
        if state then
            if v4.titans:FindFirstChild("Attack_Titan") then
                coroutine.wrap(updateErenTarget)()
            end
        else
            coroutine.wrap(resetErenHitboxes)()
        end
    end,
})

TestingTab:Space()

TestingTab:Button({
    Title    = "Check Shadow Ban",
    Desc     = "Checks your account's server-side blacklist status",
    Icon     = "search",
    Justify  = "Center",
    Callback = function()
        coroutine.wrap(checkShadowBan)()
    end,
})

-- ================================================================
-- Discord Tab
-- ================================================================
local DiscordTab = Window:Tab({
    Title     = "Discord",
    Icon      = "message-circle",
    IconColor = Color3.fromHex("#5865F2"),
})

DiscordTab:Section({ Title = "Join the Tekkit Hub Community", TextSize = 20 })

DiscordTab:Space()

DiscordTab:Paragraph({
    Title = "Tekkit Hub",
    Desc  = "Get updates, report bugs, and access premium features by joining our Discord server.",
    Buttons = {
        {
            Title    = "Copy Invite",
            Icon     = "link",
            Callback = function()
                if setclipboard then
                    setclipboard("https://discord.gg/CXFxhXShwt")
                end
                notify("Discord", "Invite link copied to clipboard!")
            end,
        },
    },
})

-- ================================================================
print("[TekkitHub] WindUI loaded successfully. Toggle: RightShift")
