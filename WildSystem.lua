--!strict
-- WildSystem (ModuleScript -> ServerScriptService > WildSystem)
-- The wild zones: pets wander their own zone (forests and the two volcanoes). Walk up to one,
-- offer bait (ProximityPrompt "Befriend"), and it may decide to join you.
--
-- Copyright-safe by design: this is NEVER "catching". No balls, no throwing,
-- no weakening, no capture devices of any kind. You offer a treat or berry;
-- the pet chooses you. Starters NEVER appear in the wild.

local WildSystem = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PetData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PetData"))

local PlayerData: any = nil
local EventSystem: any = nil
local QuestSystem: any = nil
local function PD()
	if not PlayerData then PlayerData = require(script.Parent:WaitForChild("PlayerData")) end
	return PlayerData
end
local function ES()
	if not EventSystem then EventSystem = require(script.Parent:WaitForChild("EventSystem")) end
	return EventSystem
end
local function QS()
	if not QuestSystem then QuestSystem = require(script.Parent:WaitForChild("QuestSystem")) end
	return QuestSystem
end

local Remotes: Folder? = nil
local function R(name: string): RemoteEvent
	return ((Remotes :: Folder):WaitForChild(name) :: RemoteEvent)
end

function WildSystem.SetRemotes(folder: Folder)
	Remotes = folder
end

-- top of the BigGround base built by MapBuilder (wild pets walk on it).
-- Zones with their own GroundY (sky islands, twilight halves) override it.
local GROUND_Y = 2 -- v44: island top is y=0 (was -3 for old terrain); pets spawn standing on grass

local function zoneGroundY(zone: { [string]: any }): number
	local gy = (zone.GroundY :: number?) :: number
	if gy then return gy end
	return GROUND_Y
end

-- Species pools: forest pets (everything except water, fire, and ground),
-- volcano pets (fire only), and cave pets (ground/rock only, so the Crystal
-- Cavern has its own identity). Stage-1, non-starter only.
-- Starters NEVER appear in the wild.
local forestPool: { string } = {}
local firePool: { string } = {}
local cavePool: { string } = {} -- v12/v13: crystal caves (Crystal Cavern + Glimmer Grotto)
local skyPool: { string } = {} -- v16: sky islands (Zephyric line only)
local twilightLightPool: { string } = {} -- v23: Daybreak Meadows (Day/Any + light exclusives)
local twilightDarkPool: { string } = {} -- v23: Umbral Fields (Night/Any + dark exclusives)
local function buildPool()
	for id, def in (PetData.PETS :: { [string]: any }) do
		local d = def :: { [string]: any }
		if d.Stage == 1 and not d.Starter and not d.Fossil and not d.Rot and not d.Twilight then -- v14/v21/v23: fossils, rot bugs & twilight exclusives never appear wild
			if d.Sky then -- v16: sky-flagged pets only ever spawn on the islands
				table.insert(skyPool, id)
			elseif d.Type == "Fire" then
				table.insert(firePool, id)
			elseif d.Type == "Ground" then
				table.insert(cavePool, id)
			elseif d.Type ~= "Water" then
				table.insert(forestPool, id)
			end
			-- v23: twilight mirrors — Day/Any wilds also roam the light half,
			-- Night/Any the dark half (sky/fossil/rot/starters never leave home)
			if not d.Sky then
				local at = (d.ActiveTime :: string) or "Any"
				if at == "Day" or at == "Any" then table.insert(twilightLightPool, id) end
				if at == "Night" or at == "Any" then table.insert(twilightDarkPool, id) end
			end
		elseif d.Twilight and d.Stage == 1 then
			-- v23: dimension exclusives, routed by their own ActiveTime
			if d.ActiveTime == "Day" then
				table.insert(twilightLightPool, id)
			elseif d.ActiveTime == "Night" then
				table.insert(twilightDarkPool, id)
			end
		end
	end
end

local wilds: { [string]: { [string]: any } } = {}
local uidCounter = 0
local lastAttempt: { [number]: number } = {}

