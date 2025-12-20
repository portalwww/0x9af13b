-- VR Hat Alignment Script - Fixed Drop & Modernized (Dec 2025)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game.Workspace

local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Options (customize these)
getgenv().options = getgenv().options or {
    headscale = 1,
    lefthandrotoffset = Vector3.new(0,0,0),
    righthandrotoffset = Vector3.new(0,0,0),
    controllerRotationOffset = Vector3.new(0,0,0),
    leftToyBind = Enum.KeyCode.ButtonL2,
    rightToyBind = Enum.KeyCode.ButtonR2,
    thirdPersonButtonToggle = Enum.KeyCode.ButtonSelect,
    HeadHatTransparency = 1,
}

-- Create alignment parts
local function createPart(name, size, anchored)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size or Vector3.new(1,1,1)
    part.Transparency = 1
    part.CanCollide = false
    part.Anchored = anchored or false
    part.Parent = Workspace
    return part
end

local leftHand = createPart("LeftHandAlign", Vector3.new(2,1,1))
local rightHand = createPart("RightHandAlign", Vector3.new(2,1,1))
local headAlign = createPart("HeadAlign", Vector3.new(1,1,1))
local leftToy = createPart("LeftToy", Vector3.new(1,1,1))
local rightToy = createPart("RightToy", Vector3.new(1,1,1))

local parts = {
    left = leftHand,
    right = rightHand,
    headhats = headAlign,
    leftToy = leftToy,
    rightToy = rightToy,
}

-- State
local rightAlign = nil
local leftToyEnabled = false
local rightToyEnabled = false
local lToyOffset = CFrame.new(1.15, 0, 0) * CFrame.Angles(0, math.rad(180), 0)
local rToyOffset = CFrame.new(1.15, 0, 0)

-- Network ownership check
local function isNetworkOwner(part)
    return part and part.ReceiveAge == 0
end

-- Align function
local function Align(handle, targetPart, offsetCF, isFlingPart)
    offsetCF = offsetCF or CFrame.new()
    local velocity = Vector3.new(20,20,20)
    local con
    con = RunService.PostSimulation:Connect(function()
        if not handle.Parent or not isNetworkOwner(handle) then return end
        handle.CanCollide = false
        handle.CFrame = targetPart.CFrame * offsetCF
        handle.Velocity = velocity
    end)
    return {
        SetVelocity = function(v) velocity = v end,
        SetCFrame = function(cf) offsetCF = cf end,
        Disconnect = function() con:Disconnect() end,
    }
end

-- Safe sethiddenproperty
local function setBackendState(acc, state)
    if sethiddenproperty then
        sethiddenproperty(acc, "BackendAccoutrementState", state)
    else
        acc.BackendAccoutrementState = state
    end
end

-- Fixed Hat Drop Function
local function DropHats(character, callback)
    local humanoid = character:WaitForChild("Humanoid")
    local hrp = character:WaitForChild("HumanoidRootPart")
    
    task.wait(0.3)
    
    -- Play freeze animation
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://35154961"
    local track = humanoid.Animator:LoadAnimation(anim)
    track:Play()
    track.TimePosition = 3.24
    track:AdjustSpeed(0)
    
    -- Lock to 2, then drop to 4
    local connections = {}
    for _, acc in pairs(humanoid:GetAccessories()) do
        table.insert(connections, acc.Changed:Connect(function(prop)
            if prop == "BackendAccoutrementState" then
                setBackendState(acc, 0)
            end
        end))
        setBackendState(acc, 2)
    end
    
    -- Drop slightly below current position (fixed!)
    local dropY = hrp.Position.Y - 25
    local dropCF = CFrame.new(hrp.Position.X, dropY, hrp.Position.Z)
    
    local loop
    loop = RunService.Heartbeat:Connect(function()
        if not hrp.Parent then loop:Disconnect() return end
        hrp.CFrame = dropCF * CFrame.Angles(math.rad(90), 0, 0)
        hrp.Velocity = Vector3.new(0, 50, 0)
        hrp.RotVelocity = Vector3.zero
    end)
    
    task.wait(0.4)
    
    -- Release to physical
    for _, conn in pairs(connections) do conn:Disconnect() end
    for _, acc in pairs(humanoid:GetAccessories()) do
        setBackendState(acc, 4)
    end
    
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    
    task.wait(0.5)
    loop:Disconnect()
    
    callback()
