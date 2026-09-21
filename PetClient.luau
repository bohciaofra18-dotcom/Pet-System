-- Connected Discord-GitHub: @_diegosxh_ (Discord) / @pasticcino074 (Roblox)

-- // Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GroupService = game:GetService("GroupService")
local MarketplaceService = game:GetService("MarketplaceService")
local SoundService = game:GetService("SoundService")

-- // Directories
local UI = ReplicatedStorage:WaitForChild("UI")
local Functions = ReplicatedStorage:WaitForChild("Functions")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- // Player References
local Player = Players.LocalPlayer
local PlayerGUI = Player:WaitForChild("PlayerGui")
local PlayerScripts = Player:WaitForChild("PlayerScripts")

-- // UI References
local HatchUI = PlayerGUI:WaitForChild("HatchUI")
local HatchingContainer = HatchUI:WaitForChild("HatchingFrame")
local AnimEggFrame = HatchingContainer:WaitForChild("EggFrame")
local EggViewport = AnimEggFrame:WaitForChild("EggViewport")
local PetFrame = HatchingContainer:WaitForChild("PetFrame")
local PetImage = PetFrame:WaitForChild("PetImage")
local PetRarity = PetFrame:WaitForChild("Rarity")
local PetName = PetFrame:WaitForChild("PetName")
local StopAutoHatch = HatchingContainer:WaitForChild("StopAutoHatch")

local MainShopUI = PlayerGUI:WaitForChild("Pets", 10)
local MainShopFrame = MainShopUI and MainShopUI:WaitForChild("PetsFrame", 10)

-- // Modules & Configs
local NotificationModule = require(Modules:WaitForChild("NotificationManager"))
local RaritiesModule = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("Rarities"))

-- // Sounds
local SoundsFolder = SoundService:WaitForChild("Sounds"):WaitForChild("Egg")
local CrackSoundTemplate = SoundsFolder:WaitForChild("Crack Egg Crunchy 9 (SFX)")
local BlockOpenSound = SoundsFolder:WaitForChild("LuckyBlockOpen")

-- // Remotes & Functions
local HatchPetFunction = Functions:WaitForChild("HatchPet")
local TripleHatchFunction = Functions:WaitForChild("TripleHatchPet")
local GetData_RF = Functions:WaitForChild("GetData")
local PaidHatchBroadcast = Remotes:WaitForChild("PaidHatchBroadcast")

-- // Constants
local GROUP_ID = 679870044

local GODLY_PRODUCT_1X = 3610846982
local GODLY_PRODUCT_3X = 3610847172

local DOMINUS_PRODUCT_1X = 3607918980
local DOMINUS_PRODUCT_3X = 3607918956

local BRAINROT_PRODUCT_1X = 3610515808
local BRAINROT_PRODUCT_3X = 3610515885
local BRAINROT_PRODUCT_10X = 3610515931

-- // State Variables
local isHatching = false
local isAutoHatching = false
local autoHatchThread = nil
local isSkipped = false

-- // Queue System Variables
local AnimationQueue = {}
local isProcessingQueue = false

-- // Egg Mappings
local EggModelMapping = {
	["COMMON EGG_World1"] = "Meowl Lucky Block",
	["RARE EGG_World1"] = "DEVELOPER Lucky Block",
	["EPIC EGG_World1"] = "OwnerLuckyBlock",
	["GODLY EGG_World1"] = "NEEDOH LUCKYBLOCK",
	["Brainrot EGG"] = "Brainrot Lucky Block",

	["COMMON EGG_World2"] = "Easter Egg",
	["RARE EGG_World2"] = "Glitched Lucky block",
	["EPIC EGG_World2"] = "Upgraded Lucky Block",
	["GODLY EGG_World2"] = "Dominus Egg",
	["DOMINUS EGG"] = "Dominus Egg"
}

local WorldEggDataAliases = {
	World2 = {
		["COMMON EGG"] = "COMMON1 EGG",
		["RARE EGG"] = "RARE1 EGG",
		["EPIC EGG"] = "EPIC1 EGG",
	},
}