-- v10: forests + two volcanoes — pets split across all wild zones
-- Pushes points out of a zone's ClearR circle (volcano cone is solid rock).
local function avoidClear(p: Vector3, zone: { [string]: any }): Vector3
	local cr = (zone.ClearR :: number?) :: number
	if not cr then return p end
	local dx, dz = p.X - (zone.ClearCX :: number), p.Z - (zone.ClearCZ :: number)
	local d = math.sqrt(dx * dx + dz * dz)
	if d >= cr then return p end
	if d < 0.01 then dx, dz, d = 1, 0, 1 end
	local s = cr / d
	return Vector3.new((zone.ClearCX :: number) + dx * s, p.Y, (zone.ClearCZ :: number) + dz * s)
end

-- v16: sky zones use per-island spawn discs {cx, cz, r} at GroundY (island-top
-- height). Pets always land ON an island, never in the gaps between them.
local function nearestIsland(zone: { [string]: any }, x: number, z: number): { [string]: any }
	local best = nil
	local bestD = math.huge
	for _, isl in (zone.Islands :: { { [string]: any } }) do
		local dx, dz = x - (isl.cx :: number), z - (isl.cz :: number)
		local d = dx * dx + dz * dz
		if d < bestD then bestD, best = d, isl end
	end
	return best :: { [string]: any }
end

local function discPoint(zone: { [string]: any }, isl: { [string]: any }): Vector3
	local a = math.random() * math.pi * 2
	local r = math.sqrt(math.random()) * math.max(4, (isl.r :: number) - 6)
	return Vector3.new((isl.cx :: number) + math.cos(a) * r,
		(zone.GroundY :: number) or 100, (isl.cz :: number) + math.sin(a) * r)
end

