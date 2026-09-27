-- Connected Discord-GitHub: @_diegosxh_ (Discord) / @pasticcino074 (Roblox)

-- // Services Initialization
local ReplicatedStorage = game:GetService("ReplicatedStorage") -- Fetches ReplicatedStorage to access shared assets and network conduits.
local Players = game:GetService("Players") -- Fetches Players service to manage local and remote client states.
local TweenService = game:GetService("TweenService") -- Fetches TweenService to execute smooth UI and property animations.
local GroupService = game:GetService("GroupService") -- Fetches GroupService to prompt group joins for permissions.
local MarketplaceService = game:GetService("MarketplaceService") -- Fetches MarketplaceService to handle developer product purchasing prompts.
local SoundService = game:GetService("SoundService") -- Fetches SoundService to manage audio playback hierarchies.

-- // Directories & Remotes Setup
local UI = ReplicatedStorage:WaitForChild("UI") -- Awaits the UI folder container inside ReplicatedStorage.
local Functions = ReplicatedStorage:WaitForChild("Functions") -- Awaits remote functions container for synchronous client-server RPC.
local Modules = ReplicatedStorage:WaitForChild("Modules") -- Awaits shared module scripts container.
local Remotes = ReplicatedStorage:WaitForChild("Remotes") -- Awaits remote events container for asynchronous network broadcasting.

-- // Player References
local Player = Players.LocalPlayer -- References the local client player instance running this script.
local PlayerGUI = Player:WaitForChild("PlayerGui") -- Awaits the PlayerGui container for GUI manipulation.
local PlayerScripts = Player:WaitForChild("PlayerScripts") -- Awaits client-side scripts folder.

-- // UI Elements Caching
local HatchUI = PlayerGUI:WaitForChild("HatchUI") -- Awaits the main hatching interface container screen.
local HatchingContainer = HatchUI:WaitForChild("HatchingFrame") -- Awaits the specific layout frame hosting egg animations.
local AnimEggFrame = HatchingContainer:WaitForChild("EggFrame") -- Awaits the template container representing eggs during animations.
local EggViewport = AnimEggFrame:WaitForChild("EggViewport") -- Awaits the 3D ViewportFrame rendering physical egg models.
local PetFrame = HatchingContainer:WaitForChild("PetFrame") -- Awaits the reward container displaying hatched pets.
local PetImage = PetFrame:WaitForChild("PetImage") -- Awaits the image label displaying pet icons.
local PetRarity = PetFrame:WaitForChild("Rarity") -- Awaits the text label displaying pet rarity tiers.
local PetName = PetFrame:WaitForChild("PetName") -- Awaits the text label displaying pet names.
local StopAutoHatch = HatchingContainer:WaitForChild("StopAutoHatch") -- Awaits the emergency button to cancel auto-hatching loops.

local MainShopUI = PlayerGUI:WaitForChild("Pets", 10) -- Safely awaits the pets shop interface with a 10-second timeout fallback.
local MainShopFrame = MainShopUI and MainShopUI:WaitForChild("PetsFrame", 10) -- Awaits the shop frame if MainShopUI successfully resolved.

-- // Modules & Configs Loading
local NotificationModule = require(Modules:WaitForChild("NotificationManager")) -- Requires notification module to display alert popups.
local RaritiesModule = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("Rarities")) -- Requires config data mapping rarity colors and styling.

-- // Sound Assets Caching
local SoundsFolder = SoundService:WaitForChild("Sounds"):WaitForChild("Egg") -- Navigates to egg-specific audio folders.
local CrackSoundTemplate = SoundsFolder:WaitForChild("Crack Egg Crunchy 9 (SFX)") -- Caches sound template for egg cracking impacts.
local BlockOpenSound = SoundsFolder:WaitForChild("LuckyBlockOpen") -- Caches sound template for final reward reveals.