local function ResolveDataEggName(eggName, worldFolder)
	local aliases = WorldEggDataAliases[worldFolder]
	return (aliases and aliases[eggName]) or eggName
end

local PetClient = {}

StopAutoHatch.Visible = false

local function WaitOrSkip(duration: number): boolean
	local startTime = os.clock()
	while (os.clock() - startTime) < duration do
		if isSkipped then return true end
		task.wait()
	end
	return isSkipped
end

local function SoundClone(sound)
	local clone = sound:Clone()
	clone.Parent = workspace
	clone:Play()
	clone.Ended:Connect(function()
		clone:Destroy()
	end)
	return clone
end

-- Sostituito FindFirstChild ricorsivo con ricerca sicura e ottimizzata
local function FindAssetRecursive(parent, targetName)
	local found = parent:FindFirstChild(targetName)
	if found then return found end
	for _, child in ipairs(parent:GetChildren()) do
		local result = FindAssetRecursive(child, targetName)
		if result then return result end
	end
	return nil
end

local function SetupViewportModel(viewport, eggName, worldFolder)
	viewport:ClearAllChildren()
	viewport.Visible = true
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(255, 255, 255)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)

	worldFolder = worldFolder or "World1"
	local upperName = string.upper(tostring(eggName))
	local lookupKey = upperName .. "_" .. worldFolder
	local targetModelName = EggModelMapping[lookupKey] or EggModelMapping[upperName] or EggModelMapping[eggName] or eggName

	local assetsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("LuckyBlocks")
	local originalModel = FindAssetRecursive(assetsFolder, targetModelName)
	if not originalModel then return nil end

	local modelClone = originalModel:Clone()
	for _, child in ipairs(modelClone:GetDescendants()) do
		if child:IsA("LuaSourceContainer") or child:IsA("Highlight") then
			child:Destroy()
		end
	end

	modelClone.Parent = viewport
	local centerCFrame, modelSize = modelClone:GetBoundingBox()
	local maxDim = math.max(modelSize.X, modelSize.Y, modelSize.Z)
	if maxDim < 1 then maxDim = 3 end
	modelClone:PivotTo(CFrame.new(0, 0, 0))

	local camera = Instance.new("Camera")
	camera.FieldOfView = 50
	local multiplier = (targetModelName == "Easter Egg") and 2.6 or 1.4

	local distance = (maxDim / 2) / math.tan(math.rad(camera.FieldOfView / 2))
	camera.CFrame = CFrame.new(Vector3.new(0, 0, distance * multiplier), Vector3.new(0, 0, 0))
	viewport.CurrentCamera = camera
	camera.Parent = viewport

	return modelClone
end

local function ApplyRarityColors(textLabel, rarityName)
	if RaritiesModule and RaritiesModule[rarityName] then
		local rarityData = RaritiesModule[rarityName]
		textLabel.Text = rarityName
		textLabel.TextColor3 = rarityData.Color or Color3.fromRGB(255, 255, 255)
		local stroke = textLabel:FindFirstChildOfClass("UIStroke")
		if stroke and rarityData.StrokeColor then stroke.Color = rarityData.StrokeColor end
	else
		textLabel.Text = rarityName
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

