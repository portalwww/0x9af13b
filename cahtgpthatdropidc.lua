-- Clean VR Hat Script (December 2025) - Fixed drop position & alignment

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game.Workspace

local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- === OPTIONS (edit these) ===
getgenv().options = getgenv().options or {
    headscale = 1,
    lefthandrotoffset = Vector3.new(0, 0, 0),
    righthandrotoffset = Vector3.new(0, 0, 0),
    controllerRotationOffset = Vector3.new(0, 0, 0),
    leftToyBind = Enum.KeyCode.ButtonL2,
    rightToyBind = Enum.KeyCode.ButtonR2,
    HeadHatTransparency = 1,
}

-- Your hat configurations (example format)
getgenv().headhats = getgenv().headhats or {}  -- e.g. ["Dominus"] = CFrame.new(0,0.5,0)
getgenv().left = getgenv().left or nil         -- "HatName" or "meshid:123456"
getgenv().right = getgenv().right or nil

-- === Create alignment parts ===
local function CreateAlignPart(name, size, anchored)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size or Vector3.new(1,1,1)
    part.Transparency = 1
    part.CanCollide = false
    part.Anchored = anchored or false
    part.Parent = Workspace
    return part
end

local LeftHandPart  = CreateAlignPart("LeftHandAlign",  Vector3.new(2,1,1))
local RightHandPart = CreateAlignPart("RightHandAlign", Vector3.new(2,1,1))
local HeadPart      = CreateAlignPart("HeadAlign",      Vector3.new(1,1,1))
local LeftToyPart   = CreateAlignPart("LeftToy",        Vector3.new(1,1,1))
local RightToyPart  = CreateAlignPart("RightToy",       Vector3.new(1,1,1))

local parts = {
    left = LeftHandPart,
    right = RightHandPart,
    headhats = HeadPart,
    leftToy = LeftToyPart,
    rightToy = RightToyPart,
}

-- Toy toggles
local leftToyEnabled, rightToyEnabled = false, false
local leftToyCF, rightToyCF = CFrame.new(1.15, 0, 0) * CFrame.Angles(0, math.rad(180), 0), CFrame.new(1.15, 0, 0)

-- === Network ownership check ===
local function IsNetworkOwner(part)
    return part and part.ReceiveAge == 0
end

-- === Align function ===
local function Align(handle, alignPart, offsetCF, isFlingPart)
    offsetCF = offsetCF or CFrame.new()
    local velocity = Vector3.new(20, 20, 20)
    local con

    con = RunService.PostSimulation:Connect(function()
        if not handle.Parent or not IsNetworkOwner(handle) then return end
        handle.CanCollide = false
        handle.CFrame = alignPart.CFrame * offsetCF
        handle.Velocity = velocity
    end)

    return {
        SetVelocity = function(v) velocity = v end,
        SetCFrame = function(cf) offsetCF = cf end,
        Disconnect = function() con:Disconnect() end
    }
end

-- === Hat dropping (fixed position) ===
local function DropHats(character, callback)
    local hrp = character:WaitForChild("HumanoidRootPart")
    local humanoid = character:WaitForChild("Humanoid")

    local startY = hrp.Position.Y
    local dropY = startY - 20  -- Drop just below feet

    -- Freeze animation
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://35154961"
    local track = humanoid.Animator:LoadAnimation(anim)
    track:Play()
    track.TimePosition = 3.24
    track:AdjustSpeed(0)

    -- Lock accessories
    local locks = {}
    for _, acc in pairs(humanoid:GetAccessories()) do
        table.insert(locks, acc.Changed:Connect(function(prop)
            if prop == "BackendAccoutrementState" then
                pcall(sethiddenproperty, acc, "BackendAccoutrementState", 0)
            end
        end))
        pcall(sethiddenproperty, acc, "BackendAccoutrementState", 2)
    end

    -- Hold position slightly below
    local holdCon
    holdCon = RunService.Heartbeat:Connect(function()
        if not hrp.Parent then holdCon:Disconnect() return end
        hrp.CFrame = CFrame.new(hrp.Position.X, dropY, hrp.Position.Z)
        hrp.Velocity = Vector3.new(0, 40, 0)
        hrp.RotVelocity = Vector3.new()
    end)

    task.wait(0.4)
    callback()

    humanoid:ChangeState(Enum.HumanoidStateType.Dead)
    character:WaitForChild("Head").Anchored = false  -- Trigger detach

    -- Unlock and drop
    for _, lock in locks do lock:Disconnect() end
    for _, acc in pairs(humanoid:GetAccessories()) do
        pcall(sethiddenproperty, acc, "BackendAccoutrementState", 4)
    end

    holdCon:Disconnect()