end

-- Main alignment setup
local function SetupHats(character)
    rightAlign = nil
    for _, acc in pairs(character:GetDescendants()) do
        if not acc:IsA("Accessory") or not acc:FindFirstChild("Handle") then continue end
        
        local handle = acc.Handle
        local mesh = handle:FindFirstChildOfClass("SpecialMesh")
        local id = mesh and tostring(mesh.MeshId):match("%d+") or acc.Name
        
        local slot = nil
        local offset = CFrame.new()
        
        if getgenv().headhats and getgenv().headhats["meshid:"..id] then
            slot = "headhats"
            offset = getgenv().headhats["meshid:"..id]
            handle.Transparency = options.HeadHatTransparency or 1
        elseif getgenv().left == "meshid:"..id or getgenv().left == acc.Name then
            slot = "left"
        elseif getgenv().right == "meshid:"..id or getgenv().right == acc.Name then
            slot = "right"
        elseif options.leftToy == "meshid:"..id or options.leftToy == acc.Name then
            slot = "leftToy"
        elseif options.rightToy == "meshid:"..id or options.rightToy == acc.Name then
            slot = "rightToy"
        end
        
        if slot and parts[slot] then
            local align = Align(handle, parts[slot], offset)
            if slot == "right" then rightAlign = align end
        end
    end
end

-- VR Input Handling
Camera.CameraType = Enum.CameraType.Scriptable
UserInputService.UserCFrameChanged:Connect(function(part, cf)
    Camera.HeadScale = options.headscale
    
    if part == Enum.UserCFrame.Head then
        headAlign.CFrame = Camera.CFrame * cf
    elseif part == Enum.UserCFrame.LeftHand then
        leftHand.CFrame = Camera.CFrame * cf * CFrame.Angles(math.rad(options.lefthandrotoffset.X), math.rad(options.lefthandrotoffset.Y), math.rad(options.lefthandrotoffset.Z))
        if leftToyEnabled then
            leftToy.CFrame = leftHand.CFrame * lToyOffset
        end
    elseif part == Enum.UserCFrame.RightHand then
        rightHand.CFrame = Camera.CFrame * cf * CFrame.Angles(math.rad(options.righthandrotoffset.X), math.rad(options.righthandrotoffset.Y), math.rad(options.righthandrotoffset.Z))
        if rightToyEnabled then
            rightToy.CFrame = rightHand.CFrame * rToyOffset
        end
    end
end)

-- Input toggles
local r2Down = false
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == options.leftToyBind then
        leftToyEnabled = not leftToyEnabled
    elseif input.KeyCode == options.rightToyBind then
        rightToyEnabled = not rightToyEnabled
        if rightToyEnabled and rightAlign then
            rToyOffset = rightToy.CFrame:ToObjectSpace(rightHand.CFrame)
        end
    elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
        r2Down = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.ButtonR2 then
        r2Down = false
    end
end)

-- Fling on R2
RunService.RenderStepped:Connect(function()
    if rightAlign and r2Down then
        rightAlign:SetVelocity(Vector3.new(0, 0, -999999))
        rightAlign:SetCFrame(CFrame.new(0, 0, -10))
    elseif rightAlign then
        rightAlign:SetVelocity(Vector3.new(20,20,20))
        rightAlign:SetCFrame(CFrame.new())
    end
end)

-- Initial drop + respawn handler
if Player.Character then
    DropHats(Player.Character, function() SetupHats(Player.Character) end)
end

Player.CharacterAdded:Connect(function(char)
    DropHats(char, function() SetupHats(char) end)
end)

print("VR Hat Script Loaded - Hats will drop near you!")