local function RevealPet(petData)
	PetFrame.Visible = true
	PetName.Text = petData.Name
	ApplyRarityColors(PetRarity, petData.Rarity)
	PetImage.Image = petData.Image
	PetName.TextScaled = true
	PetRarity.TextScaled = true

	local uiScale = PetFrame:FindFirstChild("UIScale") or Instance.new("UIScale", PetFrame)
	if isSkipped then
		uiScale.Scale = 1
	else
		uiScale.Scale = 0
		TweenService:Create(uiScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		WaitOrSkip(0.5)
	end
end

local function ProcessAnimationQueue()
	if isProcessingQueue then return end
	isProcessingQueue = true

	task.spawn(function()
		while #AnimationQueue > 0 do
			isSkipped = false
			local animRequest = table.remove(AnimationQueue, 1)

			if animRequest.HatchType == "Single" then
				PetClient:HatchAnimation(animRequest.Data.NewPet, animRequest.EggName, animRequest.WorldFolder)
			elseif animRequest.HatchType == "Triple" then
				PetClient:TripleHatchAnimation(animRequest.Data.NewPets, animRequest.EggName, animRequest.WorldFolder)
			elseif animRequest.HatchType == "Ten" then
				PetClient:TenHatchAnimation(animRequest.Data.NewPets, animRequest.EggName, animRequest.WorldFolder)
			end

			task.wait(0.15)
		end
		isProcessingQueue = false
	end)
end

function PetClient:HatchAnimation(petData, eggName, worldFolder)
	if MainShopFrame then MainShopFrame.Visible = false end
	for _, ui in ipairs(PlayerGUI:GetChildren()) do
		if ui:IsA("ScreenGui") and ui ~= HatchUI and ui.Name ~= "GUI" and ui.Name ~= "LoadingGui" then ui.Enabled = false end
	end
	HatchUI.Enabled = true
	HatchingContainer.Visible = true
	AnimEggFrame.Visible = true
	EggViewport.Visible = true
	PetFrame.Visible = false

	local eggUIScale = AnimEggFrame:FindFirstChild("UIScale") or Instance.new("UIScale", AnimEggFrame)
	eggUIScale.Scale = 1
	EggViewport.Rotation = 0
	EggViewport.ImageTransparency = 0
	SetupViewportModel(EggViewport, eggName or "COMMON EGG", worldFolder)

	local clickButton = HatchUI:FindFirstChild("HatchClickButton") or Instance.new("TextButton")
	clickButton.Name = "HatchClickButton"
	clickButton.Text = ""
	clickButton.BackgroundTransparency = 1
	clickButton.Size = UDim2.new(1, 0, 1, 0)
	clickButton.ZIndex = 999
	clickButton.Visible = true
	clickButton.Parent = HatchUI

	local clickCount = 0
	local clickReady = true
	local clickDone = Instance.new("BindableEvent")
	local shakeIntensities = {14, 24, 38}
	local shakeSpeeds = {0.1, 0.08, 0.06}

	local connection
	connection = clickButton.Activated:Connect(function()
		if not clickReady or clickCount >= 3 or isSkipped then return end
		clickReady = false
		clickCount += 1

		local shakeInfo = TweenInfo.new(shakeSpeeds[clickCount], Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 0, true)
		TweenService:Create(eggUIScale, TweenInfo.new(shakeSpeeds[clickCount] * 2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1 + shakeIntensities[clickCount] * 0.015}):Play()

		local rot = (clickCount % 2 == 0) and shakeIntensities[clickCount] or -shakeIntensities[clickCount]
		TweenService:Create(EggViewport, shakeInfo, {Rotation = rot}):Play()
		SoundClone(CrackSoundTemplate)
		WaitOrSkip(shakeSpeeds[clickCount])

		TweenService:Create(EggViewport, TweenInfo.new(0.05, Enum.EasingStyle.Linear), {Rotation = 0}):Play()
		TweenService:Create(eggUIScale, TweenInfo.new(0.1), {Scale = 1}):Play()

		if clickCount >= 3 or isSkipped then
			if connection then connection:Disconnect() end
			clickDone:Fire()
		else
			clickReady = true
		end
	end)

	while not isSkipped and clickCount < 3 do task.wait(0.05) end
	if connection then connection:Disconnect() end
	if clickButton then clickButton:Destroy() end
	clickDone:Destroy()

	if not isSkipped then
		TweenService:Create(eggUIScale, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 2.8}):Play()
		TweenService:Create(EggViewport, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {ImageTransparency = 1}):Play()
		WaitOrSkip(0.3)
		SoundClone(BlockOpenSound)
	end

	EggViewport.ImageTransparency = 0
	eggUIScale.Scale = 1
	AnimEggFrame.Visible = false
	RevealPet(petData)

	if isSkipped then task.wait(0.6) else WaitOrSkip(2.5) end
	PetFrame.Visible = false
	HatchingContainer.Visible = false

	if #AnimationQueue == 0 then
		HatchUI.Enabled = false
		for _, ui in ipairs(PlayerGUI:GetChildren()) do
			if ui:IsA("ScreenGui") and ui.Name ~= "LoadingGui" then ui.Enabled = true end
		end
	end