end

-- === Find matching hats ===
local function GetMatchingHats(character)
    local hats = {}
    local usedMeshIds = {}

    for _, acc in pairs(character:GetChildren()) do
        if not acc:IsA("Accessory") then continue end
        local handle = acc:FindFirstChild("Handle")
        if not handle or not handle:FindFirstChildOfClass("SpecialMesh") then continue end

        local mesh = handle.SpecialMesh
        local meshId = tostring(mesh.MeshId:match("%d+"))
        local key = "meshid:" .. meshId

        local category, offset
        if getgenv().headhats[key] then
            category = "headhats"
            offset = getgenv().headhats[key]
        elseif getgenv().left == key or getgenv().left == acc.Name then
            category = "left"
            offset = CFrame.new()
        elseif getgenv().right == key or getgenv().right == acc.Name then
            category = "right"
            offset = CFrame.new()
        end

        if category and not usedMeshIds[key] and not usedMeshIds[acc.Name] then
            usedMeshIds[key] = true
            usedMeshIds[acc.Name] = true
            table.insert(hats, {acc, category, offset or CFrame.new()})
        end
    end
    return hats
end

-- === VR Controller Tracking ===
Camera.CameraType = Enum.CameraType.Scriptable
local rightAlign = nil
local R1Down, R2Down = false, false

UserInputService.UserCFrameChanged:Connect(function(part, cf)
    local scaleOffset = CFrame.new(cf.Position * (Camera.HeadScale - 1)) * cf
    if part == Enum.UserCFrame.Head then
        HeadPart.CFrame = Camera.CFrame * scaleOffset
    elseif part == Enum.UserCFrame.LeftHand then
        LeftHandPart.CFrame = Camera.CFrame * scaleOffset * CFrame.Angles(math.rad(options.lefthandrotoffset.X), math.rad(options.lefthandrotoffset.Y), math.rad(options.lefthandrotoffset.Z))
        if leftToyEnabled then LeftToyPart.CFrame = LeftHandPart.CFrame * leftToyCF end
    elseif part == Enum.UserCFrame.RightHand then
        RightHandPart.CFrame = Camera.CFrame * scaleOffset * CFrame.Angles(math.rad(options.righthandrotoffset.X), math.rad(options.righthandrotoffset.Y), math.rad(options.righthandrotoffset.Z))
        if rightToyEnabled then RightToyPart.CFrame = RightHandPart.CFrame * rightToyCF end
    end
end)

UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == options.leftToyBind then
        leftToyEnabled = not leftToyEnabled
    elseif input.KeyCode == options.rightToyBind then
        rightToyEnabled = not rightToyEnabled
    elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
        R1Down = true
    elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
        R2Down = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.ButtonR1 then R1Down = false end
    if input.KeyCode == Enum.KeyCode.ButtonR2 then R2Down = false end
end)

RunService.RenderStepped:Connect(function()
    if R1Down and RightHandPart then
        Camera.CFrame = Camera.CFrame:Lerp(RightHandPart.CFrame * CFrame.Angles(math.rad(options.righthandrotoffset.X), math.rad(options.righthandrotoffset.Y), math.rad(options.righthandrotoffset.Z)), 0.5)
    end

    if rightAlign then
        if R2Down then
            rightAlign:SetVelocity(Vector3.new(0, 0, -999999))
        else
            rightAlign:SetVelocity(Vector3.new(20, 20, 20))
        end
    end
end)

-- === Drop and align hats ===
local function SetupHats(character)
    DropHats(character, function()
        task.wait(0.5)
        for _, data in GetMatchingHats(character) do
            local acc, cat, offset = data[1], data[2], data[3]
            local handle = acc:FindFirstChild("Handle")
            if handle then
                if cat == "headhats" then handle.Transparency = options.HeadHatTransparency end
                local aligner = Align(handle, parts[cat], offset)
                if cat == "right" then rightAlign = aligner end
            end
        end
    end)
end

if Player.Character then SetupHats(Player.Character) end
Player.CharacterAdded:Connect(SetupHats)
