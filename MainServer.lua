--!strict
-- MainServer (Script -> ServerScriptService > MainServer)
-- Bootstrap: creates Remotes, wires every system, handles join/leave,
-- connects all client -> server remote calls. Put this in as a Script.

-- Jarvis error reporting: Studio Play sessions send error text back to Jarvis automatically
pcall(function()
	require(game:GetService("ReplicatedStorage"):WaitForChild("JarvisReporter", 10)).start("server")
end)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- v46: robust requires — if a ModuleScript was deleted/renamed, don't hang forever
local function safeRequire(name: string)
	local mod = script.Parent:WaitForChild(name, 5)
	if not mod then
		warn("⚠️ MainServer: " .. name .. " not found! Continuing without it.")
		return nil
	end
	local ok, result = pcall(require, mod)
	if not ok then
		warn("⚠️ MainServer: " .. name .. " failed to load: " .. tostring(result))
		return nil
	end
	return result
end
local PlayerData = safeRequire("PlayerData")
local GardenManager = safeRequire("GardenManager")
local GrowthSystem = safeRequire("GrowthSystem")
local ShopSystem = safeRequire("ShopSystem")
local SellSystem = safeRequire("SellSystem")
local EventSystem = safeRequire("EventSystem")
local SecretSystem = safeRequire("SecretSystem")
local CollectionSystem = safeRequire("CollectionSystem")
local VisitSystem = safeRequire("VisitSystem")
local LeaderboardSystem = safeRequire("LeaderboardSystem")
local DailyRewards = safeRequire("DailyRewards")
local EvolutionSystem = safeRequire("EvolutionSystem")
local FollowerSystem = safeRequire("FollowerSystem")
local BattleSystem = safeRequire("BattleSystem")
local TradeSystem = safeRequire("TradeSystem")
local WildSystem = require(script.Parent:WaitForChild("WildSystem"))
local FishingSystem = require(script.Parent:WaitForChild("FishingSystem"))
local DigSystem = require(script.Parent:WaitForChild("DigSystem")) -- v14: digging + fossils
local QuestSystem = require(script.Parent:WaitForChild("QuestSystem"))
local SprinklerSystem = require(script.Parent:WaitForChild("SprinklerSystem"))
local BossSystem = require(script.Parent:WaitForChild("BossSystem")) -- v16: boss events
local SkySystem = require(script.Parent:WaitForChild("SkySystem")) -- v16: sky portal pads
local AuctionSystem = require(script.Parent:WaitForChild("AuctionSystem")) -- v20: night auction
local FountainSystem = require(script.Parent:WaitForChild("FountainSystem")) -- v22: lucky fountain
local TwilightSystem = require(script.Parent:WaitForChild("TwilightSystem")) -- v23: twilight dimension
local RideSystem = require(script.Parent:WaitForChild("RideSystem")) -- v25: pet riding
local DaycareSystem = require(script.Parent:WaitForChild("DaycareSystem")) -- v26: pet daycare
local RadarSystem = require(script.Parent:WaitForChild("RadarSystem")) -- v26: shiny radar
local SpinSystem = require(script.Parent:WaitForChild("SpinSystem")) -- v16: daily spin wheel

-- ---- remotes -------------------------------------------------------------------
local REMOTE_NAMES = {
	-- server -> client
	"CoinsChanged", "SeedsChanged", "ItemsChanged", "InventoryChanged", "BuffsChanged",
	"CollectionUpdate", "SettingsChanged", "GardenInfo", "PlotState", -- PlotState: GrowthSystem growth/ready sync (missing it froze the growth tick)
	"ShopStock", "EventChanged", "PhaseChanged", "Announce", "Notify", "Leaderboards",
	"DailyInfo", "VisitList", "OpenShop", "OpenSell",
	"StarterPrompt", "StarterChanged", "TeamChanged",
	"BattleInvite", "BattleInviteExpired", "BattleStart", "BattleUpdate", "BattleEnd",
	"TradeInvite", "TradeInviteExpired", "TradeStart", "TradeUpdate", "TradeEnd",
	"BoothInfo", "BoothOpen", -- v18: trading booths (server -> client)
	"FishBite", "QuestInfo", "SkinsChanged",
	"BossInfo", "SpinInfo", "SkyFlash", -- v16: boss HUD, spin wheel, teleport flash
	"AuctionState", -- v20: night auction (server -> client)
	"FountainOpen", "FountainState", "FountainFX", -- v22: lucky fountain (server -> client)
	"TwilightFlash", -- v23: twilight dimension teleport flash (server -> client)
	"RideState", -- v25: pet riding mount/dismount (server -> client)
	"DaycareInfo", -- v26: pet daycare slots (server -> client)
	"RadarPing", -- v26: shiny radar direction ping (server -> client)
	"SprayDone", -- v21: server tells the client the armed spray was consumed
	"StoneDone", -- v24: server tells the client the armed stone was consumed
	-- client -> server
	"ChooseStarter", "RequestStarter", "RequestShopStock", "RequestEvent", "RequestPhase",
	"BuyEgg", "BuyPotion", "BuyPlot", "BuyBait", "BuySprinkler", "RenamePet",
	"BuySkin", "SetSkin", "BuyRepellent", "ArmRepellent", -- v21: pest repellent
	"BuyEvoStone", "ArmEvoStone", -- v24: evolution stones (client -> server)
	"RequestQuests", "ClaimQuest",
	"RequestSpinInfo", "SpinWheel", -- v16: spin wheel
	"PlantPet", "UsePotion",
	"SellAll", "SellOne", "FusePets",
	"SetTeamSlot", "SetFollower",
	"Visit", "GoHome", "Gift", "ClaimDaily", "ToggleAutoSell",
	"BattleChallenge", "BattleRespond", "BattlePickFighter",
	"BattleAttack", "BattleUsePotion", "BattleForfeit",
	"TradeRequest", "TradeRespond", "TradeOffer", "TradeConfirm", "TradeCancel",
	"BoothClaim", "BoothList", "BoothCancel", "BoothAccept", -- v18: trading booths (client -> server)
	"FishCast", "FishReel", "BefriendAttempt",
	"AuctionBid", -- v20: night auction (client -> server)
	"MakeWish", -- v22: lucky fountain (client -> server)
	"RideToggle", -- v25: pet riding mount/dismount request (client -> server)
	"BuyRod", "BuyShovel", "DigSpot", "ReviveFossil", -- v14: rods, digging, fossils
	"BuyRadar", "RadarScan", -- v26: shiny radar (client -> server)
	"DaycareOpen", "DaycareCheckIn", "DaycareCheckOut", -- v26: pet daycare (client -> server)
}

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end
for _, n in REMOTE_NAMES do
	if not (remotesFolder :: Folder):FindFirstChild(n) then
		local re = Instance.new("RemoteEvent")
		re.Name = n
		re.Parent = remotesFolder
	end