end

function PetClient:TripleHatchAnimation(newPets, eggName, worldFolder)
	if MainShopFrame then MainShopFrame.Visible = false end
	for _, ui in ipairs(PlayerGUI:GetChildren()) do
		if ui:IsA("ScreenGui") and ui ~= HatchUI and ui.Name ~= "GUI" and ui.Name ~= "LoadingGui" then ui.Enabled = false end
	end

	HatchUI.Enabled = true
	HatchingContainer.Visible = true
	AnimEggFrame.Visible = false
	PetFrame.Visible = false

	local eggScale = 0.8
	local petScale = 0.70
	local positions = {
		UDim2.new(-0.2, 0, 0.55, 0),
		UDim2.new(0.5, 0, 0.42, 0),
		UDim2.new(1.2, 0, 0.55, 0),
	}

	local eggClones = {}
	for i = 1, math.min(3, #newPets) do
		local clone = AnimEggFrame:Clone()
		clone.Visible = true
		clone.AnchorPoint = Vector2.new(0.5, 0.5)
		clone.Position = positions[i] or UDim2.new(0.5, 0, 0.5, 0)
		local cloneScale = clone:FindFirstChild("UIScale") or Instance.new("UIScale", clone)
		cloneScale.Scale = eggScale
		local vp = clone:FindFirstChild("EggViewport")
		vp.Visible = true
		vp.Rotation = 0
		vp.ImageTransparency = 0
		SetupViewportModel(vp, eggName or "COMMON EGG", worldFolder)
		clone.Parent = HatchingContainer
		eggClones[i] = clone
	end

	local clickButton = HatchUI:FindFirstChild("TripleHatchClickButton") or Instance.new("TextButton")
	clickButton.Name = "TripleHatchClickButton"
	clickButton.Text = ""
	clickButton.BackgroundTransparency = 1
	clickButton.Size = UDim2.new(1, 0, 1, 0)
	clickButton.ZIndex = 999
	clickButton.Visible = true
	clickButton.Parent = HatchUI

	local clickCount = 0
	local clickReady = true
	local connection
	connection = clickButton.Activated:Connect(function()
		if not clickReady or clickCount >= 3 or isSkipped then return end
		clickReady = false
		clickCount += 1
		SoundClone(CrackSoundTemplate)

		for _, clone in ipairs(eggClones) do
			local cloneScale = clone:FindFirstChild("UIScale")
			if cloneScale then TweenService:Create(cloneScale, TweenInfo.new(0.16, Enum.EasingStyle.Back), {Scale = eggScale + 0.3}):Play() end
		end
		WaitOrSkip(0.1)
		for _, clone in ipairs(eggClones) do
			local cloneScale = clone:FindFirstChild("UIScale")
			if cloneScale then TweenService:Create(cloneScale, TweenInfo.new(0.1), {Scale = eggScale}):Play() end
		end
		if clickCount < 3 and not isSkipped then clickReady = true end
	end)

	while not isSkipped and clickCount < 3 do task.wait(0.05) end
	if connection then connection:Disconnect() end
	if clickButton then clickButton:Destroy() end

	for _, clone in ipairs(eggClones) do clone:Destroy() end

	for i = 1, #newPets do
		local petData = newPets[i]
		if not petData then continue end

		local petFrameClone = PetFrame:Clone()
		petFrameClone.Visible = true
		petFrameClone.AnchorPoint = Vector2.new(0.5, 0.5)
		petFrameClone.Position = positions[i] or UDim2.new(0.5, 0, (i * 0.1) - 0.2, 0)
		petFrameClone.Parent = HatchingContainer

		ApplyRarityColors(petFrameClone:FindFirstChild("Rarity"), petData.Rarity)
		petFrameClone:FindFirstChild("PetName").Text = petData.Name
		petFrameClone:FindFirstChild("PetImage").Image = petData.Image

		local uiScale = petFrameClone:FindFirstChild("UIScale") or Instance.new("UIScale", petFrameClone)
		if isSkipped then
			uiScale.Scale = petScale
		else
			uiScale.Scale = 0
			TweenService:Create(uiScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = petScale}):Play()
		end
	end

	if not isSkipped then SoundClone(BlockOpenSound) end
	if isSkipped then task.wait(0.8) else WaitOrSkip(2.8) end

	for _, child in ipairs(HatchingContainer:GetChildren()) do
		if child ~= AnimEggFrame and child ~= PetFrame and child ~= StopAutoHatch then child:Destroy() end
	end

	HatchingContainer.Visible = false
	if #AnimationQueue == 0 then
		HatchUI.Enabled = false
		for _, ui in ipairs(PlayerGUI:GetChildren()) do
			if ui:IsA("ScreenGui") and ui.Name ~= "LoadingGui" then ui.Enabled = true end
		end
	end
