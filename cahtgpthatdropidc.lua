-- Fixed SkyVR Hatdrop (Compatible with v8.1 Loader - Dec 2025)
-- Fixes: Velocity in Align (no falling), proper headhats cf lookup (name/meshid), networkowner, CFrame deprecation, movementSpeed, loco offsets, toy binds, outlines, error handling

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game.Workspace

local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local PostSimulation = RunService.PostSimulation
local RenderStepped = RunService.RenderStepped

local options = getgenv().options or {}
local headhats = getgenv().headhats or {}
local leftHat = getgenv().left or ""
local rightHat = getgenv().right or ""

-- Defaults if missing
options.NetVelocity = options.NetVelocity or Vector3.new(20, 20, 20)
options.headscale = options.headscale or 6.5
options.HeadHatTransparency = options.HeadHatTransparency or 1
options.lefthandrotoffset = options.lefthandrotoffset or Vector3.new(0, 90, 0)
options.righthandrotoffset = options.righthandrotoffset or Vector3.new(0, 90, 0)
options.controllerRotationOffset = options.controllerRotationOffset or Vector3.new(0, 0, 0)
options.leftToyBind = options.leftToyBind or Enum.KeyCode.ButtonY
options.rightToyBind = options.rightToyBind or Enum.KeyCode.ButtonB
options.leftToy = options.leftToy or ""
options.rightToy = options.rightToy or ""
options.movementSpeed = options.movementSpeed or 1
options.locomotionSpeed = options.locomotionSpeed or 0.5
options.locomotionSmoothing = options.locomotionSmoothing or 0.5
options.outlinesEnabled = options.outlinesEnabled or false

Workspace.FallenPartsDestroyHeight = 0 / 0

-- Create target parts
local function createPart(size, name, highlight)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.Transparency = 1
    part.CanCollide = false
    part.Anchored = true
    part.Parent = Workspace
    if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        part.CFrame = Player.Character.HumanoidRootPart.CFrame
    else
        part.CFrame = CFrame.new(0, 10, 0)
    end
    if highlight and options.outlinesEnabled then
        local sel = Instance.new("SelectionBox")
        sel.Adornee = part
        sel.LineThickness = 0.05
        sel.Parent = part
    end
    return part
end

local leftHandPart = createPart(Vector3.new(2, 1, 1), "moveLH", true)
local rightHandPart = createPart(Vector3.new(2, 1, 1), "moveRH", true)
local headPart = createPart(Vector3.new(1, 1, 1), "moveH", false)
local leftToyPart = createPart(Vector3.new(1, 1, 1), "LToy", true)
local rightToyPart = createPart(Vector3.new(1, 1, 1), "RToy", true)

local leftToyEnabled = false
local rightToyEnabled = false
local lFirst = true
local rFirst = true
local lToyPos = CFrame.new(1.15, 0, 0) * CFrame.Angles(0, math.rad(180), 0)
local rToyPos = CFrame.new(1.15, 0, 0)

local R1down = false
local R2down = false  -- If needed for fling

-- Filter MeshID
local function filterMeshID(id)
    return (string.find(id, 'assetdelivery') and string.match(string.sub(id, 37), "%d+")) or string.match(id, "%d+")
end

-- Find by MeshID
local function findMeshID(id)
    for k, v in pairs(headhats) do
        if k == "meshid:" .. id then
            return true, headPart, v
        end
    end
    if rightHat == "meshid:" .. id then
        return true, rightHandPart, CFrame.new()
    end
    if leftHat == "meshid:" .. id then
        return true, leftHandPart, CFrame.new()
    end
    if options.leftToy == "meshid:" .. id then
        return true, leftToyPart, CFrame.new()
    end
    if options.rightToy == "meshid:" .. id then
        return true, rightToyPart, CFrame.new()
    end
    return false
end

