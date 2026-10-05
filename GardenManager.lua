--!strict
-- GardenManager (ModuleScript -> ServerScriptService > GardenManager)
-- Owns every garden: plot data, planting eggs AND pets, watering, buying plots.
-- Growing a pet is SAFE: the pet record lives on the plot while growing and is
-- always returned on harvest (evolved or unchanged). Builds garden visuals in
-- code so only a baseplate + spawn needs placing.

local GardenManager = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PetData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PetData"))

local PlayerData: any = nil -- lazy (avoids load-order issue)
local EventSystem: any = nil
local QuestSystem: any = nil
local FountainSystem: any = nil -- v22: lucky-fountain blessings
local function PD() if not PlayerData then PlayerData = require(script.Parent:WaitForChild("PlayerData")) end return PlayerData end
local function ES() if not EventSystem then EventSystem = require(script.Parent:WaitForChild("EventSystem")) end return EventSystem end
local function QS() if not QuestSystem then QuestSystem = require(script.Parent:WaitForChild("QuestSystem")) end return QuestSystem end
local function FS() if not FountainSystem then FountainSystem = require(script.Parent:WaitForChild("FountainSystem")) end return FountainSystem end

local Remotes: Folder? = nil
local function R(name: string): RemoteEvent
	return ((Remotes :: Folder):WaitForChild(name) :: RemoteEvent)
end

export type Plot = {
	Index: number,
	Part: Part,
	State: string, -- "Empty" | "Growing" | "Ready"
	Mode: string?, -- "Egg" | "Pet"
	EggId: string?,
	Pet: { [string]: any }?, -- pet record while growing (safe, never destroyed)
	PetId: string?, -- species currently in plot (for visuals/sync)
	Mutation: string?,
	Progress: number, -- 0..1
	GrowTime: number,
	WaterUntil: number, -- os.clock cooldown
	SuperWater: number, -- stacked super-water crits, consumed on harvest
	EvoStone: string?, -- v24: evolution stone set on this plot (consumed only if it forces evolution)
	Model: Model?,
	ReadyBillboard: BillboardGui?,
	-- v21: rot / infestation state (timer ticks ONLINE ONLY — the per-second
	-- growth loop only iterates live gardens, so offline time never accrues)
	RotOnline: number, -- accumulated online seconds while Ready
	RotWarned: boolean, -- 75% warning already sent
	RotReady: boolean, -- true once the plot has rotted (harvests a bug pet)
	RotBugId: string?, -- bug species this rotted plot will harvest into
	Repelled: boolean, -- pest repellent active: cannot rot this cycle
	RotCloud: ParticleEmitter?, -- stink cloud FX (rotted plots)
	RotFlies: ParticleEmitter?, -- fly FX (rotted plots)
	RepelSheen: ParticleEmitter?, -- protective sheen FX (repelled plots)
	ClickConn: RBXScriptConnection?, -- v47: soil ClickDetector connection (disconnected on garden teardown)
}

export type Garden = {
	Owner: Player,
	Index: number,
	Origin: Vector3,
	Plots: { [number]: Plot },
	Folder: Folder,
	ReusedVisuals: boolean, -- v47: true when Folder is a renamed MapBuilt prebuilt (restored, not destroyed, on release)
}

local gardens: { [number]: Garden } = {} -- userId -> garden
local gardenByIndex: { [number]: Garden } = {} -- garden index -> garden (claim checks)
local claimPrompts: { [number]: ProximityPrompt? } = {} -- garden index -> hold-E claim prompt

function GardenManager.PlotKey(userId: number, index: number): string
	return userId .. ":" .. index
end

function GardenManager.ParseKey(key: string): (number?, number?)
	local a, b = string.match(key, "^(%d+):(%d+)$")
	if not a then return nil end
	return tonumber(a) :: number, tonumber(b) :: number
end

function GardenManager.SetRemotes(folder: Folder)
	Remotes = folder
end

-- 6 fixed garden spots: symmetric hexagonal ring around the central plaza
-- (v17 fair map). Radius 140, one garden every 60 degrees, so every garden is
-- exactly as far from the plaza, lakes, and dig sites as every other.
function GardenManager.GardenOrigin(index: number): Vector3
	if index < 6 then
		local a = math.rad(index * 60)
		return Vector3.new(140 * math.cos(a), 0, -140 * math.sin(a))
	end
	-- safety fallback for a 7th+ player: clear SE corner (verified empty)
	return Vector3.new(450, 0, -350 - (index - 6) * 80)
end

function GardenManager.GetGarden(player: Player): Garden?
	return gardens[player.UserId]
end

function GardenManager.GetGardenByUserId(userId: number): Garden?
	return gardens[userId]
end

function GardenManager.GetAllGardens(): { [number]: Garden }
	return gardens
end

function GardenManager.GetPlot(userId: number, index: number): Plot?
	local g = gardens[userId]
	return g and g.Plots[index] or nil
end