end

function PetClient:TenHatchAnimation(newPets, eggName, worldFolder)
	if MainShopFrame then MainShopFrame.Visible = false end
	for _, ui in ipairs(PlayerGUI:GetChildren()) do
		if ui:IsA("ScreenGui") and ui ~= HatchUI and ui.Name ~= "GUI" and ui.Name ~= "LoadingGui" then ui.Enabled = false end
	end

	HatchUI.Enabled = true
	HatchingContainer.Visible = true
	AnimEggFrame.Visible = false
	PetFrame.Visible = false
	
	local originalContainerSize = HatchingContainer.Size
	local originalContainerAnchor = HatchingContainer.AnchorPoint
	local originalContainerPos = HatchingContainer.Position

	HatchingContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	HatchingContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
	HatchingContainer.Size = UDim2.new(0.9, 0, 0.9, 0)

	local eggScale = 0.55
	local petScale = 0.50

	local allPositions = {
		UDim2.new(0.10, 0, 0.25, 0), UDim2.new(0.30, 0, 0.25, 0), UDim2.new(0.50, 0, 0.25, 0), UDim2.new(0.70, 0, 0.25, 0), UDim2.new(0.90, 0, 0.25, 0),
		UDim2.new(0.10, 0, 0.75, 0), UDim2.new(0.30, 0, 0.75, 0), UDim2.new(0.50, 0, 0.75, 0), UDim2.new(0.70, 0, 0.75, 0), UDim2.new(0.90, 0, 0.75, 0),
	}

	local eggClones = {}
	for i = 1, math.min(10, #newPets) do
		local clone = AnimEggFrame:Clone()
		clone.Visible = true
		clone.AnchorPoint = Vector2.new(0.5, 0.5)
		clone.Position = allPositions[i] or UDim2.new(0.5, 0, 0.5, 0)
		local cloneScale = clone:FindFirstChild("UIScale") or Instance.new("UIScale", clone)
		cloneScale.Scale = eggScale
		local vp = clone:FindFirstChild("EggViewport")
		vp.Visible = true
		vp.Rotation = 0
		vp.ImageTransparency = 0
		SetupViewportModel(vp, eggName or "COMMON EGG", worldFolder)
		clone.Parent = HatchingContainer
		eggClones[i] = clone
	end

	local clickButton = HatchUI:FindFirstChild("TenHatchClickButton") or Instance.new("TextButton")
	clickButton.Name = "TenHatchClickButton"
	clickButton.Text = ""
	clickButton.BackgroundTransparency = 1
	clickButton.Size = UDim2.new(1, 0, 1, 0)
	clickButton.ZIndex = 999
	clickButton.Visible = true
	clickButton.Parent = HatchUI

	local clickCount = 0
	local clickReady = true
	local connection

	connection = clickButton.Activated:Connect(function()
		if not clickReady or clickCount >= 3 or isSkipped then return end
		clickReady = false
		clickCount += 1
		SoundClone(CrackSoundTemplate)

		for _, clone in ipairs(eggClones) do
			local cloneScale = clone:FindFirstChild("UIScale")
			if cloneScale then TweenService:Create(cloneScale, TweenInfo.new(0.16, Enum.EasingStyle.Back), {Scale = eggScale + 0.12}):Play() end
		end
		WaitOrSkip(0.1)
		for _, clone in ipairs(eggClones) do
			local cloneScale = clone:FindFirstChild("UIScale")
			if cloneScale then TweenService:Create(cloneScale, TweenInfo.new(0.1), {Scale = eggScale}):Play() end
		end
		if clickCount < 3 and not isSkipped then clickReady = true end
	end)

	while not isSkipped and clickCount < 3 do task.wait(0.05) end
	if connection then connection:Disconnect() end
	if clickButton then clickButton:Destroy() end

	for _, clone in ipairs(eggClones) do clone:Destroy() end

	for i = 1, #newPets do
		local petData = newPets[i]
		if not petData then continue end

		local petFrameClone = PetFrame:Clone()
		petFrameClone.Visible = true
		petFrameClone.AnchorPoint = Vector2.new(0.5, 0.5)
		petFrameClone.Position = allPositions[i] or UDim2.new(0.5, 0, 0.5, 0)
		petFrameClone.Parent = HatchingContainer

		ApplyRarityColors(petFrameClone:FindFirstChild("Rarity"), petData.Rarity)
		petFrameClone:FindFirstChild("PetName").Text = petData.Name
		petFrameClone:FindFirstChild("PetImage").Image = petData.Image

		local uiScale = petFrameClone:FindFirstChild("UIScale") or Instance.new("UIScale", petFrameClone)
		if isSkipped then
			uiScale.Scale = petScale
		else
			uiScale.Scale = 0
			TweenService:Create(uiScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = petScale}):Play()
		end
	end

	if not isSkipped then SoundClone(BlockOpenSound) end
	if isSkipped then task.wait(0.8) else WaitOrSkip(3.2) end

	HatchingContainer.Size = originalContainerSize
	HatchingContainer.AnchorPoint = originalContainerAnchor
	HatchingContainer.Position = originalContainerPos

	for _, child in ipairs(HatchingContainer:GetChildren()) do
		if child ~= AnimEggFrame and child ~= PetFrame and child ~= StopAutoHatch then child:Destroy() end
	end

	HatchingContainer.Visible = false
	if #AnimationQueue == 0 then
		HatchUI.Enabled = false
		for _, ui in ipairs(PlayerGUI:GetChildren()) do
			if ui:IsA("ScreenGui") and ui.Name ~= "LoadingGui" then ui.Enabled = true end
		end
	end