local function skyPoint(zone: { [string]: any }): Vector3
	local islands = (zone.Islands :: { { [string]: any } })
	local isl = islands[math.random(1, #islands)]
	return discPoint(zone, isl)
end

local function clampSky(p: Vector3, zone: { [string]: any }): Vector3
	local isl = nearestIsland(zone, p.X, p.Z)
	local dx, dz = p.X - (isl.cx :: number), p.Z - (isl.cz :: number)
	local maxR = math.max(4, (isl.r :: number) - 5)
	local d = math.sqrt(dx * dx + dz * dz)
	if d > maxR then
		dx, dz = dx / d * maxR, dz / d * maxR
	end
	return Vector3.new((isl.cx :: number) + dx, (zone.GroundY :: number) or 100, (isl.cz :: number) + dz)
end

local function zonePoint(zone: { [string]: any }): Vector3
	if (zone.Kind :: string) == "Sky" then return skyPoint(zone) end
	local x = (zone.MinX :: number) + math.random() * ((zone.MaxX :: number) - (zone.MinX :: number))
	local zz = (zone.MinZ :: number) + math.random() * ((zone.MaxZ :: number) - (zone.MinZ :: number))
	return avoidClear(Vector3.new(x, zoneGroundY(zone), zz), zone)
end

local function clampZone(p: Vector3, zone: { [string]: any }): Vector3
	if (zone.Kind :: string) == "Sky" then return clampSky(p, zone) end
	return Vector3.new(
		math.clamp(p.X, (zone.MinX :: number) + 4, (zone.MaxX :: number) - 4),
		zoneGroundY(zone),
		math.clamp(p.Z, (zone.MinZ :: number) + 4, (zone.MaxZ :: number) - 4))
end

local function allZones(): { { [string]: any } }
	local zs: { { [string]: any } } = {}
	for _, z in (Config.ForestZones :: { { [string]: any } }) do
		table.insert(zs, z)
	end
	for _, z in (Config.VolcanoZones :: { { [string]: any } }) do
		table.insert(zs, z)
	end
	for _, z in (Config.CaveZones :: { { [string]: any } }) do
		table.insert(zs, z)
	end
	for _, z in (Config.SkyZones :: { { [string]: any } }) do -- v16
		table.insert(zs, z)
	end
	-- v23: twilight dimension halves (eternal day / eternal night)
	table.insert(zs, (Config.TwilightLightZone :: { [string]: any }))
	table.insert(zs, (Config.TwilightDarkZone :: { [string]: any }))
	return zs
end

local function randomZone(): { [string]: any }
	local zones = allZones()
	return zones[math.random(1, #zones)]
end

-- pink sparkle burst when a pet agrees to join
local function heartsBurst(at: Vector3)
	for _ = 1, 7 do
		local p = Instance.new("Part")
		p.Name = "HeartSpark"
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(0.9, 0.9, 0.9)
		p.Color = Color3.fromRGB(255, 130, 180)
		p.Material = Enum.Material.Neon
		p.Anchored = true
		p.CanCollide = false
		p.CFrame = CFrame.new(at + Vector3.new(math.random(-3, 3), 2 + math.random() * 3, math.random(-3, 3)))
		p.Parent = workspace
		task.spawn(function()
			for _ = 1, 12 do
				if not p.Parent then break end
				p.CFrame += Vector3.new(0, 0.3, 0)
				task.wait(0.1)
			end
			p:Destroy()
		end)
	end
end

local function removeWild(uid: string)
	local rec = wilds[uid]
	if not rec then return end
	wilds[uid] = nil
	local m = rec.Model :: Model
	if m and m.Parent then m:Destroy() end
end

-- v26: find the nearest currently-spawned shiny wild pet within range of a
-- position. Server-side only — the radar result is authoritative.
-- Returns {Uid, PetId, Name, Pos, Dist} or nil.
function WildSystem.FindShinyNear(pos: Vector3, range: number): { [string]: any }?
	local best: { [string]: any }? = nil
	local bestD = range
	for _, rec in wilds do
		local r = rec :: { [string]: any }
		if (r.Shiny :: boolean) == true then
			local model = r.Model :: Model
			if model and model.Parent then
				local d = (model:GetPivot().Position - pos).Magnitude
				if d <= bestD then
					bestD = d
					best = {
						Uid = r.Uid,
						PetId = r.PetId,
						Name = ((PetData.PETS :: { [string]: any })[r.PetId].Name :: string),
						Pos = model:GetPivot().Position,
						Dist = math.floor(d),
					}
				end
			end
		end
	end
	return best
end

local function wildFolder(): Folder
	local f = workspace:FindFirstChild("WildPets")
	if f and f:IsA("Folder") then return f :: Folder end
	local nf = Instance.new("Folder")
	nf.Name = "WildPets"
	nf.Parent = workspace
	return nf
end

-- zone icon for prompts/labels
local function zoneIcon(zone: { [string]: any }): string
	local kind = (zone.Kind :: string) or "Forest"
	if kind == "Volcano" then return "🌋" end
	if kind == "Cave" then return "💎" end
	if kind == "Sky" then return "☁️" end -- v16
	if kind == "TwilightLight" then return "☀️" end -- v23
	if kind == "TwilightDark" then return "🌙" end -- v23
	return "🌲"
end

local function spawnWild(forceZone: { [string]: any }?, forceTitan: boolean?)
	local zone = forceZone or randomZone()
	local kind = (zone.Kind :: string) or "Forest"
	-- volcano spawns fire pets only; the cave spawns ground/rock pets only;
	-- forests spawn everything except water/fire/ground.
	-- v11: only species whose ActiveTime matches the current phase come out
	-- (or "Any"). Existing wild pets stay when the phase flips.
	-- v23: the twilight halves force their own phase (Light=Day, Dark=Night)
	-- so the global cycle never overrides them.
	local base = if kind == "Volcano" then firePool
		elseif kind == "Cave" then cavePool
		elseif kind == "Sky" then skyPool -- v16: sky islands (Zephyric line only)
		elseif kind == "TwilightLight" then twilightLightPool -- v23: Daybreak Meadows
		elseif kind == "TwilightDark" then twilightDarkPool -- v23: Umbral Fields
		else forestPool
	-- v23: the dimension halves are eternal day / eternal night — the global
	-- phase NEVER decides what comes out here; each half forces its own.
	local phase = if kind == "TwilightLight" then "Day"
		elseif kind == "TwilightDark" then "Night"
		else ES().Phase()
	local pool: { string } = {}
	for _, id in base do
		local at = (((PetData.PETS :: { [string]: any })[id] :: { [string]: any }).ActiveTime :: string) or "Any"
		if at == "Any" or at == phase then table.insert(pool, id) end
	end
	if #pool == 0 then pool = base end -- safety: never spawn nothing
	if #pool == 0 then return end
	uidCounter += 1
	local uid = "wild_" .. uidCounter .. "_" .. math.floor(os.clock() * 1000)
	local petId = pool[math.random(1, #pool)]
	-- shiny is rolled at SPAWN so you can SEE it (sparkles + SHINY tag)
	-- before spending bait -- never a blind gamble.
	local shiny = PetData.RollShiny(ES().GetShinyMult()) -- 1 in 4000 (x2 during 🌈 Rainbow)
	-- v12: ~2% of spawns are TITANS -- giant pets that need a co-op rally
	-- (2+ different players) to befriend. Titan and shiny roll independently.
	local titan = forceTitan == true or math.random() < (Config.TitanChance :: number)
	local model = PetData.BuildPetModel(petId, if titan then 3.0 else 1.0, nil, shiny)
	model.Name = "WildPet_" .. petId
	-- v47.1: offset the spawn by the model's pivot height (BuildPetModel puts
	-- the pivot 1.7*scale above the feet) so pets sit ON the ground instead
	-- of floating (normal) or spawning buried (Titans at 3x scale).
	local pdef = (PetData.PETS :: { [string]: any })[petId]
	local feetOffset = 1.7 * (if titan then 3.0 else 1.0) * (((pdef :: { [string]: any }).Size :: number) or 1)
	local sp = zonePoint(zone)
	model:PivotTo(CFrame.new(sp.X, sp.Y + feetOffset, sp.Z))
	model.Parent = wildFolder()
	local pname: string = ((PetData.PETS :: { [string]: any })[petId].Name :: string)
	local zicon = zoneIcon(zone)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BefriendPrompt"
	prompt.ActionText = if titan then "👑 Rally (team bait!)" else "🤝 Befriend (bait)"
	prompt.ObjectText = (if titan then "👑 TITAN " else "")
		.. (if shiny then "✨ SHINY " else "") .. pname .. " " .. zicon
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = if titan then 16 else 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	if titan then
		-- big golden "👑 TITAN" nameplate, readable across the zone
		local bb = Instance.new("BillboardGui")
		bb.Name = "TitanTag"
		bb.Size = UDim2.new(0, 130, 0, 28) -- v44: smaller (was 220x48)
		bb.StudsOffset = Vector3.new(0, 7, 0)
		bb.AlwaysOnTop = true
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.new(1, 0, 1, 0)
		tl.BackgroundTransparency = 0.3
		tl.BackgroundColor3 = Color3.fromRGB(90, 60, 10)
		tl.Text = "👑 TITAN"
		tl.TextScaled = true
		tl.TextColor3 = Color3.fromRGB(255, 225, 120)
		tl.Font = Enum.Font.FredokaOne
		tl.Parent = bb
		bb.Adornee = model.PrimaryPart
		bb.Parent = model.PrimaryPart
	end
	local rec: { [string]: any } = {
		Uid = uid, PetId = petId, Model = model, Zone = zone,
		ShyUntil = 0, Speed = 1, Target = nil, NextThink = 0,
		Shiny = shiny,
		Titan = titan, -- v12
		Rally = nil, -- v12: active co-op rally state (titans only)
	}
	wilds[uid] = rec
	prompt.Triggered:Connect(function(player: Player)
		WildSystem.TryBefriend(player, uid)
	end)
end

-- v47.2: the real hourly Titan spawner (renamed from DebugSpawnTitan — it was
-- never just a debug hook). Old name kept as an alias for command-bar muscle memory.
-- View -> Command Bar: require(game.ServerScriptService.WildSystem).SpawnHourlyTitan()
function WildSystem.SpawnHourlyTitan(): string?
	-- mark existing titans so the search below finds the fresh one
	for _, rec in wilds do
		(rec :: { [string]: any }).DebugForced = true
	end
	local zones = allZones()
	spawnWild(zones[math.random(1, #zones)], true)
	for uid, rec in wilds do
		if (rec :: { [string]: any }).Titan == true and not (rec :: { [string]: any }).DebugForced then
			(rec :: { [string]: any }).DebugForced = true
			return uid
		end
	end
	return nil
end
WildSystem.DebugSpawnTitan = WildSystem.SpawnHourlyTitan -- deprecated alias

-- Offer bait. The pet decides. Bait is only eaten on SUCCESS.
-- Bait priority: Sweet Berry (95%) first, then Pet Treat (70%).
function WildSystem.TryBefriend(player: Player, uid: string): (boolean, string)
	local now = os.clock()
	local last = lastAttempt[player.UserId] or 0
	if now - last < (Config.BefriendAttemptGap :: number) then return false, "Too fast!" end
	lastAttempt[player.UserId] = now
	local rec = wilds[uid]
	if not rec then return false, "That pet already wandered off!" end
	local model = rec.Model :: Model
	if not model.Parent then wilds[uid] = nil return false, "That pet already wandered off!" end
	if now < (rec.ShyUntil :: number) then
		if Remotes then R("Notify"):FireClient(player, "It's still shy... give it a moment. " .. zoneIcon(rec.Zone), "warn") end
		return false, "shy"
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local pp = model:GetPivot().Position
	if not hrp or ((hrp :: BasePart).Position - pp).Magnitude > 16 then
		if Remotes then R("Notify"):FireClient(player, "Get closer to offer a treat!", "warn") end
		return false, "too far"
	end
	-- v12: Titans are NEVER befriended solo -- they need a co-op rally.
	if (rec.Titan :: boolean) == true then
		return WildSystem.TryTitanRally(player, uid, rec)
	end
	local prof = PD().Get(player)
	local items: { [string]: number } = (prof.Items :: { [string]: number })
	-- bait priority: Sweet Berry first (nearly irresistible), then Pet Treat
	local baitId: string? = nil
	local chance: number = 0
	local baitDesc = ""
	if (items.SweetBerry or 0) >= 1 then
		baitId, chance, baitDesc = "SweetBerry", (Config.BefriendBerryChance :: number), "🫐 Sweet Berry"
	elseif (items.PetTreat or 0) >= 1 then
		baitId, chance, baitDesc = "PetTreat", (Config.BefriendChance :: number), "🍪 Pet Treat"
	end
	if not baitId then
		if Remotes then R("Notify"):FireClient(player, "You need bait — grab Treats or Berries at the shop!", "warn") end
		return false, "no bait"
	end
	local petId: string = rec.PetId
	local pname: string = ((PetData.PETS :: { [string]: any })[petId].Name :: string)
	if math.random() < chance then
		-- it chooses you! bait is eaten, pet joins the collection
		PD().RemoveItem(player, baitId :: string)
		heartsBurst(pp)
		local wasShiny: boolean = (rec.Shiny :: boolean) == true
		removeWild(uid)
		PD().AddPet(player, petId, nil, wasShiny)
		pcall(function() QS().Progress(player, "befriend", 1) end)
		local msg = if wasShiny
			then "✨ SHINY " .. pname .. " joined you! 1 in 4000!! ✨"
			elseif baitId == "SweetBerry"
			then "🤝 " .. pname .. " couldn't resist the 🫐 Sweet Berry!"
			else "🤝 " .. pname .. " decided to join you!"
		if Remotes then R("Notify"):FireClient(player, msg, if wasShiny then "shiny" else "ok") end
		-- a new wild pet wanders in after a while
		local wait = (Config.WildRespawnMin :: number)
			+ math.random() * ((Config.WildRespawnMax :: number) - (Config.WildRespawnMin :: number))
		local homeZone = rec.Zone
		task.delay(wait, function() spawnWild(homeZone) end)
		return true, "befriended"
	else
		-- not this time: it gets shy and hurries off. bait is NOT eaten.
		rec.ShyUntil = now + (Config.BefriendShySeconds :: number)
		rec.Speed = 2.4
		local away = clampZone(pp + (pp - (hrp :: BasePart).Position).Unit * 40, rec.Zone)
		rec.Target = avoidClear(away, rec.Zone)
		task.delay(Config.BefriendShySeconds :: number, function()
			local r2 = wilds[uid]
			if r2 then r2.Speed = 1 end
		end)
		local zicon2 = zoneIcon(rec.Zone)
		if Remotes then R("Notify"):FireClient(player, "It scampered off... maybe try again later! " .. zicon2, "warn") end
		return false, "shy"
	end
end

-- ============================================================================
-- v12: TITAN co-op rallies
-- ============================================================================
-- Befriending a Titan needs 2+ DIFFERENT players offering bait within a
-- 60-second rally window. The first offer starts the rally and announces the
-- Titan server-wide. Joining costs nothing up front -- bait is only spent on
-- SUCCESS (each contributor spends one bait, their own best: berry first).
-- ONE roll happens when the 2nd player joins, using the INITIATOR's bait odds
-- (berry 95% / treat 70%). On success the initiator gets the Titan; helpers
-- get 150 coins + "befriend" quest credit. On failure or timeout nobody is
-- charged (same no-cost-failure rule as normal befriending).
function WildSystem.TryTitanRally(player: Player, uid: string, rec: { [string]: any }): (boolean, string)
	local now = os.clock()
	local petId: string = rec.PetId
	local pname: string = ((PetData.PETS :: { [string]: any })[petId].Name :: string)
	-- find this player's best bait (berry first). not spent yet -- only on success.
	local prof = PD().Get(player)
	local items: { [string]: number } = (prof.Items :: { [string]: number })
	local baitId: string? = nil
	if (items.SweetBerry or 0) >= 1 then baitId = "SweetBerry"
	elseif (items.PetTreat or 0) >= 1 then baitId = "PetTreat" end
	if not baitId then
		if Remotes then R("Notify"):FireClient(player, "You need bait to join the rally — grab Treats or Berries at the shop!", "warn") end
		return false, "no bait"
	end
	local rally = rec.Rally
	if rally and now >= (rally.EndsAt :: number) then
		-- stale rally (the timer below fires ExpireRally, but this is safer)
		rec.Rally = nil
		rally = nil
	end
	if not rally then
		-- first offer starts the rally + announces the Titan to the whole server
		local seconds: number = Config.TitanRallySeconds
		rec.Rally = { Initiator = player.UserId, Members = { [player.UserId] = baitId }, EndsAt = now + seconds }
		if Remotes then
			R("Announce"):FireAllClients("👑 TITAN " .. pname .. "!",
				"Offer bait together! " .. seconds .. " seconds for 2+ players to join the rally!", Color3.fromRGB(255, 200, 60))
		end
		task.delay(seconds, function() WildSystem.ExpireRally(uid) end)
		if Remotes then R("Notify"):FireClient(player, "👑 Rally started! A different player must offer bait too!", "ok") end
		return true, "rally started"
	end
	local members: { [number]: string } = rally.Members
	if members[player.UserId] then
		if Remotes then R("Notify"):FireClient(player, "You're already in this rally — a DIFFERENT player must join! 👑", "warn") end
		return false, "already joined"
	end
	members[player.UserId] = baitId
	local count = 0
	for _ in members do count += 1 end
	if Remotes then
		R("Notify"):FireClient(player, "👑 You joined the rally! (" .. count .. "/2+)", "ok")
		local initPlayer = Players:GetPlayerByUserId(rally.Initiator)
		if initPlayer then R("Notify"):FireClient(initPlayer, "👑 " .. player.DisplayName .. " joined your Titan rally!", "ok") end
	end
	if count >= 2 then
		WildSystem.ResolveRally(uid)
	end
	return true, "rally joined"
end

-- ONE roll when the 2nd distinct player joins, using the initiator's bait odds.
function WildSystem.ResolveRally(uid: string)
	local rec = wilds[uid]
	if not rec or not rec.Rally then return end
	local rally = rec.Rally
	rec.Rally = nil
	local members: { [number]: string } = rally.Members
	local initBait: string? = members[rally.Initiator]
	local chance = if initBait == "SweetBerry" then (Config.BefriendBerryChance :: number) else (Config.BefriendChance :: number)
	local model = rec.Model :: Model
	local pp = model:GetPivot().Position
	local petId: string = rec.PetId
	local pname: string = ((PetData.PETS :: { [string]: any })[petId].Name :: string)
	local wasShiny: boolean = (rec.Shiny :: boolean) == true
	if math.random() < chance then
		-- SUCCESS: every contributor spends one bait (their own best),
		-- the initiator gets the Titan, helpers get coins + quest credit.
		for userId, baitId in members do
			local pl = Players:GetPlayerByUserId(userId)
			if pl then PD().RemoveItem(pl, baitId) end
		end
		heartsBurst(pp)
		removeWild(uid)
		local initPlayer = Players:GetPlayerByUserId(rally.Initiator)
		if not initPlayer then
			-- initiator left mid-rally: promote another present member
			for userId, _ in members do
				local pl = Players:GetPlayerByUserId(userId)
				if pl then
					rally.Initiator = userId
					initPlayer = pl
					break
				end
			end
		end
		if initPlayer then
			PD().AddPet(initPlayer, petId, nil, wasShiny, true)
			pcall(function() QS().Progress(initPlayer, "befriend", 1) end)
			if Remotes then
				R("Notify"):FireClient(initPlayer,
					"👑 " .. (if wasShiny then "✨ SHINY " else "") .. "TITAN " .. pname .. " joined you!! 👑",
					if wasShiny then "shiny" else "ok")
			end
		end
		for userId, _ in members do
			if userId ~= rally.Initiator then
				local helper = Players:GetPlayerByUserId(userId)
				if helper then
					PD().AddCoins(helper, Config.TitanHelperReward, "titan_help")
					pcall(function() QS().Progress(helper, "befriend", 1) end)
					if Remotes then
						R("Notify"):FireClient(helper,
							"👑 You helped befriend a Titan! +" .. (Config.TitanHelperReward :: number) .. " coins!", "ok")
					end
				end
			end
		end
		-- a new wild pet wanders in after a while
		local wait = (Config.WildRespawnMin :: number)
			+ math.random() * ((Config.WildRespawnMax :: number) - (Config.WildRespawnMin :: number))
		local homeZone = rec.Zone
		task.delay(wait, function() spawnWild(homeZone) end)
	else
		-- FAILURE: the Titan gets shy and hurries off. NOBODY is charged.
		rec.ShyUntil = os.clock() + (Config.BefriendShySeconds :: number)
		rec.Speed = 2.4
		if Remotes then
			for userId, _ in members do
				local pl = Players:GetPlayerByUserId(userId)
				if pl then R("Notify"):FireClient(pl, "The Titan refused... nobody lost any bait. " .. zoneIcon(rec.Zone), "warn") end
			end
		end
		task.delay(Config.BefriendShySeconds :: number, function()
			local r2 = wilds[uid]
			if r2 then r2.Speed = 1 end
		end)
	end
end

-- The 60s rally window ran out with fewer than 2 players. Nobody is charged.
function WildSystem.ExpireRally(uid: string)
	local rec = wilds[uid]
	if not rec or not rec.Rally then return end
	rec.Rally = nil
	local petId: string = rec.PetId
	local pname: string = ((PetData.PETS :: { [string]: any })[petId].Name :: string)
	if Remotes then
		R("Announce"):FireAllClients("👑 The Titan " .. pname .. " lost interest...",
			"The rally needed 2+ players. It's still out there — try again with a friend!", Color3.fromRGB(200, 160, 60))
	end
end

-- smooth wander: framerate-independent strolling with eased turning.
-- Pets drift onward with a sideways bend (curved paths instead of zig-zags),
-- pause sometimes, and turn with a shortest-arc lerp instead of snapping.
local RunService = game:GetService("RunService")

-- shortest-arc angle lerp (handles wrap-around at ±π)
local function lerpAngle(a: number, b: number, t: number): number
	local diff = (b - a) % (math.pi * 2)
	if diff > math.pi then
		diff -= math.pi * 2
	end
	return a + diff * t
end

local function wanderLoop()
	local last = os.clock()
	while true do
		local now = os.clock()
		local dt = math.min(now - last, 0.1) -- clamp hitches so pets never teleport
		last = now
		for uid, rec in wilds do
			local model = rec.Model :: Model
			if not model.Parent then
				removeWild(uid) -- v47: model destroyed externally; drop the stale record so wilds never accumulates dead entries
			else
				local pivot = model:GetPivot()
				local p = pivot.Position
				if now >= (rec.NextThink :: number) then
					if math.random() < 0.3 then
						rec.Target = nil -- idle pause
					else
						-- drift onward: mostly forward with a random sideways bend
						local zv = pivot.ZVector
						local dist = 24 + math.random() * 24
						local bend = (math.random() * 2 - 1) * 22
						local t = p + Vector3.new(
							zv.X * dist - zv.Z * bend,
							0,
							zv.Z * dist + zv.X * bend
						)
						rec.Target = avoidClear(clampZone(t, rec.Zone), rec.Zone)
					end
					rec.NextThink = now + 2.5 + math.random() * 3.5
				end
				local t = rec.Target :: Vector3?
				if t then
					local d = Vector3.new(t.X - p.X, 0, t.Z - p.Z)
					local dist = d.Magnitude
					if dist <= 1.5 then
						rec.Target = nil -- arrived: idle until the next think
					else
						-- ease the turn (pets face +Z by construction)
						local zv = pivot.ZVector
						local yaw = lerpAngle(
							math.atan2(zv.X, zv.Z),
							math.atan2(d.X, d.Z),
							math.min(1, dt * 5)
						)
						-- stroll at the pet's speed, framerate-independent
						local step = math.min(dist, 5 * (rec.Speed :: number) * dt)
						local np = p + d.Unit * step
						pcall(function()
							model:PivotTo(CFrame.new(np.X, p.Y, np.Z) * CFrame.Angles(0, yaw, 0))
						end)
					end
				end
			end
		end
		RunService.Heartbeat:Wait()
	end
end

function WildSystem.Start()
	buildPool()
	wildFolder()
	for _ = 1, (Config.WildCount :: number) do
		spawnWild()
	end
	task.spawn(wanderLoop)
	print("[GrowAPet] WildSystem: " .. #forestPool .. " forest species, " .. #firePool
		.. " volcano species, " .. #cavePool .. " cave species, " .. #skyPool
		.. " sky species, " .. #twilightLightPool .. " twilight-day species, "
		.. #twilightDarkPool .. " twilight-night species, " .. (Config.WildCount :: number)
		.. " wild pets wandering 🌲🌋💎☁️🌗🤝")
end

-- Jarvis health endpoint: snapshot of the wild population for the auto-reporter
function WildSystem.GetHealth(): { count: number, titans: number }
	local count, titans = 0, 0
	for _, rec in pairs(wilds) do
		count += 1
		if (rec :: { [string]: any }).Titan == true then
			titans += 1
		end
	end
	return { count = count, titans = titans }
end

return WildSystem
