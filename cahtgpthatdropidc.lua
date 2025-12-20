-- Fixed VR Hatdrop Script
local function createpart(size, name, h)
    local Part = Instance.new("Part")
    Part.Parent = workspace
    if game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        Part.CFrame = game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame
    else
        Part.CFrame = CFrame.new(0, 10, 0)
    end
    Part.Size = size
    Part.Transparency = 1
    Part.CanCollide = false
    Part.Anchored = true
    Part.Name = name
    return Part
end

local ps = game:GetService("RunService").PostSimulation
local input = game:GetService("UserInputService")
local fpdh = game.Workspace.FallenPartsDestroyHeight
local Player = game.Players.LocalPlayer
local options = getgenv().options or {}

-- Create parts
local lefthandpart = createpart(Vector3.new(2, 1, 1), "moveRH", true)
local righthandpart = createpart(Vector3.new(2, 1, 1), "moveRH", true)
local headpart = createpart(Vector3.new(1, 1, 1), "moveH", false)
local lefttoypart = createpart(Vector3.new(1, 1, 1), "LToy", true)
local righttoypart = createpart(Vector3.new(1, 1, 1), "RToy", true)

-- State variables
local thirdperson = false
local lefttoyenable = false
local righttoyenable = false
local lfirst = true
local rfirst = true
local ltoypos = CFrame.new(1.15, 0, 0) * CFrame.Angles(0, math.rad(180), 0)
local rtoypos = CFrame.new(1.15, 0, 0) * CFrame.Angles(0, math.rad(0), 0)
local R1down = false
local R2down = false
local negitive = true
local velocity = nil

-- Parts table
local parts = {
    left = lefthandpart,
    right = righthandpart,
    headhats = headpart,
    leftToy = lefttoypart,
    rightToy = righttoypart,
}

-- Network ownership check
function _isnetworkowner(Part)
    return Part.ReceiveAge == 0
end

-- Set fallen parts height
game.Workspace.FallenPartsDestroyHeight = 0/0