end

function PetClient:PurchaseRequest(eggName, worldFolder)
	if isHatching then return end

	if eggName == "GODLY EGG" or eggName == "GODLY1 EGG" then
		MarketplaceService:PromptProductPurchase(Player, GODLY_PRODUCT_1X)
		return
	elseif eggName == "DOMINUS EGG" then
		MarketplaceService:PromptProductPurchase(Player, DOMINUS_PRODUCT_1X)
		return
	elseif eggName == "Brainrot EGG" then
		MarketplaceService:PromptProductPurchase(Player, BRAINROT_PRODUCT_1X)
		return
	end

	isHatching = true
	local success, result = HatchPetFunction:InvokeServer(ResolveDataEggName(eggName, worldFolder))
	if success then
		pcall(function()
			table.insert(AnimationQueue, { HatchType = "Single", Data = result, EggName = eggName, WorldFolder = worldFolder })
			ProcessAnimationQueue()
		end)
	else
		if isAutoHatching then self:StopAutoHatch() end
		NotificationModule.show(tostring(result), "Error")
	end
	isHatching = false
end

function PetClient:TriplePurchaseRequest(eggName, worldFolder)
	if isHatching then return end

	if eggName == "GODLY EGG" or eggName == "GODLY1 EGG" then
		MarketplaceService:PromptProductPurchase(Player, GODLY_PRODUCT_3X)
		return
	elseif eggName == "DOMINUS EGG" then
		MarketplaceService:PromptProductPurchase(Player, DOMINUS_PRODUCT_3X)
		return
	elseif eggName == "Brainrot EGG" then
		MarketplaceService:PromptProductPurchase(Player, BRAINROT_PRODUCT_3X)
		return
	end

	isHatching = true
	local success, result = TripleHatchFunction:InvokeServer(ResolveDataEggName(eggName, worldFolder))
	if success then
		pcall(function()
			table.insert(AnimationQueue, { HatchType = "Triple", Data = result, EggName = eggName, WorldFolder = worldFolder })
			ProcessAnimationQueue()
		end)
	else
		if isAutoHatching then self:StopAutoHatch() end
		NotificationModule.show(tostring(result), "Error")
		if result == "Join the Group to triple hatch!" then GroupService:PromptJoinAsync(GROUP_ID, Player) end
	end
	isHatching = false