end

local function R(name: string): RemoteEvent
	return ((remotesFolder :: Folder):WaitForChild(name) :: RemoteEvent)
end

for _, mod in { PlayerData, GardenManager, GrowthSystem, ShopSystem, SellSystem,
	EventSystem, SecretSystem, CollectionSystem, VisitSystem, LeaderboardSystem,
	DailyRewards, EvolutionSystem, FollowerSystem, BattleSystem, TradeSystem,
	WildSystem, FishingSystem, QuestSystem, SprinklerSystem, DigSystem,
	BossSystem, SkySystem, SpinSystem } do
	if mod then (mod :: any).SetRemotes(remotesFolder) end -- skip modules that failed to load
end
for _, mod in { AuctionSystem, FountainSystem, TwilightSystem, RideSystem } do -- v20: auction prompts; v22: fountain prompts; v23: twilight portal pads; v25: riding
	if mod then (mod :: any).SetRemotes(remotesFolder) end
end
for _, mod in { DaycareSystem, RadarSystem } do -- v26: daycare prompt; shiny radar
	if mod then (mod :: any).SetRemotes(remotesFolder) end
end

-- ---- spawn area: market stands with NPC shopkeepers (code-built) ------------
-- v44: proper open-air stands (not wooden boxes) with a shopkeeper NPC
-- behind the counter. Talk to them via the 💬 prompt to open the shop.
local function buildSpawnArea()
	-- v46: guard against duplicate builds (can be called multiple times due to module retry logic)
	if workspace:FindFirstChild("ShopStall_Platform") then
		print("🏪 buildSpawnArea: shops already exist, skipping")
		return
	end
	print("🏪 buildSpawnArea: starting...")
	local function atPos(name: string, pos: Vector3): Vector3
		local marker = workspace:FindFirstChild(name)
		if marker and marker:IsA("BasePart") then return (marker :: BasePart).Position end
		return pos
	end
	local function mkPart(name: string, size: Vector3, pos: Vector3, color: Color3, mat: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = pos
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = workspace
		return p
	end
	-- v45: proper Roblox-character NPC (R6 rig with Humanoid, classic proportions
	-- and smile face) — stands behind the counter like a real shopkeeper.
	local function buildNPC(name: string, pos: Vector3, shirt: Color3, pants: Color3): Model
		local skin = Color3.fromRGB(255, 205, 150)
		local model = Instance.new("Model")
		model.Name = name .. "NPC"
		local function limb(nm: string, size: Vector3, p: Vector3, c: Color3)
			local pt = Instance.new("Part")
			pt.Name = nm
			pt.Size = size
			pt.Position = p
			pt.Color = c
			pt.Material = Enum.Material.SmoothPlastic
			pt.Anchored = true
			pt.TopSurface = Enum.SurfaceType.Smooth
			pt.BottomSurface = Enum.SurfaceType.Smooth
			pt.Parent = model
			return pt
		end
		-- R6 proportions, feet at pos.Y
		limb("Left Leg", Vector3.new(1, 2, 1), pos + Vector3.new(-0.5, 1, 0), pants)
		limb("Right Leg", Vector3.new(1, 2, 1), pos + Vector3.new(0.5, 1, 0), pants)
		limb("Torso", Vector3.new(2, 2, 1), pos + Vector3.new(0, 3, 0), shirt)
		limb("Left Arm", Vector3.new(1, 2, 1), pos + Vector3.new(-1.5, 3, 0), shirt)
		limb("Right Arm", Vector3.new(1, 2, 1), pos + Vector3.new(1.5, 3, 0), shirt)
		local head = limb("Head", Vector3.new(1.3, 1.2, 1.3), pos + Vector3.new(0, 4.6, 0), skin)
		head.Shape = Enum.PartType.Ball
		-- classic smile
		local face = Instance.new("Decal")
		face.Texture = "rbxasset://textures/face.png"
		face.Face = Enum.NormalId.Front
		face.Parent = head
		local hum = Instance.new("Humanoid")
		hum.RigType = Enum.HumanoidRigType.R6
		hum.DisplayName = name
		hum.Parent = model
		model.Parent = workspace
		return model
	end
	local function buildStand(name: string, pos: Vector3, wood: Color3,
		label: string, awning: Color3, npcName: string, npcShirt: Color3): Model
		local gx, gz, baseY = pos.X, pos.Z, pos.Y
		-- platform (sits on the plaza)
		mkPart(name .. "_Platform", Vector3.new(11, 1, 9),
			Vector3.new(gx, baseY + 0.5, gz), wood, Enum.Material.Wood)
		-- counter (front)
		mkPart(name .. "_Counter", Vector3.new(9, 2, 1.6),
			Vector3.new(gx, baseY + 2, gz + 3.2), Color3.fromRGB(120, 82, 50), Enum.Material.Wood)
		-- 4 posts
		for _, c in { { -5, -4 }, { 5, -4 }, { -5, 4 }, { 5, 4 } } do
			mkPart(name .. "_Post", Vector3.new(0.7, 7, 0.7),
				Vector3.new(gx + c[1], baseY + 4.5, gz + c[2]), Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
		end
		-- striped awning
		for i = 0, 5 do
			mkPart(name .. "_Awning" .. i, Vector3.new(1.9, 0.4, 9.6),
				Vector3.new(gx - 4.75 + i * 1.9, baseY + 8.1, gz),
				if i % 2 == 0 then awning else Color3.fromRGB(245, 245, 240),
				Enum.Material.SmoothPlastic)
		end
		-- crates of goods on the counter
		mkPart(name .. "_Crate1", Vector3.new(1.6, 1.6, 1.6),
			Vector3.new(gx - 2.5, baseY + 3.8, gz + 3.2), Color3.fromRGB(160, 115, 70), Enum.Material.Wood)
		mkPart(name .. "_Crate2", Vector3.new(1.2, 1.2, 1.2),
			Vector3.new(gx + 2.8, baseY + 3.6, gz + 3.2), Color3.fromRGB(150, 105, 65), Enum.Material.Wood)
		-- shopkeeper NPC (real Roblox character) behind the counter, on the platform
		local npc = buildNPC(npcName, Vector3.new(gx, baseY + 1, gz - 1.5),
			npcShirt, Color3.fromRGB(60, 60, 80))
		local npcHead = npc:WaitForChild("Head")
		-- sign above the NPC
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 130, 0, 32)
		bb.StudsOffset = Vector3.new(0, 2.6, 0)
		bb.AlwaysOnTop = false
		bb.Adornee = npcHead
		bb.Parent = npcHead
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.new(1, 0, 1, 0)
		tl.BackgroundTransparency = 0.3
		tl.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
		tl.Text = label
		tl.TextScaled = true
		tl.TextColor3 = Color3.fromRGB(255, 255, 255)
		tl.Font = Enum.Font.FredokaOne
		tl.Parent = bb
		return npc
	end
	-- v46: no plaza — island top is y=0, so stands sit at baseY=0
	local shopNPC = buildStand("ShopStall", atPos("ShopStall", Vector3.new(18, 0, 10)),
		Color3.fromRGB(150, 110, 70), "🥚 PET SHOP 🧪", Color3.fromRGB(220, 70, 70),
		"Shopkeeper", Color3.fromRGB(70, 130, 220))
	local sellNPC = buildStand("SellStation", atPos("SellStation", Vector3.new(-18, 0, 10)),
		Color3.fromRGB(110, 150, 110), "💰 SELL PETS", Color3.fromRGB(70, 170, 90),
		"Trader", Color3.fromRGB(220, 170, 70))
	local pr1 = Instance.new("ProximityPrompt")
	pr1.Name = "TalkShop"
	pr1.ActionText = "💬 Talk"
	pr1.ObjectText = "Shopkeeper"
	pr1.HoldDuration = 0
	pr1.MaxActivationDistance = 12
	pr1.RequiresLineOfSight = false
	pr1.Parent = shopNPC:WaitForChild("Head")
	pr1.Triggered:Connect(function(player: Player)
		R("OpenShop"):FireClient(player)
	end)
	local pr2 = Instance.new("ProximityPrompt")
	pr2.Name = "TalkSell"
	pr2.ActionText = "💬 Talk"
	pr2.ObjectText = "Trader"
	pr2.HoldDuration = 0
	pr2.MaxActivationDistance = 12
	pr2.RequiresLineOfSight = false
	pr2.Parent = sellNPC:WaitForChild("Head")
	pr2.Triggered:Connect(function(player: Player)
		-- v46: Open the Pets bag so Deacon can pick which pets to sell
		-- (each pet card has its own 💰 Sell button)
		R("OpenSell"):FireClient(player)
	end)
	print("🏪 buildSpawnArea: shops built!")
end

-- ---- fishing docks + ocean safety (v47.9) ------------------------------------
-- The v46 minimal map has no lakes/docks and its Ocean part is non-collidable,
-- so fishing could never start and stepping off the island fell into the void.
-- MainServer builds the three Config lakes/docks at startup (idempotent) so
-- JarvisSync alone fixes it — no command-bar rebuild needed.
local function buildFishingDocks()
	if workspace:FindFirstChild("FishingDocks") then return end
	local folder = Instance.new("Folder")
	folder.Name = "FishingDocks"
	folder.Parent = workspace
	local function mk(name: string, size: Vector3, pos: Vector3, color: Color3, mat: Enum.Material?, collide: boolean?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = pos
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = collide ~= false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = folder
		return p
	end
	-- MUST match Config.Docks / Config.Lakes (FishingSystem validates by EndPos)
	local dockDefs = {
		{ EndPos = Vector3.new(45, 0, -250), Lake = Vector3.new(0, 0, -250) },
		{ EndPos = Vector3.new(-171, 0, 125), Lake = Vector3.new(-217, 0, 125) },
		{ EndPos = Vector3.new(171, 0, 125), Lake = Vector3.new(217, 0, 125) },
	}
	for i, d in dockDefs do
		local ep = d.EndPos
		local lake = d.Lake
		local rim = mk("LakeSand" .. i, Vector3.new(0.5, 176, 176), Vector3.new(lake.X, -0.05, lake.Z), Color3.fromRGB(235, 215, 160), Enum.Material.Sand, false)
		rim.Shape = Enum.PartType.Cylinder
		rim.Orientation = Vector3.new(0, 0, 90)
		local water = mk("LakeWater" .. i, Vector3.new(0.7, 164, 164), Vector3.new(lake.X, 0.05, lake.Z), Color3.fromRGB(45, 140, 220), Enum.Material.Water, false)
		water.Shape = Enum.PartType.Cylinder
		water.Orientation = Vector3.new(0, 0, 90)
		local side = if ep.X >= lake.X then 1 else -1
		local shoreX = lake.X + side * 88
		local length = math.max(10, math.abs(shoreX - ep.X))
		local wood = Color3.fromRGB(139, 99, 65)
		mk("Dock" .. i, Vector3.new(length, 1, 7), Vector3.new((shoreX + ep.X) / 2, 1, ep.Z), wood, Enum.Material.Wood, true)
		mk("DockEnd" .. i, Vector3.new(10, 1, 10), Vector3.new(ep.X, 1, ep.Z), wood, Enum.Material.Wood, true)
		for _, px in { shoreX, ep.X } do
			for _, pz in { ep.Z - 3, ep.Z + 3 } do
				mk("DockPost" .. i, Vector3.new(0.8, 3, 0.8), Vector3.new(px, -0.5, pz), Color3.fromRGB(110, 75, 45), Enum.Material.Wood, false)
			end
		end
		local anchor = mk("DockPrompt" .. i, Vector3.new(2, 2, 2), Vector3.new(ep.X, 2.4, ep.Z), wood, Enum.Material.Wood, false)
		anchor.Transparency = 1
		local pr = Instance.new("ProximityPrompt")
		pr.Name = "FishPrompt"
		pr.ActionText = "🎣 Fish"
		pr.ObjectText = "Fishing Dock"
		pr.HoldDuration = 0
		pr.MaxActivationDistance = 12
		pr.RequiresLineOfSight = false
		pr.Parent = anchor
	end
	print("🎣 buildFishingDocks: built " .. #dockDefs .. " fishing docks")
end

local oceanSafetyStarted = false
local function startOceanSafety()
	if oceanSafetyStarted then return end
	oceanSafetyStarted = true
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp and (hrp :: BasePart).Position.Y < -8 then
					local part = hrp :: BasePart
					part.CFrame = CFrame.new(0, 3, 0)
					pcall(function()
						part.AssemblyLinearVelocity = Vector3.zero
						part.AssemblyAngularVelocity = Vector3.zero
					end)
					R("Notify"):FireClient(player, "🌊 Too deep to swim! Fish from a wooden dock 🎣", "warn")
				end
			end
			task.wait(0.25)
		end
	end)
end

-- ---- map dressing (v48, from MAP_DESIGN_V48) ---------------------------------
-- Runtime-built so JarvisSync delivers it: sand paths, battle/trade pads,
-- spawn signpost and floating zone labels. Geometry matches GardenManager's
-- garden ring (r=140) and Config lakes/docks, so nothing needs a rebuild.
local function buildMapDressing()
	if workspace:FindFirstChild("MapDressing") then return end
	local folder = Instance.new("Folder")
	folder.Name = "MapDressing"
	folder.Parent = workspace
	local function mk(name: string, size: Vector3, pos: Vector3, color: Color3, mat: Enum.Material?, collide: boolean?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = pos
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = collide ~= false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = folder
		return p
	end
	local function disc(name: string, radius: number, height: number, pos: Vector3, color: Color3): Part
		local p = mk(name, Vector3.new(height, radius * 2, radius * 2), pos, color, Enum.Material.SmoothPlastic, true)
		p.Shape = Enum.PartType.Cylinder
		p.Orientation = Vector3.new(0, 0, 90)
		return p
	end
	local function makeLabel(name: string, pos: Vector3, text: string, color: Color3)
		local anchor = mk(name, Vector3.new(1, 1, 1), pos, color, nil, false)
		anchor.Transparency = 1
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 200, 0, 46)
		bb.AlwaysOnTop = false
		bb.Adornee = anchor
		bb.Parent = anchor
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.new(1, 0, 1, 0)
		tl.BackgroundTransparency = 0.35
		tl.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
		tl.Text = text
		tl.TextScaled = true
		tl.TextColor3 = color
		tl.Font = Enum.Font.FredokaOne
		tl.Parent = bb
	end
	local function makePath(name: string, fromPos: Vector3, toPos: Vector3, width: number)
		local mid = (fromPos + toPos) / 2
		local len = (toPos - fromPos).Magnitude
		local p = mk(name, Vector3.new(width, 0.12, len), Vector3.new(mid.X, 0.08, mid.Z), Color3.fromRGB(232, 214, 160), Enum.Material.Sand, false)
		p.CFrame = CFrame.lookAt(Vector3.new(mid.X, 0.08, mid.Z), Vector3.new(toPos.X, 0.08, toPos.Z))
	end
	-- sand paths: plaza edge -> each garden, plaza -> each dock end
	local gardens = {
		Vector3.new(140, 0, 0), Vector3.new(70, 0, -121), Vector3.new(-70, 0, -121),
		Vector3.new(-140, 0, 0), Vector3.new(-70, 0, 121), Vector3.new(70, 0, 121),
	}
	for i, g in gardens do
		local dir = Vector3.new(g.X, 0, g.Z).Unit
		makePath("GardenPath" .. i, dir * 30, dir * 104, 8)
		makeLabel("GardenLabel" .. i, g + Vector3.new(0, 13, 0), "🌱 Garden " .. i, Color3.fromRGB(190, 255, 190))
	end
	local dockEnds = { Vector3.new(45, 0, -250), Vector3.new(-171, 0, 125), Vector3.new(171, 0, 125) }
	for i, ep in dockEnds do
		local dir = Vector3.new(ep.X, 0, ep.Z).Unit
		makePath("LakePath" .. i, dir * 30, ep - dir * 14, 6)
		makeLabel("DockLabel" .. i, ep + Vector3.new(0, 8, 0), "🎣 Fishing", Color3.fromRGB(170, 220, 255))
	end
	-- battle / trade pads just south of spawn (core-loop social spots)
	disc("BattlePad", 10, 0.5, Vector3.new(16, 0.25, 34), Color3.fromRGB(170, 90, 220))
	disc("TradePad", 10, 0.5, Vector3.new(-16, 0.25, 34), Color3.fromRGB(60, 190, 200))
	makeLabel("BattleLabel", Vector3.new(16, 7, 34), "⚔️ Battle", Color3.fromRGB(255, 200, 255))
	makeLabel("TradeLabel", Vector3.new(-16, 7, 34), "🤝 Trade", Color3.fromRGB(190, 255, 255))
	-- spawn signpost: the whole loop on one board
	mk("SignPost", Vector3.new(0.6, 5, 0.6), Vector3.new(10, 2.5, -14), Color3.fromRGB(110, 75, 45), Enum.Material.Wood, true)
	mk("SignBoard", Vector3.new(12, 3, 0.4), Vector3.new(10, 5.6, -14), Color3.fromRGB(90, 68, 44), Enum.Material.Wood, false)
	makeLabel("SignText", Vector3.new(10, 8.2, -14), "🌱 CLAIM → GROW → EVOLVE → ⚔️ BATTLE → 🤝 TRADE", Color3.fromRGB(255, 255, 255))
	print("🗺️ buildMapDressing: paths, pads, signs and labels built")
end

-- ---- player lifecycle ---------------------------------------------------------------
local function broadcastVisitList()
	local list = VisitSystem.GetVisitList(nil)
	for _, p in Players:GetPlayers() do
		local mine = {}
		for _, e in list do
			if (e :: { [string]: any }).UserId ~= p.UserId then table.insert(mine, e) end
		end
		R("VisitList"):FireClient(p, mine)
	end
end

local function onJoin(player: Player)
	PlayerData.LoadProfile(player)
	-- v47: spawn ON THE GROUND (SpawnPad at 0,0,0) instead of dropping from the sky
	player.CharacterAdded:Connect(function(char: Model)
		local hrp = char:WaitForChild("HumanoidRootPart", 10)
		if hrp then
			(hrp :: BasePart).CFrame = CFrame.new(0, 3, 0)
		end
	end)
	if player.Character then
		local hrp = player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then (hrp :: BasePart).CFrame = CFrame.new(0, 3, 0) end
	end
	-- v46: no auto-assign — the player claims a garden by holding E at its front gate
	R("Notify"):FireClient(player, "🌱 Walk up to any garden and hold E to claim it!", "ok")
	FollowerSystem.OnJoin(player)
	R("ShopStock"):FireClient(player, ShopSystem.GetStock())
	R("EventChanged"):FireClient(player, EventSystem.CurrentEvent(), os.time() + EventSystem.TimeLeft())
	R("PhaseChanged"):FireClient(player, EventSystem.Phase(), os.time() + EventSystem.PhaseTimeLeft())
	DailyRewards.PushStatus(player)
	local s = DailyRewards.Status(player)
	if (s.CanClaim :: boolean) then
		R("Notify"):FireClient(player, "🎁 Daily reward ready! Open the Daily panel.", "ok")
	end
	QuestSystem.PushStatus(player)
	TradeSystem.PushBooths(player) -- v18: trading booth state
	SprinklerSystem.EnsureVisual(player)
	-- starter choice for brand-new players
	local prof = PlayerData.Get(player)
	if not prof.StarterChosen then
		R("StarterPrompt"):FireClient(player)
	else
		FollowerSystem.Refresh(player)
	end
	AuctionSystem.PushState(player) -- v20: sync auction HUD on join
	DaycareSystem.PushState(player) -- v26: sync daycare slots on join
	broadcastVisitList()
end

local function onLeave(player: Player)
	-- v47.2: safeRequire can return nil — never crash on leave (a crash here
	-- would skip PlayerData.UnloadProfile and lose the player's save)
	if BattleSystem then BattleSystem.onDisconnect(player.UserId) end
	if TradeSystem then TradeSystem.OnDisconnect(player.UserId) end -- also closes their booth
	if FollowerSystem then FollowerSystem.OnLeave(player) end
	RideSystem.OnLeave(player) -- v25: clear ride state (model dies with FollowerSystem)
	FishingSystem.OnLeave(player)
	AuctionSystem.OnLeave(player) -- v20: refund any escrowed auction bids
	if GardenManager then GardenManager.RemoveGarden(player) end -- snapshots plots first
	if PlayerData then PlayerData.UnloadProfile(player) end -- saves
	task.delay(1, broadcastVisitList)
end

Players.PlayerAdded:Connect(onJoin)
Players.PlayerRemoving:Connect(onLeave)
for _, p in Players:GetPlayers() do
	task.spawn(onJoin, p)
end

-- ---- client -> server -----------------------------------------------------------------
R("ChooseStarter").OnServerEvent:Connect(function(player: Player, starterId: string)
	local ok, msg = PlayerData.ChooseStarter(player, tostring(starterId))
	if ok then
		FollowerSystem.Refresh(player)
	else
		R("Notify"):FireClient(player, msg, "warn")
	end
end)

-- fallback: client asks for the starter prompt once its UI is ready
-- (the onJoin fire can arrive before the client connects its handler)
R("RequestStarter").OnServerEvent:Connect(function(player: Player)
	local prof = PlayerData.Get(player)
	if prof and not (prof :: { [string]: any }).StarterChosen then
		R("StarterPrompt"):FireClient(player)
	end
end)

-- fallback: client asks for the shop stock once its UI is ready, and every
-- time the shop is opened (the onJoin fire can arrive before the client
-- connects its handler, which left the shop showing only the plot row)
R("RequestShopStock").OnServerEvent:Connect(function(player: Player)
	R("ShopStock"):FireClient(player, ShopSystem.GetStock())
end)

-- fallback: client asks for the current event once its UI is ready
-- (same join-race as the shop stock; otherwise event visuals never start)
R("RequestEvent").OnServerEvent:Connect(function(player: Player)
	R("EventChanged"):FireClient(player, EventSystem.CurrentEvent(), os.time() + EventSystem.TimeLeft())
end)

-- same join-race for the day/night phase (client needs it for lighting + indicator)
R("RequestPhase").OnServerEvent:Connect(function(player: Player)
	R("PhaseChanged"):FireClient(player, EventSystem.Phase(), os.time() + EventSystem.PhaseTimeLeft())
end)

R("BuyEgg").OnServerEvent:Connect(function(player: Player)
	local ok, msg = ShopSystem.BuyEgg(player, "PetEgg")
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("BuyPotion").OnServerEvent:Connect(function(player: Player, potionId: string)
	local ok, msg = ShopSystem.BuyPotion(player, tostring(potionId))
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("BuyPlot").OnServerEvent:Connect(function(player: Player)
	local ok, msg = GardenManager.BuyPlot(player)
	R("Notify"):FireClient(player, msg, ok and "ok" or "warn")
end)

R("BuyBait").OnServerEvent:Connect(function(player: Player, kind: string)
	local ok, msg = ShopSystem.BuyBait(player, tostring(kind))
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

-- v21: pest repellent
R("BuyRepellent").OnServerEvent:Connect(function(player: Player)
	local ok, msg = ShopSystem.BuyRepellent(player)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("ArmRepellent").OnServerEvent:Connect(function(player: Player, armed: boolean)
	local ok, msg = GardenManager.ArmSpray(player, armed == true)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

-- v24: evolution stones
R("BuyEvoStone").OnServerEvent:Connect(function(player: Player, stoneId: string)
	local ok, msg = ShopSystem.BuyEvoStone(player, tostring(stoneId))
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("ArmEvoStone").OnServerEvent:Connect(function(player: Player, stoneId: string?)
	local ok, msg = GardenManager.ArmStone(player, if stoneId and stoneId ~= "" then tostring(stoneId) else nil)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

-- v12: custom pet skins
R("BuySkin").OnServerEvent:Connect(function(player: Player, skinId: string)
	local ok, msg = PlayerData.BuySkin(player, tostring(skinId))
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)
R("SetSkin").OnServerEvent:Connect(function(player: Player, uid: string, skinId: string?)
	local ok, msg = PlayerData.SetSkin(player, tostring(uid), skinId ~= nil and tostring(skinId) or nil)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("PlantPet").OnServerEvent:Connect(function(player: Player, uid: string)
	local ok, msg = GardenManager.PlantPet(player, tostring(uid))
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("UsePotion").OnServerEvent:Connect(function(player: Player, potionId: string, uid: string?)
	local ok, msg = PlayerData.UsePotion(player, tostring(potionId), uid and tostring(uid) or nil)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("SellAll").OnServerEvent:Connect(function(player: Player)
	local ok, msg = SellSystem.SellAll(player)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("SellOne").OnServerEvent:Connect(function(player: Player, uid: string)
	local ok, msg = SellSystem.SellOne(player, tostring(uid))
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("FusePets").OnServerEvent:Connect(function(player: Player, uidA: string, uidB: string)
	local ok, msg = PlayerData.FusePets(player, tostring(uidA), tostring(uidB))
	if ok then
		FollowerSystem.Refresh(player)
	else
		R("Notify"):FireClient(player, msg, "warn")
	end
end)

R("SetTeamSlot").OnServerEvent:Connect(function(player: Player, slot: number, uid: string?)
	local ok, msg = PlayerData.SetTeamSlot(player, tonumber(slot) or 0, uid and tostring(uid) or nil)
	if ok then
		FollowerSystem.Refresh(player)
	else
		R("Notify"):FireClient(player, msg, "warn")
	end
end)

R("SetFollower").OnServerEvent:Connect(function(player: Player, uid: string)
	local ok, msg = PlayerData.SetFollower(player, tostring(uid))
	if ok then
		RideSystem.Dismount(player, true) -- v25: new follower = dismount first
		FollowerSystem.Refresh(player)
	else
		R("Notify"):FireClient(player, msg, "warn")
	end
end)

R("RideToggle").OnServerEvent:Connect(function(player: Player) -- v25: mount/dismount
	RideSystem.RequestRide(player)
end)

R("Visit").OnServerEvent:Connect(function(player: Player, targetUserId: number)
	local ok, msg = VisitSystem.Visit(player, tonumber(targetUserId) or 0)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("GoHome").OnServerEvent:Connect(function(player: Player)
	VisitSystem.GoHome(player)
end)

R("Gift").OnServerEvent:Connect(function(player: Player, targetUserId: number)
	local ok, msg = VisitSystem.Gift(player, tonumber(targetUserId) or 0)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("ClaimDaily").OnServerEvent:Connect(function(player: Player)
	local ok, msg = DailyRewards.Claim(player)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("ToggleAutoSell").OnServerEvent:Connect(function(player: Player)
	local prof = PlayerData.Get(player)
	local set = prof.Settings :: { [string]: any }
	set.AutoSell = not set.AutoSell
	PlayerData.Sync(player)
	R("Notify"):FireClient(player, "Auto-sell " .. (set.AutoSell and "ON ✅" or "OFF ❌"), "ok")
end)

-- battle
R("BattleChallenge").OnServerEvent:Connect(function(player: Player, targetUserId: number)
	local ok, msg = BattleSystem.Challenge(player, tonumber(targetUserId) or 0)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("BattleRespond").OnServerEvent:Connect(function(player: Player, fromUserId: number, accept: boolean)
	BattleSystem.Respond(player, tonumber(fromUserId) or 0, accept == true)
end)

R("BattlePickFighter").OnServerEvent:Connect(function(player: Player, uid: string)
	local ok, msg = BattleSystem.PickFighter(player, tostring(uid))
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("BattleAttack").OnServerEvent:Connect(function(player: Player, moveIdx: number)
	local ok, msg = BattleSystem.Attack(player, tonumber(moveIdx) or 1)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("BattleUsePotion").OnServerEvent:Connect(function(player: Player)
	local ok, msg = BattleSystem.UsePotion(player)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("BattleForfeit").OnServerEvent:Connect(function(player: Player)
	BattleSystem.Forfeit(player)
end)

-- trade
R("TradeRequest").OnServerEvent:Connect(function(player: Player, targetUserId: number)
	local ok, msg = TradeSystem.Request(player, tonumber(targetUserId) or 0)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("TradeRespond").OnServerEvent:Connect(function(player: Player, fromUserId: number, accept: boolean)
	TradeSystem.Respond(player, tonumber(fromUserId) or 0, accept == true)
end)

R("TradeOffer").OnServerEvent:Connect(function(player: Player, uid: string?, coins: number)
	local id = if uid and tostring(uid) ~= "" then tostring(uid) else nil
	local ok, msg = TradeSystem.Offer(player, id, tonumber(coins) or 0)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("TradeConfirm").OnServerEvent:Connect(function(player: Player)
	local ok, msg = TradeSystem.Confirm(player)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("TradeCancel").OnServerEvent:Connect(function(player: Player)
	TradeSystem.Cancel(player)
end)

-- fishing + befriending
R("FishCast").OnServerEvent:Connect(function(player: Player)
	local ok, msg = FishingSystem.Cast(player)
	if not ok and msg ~= "Too fast!" then R("Notify"):FireClient(player, msg, "warn") end
end)

R("FishReel").OnServerEvent:Connect(function(player: Player)
	FishingSystem.Reel(player)
end)

R("BefriendAttempt").OnServerEvent:Connect(function(player: Player, uid: string)
	WildSystem.TryBefriend(player, tostring(uid))
end)

R("BuySprinkler").OnServerEvent:Connect(function(player: Player)
	local ok, msg = SprinklerSystem.Buy(player)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

-- v14: fishing rods, shovel, digging, fossil revival
R("BuyRod").OnServerEvent:Connect(function(player: Player, rodId: string)
	local ok, msg = PlayerData.BuyRod(player, tostring(rodId))
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("BuyShovel").OnServerEvent:Connect(function(player: Player)
	local ok, msg = PlayerData.BuyShovel(player)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("DigSpot").OnServerEvent:Connect(function(player: Player, spotUid: string?)
	local ok, msg = DigSystem.Dig(player, spotUid and tostring(spotUid) or nil)
	if not ok and msg ~= "Too fast!" then R("Notify"):FireClient(player, msg, "warn") end
end)

-- v26: pet daycare + shiny radar
R("DaycareOpen").OnServerEvent:Connect(function(player: Player)
	DaycareSystem.PushState(player)
end)
R("DaycareCheckIn").OnServerEvent:Connect(function(player: Player, uid: string)
	local ok, msg = DaycareSystem.CheckIn(player, tostring(uid))
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)
R("DaycareCheckOut").OnServerEvent:Connect(function(player: Player, slotIdx: number)
	local ok, msg = DaycareSystem.CheckOut(player, tonumber(slotIdx) or 0)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)
R("BuyRadar").OnServerEvent:Connect(function(player: Player)
	local ok, msg = ShopSystem.BuyRadar(player)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)
R("RadarScan").OnServerEvent:Connect(function(player: Player)
	local ok, msg = RadarSystem.RadarScan(player)
	if not ok and msg ~= "Too fast!" then R("Notify"):FireClient(player, msg, "warn") end
end)

R("ReviveFossil").OnServerEvent:Connect(function(player: Player, speciesId: string)
	local ok, msg = PlayerData.ReviveFossil(player, tostring(speciesId))
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("RenamePet").OnServerEvent:Connect(function(player: Player, uid: string, name: string)
	local ok, msg = PlayerData.RenamePet(player, tostring(uid), tostring(name or ""))
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("RequestQuests").OnServerEvent:Connect(function(player: Player)
	QuestSystem.PushStatus(player)
end)

R("ClaimQuest").OnServerEvent:Connect(function(player: Player, questId: string)
	local ok, msg = QuestSystem.Claim(player, tostring(questId))
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

-- v16: spin wheel
R("RequestSpinInfo").OnServerEvent:Connect(function(player: Player)
	SpinSystem.PushStatus(player)
end)

R("SpinWheel").OnServerEvent:Connect(function(player: Player)
	local ok, msg = SpinSystem.Spin(player)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

-- v22: lucky fountain wishes
R("MakeWish").OnServerEvent:Connect(function(player: Player, tierId: string)
	local ok, msg = FountainSystem.MakeWish(player, tostring(tierId))
	R("Notify"):FireClient(player, msg, ok and "ok" or "warn")
end)

-- v20: night auction bids
R("AuctionBid").OnServerEvent:Connect(function(player: Player, amount: number)
	local ok, msg = AuctionSystem.Bid(player, amount)
	R("Notify"):FireClient(player, msg, ok and "ok" or "warn")
end)

-- v18: trading booths
R("BoothClaim").OnServerEvent:Connect(function(player: Player, idx: number)
	local ok, msg = TradeSystem.ClaimBooth(player, tonumber(idx) or 0)
	R("Notify"):FireClient(player, msg, ok and "ok" or "warn")
end)

R("BoothList").OnServerEvent:Connect(function(player: Player, idx: number, uid: string, price: number, wanted: string?)
	local ok, msg = TradeSystem.ListPet(player, tonumber(idx) or 0, tostring(uid), tonumber(price) or 0, wanted)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

R("BoothCancel").OnServerEvent:Connect(function(player: Player, idx: number, kind: string)
	if tostring(kind) == "booth" then
		local ok, msg = TradeSystem.ReleaseBooth(player, tonumber(idx) or 0)
		R("Notify"):FireClient(player, msg, ok and "ok" or "warn")
	else
		local ok, msg = TradeSystem.CancelListing(player, tonumber(idx) or 0)
		if not ok then R("Notify"):FireClient(player, msg, "warn") end
	end
end)

R("BoothAccept").OnServerEvent:Connect(function(player: Player, idx: number, offerUid: string?, offerCoins: number)
	local id = if offerUid and tostring(offerUid) ~= "" then tostring(offerUid) else nil
	local ok, msg = TradeSystem.AcceptBooth(player, tonumber(idx) or 0, id, tonumber(offerCoins) or 0)
	if not ok then R("Notify"):FireClient(player, msg, "warn") end
end)

-- ---- start everything -------------------------------------------------------------------
buildSpawnArea()
-- v47: guard the soft-required systems — a missing module warns via
-- safeRequire but must not kill the rest of startup (titan loop, autosave)
if GrowthSystem then GrowthSystem.Start() end
if EventSystem then EventSystem.Start() end
if ShopSystem then ShopSystem.Start() end
if LeaderboardSystem then LeaderboardSystem.Start() end
WildSystem.Start()
buildFishingDocks() -- v47.9: prompts must exist before FishingSystem.Start wires them
FishingSystem.Start()
startOceanSafety() -- v47.9: rescue anyone who falls through the non-collidable ocean
buildMapDressing() -- v48: sand paths, battle/trade pads, spawn signpost, zone labels
DigSystem.Start() -- v14: digging + fossils
SprinklerSystem.Start()
BossSystem.Start() -- v16: boss events
SkySystem.Start() -- v16: sky portal pads
SpinSystem.Start() -- v16: daily spin wheel
if TradeSystem then TradeSystem.Start() end -- v18: trading booth prompts
FountainSystem.Start() -- v22: lucky fountain prompt
AuctionSystem.Start() -- v20: night auction scheduler
TwilightSystem.Start() -- v23: twilight dimension portal pads
RideSystem.Start() -- v25: pet riding sanity loop
DaycareSystem.Start() -- v26: daycare prompt
RadarSystem.Start() -- v26: shiny radar
if GardenManager and GardenManager.WireClaimPrompts then
	GardenManager.WireClaimPrompts() -- v46: hold-E claim prompts at each garden gate
end

-- v47: keep hold-E claim prompts alive — re-places them if the map was
-- rebuilt mid-session (BuildEverything wipes the ClaimPrompts folder)
task.spawn(function()
	while true do
		task.wait(30)
		pcall(function()
			if GardenManager and GardenManager.WireClaimPrompts then
				GardenManager.WireClaimPrompts()
			end
		end)
	end
end)

-- v47: hourly TITAN — spawns at the top of every hour, at the SAME moment on
-- every server (all servers agree on the wall-clock hour boundary)
task.spawn(function()
	while true do
		local now = os.time()
		local nextTop = (math.floor(now / 3600) + 1) * 3600
		local waitFor = nextTop - now
		if waitFor > 0 then task.wait(waitFor) end
		pcall(function() (WildSystem :: any).SpawnHourlyTitan() end)
		pcall(function()
			R("Notify"):FireAllClients("👑 A TITAN pet has appeared! Team up and rally to befriend it!", "event")
		end)
		task.wait(5) -- never double-fire on the boundary
	end
end)

-- quest day-rollover: players online across midnight get the new set
task.spawn(function()
	while true do
		task.wait(60)
		for _, p in Players:GetPlayers() do
			pcall(function() QuestSystem.PushStatus(p) end)
		end
	end
end)

-- autosave every 60s
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			GardenManager.SnapshotPlots(player)
		end
		PlayerData.SaveAll()
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		GardenManager.SnapshotPlots(player)
	end
	PlayerData.SaveAll()
end)

print("[GrowAPet] Server started 🌷🐾⚔️")