-- // Network Functions & Remotes
local HatchPetFunction = Functions:WaitForChild("HatchPet") -- RemoteFunction for single egg purchases and server validation.
local TripleHatchFunction = Functions:WaitForChild("TripleHatchPet") -- RemoteFunction for triple egg bundle purchases.
local GetData_RF = Functions:WaitForChild("GetData") -- RemoteFunction for fetching player data states from server.
local PaidHatchBroadcast = Remotes:WaitForChild("PaidHatchBroadcast") -- RemoteEvent for receiving server-authenticated paid hatch broadcasts.

-- // Constants Definitions
local GROUP_ID = 679870044 -- Defines the target Roblox group ID required for group perks.

local GODLY_PRODUCT_1X = 3610846982 -- Developer product ID for single godly purchases.
local GODLY_PRODUCT_3X = 3610847172 -- Developer product ID for triple godly purchases.

local DOMINUS_PRODUCT_1X = 3607918980 -- Developer product ID for single dominus purchases.
local DOMINUS_PRODUCT_3X = 3607918956 -- Developer product ID for triple dominus purchases.

local BRAINROT_PRODUCT_1X = 3610515808 -- Developer product ID for single brainrot purchases.
local BRAINROT_PRODUCT_3X = 3610515885 -- Developer product ID for triple brainrot purchases.
local BRAINROT_PRODUCT_10X = 3610515931 -- Developer product ID for 10x bulk brainrot purchases.

-- // State Management Variables
local isHatching = false -- Boolean flag tracking whether an active hatch transaction is currently processing.
local isAutoHatching = false -- Boolean flag tracking whether auto-hatch mode is toggled on.
local autoHatchThread = nil -- Stores reference to the active auto-hatch coroutine thread.
local isSkipped = false -- Boolean flag permitting users to skip active animation sequences instantly.

-- // Queue System Variables
local AnimationQueue = {} -- Table acting as a FIFO queue to store incoming hatch request packets sequentially.
local isProcessingQueue = false -- Boolean flag preventing concurrent execution loops inside the queue processor.