-- ---- visuals -------------------------------------------------------------
local function mkPart(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.Parent = parent
	return p
end

local function plotGridPos(garden: Garden, index: number): Vector3
	local i0 = index - 1
	local col = i0 % Config.PlotCols
	local row = math.floor(i0 / Config.PlotCols)
	local ox = (col - (Config.PlotCols - 1) / 2) * Config.PlotSpacing
	local oz = (row - 1.5) * Config.PlotSpacing
	return garden.Origin + Vector3.new(ox, 0.5, oz)
end

local function createPlotVisual(garden: Garden, index: number): Plot
	-- v46: reuse MapBuilder visual if it exists
	local existing = garden.Folder:FindFirstChild("Plot" .. index)
	local soil: Part
	if existing and existing:IsA("BasePart") then
		soil = existing :: Part
	else
		local pos = plotGridPos(garden, index)
		soil = mkPart(garden.Folder, "Plot" .. index, Vector3.new(8, 1, 8), pos, Color3.fromRGB(115, 78, 52), Enum.Material.Ground)
		soil.CanCollide = false -- walk over plots; clicks still work
		-- wooden raised-bed frame, Grow-a-Garden style
		mkPart(garden.Folder, "PlotRim" .. index, Vector3.new(9, 0.6, 9), pos - Vector3.new(0, 0.55, 0), Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
		local cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 14
		cd.Parent = soil
	end
	-- ensure ClickDetector exists and is wired
	local cd = soil:FindFirstChildOfClass("ClickDetector")
	if not cd then
		cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 14
		cd.Parent = soil
	end
	local plot: Plot = {
		Index = index, Part = soil, State = "Empty",
		Mode = nil, EggId = nil, Pet = nil, PetId = nil, Mutation = nil,
		Progress = 0, GrowTime = 0, WaterUntil = 0, SuperWater = 0,
		Model = nil, ReadyBillboard = nil,
		RotOnline = 0, RotWarned = false, RotReady = false, RotBugId = nil,
		Repelled = false, RotCloud = nil, RotFlies = nil, RepelSheen = nil,
		EvoStone = nil, -- v24: armed evolution stone (stoneId) for this plot
	}
	-- v47: keep the connection so garden teardown can disconnect it (a re-claim
	-- re-wires the same soil ClickDetector, which would otherwise double-fire)
	plot.ClickConn = (cd :: ClickDetector).MouseClick:Connect(function(clicker: Player)
		GardenManager.OnPlotClicked(clicker, garden, plot)
	end)
	garden.Plots[index] = plot
	return plot
end

-- v46: claim flow — assign a SPECIFIC garden index (called by ClaimGarden,
-- from the hold-E prompt at the garden gate). Gardens are no longer
-- auto-assigned on join; the player claims one by holding E.
local function assignGardenAt(player: Player, index: number): Garden
	local existing = gardens[player.UserId]
	if existing then return existing end
	local origin = GardenManager.GardenOrigin(index)
	-- v46: reuse MapBuilder visuals if they exist (so gardens are visible immediately)
	local visFolder = workspace:FindFirstChild("MapBuilt") and workspace.MapBuilt:FindFirstChild("GardenVis_" .. index)
	local folder: Folder
	local reusedVisuals = visFolder ~= nil
	if visFolder then
		-- use the pre-built visuals (already has fences, plots, sign)
		folder = visFolder :: Folder
		folder.Name = "Garden_" .. player.Name
	else
		folder = Instance.new("Folder")
		folder.Name = "Garden_" .. player.Name
		folder.Parent = workspace
		mkPart(folder, "Grass", Vector3.new(76, 1, 56), origin - Vector3.new(0, 0.45, 0), Color3.fromRGB(88, 176, 98), Enum.Material.Grass)
	end

	-- Only build fences/flowers/sign if NOT reusing prebuilt visuals
	-- (BuildEverything already built them)
	if not reusedVisuals then
	local gdx, gdz = -origin.X, -origin.Z -- direction from garden to plaza
	local gateSide: string
	if math.abs(gdx) > math.abs(gdz) then
		gateSide = if gdx > 0 then "E" else "W"
	else
		gateSide = if gdz > 0 then "S" else "N"
	end
	local picketWhite = Color3.fromRGB(246, 246, 242)
	for _, sz in { -1, 1 } do
		local rail = mkPart(folder, "Rail", Vector3.new(76, 0.6, 0.6), origin + Vector3.new(0, 2.2, sz * 28), picketWhite)
		rail.CanCollide = false
	end
	for _, sx in { -1, 1 } do
		local rail = mkPart(folder, "Rail", Vector3.new(0.6, 0.6, 56), origin + Vector3.new(sx * 38, 2.2, 0), picketWhite)
		rail.CanCollide = false
	end
	for x = -36, 36, 4 do
		if not (gateSide == "N" and math.abs(x) < 8) then
			mkPart(folder, "Picket", Vector3.new(2.2, 3, 1), origin + Vector3.new(x, 1.5, -28), picketWhite)
		end
		if not (gateSide == "S" and math.abs(x) < 8) then
			mkPart(folder, "Picket", Vector3.new(2.2, 3, 1), origin + Vector3.new(x, 1.5, 28), picketWhite)
		end
	end
	for z = -24, 24, 4 do
		if not (gateSide == "W" and math.abs(z) < 8) then
			mkPart(folder, "Picket", Vector3.new(1, 3, 2.2), origin + Vector3.new(-38, 1.5, z), picketWhite)
		end
		if not (gateSide == "E" and math.abs(z) < 8) then
			mkPart(folder, "Picket", Vector3.new(1, 3, 2.2), origin + Vector3.new(38, 1.5, z), picketWhite)
		end
	end

	-- decorative flowers along the fence line (non-colliding)
	local petalColors = {
		Color3.fromRGB(255, 120, 160), Color3.fromRGB(255, 200, 80),
		Color3.fromRGB(180, 120, 255), Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(255, 140, 80),
	}
	for _ = 1, 8 do
		local fx = math.random(-35, 35)
		local fz = if math.random() < 0.5 then -math.random(22, 26) else math.random(22, 26)
		local fpos = origin + Vector3.new(fx, 0, fz)
		local stem = mkPart(folder, "FlowerStem", Vector3.new(0.3, 1.6, 0.3), fpos + Vector3.new(0, 0.8, 0), Color3.fromRGB(60, 140, 70))
		stem.CanCollide = false
		local head = mkPart(folder, "FlowerHead", Vector3.new(1.2, 1.2, 1.2), fpos + Vector3.new(0, 1.9, 0), petalColors[math.random(1, #petalColors)])
		head.Shape = Enum.PartType.Ball
		head.CanCollide = false
	end

	-- sign on the plaza-facing side (above the gate)
	local sox, soz = 0, 0
	local signSize = Vector3.new(10, 4, 0.5)
	if gateSide == "N" then soz = -31
	elseif gateSide == "S" then soz = 31
	elseif gateSide == "W" then
		sox = -41
		signSize = Vector3.new(0.5, 4, 10)
	elseif gateSide == "E" then
		sox = 41
		signSize = Vector3.new(0.5, 4, 10)
	end
	local post = mkPart(folder, "SignPost", Vector3.new(1, 6, 1), origin + Vector3.new(sox, 3, soz), Color3.fromRGB(120, 85, 55), Enum.Material.Wood)
	local sign = mkPart(folder, "Sign", signSize, origin + Vector3.new(sox, 7, soz), Color3.fromRGB(200, 170, 120), Enum.Material.Wood)
	sign.CanCollide = false
	post.CanCollide = false
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 200, 0, 60)
	bb.StudsOffset = Vector3.new(0, 2, 0)
	bb.Adornee = sign
	bb.Parent = sign
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.BackgroundTransparency = 1
	tl.Text = "🌷 " .. player.DisplayName .. "'s Garden 🐾"
	tl.TextScaled = true
	tl.TextColor3 = Color3.fromRGB(60, 40, 20)
	tl.Font = Enum.Font.FredokaOne
	tl.Parent = bb

	end -- if not reusedVisuals (skip duplicate fences/decor when using prebuilt visuals)

	local garden: Garden = { Owner = player, Index = index, Origin = origin, Plots = {}, Folder = folder, ReusedVisuals = reusedVisuals }
	gardens[player.UserId] = garden
	gardenByIndex[index] = garden

	-- floating label shows the owner's name once claimed
	local gl = folder:FindFirstChild("GardenLabel")
	if gl then
		local bbl = gl:FindFirstChildOfClass("BillboardGui")
		local tll = bbl and (bbl :: BillboardGui):FindFirstChildOfClass("TextLabel")
		if tll then (tll :: TextLabel).Text = "🌷 " .. player.DisplayName .. "'s Garden" end
	end
	-- the hold-E prompt is destroyed on claim — it does not stay
	-- v47.1: destroy the invisible holder part too, not just the prompt,
	-- so claim cycles don't orphan parts in the ClaimPrompts folder
	local cp: ProximityPrompt? = claimPrompts[index]
	if cp then pcall(function()
		local holder = (cp :: ProximityPrompt).Parent
		;(cp :: ProximityPrompt):Destroy()
		if holder and holder:IsA("BasePart") then holder:Destroy() end
	end) end
	claimPrompts[index] = nil

	local prof = PD().Get(player)
	for i = 1, (prof.PlotsOwned :: number) do
		createPlotVisual(garden, i)
	end

	GardenManager.RestorePlots(player)

	if Remotes then
		R("GardenInfo"):FireClient(player, index, (prof.PlotsOwned :: number))
	end
	return garden
end

-- claim flow: hold E at a garden's front gate to make it yours
function GardenManager.ClaimGarden(player: Player, index: number): (boolean, string)
	if typeof(index) ~= "number" then return false, "Hmm, that prompt is broken!" end
	if gardens[player.UserId] then return false, "You already have a garden! 🌷" end
	local g = gardenByIndex[index]
	if g then
		local owner = g.Owner
		local name = (owner and owner.Parent) and owner.DisplayName or "someone else"
		return false, "Already claimed by " .. name .. "!"
	end
	assignGardenAt(player, index)
	return true, "Garden " .. (index + 1) .. " claimed! Plant something 🌱"
end

-- Hold-E claim prompt at the FRONT of a garden (by the gate, facing the plaza).
-- Built for every unclaimed garden; destroyed on claim (it does not stay);
-- re-placed when the owner's garden is released.
function GardenManager.EnsureClaimPrompt(index: number)
	if gardenByIndex[index] then return end -- claimed: no prompt here
	local old: ProximityPrompt? = claimPrompts[index]
	if old and old.Parent then return end -- already placed
	claimPrompts[index] = nil
	local origin = GardenManager.GardenOrigin(index)
	-- gate side = the side facing the island center (same math as the fences)
	local gdx, gdz = -origin.X, -origin.Z
	local px, pz: number, number = 0, 31
	if math.abs(gdx) > math.abs(gdz) then
		px, pz = (if gdx > 0 then 41 else -41), 0
	else
		px, pz = 0, (if gdz > 0 then 31 else -31)
	end
	local mb = workspace:FindFirstChild("MapBuilt")
	local folder = mb and (mb :: Instance):FindFirstChild("ClaimPrompts")
	if not folder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = "ClaimPrompts"
		newFolder.Parent = mb or workspace
		folder = newFolder
	end
	local holder = Instance.new("Part")
	holder.Name = "ClaimPrompt_" .. index
	holder.Size = Vector3.new(2, 2, 2)
	holder.Position = origin + Vector3.new(px, 3, pz)
	holder.Anchored = true
	holder.CanCollide = false
	holder.Transparency = 1
	holder.Parent = folder
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Claim"
	pr.ObjectText = "🌱 Garden " .. (index + 1)
	pr.HoldDuration = 0.8
	pr.MaxActivationDistance = 12
	pr.RequiresLineOfSight = false
	pr.Parent = holder
	pr.Triggered:Connect(function(player: Player)
		local ok, msg = GardenManager.ClaimGarden(player, index)
		if Remotes then R("Notify"):FireClient(player, msg, ok and "ok" or "warn") end
	end)
	claimPrompts[index] = pr
end

-- place a hold-E prompt at every unclaimed garden (server startup)
local legacyClaimSwept = false
function GardenManager.WireClaimPrompts()
	-- clean up any leftover click-buttons from the old claim style. Runs only
	-- once: WireClaimPrompts is re-called every 30s and a full workspace
	-- descendant sweep each time is wasted work (4000+ tree parts).
	if not legacyClaimSwept then
		legacyClaimSwept = true
		for _, d in workspace:GetDescendants() do
			if d.Name == "ClaimButton" or d.Name == "ClaimPost" then
				pcall(function() d:Destroy() end)
			end
		end
	end
	for i = 0, 5 do
		GardenManager.EnsureClaimPrompt(i)
	end
end

-- Rebuild saved plot states after assign (called once per join)
function GardenManager.RestorePlots(player: Player)
	local garden = gardens[player.UserId]
	if not garden then return end
	local prof = PD().Get(player)
	local now = os.time()
	for idxStr, saved in (prof.PlotData :: { [string]: any }) do
		local idx = tonumber(idxStr)
		local plot = garden.Plots[idx]
		if plot and saved then
			local s = saved :: { [string]: any }
			if s.Mode == "Egg" and s.EggId then
				plot.State = "Growing"
				plot.Mode = "Egg"
				plot.EggId = s.EggId
				plot.PetId = s.PetId
				plot.Progress = s.Progress or 0
				plot.GrowTime = s.GrowTime or Config.EggGrowTime
			elseif s.Mode == "Pet" and s.Pet then
				plot.State = "Growing"
				plot.Mode = "Pet"
				plot.Pet = s.Pet
				plot.PetId = (s.Pet :: { [string]: any }).PetId
				plot.Mutation = (s.Pet :: { [string]: any }).Mutation
				plot.Progress = s.Progress or 0
				plot.GrowTime = s.GrowTime or 180
			elseif s.Mode == "Pet" and s.RotBugId then
				-- v21: rotted plot (the original pet was consumed by rot)
				plot.State = "Ready"
				plot.Mode = "Pet"
				plot.Pet = nil
				plot.PetId = s.RotBugId
				plot.Mutation = nil
				plot.Progress = 1
				plot.GrowTime = s.GrowTime or 180
				plot.RotReady = true
				plot.RotBugId = s.RotBugId
			else
				continue
			end
			-- v47.6: keep earned harvest modifiers across saves/rejoins —
			-- super-water stacks and a set evolution stone belong to this
			-- growth cycle until harvest consumes them.
			plot.SuperWater = s.SuperWater or 0
			plot.EvoStone = s.EvoStone
			-- offline catch-up (capped)
			local plantT: number = s.PlantTime or now
			local offline = math.min(now - plantT, Config.MaxOfflineProgress)
			if offline > 0 then
				plot.Progress = math.min(1, plot.Progress + offline / plot.GrowTime)
			end
			if plot.Progress >= 1 then
				plot.State = "Ready"
			end
			-- v21: rot state resumes from the save (it only advanced while
			-- online, and offline catch-up above never adds rot time)
			plot.RotOnline = s.RotOnline or 0
			plot.RotWarned = s.RotWarned or false
			plot.Repelled = s.Repelled or false
			if s.RotReady and plot.State == "Ready" then
				-- rotted egg plot (pet-mode rotted plots restore via the
				-- branch above); the bug species id is already the PetId
				plot.RotReady = true
				plot.RotBugId = s.RotBugId
				plot.PetId = s.RotBugId or plot.PetId
				plot.Pet = nil
				plot.Mutation = nil
			end
		end
	end
	local GS: any = require(script.Parent:WaitForChild("GrowthSystem"))
	for _, plot in garden.Plots do
		GS.RefreshVisual(garden, plot)
	end
end

-- Persist plot states into the profile (called by save loop)
function GardenManager.SnapshotPlots(player: Player)
	local garden = gardens[player.UserId]
	if not garden then return end
	local prof = PD().Get(player)
	local data: { [string]: any } = {}
	for i, plot in garden.Plots do
		if plot.State ~= "Empty" then
			data[tostring(i)] = {
				Mode = plot.Mode,
				EggId = plot.EggId,
				Pet = plot.Pet,
				PetId = plot.PetId,
				Progress = plot.Progress,
				GrowTime = plot.GrowTime,
				SuperWater = plot.SuperWater,
				EvoStone = plot.EvoStone,
				PlantTime = os.time(),
				-- v21: rot state (timer only ever advanced while online)
				RotOnline = plot.RotOnline,
				RotWarned = plot.RotWarned,
				RotReady = plot.RotReady,
				RotBugId = plot.RotBugId,
				Repelled = plot.Repelled,
			}
		end
	end
	prof.PlotData = data
end

-- v47: restore a released garden's prebuilt MapBuilt visuals instead of
-- destroying them, so the NEXT claim reuses the same fences/plots/sign.
-- Runtime additions (pet models, sprinklers, plots 5-12, FX) are removed;
-- the original Plot1-4 soil is kept but stripped of runtime FX.
local function RestorePrebuiltVisuals(g: Garden)
	local folder = g.Folder
	-- 1. disconnect the stored soil ClickDetector connections so a re-claim
	--    doesn't double-fire OnPlotClicked on the same detector
	for _, plot in g.Plots do
		if plot.ClickConn then
			pcall(function() (plot.ClickConn :: RBXScriptConnection):Disconnect() end)
			plot.ClickConn = nil
		end
	end
	-- 2. remove everything gameplay added at runtime (but keep the garden's
	--    own floating label — step 3 resets its text)
	local labelAnchor = folder:FindFirstChild("GardenLabel")
	for _, d in folder:GetDescendants() do
		if labelAnchor and (d == labelAnchor or d:IsDescendantOf(labelAnchor)) then
			continue
		end
		if d:IsA("Model") then
			-- pet models + sprinkler models
			pcall(function() d:Destroy() end)
		elseif d:IsA("BillboardGui") or d:IsA("ParticleEmitter") then
			-- ready billboards, rot clouds/flies, repellent sheen
			pcall(function() d:Destroy() end)
		end
	end
	for _, d in folder:GetChildren() do
		-- runtime-added plots beyond the 4 prebuilt ones (+ their rims)
		local num = tonumber(string.match(d.Name, "^Plot(%d+)$") or string.match(d.Name, "^PlotRim(%d+)$") or "")
		if num and num > 4 then
			pcall(function() d:Destroy() end)
		end
	end
	-- 3. reset the floating label to the unclaimed text
	local gl = folder:FindFirstChild("GardenLabel")
	if gl then
		local bbl = gl:FindFirstChildOfClass("BillboardGui")
		local tll = bbl and (bbl :: BillboardGui):FindFirstChildOfClass("TextLabel")
		if tll then (tll :: TextLabel).Text = "🌱 Garden " .. (g.Index + 1) end
	end
	-- 4. rename back + reparent under MapBuilt so the next claim finds it
	folder.Name = "GardenVis_" .. g.Index
	local mb = workspace:FindFirstChild("MapBuilt")
	if mb then
		folder.Parent = mb
	else
		folder.Parent = workspace
	end
end

function GardenManager.RemoveGarden(player: Player)
	local g = gardens[player.UserId]
	if g then
		GardenManager.SnapshotPlots(player)
		if g.ReusedVisuals then
			-- v47: prebuilt visuals survive for the next claim
			RestorePrebuiltVisuals(g)
		else
			g.Folder:Destroy()
		end
		gardens[player.UserId] = nil
		gardenByIndex[g.Index] = nil
		-- garden freed up: re-place the hold-E prompt at its gate
		GardenManager.EnsureClaimPrompt(g.Index)
	end
end

-- ---- actions ---------------------------------------------------------------
function GardenManager.OnPlotClicked(player: Player, garden: Garden, plot: Plot)
	local GrowthSystem: any = require(script.Parent:WaitForChild("GrowthSystem"))
	local isOwner = (player == garden.Owner)
	-- v21: armed pest-repellent spray takes priority over the normal click action
	local sess = (PD().Get(player)._session :: { [string]: any })
	if sess.ArmedSpray == true then
		sess.ArmedSpray = false -- one-shot: spraying arms for a single tap
		if Remotes then R("SprayDone"):FireClient(player) end -- v21: disarm the client button
		if not isOwner then
			if Remotes then R("Notify"):FireClient(player, "You can only spray your own plots! 🧴", "warn") end
			return
		end
		if plot.State == "Empty" then
			if Remotes then R("Notify"):FireClient(player, "Spray a plot that's growing or ready! 🧴", "warn") end
			return
		end
		local ok, msg = GardenManager.SprayRepellent(player, garden, plot)
		if Remotes then R("Notify"):FireClient(player, msg, ok and "ok" or "warn") end
		return
	end
	-- v24: armed evolution stone takes priority over the normal click action.
	-- The player picked a stone in the 🪨 Stones panel; tapping one of their
	-- growing/ready plots sets it there (server-validated). Tapping the plot
	-- that already has this stone armed removes it (toggle off).
	if sess.ArmedStone then
		local stoneId: string = sess.ArmedStone
		sess.ArmedStone = nil -- one-shot: setting arms for a single tap
		if Remotes then R("StoneDone"):FireClient(player) end -- v24: disarm the client button
		if not isOwner then
			if Remotes then R("Notify"):FireClient(player, "You can only set stones on your own plots! 🪨", "warn") end
			return
		end
		if plot.EvoStone == stoneId then
			plot.EvoStone = nil
			if Remotes then R("Notify"):FireClient(player, "🪨 Stone removed from Plot " .. plot.Index .. ".", "ok") end
			return
		end
		local ok, msg = GardenManager.SetEvoStone(player, garden, plot, stoneId)
		if Remotes then R("Notify"):FireClient(player, msg, ok and "ok" or "warn") end
		return
	end
	if plot.State == "Empty" then
		if not isOwner then return end
		-- plant the selected seed (only Pet Eggs exist)
		local prof = PD().Get(player)
		local seed: string = (prof._session :: { [string]: any }).SelectedSeed or "PetEgg"
		local ok, msg = GardenManager.PlantEgg(player, plot.Index, seed)
		if not ok and Remotes then R("Notify"):FireClient(player, msg, "warn") end
	elseif plot.State == "Growing" then
		local key = GardenManager.PlotKey(garden.Owner.UserId, plot.Index)
		local ok, msg = GardenManager.WaterPlot(player, key)
		if Remotes then R("Notify"):FireClient(player, msg, ok and "ok" or "warn") end
	elseif plot.State == "Ready" then
		if not isOwner then
			if Remotes then R("Notify"):FireClient(player, "Only the owner can harvest this!", "warn") end
			return
		end
		local harvested = GrowthSystem.HarvestPlot(player, plot.Index)
		-- v47.6: celebrate only after the harvest actually clears the plot
		-- (a rate-limited/failed harvest leaves it Ready and gets no burst).
		if harvested ~= false and plot.State ~= "Ready" then
			-- v47.5: golden harvest burst — the payoff moment should feel rewarding
			local hburst = Instance.new("ParticleEmitter")
			hburst.Color = ColorSequence.new(Color3.fromRGB(255, 215, 90), Color3.fromRGB(255, 245, 180))
			hburst.Size = NumberSequence.new(0.55)
			hburst.Rate = 0
			hburst.Lifetime = NumberRange.new(0.8, 1.4)
			hburst.Speed = NumberRange.new(5, 10)
			hburst.Parent = plot.Part
			hburst:Emit(36)
			task.delay(2, function() hburst:Destroy() end)
		end
	end
end

-- Plant a Pet Egg (consumes the egg). Hatches a random basic pet.
function GardenManager.PlantEgg(player: Player, index: number, eggId: string): (boolean, string)
	if not PD().CheckRate(player, "Default") then return false, "Too fast!" end
	local garden = gardens[player.UserId]
	if not garden then return false, "No garden!" end
	local plot = garden.Plots[index]
	if not plot then return false, "Buy that plot first!" end
	if plot.State ~= "Empty" then return false, "Plot is busy!" end
	if eggId ~= "PetEgg" then return false, "Unknown egg!" end
	if not PD().RemoveSeed(player, eggId) then return false, "No Pet Eggs! Buy some in the shop." end

	plot.State = "Growing"
	plot.Mode = "Egg"
	plot.EggId = eggId
	plot.Pet = nil
	plot.PetId = PetData.RollPet()
	plot.Mutation = nil
	plot.Progress = 0
	plot.GrowTime = Config.EggGrowTime
	plot.WaterUntil = 0
	plot.SuperWater = 0
	-- v21: fresh cycle, no rot state
	plot.RotOnline = 0
	plot.RotWarned = false
	plot.RotReady = false
	plot.RotBugId = nil
	plot.Repelled = false
	plot.EvoStone = nil -- v24: fresh cycle, no armed evolution stone

	local GrowthSystem: any = require(script.Parent:WaitForChild("GrowthSystem"))
	GrowthSystem.RefreshVisual(garden, plot)
	-- v47.5: soil burst so planting feels snappy (matches the WaterPlot pattern)
	local burst = Instance.new("ParticleEmitter")
	burst.Color = ColorSequence.new(Color3.fromRGB(140, 100, 70), Color3.fromRGB(110, 180, 90))
	burst.Size = NumberSequence.new(0.5)
	burst.Rate = 0
	burst.Lifetime = NumberRange.new(0.6, 1.1)
	burst.Speed = NumberRange.new(4, 9)
	burst.Parent = plot.Part
	burst:Emit(24)
	task.delay(2, function() burst:Destroy() end)
	if Remotes then R("Notify"):FireClient(player, "Planted a Pet Egg 🥚 (something's inside...)", "ok") end
	return true, "Planted!"
end

-- Plant one of the player's pets to grow it toward evolution.
-- The pet is SAFE: it lives on the plot and always comes back on harvest.
local function canEvolve(rec: { [string]: any }): boolean
	local EvoSys: any = require(script.Parent:WaitForChild("EvolutionSystem"))
	return EvoSys.CanEvolve(rec.PetId)
end

function GardenManager.PlantPet(player: Player, uid: string): (boolean, string)
	if not PD().CheckRate(player, "Default") then return false, "Too fast!" end
	local garden = gardens[player.UserId]
	if not garden then return false, "No garden!" end
	local rec = PD().GetPet(player, uid)
	if not rec then return false, "Pet not found!" end
	if not canEvolve(rec) then
		return false, "That pet can't evolve further!"
	end
	-- first empty plot
	local plot: Plot? = nil
	for i = 1, (PD().Get(player).PlotsOwned :: number) do
		local p = garden.Plots[i]
		if p and p.State == "Empty" then plot = p break end
	end
	if not plot then return false, "No empty plots! Buy more in the shop." end

	PD().RemovePet(player, uid) -- moves to the plot (team slots cleared there if needed)
	plot.State = "Growing"
	plot.Mode = "Pet"
	plot.EggId = nil
	plot.Pet = rec
	plot.PetId = (rec :: { [string]: any }).PetId
	plot.Mutation = (rec :: { [string]: any }).Mutation
	plot.Progress = 0
	local def = (PetData.PETS :: { [string]: any })[(rec :: { [string]: any }).PetId]
	local stage: number = (def and def.Stage) or 1
	plot.GrowTime = (Config.PetGrowTime :: { [number]: number })[stage] or 180
	plot.WaterUntil = 0
	plot.SuperWater = 0
	-- v21: fresh cycle, no rot state
	plot.RotOnline = 0
	plot.RotWarned = false
	plot.RotReady = false
	plot.RotBugId = nil
	plot.Repelled = false
	plot.EvoStone = nil -- v24: fresh cycle, no armed evolution stone

	local GrowthSystem: any = require(script.Parent:WaitForChild("GrowthSystem"))
	GrowthSystem.RefreshVisual(garden, plot)
	local petName: string = (def and def.Name) or "pet"
	if Remotes then
		R("Notify"):FireClient(player, "🌱 " .. petName .. " is growing! Harvest for a chance to evolve — it's safe.", "ok")
	end
	local FS: any = require(script.Parent:WaitForChild("FollowerSystem"))
	FS.Refresh(player)
	return true, "Growing!"
end

-- v24: set an evolution stone on a plot. Fully server-authoritative:
-- ownership, plot state, species match, stone inventory, and the branch's
-- event gate are all validated here. The stone is NOT consumed yet — only a
-- successful forced evolution at harvest consumes it.
function GardenManager.SetEvoStone(player: Player, garden: Garden, plot: Plot, stoneId: string): (boolean, string)
	if not PD().CheckRate(player, "Default") then return false, "Too fast!" end
	local sdef = (PetData.EVO_STONES :: { [string]: any })[stoneId]
	if not sdef then return false, "Unknown stone!" end
	if plot.State ~= "Growing" and plot.State ~= "Ready" then
		return false, "Set the stone on a growing or ready plot! 🪨"
	end
	if plot.Mode ~= "Pet" or not plot.PetId then
		return false, "Stones only work on growing pets, not eggs! 🪨"
	end
	local species: string = plot.PetId
	if (sdef.From :: string) ~= species then
		local needName: string = (((PetData.PETS :: { [string]: any })[sdef.From] or {}).Name :: string) or (sdef.From :: string)
		return false, (sdef.Name :: string) .. " only works on " .. needName .. "! 🪨"
	end
	local EvoSys: any = require(script.Parent:WaitForChild("EvolutionSystem"))
	local branches = (PetData.EVOLUTIONS :: { [string]: any })[species]
	if not branches or #branches <= 1 then
		return false, "That pet has only one evolution path — no stone needed! 🪨"
	end
	if not EvoSys.BranchEligible(species, (sdef.To :: string)) then
		return false, "That branch needs its event first! " .. (sdef.Desc :: string) .. " 🪨"
	end
	local prof = PD().Get(player)
	local have: number = ((prof.Items :: { [string]: number })[stoneId] or 0)
	if have < 1 then return false, "You don't have that stone! 🪨" end
	plot.EvoStone = stoneId
	local petName: string = (((PetData.PETS :: { [string]: any })[species] or {}).Name :: string) or species
	local branchName: string = (((PetData.PETS :: { [string]: any })[sdef.To] or {}).Name :: string) or (sdef.To :: string)
	pcall(function()
		local QS: any = require(script.Parent:WaitForChild("QuestSystem"))
		QS.Progress(player, "stone", 1)
	end)
	return true, "🪨 " .. (sdef.Name :: string) .. " set on Plot " .. plot.Index
		.. " — " .. petName .. " will evolve into " .. branchName .. "!"
end

function GardenManager.WaterPlot(player: Player, plotKey: string): (boolean, string)
	if not PD().CheckRate(player, "Default") then return false, "Too fast!" end
	local userId, index = GardenManager.ParseKey(plotKey)
	if not userId or not index then return false, "Bad plot!" end
	local garden = gardens[userId]
	local plot = garden and garden.Plots[index]
	if not plot or plot.State ~= "Growing" then return false, "Nothing to water!" end
	local now = os.clock()
	if now < plot.WaterUntil then
		return false, "Watered recently — wait a bit!"
	end
	local isOwner = (player.UserId == userId)
	local helperNote = ""
	if isOwner then
		plot.WaterUntil = now + Config.WaterSelfCooldown
		local boost = (Config.WaterSelfBoost :: number)
		if plot.PetId then -- v48: Dew Touch trait: watering its plot gives +25% progress
			local petDef = (PetData.PETS :: { [string]: any })[plot.PetId]
			if petDef and (petDef.Trait :: string?) == "DewTouch" then boost *= 1.25 end
		end
		plot.Progress = math.min(0.999, plot.Progress + boost)
	else
		-- v20 co-op watering: one help per growth stage per helper (anti-farm),
		-- helper coin rewards capped daily, +1 follower bond per help (capped).
		local stage = if plot.Progress < 0.33 then 0 elseif plot.Progress < 0.66 then 1 else 2
		local helped = (plot :: { [string]: any }).HelpedBy :: { [number]: number }?
		if not helped then
			helped = {}
			;(plot :: { [string]: any }).HelpedBy = helped
		end
		if (helped :: { [number]: number })[player.UserId] == stage then
			return false, "You already helped this plot — come back when it's grown more! 💧"
		end
		;(helped :: { [number]: number })[player.UserId] = stage
		plot.WaterUntil = now + Config.WaterOtherCooldown
		plot.Progress = math.min(0.999, plot.Progress + Config.WaterOtherBoost)
		local tipBase = 100
		if plot.PetId then
			local petDef = (PetData.PETS :: { [string]: any })[plot.PetId]
			tipBase = (petDef and petDef.Value) or 100
		end
		local tip = math.max(Config.WaterTipMin, math.floor(tipBase * Config.WaterTipRate))
		-- daily helper coin cap
		local prof = PD().Get(player)
		local day = os.date("%Y-%m-%d") :: string
		local hw = (prof.HelperWater :: { [string]: any }?)
		if not hw or (hw.Day :: string) ~= day then
			hw = { Day = day, Coins = 0, Bond = 0 }
			prof.HelperWater = hw
		end
		local room = math.max(0, (Config.HelperWaterDailyCoins :: number) - (hw.Coins :: number))
		local grant = math.min(tip, room)
		if grant > 0 then
			PD().AddCoins(player, grant, "water_tip")
			hw.Coins = (hw.Coins :: number) + grant
		end
		prof.Stats.WatersGiven += 1
		-- +1 follower bond per help, daily capped
		local FS: any = require(script.Parent:WaitForChild("FollowerSystem"))
		local bondMsg = ""
		if (hw.Bond :: number) < (Config.HelperWaterDailyBond :: number) then
			if FS.GrantBond(player, 1) then
				hw.Bond = (hw.Bond :: number) + 1
				bondMsg = " 💕 +1 bond"
			end
		end
		local owner = Players:GetPlayerByUserId(userId)
		if owner and Remotes then
			R("Notify"):FireClient(owner, player.DisplayName .. " watered your plot! 💧", "ok")
		end
		-- pink hearts burst on the helped plot
		local hearts = Instance.new("ParticleEmitter")
		hearts.Color = ColorSequence.new(Color3.fromRGB(255, 130, 180))
		hearts.Size = NumberSequence.new(0.55)
		hearts.Rate = 0
		hearts.Lifetime = NumberRange.new(0.8, 1.4)
		hearts.Speed = NumberRange.new(3, 7)
		hearts.Parent = plot.Part
		hearts:Emit(16)
		task.delay(2, function() hearts:Destroy() end)
		pcall(function() QS().Progress(player, "helpwater", 1) end)
		helperNote = if grant < tip
			then " (daily rewards maxed — still helped!)"
			else bondMsg
	end
	local GrowthSystem: any = require(script.Parent:WaitForChild("GrowthSystem"))
	GrowthSystem.RefreshVisual(garden, plot)
	local splash = Instance.new("ParticleEmitter")
	splash.Color = ColorSequence.new(Color3.fromRGB(120, 180, 255))
	splash.Size = NumberSequence.new(0.5)
	splash.Rate = 0
	splash.Lifetime = NumberRange.new(0.5, 1)
	splash.Speed = NumberRange.new(4, 8)
	splash.Parent = plot.Part
	splash:Emit(20)
	task.delay(2, function() splash:Destroy() end)
	-- ✨ SUPER WATER: lucky crit, stacks on the plot until harvest
	local msg: string = isOwner and "Watered! 💧 +10% growth" or "Watered! 💧 Tip earned!" .. helperNote
	if math.random() < Config.SuperWaterChance then
		plot.SuperWater = (plot.SuperWater or 0) + 1
		local gold = Instance.new("ParticleEmitter")
		gold.Color = ColorSequence.new(Color3.fromRGB(255, 215, 90))
		gold.Size = NumberSequence.new(0.6)
		gold.Rate = 0
		gold.Lifetime = NumberRange.new(0.8, 1.4)
		gold.Speed = NumberRange.new(5, 10)
		gold.Parent = plot.Part
		gold:Emit(30)
		task.delay(2, function() gold:Destroy() end)
		msg = "✨ SUPER WATER! ✨ (" .. plot.SuperWater .. "x) Evo & mutation luck up!"
	end
	pcall(function() QS().Progress(player, "water", 1) end)
	return true, msg
end

-- ---- v21: pest repellent ----------------------------------------------------
-- Toggle the one-shot spray tool. The client calls this when the player taps
-- the 🧴 Spray button; the next plot they tap gets sprayed instead of watered.
function GardenManager.ArmSpray(player: Player, armed: boolean): (boolean, string)
	local sess = (PD().Get(player)._session :: { [string]: any })
	if armed then
		local have: number = ((PD().Get(player).Items :: { [string]: number }).PestRepellent or 0)
		if have < 1 then return false, "No 🧴 Pest Repellent! Buy some in the 🥚 Shop." end
		sess.ArmedSpray = true
		return true, "🧴 Spray armed — tap one of your growing/ready plots!"
	end
	sess.ArmedSpray = false
	return true, "🧴 Spray put away."
end

-- ---- v24: evolution stones --------------------------------------------------
-- Arm a stone: the client calls this when the player taps Set on a stone in
-- the 🪨 Stones panel; the next plot they tap gets the stone (validated in
-- SetEvoStone). Passing nil disarms.
function GardenManager.ArmStone(player: Player, stoneId: string?): (boolean, string)
	local sess = (PD().Get(player)._session :: { [string]: any })
	if stoneId and stoneId ~= "" then
		local sdef = (PetData.EVO_STONES :: { [string]: any })[stoneId]
		if not sdef then return false, "Unknown stone!" end
		local have: number = ((PD().Get(player).Items :: { [string]: number })[stoneId] or 0)
		if have < 1 then return false, "No " .. ((sdef :: { [string]: any }).Name :: string) .. "! Buy one in the 🥚 Shop." end
		sess.ArmedStone = stoneId
		return true, "🪨 " .. ((sdef :: { [string]: any }).Name :: string) .. " armed — tap one of your growing/ready plots!"
	end
	sess.ArmedStone = nil
	return true, "🪨 Stone put away."
end

-- Spray pest repellent on a plot (consumes 1). A repelled plot CANNOT rot for
-- its entire current growth cycle — harvest clears it. Server-authoritative:
-- ownership, state, and inventory are all re-validated here.
function GardenManager.SprayRepellent(player: Player, garden: Garden, plot: Plot): (boolean, string)
	if not PD().CheckRate(player, "Default") then return false, "Too fast!" end
	if plot.Repelled then return false, "That plot is already protected! 🧴✨" end
	if plot.RotReady then return false, "Too late — that plot already rotted! 🪲" end
	if not PD().RemoveItem(player, "PestRepellent") then
		return false, "No 🧴 Pest Repellent left! Buy more in the 🥚 Shop."
	end
	plot.Repelled = true
	plot.RotOnline = 0 -- a fresh shield: any accrued rot time is wiped
	plot.RotWarned = false
	-- rebuild visuals so the protective sheen appears
	local GrowthSystem: any = require(script.Parent:WaitForChild("GrowthSystem"))
	GrowthSystem.RefreshVisual(garden, plot)
	if Remotes then
		R("Notify"):FireClient(player, "🧴✨ Protected! This plot can't rot until harvest.", "ok")
	end
	pcall(function() QS().Progress(player, "repel", 1) end)
	return true, "Protected! 🧴✨"
end

function GardenManager.BuyPlot(player: Player): (boolean, string)
	if not PD().CheckRate(player, "Buy") then return false, "Too fast!" end
	local prof = PD().Get(player)
	local owned: number = prof.PlotsOwned
	if owned >= Config.MaxPlots then return false, "Max plots reached!" end
	local price: number = (Config.PlotPrices :: { number })[owned - Config.StartPlots + 1]
	if not price then return false, "Max plots reached!" end
	if not PD().SpendCoins(player, price) then return false, "Need " .. price .. " coins!" end
	prof.PlotsOwned = owned + 1
	local garden = gardens[player.UserId]
	if garden then
		createPlotVisual(garden, owned + 1)
		if Remotes then R("GardenInfo"):FireClient(player, garden.Index, owned + 1) end
	end
	PD().Sync(player)
	return true, "New plot! 🟫 (" .. (owned + 1) .. "/" .. Config.MaxPlots .. ")"
end

-- Growth rate multiplier: events + night + growth tonic
function GardenManager.GrowthRate(garden: Garden, plot: Plot?): number
	local rate = 1
	local prof = PD().Get(garden.Owner)
	if prof.GoldenCan then rate *= 1.25 end -- full-collection reward
	if (prof.TonicUntil :: number) > os.time() then
		rate *= 1 + Config.TonicBoost
	end
	if FS().Has(garden.Owner, "GrowthSurge") then -- v22: ⛲ fountain blessing +50%
		rate *= 1.5
	end
	local ev = ES().CurrentEvent()
	if ev == "Rain" then rate *= 2 end
	if ev == "Rainbow" then rate *= (Config.RainbowGrowthMult :: number) end -- 🌈 +25% growth
	if ES().IsNight() and plot and plot.PetId then -- 🌙 night phase: nocturnal pets grow 2x
		local def = (PetData.PETS :: { [string]: any })[plot.PetId]
		if def and (def.Nocturnal :: boolean) then rate *= 2 end
	end
	if plot and plot.PetId then -- v48: Claude batch garden traits
		local def = (PetData.PETS :: { [string]: any })[plot.PetId]
		local trait = def and (def.Trait :: string?)
		if trait == "QuickSprout" then rate *= 1.10 end -- +10% grow speed on plot
		if trait == "RainLover" and ev == "Rain" then rate *= 1.25 end -- +25% during Rain
		if trait == "SunChaser" and ev == "Sunny" then rate *= 1.25 end -- +25% during Sunny
	end
	return rate
end

-- Sprinkler tick: auto-waters every growing plot like a normal self-watering,
-- but NEVER rolls super-water crits and doesn't count toward quests.
function GardenManager.SprinklerTick(garden: Garden)
	local GrowthSystem: any = require(script.Parent:WaitForChild("GrowthSystem"))
	local watered = 0
	for _, plot in garden.Plots do
		if plot.State == "Growing" then
			plot.Progress = math.min(0.999, plot.Progress + (Config.SprinklerBoost :: number))
			GrowthSystem.RefreshVisual(garden, plot)
			watered += 1
		end
	end
	if watered == 0 then return end
	-- spray burst from the sprinkler post
	local sm = (garden :: { [string]: any }).SprinklerModel
	if sm and (sm :: Model).Parent then
		local head = (sm :: Model):FindFirstChild("Head", true)
		if head then
			local spray = (head :: BasePart):FindFirstChild("Spray")
			if spray and spray:IsA("ParticleEmitter") then
				local emitter = spray :: ParticleEmitter
				emitter:Emit(40)
			end
		end
	end
	local owner = garden.Owner
	if owner and Remotes then
		R("Notify"):FireClient(owner, "💦 Sprinkler watered " .. watered .. " plot(s)!", "ok")
	end
end

-- Jarvis health endpoint: snapshot of garden claims + plot states for the auto-reporter
function GardenManager.GetHealth(): { { index: number, owner: string, plots: number, growing: number, ready: number } }
	local out: { { index: number, owner: string, plots: number, growing: number, ready: number } } = {}
	for _, g in pairs(gardens) do
		local plots, growing, ready = 0, 0, 0
		for _, plot in pairs(g.Plots) do
			plots += 1
			if plot.State == "Growing" then
				growing += 1
			elseif plot.State == "Ready" then
				ready += 1
			end
		end
		table.insert(out, {
			index = g.Index,
			owner = (g.Owner and g.Owner.Parent) and g.Owner.DisplayName or "?",
			plots = plots,
			growing = growing,
			ready = ready,
		})
	end
	return out
end

return GardenManager