-- Find by Hat Name
local function findHatName(name)
    for k, v in pairs(headhats) do
        if k == name then
            return true, headPart, v
        end
    end
    if rightHat == name then
        return true, rightHandPart, CFrame.new()
    end
    if leftHat == name then
        return true, leftHandPart, CFrame.new()
    end
    if options.leftToy == name then
        return true, leftToyPart, CFrame.new()
    end
    if options.rightToy == name then
        return true, rightToyPart, CFrame.new()
    end
    return false
end

-- Align Handle to Target
local function Align(handle, targetPart, offsetCF)
    local con
    con = PostSimulation:Connect(function()
        if not handle or not handle:IsDescendantOf(Workspace) then
            con:Disconnect()
            return
        end
        if handle.ReceiveAge ~= 0 then
            return
        end
        handle.CanCollide = false
        handle.CFrame = targetPart.CFrame * (offsetCF or CFrame.new())
        handle.Velocity = options.NetVelocity
        handle.RotVelocity = Vector3.new()
    end)
end

-- Get all matching hats/accessories
local function getAllHats(character)
    local allHats = {}
    local foundMeshIds = {}
    for _, acc in pairs(character.Humanoid:GetAccessories()) do
        if not acc:FindFirstChild("Handle") then
            continue
        end
        local handle = acc.Handle
        local mesh = handle:FindFirstChildOfClass("SpecialMesh")
        local meshId = ""
        if mesh then
            meshId = filterMeshID(mesh.MeshId)
        end
        local isMatch, destPart, cf = findMeshID(meshId)
        local key = "meshid:" .. meshId
        if foundMeshIds[key] then
            isMatch = false
        else
            foundMeshIds[key] = true
        end
        if isMatch then
            table.insert(allHats, {acc = acc, handle = handle, dest = destPart, cf = cf})
        else
            isMatch, destPart, cf = findHatName(acc.Name)
            if isMatch then
                table.insert(allHats, {acc = acc, handle = handle, dest = destPart, cf = cf})
            end
        end
    end
    return allHats
end

-- Hat Drop & Align
local function HatdropCallback(character, alignCallback)
    local humanoid = character:WaitForChild("Humanoid")
    local hrp = character:WaitForChild("HumanoidRootPart")
    task.wait(0.4)

    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://35154961"
    local track = humanoid.Animator:LoadAnimation(anim)
    track:Play()
    track.TimePosition = 3.24
    track:AdjustSpeed(0)

    local allHats = getAllHats(character)
    local locks = {}

    -- Set BackendState=2 on matching hats to prepare drop
    for _, data in pairs(allHats) do
        table.insert(locks, data.acc.Changed:Connect(function(prop)
            if prop == "BackendAccoutrementState" then
                sethiddenproperty(data.acc, "BackendAccoutrementState", 0)
            end
        end))
        sethiddenproperty(data.acc, "BackendAccoutrementState", 2)
    end

    -- Hold position low
    local holdCon
    holdCon = PostSimulation:Connect(function()
        if not character:FindFirstChild("HumanoidRootPart") then
            holdCon:Disconnect()
            return
        end
        hrp.Velocity = Vector3.new(0, 25, 0)
        hrp.RotVelocity = Vector3.new()
        hrp.CFrame = CFrame.new(hrp.Position.X, Workspace.FallenPartsDestroyHeight + 0.25, hrp.Position.Z) * CFrame.Angles(math.rad(90), 0, 0)
    end)

    task.wait(0.25)

    -- Break joints to detach
    for _, data in pairs(allHats) do
        data.handle:BreakJoints()
        -- Initial velocity push
        local tempCon
        tempCon = PostSimulation:Connect(function()
            if not data.handle.Parent then
                tempCon:Disconnect()
                return
            end
            data.handle.Velocity = options.NetVelocity
            data.handle.RotVelocity = Vector3.new()
        end)
        task.delay(0.1, function() tempCon:Disconnect() end)
    end

    -- Align
    alignCallback(allHats)

    humanoid:ChangeState(Enum.HumanoidStateType.Dead)

    -- Wait death
    local torso = character:FindFirstChild("Torso") or character:FindFirstChild("LowerTorso")
    if torso then
        torso.AncestryChanged:Wait()
    end

    -- Cleanup
    for _, lock in pairs(locks) do
        lock:Disconnect()
    end
    for _, data in pairs(allHats) do
        sethiddenproperty(data.acc, "BackendAccoutrementState", 4)
    end
    holdCon:Disconnect()