-- // Egg Mappings Configuration
local EggModelMapping = { -- Dictionary mapping logical UI egg names to physical 3D asset model names in workspace storage.
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

local WorldEggDataAliases = { -- Nested configuration table handling world-specific data string conversions.
	World2 = {
		["COMMON EGG"] = "COMMON1 EGG",
		["RARE EGG"] = "RARE1 EGG",
		["EPIC EGG"] = "EPIC1 EGG",
	},
}

-- Resolves normalized egg data keys across different worlds using fallback alias mapping.
local function ResolveDataEggName(eggName, worldFolder)
	local aliases = WorldEggDataAliases[worldFolder] -- Retrieves world-specific aliases table if it exists.
	return (aliases and aliases[eggName]) or eggName -- Returns the aliased name or falls back to the original input name.
end

local PetClient = {} -- Initializes main client-side module table.

StopAutoHatch.Visible = false -- Hides the stop auto-hatch button by default upon script initialization.

-- High-precision asynchronous sleep utility using os.clock().
local function WaitOrSkip(duration: number): boolean
	local startTime = os.clock() -- Captures current high-resolution CPU clock time.
	while (os.clock() - startTime) < duration do -- Loops until desired duration elapses.
		if isSkipped then return true end -- Returns immediately if the skip flag is triggered by the user.
		task.wait() -- Yields execution for one frame to prevent CPU lockups.
	end
	return isSkipped -- Returns final skip status state.
end

-- Manages dynamic audio playback by cloning sound templates into the workspace.
local function SoundClone(sound)
	local clone = sound:Clone() -- Clones the target sound template to allow overlapping audio playback instances.
	clone.Parent = workspace -- Parents the sound clone directly into the workspace container.
	clone:Play() -- Executes audio playback immediately.
	clone.Ended:Connect(function() -- Connects an event listener to trigger when audio finishes playing.
		clone:Destroy() -- Destroys the sound instance automatically to prevent memory leaks.
	end)
	return clone -- Returns the active sound clone reference.
end

-- Custom recursive tree traversal to safely locate model assets without using deprecated deep search parameters.
local function FindAssetRecursive(parent, targetName)
	local found = parent:FindFirstChild(targetName) -- Checks current hierarchical level for target asset.
	if found then return found end -- Returns found instance immediately if matched.
	for _, child in ipairs(parent:GetChildren()) do -- Iterates through all child instances in current level.
		local result = FindAssetRecursive(child, targetName) -- Recursively searches deeper branches of the tree.
		if result then return result end -- Propagates found asset upward through return calls.
	end
	return nil -- Returns nil if target asset cannot be located in branch.
end

-- Configures 3D viewport frames dynamically by calculating bounding boxes and focal lengths.
local function SetupViewportModel(viewport, eggName, worldFolder)
	viewport:ClearAllChildren() -- Clears prior models inside viewport to prevent visual stacking.
	viewport.Visible = true -- Ensures viewport frame visibility is enabled.
	viewport.BackgroundTransparency = 1 -- Sets background transparency to fully transparent.
	viewport.Ambient = Color3.fromRGB(255, 255, 255) -- Sets ambient lighting color to pure white.
	viewport.LightColor = Color3.fromRGB(255, 255, 255) -- Sets directional lighting color to pure white.

	worldFolder = worldFolder or "World1" -- Applies default world folder fallback if argument is nil.
	local upperName = string.upper(tostring(eggName)) -- Converts egg name to uppercase for uniform matching keys.
	local lookupKey = upperName .. "_" .. worldFolder -- Concatenates lookup key combining egg name and world identifier.
	local targetModelName = EggModelMapping[lookupKey] or EggModelMapping[upperName] or EggModelMapping[eggName] or eggName -- Resolves physical asset name via mapping lookups.

	local assetsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("LuckyBlocks") -- References assets directory.
	local originalModel = FindAssetRecursive(assetsFolder, targetModelName) -- Locates original model using recursive search utility.
	if not originalModel then return nil end -- Exits function early if model template is missing.

	local modelClone = originalModel:Clone() -- Clones the model asset for local viewport rendering.
	for _, child in ipairs(modelClone:GetDescendants()) do -- Iterates through all descendants of the cloned model.
		if child:IsA("LuaSourceContainer") or child:IsA("Highlight") then -- Checks if descendant is a script container or highlight effect.
			child:Destroy() -- Destroys unauthorized scripts/highlights to secure client performance.
		end
	end

	modelClone.Parent = viewport -- Parents cloned model inside the viewport frame.
	local centerCFrame, modelSize = modelClone:GetBoundingBox() -- Calculates bounding box size and center coordinates.
	local maxDim = math.max(modelSize.X, modelSize.Y, modelSize.Z) -- Determines maximum dimensional axis of the model.
	if maxDim < 1 then maxDim = 3 end -- Applies minimum boundary size fallback.
	modelClone:PivotTo(CFrame.new(0, 0, 0)) -- Centers model pivot point to origin vector.

	local camera = Instance.new("Camera") -- Instantiates a dedicated viewport camera.
	camera.FieldOfView = 50 -- Sets camera field of view angle.
	local multiplier = (targetModelName == "Easter Egg") and 2.6 or 1.4 -- Adjusts zoom multiplier based on specific model scaling requirements.

	local distance = (maxDim / 2) / math.tan(math.rad(camera.FieldOfView / 2)) -- Trigonometrically calculates optimal camera distance.
	camera.CFrame = CFrame.new(Vector3.new(0, 0, distance * multiplier), Vector3.new(0, 0, 0)) -- Positions camera facing origin vector.
	viewport.CurrentCamera = camera -- Assigns camera as active viewport rendering device.
	camera.Parent = viewport -- Parents camera inside viewport.

	return modelClone -- Returns cloned model reference.
end

-- Applies data-driven rarity color profiles safely with fallback parameters.
local function ApplyRarityColors(textLabel, rarityName)
	if RaritiesModule and RaritiesModule[rarityName] then -- Checks if rarity configuration dictionary contains specified rarity tier.
		local rarityData = RaritiesModule[rarityName] -- Retrieves rarity styling data table.
		textLabel.Text = rarityName -- Assigns rarity text string to label.
		textLabel.TextColor3 = rarityData.Color or Color3.fromRGB(255, 255, 255) -- Applies custom text color with white fallback.
		local stroke = textLabel:FindFirstChildOfClass("UIStroke") -- Locates UIStroke component inside text label.
		if stroke and rarityData.StrokeColor then stroke.Color = rarityData.StrokeColor end -- Applies stroke color if defined.
	else
		textLabel.Text = rarityName -- Assigns fallback plain text.
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- Applies default white text color.
	end
end

-- Renders pet reward details using elastic scaling tweens for visual feedback.
local function RevealPet(petData)
	PetFrame.Visible = true -- Makes pet reward frame visible.
	PetName.Text = petData.Name -- Sets pet name text string.
	ApplyRarityColors(PetRarity, petData.Rarity) -- Applies rarity styling colors to pet rarity label.
	PetImage.Image = petData.Image -- Sets pet icon image asset ID.
	PetName.TextScaled = true -- Enables text scaling for pet name.
	PetRarity.TextScaled = true -- Enables text scaling for rarity text.

	local uiScale = PetFrame:FindFirstChild("UIScale") or Instance.new("UIScale", PetFrame) -- Gets or creates UIScale component.
	if isSkipped then
		uiScale.Scale = 1 -- Instantly sets scale to full if animation is skipped.
	else
		uiScale.Scale = 0 -- Initializes scale to zero for pop-in animation effect.
		TweenService:Create(uiScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play() -- Tweens scale back to full using elastic easing.
		WaitOrSkip(0.5) -- Waits for reveal animation duration.
	end
end

-- Background coroutine worker processing AnimationQueue items sequentially (FIFO pattern).
local function ProcessAnimationQueue()
	if isProcessingQueue then return end -- Exits early if queue worker thread is already active.
	isProcessingQueue = true -- Locks queue processing flag to prevent race conditions.

	task.spawn(function() -- Spawns asynchronous background execution thread.
		while #AnimationQueue > 0 do -- Loops while pending animation packets remain in queue table.
			isSkipped = false -- Resets skip flag state for incoming animation.
			local animRequest = table.remove(AnimationQueue, 1) -- Extracts the oldest animation request packet from index 1 (FIFO).

			if animRequest.HatchType == "Single" then
				PetClient:HatchAnimation(animRequest.Data.NewPet, animRequest.EggName, animRequest.WorldFolder) -- Executes single hatch animation sequence.
			elseif animRequest.HatchType == "Triple" then
				PetClient:TripleHatchAnimation(animRequest.Data.NewPets, animRequest.EggName, animRequest.WorldFolder) -- Executes triple hatch animation sequence.
			elseif animRequest.HatchType == "Ten" then
				PetClient:TenHatchAnimation(animRequest.Data.NewPets, animRequest.EggName, animRequest.WorldFolder) -- Executes ten-fold bulk hatch animation sequence.
			end

			task.wait(0.15) -- Brief delay buffer between successive animations.
		end
		isProcessingQueue = false -- Unlocks queue processing flag when queue table is empty.
	end)
end

-- Manages interactive single egg cracking physics and state transitions.
function PetClient:HatchAnimation(petData, eggName, worldFolder)
	if MainShopFrame then MainShopFrame.Visible = false end -- Hides shop interface to prevent visual clutter.
	for _, ui in ipairs(PlayerGUI:GetChildren()) do -- Iterates through all screen GUIs in player interface.
		if ui:IsA("ScreenGui") and ui ~= HatchUI and ui.Name ~= "GUI" and ui.Name ~= "LoadingGui" then ui.Enabled = false end -- Disables background UI elements during hatching.
	end
	HatchUI.Enabled = true -- Enables main hatch screen GUI.
	HatchingContainer.Visible = true -- Makes hatching layout container visible.
	AnimEggFrame.Visible = true -- Makes egg container frame visible.
	EggViewport.Visible = true -- Makes egg viewport frame visible.
	PetFrame.Visible = false -- Hides pet reward frame during egg phase.

	local eggUIScale = AnimEggFrame:FindFirstChild("UIScale") or Instance.new("UIScale", AnimEggFrame) -- Gets or creates UIScale component.
	eggUIScale.Scale = 1 -- Resets scale to default baseline.
	EggViewport.Rotation = 0 -- Resets rotation angle.
	EggViewport.ImageTransparency = 0 -- Resets transparency level.
	SetupViewportModel(EggViewport, eggName or "COMMON EGG", worldFolder) -- Populates viewport with target 3D egg model.

	local clickButton = HatchUI:FindFirstChild("HatchClickButton") or Instance.new("TextButton") -- Gets or creates click interaction button.
	clickButton.Name = "HatchClickButton"
	clickButton.Text = ""
	clickButton.BackgroundTransparency = 1
	clickButton.Size = UDim2.new(1, 0, 1, 0)
	clickButton.ZIndex = 999
	clickButton.Visible = true
	clickButton.Parent = HatchUI

	local clickCount = 0 -- Tracks number of clicks performed by user.
	local clickReady = boolean and true or true -- Establishes click cooldown readiness flag.
	local clickDone = Instance.new("BindableEvent") -- Creates bindable event for signal coordination.
	local shakeIntensities = {14, 24, 38} -- Defines progressive shake intensity tiers per click.
	local shakeSpeeds = {0.1, 0.08, 0.06} -- Defines progressive shake duration speeds per click.

	local connection
	connection = clickButton.Activated:Connect(function() -- Connects click activation listener for egg cracking interaction.
		if not clickReady or clickCount >= 3 or isSkipped then return end -- Guard clause preventing rapid multi-clicks or post-completion triggers.
		clickReady = false -- Locks click readiness until current shake tween finishes.
		clickCount += 1 -- Increments click counter tally.

		local shakeInfo = TweenInfo.new(shakeSpeeds[clickCount], Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 0, true) -- Sets tween configuration for shake bounce effect.
		TweenService:Create(eggUIScale, TweenInfo.new(shakeSpeeds[clickCount] * 2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1 + shakeIntensities[clickCount] * 0.015}):Play() -- Scales egg up dynamically on impact.

		local rot = (clickCount % 2 == 0) and shakeIntensities[clickCount] or -shakeIntensities[clickCount] -- Alternates rotation direction per click.
		TweenService:Create(EggViewport, shakeInfo, {Rotation = rot}):Play() -- Executes rotation shake tween.
		SoundClone(CrackSoundTemplate) -- Plays crunch sound effect instance.
		WaitOrSkip(shakeSpeeds[clickCount]) -- Waits for shake duration using skip-aware utility.

		TweenService:Create(EggViewport, TweenInfo.new(0.05, Enum.EasingStyle.Linear), {Rotation = 0}):Play() -- Resets egg rotation back to zero.
		TweenService:Create(eggUIScale, TweenInfo.new(0.1), {Scale = 1}):Play() -- Resets egg scale back to normal.

		if clickCount >= 3 or isSkipped then
			if connection then connection:Disconnect() end -- Disconnects click event connection upon completion.
			clickDone:Fire() -- Fires bindable event signal to resume main thread.
		else
			clickReady = true -- Restores click readiness for next tap.
		end
	end)

	while not isSkipped and clickCount < 3 do task.wait(0.05) end -- Yields thread execution until 3 clicks are completed or user skips.
	if connection then connection:Disconnect() end -- Ensures cleanup of connection pointer.
	if clickButton then clickButton:Destroy() end -- Destroys interactive click button instance.
	clickDone:Destroy() -- Destroys bindable event instance.

	if not isSkipped then
		TweenService:Create(eggUIScale, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 2.8}):Play() -- Explodes egg scale outward before opening.
		TweenService:Create(EggViewport, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {ImageTransparency = 1}):Play() -- Fades viewport transparency out.
		WaitOrSkip(0.3) -- Waits for explosion transition duration.
		SoundClone(BlockOpenSound) -- Plays final reward opening sound effect.
	end

	EggViewport.ImageTransparency = 0 -- Resets image transparency property.
	eggUIScale.Scale = 1 -- Resets scale property.
	AnimEggFrame.Visible = false -- Hides egg frame container.
	RevealPet(petData) -- Calls function to render pet reward UI container.

	if isSkipped then task.wait(0.6) else WaitOrSkip(2.5) end -- Waits for reward display duration.
	PetFrame.Visible = false -- Hides pet frame.
	HatchingContainer.Visible = false -- Hides hatching container frame.

	if #AnimationQueue == 0 then
		HatchUI.Enabled = false -- Disables hatch screen GUI if queue is fully cleared.
		for _, ui in ipairs(PlayerGUI:GetChildren()) do
			if ui:IsA("ScreenGui") and ui.Name ~= "LoadingGui" then ui.Enabled = true end -- Restores general UI visibility.
		end
	end
end

-- Manages parallel multi-instance layout calculations for triple hatching sequences.
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
		UDim2.new(-0.2, 0, 0.55, 0), -- Left egg slot UDim2 coordinate.
		UDim2.new(0.5, 0, 0.42, 0),  -- Center egg slot UDim2 coordinate.
		UDim2.new(1.2, 0, 0.55, 0),  -- Right egg slot UDim2 coordinate.
	}

	local eggClones = {}
	for i = 1, math.min(3, #newPets) do -- Loops up to 3 times to create triple egg instances.
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

	for _, clone in ipairs(eggClones) do clone:Destroy() end -- Cleans up active egg clone instances from memory.

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

-- Handles dual-row grid layout orchestration for 10x bulk opening sequences.
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

	local allPositions = { -- Array of 10 grid coordinates for bulk 10x layout arrangement.
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

-- Intercepts purchase intents, routing premium gamepass/product eggs to MarketplaceService prompts.
function PetClient:PurchaseRequest(eggName, worldFolder)
	if isHatching then return end

	if eggName == "GODLY EGG" or eggName == "GODLY1 EGG" then
		MarketplaceService:PromptProductPurchase(Player, GODLY_PRODUCT_1X) -- Prompts developer product purchase for godly eggs.
		return
	elseif eggName == "DOMINUS EGG" then
		MarketplaceService:PromptProductPurchase(Player, DOMINUS_PRODUCT_1X) -- Prompts developer product purchase for dominus eggs.
		return
	elseif eggName == "Brainrot EGG" then
		MarketplaceService:PromptProductPurchase(Player, BRAINROT_PRODUCT_1X) -- Prompts developer product purchase for brainrot eggs.
		return
	end

	isHatching = true
	local success, result = HatchPetFunction:InvokeServer(ResolveDataEggName(eggName, worldFolder)) -- Invokes server hatching function synchronously.
	if success then
		pcall(function()
			table.insert(AnimationQueue, { HatchType = "Single", Data = result, EggName = eggName, WorldFolder = worldFolder }) -- Enqueues successful hatch data package.
			ProcessAnimationQueue() -- Triggers queue execution loop.
		end)
	else
		if isAutoHatching then self:StopAutoHatch() end
		NotificationModule.show(tostring(result), "Error") -- Displays error notification message if server returns failure.
	end
	isHatching = false
end

-- Intercepts triple purchase validation requests, incorporating group membership checks.
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
	local success, result = TripleHatchFunction:InvokeServer(ResolveDataEggName(eggName, worldFolder)) -- Invokes triple hatch remote function.
	if success then
		pcall(function()
			table.insert(AnimationQueue, { HatchType = "Triple", Data = result, EggName = eggName, WorldFolder = worldFolder })
			ProcessAnimationQueue()
		end)
	else
		if isAutoHatching then self:StopAutoHatch() end
		NotificationModule.show(tostring(result), "Error")
		if result == "Join the Group to triple hatch!" then GroupService:PromptJoinAsync(GROUP_ID, Player) end -- Prompts group membership join if player lacks group requirement.
	end
	isHatching = false
end

-- Manages developer product monetization routing for 10x bulk bundles.
function PetClient:TenXPurchaseRequest(eggName, worldFolder)
	if eggName == "Brainrot EGG" or eggName == "Brainrot" then
		MarketplaceService:PromptProductPurchase(Player, BRAINROT_PRODUCT_10X) -- Prompts 10x bulk developer product purchase.
		return
	end
end

-- Spawns a background worker thread throttled at fixed intervals to sustain automated hatch loops.
function PetClient:StartAutoHatch(eggName, worldFolder)
	if eggName == "GODLY EGG" or eggName == "GODLY1 EGG" or eggName == "DOMINUS EGG" or eggName == "Brainrot EGG" then return end
	if isAutoHatching then return end
	isAutoHatching = true
	StopAutoHatch.Visible = true
	if MainShopFrame then MainShopFrame.Visible = false end

	autoHatchThread = task.spawn(function() -- Spawns dedicated auto-hatch background loop thread.
		while isAutoHatching do
			self:PurchaseRequest(eggName, worldFolder) -- Repeatedly fires purchase requests while loop remains active.
			local elapsed = 0
			while elapsed < 0.1 do
				if not isAutoHatching then break end
				elapsed += task.wait()
			end
		end
		autoHatchThread = nil
	end)
end

-- Safely tears down automation loops, flushes pending queues, and restores default GUI state visibility.
function PetClient:StopAutoHatch()
	isAutoHatching = false -- Disables auto-hatch loop flag state.
	isHatching = false -- Resets main hatching transaction lock state.
	table.clear(AnimationQueue) -- Clears all remaining items from animation queue table.
	EggViewport.Rotation = 0
	EggViewport.ImageTransparency = 0
	AnimEggFrame.Visible = false
	PetFrame.Visible = false
	HatchingContainer.Visible = false
	HatchUI.Enabled = false
	StopAutoHatch.Visible = false
	for _, ui in ipairs(PlayerGUI:GetChildren()) do
		if ui:IsA("ScreenGui") and ui.Name ~= "LoadingGui" then ui.Enabled = true end -- Restores visibility of normal game HUD elements.
	end
end

-- Validates gamepass ownership status via server data before permitting automation features.
function PetClient:AutoHatchRequest(eggName, worldFolder)
	if eggName == "GODLY EGG" or eggName == "GODLY1 EGG" or eggName == "DOMINUS EGG" or eggName == "Brainrot EGG" then return end
	local ownsPass = GetData_RF:InvokeServer("GetClaimedData") -- Queries server data to verify auto-hatch gamepass ownership.
	local ClaimFreeGamepassHandler = require(PlayerScripts:WaitForChild("UI"):WaitForChild("ClaimFreeGamepassHandler")) -- Requires gamepass UI handler module.
	if ownsPass then
		self:StartAutoHatch(eggName, worldFolder) -- Initiates auto-hatch loop if pass is owned.
	else
		ClaimFreeGamepassHandler.OpenFrame() -- Opens gamepass claim frame prompt.
		NotificationModule.show("Claim the free gamepass pack to Auto Hatch!", "Error") -- Displays instructional notification error.
	end
end

-- Listens to global network broadcasts to inject server-verified paid hatch events directly into client queue.
PaidHatchBroadcast.OnClientEvent:Connect(function(hatchType, data)
	local eggName = data and data.EggName or "COMMON EGG"
	local worldFolder = data and data.WorldFolder or "World1"

	table.insert(AnimationQueue, { -- Inserts network-broadcasted paid hatch event into animation queue table.
		HatchType = hatchType,
		Data = data,
		EggName = eggName,
		WorldFolder = worldFolder
	})
	ProcessAnimationQueue()
end)

-- Binds UI interaction events to terminate active automation states cleanly.
StopAutoHatch.Activated:Connect(function()
	PetClient:StopAutoHatch()
end)

-- Exposes a unified state encapsulation method to check if the client is busy rendering animations.
function PetClient:IsHatching(): boolean
	return isHatching or #AnimationQueue > 0 or isProcessingQueue or HatchingContainer.Visible
end

return PetClient -- Returns module table reference to calling environment.