-- Filter mesh ID from URL
function filterMeshID(id)
    if not id then return nil end
    return (string.find(id, 'assetdelivery') ~= nil and string.match(string.sub(id, 37, #id), "%d+")) or string.match(id, "%d+")
end

-- Find accessory by mesh ID
function findMeshID(id)
    if not id then return false end
    for i, v in pairs(getgenv().headhats or {}) do
        if i == "meshid:" .. id then return true, "headhats" end
    end
    if getgenv().right == "meshid:" .. id then return true, "right" end
    if getgenv().left == "meshid:" .. id then return true, "left" end
    if options.leftToy == "meshid:" .. id then return true, "leftToy" end
    if options.rightToy == "meshid:" .. id then return true, "rightToy" end
    return false
end

-- Find accessory by name
function findHatName(id)
    for i, v in pairs(getgenv().headhats or {}) do
        if i == id then return true, "headhats" end
    end
    if getgenv().right == id then return true, "right" end
    if getgenv().left == id then return true, "left" end
    if options.leftToy == id then return true, "leftToy" end
    if options.rightToy == id then return true, "rightToy" end
    return false
end

-- Align part to another part
function Align(Part1, Part0, cf, isflingpart) 
    local up = isflingpart
    local con
    con = ps:Connect(function()
        if up ~= nil then up = not up end
        if not Part1:IsDescendantOf(workspace) then 
            con:Disconnect() 
            return 
        end
        if not _isnetworkowner(Part1) then return end
        Part1.CanCollide = false
        Part1.CFrame = Part0.CFrame * cf
        Part1.Velocity = velocity or Vector3.new(20, 20, 20)
    end)

    return {
        SetVelocity = function(self, v) 
            velocity = v 
        end,
        SetCFrame = function(self, v) 
            cf = v 
        end,
    }
end

-- Get all valid accessories from character
function getAllHats(Character)
    local allhats = {}
    local foundmeshids = {}
    
    for i, v in pairs(Character:GetChildren()) do
        if not v:IsA("Accessory") then continue end
        if not v:FindFirstChild("Handle") then continue end
        
        local mesh = v.Handle:FindFirstChildOfClass("SpecialMesh")
        if not mesh then continue end
        
        local meshId = filterMeshID(mesh.MeshId)
        if not meshId then continue end
        
        local is, d = findMeshID(meshId)
        local meshKey = "meshid:" .. meshId
        
        if foundmeshids[meshKey] then 
            is = false 
        else 
            foundmeshids[meshKey] = true 
        end
    
        if is then
            table.insert(allhats, {v, d, meshKey})
        else
            local is2, d2 = findHatName(v.Name)
            if is2 then
                table.insert(allhats, {v, d2, v.Name})
            end
        end
    end
    
    return allhats
end

-- Hatdrop animation callback
function HatdropCallback(Character, callback)
    if not Character then return end
    
    Character:WaitForChild("Humanoid")
    Character:WaitForChild("HumanoidRootPart")
    task.wait(0.4)
    
    local AnimationInstance = Instance.new("Animation")
    AnimationInstance.AnimationId = "rbxassetid://35154961"
    workspace.FallenPartsDestroyHeight = 0/0
    
    local hrp = Character.HumanoidRootPart
    local startCF = hrp.CFrame
    local torso = Character:FindFirstChild("Torso") or Character:FindFirstChild("LowerTorso")
    
    if not Character.Humanoid or not Character.Humanoid.Animator then return end
    
    local Track = Character.Humanoid.Animator:LoadAnimation(AnimationInstance)
    Track:Play()
    Track.TimePosition = 3.24
    Track:AdjustSpeed(0)
    
    local locks = {}
    for i, v in pairs(Character.Humanoid:GetAccessories()) do
        table.insert(locks, v.Changed:Connect(function(p)
            if p == "BackendAccoutrementState" then
                sethiddenproperty(v, "BackendAccoutrementState", 0)
            end
        end))
        sethiddenproperty(v, "BackendAccoutrementState", 2)
    end
    
    local c
    c = game:GetService("RunService").PostSimulation:Connect(function()
        if not Character:FindFirstChild("HumanoidRootPart") then 
            c:Disconnect()
            return
        end
        
        hrp.Velocity = Vector3.new(0, 0, 25)
        hrp.RotVelocity = Vector3.new(0, 0, 0)
        hrp.CFrame = CFrame.new(startCF.X, fpdh + 0.25, startCF.Z) * 
            (Character:FindFirstChild("Torso") and CFrame.Angles(math.rad(90), 0, 0) or CFrame.new())
    end)
    
    task.wait(0.35)
    callback(getAllHats(Character))
    
    if Character.Humanoid then
        Character.Humanoid:ChangeState(15)
    end
    
    if torso then
        torso.AncestryChanged:Wait()
    end
    
    for i, v in pairs(locks) do
        v:Disconnect()
    end
    
    for i, v in pairs(Character.Humanoid:GetAccessories()) do
        sethiddenproperty(v, "BackendAccoutrementState", 4)
    end
end

-- Camera setup
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
cam.HeadScale = options.headscale or 1

game:GetService("StarterGui"):SetCore("VREnableControllerModels", false)

local rightarmalign = nil

-- VR input handling
getgenv().con5 = input.UserCFrameChanged:Connect(function(part, move)
    cam.CameraType = Enum.CameraType.Scriptable
    cam.HeadScale = options.headscale or 1
    
    if part == Enum.UserCFrame.Head then
        headpart.CFrame = cam.CFrame * (CFrame.new(move.p * (cam.HeadScale - 1)) * move)
    elseif part == Enum.UserCFrame.LeftHand then
        local leftOffset = options.lefthandrotoffset or Vector3.new(0, 0, 0)
        lefthandpart.CFrame = cam.CFrame * (CFrame.new(move.p * (cam.HeadScale - 1)) * move * 
            CFrame.Angles(math.rad(leftOffset.X), math.rad(leftOffset.Y), math.rad(leftOffset.Z)))
        if lefttoyenable then
            lefttoypart.CFrame = lefthandpart.CFrame * ltoypos
        end
    elseif part == Enum.UserCFrame.RightHand then
        local rightOffset = options.righthandrotoffset or Vector3.new(0, 0, 0)
        righthandpart.CFrame = cam.CFrame * (CFrame.new(move.p * (cam.HeadScale - 1)) * move * 
            CFrame.Angles(math.rad(rightOffset.X), math.rad(rightOffset.Y), math.rad(rightOffset.Z)))
        if righttoyenable then
            righttoypart.CFrame = righthandpart.CFrame * rtoypos
        end
    end
end)

-- Input began
getgenv().con4 = input.InputBegan:Connect(function(key)
    if key.KeyCode == (options.thirdPersonButtonToggle or Enum.KeyCode.ButtonY) then
        thirdperson = not thirdperson
    end
    if key.KeyCode == Enum.KeyCode.ButtonR1 then
        R1down = true
    end
    if key.KeyCode == (options.leftToyBind or Enum.KeyCode.ButtonL1) then
        if not lfirst then
            ltoypos = lefttoypart.CFrame:ToObjectSpace(lefthandpart.CFrame):Inverse()
        end
        lfirst = false
        lefttoyenable = not lefttoyenable
    end
    if key.KeyCode == (options.rightToyBind or Enum.KeyCode.ButtonR1) then
        if not rfirst then
            rtoypos = righttoypart.CFrame:ToObjectSpace(righthandpart.CFrame):Inverse()
        end
        rfirst = false
        righttoyenable = not righttoyenable
    end
    if key.KeyCode == Enum.KeyCode.ButtonR2 and rightarmalign ~= nil then
        R2down = true
    end
end)

-- Input ended
getgenv().con3 = input.InputEnded:Connect(function(key)
    if key.KeyCode == Enum.KeyCode.ButtonR1 then
        R1down = false
    end
    if key.KeyCode == Enum.KeyCode.ButtonR2 and rightarmalign ~= nil then
        R2down = false
    end
end)

-- Render loop
getgenv().con2 = game:GetService("RunService").RenderStepped:Connect(function()
    if R1down then
        local rightOffset = options.righthandrotoffset or Vector3.new(0, 0, 0)
        local controllerOffset = options.controllerRotationOffset or Vector3.new(0, 0, 0)
        
        local direction = (righthandpart.CFrame * 
            CFrame.Angles(math.rad(rightOffset.X), math.rad(rightOffset.Y), math.rad(rightOffset.Z)):Inverse() * 
            CFrame.Angles(math.rad(controllerOffset.X), math.rad(controllerOffset.Y), math.rad(controllerOffset.Z))).LookVector * 
            cam.HeadScale / 2
        
        cam.CFrame = cam.CFrame:Lerp(cam.CoordinateFrame + direction, 0.5)
    end
    
    if rightarmalign then
        if R2down then
            negitive = not negitive
            rightarmalign:SetVelocity(Vector3.new(0, 0, -99999999))
            local rightOffset = options.righthandrotoffset or Vector3.new(0, 0, 0)
            rightarmalign:SetCFrame(
                CFrame.Angles(math.rad(rightOffset.X), math.rad(rightOffset.Y), math.rad(rightOffset.Z)):Inverse() * 
                CFrame.new(0, 0, 8 * (negitive and -1 or 1))
            )
        else
            rightarmalign:SetVelocity(Vector3.new(20, 20, 20))
            rightarmalign:SetCFrame(CFrame.new(0, 0, 0))
        end
    end
end)

-- Initial character setup
if Player.Character then
    HatdropCallback(Player.Character, function(allhats)
        for i, v in pairs(allhats) do
            if not v[1]:FindFirstChild("Handle") then continue end
            if v[2] == "headhats" then 
                v[1].Handle.Transparency = options.HeadHatTransparency or 1 
            end

            local align = Align(
                v[1].Handle, 
                parts[v[2]], 
                ((v[2] == "headhats") and (getgenv().headhats and getgenv().headhats[v[3]])) or CFrame.identity
            )
            
            if v[2] == "right" then
                rightarmalign = align
            end
        end
    end)
end

-- Character respawn handling
getgenv().conn = Player.CharacterAdded:Connect(function(Character)
    task.wait(0.1)
    HatdropCallback(Character, function(allhats)
        for i, v in pairs(allhats) do
            if not v[1]:FindFirstChild("Handle") then continue end
            if v[2] == "headhats" then 
                v[1].Handle.Transparency = options.HeadHatTransparency or 1 
            end

            local align = Align(
                v[1].Handle, 
                parts[v[2]], 
                ((v[2] == "headhats") and (getgenv().headhats and getgenv().headhats[v[3]])) or CFrame.identity
            )
            
            if v[2] == "right" then
                rightarmalign = align
            end
        end
    end)
end)