end

-- VR Input
Camera.CameraType = Enum.CameraType.Scriptable
Camera.HeadScale = options.headscale
StarterGui:SetCore("VREnableControllerModels", false)

UserInputService.UserCFrameChanged:Connect(function(part, ucf)
    Camera.CameraType = Enum.CameraType.Scriptable
    Camera.HeadScale = options.headscale
    local speedMult = options.movementSpeed or 1
    local scaleOffset = CFrame.new(ucf.Position * (Camera.HeadScale - 1) * speedMult) * ucf
    if part == Enum.UserCFrame.Head then
        headPart.CFrame = Camera.CFrame * scaleOffset
    elseif part == Enum.UserCFrame.LeftHand then
        leftHandPart.CFrame = Camera.CFrame * scaleOffset * CFrame.Angles(
            math.rad(options.lefthandrotoffset.X),
            math.rad(options.lefthandrotoffset.Y),
            math.rad(options.lefthandrotoffset.Z)
        )
        if leftToyEnabled then
            leftToyPart.CFrame = leftHandPart.CFrame * lToyPos
        end
    elseif part == Enum.UserCFrame.RightHand then
        rightHandPart.CFrame = Camera.CFrame * scaleOffset * CFrame.Angles(
            math.rad(options.righthandrotoffset.X),
            math.rad(options.righthandrotoffset.Y),
            math.rad(options.righthandrotoffset.Z)
        )
        if rightToyEnabled then
            rightToyPart.CFrame = rightHandPart.CFrame * rToyPos
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    local kc = input.KeyCode
    if kc == options.leftToyBind then
        if not lFirst then
            lToyPos = leftToyPart.CFrame:ToObjectSpace(leftHandPart.CFrame):Inverse()
        end
        lFirst = false
        leftToyEnabled = not leftToyEnabled
    elseif kc == options.rightToyBind then
        if not rFirst then
            rToyPos = rightToyPart.CFrame:ToObjectSpace(rightHandPart.CFrame):Inverse()
        end
        rFirst = false
        rightToyEnabled = not rightToyEnabled
    elseif kc == Enum.KeyCode.ButtonR1 then
        R1down = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    local kc = input.KeyCode
    if kc == Enum.KeyCode.ButtonR1 then
        R1down = false
    end
end)

-- Locomotion (Right hand thumbstick analog? R1 hold)
RenderStepped:Connect(function()
    if R1down then
        local controllerOff = options.controllerRotationOffset
        local rightOff = options.righthandrotoffset
        local locoSmooth = options.locomotionSmoothing or 0.5
        local locoSpeed = options.locomotionSpeed or 0.5
        local moveDir = (rightHandPart.CFrame * CFrame.Angles(
            math.rad(controllerOff.X - rightOff.X),
            math.rad(controllerOff.Y - rightOff.Y),
            math.rad(controllerOff.Z - rightOff.Z)
        )).LookVector * (Camera.HeadScale / 2) * locoSpeed
        Camera.CFrame = Camera.CFrame:Lerp(Camera.CFrame + moveDir, locoSmooth)
    end
end)

-- Initial & Respawn
local function alignHats(allHats)
    for _, data in pairs(allHats) do
        if data.handle and data.handle.Parent then
            if data.dest == headPart then
                data.handle.Transparency = options.HeadHatTransparency
            end
            Align(data.handle, data.dest, data.cf)
        end
    end
end

if Player.Character then
    HatdropCallback(Player.Character, alignHats)
end

Player.CharacterAdded:Connect(function(char)
    task.wait(0.35)
    HatdropCallback(Player.Character, alignHats)
end)

print("SkyVR Hatdrop Fixed - Loaded Successfully!")