end

function PetClient:TenXPurchaseRequest(eggName, worldFolder)
	if eggName == "Brainrot EGG" or eggName == "Brainrot" then
		MarketplaceService:PromptProductPurchase(Player, BRAINROT_PRODUCT_10X)
		return
	end
end

function PetClient:StartAutoHatch(eggName, worldFolder)
	if eggName == "GODLY EGG" or eggName == "GODLY1 EGG" or eggName == "DOMINUS EGG" or eggName == "Brainrot EGG" then return end
	if isAutoHatching then return end
	isAutoHatching = true
	StopAutoHatch.Visible = true
	if MainShopFrame then MainShopFrame.Visible = false end

	autoHatchThread = task.spawn(function()
		while isAutoHatching do
			self:PurchaseRequest(eggName, worldFolder)
			local elapsed = 0
			while elapsed < 0.1 do
				if not isAutoHatching then break end
				elapsed += task.wait()
			end
		end
		autoHatchThread = nil
	end)
end

function PetClient:StopAutoHatch()
	isAutoHatching = false
	isHatching = false
	table.clear(AnimationQueue)
	EggViewport.Rotation = 0
	EggViewport.ImageTransparency = 0
	AnimEggFrame.Visible = false
	PetFrame.Visible = false
	HatchingContainer.Visible = false
	HatchUI.Enabled = false
	StopAutoHatch.Visible = false
	for _, ui in ipairs(PlayerGUI:GetChildren()) do
		if ui:IsA("ScreenGui") and ui.Name ~= "LoadingGui" then ui.Enabled = true end
	end
end

function PetClient:AutoHatchRequest(eggName, worldFolder)
	if eggName == "GODLY EGG" or eggName == "GODLY1 EGG" or eggName == "DOMINUS EGG" or eggName == "Brainrot EGG" then return end
	local ownsPass = GetData_RF:InvokeServer("GetClaimedData")
	local ClaimFreeGamepassHandler = require(PlayerScripts:WaitForChild("UI"):WaitForChild("ClaimFreeGamepassHandler"))
	if ownsPass then
		self:StartAutoHatch(eggName, worldFolder)
	else
		ClaimFreeGamepassHandler.OpenFrame()
		NotificationModule.show("Claim the free gamepass pack to Auto Hatch!", "Error")
	end
end

PaidHatchBroadcast.OnClientEvent:Connect(function(hatchType, data)
	local eggName = data and data.EggName or "COMMON EGG"
	local worldFolder = data and data.WorldFolder or "World1"

	table.insert(AnimationQueue, {
		HatchType = hatchType,
		Data = data,
		EggName = eggName,
		WorldFolder = worldFolder
	})
	ProcessAnimationQueue()
end)

StopAutoHatch.Activated:Connect(function()
	PetClient:StopAutoHatch()
end)

function PetClient:IsHatching(): boolean
	return isHatching or #AnimationQueue > 0 or isProcessingQueue or HatchingContainer.Visible
end

return PetClient
