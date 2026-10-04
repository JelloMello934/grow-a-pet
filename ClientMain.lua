--!strict
-- ClientMain (LocalScript -> StarterPlayer > StarterPlayerScripts > ClientMain)
-- Builds the ENTIRE HUD in code: coins, shop (eggs + potions), pet bag,
-- battle team + follower, fusion, collection book, visit/battle/trade,
-- leaderboards, daily rewards, event banner, battle + trade windows.
-- All economy stays server-side; this only displays and fires remotes.

-- Jarvis error reporting: Studio Play sessions send error text back to Jarvis automatically
pcall(function()
	require(game:GetService("ReplicatedStorage"):WaitForChild("JarvisReporter", 10)).start("client")
end)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PetData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PetData"))
local Mutations = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Mutations"))
local TypeChart = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TypeChart"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local function R(name: string): RemoteEvent
	return (remotes:WaitForChild(name) :: RemoteEvent)
end

-- ---- state ---------------------------------------------------------------------
local coins = 0
local eggCount = 0
local items: { [string]: number } = {}
local buffs: { [string]: any } = { TonicLeft = 0, EvoBoost = false, Rod = nil, Shovel = false, FossilFrags = 0 } -- v14: rod/shovel/fragments
local inventory: { { [string]: any } } = {}
local collection: { [string]: any } = {}
local teamSlots: { { [string]: any }? } = {}
local followerUid: string? = nil
local starterPetId: string? = nil
local shopStock: { { [string]: any } } = {}
local eventId = "Sunny"
local eventEndsAt = 0
local boards: { [string]: any } = {}
local boardLabels: { [string]: string } = {}
local dailyDay, dailyCan, dailyStreak = 1, false, 0
local visitList: { { [string]: any } } = {}
local settings: { [string]: any } = { AutoSell = false }
local plotsOwned = 3

-- battle / trade local state
local battleId: number? = nil
local battleView: { [string]: any }? = nil
local tradeId: number? = nil
local tradeView: { [string]: any }? = nil
local tradeOfferUid: string? = nil
local tradeOfferCoins = 0
-- forward-declared (assigned later): healing-potion pet picker
local openHealPicker: (() -> ())? = nil
-- forward-declared (assigned later): rename modal opener
local openRename: ((string, string) -> ())? = nil
local openSkinPicker: ((string, string?) -> ())? = nil -- v12: custom pet skins
local ownedSkins: { string } = {} -- v12: owned skin ids, pushed by the server

-- ---- UI helpers ------------------------------------------------------------------
-- v46 UI fix: self-heal — destroy any pre-existing HUD copies first
-- (re-pasting the script used to stack duplicate GUIs, doubling every button).
do
	local pg = player:WaitForChild("PlayerGui")
	for _, ch in pg:GetChildren() do
		if ch.Name == "GrowAPetHUD" then
			pcall(function() ch:Destroy() end)
		end
	end
end
local gui = Instance.new("ScreenGui")
gui.Name = "GrowAPetHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
-- v46 UI fix: Global ZIndexBehavior so the popup/menu/option ZIndexes below
-- are compared across the whole GUI. With the default Sibling behavior the
-- option buttons inside the popup could end up painted behind other layers
-- (popup opened sized-but-empty).
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(obj: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = obj
end

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, textSize: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = textSize
	l.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	l.Font = Enum.Font.FredokaOne
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, size: UDim2, pos: UDim2, color: Color3?): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color or Color3.fromRGB(70, 130, 220)
	b.Text = text
	b.TextSize = 16
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = Enum.Font.FredokaOne
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 8)
	return b
end

local function typeColor(t: string): Color3
	return (TypeChart.COLORS :: { [string]: Color3 })[t] or Color3.fromRGB(160, 160, 160)
end

local function rarityColor(r: string): Color3
	return (Config.RarityColor :: { [string]: Color3 })[r] or Color3.fromRGB(200, 200, 200)
end

local function petDisplayValue(rec: { [string]: any }): number
	local base = PetData.GetValue(rec.PetId)
	local mm = Mutations.ValueMult(rec.Mutation) -- v14 fix: was reading a nonexistent MULT field (always errored)
	local val = math.floor(base * mm * (1.25 ^ (rec.Stars or 0)))
	if rec.Titan then val = math.floor(val * (Config.TitanValueMult :: number)) end -- v12: Titans sell for +50%
	return val
end

local function petTitle(rec: { [string]: any }): string
	local pdef = (PetData.PETS :: { [string]: any })[rec.PetId]
	local species = (pdef and pdef.Name) or "???"
	local name = PetData.PetName(rec)
	local mut = Mutations.DisplayName(rec.Mutation)
	local stars = string.rep("⭐", math.min(rec.Stars or 0, 5))
	local t = if name ~= species then name .. " (" .. species .. ")" else species
	if mut ~= "" then t ..= " (" .. mut .. ")" end
	if stars ~= "" then t ..= " " .. stars end
	if rec.Shiny then t = "✨ " .. t end -- 1-in-4000 prestige flex
	if rec.Titan then t = "👑 " .. t end -- v12: Titan pets show their crown
	local bond = rec.Bond or 0
	if bond > 0 then t ..= " 💕" .. bond end -- petting bond
	local skinDef = rec.Skin and (Config.Skins :: { [string]: any })[rec.Skin] or nil
	if skinDef then t ..= " 🎨" .. (skinDef.Name :: string) end -- v12: custom skin
	local at = (pdef and pdef.ActiveTime) or "Any" -- day/night pet indicator
	if at == "Day" then t ..= " ☀️" elseif at == "Night" then t ..= " 🌙" end
	return t
end

-- ---- panels ------------------------------------------------------------------------
local panels: { [string]: Frame } = {}
local openPanel: string? = nil

local function closePanels()
	openPanel = nil
	for _, f in panels do f.Visible = false end
end

local function makePanel(name: string, title: string, warm: boolean?): (Frame, ScrollingFrame)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.new(0.94, 0, 0.78, 0)
	f.Position = UDim2.new(0.03, 0, 0.1, 0)
	f.BackgroundColor3 = if warm then Color3.fromRGB(58, 42, 30) else Color3.fromRGB(30, 32, 54)
	f.BorderSizePixel = 0
	f.Visible = false
	f.Parent = gui
	corner(f, 12)
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 44)
	-- v36: every panel gets its own vivid header color
	local titleCols = {
		Shop = Color3.fromRGB(255, 170, 30), Bag = Color3.fromRGB(46, 204, 113),
		Team = Color3.fromRGB(235, 95, 70), Fuse = Color3.fromRGB(170, 90, 255),
		Dex = Color3.fromRGB(20, 190, 190), Boards = Color3.fromRGB(250, 200, 40),
		Visit = Color3.fromRGB(255, 110, 170), Daily = Color3.fromRGB(150, 220, 60),
		Settings = Color3.fromRGB(110, 130, 180), Spin = Color3.fromRGB(255, 80, 200),
		Auction = Color3.fromRGB(90, 100, 220), Quests = Color3.fromRGB(60, 180, 255),
		Stones = Color3.fromRGB(220, 140, 60), Daycare = Color3.fromRGB(255, 160, 120),
		Fountain = Color3.fromRGB(80, 170, 255),
	}
	titleBar.BackgroundColor3 = titleCols[name]
		or (if warm then Color3.fromRGB(90, 68, 44) else Color3.fromRGB(48, 48, 68))
	titleBar.BorderSizePixel = 0
	titleBar.Parent = f
	corner(titleBar, 12)
	label(titleBar, title, UDim2.new(1, -60, 1, 0), UDim2.new(0, 12, 0, 0), 20, Color3.fromRGB(255, 255, 255))
	local x = button(titleBar, "X", UDim2.new(0, 44, 0, 36), UDim2.new(1, -50, 0, 4), Color3.fromRGB(200, 70, 70))
	x.TextSize = 18
	x.ZIndex = 5 -- v47: keep the X above the title bar
	x.MouseButton1Click:Connect(closePanels)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -16, 1, -60)
	scroll.Position = UDim2.new(0, 8, 0, 52)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = f
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	panels[name] = f
	return f, scroll
end

local function togglePanel(name: string)
	if openPanel == name then
		closePanels()
	else
		closePanels()
		if closeCat then closeCat() end -- v47: popup can't linger above the new panel
		openPanel = name
		local f = panels[name]
		if f then f.Visible = true end
	end
end

-- ---- ZIndex ladder (Global ZIndexBehavior: descendants compete with non-descendants)
-- v47 documented: 1 = HUD + all side panels + battle/trade frames (default)
--   50 = modal dim scrims (rename/skin) | 51-52 = their dialogs
--   55 = trading-booth frame | 56 = booth pet picker
--   60-63 = bottom-bar category popup (60) + its buttons
--   65 = modal pet pickers (battle fighter / trade offer / potion heal)
--   70 = toasts, announcements, invites (yes/no prompt)
--   200 = sky-flash overlay (sky system draws its own)

-- ---- toast notifications + announcements ---------------------------------------------
local toastHolder = Instance.new("Frame")
toastHolder.Size = UDim2.new(0.9, 0, 0, 200) -- v47: scale so narrow phones don't push toasts off-screen
toastHolder.Position = UDim2.new(0.05, 0, 0, 70)
local toastCap = Instance.new("UISizeConstraint") -- v47
toastCap.MaxSize = Vector2.new(340, 200)
toastCap.Parent = toastHolder
toastHolder.BackgroundTransparency = 1
toastHolder.ZIndex = 70 -- v47: toasts stay visible above open panels
toastHolder.Parent = gui
local toastLayout = Instance.new("UIListLayout")
toastLayout.Padding = UDim.new(0, 6)
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Top
toastLayout.Parent = toastHolder

local function toast(msg: string, kind: string?)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 0, 44)
	t.BackgroundColor3 = if kind == "warn" then Color3.fromRGB(150, 60, 60)
		elseif kind == "ok" then Color3.fromRGB(50, 130, 70)
		elseif kind == "shiny" then Color3.fromRGB(190, 130, 20) -- gold for 1-in-4000 moments
		else Color3.fromRGB(45, 45, 60)
	t.Text = msg
	t.TextSize = 14
	t.TextColor3 = Color3.fromRGB(255, 255, 255)
	t.Font = Enum.Font.FredokaOne
	t.TextWrapped = true
	t.Parent = toastHolder
	corner(t, 8)
	task.delay(4, function()
		for _ = 1, 10 do t.BackgroundTransparency += 0.1 t.TextTransparency += 0.1 task.wait(0.05) end
		t:Destroy()
	end)
end

local announceFrame = Instance.new("Frame")
announceFrame.Size = UDim2.new(0.9, 0, 0, 90)
announceFrame.Position = UDim2.new(0.05, 0, 0.18, 0)
announceFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
announceFrame.Visible = false
announceFrame.ZIndex = 70 -- v47: announcements stay visible above open panels
announceFrame.Parent = gui
corner(announceFrame, 14)
local announceTitle = label(announceFrame, "", UDim2.new(1, -20, 0, 40), UDim2.new(0, 10, 0, 6), 26, Color3.fromRGB(255, 220, 120))
announceTitle.TextXAlignment = Enum.TextXAlignment.Center
local announceBody = label(announceFrame, "", UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 0, 46), 16)
announceBody.TextXAlignment = Enum.TextXAlignment.Center
announceBody.TextWrapped = true
announceTitle.ZIndex = 71 -- v47.9: labels must render ABOVE the opaque announceFrame (ZIndex 70), or announcements show as an empty black bar
announceBody.ZIndex = 71

local function announce(title: string, body: string)
	announceTitle.Text = title
	announceBody.Text = body
	announceFrame.Visible = true
	task.delay(6, function() announceFrame.Visible = false end)
end

-- ---- sunny side panel + bottom bar ---------------------------------------------------
-- The old top bar sat under the Roblox menu icon + chat; this lives on the
-- right edge instead, in happy sunny colors.
local sidePanel = Instance.new("Frame")
sidePanel.Name = "SidePanel"
sidePanel.Size = UDim2.new(0, 164, 0, 226)
sidePanel.Position = UDim2.new(1, -176, 0.5, -113)
sidePanel.BackgroundColor3 = Color3.fromRGB(255, 205, 85)
sidePanel.BorderSizePixel = 0
sidePanel.Parent = gui
corner(sidePanel, 18)
local panelGrad = Instance.new("UIGradient")
panelGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 226, 130)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 178, 70)),
})
panelGrad.Rotation = 90
panelGrad.Parent = sidePanel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(255, 240, 200)
panelStroke.Thickness = 3
panelStroke.Parent = sidePanel
local panelPad = Instance.new("UIPadding")
panelPad.PaddingTop = UDim.new(0, 12)
panelPad.PaddingBottom = UDim.new(0, 12)
panelPad.PaddingLeft = UDim.new(0, 8)
panelPad.PaddingRight = UDim.new(0, 8)
panelPad.Parent = sidePanel
local panelStack = Instance.new("UIListLayout")
panelStack.FillDirection = Enum.FillDirection.Vertical
panelStack.Padding = UDim.new(0, 6)
panelStack.HorizontalAlignment = Enum.HorizontalAlignment.Center
panelStack.VerticalAlignment = Enum.VerticalAlignment.Center
panelStack.Parent = sidePanel

local cocoa = Color3.fromRGB(96, 62, 24) -- readable happy-brown text on sunshine
local coinsLabel = label(sidePanel, "💰 0", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 0), 23, cocoa)
local eggLabel = label(sidePanel, "🥚 0", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 0), 23, cocoa)
local buffLabel = label(sidePanel, "", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 0), 14, Color3.fromRGB(140, 80, 20))
local eventLabel = label(sidePanel, "☀️ Sunny", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 0), 18, cocoa)
local phaseLabel = label(sidePanel, "☀️ Day", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 0), 16, cocoa)
for _, l in { coinsLabel, eggLabel, buffLabel, eventLabel, phaseLabel } do
	(l :: TextLabel).TextXAlignment = Enum.TextXAlignment.Center
	;(l :: TextLabel).BackgroundTransparency = 1
end
local shopBalance: any -- v47.8: Shop header balance readout (filled in below)

local bottomBar = Instance.new("Frame")
bottomBar.Size = UDim2.new(1, 0, 0, 64)
bottomBar.Position = UDim2.new(0, 0, 1, -64)
bottomBar.BackgroundColor3 = Color3.fromRGB(40, 175, 100) -- vivid garden green
bottomBar.BorderSizePixel = 0
bottomBar.Parent = gui
-- v33: 5 big category buttons instead of 19 cramped ones. The real actions
-- live in popup menus above the bar; menus are pre-built once so the spray /
-- stone / radar button references stay valid across opens.
local catMenus: any, openCat: any, closeCat: any, menuOption: any, catButton: any -- §escapes: CATEGORY BAR (v33)
do
local barRow = Instance.new("Frame")
barRow.Name = "BarRow"
barRow.Size = UDim2.new(1, -16, 1, -8)
barRow.Position = UDim2.new(0, 8, 0, 4)
barRow.BackgroundTransparency = 1
barRow.Parent = bottomBar
local barRowLayout = Instance.new("UIListLayout")
barRowLayout.FillDirection = Enum.FillDirection.Horizontal
barRowLayout.Padding = UDim.new(0, 6) -- v47: 6 buttons must fit a 360px phone
barRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
barRowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
barRowLayout.Parent = barRow

-- tap-catcher behind the popup: tapping anywhere else closes the menu.
-- It stops above the bar so the category buttons stay tappable.
local menuScrim = Instance.new("TextButton")
menuScrim.Name = "MenuScrim"
menuScrim.Size = UDim2.new(1, 0, 1, -64)
menuScrim.BackgroundTransparency = 1
menuScrim.Text = ""
menuScrim.Visible = false
menuScrim.ZIndex = 50
menuScrim.Parent = gui

local catPopup = Instance.new("Frame")
catPopup.Name = "CatPopup"
catPopup.AnchorPoint = Vector2.new(0.5, 1)
catPopup.Position = UDim2.new(0.5, 0, 1, -72)
catPopup.Size = UDim2.new(0, 280, 0, 0)
-- v39: explicit sizing (no nested AutomaticSize) so the popup can never
-- render sized-but-empty if Studio glitches automatic layout.
catPopup.BackgroundColor3 = Color3.fromRGB(255, 248, 225)
catPopup.BorderSizePixel = 0
catPopup.Visible = false
catPopup.ZIndex = 60 -- v46 UI fix: above the scrim (50); menus/buttons go higher
catPopup.Parent = gui
corner(catPopup, 16)
local catStroke = Instance.new("UIStroke")
catStroke.Color = Color3.fromRGB(230, 190, 120)
catStroke.Thickness = 3
catStroke.Parent = catPopup
local catPad = Instance.new("UIPadding")
catPad.PaddingTop = UDim.new(0, 10)
catPad.PaddingBottom = UDim.new(0, 10)
catPad.PaddingLeft = UDim.new(0, 10)
catPad.PaddingRight = UDim.new(0, 10)
catPad.Parent = catPopup
-- red X to close the popup (same look as the panel close buttons)
local catX = Instance.new("TextButton")
catX.Name = "CatX"
catX.Size = UDim2.new(0, 30, 0, 30)
catX.Position = UDim2.new(1, -36, 0, 6)
catX.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
catX.Text = "X"
catX.TextSize = 16
catX.TextColor3 = Color3.fromRGB(255, 255, 255)
catX.Font = Enum.Font.FredokaOne
catX.ZIndex = 63
catX.Parent = catPopup
corner(catX, 8)

-- one pre-built vertical menu per category (only one visible at a time)
catMenus = {}
local openCatName: string? = nil
closeCat = function()
	openCatName = nil
	catPopup.Visible = false
	menuScrim.Visible = false
end
menuScrim.MouseButton1Click:Connect(function() closeCat() end)
catX.MouseButton1Click:Connect(function() closeCat() end)

local function makeCatMenu(name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name .. "Menu"
	f.Size = UDim2.new(1, 0, 0, 0) -- v39: sized explicitly after options are built (no AutomaticSize)
	f.BackgroundTransparency = 1
	f.Visible = false
	f.ZIndex = 61 -- v46 UI fix: above popup (60) so options can never paint behind it
	local lay = Instance.new("UIListLayout")
	lay.FillDirection = Enum.FillDirection.Vertical
	lay.Padding = UDim.new(0, 8)
	lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lay.Parent = f
	f.Parent = catPopup
	catMenus[name] = f
	return f
end
for _, n in { "Pets", "Shop", "Play", "Social" } do makeCatMenu(n) end

openCat = function(name: string)
	if openCatName == name then closeCat() return end
	openCatName = name
	for n, f in catMenus do (f :: Frame).Visible = (n == name) end
	-- v39: size the popup explicitly from the shown menu's measured height
	local shown = catMenus[name] :: Frame
	catPopup.Size = UDim2.new(0, 280, 0, (shown.Size :: UDim2).Y.Offset + 20)
	catPopup.Visible = true
	menuScrim.Visible = true
end

-- big touch-friendly option buttons inside a category menu. Tapping one runs
-- the existing action and closes the menu (panels open on top anyway).
menuOption = function(menu: Frame, text: string, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 56)
	b.ZIndex = 62 -- v46 UI fix: top of the popup stack; nothing can cover the options
	b.BackgroundTransparency = 0
	b.TextTransparency = 0
	b.Active = true
	-- v36: popup options match their category's bold color
	local menuCols = {
		PetsMenu = Color3.fromRGB(46, 204, 113),
		ShopMenu = Color3.fromRGB(255, 165, 20),
		PlayMenu = Color3.fromRGB(95, 125, 255),
		SocialMenu = Color3.fromRGB(255, 95, 165),
	}
	b.BackgroundColor3 = menuCols[menu.Name] or Color3.fromRGB(46, 175, 100)
	b.Text = text
	b.TextSize = 20
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = Enum.Font.FredokaOne
	b.Parent = menu
	corner(b, 12)
	b.MouseButton1Click:Connect(function()
		closeCat()
		onClick()
	end)
	return b
end

catButton = function(emoji: string, name: string, onClick: () -> (), color: Color3, fs: number?)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.148, 0, 1, -8) -- v47: 6 buttons fit a 360px phone bar
	b.BackgroundColor3 = color
	b.Text = emoji .. "\n" .. name
	b.TextSize = fs or 15
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = Enum.Font.FredokaOne
	b.Parent = barRow
	corner(b, 14)
	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(150, 58)
	cap.Parent = b
	b.MouseButton1Click:Connect(onClick)
end
end

local function refreshTop()
	coinsLabel.Text = "💰 " .. coins
	eggLabel.Text = "🥚 " .. eggCount
	if shopBalance then (shopBalance :: TextLabel).Text = "💰 " .. coins .. "    🥚 " .. eggCount end
	local bits = {}
	if (buffs.TonicLeft or 0) > 0 then table.insert(bits, "🌱+" .. math.floor(buffs.TonicLeft / 60) .. "m") end
	if buffs.EvoBoost then table.insert(bits, "⚡Evo") end
	if buffs.Sprinkler then table.insert(bits, "💦") end
	if buffs.Shovel then table.insert(bits, "⛏️") end -- v14: shovel owned
	if buffs.Rod then
		local rdef = (Config.Rods :: { [string]: any })[buffs.Rod]
		if rdef then table.insert(bits, "🎣" .. (rdef.Name :: string)) end -- v14: owned rod
	end
	if buffs.Blessing and (buffs.Blessing.Left or 0) > 0 then -- v22: ⛲ fountain blessing chip
		local b = buffs.Blessing :: { [string]: any }
		-- inline icon lookup (blessingDisplay is declared later in the file)
		local bid = b.Id :: string
		local icon = "⛲"
		if bid == "Jackpot" then icon = "🌈"
		else
			local bdef = (Config.Blessings :: { [string]: any })[bid]
			if bdef then icon = (bdef.Icon :: string) end
		end
		table.insert(bits, "⛲" .. icon .. math.floor((b.Left :: number) / 60) .. "m")
	end
	buffLabel.Text = table.concat(bits, "  ")
end

-- ============================================================================
-- SHOP PANEL
local canEvolveClient: any, refreshShop: any -- §escapes: SHOP PANEL
do
-- ============================================================================
local shopPanel, shopList = makePanel("Shop", "🥚 Pet Shop 🧪", true)
-- v47.8: the wide shop panel covers the right-side money HUD, so mirror the
-- live coin/egg balance in the shop header (left of the X, updates on buy).
shopBalance = label(shopPanel, "💰 0    🥚 0", UDim2.new(0, 230, 0, 30), UDim2.new(1, -302, 0, 7), 16, Color3.fromRGB(255, 255, 255))
;(shopBalance :: TextLabel).TextXAlignment = Enum.TextXAlignment.Right
;(shopBalance :: TextLabel).ZIndex = 6

canEvolveClient = function(petId: string): boolean
	-- v14 fix: evolutions live in PetData.EVOLUTIONS, not on the species def
	-- (this always returned false, so the 🌱 Grow button never showed)
	return (PetData.EVOLUTIONS :: { [string]: any })[petId] ~= nil
end

refreshShop = function()
	for _, c in shopList:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	for i, entry in shopStock do
		local e = entry :: { [string]: any }
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 76)
		row.BackgroundColor3 = Color3.fromRGB(62, 50, 36)
		row.LayoutOrder = i
		row.Parent = shopList
		corner(row, 8)
		local name = tostring(e.Name)
		if e.Discounted then name ..= " 🔖" end
		label(row, name, UDim2.new(1, -140, 0, 28), UDim2.new(0, 10, 0, 4), 17, Color3.fromRGB(255, 225, 160))
		local descTxt = tostring(e.Desc)
		if e.Discounted then descTxt ..= " (was " .. tostring(e.OrigPrice) .. "c)" end -- v47: was-price lives in the desc so the buy button never clips
		local descLbl = label(row, descTxt, UDim2.new(1, -140, 0, 36), UDim2.new(0, 10, 0, 32), 13, Color3.fromRGB(230, 210, 180))
		descLbl.TextWrapped = true -- v47
		local priceTxt = tostring(e.Price) .. "c"
		local ownedSprinkler = e.Kind == "Sprinkler" and (buffs.Sprinkler == true)
		local ownedSkin = e.Kind == "Skin" and table.find(ownedSkins, e.Id) ~= nil -- v12
		-- v14: rods replace — owned tier AND all lower tiers show Owned ✅,
		-- mirroring the server rule (only a strictly higher tier is buyable)
		local ownedRod = false
		if e.Kind == "Rod" then
			local order = Config.RodOrder :: { string }
			local ownedIdx, thisIdx = 0, 0
			for i, id in order do
				if id == buffs.Rod then ownedIdx = i end
				if id == e.Id then thisIdx = i end
			end
			ownedRod = thisIdx > 0 and thisIdx <= ownedIdx
		end
		local ownedShovel = e.Kind == "Shovel" and (buffs.Shovel == true) -- v14
		local ownedRadar = e.Kind == "Radar" and (buffs.RadarOwned == true) -- v26: one-time radar
		local owned = ownedSprinkler or ownedSkin or ownedRod or ownedShovel or ownedRadar
		local b = button(row, if owned then "Owned ✅" else "Buy\n" .. priceTxt,
			UDim2.new(0, 118, 0, 60), UDim2.new(1, -128, 0, 8),
			if owned then Color3.fromRGB(90, 90, 100) else Color3.fromRGB(70, 140, 70))
		b.TextSize = 14
		b.MouseButton1Click:Connect(function()
			if e.Kind == "Egg" then R("BuyEgg"):FireServer()
			elseif e.Kind == "Treat" then R("BuyBait"):FireServer(e.Id)
			elseif e.Kind == "Sprinkler" then
				if not ownedSprinkler then R("BuySprinkler"):FireServer() end
			elseif e.Kind == "Skin" then
				if not ownedSkin then R("BuySkin"):FireServer(e.Id) end
			elseif e.Kind == "Rod" then -- v14
				if not ownedRod then R("BuyRod"):FireServer(e.Id) end
			elseif e.Kind == "Shovel" then -- v14
				if not ownedShovel then R("BuyShovel"):FireServer() end
			elseif e.Kind == "Repellent" then R("BuyRepellent"):FireServer() -- v21
			elseif e.Kind == "EvoStone" then R("BuyEvoStone"):FireServer(e.Id) -- v24
			elseif e.Kind == "Radar" then -- v26: one-time shiny radar
				if not ownedRadar then R("BuyRadar"):FireServer() end
			else R("BuyPotion"):FireServer(e.Id) end
		end)
	end
	-- plot upsell
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 76)
	row.BackgroundColor3 = Color3.fromRGB(74, 58, 36)
	row.LayoutOrder = 100
	row.Parent = shopList
	corner(row, 8)
	label(row, "🟫 Extra Plot (" .. plotsOwned .. "/12)", UDim2.new(1, -140, 0, 28), UDim2.new(0, 10, 0, 4), 17, Color3.fromRGB(255, 225, 160))
	label(row, "More plots = more pets growing at once", UDim2.new(1, -140, 0, 36), UDim2.new(0, 10, 0, 32), 13, Color3.fromRGB(230, 210, 180))
	local b = button(row, "Buy Plot", UDim2.new(0, 118, 0, 60), UDim2.new(1, -128, 0, 8), Color3.fromRGB(150, 110, 60))
	b.TextSize = 14
	b.MouseButton1Click:Connect(function() R("BuyPlot"):FireServer() end)
end

end
-- ============================================================================
-- PET CARD BUILDER (shared by Bag / Team / Fuse / Trade / Battle pickers)
local addPetCard: any -- §escapes: PET CARD BUILDER (shared by Bag / Team / Fuse / Trade / Batt
do
-- ============================================================================
addPetCard = function(parent: Instance, rec: { [string]: any }, order: number, buttons: { { [string]: any } }?): Frame
	local pdef = (PetData.PETS :: { [string]: any })[rec.PetId]
	local nBtn = buttons and #buttons or 0
	local cardH = 96 + math.max(0, nBtn - 3) * 30 -- v12: grow the card when >3 buttons (skin picker)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, cardH)
	card.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
	card.LayoutOrder = order
	card.Parent = parent
	corner(card, 8)
	-- rarity stripe
	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.new(0, 8, 1, 0)
	stripe.BackgroundColor3 = rarityColor((pdef and pdef.Rarity) or "Common")
	stripe.BorderSizePixel = 0
	stripe.Parent = card
	corner(stripe, 4)
	label(card, petTitle(rec), UDim2.new(1, -130, 0, 26), UDim2.new(0, 16, 0, 4), 16, Color3.fromRGB(255, 255, 255))
	-- type badge
	local tb = Instance.new("TextLabel")
	tb.Size = UDim2.new(0, 84, 0, 22)
	tb.Position = UDim2.new(0, 16, 0, 32)
	tb.BackgroundColor3 = typeColor((pdef and pdef.Type) or "Normal")
	tb.Text = (pdef and pdef.Type) or "?"
	tb.TextSize = 13
	tb.TextColor3 = Color3.fromRGB(255, 255, 255)
	tb.Font = Enum.Font.FredokaOne
	tb.Parent = card
	corner(tb, 6)
	if rec.IsStarter then
		local sl = Instance.new("TextLabel")
		sl.Size = UDim2.new(0, 70, 0, 22)
		sl.Position = UDim2.new(0, 106, 0, 32)
		sl.BackgroundColor3 = Color3.fromRGB(120, 90, 20)
		sl.Text = "🔒 STARTER"
		sl.TextSize = 12
		sl.TextColor3 = Color3.fromRGB(255, 240, 200)
		sl.Font = Enum.Font.FredokaOne
		sl.Parent = card
		corner(sl, 6)
	end
	-- HP bar
	local hpPct = math.clamp((rec.HP or 1) / math.max(1, rec.MaxHP or 1), 0, 1)
	local hpBg = Instance.new("Frame")
	hpBg.Size = UDim2.new(1, -140, 0, 10)
	hpBg.Position = UDim2.new(0, 16, 0, 58)
	hpBg.BackgroundColor3 = Color3.fromRGB(60, 20, 25)
	hpBg.BorderSizePixel = 0
	hpBg.Parent = card
	corner(hpBg, 5)
	local hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.new(hpPct, 0, 1, 0)
	hpFill.BackgroundColor3 = if hpPct > 0.5 then Color3.fromRGB(80, 200, 90)
		elseif hpPct > 0.25 then Color3.fromRGB(230, 180, 60) else Color3.fromRGB(220, 70, 70)
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBg
	corner(hpFill, 5)
	label(card, "❤️ " .. math.floor(rec.HP or 0) .. "/" .. (rec.MaxHP or 0) .. "   💰 " .. petDisplayValue(rec),
		UDim2.new(1, -140, 0, 20), UDim2.new(0, 16, 0, 70), 13, Color3.fromRGB(200, 200, 210))
	-- action buttons (right side, stacked)
	if buttons then
		local y = 4
		for _, bd in buttons do
			local bb = button(card, bd.Text, UDim2.new(0, 112, 0, 26), UDim2.new(1, -122, 0, y), bd.Color)
			bb.TextSize = 13
			bb.MouseButton1Click:Connect(bd.OnClick)
			y += 30
		end
	end
	return card
end

end
-- ============================================================================
-- BAG PANEL (pets + potions)
local refreshBag: any -- §escapes: BAG PANEL (pets + potions)
do
-- ============================================================================
local bagPanel, bagList = makePanel("Bag", "🎒 Pet Bag")

local function firstEmptyTeamSlot(): number?
	for i = 1, 5 do
		if teamSlots[i] == nil then return i end
	end
	return nil
end

refreshBag = function()
	for _, c in bagList:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	local order = 0
	-- potions row
	local hasPotions = false
	for pid, n in items do if (n :: number) > 0 then hasPotions = true break end end
	if hasPotions then
		order += 1
		local prow = Instance.new("Frame")
		prow.Size = UDim2.new(1, 0, 0, 64)
		prow.BackgroundColor3 = Color3.fromRGB(44, 36, 58)
		prow.LayoutOrder = order
		prow.Parent = bagList
		corner(prow, 8)
		label(prow, "🧪 Potions", UDim2.new(1, -16, 0, 24), UDim2.new(0, 10, 0, 4), 16, Color3.fromRGB(220, 180, 255))
		local x = 10
		for pid, n in items do
			if (n :: number) > 0 then
				if pid == "PetTreat" then
					-- treats are offered to wild pets, not "used" like potions
					local lbl = label(prow, "🍪 Pet Treat x" .. n .. "\n🌲 forest", UDim2.new(0, 130, 0, 44), UDim2.new(0, x, 0, 28), 12, Color3.fromRGB(255, 220, 160))
					lbl.BackgroundColor3 = Color3.fromRGB(110, 80, 40)
					lbl.BackgroundTransparency = 0
					lbl.TextWrapped = true
					corner(lbl, 6)
				elseif pid == "SweetBerry" then
					-- premium bait: same display pattern, no Use button
					local lbl = label(prow, "🫐 Sweet Berry x" .. n .. "\n🌲 forest", UDim2.new(0, 130, 0, 44), UDim2.new(0, x, 0, 28), 12, Color3.fromRGB(200, 160, 255))
					lbl.BackgroundColor3 = Color3.fromRGB(80, 50, 120)
					lbl.BackgroundTransparency = 0
					lbl.TextWrapped = true
					corner(lbl, 6)
				else
				local pdef = (Config.Potions :: { [string]: any })[pid]
				local b = button(prow, ((pdef and pdef.Name) or pid) .. " x" .. n .. "\nUse",
					UDim2.new(0, 130, 0, 44), UDim2.new(0, x, 0, 28), Color3.fromRGB(120, 70, 180))
				b.TextSize = 12
				local idCopy = pid
				b.MouseButton1Click:Connect(function()
					if idCopy == "HealingPotion" and openHealPicker then
						openHealPicker() -- choose which pet to heal
					else
						R("UsePotion"):FireServer(idCopy)
					end
				end)
				end
				x += 138
			end
		end
	end
	-- v14: fossil fragments + revive row (shows once the shovel is owned or
	-- fragments exist). 3 fragments -> revive a stage-1 fossil pet.
	local frags: number = buffs.FossilFrags or 0
	local needFrags: number = Config.FossilFragsNeeded
	if buffs.Shovel or frags > 0 then
		order += 1
		local frow = Instance.new("Frame")
		frow.Size = UDim2.new(1, 0, 0, 104)
		frow.BackgroundColor3 = Color3.fromRGB(58, 48, 36)
		frow.LayoutOrder = order
		frow.Parent = bagList
		corner(frow, 8)
		label(frow, "🦴 Fossil Fragments: " .. frags .. "/" .. needFrags, UDim2.new(1, -16, 0, 26), UDim2.new(0, 10, 0, 6), 16, Color3.fromRGB(255, 220, 170))
		label(frow, "Dig glowing dirt mounds ⛏️ — 3 fragments revive a fossil pet!", UDim2.new(1, -16, 0, 20), UDim2.new(0, 10, 0, 30), 12, Color3.fromRGB(210, 190, 160))
		local bx = 10
		for _, fid in (PetData.FOSSIL_STARTERS :: { string }) do
			local fdef = (PetData.PETS :: { [string]: any })[fid]
			local can = frags >= needFrags
			local rb = button(frow, "🦴 Revive " .. ((fdef and fdef.Name) or fid) .. (can and "" or " (" .. frags .. "/" .. needFrags .. ")"),
				UDim2.new(0, 200, 0, 40), UDim2.new(0, bx, 0, 54),
				if can then Color3.fromRGB(70, 140, 70) else Color3.fromRGB(90, 90, 100))
			rb.TextSize = 14
			local idCopy = fid
			rb.MouseButton1Click:Connect(function()
				if (buffs.FossilFrags or 0) >= (Config.FossilFragsNeeded :: number) then
					R("ReviveFossil"):FireServer(idCopy)
				else
					toast("Need " .. (Config.FossilFragsNeeded :: number) .. " 🦴 fragments to revive!", "warn")
				end
			end)
			bx += 210
		end
	end
	-- pets (starter first, then rarity)
	local sorted: { { [string]: any } } = {}
	for _, rec in inventory do table.insert(sorted, rec) end
	table.sort(sorted, function(a, b)
		if (a.IsStarter and not b.IsStarter) then return true end
		if (b.IsStarter and not a.IsStarter) then return false end
		local pa = (PetData.PETS :: { [string]: any })[a.PetId]
		local pb = (PetData.PETS :: { [string]: any })[b.PetId]
		local ra = (Config.RarityScore :: { [string]: number })[(pa and pa.Rarity) or "Common"] or 0
		local rb = (Config.RarityScore :: { [string]: number })[(pb and pb.Rarity) or "Common"] or 0
		return ra > rb
	end)
	for _, rec in sorted do
		order += 1
		local btns: { { [string]: any } } = {}
		local uid = rec.Uid
		if canEvolveClient(rec.PetId) then
			table.insert(btns, { Text = "🌱 Grow", Color = Color3.fromRGB(70, 150, 70),
				OnClick = function() R("PlantPet"):FireServer(uid) end })
		end
		-- starters CAN battle: Team button shows for everyone
		table.insert(btns, { Text = "🛡️ Team", Color = Color3.fromRGB(70, 110, 200),
			OnClick = function()
				local slot = firstEmptyTeamSlot()
				if slot then R("SetTeamSlot"):FireServer(slot, uid)
				else toast("Team is full! Remove someone first.", "warn") end
			end })
		table.insert(btns, { Text = "✏️ Name", Color = Color3.fromRGB(150, 110, 180),
			OnClick = function() if openRename then openRename(uid, PetData.PetName(rec)) end end })
		table.insert(btns, { Text = "🎨 Skin", Color = Color3.fromRGB(110, 90, 200), -- v12: custom skins
			OnClick = function() if openSkinPicker then openSkinPicker(uid, rec.Skin) end end })
		if not rec.IsStarter then
			table.insert(btns, { Text = "💰 Sell", Color = Color3.fromRGB(180, 130, 50),
				OnClick = function() R("SellOne"):FireServer(uid) end })
		end
		addPetCard(bagList, rec, order, btns)
	end
	if #sorted == 0 then
		order += 1
		label(bagList, "No pets yet! Buy a 🥚 Pet Egg from the shop.", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), 16).LayoutOrder = order
	end
end

end
-- ============================================================================
-- TEAM PANEL (5 slots + follower)
local refreshTeam: any -- §escapes: TEAM PANEL (5 slots + follower)
do
-- ============================================================================
local teamPanel, teamList = makePanel("Team", "🛡️ Battle Team & Follower")

refreshTeam = function()
	for _, c in teamList:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	local order = 0
	order += 1
	local info = label(teamList, "Pick ONE fighter per battle from this team. One pet follows you around — default is slot 1.",
		UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), 14, Color3.fromRGB(190, 190, 200))
	info.TextWrapped = true
	info.LayoutOrder = order
	for slot = 1, 5 do
		order += 1
		local rec = teamSlots[slot]
		if rec then
			local uid = rec.Uid
			local isFollower = (followerUid == uid)
			local btns: { { [string]: any } } = {
				{ Text = "❌ Remove", Color = Color3.fromRGB(170, 70, 70),
					OnClick = function() R("SetTeamSlot"):FireServer(slot, nil) end },
			}
			if not isFollower then
				table.insert(btns, 1, { Text = "🐾 Follow", Color = Color3.fromRGB(120, 90, 180),
					OnClick = function() R("SetFollower"):FireServer(uid) end })
			end
			local card = addPetCard(teamList, rec, order, btns)
			label(card, "SLOT " .. slot .. (isFollower and "  🐾 FOLLOWING YOU" or ""),
				UDim2.new(0, 220, 0, 20), UDim2.new(0, 186, 0, 32), 13,
				if isFollower then Color3.fromRGB(200, 150, 255) else Color3.fromRGB(150, 150, 160))
		else
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 56)
			row.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
			row.LayoutOrder = order
			row.Parent = teamList
			corner(row, 8)
			label(row, "SLOT " .. slot .. " — empty", UDim2.new(1, -140, 1, 0), UDim2.new(0, 12, 0, 0), 16, Color3.fromRGB(140, 140, 150))
			local b = button(row, "＋ Add", UDim2.new(0, 112, 0, 40), UDim2.new(1, -124, 0, 8), Color3.fromRGB(70, 110, 200))
			local slotCopy = slot
			b.MouseButton1Click:Connect(function()
				-- quick-add: first inventory pet not already on the team
				local onTeam: { [string]: boolean } = {}
				for i = 1, 5 do if teamSlots[i] then onTeam[(teamSlots[i] :: { [string]: any }).Uid] = true end end
				for _, rec2 in inventory do
					if not onTeam[rec2.Uid] then
						R("SetTeamSlot"):FireServer(slotCopy, rec2.Uid)
						return
					end
				end
				toast("No pets available!", "warn")
			end)
		end
	end
end

end
-- ============================================================================
-- FUSE PANEL
local refreshFuse: any -- §escapes: FUSE PANEL
do
-- ============================================================================
local fusePanel, fuseList = makePanel("Fuse", "⭐ Fuse Duplicates")
local fuseA: string? = nil
local fuseB: string? = nil

local function fuseEligible(rec: { [string]: any }): boolean
	if rec.IsStarter then return false end
	local pdef = (PetData.PETS :: { [string]: any })[rec.PetId]
	if not pdef or (pdef :: { [string]: any }).Stage ~= 1 then return false end -- basic only
	return (rec.Stars or 0) < 5
end

-- v14: fusion preview. Mirrors PlayerData.FusePets' result math exactly
-- (best mutation wins, +1 star, stronger bond kept, shiny/titan if either,
-- first pet's nickname + skin). Computed client-side with the same shared
-- PetData formulas the server uses, so the preview always matches.
local function fusePreviewData(recA: { [string]: any }, recB: { [string]: any }): { [string]: any }
	local petId: string = recA.PetId
	local stars: number = recA.Stars or 0
	local newStars = stars + 1
	local function rank(m: string?): number
		if not m then return 0 end
		return (Config.MutationRank :: { [string]: number })[m] or 0
	end
	local bestMut: string? = recA.Mutation
	if rank(recB.Mutation) > rank(bestMut) then bestMut = recB.Mutation end
	local bond = math.max(recA.Bond or 0, recB.Bond or 0)
	local shiny = (recA.Shiny or recB.Shiny) == true
	local titan = (recA.Titan or recB.Titan) == true
	local newStats = PetData.GetBattleStats(petId, bestMut, newStars, bond)
	local aStats = PetData.GetBattleStats(petId, recA.Mutation, stars, recA.Bond or 0)
	local bStats = PetData.GetBattleStats(petId, recB.Mutation, stars, recB.Bond or 0)
	local function valueOf(rec: { [string]: any }): number
		local v = PetData.GetValue(petId, rec.Mutation, rec.Stars or 0)
		if rec.Titan then v = math.floor(v * (Config.TitanValueMult :: number)) end -- v12: Titans +50%
		return v
	end
	local newValue = PetData.GetValue(petId, bestMut, newStars)
	if titan then newValue = math.floor(newValue * (Config.TitanValueMult :: number)) end
	return {
		PetId = petId, Stars = stars, NewStars = newStars,
		BestMut = bestMut, Bond = bond, Shiny = shiny, Titan = titan,
		AStats = aStats, BStats = bStats, NewStats = newStats,
		AVal = valueOf(recA), BVal = valueOf(recB), NewVal = newValue,
		Nick = recA.Nickname or recB.Nickname,
		Skin = recA.Skin or recB.Skin,
	}
end

local previewPair: { a: string, b: string }? = nil -- v14: selected pair for the preview

local function findRec(uid: string): { [string]: any }?
	for _, rec in inventory do
		if (rec :: { [string]: any }).Uid == uid then return rec end
	end
	return nil
end

refreshFuse = function()
	for _, c in fuseList:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	local order = 0
	order += 1
	local info = label(fuseList,
		"Fuse 2 IDENTICAL pets (same species, same ⭐) into one pet at +1 ⭐. Max ⭐5. Each ⭐: +20% HP/Atk/Def, +25% sell value. Basic pets only. Tap 🔍 Preview to see the result before you commit!",
		UDim2.new(1, 0, 0, 72), UDim2.new(0, 0, 0, 0), 14, Color3.fromRGB(190, 190, 200))
	info.TextWrapped = true
	info.LayoutOrder = order
	-- v14: validate the preview selection (pets may have been sold/traded since)
	local pA: { [string]: any }? = nil
	local pB: { [string]: any }? = nil
	if previewPair then
		pA = findRec(previewPair.a)
		pB = findRec(previewPair.b)
		local ok = pA ~= nil and pB ~= nil
			and (pA :: { [string]: any }).PetId == (pB :: { [string]: any }).PetId
			and (pA :: { [string]: any }).Stars == (pB :: { [string]: any }).Stars
			and fuseEligible(pA :: { [string]: any }) and fuseEligible(pB :: { [string]: any })
		if not ok then previewPair = nil pA = nil pB = nil end
	end
	-- v14: the preview card (exact numbers, computed with the same formulas
	-- the server uses, so what you see is what you get)
	if pA and pB and previewPair then
		local d = fusePreviewData(pA, pB)
		local pdef = (PetData.PETS :: { [string]: any })[d.PetId]
		local pname: string = (pdef and pdef.Name) or "?"
		local ns: { [string]: number } = d.NewStats
		local as: { [string]: number } = d.AStats
		local bs: { [string]: number } = d.BStats
		order += 1
		local pv = Instance.new("Frame")
		pv.Size = UDim2.new(1, 0, 0, 250) -- v47: taller so Atk/Def get their own lines on phones
		pv.BackgroundColor3 = Color3.fromRGB(52, 42, 74)
		pv.LayoutOrder = order
		pv.Parent = fuseList
		corner(pv, 10)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(150, 90, 200)
		stroke.Thickness = 2
		stroke.Parent = pv
		label(pv, "🔍 Preview: " .. pname .. " " .. string.rep("⭐", d.Stars) .. " → " .. string.rep("⭐", d.NewStars),
			UDim2.new(1, -16, 0, 28), UDim2.new(0, 10, 0, 6), 17, Color3.fromRGB(255, 230, 150))
		label(pv, "❤️ HP: " .. as.HP .. " / " .. bs.HP .. " → " .. ns.HP,
			UDim2.new(1, -16, 0, 22), UDim2.new(0, 10, 0, 36), 14, Color3.fromRGB(255, 170, 170))
		-- v47: Atk and Def on separate lines (the combined line truncated on phones)
		label(pv, "⚔️ Atk: " .. as.Atk .. " / " .. bs.Atk .. " → " .. ns.Atk,
			UDim2.new(1, -16, 0, 22), UDim2.new(0, 10, 0, 58), 14, Color3.fromRGB(255, 210, 150))
		label(pv, "🛡️ Def: " .. as.Def .. " / " .. bs.Def .. " → " .. ns.Def,
			UDim2.new(1, -16, 0, 22), UDim2.new(0, 10, 0, 80), 14, Color3.fromRGB(170, 210, 255))
		local mutTxt = if d.BestMut then Mutations.DisplayName(d.BestMut) else "none"
		label(pv, "🧬 Mutation kept: " .. mutTxt .. " (best of the two)",
			UDim2.new(1, -16, 0, 22), UDim2.new(0, 10, 0, 102), 14, Color3.fromRGB(200, 170, 255))
		label(pv, "💰 Value: " .. d.AVal .. " + " .. d.BVal .. " → " .. d.NewVal .. "c",
			UDim2.new(1, -16, 0, 22), UDim2.new(0, 10, 0, 124), 14, Color3.fromRGB(255, 230, 150))
		local keepBits = {}
		if d.Shiny then table.insert(keepBits, "✨ stays shiny") end
		if d.Titan then table.insert(keepBits, "👑 stays Titan") end
		if (d.Bond :: number) > 0 then table.insert(keepBits, "💕 bond " .. d.Bond) end
		if d.Nick then table.insert(keepBits, "✏️ keeps name") end
		if d.Skin then table.insert(keepBits, "🎨 keeps skin") end
		label(pv, #keepBits > 0 and ("Kept: " .. table.concat(keepBits, " · ")) or "Nothing special kept.",
			UDim2.new(1, -16, 0, 22), UDim2.new(0, 10, 0, 146), 13, Color3.fromRGB(180, 200, 180))
		local uidA, uidB = previewPair.a, previewPair.b
		local confirm = button(pv, "⚡ CONFIRM FUSE", UDim2.new(1, -20, 0, 44), UDim2.new(0, 10, 0, 174), Color3.fromRGB(150, 90, 200))
		confirm.MouseButton1Click:Connect(function()
			previewPair = nil
			R("FusePets"):FireServer(uidA, uidB)
		end)
		local cancel = button(pv, "X", UDim2.new(0, 44, 0, 32), UDim2.new(1, -54, 0, 6), Color3.fromRGB(120, 60, 60))
		cancel.TextSize = 16
		cancel.MouseButton1Click:Connect(function() previewPair = nil refreshFuse() end)
	end
	-- group eligible pets by species+stars
	local groups: { [string]: { { [string]: any } } } = {}
	for _, rec in inventory do
		if fuseEligible(rec) then
			local key = rec.PetId .. "_" .. (rec.Stars or 0)
			groups[key] = groups[key] or {}
			table.insert(groups[key], rec)
		end
	end
	local anyGroup = false
	for key, list in groups do
		if #list >= 2 then
			anyGroup = true
			order += 1
			local sample = list[1]
			local pdef = (PetData.PETS :: { [string]: any })[sample.PetId]
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 64)
			row.BackgroundColor3 = Color3.fromRGB(44, 38, 58)
			row.LayoutOrder = order
			row.Parent = fuseList
			corner(row, 8)
			label(row, ((pdef and pdef.Name) or "?") .. " " .. string.rep("⭐", sample.Stars or 0) .. "  (x" .. #list .. ")",
				UDim2.new(1, -150, 0, 28), UDim2.new(0, 10, 0, 4), 16, Color3.fromRGB(255, 230, 150))
			label(row, "→ " .. string.rep("⭐", math.min((sample.Stars or 0) + 1, 5)) .. " " .. ((pdef and pdef.Name) or "?"),
				UDim2.new(1, -150, 0, 24), UDim2.new(0, 10, 0, 32), 14, Color3.fromRGB(180, 220, 255))
			local b = button(row, "🔍 Preview", UDim2.new(0, 128, 0, 48), UDim2.new(1, -138, 0, 8), Color3.fromRGB(120, 90, 200))
			local a, bb2 = list[1].Uid, list[2].Uid
			b.MouseButton1Click:Connect(function() previewPair = { a = a, b = bb2 } refreshFuse() end)
		end
	end
	if not anyGroup then
		order += 1
		label(fuseList, "No fuseable pairs! You need 2 identical basic pets at the same ⭐ level.",
			UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), 15, Color3.fromRGB(170, 170, 180)).LayoutOrder = order
	end
end

end
-- ============================================================================
-- COLLECTION BOOK
local refreshDex: any -- §escapes: COLLECTION BOOK
do
-- ============================================================================
local dexPanel, dexList = makePanel("Dex", "📖 Collection Book")

refreshDex = function()
	for _, c in dexList:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	local order = 0
	local total, found = 0, 0
	for _ in (PetData.PETS :: { [string]: any }) do total += 1 end
	for _ in collection do found += 1 end
	order += 1
	label(dexList, "Discovered: " .. found .. " / " .. total, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 0), 18, Color3.fromRGB(255, 230, 150)).LayoutOrder = order
	-- group by stage
	for stage = 1, 3 do
		order += 1
		label(dexList, if stage == 1 then "— Basic —" elseif stage == 2 then "— Evolved —" else "— Final —",
			UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 0), 15, Color3.fromRGB(170, 170, 190)).LayoutOrder = order
		local ids: { string } = {}
		for pid, pdef in (PetData.PETS :: { [string]: any }) do
			if (pdef :: { [string]: any }).Stage == stage then table.insert(ids, pid) end
		end
		table.sort(ids)
		for _, pid in ids do
			order += 1
			local pdef = (PetData.PETS :: { [string]: any })[pid]
			local known = collection[pid] ~= nil
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 60) -- v47: two lines so type/rarity/evo never run off phones
			row.BackgroundColor3 = if known then Color3.fromRGB(38, 38, 52) else Color3.fromRGB(28, 28, 36)
			row.LayoutOrder = order
			row.Parent = dexList
			corner(row, 8)
			local atIcon = ""
			local at = (pdef :: { [string]: any }).ActiveTime or "Any"
			if at == "Day" then atIcon = " ☀️" elseif at == "Night" then atIcon = " 🌙" end
			label(row, if known then (pdef.Name :: string) .. atIcon else "???", UDim2.new(1, -190, 0, 26), UDim2.new(0, 12, 0, 2), 15,
				if known then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(110, 110, 120))
			if known then
				local tb = Instance.new("TextLabel")
				tb.Size = UDim2.new(0, 72, 0, 22)
				tb.Position = UDim2.new(1, -162, 0, 5)
				tb.BackgroundColor3 = typeColor(pdef.Type)
				tb.Text = pdef.Type
				tb.TextSize = 12
				tb.TextColor3 = Color3.fromRGB(255, 255, 255)
				tb.Font = Enum.Font.FredokaOne
				tb.Parent = row
				corner(tb, 6)
				local rarLbl = label(row, (pdef.Rarity :: string), UDim2.new(0, 80, 0, 22), UDim2.new(1, -82, 0, 5), 12, rarityColor(pdef.Rarity))
				rarLbl.TextXAlignment = Enum.TextXAlignment.Right
				-- evolution hint (second line; truncates with … on narrow screens)
				local evos = (pdef :: { [string]: any }).Evolutions
				if evos then
					local names = {}
					for _, eid in evos do
						local ed = (PetData.PETS :: { [string]: any })[eid]
						table.insert(names, (ed and ed.Name) or "?")
					end
					label(row, "→ " .. table.concat(names, " / "), UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 34), 12, Color3.fromRGB(170, 200, 255))
				end
			end
		end
	end
end

end
-- ============================================================================
-- LEADERBOARDS
local refreshBoards: any -- §escapes: LEADERBOARDS
do
-- ============================================================================
local boardPanel, boardList = makePanel("Boards", "🏆 Leaderboards")

refreshBoards = function()
	for _, c in boardList:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	local order = 0
	for key, entries in boards do
		order += 1
		label(boardList, boardLabels[key] or key, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 0), 18, Color3.fromRGB(255, 220, 120)).LayoutOrder = order
		local list = entries :: { { [string]: any } }
		if #list == 0 then
			order += 1
			label(boardList, "No entries yet!", UDim2.new(1, 0, 0, 26), UDim2.new(0, 8, 0, 0), 14, Color3.fromRGB(150, 150, 160)).LayoutOrder = order
		end
		for i, e in list do
			order += 1
			label(boardList, i .. ". " .. tostring(e.Name) .. " — " .. tostring(e.Value),
				UDim2.new(1, 0, 0, 26), UDim2.new(0, 8, 0, 0), 14).LayoutOrder = order
		end
	end
end

end
-- ============================================================================
-- VISIT / SOCIAL PANEL (visit, battle challenge, trade, gift)
local refreshVisit: any -- §escapes: VISIT / SOCIAL PANEL (visit, battle challenge, trade, gift)
do
-- ============================================================================
local visitPanel, visitListUI = makePanel("Visit", "🧑‍🤝‍🧑 Players")

refreshVisit = function()
	for _, c in visitListUI:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	local order = 0
	order += 1
	local home = button(visitListUI, "🏠 Go Home", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 0), Color3.fromRGB(70, 130, 180))
	home.LayoutOrder = order
	home.MouseButton1Click:Connect(function() R("GoHome"):FireServer() end)
	if #visitList == 0 then
		order += 1
		label(visitListUI, "No other players in this server yet!", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 0), 15, Color3.fromRGB(160, 160, 170)).LayoutOrder = order
	end
	for _, e in visitList do
		order += 1
		local entry = e :: { [string]: any }
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 88) -- v47: two-line row so the 4 buttons never run off phones
		row.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
		row.LayoutOrder = order
		row.Parent = visitListUI
		corner(row, 8)
		label(row, tostring(entry.DisplayName), UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, 4), 16)
		local uid = entry.UserId
		local specs = {
			{ "🏠 Visit", Color3.fromRGB(70, 130, 70), function() R("Visit"):FireServer(uid) end },
			{ "⚔️ Battle", Color3.fromRGB(180, 70, 70), function() R("BattleChallenge"):FireServer(uid) end },
			{ "🔄 Trade", Color3.fromRGB(70, 110, 200), function() R("TradeRequest"):FireServer(uid) end },
			{ "🎁 Gift 🥚", Color3.fromRGB(150, 110, 60), function() R("Gift"):FireServer(uid) end },
		}
		local btnRow = Instance.new("Frame")
		btnRow.Size = UDim2.new(1, -16, 0, 44)
		btnRow.Position = UDim2.new(0, 8, 0, 36)
		btnRow.BackgroundTransparency = 1
		btnRow.Parent = row
		local btnLay = Instance.new("UIListLayout")
		btnLay.FillDirection = Enum.FillDirection.Horizontal
		btnLay.Padding = UDim.new(0, 6)
		btnLay.Parent = btnRow
		for _, s in specs do
			local b = button(btnRow, (s :: { [string]: any })[1], UDim2.new(0.25, -5, 1, 0), UDim2.new(0, 0, 0, 0), (s :: { [string]: any })[2])
			b.TextSize = 12 -- v47: fits the evenly-split buttons on phones
			local fn = (s :: { [string]: any })[3]
			b.MouseButton1Click:Connect(function() fn() end)
		end
	end
end

end
-- ============================================================================
-- DAILY + SETTINGS
local refreshDaily: any, refreshSettings: any -- §escapes: DAILY + SETTINGS
do
-- ============================================================================
local dailyPanel, dailyList = makePanel("Daily", "🎁 Daily Rewards")

refreshDaily = function()
	for _, c in dailyList:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	label(dailyList, "Streak: " .. dailyStreak .. " day(s) — claim once every 20 hours!",
		UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 0), 15, Color3.fromRGB(200, 200, 210)).LayoutOrder = 1
	local names = { "500 coins", "3x Pet Egg", "2,000 coins", "1x Healing Potion",
		"10,000 coins", "1x Growth Tonic", "50,000 coins + 1x Evolution Elixir" }
	for day = 1, 7 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 44)
		row.BackgroundColor3 = if day == dailyDay then Color3.fromRGB(60, 50, 30) else Color3.fromRGB(36, 36, 48)
		row.LayoutOrder = day + 1
		row.Parent = dailyList
		corner(row, 8)
		label(row, "Day " .. day .. ": " .. names[day], UDim2.new(1, -140, 1, 0), UDim2.new(0, 10, 0, 0), 15,
			if day == dailyDay then Color3.fromRGB(255, 230, 150) else Color3.fromRGB(200, 200, 200))
		if day == dailyDay then
			local b = button(row, if dailyCan then "CLAIM!" else "CLAIMED", UDim2.new(0, 118, 0, 34), UDim2.new(1, -128, 0, 5),
				if dailyCan then Color3.fromRGB(70, 150, 70) else Color3.fromRGB(90, 90, 100))
			b.TextSize = 14
			if dailyCan then
				b.MouseButton1Click:Connect(function() R("ClaimDaily"):FireServer() end)
			end
		end
	end
end

local settingsPanel, settingsList = makePanel("Settings", "⚙️ Settings")

refreshSettings = function()
	for _, c in settingsList:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 56)
	row.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
	row.LayoutOrder = 1
	row.Parent = settingsList
	corner(row, 8)
	label(row, "Auto-sell hatched pets: " .. (if settings.AutoSell then "ON ✅" else "OFF ❌"),
		UDim2.new(1, -140, 1, 0), UDim2.new(0, 10, 0, 0), 15)
	local b = button(row, "Toggle", UDim2.new(0, 118, 0, 40), UDim2.new(1, -128, 0, 8), Color3.fromRGB(90, 90, 140))
	b.MouseButton1Click:Connect(function() R("ToggleAutoSell"):FireServer() end)
	local sellNote = label(settingsList, "Note: auto-sell NEVER applies to pets you grow yourself — those always come back to your bag. 🌱",
		UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 0), 13, Color3.fromRGB(160, 200, 160))
	sellNote.LayoutOrder = 2
	sellNote.TextWrapped = true -- v47: was truncating mid-sentence on narrow screens
end

end
-- ============================================================================
-- V16: DAILY SPIN WHEEL (server rolls, wheel animation is cosmetic)
local spinSegs: { { [string]: any } }, spinCan: any, spinStreak: any, spinning: any, spinTierName: any, wheelInner: Frame?, buildWheel: any, refreshSpin: any, spinAnimate: any -- §escapes: V16: DAILY SPIN WHEEL (server rolls, wheel animation is cosm
do
-- ============================================================================
spinSegs= {}
spinCan, spinStreak, spinning= false, 0, false
spinTierName= "❄️ Cold"
wheelInner= nil
local spinStreakLabel: TextLabel? = nil
local spinBtn: TextButton? = nil
local spinResultLabel: TextLabel? = nil

local spinPanel, spinList = makePanel("Spin", "🎡 Daily Spin Wheel", true)

local function refreshSpinText()
	if spinStreakLabel then
		spinStreakLabel.Text = "🔥 Streak x" .. spinStreak .. " — luck: " .. spinTierName
			.. " (streak 3+ warms up, 7+ unlocks the ⭐ JACKPOT!)"
	end
	if spinBtn then
		spinBtn.Text = if spinning then "Spinning..." elseif spinCan then "🎡 SPIN!" else "Come back tomorrow!"
		spinBtn.BackgroundColor3 = if spinCan and not spinning then Color3.fromRGB(70, 150, 70) else Color3.fromRGB(90, 90, 100)
	end
end

buildWheel = function()
	for _, c in spinList:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	wheelInner = nil
	spinStreakLabel = label(spinList, "", UDim2.new(1, 0, 0, 48), UDim2.new(0, 0, 0, 0), 15, Color3.fromRGB(255, 220, 150))
	;(spinStreakLabel :: TextLabel).LayoutOrder = 1
	;(spinStreakLabel :: TextLabel).TextWrapped = true -- v47: the streak text is ~80 chars, wraps on phones
	local cont = Instance.new("Frame")
	cont.Size = UDim2.new(1, 0, 0, 350)
	cont.BackgroundTransparency = 1
	cont.LayoutOrder = 2
	cont.Parent = spinList
	-- pointer at the top
	local pointer = label(cont, "▼", UDim2.new(0, 40, 0, 30), UDim2.new(0.5, -20, 0, 0), 26, Color3.fromRGB(255, 220, 120))
	pointer.TextXAlignment = Enum.TextXAlignment.Center
	-- wheel disc (v47: scale-based with 1:1 aspect so it shrinks on phones instead of overflowing)
	local back = Instance.new("Frame")
	back.Name = "WheelBack"
	back.Size = UDim2.new(1, -16, 1, -16)
	back.Position = UDim2.new(0, 8, 0, 30)
	back.BackgroundColor3 = Color3.fromRGB(35, 30, 50)
	back.BorderSizePixel = 0
	back.Parent = cont
	local backAspect = Instance.new("UIAspectRatioConstraint")
	backAspect.AspectRatio = 1
	backAspect.DominantAxis = Enum.DominantAxis.Width
	backAspect.Parent = back
	local backCap = Instance.new("UISizeConstraint")
	backCap.MaxSize = Vector2.new(300, 300)
	backCap.Parent = back
	local uc = Instance.new("UICorner")
	uc.CornerRadius = UDim.new(1, 0)
	uc.Parent = back
	-- rotating inner layer with the 8 segment chips
	local inner = Instance.new("Frame")
	inner.Name = "WheelInner"
	inner.Size = UDim2.new(1, 0, 1, 0)
	inner.BackgroundTransparency = 1
	inner.Parent = back
	wheelInner = inner
	for i, seg in spinSegs do
		local s = seg :: { [string]: any }
		local theta = math.rad((i - 1) * 45 - 90) -- segment 1 starts at the pointer
		local chip = Instance.new("TextLabel")
		chip.Size = UDim2.new(0.3, 0, 0.13, 0) -- v47: scale so chips fit any disc size
		chip.AnchorPoint = Vector2.new(0.5, 0.5)
		chip.Position = UDim2.new(0.5 + math.cos(theta) * 0.34, 0, 0.5 + math.sin(theta) * 0.34, 0)
		chip.Text = tostring(s.Label)
		chip.TextSize = 13
		chip.Font = Enum.Font.FredokaOne
		chip.TextColor3 = Color3.fromRGB(30, 25, 45)
		local col = (s.Color :: Color3?) or Color3.fromRGB(200, 200, 220)
		chip.BackgroundColor3 = col
		chip.BorderSizePixel = 0
		chip.Parent = inner
		corner(chip, 20)
	end
	-- hub (v47: parented to the disc so it stays centered at any size)
	local hub = label(back, "🎡", UDim2.new(0, 60, 0, 60), UDim2.new(0.5, -30, 0.5, -30), 34, Color3.fromRGB(255, 255, 255))
	hub.TextXAlignment = Enum.TextXAlignment.Center
	hub.BackgroundColor3 = Color3.fromRGB(60, 50, 90)
	hub.BackgroundTransparency = 0
	local huc = Instance.new("UICorner")
	huc.CornerRadius = UDim.new(1, 0)
	huc.Parent = hub
	-- spin button + result
	spinBtn = button(spinList, "🎡 SPIN!", UDim2.new(0, 220, 0, 52), UDim2.new(0.5, -110, 0, 0), Color3.fromRGB(70, 150, 70))
	;(spinBtn :: TextButton).LayoutOrder = 3
	;(spinBtn :: TextButton).TextSize = 20
	(spinBtn :: TextButton).MouseButton1Click:Connect(function()
		if spinning or not spinCan then return end
		R("SpinWheel"):FireServer()
	end)
	spinResultLabel = label(spinList, "", UDim2.new(1, 0, 0, 34), UDim2.new(0, 0, 0, 0), 16, Color3.fromRGB(255, 230, 150))
	;(spinResultLabel :: TextLabel).LayoutOrder = 4
	;(spinResultLabel :: TextLabel).TextXAlignment = Enum.TextXAlignment.Center
	refreshSpinText()
end

refreshSpin = function()
	if spinning then return end -- don't rebuild mid-animation
	buildWheel()
end

-- cosmetic spin: lands the wheel on the server-chosen segment index (1-based)
spinAnimate = function(segIdx: number, summary: string)
	local inner = wheelInner
	spinning = true
	refreshSpinText()
	if not inner then
		spinning = false
		if spinResultLabel then spinResultLabel.Text = "You won " .. summary .. "!" end
		return
	end
	inner.Rotation = 0
	local target = 360 * 6 - (segIdx - 1) * 45 -- segment lands under the pointer
	local tw = game:GetService("TweenService"):Create(inner,
		TweenInfo.new(4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Rotation = target })
	tw:Play()
	tw.Completed:Connect(function()
		spinning = false
		if spinResultLabel then spinResultLabel.Text = "🎉 You won " .. summary .. "!" end
		refreshSpinText()
	end)
end

end
-- ============================================================================
-- V16: BOSS HUD (slim HP bar while a boss event is live)
local bossBar: any, bossNameL: any, bossBarFill: any -- §escapes: V16: BOSS HUD (slim HP bar while a boss event is live)
do
-- ============================================================================
bossBar= Instance.new("Frame")
bossBar.Name = "BossBar"
bossBar.Size = UDim2.new(0.9, 0, 0, 58) -- v47: scale so it fits narrow phones (capped at 380 by constraint)
bossBar.Position = UDim2.new(0.05, 0, 0, 12)
bossBar.BackgroundColor3 = Color3.fromRGB(35, 18, 22)
bossBar.BorderSizePixel = 0
bossBar.Visible = false
bossBar.Parent = gui
corner(bossBar, 10)
local bossSizeCap = Instance.new("UISizeConstraint") -- v47
bossSizeCap.MaxSize = Vector2.new(380, 58)
bossSizeCap.Parent = bossBar
bossNameL= label(bossBar, "", UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 4), 17, Color3.fromRGB(255, 130, 130))
bossNameL.TextXAlignment = Enum.TextXAlignment.Center
local bossBarBG = Instance.new("Frame")
bossBarBG.Size = UDim2.new(1, -16, 0, 16)
bossBarBG.Position = UDim2.new(0, 8, 0, 32)
bossBarBG.BackgroundColor3 = Color3.fromRGB(20, 8, 8)
bossBarBG.BorderSizePixel = 0
bossBarBG.Parent = bossBar
corner(bossBarBG, 8)
bossBarFill= Instance.new("Frame")
bossBarFill.Size = UDim2.new(1, 0, 1, 0)
bossBarFill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
bossBarFill.BorderSizePixel = 0
bossBarFill.Parent = bossBarBG
corner(bossBarFill, 8)

end
-- ============================================================================
-- V16: SKY TELEPORT FLASH
do
-- ============================================================================
local skyFlash = Instance.new("Frame")
skyFlash.Name = "SkyFlash"
skyFlash.Size = UDim2.new(1, 0, 1, 0)
skyFlash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
skyFlash.BackgroundTransparency = 1
skyFlash.BorderSizePixel = 0
skyFlash.ZIndex = 200
skyFlash.Parent = gui

R("SpinInfo").OnClientEvent:Connect(function(segs: { { [string]: any } }, can: boolean, streak: number, tierName: string, resultIdx: number?, summary: string?)
	spinSegs = segs
	spinCan, spinStreak, spinTierName = can, streak, tierName
	if resultIdx then
		-- a spin just resolved: rebuild if needed, then run the cosmetic animation
		if not wheelInner then buildWheel() end
		spinAnimate(resultIdx, tostring(summary))
	elseif openPanel == "Spin" then
		refreshSpin()
	end
end)

R("BossInfo").OnClientEvent:Connect(function(info: { [string]: any })
	local i = info :: { [string]: any }
	if i.Active then
		bossBar.Visible = true
		bossNameL.Text = "👹 " .. tostring(i.Name) .. " — near " .. tostring(i.Zone)
		local frac = math.clamp((i.HP :: number) / math.max(1, (i.MaxHP :: number)), 0, 1)
		bossBarFill.Size = UDim2.new(frac, 0, 1, 0)
	else
		bossBar.Visible = false
	end
end)

R("SkyFlash").OnClientEvent:Connect(function()
	skyFlash.BackgroundTransparency = 0.2
	game:GetService("TweenService"):Create(skyFlash, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
end)

-- 🌗 v23: twilight dimension teleport flash (same white flash as the sky portal)
R("TwilightFlash").OnClientEvent:Connect(function()
	skyFlash.BackgroundTransparency = 0.2
	game:GetService("TweenService"):Create(skyFlash, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
end)

end
-- ============================================================================
-- V20: NIGHT AUCTION PANEL (🌙 bid on 3 bracketed lots during auction nights)
local refreshAuction: any -- §escapes: V20: NIGHT AUCTION PANEL (🌙 bid on 3 bracketed lots during a
do
-- ============================================================================
local aucPanel, aucList = makePanel("Auction", "🌙 Night Auction", true)
local aucInfo: { [string]: any }? = nil
local aucCountdown: TextLabel? = nil -- v47: updated in place by the ticker

refreshAuction = function()
	for _, c in aucList:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	local info = aucInfo
	local function addText(t: string, size: number?, color: Color3?)
		local l = label(aucList, t, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 0), size or 16, color or Color3.fromRGB(255, 230, 170))
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.TextWrapped = true
		return l
	end
	if not info or not (info :: { [string]: any }).Active then
		addText("🌙 The auction runs on random nights!", 18)
		addText("When night falls, the auctioneer may take the plaza stage.", 14, Color3.fromRGB(200, 190, 170))
		addText("3 lots: 🌱 Sprout (bids capped — new players can win!)", 14, Color3.fromRGB(200, 190, 170))
		addText("🌿 Adventurer and 👑 High Roller (no cap).", 14, Color3.fromRGB(200, 190, 170))
		addText("Watch for the 🌙 announcement at dusk!", 14, Color3.fromRGB(200, 190, 170))
		return
	end
	local i = info :: { [string]: any }
	local b = i.Bracket :: { [string]: any }
	addText(tostring(b.Name) .. " — Lot " .. tostring(i.LotIdx) .. "/" .. tostring(i.LotCount), 20)
	addText(tostring(b.Desc), 13, Color3.fromRGB(200, 190, 170))
	addText("🔨 " .. tostring(i.ItemName), 18, Color3.fromRGB(255, 255, 255))
	addText(tostring(i.ItemDesc), 14, Color3.fromRGB(210, 200, 180))
	local left = math.max(0, (i.EndsAt :: number) - os.time())
	aucCountdown = addText("⏳ " .. tostring(left) .. "s left", 18, if left <= 10 then Color3.fromRGB(255, 120, 120) else Color3.fromRGB(150, 220, 150))
	addText("Top bid: " .. tostring(i.TopBid) .. "c — " .. tostring(i.TopBidderName), 16)
	if b.Cap then
		addText("⛔ Bids capped at " .. tostring(b.Cap) .. "c in this bracket!", 14, Color3.fromRGB(255, 200, 120))
	end
	-- quick-bid buttons
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 52)
	row.BackgroundTransparency = 1
	row.Parent = aucList
	local incs = { 25, 50, 100, 250 }
	for k, inc in incs do
		local bid = (i.TopBid :: number) + inc
		local bb2 = button(row, "+" .. tostring(inc) .. " (" .. tostring(bid) .. "c)",
			UDim2.new(0.24, -4, 1, 0), UDim2.new((k - 1) * 0.25, 2, 0, 0), Color3.fromRGB(70, 120, 200))
		;(bb2 :: TextButton).TextSize = 14
		(bb2 :: TextButton).MouseButton1Click:Connect(function()
			R("AuctionBid"):FireServer(bid)
		end)
	end
end

R("AuctionState").OnClientEvent:Connect(function(info: { [string]: any })
	aucInfo = info
	if openPanel == "Auction" then refreshAuction() end
end)

-- live countdown ticker while the panel is open (v47: updates the countdown
-- label in place instead of rebuilding the whole panel every second)
task.spawn(function()
	while true do
		task.wait(1)
		if openPanel == "Auction" and aucInfo and (aucInfo :: { [string]: any }).Active then
			local i = aucInfo :: { [string]: any }
			local left = math.max(0, (i.EndsAt :: number) - os.time())
			if aucCountdown and aucCountdown.Parent then
				aucCountdown.Text = "⏳ " .. tostring(left) .. "s left"
				aucCountdown.TextColor3 = if left <= 10 then Color3.fromRGB(255, 120, 120) else Color3.fromRGB(150, 220, 150)
			else
				refreshAuction()
			end
		end
	end
end)

end
-- ============================================================================
-- STARTER PROMPT (brand-new players pick 1 of 3)
local starterFrame: any, relayoutStarters: any -- §escapes: STARTER PROMPT (brand-new players pick 1 of 3)
do
-- ============================================================================
starterFrame= Instance.new("Frame")
starterFrame.Size = UDim2.new(1, 0, 1, 0)
starterFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
starterFrame.BackgroundTransparency = 0.15
starterFrame.Visible = false
starterFrame.Parent = gui
corner(starterFrame, 0)
label(starterFrame, "🌱 Choose your starter pet! 🌱", UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 0.08, 0), 30, Color3.fromRGB(255, 230, 150)).TextXAlignment = Enum.TextXAlignment.Center
label(starterFrame, "It's permanent — it can never be sold or traded. Grow it to evolve it twice!",
	UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0.08, 52), 16, Color3.fromRGB(200, 200, 210)).TextXAlignment = Enum.TextXAlignment.Center

local STARTER_IDS = { "Leafpup", "Cindercub", "Bubblin" }
do
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(0.96, 0, 0.6, 0)
	holder.Position = UDim2.new(0.02, 0, 0.2, 0)
	holder.BackgroundTransparency = 1
	holder.Parent = starterFrame
	-- v47: one card builder shared by both layouts
	local function buildStarterCard(pid: string): Frame
		local pdef = (PetData.PETS :: { [string]: any })[pid]
		local card = Instance.new("Frame")
		card.Size = UDim2.new(0, 220, 0, 330)
		card.BackgroundColor3 = Color3.fromRGB(42, 36, 66)
		-- v47.7: hard floor on card size — a bad first-frame viewport read
		-- used to collapse the starter cards into a thin vertical strip.
		local cardCap = Instance.new("UISizeConstraint")
		cardCap.MinSize = Vector2.new(190, 330)
		cardCap.MaxSize = Vector2.new(340, 330)
		cardCap.Parent = card
		corner(card, 12)
		-- v36: vivid type-colored glow around each starter card
		local cglow = Instance.new("UIStroke")
		cglow.Color = typeColor(pdef.Type)
		cglow.Thickness = 3
		cglow.Transparency = 0.3
		cglow.Parent = card
		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.new(1, 0, 0, 10)
		stripe.BackgroundColor3 = typeColor(pdef.Type)
		stripe.BorderSizePixel = 0
		stripe.Parent = card
		corner(stripe, 5)
		-- 3D portrait: live preview of the actual pet model
		local vf = Instance.new("ViewportFrame")
		vf.Size = UDim2.new(1, -20, 0, 150)
		vf.Position = UDim2.new(0, 10, 0, 16)
		vf.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
		vf.BorderSizePixel = 0
		vf.Parent = card
		corner(vf, 10)
		local pmodel = PetData.BuildPetModel(pid, 1.0, nil)
		pmodel.Parent = vf
		local vcam = Instance.new("Camera")
		vcam.CFrame = CFrame.new(Vector3.new(3.6, 3.4, 5.6), Vector3.new(0, 2.3, 0))
		vcam.Parent = vf
		vf.CurrentCamera = vcam
		label(card, (pdef.Name :: string), UDim2.new(1, -20, 0, 32), UDim2.new(0, 10, 0, 170), 22).TextXAlignment = Enum.TextXAlignment.Center
		label(card, (pdef.Type :: string) .. " type", UDim2.new(1, -20, 0, 22), UDim2.new(0, 10, 0, 202), 15, typeColor(pdef.Type)).TextXAlignment = Enum.TextXAlignment.Center
		local desc = label(card, (pdef.Desc or ""),
			UDim2.new(1, -20, 0, 44), UDim2.new(0, 10, 0, 226), 12, Color3.fromRGB(180, 180, 190))
		desc.TextWrapped = true
		desc.TextXAlignment = Enum.TextXAlignment.Center
		local b = button(card, "Choose!", UDim2.new(1, -20, 0, 46), UDim2.new(0, 10, 1, -56), Color3.fromRGB(40, 200, 95))
		local idCopy = pid
		b.MouseButton1Click:Connect(function()
			R("ChooseStarter"):FireServer(idCopy)
		end)
		return card
	end
	-- v47: phones (<720px) get a vertical scrolling stack of width-clamped
	-- cards; wider screens keep the original horizontal trio
	relayoutStarters = function()
		for _, c in holder:GetChildren() do c:Destroy() end
		-- v47.7: use the real GUI size first. CurrentCamera.ViewportSize can
		-- be 0/tiny on the exact frame StarterPrompt arrives in Studio, which
		-- made the phone branch build near-zero-width cards.
		local vw = gui.AbsoluteSize.X
		if vw < 200 then
			local cam = workspace.CurrentCamera
			if cam then vw = cam.ViewportSize.X end
		end
		if vw < 200 then vw = 1024 end
		if vw < 720 then
			local scroll = Instance.new("ScrollingFrame")
			scroll.Size = UDim2.new(1, 0, 1, 0)
			scroll.BackgroundTransparency = 1
			scroll.ScrollBarThickness = 4
			scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y -- v47: fit the 3 stacked cards
			scroll.Parent = holder
			local lay = Instance.new("UIListLayout")
			lay.FillDirection = Enum.FillDirection.Vertical
			lay.Padding = UDim.new(0, 12)
			lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
			lay.Parent = scroll
			for i, pid in STARTER_IDS do
				local card = buildStarterCard(pid)
				card.LayoutOrder = i
				card.Size = UDim2.new(0, math.clamp(math.floor(vw * 0.9), 230, 320), 0, 330)
				card.Parent = scroll
			end
		else
			local lay = Instance.new("UIListLayout")
			lay.FillDirection = Enum.FillDirection.Horizontal
			lay.Padding = UDim.new(0, 12)
			lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
			lay.VerticalAlignment = Enum.VerticalAlignment.Center
			lay.Parent = holder
			local cardW = math.clamp(math.floor((vw - 36) / 3), 190, 220)
			for i, pid in STARTER_IDS do
				local card = buildStarterCard(pid)
				card.LayoutOrder = i
				card.Size = UDim2.new(0, cardW, 0, 330)
				card.Parent = holder
			end
		end
	end
	relayoutStarters()
end

end
-- ============================================================================
-- GENERIC YES/NO PROMPT (battle/trade invites)
local askYesNo: any -- §escapes: GENERIC YES/NO PROMPT (battle/trade invites)
do
-- ============================================================================
local promptFrame = Instance.new("Frame")
promptFrame.Size = UDim2.new(0.9, 0, 0, 170) -- v47: scale so 320px phones fit
promptFrame.Position = UDim2.new(0.05, 0, 0.35, 0)
local promptCap = Instance.new("UISizeConstraint")
promptCap.MaxSize = Vector2.new(380, 170)
promptCap.Parent = promptFrame
promptFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
promptFrame.Visible = false
promptFrame.ZIndex = 70 -- v47: invites stay visible/clickable above popups and panels
promptFrame.Parent = gui
corner(promptFrame, 12)
local promptText = label(promptFrame, "", UDim2.new(1, -20, 0, 80), UDim2.new(0, 10, 0, 10), 17)
promptText.TextWrapped = true
promptText.TextXAlignment = Enum.TextXAlignment.Center
local promptYes = button(promptFrame, "Accept", UDim2.new(0.45, 0, 0, 48), UDim2.new(0.03, 0, 1, -60), Color3.fromRGB(70, 150, 70))
local promptNo = button(promptFrame, "Decline", UDim2.new(0.45, 0, 0, 48), UDim2.new(0.52, 0, 1, -60), Color3.fromRGB(170, 70, 70))
local promptCb: ((boolean) -> ())? = nil
promptYes.MouseButton1Click:Connect(function() promptFrame.Visible = false if promptCb then promptCb(true) end end)
promptNo.MouseButton1Click:Connect(function() promptFrame.Visible = false if promptCb then promptCb(false) end end)

askYesNo = function(text: string, cb: (boolean) -> ())
	promptText.Text = text
	promptCb = cb
	promptFrame.Visible = true
end

end
-- ============================================================================
-- BATTLE UI
local battleFrame: any, battleTurn: any, pickFrame: any, openFighterPicker: any, refreshBattleUI: any, battleAwaiting: any -- §escapes: BATTLE UI
do
-- ============================================================================
battleAwaiting = false -- v47.5: true between tap and server update (instant button feedback)
battleFrame= Instance.new("Frame")
battleFrame.Size = UDim2.new(0.96, 0, 0.9, 0) -- v47: taller + scale-based guts so short phones fit
battleFrame.Position = UDim2.new(0.02, 0, 0.05, 0)
battleFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 38)
battleFrame.Visible = false
battleFrame.Parent = gui
corner(battleFrame, 14)

local battleTitle = label(battleFrame, "⚔️ BATTLE!", UDim2.new(1, -20, 0, 40), UDim2.new(0, 10, 0, 6), 26, Color3.fromRGB(255, 150, 150))
battleTitle.TextXAlignment = Enum.TextXAlignment.Center
battleTurn= label(battleFrame, "", UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 46), 16, Color3.fromRGB(255, 230, 150))
battleTurn.TextXAlignment = Enum.TextXAlignment.Center

-- v47: fighter blocks use scale widths (the old fixed 340px bars overflowed
-- phones) and the name sits ABOVE the bar (the old HP text overlapped it).
local function fighterBlock(y: number): (TextLabel, Frame, TextLabel)
	local name = label(battleFrame, "", UDim2.new(0.88, 0, 0, 24), UDim2.new(0.06, 0, 0, y), 17)
	name.TextXAlignment = Enum.TextXAlignment.Center
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(0.88, 0, 0, 16)
	bg.Position = UDim2.new(0.06, 0, 0, y + 26)
	bg.BackgroundColor3 = Color3.fromRGB(60, 20, 25)
	bg.BorderSizePixel = 0
	bg.Parent = battleFrame
	corner(bg, 8)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(80, 200, 90)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	corner(fill, 8)
	local txt = label(battleFrame, "", UDim2.new(0.88, 0, 0, 20), UDim2.new(0.06, 0, 0, y + 44), 13)
	txt.TextXAlignment = Enum.TextXAlignment.Center
	return name, fill, txt
end

local foeName, foeFill, foeTxt = fighterBlock(80) -- v47.2: was 70, overlapped battleTurn (ends y74)
local youName, youFill, youTxt = fighterBlock(182) -- v47.2: shifted with foe block
local vsLabel = label(battleFrame, "VS", UDim2.new(0.88, 0, 0, 24), UDim2.new(0.06, 0, 0, 150), 20, Color3.fromRGB(255, 120, 120))
vsLabel.TextXAlignment = Enum.TextXAlignment.Center

-- v47: the log flexes with the frame height (old fixed 130px log overlapped
-- the buttons on short landscape phones)
local battleLog = label(battleFrame, "", UDim2.new(0.94, 0, 1, -326), UDim2.new(0.03, 0, 0, 252), 14, Color3.fromRGB(210, 210, 220))
battleLog.TextWrapped = true
battleLog.TextYAlignment = Enum.TextYAlignment.Top

local btnAttack = button(battleFrame, "👊 Attack", UDim2.new(0.23, 0, 0, 52), UDim2.new(0.02, 0, 1, -62), Color3.fromRGB(180, 80, 60))
local btnStrong = button(battleFrame, "💥 Strong", UDim2.new(0.23, 0, 0, 52), UDim2.new(0.265, 0, 1, -62), Color3.fromRGB(150, 60, 160))
local btnPotion = button(battleFrame, "🧪 Potion", UDim2.new(0.23, 0, 0, 52), UDim2.new(0.51, 0, 1, -62), Color3.fromRGB(60, 130, 180))
local btnForfeit = button(battleFrame, "🏳️ Flee", UDim2.new(0.23, 0, 0, 52), UDim2.new(0.755, 0, 1, -62), Color3.fromRGB(100, 100, 110))
btnAttack.TextSize = 14 -- v47: 14px keeps labels inside the narrower phone buttons
btnStrong.TextSize = 14
btnPotion.TextSize = 14
btnForfeit.TextSize = 14
-- v47: re-opens the fighter picker if it was closed (it now has an X)
local btnChoose = button(battleFrame, "⚔️ Choose Fighter", UDim2.new(0.5, 0, 0, 52), UDim2.new(0.25, 0, 1, -62), Color3.fromRGB(70, 130, 200))
btnChoose.TextSize = 16
btnChoose.Visible = false
btnChoose.MouseButton1Click:Connect(function() openFighterPicker() end)
-- v47.5: instant tap feedback — action buttons hide the moment you tap so there's
-- no dead air wondering if it registered. The next BattleUpdate re-shows them;
-- a 3s failsafe covers a server-rejected tap (no update ever arrives).
local function battleAct(remoteName: string, arg: number?)
	if battleAwaiting then return end
	battleAwaiting = true
	refreshBattleUI()
	if arg == nil then R(remoteName):FireServer() else R(remoteName):FireServer(arg) end
	task.delay(3, function()
		if battleAwaiting then
			battleAwaiting = false
			refreshBattleUI()
		end
	end)
end
btnAttack.MouseButton1Click:Connect(function() battleAct("BattleAttack", 1) end)
btnStrong.MouseButton1Click:Connect(function() battleAct("BattleAttack", 2) end)
btnPotion.MouseButton1Click:Connect(function() battleAct("BattleUsePotion", nil) end)
btnForfeit.MouseButton1Click:Connect(function() R("BattleForfeit"):FireServer() end)

local function setFighterUI(fill: Frame, txt: TextLabel, nameLbl: TextLabel, f: { [string]: any }?)
	if not f then
		fill.Size = UDim2.new(0, 0, 1, 0)
		txt.Text = "waiting..."
		nameLbl.Text = "???"
		return
	end
	local pct = math.clamp((f.HP or 0) / math.max(1, f.MaxHP or 1), 0, 1)
	fill.Size = UDim2.new(pct, 0, 1, 0)
	fill.BackgroundColor3 = if pct > 0.5 then Color3.fromRGB(80, 200, 90)
		elseif pct > 0.25 then Color3.fromRGB(230, 180, 60) else Color3.fromRGB(220, 70, 70)
	txt.Text = "❤️ " .. math.floor(f.HP) .. "/" .. f.MaxHP
	local stars = string.rep("⭐", math.min(f.Stars or 0, 5))
	nameLbl.Text = (if f.Titan then "👑 " else "") .. tostring(f.Name) .. " [" .. tostring(f.Type) .. "] " .. stars
		.. (if f.Skin then " 🎨" else "") -- v12: Titans + skins show in battle
	nameLbl.TextColor3 = typeColor(tostring(f.Type))
end

-- fighter picker (from battle team only)
pickFrame= Instance.new("Frame")
pickFrame.Size = UDim2.new(0.9, 0, 0.7, 0)
pickFrame.Position = UDim2.new(0.05, 0, 0.15, 0)
pickFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
pickFrame.Visible = false
pickFrame.ZIndex = 65 -- v47: modal picker paints above the battle frame + popups
pickFrame.Parent = gui
corner(pickFrame, 12)
local pickX = button(pickFrame, "X", UDim2.new(0, 40, 0, 32), UDim2.new(1, -48, 0, 8), Color3.fromRGB(170, 70, 70))
pickX.ZIndex = 66
pickX.MouseButton1Click:Connect(function() pickFrame.Visible = false end) -- re-open via ⚔️ Choose Fighter
local pickTitle = label(pickFrame, "Choose your fighter! (from battle team)", UDim2.new(1, -60, 0, 54), UDim2.new(0, 10, 0, 8), 19, Color3.fromRGB(255, 200, 150))
pickTitle.TextXAlignment = Enum.TextXAlignment.Center
pickTitle.TextWrapped = true -- v47: was truncating on narrow screens
local pickScroll = Instance.new("ScrollingFrame")
pickScroll.Size = UDim2.new(1, -16, 1, -74)
pickScroll.Position = UDim2.new(0, 8, 0, 66)
pickScroll.BackgroundTransparency = 1
pickScroll.ScrollBarThickness = 6
pickScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
pickScroll.Parent = pickFrame
local pickLayout = Instance.new("UIListLayout")
pickLayout.Padding = UDim.new(0, 8)
pickLayout.Parent = pickScroll

openFighterPicker = function()
	for _, c in pickScroll:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	local order = 0
	local anyValid = false
	for slot = 1, 5 do
		local rec = teamSlots[slot]
		if rec then
			order += 1
			local alive = math.floor(rec.HP or 0) > 0
			if alive then anyValid = true end
			local uid = rec.Uid
			addPetCard(pickScroll, rec, order, {
				{ Text = if alive then "⚔️ FIGHT!" else "💤 KO'd", Color = if alive then Color3.fromRGB(180, 70, 70) else Color3.fromRGB(90, 90, 100),
					OnClick = function()
						if alive then
							R("BattlePickFighter"):FireServer(uid)
							pickFrame.Visible = false
						else
							toast("That pet is knocked out — wait for it to recover! 💤", "warn")
						end
					end },
			})
		end
	end
	if not anyValid then
		order += 1
		label(pickScroll, "No healthy team pets! Add pets to your team (🛡️ Team) and let KO'd pets recover.",
			UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 0, 0), 15, Color3.fromRGB(200, 170, 170)).LayoutOrder = order
	end
	pickFrame.Visible = true
end

refreshBattleUI = function()
	local v = battleView
	if not v then return end
	battleFrame.Visible = true
	if not v.BothPicked then
		battleTitle.Text = "⚔️ Pick your fighter!"
		battleTurn.Text = "Waiting for both players to choose..."
		setFighterUI(youFill, youTxt, youName, v.You)
		setFighterUI(foeFill, foeTxt, foeName, v.Foe)
		btnChoose.Visible = true -- v47: picker is closable now, so it can be re-opened
		btnAttack.Visible = false
		btnStrong.Visible = false
		btnPotion.Visible = false
		return
	end
	battleTitle.Text = "⚔️ BATTLE!"
	battleTurn.Text = if v.YourTurn
		then "🟢 YOUR TURN! (" .. v.TurnEndsIn .. "s)"
		else "🔴 Opponent's turn... (" .. v.TurnEndsIn .. "s)"
	setFighterUI(youFill, youTxt, youName, v.You)
	setFighterUI(foeFill, foeTxt, foeName, v.Foe)
	local logBits = {}
	for _, line in (v.Log :: { string }) do table.insert(logBits, line) end
	battleLog.Text = table.concat(logBits, "\n")
	local canAct = v.YourTurn and v.BothPicked and not battleAwaiting -- v47.5: hide while awaiting server
	btnChoose.Visible = not v.BothPicked
	btnAttack.Visible = canAct
	btnStrong.Visible = canAct
	btnPotion.Visible = canAct and not v.YouPotionUsed
	if v.You then
		btnStrong.Text = "💥 Strong (" .. (v.You.StrongLeft or 0) .. ")"
	end
end

end
-- ============================================================================
-- TRADE UI
local tradeFrame: any, tradePickFrame: any, coinBox: any, refreshTradeUI: any -- §escapes: TRADE UI
do
-- ============================================================================
tradeFrame= Instance.new("Frame")
tradeFrame.Size = UDim2.new(0.96, 0, 0.9, 0) -- v47: taller; bottom rows anchor so short phones don't overlap
tradeFrame.Position = UDim2.new(0.02, 0, 0.05, 0)
tradeFrame.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
tradeFrame.Visible = false
tradeFrame.Parent = gui
corner(tradeFrame, 14)
local tradeTitle = label(tradeFrame, "🔄 TRADE", UDim2.new(1, -20, 0, 30), UDim2.new(0, 10, 0, 4), 22, Color3.fromRGB(150, 200, 255))
tradeTitle.TextXAlignment = Enum.TextXAlignment.Center

local tradeYouLbl = label(tradeFrame, "YOU", UDim2.new(0.44, 0, 0, 22), UDim2.new(0.03, 0, 0, 36), 17, Color3.fromRGB(150, 220, 150))
local tradeThemLbl = label(tradeFrame, "THEM", UDim2.new(0.44, 0, 0, 22), UDim2.new(0.53, 0, 0, 36), 17, Color3.fromRGB(220, 150, 150))
local tradeYouOffer = label(tradeFrame, "", UDim2.new(0.44, 0, 0, 62), UDim2.new(0.03, 0, 0, 60), 14, Color3.fromRGB(210, 210, 220))
local tradeThemOffer = label(tradeFrame, "", UDim2.new(0.44, 0, 0, 62), UDim2.new(0.53, 0, 0, 60), 14, Color3.fromRGB(210, 210, 220))
tradeYouOffer.TextWrapped = true
tradeThemOffer.TextWrapped = true
tradeYouOffer.TextYAlignment = Enum.TextYAlignment.Top
tradeThemOffer.TextYAlignment = Enum.TextYAlignment.Top
local tradeStatus = label(tradeFrame, "", UDim2.new(0.94, 0, 0, 22), UDim2.new(0.03, 0, 0, 124), 15, Color3.fromRGB(255, 230, 150))
tradeStatus.TextXAlignment = Enum.TextXAlignment.Center

local function offerText(o: { [string]: any }): string
	if not o then return "nothing" end
	local bits = {}
	if o.Pet then
		local p = o.Pet :: { [string]: any }
		bits[#bits + 1] = tostring(p.Name) .. " [" .. tostring(p.Type) .. "]"
			.. string.rep("⭐", math.min(p.Stars or 0, 5))
	end
	if (o.Coins or 0) > 0 then bits[#bits + 1] = "💰 " .. o.Coins end
	if #bits == 0 then return "nothing" end
	return table.concat(bits, " + ")
end

-- pet picker for trade (starters locked out)
tradePickFrame= Instance.new("Frame")
tradePickFrame.Size = UDim2.new(0.9, 0, 0.7, 0)
tradePickFrame.Position = UDim2.new(0.05, 0, 0.15, 0)
tradePickFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
tradePickFrame.Visible = false
tradePickFrame.ZIndex = 65 -- v47: modal picker above the trade frame + popups
tradePickFrame.Parent = gui
corner(tradePickFrame, 12)
local tradePickX = button(tradePickFrame, "X", UDim2.new(0, 40, 0, 32), UDim2.new(1, -48, 0, 8), Color3.fromRGB(170, 70, 70))
tradePickX.ZIndex = 66
tradePickX.MouseButton1Click:Connect(function() tradePickFrame.Visible = false end)
local tradePickTitle = label(tradePickFrame, "Choose a pet to offer (starters can't be traded 🔒)", UDim2.new(1, -60, 0, 54), UDim2.new(0, 10, 0, 8), 16, Color3.fromRGB(255, 200, 150))
tradePickTitle.TextXAlignment = Enum.TextXAlignment.Center
tradePickTitle.TextWrapped = true -- v47: was truncating on narrow screens
local tradePickScroll = Instance.new("ScrollingFrame")
tradePickScroll.Size = UDim2.new(1, -16, 1, -74)
tradePickScroll.Position = UDim2.new(0, 8, 0, 66)
tradePickScroll.BackgroundTransparency = 1
tradePickScroll.ScrollBarThickness = 6
tradePickScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
tradePickScroll.Parent = tradePickFrame
local tradePickLayout = Instance.new("UIListLayout")
tradePickLayout.Padding = UDim.new(0, 8)
tradePickLayout.Parent = tradePickScroll

local function pushTradeOffer()
	R("TradeOffer"):FireServer(tradeOfferUid or "", tradeOfferCoins)
end

local function openTradePicker()
	for _, c in tradePickScroll:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	local order = 0
	-- "no pet" option
	order += 1
	local noneB = button(tradePickScroll, "Offer no pet (coins only)", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 0), Color3.fromRGB(80, 80, 100))
	noneB.LayoutOrder = order
	noneB.MouseButton1Click:Connect(function()
		tradeOfferUid = nil
		tradePickFrame.Visible = false
		pushTradeOffer()
	end)
	for _, rec in inventory do
		order += 1
		local uid = rec.Uid
		if rec.IsStarter then
			local card = addPetCard(tradePickScroll, rec, order, nil)
			label(card, "🔒 Can't trade starter", UDim2.new(0, 150, 0, 26), UDim2.new(1, -160, 0, 60), 13, Color3.fromRGB(200, 150, 150))
		else
			addPetCard(tradePickScroll, rec, order, {
				{ Text = "Offer this", Color = Color3.fromRGB(70, 110, 200),
					OnClick = function()
						tradeOfferUid = uid
						tradePickFrame.Visible = false
						pushTradeOffer()
					end },
			})
		end
	end
	tradePickFrame.Visible = true
end

local tradePickPetB = button(tradeFrame, "🐾 Choose Pet", UDim2.new(0.44, 0, 0, 42), UDim2.new(0.03, 0, 0, 150), Color3.fromRGB(70, 110, 200))
tradePickPetB.MouseButton1Click:Connect(openTradePicker)
coinBox= Instance.new("TextBox")
coinBox.Size = UDim2.new(0.26, 0, 0, 42)
coinBox.Position = UDim2.new(0.49, 0, 0, 150)
coinBox.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
coinBox.Text = "0"
coinBox.PlaceholderText = "Coins"
coinBox.TextSize = 16
coinBox.TextColor3 = Color3.fromRGB(255, 220, 120)
coinBox.Font = Enum.Font.FredokaOne
coinBox.Parent = tradeFrame
corner(coinBox, 8)
local coinSetB = button(tradeFrame, "Set 💰", UDim2.new(0.18, -8, 0, 42), UDim2.new(0.75, 8, 0, 150), Color3.fromRGB(150, 110, 60))
local function setTradeCoins() -- v47.5: extracted so Enter key shares it
	tradeOfferCoins = math.max(0, math.floor(tonumber(coinBox.Text) or 0))
	coinBox.Text = tostring(tradeOfferCoins)
	pushTradeOffer()
end
coinSetB.MouseButton1Click:Connect(setTradeCoins)
coinBox.FocusLost:Connect(function(enterPressed: boolean) -- v47.5: Enter sets the offer, one less tap
	if enterPressed then setTradeCoins() end
end)
local tradeConfirmB = button(tradeFrame, "✅ Confirm", UDim2.new(0.44, 0, 0, 46), UDim2.new(0.03, 0, 1, -100), Color3.fromRGB(70, 150, 70))
local tradeCancelB = button(tradeFrame, "❌ Cancel", UDim2.new(0.44, 0, 0, 46), UDim2.new(0.53, 0, 1, -100), Color3.fromRGB(170, 70, 70))
tradeConfirmB.MouseButton1Click:Connect(function() R("TradeConfirm"):FireServer() end)
tradeCancelB.MouseButton1Click:Connect(function() R("TradeCancel"):FireServer() end)
local tradeWarn = label(tradeFrame, "⚠️ Changing your offer resets BOTH confirmations. Server re-checks everything at the moment of the swap.",
	UDim2.new(0.94, 0, 0, 38), UDim2.new(0.03, 0, 1, -46), 12, Color3.fromRGB(200, 170, 150))
tradeWarn.TextWrapped = true
tradeWarn.TextXAlignment = Enum.TextXAlignment.Center

refreshTradeUI = function()
	local v = tradeView
	if not v then return end
	tradeFrame.Visible = true
	tradeYouOffer.Text = "Offers: " .. offerText(v.You) .. (if v.You.Confirmed then "\n✅ CONFIRMED" else "\n…not confirmed")
	tradeThemOffer.Text = "Offers: " .. offerText(v.Them) .. (if v.Them.Confirmed then "\n✅ CONFIRMED" else "\n…not confirmed")
	tradeStatus.Text = "Your coins: 💰 " .. (v.YourCoins or 0)
		.. "   |   You: " .. (if v.You.Confirmed then "✅" else "❌")
		.. "  Them: " .. (if v.Them.Confirmed then "✅" else "❌")
	-- v47.5: nudge — when they've confirmed and you haven't, the confirm button calls out
	if v.Them.Confirmed and not v.You.Confirmed then
		tradeConfirmB.Text = "✅ CONFIRM!"
		tradeConfirmB.BackgroundColor3 = Color3.fromRGB(90, 200, 90)
	else
		tradeConfirmB.Text = "✅ Confirm"
		tradeConfirmB.BackgroundColor3 = Color3.fromRGB(70, 150, 70)
	end
end

end
-- ============================================================================
-- RENAME MODAL (pet nicknames)
local closeRename: any -- §escapes: RENAME MODAL (pet nicknames)
do
-- ============================================================================
local renameFrame = Instance.new("Frame")
renameFrame.Name = "RenameModal"
renameFrame.Size = UDim2.new(1, 0, 1, 0)
renameFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
renameFrame.BackgroundTransparency = 0.4
renameFrame.Visible = false
renameFrame.ZIndex = 50
renameFrame.Parent = gui
local renameBox = Instance.new("Frame")
renameBox.Size = UDim2.new(0.9, 0, 0, 200) -- v47: scale so 320px phones fit
renameBox.Position = UDim2.new(0.05, 0, 0.5, -100)
local renameCap = Instance.new("UISizeConstraint")
renameCap.MaxSize = Vector2.new(360, 200)
renameCap.Parent = renameBox
renameBox.BackgroundColor3 = Color3.fromRGB(40, 32, 55)
renameBox.Parent = renameFrame
corner(renameBox, 12)
renameBox.ZIndex = 51 -- v47: dialog above the dim (Global ZIndex compares children against parents)
label(renameBox, "✏️ Name your pet", UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 0, 8), 20, Color3.fromRGB(255, 220, 150))
local renameInput = Instance.new("TextBox")
renameInput.Size = UDim2.new(1, -20, 0, 48)
renameInput.Position = UDim2.new(0, 10, 0, 52)
renameInput.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
renameInput.Text = ""
renameInput.PlaceholderText = "Max 16 characters..."
renameInput.TextSize = 18
renameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
renameInput.Font = Enum.Font.FredokaOne
renameInput.ClearTextOnFocus = false
renameInput.Parent = renameBox
corner(renameInput, 8)
local renameUid: string? = nil
closeRename = function()
	renameFrame.Visible = false
	renameUid = nil
end
openRename = function(uid: string, current: string)
	renameUid = uid
	renameInput.Text = current or ""
	renameFrame.Visible = true
end
local renameSave = button(renameBox, "✅ Save", UDim2.new(0.47, 0, 0, 48), UDim2.new(0, 10, 0, 116), Color3.fromRGB(70, 150, 70))
local renameCancel = button(renameBox, "❌ Cancel", UDim2.new(0.47, 0, 0, 48), UDim2.new(0.53, -10, 0, 116), Color3.fromRGB(170, 70, 70))
renameSave.MouseButton1Click:Connect(function()
	if renameUid then
		local txt = string.gsub(renameInput.Text or "", "^%s+", "")
		txt = string.gsub(txt, "%s+$", "")
		if #txt > 16 then
			toast("Keep it under 16 characters!", "warn")
			return
		end
		R("RenamePet"):FireServer(renameUid, txt)
	end
	closeRename()
end)
renameCancel.MouseButton1Click:Connect(closeRename)
-- v47: everything inside the dialog paints above the dim (Global ZIndex)
for _, d in renameBox:GetDescendants() do
	if d:IsA("GuiObject") then d.ZIndex = 52 end
end

end
-- ============================================================================
-- SKIN PICKER MODAL (v12: custom pet skins)
do
-- ============================================================================
local skinFrame = Instance.new("Frame")
skinFrame.Name = "SkinModal"
skinFrame.Size = UDim2.new(1, 0, 1, 0)
skinFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
skinFrame.BackgroundTransparency = 0.4
skinFrame.Visible = false
skinFrame.ZIndex = 50
skinFrame.Parent = gui
local skinBox = Instance.new("Frame")
skinBox.ZIndex = 51 -- v47: dialog above the dim (Global ZIndex compares children against parents)
skinBox.Size = UDim2.new(0.92, 0, 0, 340) -- v47: scale so 320px phones fit
skinBox.Position = UDim2.new(0.04, 0, 0.5, -170)
local skinCap = Instance.new("UISizeConstraint")
skinCap.MaxSize = Vector2.new(380, 340)
skinCap.Parent = skinBox
skinBox.BackgroundColor3 = Color3.fromRGB(40, 32, 55)
skinBox.Parent = skinFrame
corner(skinBox, 12)
label(skinBox, "🎨 Pick a skin", UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 0, 8), 20, Color3.fromRGB(255, 220, 150))
label(skinBox, "Cosmetic only — bought once in the shop, applied per pet.", UDim2.new(1, -20, 0, 30), UDim2.new(0, 10, 0, 44), 13, Color3.fromRGB(190, 170, 200))
local skinList = Instance.new("ScrollingFrame")
skinList.Size = UDim2.new(1, -20, 0, 180)
skinList.Position = UDim2.new(0, 10, 0, 80)
skinList.BackgroundTransparency = 1
skinList.ScrollBarThickness = 6
skinList.Parent = skinBox
local skinLayout = Instance.new("UIListLayout")
skinLayout.Padding = UDim.new(0, 6)
skinLayout.Parent = skinList
local skinUid: string? = nil
local function closeSkin()
	skinFrame.Visible = false
	skinUid = nil
end
openSkinPicker = function(uid: string, current: string?)
	skinUid = uid
	for _, c in skinList:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	local order = 0
	-- "None" row: clear the skin
	order += 1
	local noneRow = Instance.new("Frame")
	noneRow.Size = UDim2.new(1, -6, 0, 52)
	noneRow.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
	noneRow.LayoutOrder = order
	noneRow.Parent = skinList
	corner(noneRow, 8)
	label(noneRow, (if current == nil then "✅ " else "") .. "None", UDim2.new(1, -120, 0, 24), UDim2.new(0, 10, 0, 4), 16, Color3.fromRGB(230, 230, 235))
	label(noneRow, "Plain and natural", UDim2.new(1, -120, 0, 20), UDim2.new(0, 10, 0, 28), 12, Color3.fromRGB(180, 180, 190))
	local noneB = button(noneRow, "Apply", UDim2.new(0, 100, 0, 40), UDim2.new(1, -110, 0, 6), Color3.fromRGB(90, 90, 110))
	noneB.TextSize = 14
	noneB.MouseButton1Click:Connect(function()
		if skinUid then R("SetSkin"):FireServer(skinUid, "None") end
		closeSkin()
	end)
	-- owned skins
	for _, sid in ownedSkins do
		local sdef = (Config.Skins :: { [string]: any })[sid]
		if sdef then
			order += 1
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -6, 0, 52)
			row.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
			row.LayoutOrder = order
			row.Parent = skinList
			corner(row, 8)
			label(row, (if current == sid then "✅ " else "") .. "🎨 " .. tostring(sdef.Name), UDim2.new(1, -120, 0, 24), UDim2.new(0, 10, 0, 4), 16, Color3.fromRGB(230, 230, 235))
			label(row, tostring(sdef.Desc), UDim2.new(1, -120, 0, 20), UDim2.new(0, 10, 0, 28), 12, Color3.fromRGB(180, 180, 190))
			local ab = button(row, "Apply", UDim2.new(0, 100, 0, 40), UDim2.new(1, -110, 0, 6), Color3.fromRGB(110, 90, 200))
			ab.TextSize = 14
			ab.MouseButton1Click:Connect(function()
				if skinUid then R("SetSkin"):FireServer(skinUid, sid) end
				closeSkin()
			end)
		end
	end
	if #ownedSkins == 0 then
		order += 1
		label(skinList, "No skins yet — visit the shop! 🛍️", UDim2.new(1, -6, 0, 40), UDim2.new(0, 0, 0, 0), 14, Color3.fromRGB(190, 170, 200)).LayoutOrder = order
	end
	-- v47: everything inside the dialog paints above the dim (Global ZIndex)
	for _, d in skinBox:GetDescendants() do
		if d:IsA("GuiObject") then d.ZIndex = 52 end
	end
	skinFrame.Visible = true
end
local skinCancel = button(skinBox, "❌ Close", UDim2.new(0, 150, 0, 44), UDim2.new(0.5, -75, 1, -56), Color3.fromRGB(170, 70, 70))
skinCancel.MouseButton1Click:Connect(closeSkin)

end
-- ============================================================================
-- QUEST PANEL (daily quests)
local quests: { { [string]: any } }, refreshQuests: any -- §escapes: QUEST PANEL (daily quests)
do
-- ============================================================================
local questPanel, questList = makePanel("Quests", "📋 Daily Quests")
quests= {}

refreshQuests = function()
	for _, c in questList:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	local questHint = label(questList, "New quests every day at midnight! Complete them, then claim your coins. 💰",
		UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 0), 14, Color3.fromRGB(190, 190, 200))
	questHint.LayoutOrder = 1
	questHint.TextWrapped = true -- v47: was truncating on narrow screens
	local order = 1
	for _, q in quests do
		order += 1
		local qq = q :: { [string]: any }
		local done = (qq.Progress :: number) >= (qq.Target :: number)
		local claimed = qq.Claimed == true
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 76)
		row.BackgroundColor3 = if claimed then Color3.fromRGB(40, 50, 40)
			elseif done then Color3.fromRGB(60, 55, 30) else Color3.fromRGB(36, 36, 48)
		row.LayoutOrder = order
		row.Parent = questList
		corner(row, 8)
		label(row, tostring(qq.Text), UDim2.new(1, -140, 0, 28), UDim2.new(0, 10, 0, 4), 16,
			if done then Color3.fromRGB(255, 230, 150) else Color3.fromRGB(230, 230, 235))
		-- progress bar
		local barBg = Instance.new("Frame")
		barBg.Size = UDim2.new(1, -150, 0, 12)
		barBg.Position = UDim2.new(0, 10, 0, 36)
		barBg.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
		barBg.BorderSizePixel = 0
		barBg.Parent = row
		corner(barBg, 6)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(math.clamp((qq.Progress :: number) / math.max(1, (qq.Target :: number)), 0, 1), 0, 1, 0)
		fill.BackgroundColor3 = if done then Color3.fromRGB(90, 200, 90) else Color3.fromRGB(90, 150, 230)
		fill.BorderSizePixel = 0
		fill.Parent = barBg
		corner(fill, 6)
		label(row, tostring(qq.Progress) .. "/" .. tostring(qq.Target) .. "   💰" .. tostring(qq.Reward),
			UDim2.new(1, -150, 0, 20), UDim2.new(0, 10, 0, 50), 13, Color3.fromRGB(200, 200, 210))
		if done and not claimed then
			local b = button(row, "CLAIM!", UDim2.new(0, 118, 0, 60), UDim2.new(1, -128, 0, 8), Color3.fromRGB(70, 150, 70))
			b.TextSize = 15
			local idCopy = tostring(qq.Id)
			b.MouseButton1Click:Connect(function() R("ClaimQuest"):FireServer(idCopy) end)
		elseif claimed then
			label(row, "✅ claimed", UDim2.new(0, 118, 0, 60), UDim2.new(1, -128, 0, 8), 14, Color3.fromRGB(120, 200, 120))
		end
	end
	if #quests == 0 then
		label(questList, "Loading today's quests...", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), 15).LayoutOrder = 2
	end
end

end
-- ============================================================================
-- 🪨 EVOLUTION STONES PANEL (v24) — pick your evolution branch
local stoneArmed: string?, stoneBtn: TextButton?, refreshStoneBtn: any, refreshStones: any -- §escapes: 🪨 EVOLUTION STONES PANEL (v24) — pick your evolution branch
do
-- ============================================================================
local stonePanel, stoneList = makePanel("Stones", "🪨 Evolution Stones")
stoneArmed= nil -- stoneId currently armed (tap a plot to set it)
stoneBtn= nil -- created in the bottom bar below

refreshStoneBtn = function()
	if not stoneBtn then return end
	stoneBtn.Text = if stoneArmed then "🪨 SETTING…" else "🪨 Stones"
	stoneBtn.BackgroundColor3 = if stoneArmed then Color3.fromRGB(120, 90, 40) else Color3.fromRGB(62, 148, 92)
end

refreshStones = function()
	for _, c in stoneList:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	local order = 0
	order += 1
	local info = label(stoneList, "Own a stone? Tap SET, then tap one of your growing plots — that pet WILL evolve into the chosen branch. No stone = random branch as usual. Stones are consumed only if the evolution happens.",
		UDim2.new(1, 0, 0, 64), UDim2.new(0, 0, 0, 0), 14, Color3.fromRGB(190, 190, 200))
	info.TextWrapped = true
	info.LayoutOrder = order
	-- group stones by source species (only multi-branch species have stones)
	local species: { string } = {}
	for petId, _ in (PetData.EVOLUTIONS :: { [string]: any }) do
		local branches = (PetData.EVOLUTIONS :: { [string]: any })[petId]
		if #branches > 1 then table.insert(species, petId) end
	end
	table.sort(species)
	for _, fromId in species do
		order += 1
		local fromDef = (PetData.PETS :: { [string]: any })[fromId]
		local hdr = label(stoneList, "🌱 " .. ((fromDef and fromDef.Name) or fromId),
			UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 0), 17, Color3.fromRGB(255, 220, 120))
		hdr.LayoutOrder = order
		local branches = (PetData.EVOLUTIONS :: { [string]: any })[fromId]
		for _, b in branches do
			local toId: string = b.To
			local stoneId = PetData.StoneForBranch(toId)
			if stoneId then
				order += 1
				local sdef = (PetData.EVO_STONES :: { [string]: any })[stoneId]
				local toDef = (PetData.PETS :: { [string]: any })[toId]
				local have: number = (items :: { [string]: number })[stoneId] or 0
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 76)
				row.BackgroundColor3 = Color3.fromRGB(52, 44, 34)
				row.LayoutOrder = order
				row.Parent = stoneList
				corner(row, 8)
				label(row, "→ " .. ((toDef and toDef.Name) or toId) .. "  (" .. ((toDef and toDef.Type) or "?") .. ")",
					UDim2.new(1, -140, 0, 28), UDim2.new(0, 10, 0, 4), 16, Color3.fromRGB(235, 225, 200))
				local sub = tostring((sdef :: { [string]: any }).Name) .. "   •   owned: " .. have
				if have < 1 then sub ..= "   •   " .. tostring((sdef :: { [string]: any }).Price) .. "c in 🥚 Shop" end
				label(row, sub, UDim2.new(1, -140, 0, 24), UDim2.new(0, 10, 0, 36), 13, Color3.fromRGB(200, 190, 170))
				local isArmed = stoneArmed == stoneId
				local btnText = if isArmed then "Armed ✓" elseif have > 0 then "SET" else "Buy\n" .. tostring((sdef :: { [string]: any }).Price) .. "c"
				local b = button(row, btnText, UDim2.new(0, 118, 0, 60), UDim2.new(1, -128, 0, 8),
					if isArmed then Color3.fromRGB(150, 110, 40)
					elseif have > 0 then Color3.fromRGB(70, 140, 70)
					else Color3.fromRGB(110, 110, 130))
				b.TextSize = 14
				local sidCopy = stoneId
				b.MouseButton1Click:Connect(function()
					if isArmed then
						stoneArmed = nil
						R("ArmEvoStone"):FireServer("")
						refreshStoneBtn()
						refreshStones()
					elseif have > 0 then
						stoneArmed = sidCopy
						R("ArmEvoStone"):FireServer(sidCopy)
						toast("🪨 " .. tostring((sdef :: { [string]: any }).Name) .. " armed — tap one of your growing plots!", "ok")
						refreshStoneBtn()
						refreshStones()
					else
						R("BuyEvoStone"):FireServer(sidCopy)
					end
				end)
			end
		end
	end
end

end
-- ============================================================================
-- PHOTO MODE (forward-declared: implementation sits at the end of the file so
-- it can reference sidePanel / bottomBar / fishCard, which are built below)
local photoMode: boolean, setPhotoMode: ((boolean) -> ())? -- §escapes: it can reference sidePanel / bottomBar / fishCard, which are
do
-- ============================================================================
photoMode= false
setPhotoMode= nil

end
-- ============================================================================
-- v26: 🏠 PET DAYCARE + 📡 SHINY RADAR
local openDaycare: any, radarBtn: TextButton?, refreshRadarBtn: any -- §escapes: v26: 🏠 PET DAYCARE + 📡 SHINY RADAR
do
-- ============================================================================
local daycarePanel, daycareList = makePanel("Daycare", "🏠 Pet Daycare", true)
local daycareState: { { [string]: any } } = {} -- server slots preview

local function refreshDaycareUI()
	for _, c in daycareList:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	label(daycareList, "Leave pets with the keeper — they gain Bond + Care even while you're offline (up to 8h). Checking out pays the bill.",
		UDim2.new(1, -20, 0, 44), UDim2.new(0, 10, 0, 0), 13, Color3.fromRGB(200, 215, 190))
	for _, s in daycareState do
		local st = s :: { [string]: any }
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 92)
		row.BackgroundColor3 = Color3.fromRGB(50, 60, 44)
		row.LayoutOrder = (st.Slot :: number)
		row.Parent = daycareList
		corner(row, 8)
		if st.Name then
			label(row, "🏠 " .. (st.Name :: string) .. " — " .. tostring(st.Hours) .. "h so far",
				UDim2.new(1, -140, 0, 26), UDim2.new(0, 10, 0, 4), 17, Color3.fromRGB(255, 230, 170))
			label(row, "+" .. tostring(st.BondGain) .. " Bond · +" .. tostring(st.CareGain)
				.. " Care lvl · bill " .. tostring(st.Fee) .. "c",
				UDim2.new(1, -140, 0, 24), UDim2.new(0, 10, 0, 32), 13, Color3.fromRGB(200, 215, 190))
			label(row, "Care levels = +2% sell value each",
				UDim2.new(1, -140, 0, 20), UDim2.new(0, 10, 0, 58), 11, Color3.fromRGB(160, 175, 155))
			local b = button(row, "Check\nout", UDim2.new(0, 118, 0, 72),
				UDim2.new(1, -128, 0, 10), Color3.fromRGB(90, 150, 90))
			b.TextSize = 14
			local slotIdx = st.Slot :: number
			b.MouseButton1Click:Connect(function() R("DaycareCheckOut"):FireServer(slotIdx) end)
		else
			label(row, "Slot " .. tostring(st.Slot) .. " — empty",
				UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 30), 15, Color3.fromRGB(150, 160, 145))
		end
	end
	label(daycareList, "Check a pet in (starters can't stay):",
		UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, 0), 14, Color3.fromRGB(220, 230, 210))
	local shown = 0
	for _, rec in inventory do
		if shown >= 10 then break end
		local r = rec :: { [string]: any }
		if not r.IsStarter and not r.Reserved then
			shown += 1
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 56)
			row.BackgroundColor3 = Color3.fromRGB(42, 50, 40)
			row.LayoutOrder = 100 + shown
			row.Parent = daycareList
			corner(row, 8)
			label(row, PetData.PetName(rec),
				UDim2.new(1, -140, 0, 24), UDim2.new(0, 10, 0, 6), 15, Color3.fromRGB(235, 240, 225))
			label(row, "Bond " .. tostring(r.Bond or 0) .. " · Care lvl " .. tostring(r.Care or 0),
				UDim2.new(1, -140, 0, 20), UDim2.new(0, 10, 0, 30), 12, Color3.fromRGB(170, 185, 160))
			local b = button(row, "🏠\nCheck in", UDim2.new(0, 118, 0, 46),
				UDim2.new(1, -128, 0, 5), Color3.fromRGB(120, 110, 70))
			b.TextSize = 13
			local uid = r.Uid :: string
			b.MouseButton1Click:Connect(function() R("DaycareCheckIn"):FireServer(uid) end)
		end
	end
	if shown == 0 then
		label(daycareList, "No eligible pets in your bag.",
			UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, 0), 13, Color3.fromRGB(170, 180, 160))
	end
end

R("DaycareInfo").OnClientEvent:Connect(function(slots: { { [string]: any } })
	daycareState = slots or {}
	if openPanel == "Daycare" then refreshDaycareUI() end
end)

-- opening the panel (prompt on the keeper OR the 🏠 bar button)
openDaycare = function()
	refreshDaycareUI()
	if openPanel ~= "Daycare" then togglePanel("Daycare") end
end
R("DaycareOpen").OnClientEvent:Connect(function() openDaycare() end)

-- 📡 Shiny Radar: one-time gadget (25,000c). Tap to scan; on success the
-- server fires RadarPing and the radar is consumed (it shatters).
radarBtn= nil
local radarArrow: Frame? = nil -- direction overlay after a successful ping
local radarPingUntil: number = 0
local radarTarget: Vector3? = nil
local radarPetName: string = ""

refreshRadarBtn = function()
	if not radarBtn then return end
	local owned = buffs and (buffs :: { [string]: any }).RadarOwned == true
	(radarBtn :: TextButton).Visible = owned
	if owned then
		local cd = math.floor(((buffs :: { [string]: any }).RadarCooldown :: number) or 0)
		if cd > 0 then
			(radarBtn :: TextButton).Text = "📡 (" .. cd .. "s)"
		else
			(radarBtn :: TextButton).Text = "📡 Radar"
		end
	end
end

local function hideRadarArrow()
	if radarArrow then
		(radarArrow :: Frame):Destroy()
		radarArrow = nil
	end
	radarTarget = nil
	radarPingUntil = 0
end

-- compass-style arrow: points at the shiny, shows distance, auto-hides.
local function showRadarArrow()
	hideRadarArrow()
	local target = radarTarget
	if not target then return end
	local f = Instance.new("Frame")
	f.Name = "RadarArrow"
	f.Size = UDim2.new(0, 190, 0, 90)
	f.Position = UDim2.new(0.5, -95, 0, 120)
	f.BackgroundColor3 = Color3.fromRGB(20, 24, 40)
	f.BackgroundTransparency = 0.25
	f.Parent = gui
	corner(f, 12)
	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.Size = UDim2.new(0, 60, 0, 60)
	arrow.Position = UDim2.new(0, 10, 0, 15)
	arrow.BackgroundTransparency = 1
	arrow.Text = "⬆️"
	arrow.TextSize = 44
	arrow.Parent = f
	local dist = Instance.new("TextLabel")
	dist.Name = "Dist"
	dist.Size = UDim2.new(0, 110, 0, 60)
	dist.Position = UDim2.new(0, 70, 0, 15)
	dist.BackgroundTransparency = 1
	dist.Text = "📡\n—m"
	dist.TextSize = 18
	dist.TextColor3 = Color3.fromRGB(255, 240, 180)
	dist.Font = Enum.Font.FredokaOne
	dist.Parent = f
	radarArrow = f
end

-- per-frame arrow steering (camera-relative)
task.spawn(function()
	local rs = game:GetService("RunService")
	rs.RenderStepped:Connect(function()
		if not radarArrow or not radarTarget or os.time() > radarPingUntil then
			if radarArrow and os.time() > radarPingUntil then hideRadarArrow() end
			return
		end
		local cam = workspace.CurrentCamera
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not cam or not hrp then return end
		local target = radarTarget :: Vector3
		local to = (target - (hrp :: BasePart).Position)
		local flat = Vector3.new(to.X, 0, to.Z)
		if flat.Magnitude < 1 then return end
		-- camera-relative bearing: 0 = straight ahead
		local camFlat = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
		local ang = math.atan2(flat.X, flat.Z) - math.atan2(camFlat.X, camFlat.Z)
		local arr = (radarArrow :: Frame):FindFirstChild("Arrow") :: TextLabel
		local distLbl = (radarArrow :: Frame):FindFirstChild("Dist") :: TextLabel
		if arr then arr.Rotation = math.deg(ang) end
		if distLbl then distLbl.Text = "📡 ✨ " .. radarPetName .. "\n" .. math.floor(to.Magnitude) .. "m" end
	end)
end)

R("RadarPing").OnClientEvent:Connect(function(ping: { [string]: any })
	radarTarget = Vector3.new(ping.X :: number, ping.Y :: number, ping.Z :: number)
	radarPetName = tostring(ping.Pet or "SHINY")
	radarPingUntil = (ping.Until :: number) or (os.time() + 120)
	showRadarArrow()
	refreshRadarBtn() -- radar is consumed; the button hides
end)

end
-- ============================================================================
-- BOTTOM BAR
local sprayArmed: any, refreshSprayBtn: any -- §escapes: BOTTOM BAR
do
-- ============================================================================
-- v33: the bar holds 5 big category buttons; the real actions live in the
-- popup menus above it. (Declutter: 19 cramped buttons -> 5 categories.)
local petsMenu: Frame = catMenus["Pets"]
local shopMenu: Frame = catMenus["Shop"]
local playMenu: Frame = catMenus["Play"]
local socialMenu: Frame = catMenus["Social"]

-- ---- 🐾 Pets ----
menuOption(petsMenu, "🎒 Bag", function() refreshBag() togglePanel("Bag") end)
menuOption(petsMenu, "🛡️ Team", function() refreshTeam() togglePanel("Team") end)
menuOption(petsMenu, "⭐ Fuse", function() refreshFuse() togglePanel("Fuse") end)
menuOption(petsMenu, "📖 Dex", function() refreshDex() togglePanel("Dex") end)
menuOption(petsMenu, "🐾 Ride", function() R("RideToggle"):FireServer() end)
menuOption(petsMenu, "🏠 Daycare", function() R("DaycareOpen"):FireServer() openDaycare() end)

-- ---- 🛒 Shop ----
menuOption(shopMenu, "🥚 Shop", function() R("RequestShopStock"):FireServer() refreshShop() togglePanel("Shop") end)
-- v21: pest-repellent spray — one-shot armed tool; the next plot you tap gets
-- sprayed (protected from rot for the cycle) instead of watered/harvested.
sprayArmed= false
local sprayBtn: TextButton? = nil
refreshSprayBtn = function()
	if not sprayBtn then return end
	local n: number = items.PestRepellent or 0
	if n < 1 and sprayArmed then
		sprayArmed = false
		R("ArmRepellent"):FireServer(false)
	end
	sprayBtn.Text = if sprayArmed then "🧴 SPRAYING…" else "🧴 Spray (" .. n .. ")"
	sprayBtn.BackgroundColor3 = if sprayArmed then Color3.fromRGB(90, 160, 90) else Color3.fromRGB(62, 148, 92)
end
sprayBtn = menuOption(shopMenu, "🧴 Spray (0)", function()
	if sprayArmed then
		sprayArmed = false
		R("ArmRepellent"):FireServer(false)
		refreshSprayBtn()
		return
	end
	local n: number = items.PestRepellent or 0
	if n < 1 then
		toast("Buy 🧴 Pest Repellent in the 🥚 Shop first!", "warn")
		return
	end
	sprayArmed = true
	R("ArmRepellent"):FireServer(true)
	toast("🧴 Spray armed — tap one of your growing/ready plots!", "ok")
	refreshSprayBtn()
end)
-- v24: evolution stones — open the panel, tap SET on a stone, then tap a plot
stoneBtn = menuOption(shopMenu, "🪨 Stones", function()
	if stoneArmed then
		stoneArmed = nil
		R("ArmEvoStone"):FireServer("")
		refreshStoneBtn()
		refreshStones()
		return
	end
	refreshStones()
	togglePanel("Stones")
end)

-- ---- 🎮 Play ----
menuOption(playMenu, "🎣 Fish", function() R("FishCast"):FireServer() end)
menuOption(playMenu, "⛏️ Dig", function() -- v14: digs the nearest dig spot in range (needs a shovel)
	if not buffs.Shovel then
		toast("Buy a ⛏️ Shovel in the shop first!", "warn")
	else
		R("DigSpot"):FireServer()
	end
end)
menuOption(playMenu, "📋 Quests", function() R("RequestQuests"):FireServer() refreshQuests() togglePanel("Quests") end)
menuOption(playMenu, "🎁 Daily", function() refreshDaily() togglePanel("Daily") end)
menuOption(playMenu, "🎡 Spin", function() R("RequestSpinInfo"):FireServer() refreshSpin() togglePanel("Spin") end) -- v16: daily spin wheel
menuOption(playMenu, "🌙 Auction", function() refreshAuction() togglePanel("Auction") end) -- v20: night auction
-- v26: 📡 shiny radar — 25,000c one-time gadget; shatters when it finds a shiny.
radarBtn = menuOption(playMenu, "📡 Radar", function() R("RadarScan"):FireServer() end)
refreshRadarBtn()

-- ---- 👥 Social ----
menuOption(socialMenu, "🧑‍🤝‍🧑 Players", function() refreshVisit() togglePanel("Visit") end)
menuOption(socialMenu, "🏆 Boards", function() refreshBoards() togglePanel("Boards") end)

-- v39: measure each menu explicitly (options are 56 tall + 8 padding) so the
-- popup never depends on nested AutomaticSize to render its buttons.
for _, m in catMenus do
	local mf = m :: Frame
	local n = 0
	for _, c in ipairs(mf:GetChildren()) do
		if (c :: Instance):IsA("TextButton") then n += 1 end
	end
	mf.Size = UDim2.new(1, 0, 0, n * 56 + math.max(0, n - 1) * 8)
end

-- ---- the bar itself: 6 big category buttons (v36: bold saturated colors) ----
catButton("🐾", "Pets", function() openCat("Pets") end, Color3.fromRGB(46, 204, 113))
catButton("🛒", "Shop", function() openCat("Shop") end, Color3.fromRGB(255, 165, 20))
catButton("🎮", "Play", function() openCat("Play") end, Color3.fromRGB(95, 125, 255))
catButton("👥", "Social", function() openCat("Social") end, Color3.fromRGB(255, 95, 165))
catButton("📸", "Photo", function() if setPhotoMode then setPhotoMode(not photoMode) end end, Color3.fromRGB(20, 195, 195))
-- v47: settings moved back into the bar as a proper 6th button — the floating
-- gear kept overlapping panels, and the bar is always visible and tappable.
catButton("⚙️", "Settings", function() refreshSettings() togglePanel("Settings") end, Color3.fromRGB(120, 120, 140), 10) -- v47: 10px keeps the label inside the narrow button

end
-- ============================================================================
-- FISHING CARD (status + reel button, above the bottom bar; hidden when idle)
local fishCard: any, refreshRodLabel: any, onFishBite: any -- §escapes: FISHING CARD (status + reel button, above the bottom bar; hi
do
-- ============================================================================
fishCard= Instance.new("Frame")
fishCard.Name = "FishCard"
fishCard.Size = UDim2.new(0, 300, 0, 114)
fishCard.Position = UDim2.new(0.5, -150, 1, -188)
fishCard.BackgroundColor3 = Color3.fromRGB(40, 90, 140)
fishCard.BorderSizePixel = 0
fishCard.Visible = false
fishCard.Parent = gui
corner(fishCard, 12)
local fishStatus = label(fishCard, "🎣 Waiting for a bite...", UDim2.new(1, -16, 0, 36), UDim2.new(0, 8, 0, 6), 18, Color3.fromRGB(255, 255, 255))
fishStatus.TextXAlignment = Enum.TextXAlignment.Center
local fishBtn = button(fishCard, "🎣 REEL!", UDim2.new(0, 200, 0, 38), UDim2.new(0.5, -100, 0, 44), Color3.fromRGB(200, 60, 60))
fishBtn.TextSize = 18
-- v14: shows the owned rod tier (effects are server-side)
local fishRodLabel = label(fishCard, "🎣 Basic Rod", UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 84), 14, Color3.fromRGB(180, 220, 255))
fishRodLabel.TextXAlignment = Enum.TextXAlignment.Center

refreshRodLabel = function() -- v14
	local rdef = buffs.Rod and (Config.Rods :: { [string]: any })[buffs.Rod] or nil
	fishRodLabel.Text = "🎣 " .. (rdef and (rdef.Name :: string) or "Basic Rod")
end

local fishPhase = "idle" -- idle | waiting | bite | reeling
local fishFlashGen = 0
local function flashFishCard()
	fishFlashGen += 1
	local g = fishFlashGen
	task.spawn(function()
		local on = false
		for _ = 1, 6 do
			if g ~= fishFlashGen then break end
			on = not on
			fishCard.BackgroundColor3 = on and Color3.fromRGB(205, 50, 50) or Color3.fromRGB(40, 90, 140)
			task.wait(0.25)
		end
	end)
end

fishBtn.MouseButton1Click:Connect(function()
	if fishPhase == "idle" then R("FishCast"):FireServer()
	else R("FishReel"):FireServer() end
end)

onFishBite = function(status: string, a: any?)
	local s = tostring(status)
	if s == "waiting" then
		fishPhase = "waiting"
		fishCard.Visible = true
		refreshRodLabel() -- v14: show the owned rod tier
		fishStatus.Text = "🎣 Waiting for a bite..."
		fishBtn.Text = "🎣 Fishing..."
		fishBtn.BackgroundColor3 = Color3.fromRGB(90, 120, 150)
	elseif s == "bite" then
		fishPhase = "bite"
		fishStatus.Text = "❗ NOW! REEL! ❗"
		fishBtn.Text = "🎣 REEL!"
		fishBtn.BackgroundColor3 = Color3.fromRGB(210, 60, 60)
		flashFishCard()
	elseif s == "reel" then
		fishPhase = "reeling"
		local n = tonumber(a) or 0
		local need = tostring((Config.FishReelsNeeded :: number))
		fishStatus.Text = "🎣 Reeling... " .. n .. "/" .. need
		fishBtn.Text = "🎣 REEL! (" .. n .. "/" .. need .. ")"
		fishBtn.BackgroundColor3 = Color3.fromRGB(210, 60, 60)
	elseif s == "idle" then
		fishPhase = "idle"
		fishCard.Visible = false
	elseif s == "away" then
		fishPhase = "idle"
		fishStatus.Text = "💨 It got away..."
		task.delay(2, function() fishCard.Visible = false end)
	elseif s == "hint" then
		toast("Find a wooden dock by a lake to fish! 🎣", "warn")
	end
end

end
-- ============================================================================
-- REMOTE WIRING
-- ============================================================================
R("Notify").OnClientEvent:Connect(function(msg: string, kind: string?)
	-- rate-limit rejections stay silent: extra clicks are just ignored, no popup
	if string.find(tostring(msg), "Too fast", 1, true) then return end
	toast(tostring(msg), kind)
end)
R("Announce").OnClientEvent:Connect(function(title: string, body: string, _color: Color3?) announce(tostring(title), tostring(body)) end)

R("CoinsChanged").OnClientEvent:Connect(function(c: number) coins = c refreshTop() end)
R("SeedsChanged").OnClientEvent:Connect(function(s: { [string]: number })
	eggCount = (s :: { [string]: number }).PetEgg or 0
	refreshTop()
end)
R("ItemsChanged").OnClientEvent:Connect(function(it: { [string]: number })
	items = it
	refreshTop()
	refreshSprayBtn() -- v21: repellent count on the 🧴 Spray button
	refreshStoneBtn() -- v24: stone button state
	if openPanel == "Bag" then refreshBag() end
	if openPanel == "Stones" then refreshStones() end -- v24: owned stone counts
end)
R("SprayDone").OnClientEvent:Connect(function() -- v21: the server consumed the armed spray
	sprayArmed = false
	refreshSprayBtn()
end)
R("StoneDone").OnClientEvent:Connect(function() -- v24: the armed stone was set/consumed server-side
	stoneArmed = nil
	refreshStoneBtn()
	if openPanel == "Stones" then refreshStones() end
end)

-- ============================================================================
-- PET RIDING (v25) — server-validated mount. The server welds the follower
-- model into one assembly and hands network ownership to the rider; this
-- client then drives the pet's PrimaryPart every frame from the player's
-- normal movement input (camera-relative, like walking). Flying pets also
-- read Space (up) / C (down) plus on-screen ▲/▼ buttons for mobile.
local applyEventVisual: (string) -> (), applyPhase: (string, boolean?) -> (), phaseInit: any, truePhase: any, twilightMode: string? -- §escapes: read Space (up) / C (down) plus on-screen ▲/▼ buttons for mo
do
-- ============================================================================
local UIS = game:GetService("UserInputService")
local rideConn: RBXScriptConnection? = nil
local rideWeld: WeldConstraint? = nil
local ridePet: Model? = nil
local rideSpeed = 20
local rideCanFly = false
local flyUp = false
local flyDown = false
local rideWind: ParticleEmitter? = nil
local flyBtns: Frame? = nil

-- Make the rider's character ride cleanly: no collisions, no mass dragging
-- the pet. Original values are stashed in attributes and restored on dismount.
local function setCharRideMode(on: boolean)
	local char = player.Character
	if not char then return end
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") then
			if on then
				d:SetAttribute("RideCC", d.CanCollide)
				d:SetAttribute("RideML", d.Massless)
				d.CanCollide = false
				d.Massless = true
			else
				local cc = d:GetAttribute("RideCC")
				local ml = d:GetAttribute("RideML")
				if cc ~= nil then d.CanCollide = (cc :: boolean) end
				if ml ~= nil then d.Massless = (ml :: boolean) end
				d:SetAttribute("RideCC", nil)
				d:SetAttribute("RideML", nil)
			end
		end
	end
end

local function stopRideDrive()
	if rideConn then rideConn:Disconnect() rideConn = nil end
	if rideWeld then pcall(function() (rideWeld :: WeldConstraint):Destroy() end) rideWeld = nil end
	if rideWind then pcall(function() (rideWind :: ParticleEmitter):Destroy() end) rideWind = nil end
	setCharRideMode(false)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		local jp = hum:GetAttribute("RideJP")
		if jp ~= nil then hum.JumpPower = (jp :: number) hum:SetAttribute("RideJP", nil) end
	end
	ridePet = nil
	flyUp, flyDown = false, false
	if flyBtns then flyBtns.Visible = false end
end

local function startRideDrive(pet: Model)
	stopRideDrive()
	ridePet = pet -- set AFTER stopRideDrive (it clears ridePet)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local primary = (pet :: Model).PrimaryPart
	if not (hum and hrp and (hrp :: Instance):IsA("BasePart") and primary and (primary :: Instance):IsA("BasePart")) then
		ridePet = nil
		return
	end
	local h = hum :: Humanoid
	local root = hrp :: BasePart
	local pp = primary :: BasePart
	-- seat the rider on the pet's back, then weld rider -> pet
	root.CFrame = pp.CFrame * CFrame.new(0, pp.Size.Y / 2 + 2.0, 0)
	local w = Instance.new("WeldConstraint")
	w.Name = "RiderWeld"
	w.Part0 = pp
	w.Part1 = root
	w.Parent = root
	rideWeld = w
	setCharRideMode(true)
	h:SetAttribute("RideJP", h.JumpPower)
	h.JumpPower = 0 -- Space is "fly up" while riding, not jump
	local maxAlt: number = Config.RideMaxAlt
	local radius: number = Config.RideWorldRadius
	rideConn = game:GetService("RunService").RenderStepped:Connect(function(dt: number)
		local ch = player.Character
		local hh = ch and ch:FindFirstChildOfClass("Humanoid")
		local mdl = ridePet
		local pr = mdl and (mdl :: Model).PrimaryPart
		if not (ch and ch.Parent and hh and mdl and (mdl :: Instance).Parent and pr and (pr :: Instance):IsA("BasePart")) then
			stopRideDrive()
			return
		end
		local md = (hh :: Humanoid).MoveDirection -- camera-relative, from input
		local vel = Vector3.new(md.X, 0, md.Z) * rideSpeed
		if rideCanFly then
			local vy = 0
			if flyUp then vy += rideSpeed * 0.8 end
			if flyDown then vy -= rideSpeed * 0.8 end
			vel += Vector3.new(0, vy, 0)
		end
		local part = pr :: BasePart
		local step = math.min(dt, 0.1)
		local newPos = part.Position + vel * step
		newPos = Vector3.new(
			math.clamp(newPos.X, -radius, radius),
			math.clamp(newPos.Y, 2, maxAlt),
			math.clamp(newPos.Z, -radius, radius))
		-- face travel direction (horizontal); keep the pet level
		local cf: CFrame
		if md.Magnitude > 0.15 then
			cf = CFrame.lookAt(newPos, newPos + Vector3.new(md.X, 0, md.Z))
		else
			cf = part.CFrame - part.Position + newPos
		end
		part.CFrame = cf -- unanchored + we own it: replicates to the server
	end)
end

-- ▲/▼ fly buttons (mobile-friendly; also clickable on desktop)
local function makeFlyButtons()
	if flyBtns then return end
	local f = Instance.new("Frame")
	f.Name = "FlyButtons"
	f.Size = UDim2.new(0, 76, 0, 168)
	f.Position = UDim2.new(1, -260, 1, -360) -- v47: clear of the right-edge side panel (was 1,-96, overlapping it)
	f.BackgroundTransparency = 1
	f.Visible = false
	f.Parent = gui
	local function mkBtn(text: string, y: number, set: (boolean) -> ())
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 76, 0, 76)
		b.Position = UDim2.new(0, 0, 0, y)
		b.BackgroundColor3 = Color3.fromRGB(70, 130, 200)
		b.Text = text
		b.TextSize = 34
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.Font = Enum.Font.FredokaOne
		b.Parent = f
		corner(b, 38)
		b.MouseButton1Down:Connect(function() set(true) end)
		b.MouseButton1Up:Connect(function() set(false) end)
		b.MouseLeave:Connect(function() set(false) end)
	end
	mkBtn("▲", 0, function(v: boolean) flyUp = v end)
	mkBtn("▼", 92, function(v: boolean) flyDown = v end)
	flyBtns = f
end

UIS.InputBegan:Connect(function(input: InputObject, _gpe: boolean)
	-- NOTE: gpe is intentionally ignored — Space is consumed by the jump
	-- binding, so checking it would break desktop fly-up. We only skip
	-- while the player is typing in a TextBox (chat).
	if not ridePet then return end
	if UIS:GetFocusedTextBox() ~= nil then return end
	if input.KeyCode == Enum.KeyCode.Space then flyUp = true end
	if input.KeyCode == Enum.KeyCode.C then flyDown = true end
end)
UIS.InputEnded:Connect(function(input: InputObject)
	if input.KeyCode == Enum.KeyCode.Space then flyUp = false end
	if input.KeyCode == Enum.KeyCode.C then flyDown = false end
end)

R("RideState").OnClientEvent:Connect(function(enabled: boolean, canFly: boolean, speed: number, petName: string?)
	if enabled then
		rideCanFly = canFly == true
		rideSpeed = speed or 20
		local pet = workspace:FindFirstChild("Follower_" .. player.Name)
		if pet and pet:IsA("Model") then
			if rideCanFly then
				-- wind streaks while flying fast
				local body = pet:FindFirstChild("Body")
				if body and body:IsA("BasePart") then
					local pe = Instance.new("ParticleEmitter")
					pe.Name = "RideWind"
					pe.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255))
					pe.Size = NumberSequence.new(0.8)
					pe.Rate = 24
					pe.Lifetime = NumberRange.new(0.4, 0.7)
					pe.Speed = NumberRange.new(4, 8)
					pe.Parent = body
					rideWind = pe
				end
			end
			makeFlyButtons()
			if flyBtns then flyBtns.Visible = rideCanFly end
			startRideDrive(pet)
		else
			ridePet = nil
		end
	else
		stopRideDrive()
	end
end)
R("BuffsChanged").OnClientEvent:Connect(function(b: { [string]: any }) buffs = b refreshTop() refreshRodLabel()
	if openPanel == "Bag" then refreshBag() end -- v14: fossil fragment count lives in buffs
	if openPanel == "Shop" then refreshShop() end -- v14: rod/shovel "Owned ✅" lives in buffs
	refreshRadarBtn() -- v26: 📡 radar button visible only while a radar is owned
end)
R("SkinsChanged").OnClientEvent:Connect(function(s: { string }) -- v12: owned skins
	ownedSkins = s
	if openPanel == "Shop" then refreshShop() end
end)
R("InventoryChanged").OnClientEvent:Connect(function(inv: { { [string]: any } })
	inventory = inv
	if openPanel == "Bag" then refreshBag() end
	if openPanel == "Fuse" then refreshFuse() end
end)
R("CollectionUpdate").OnClientEvent:Connect(function(c: { [string]: any })
	collection = c
	if openPanel == "Dex" then refreshDex() end
end)
R("SettingsChanged").OnClientEvent:Connect(function(s: { [string]: any })
	settings = s
	if openPanel == "Settings" then refreshSettings() end
end)
R("ShopStock").OnClientEvent:Connect(function(stock: { { [string]: any } })
	shopStock = stock
	if openPanel == "Shop" then refreshShop() end
end)
R("FishBite").OnClientEvent:Connect(onFishBite)
R("GardenInfo").OnClientEvent:Connect(function(_idx: number, owned: number) plotsOwned = owned end)
applyEventVisual = nil
applyPhase = nil
R("EventChanged").OnClientEvent:Connect(function(id: string, endsAt: number)
	eventId = id
	eventEndsAt = endsAt
	local names: { [string]: string } = { Sunny = "☀️ Sunny", Rain = "🌧️ Rain 2x growth", Meteor = "☄️ Meteor! 100% evolve", Rainbow = "🌈 Rainbow x2 shiny!", Merchant = "🧳 Merchant -25% potions" }
	eventLabel.Text = names[id] or id
	applyEventVisual(id)
end)
-- day/night phase: first push snaps instantly, later ones play the transition
phaseInit= false
-- 🌗 v23: twilight dimension override. While the player stands in the
-- dimension, the halves force their own lighting (Light=day, Dark=night) and
-- the global phase never wins. truePhase remembers the real global phase so
-- leaving the dimension restores it.
truePhase= "Day" -- last phase pushed by the server ("Day" | "Night")
twilightMode= nil -- "Light" | "Dark" while inside the dimension
R("PhaseChanged").OnClientEvent:Connect(function(p: string, _endsAt: number)
	truePhase = p
	if not phaseInit then
		phaseInit = true
		applyPhase(p, true)
	else
		applyPhase(p)
	end
end)

end
-- ============================================================================
-- EVENT VISUALS (client-side atmosphere: rain, meteors, merchant, rainbow)
-- Weather is an OVERLAY on the day/night phase base (see phase section below):
-- it never touches ClockTime. Phase changes re-layer the active weather.
local phaseId: any, TweenSvc: any -- §escapes: it never touches ClockTime. Phase changes re-layer the activ
do
-- ============================================================================
phaseId= "Day" -- "Day" | "Night", driven by the server's PhaseChanged
local eventFX: Folder? = nil
local eventLoop: thread? = nil
TweenSvc= game:GetService("TweenService")

local function clearEventFX()
	if eventLoop then task.cancel(eventLoop) eventLoop = nil end
	if eventFX then eventFX:Destroy() eventFX = nil end
end

-- one-shot particle burst at a world position (client-local)
local function burstFX(pos: Vector3, color: Color3, count: number)
	local folder = eventFX
	if not folder then return end
	local p = Instance.new("Part")
	p.Name = "Burst"
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Position = pos
	p.Anchored = true
	p.CanCollide = false
	p.Parent = folder
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color)
	pe.Size = NumberSequence.new(0.9)
	pe.Transparency = NumberSequence.new(0.1)
	pe.Speed = NumberRange.new(10, 24)
	pe.Lifetime = NumberRange.new(0.5, 1)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Rate = 0
	pe.Parent = p
	pe:Emit(count)
	game:GetService("Debris"):AddItem(p, 2)
end

local function spawnMeteor()
	local folder = eventFX
	if not folder then return end
	local sx, sz = math.random(-350, 350), math.random(-350, 350)
	local startPos = Vector3.new(sx, 170, sz)
	local m = Instance.new("Part")
	m.Name = "Meteor"
	m.Shape = Enum.PartType.Ball
	m.Size = Vector3.new(4, 4, 4)
	m.Color = Color3.fromRGB(255, 140, 60)
	m.Material = Enum.Material.Neon
	m.Anchored = true
	m.CanCollide = false
	m.Position = startPos
	m.Parent = folder
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 170, 80))
	pe.Size = NumberSequence.new(1.4)
	pe.Transparency = NumberSequence.new(0.2)
	pe.Rate = 70
	pe.Lifetime = NumberRange.new(0.4, 0.8)
	pe.Speed = NumberRange.new(2, 6)
	pe.Parent = m
	local target = Vector3.new(sx * 0.35, 2, sz * 0.35)
	local tw = TweenSvc:Create(m, TweenInfo.new(1.7, Enum.EasingStyle.Linear), { Position = target })
	tw:Play()
	tw.Completed:Wait()
	if m.Parent then
		burstFX(target, Color3.fromRGB(255, 150, 70), 50)
		m:Destroy()
	end
end

local function confettiOverPlaza()
	local folder = eventFX
	if not folder then return end
	local p = Instance.new("Part")
	p.Name = "Confetti"
	p.Transparency = 1
	p.Size = Vector3.new(40, 1, 40)
	p.Position = Vector3.new(0, 35, 0)
	p.Anchored = true
	p.CanCollide = false
	p.Parent = folder
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 120)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 120)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 255, 140)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(140, 180, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 140, 255)),
	})
	pe.Size = NumberSequence.new(0.7)
	pe.Speed = NumberRange.new(6, 14)
	pe.Lifetime = NumberRange.new(1.5, 2.5)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.EmissionDirection = Enum.NormalId.Bottom
	pe.Rate = 0
	pe.Parent = p
	pe:Emit(80)
	game:GetService("Debris"):AddItem(p, 4)
end

applyEventVisual = function(id: string)
	clearEventFX()
	-- NOTE: no restoreSky() here — the day/night phase owns the sky base.
	local L = game:GetService("Lighting")
	local atm = L:FindFirstChildOfClass("Atmosphere")
	eventFX = Instance.new("Folder")
	eventFX.Name = "EventFX"
	eventFX.Parent = workspace
	if id == "Rain" then
		if phaseId == "Night" then
			L.Brightness = 1.4
			L.OutdoorAmbient = Color3.fromRGB(62, 64, 84)
		else
			L.Brightness = 1.5
			L.OutdoorAmbient = Color3.fromRGB(110, 115, 125)
		end
		if atm then atm.Density = 0.5 end
		local sheet = Instance.new("Part")
		sheet.Name = "RainSheet"
		sheet.Size = Vector3.new(700, 1, 700)
		sheet.Position = Vector3.new(0, 95, 0)
		sheet.Transparency = 1
		sheet.Anchored = true
		sheet.CanCollide = false
		sheet.Parent = eventFX
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(Color3.fromRGB(150, 190, 255))
		pe.Size = NumberSequence.new(0.25)
		pe.Transparency = NumberSequence.new(0.25)
		pe.Rate = 1000
		pe.Lifetime = NumberRange.new(1.1, 1.5)
		pe.Speed = NumberRange.new(95, 115)
		pe.EmissionDirection = Enum.NormalId.Bottom
		pe.SpreadAngle = Vector2.new(5, 5)
		pe.Parent = sheet
	elseif id == "Meteor" then
		if phaseId == "Night" then
			L.OutdoorAmbient = Color3.fromRGB(95, 75, 100) -- meteors streak a dark sky
		else
			L.Brightness = 1.8
			L.OutdoorAmbient = Color3.fromRGB(140, 110, 110)
		end
		if atm then
			atm.Density = 0.35
			atm.Color = Color3.fromRGB(255, 200, 170)
			atm.Decay = Color3.fromRGB(200, 120, 90)
		end
		eventLoop = task.spawn(function()
			while true do
				task.wait(math.random(15, 40) / 10)
				spawnMeteor()
			end
		end)
	elseif id == "Merchant" then
		eventLoop = task.spawn(function()
			while true do
				task.wait(7)
				confettiOverPlaza()
			end
		end)
	elseif id == "Rainbow" then
		-- 🌈 a big rainbow arc across the sky + drifting sparkles
		L.Brightness = 2.2
		L.OutdoorAmbient = Color3.fromRGB(170, 160, 180)
		if atm then
			atm.Density = 0.22
			atm.Color = Color3.fromRGB(225, 215, 245)
		end
		local bandColors = {
			Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 165, 80),
			Color3.fromRGB(255, 235, 110), Color3.fromRGB(120, 225, 120),
			Color3.fromRGB(110, 170, 255), Color3.fromRGB(150, 120, 255),
			Color3.fromRGB(220, 140, 255),
		}
		local center = Vector3.new(0, 8, -330)
		local baseR = 130
		local segs = 10
		for bi, bc in bandColors do
			local r = baseR + (bi - 1) * 4.5
			for s = 1, segs do
				local a0 = math.rad(25 + (s - 1) * (130 / segs))
				local a1 = math.rad(25 + s * (130 / segs))
				local am = (a0 + a1) / 2
				local arcLen = r * (a1 - a0)
				local seg = Instance.new("Part")
				seg.Name = "RainbowBand"
				seg.Size = Vector3.new(arcLen + 1.2, 3.2, 3.2)
				seg.Color = bc
				seg.Material = Enum.Material.Neon
				seg.Transparency = 0.15
				seg.Anchored = true
				seg.CanCollide = false
				local px = center.X + math.cos(am) * r
				local py = center.Y + math.sin(am) * r
				seg.CFrame = CFrame.new(px, py, center.Z) * CFrame.Angles(0, 0, am + math.pi / 2)
				seg.Parent = eventFX
			end
		end
		-- sparkle drift under the arc
		local sheet = Instance.new("Part")
		sheet.Name = "RainbowSparkles"
		sheet.Size = Vector3.new(320, 1, 1)
		sheet.Position = center + Vector3.new(0, 60, 0)
		sheet.Transparency = 1
		sheet.Anchored = true
		sheet.CanCollide = false
		sheet.Parent = eventFX
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 150)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 255, 180)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 180, 255)),
		})
		pe.Size = NumberSequence.new(0.8)
		pe.Transparency = NumberSequence.new(0.2)
		pe.Rate = 50
		pe.Lifetime = NumberRange.new(1.5, 2.5)
		pe.Speed = NumberRange.new(4, 10)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Parent = sheet
	end
end

end
-- ============================================================================
-- DAY/NIGHT PHASE (client-side lighting + sun/moon, server-driven)
-- The server owns the cycle; the client renders it. Transitions are smooth:
-- dusk/dawn clock sweeps, ambient color tweens, and a sun<->moon swap.
do
-- ============================================================================
local phaseFX: Folder? = nil
local phaseLoop: thread? = nil
local phaseGen = 0 -- guards overlapping transitions

local PHASE_LOOK = {
	Day = {
		Clock = 14.5,
		Brightness = 2,
		Ambient = Color3.fromRGB(150, 150, 150),
		Density = 0.25,
		AtmColor = Color3.fromRGB(210, 235, 255),
		AtmDecay = Color3.fromRGB(120, 170, 220),
	},
	Night = {
		Clock = 0,
		Brightness = 1.6,
		Ambient = Color3.fromRGB(70, 70, 110),
		Density = 0.35,
		AtmColor = Color3.fromRGB(50, 60, 120),
		AtmDecay = Color3.fromRGB(25, 30, 70),
	},
}

local function clearPhaseFX()
	if phaseLoop then task.cancel(phaseLoop) phaseLoop = nil end
	if phaseFX then phaseFX:Destroy() phaseFX = nil end
end

local function tweenLighting(look: { [string]: any }, dur: number)
	local L = game:GetService("Lighting")
	TweenSvc:Create(L, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		Brightness = look.Brightness,
		OutdoorAmbient = look.Ambient,
	}):Play()
	local atm = L:FindFirstChildOfClass("Atmosphere")
	if atm then
		TweenSvc:Create(atm, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			Density = look.Density,
			Color = look.AtmColor,
			Decay = look.AtmDecay,
		}):Play()
	end
end

-- builds the sun (day) or moon + fireflies (night) into phaseFX, all starting
-- invisible; returns the parts so the caller can fade them in.
local function buildCelestial(night: boolean): { Part }
	local folder = Instance.new("Folder")
	folder.Name = "PhaseFX"
	folder.Parent = workspace
	phaseFX = folder
	local parts: { Part } = {}
	local function ball(name: string, size: number, pos: Vector3, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(size, size, size)
		p.Position = pos
		p.Color = color
		p.Material = Enum.Material.Neon
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.Parent = folder
		table.insert(parts, p)
		return p
	end
	if night then
		ball("Moon", 26, Vector3.new(-190, 160, -230), Color3.fromRGB(235, 240, 255))
		-- drifting fireflies
		local flies: { { p: Part, bx: number, bz: number, ph: number, sp: number } } = {}
		for _ = 1, 24 do
			local f = ball("Firefly", 0.7,
				Vector3.new(math.random(-180, 180), 4, math.random(-140, 140)),
				Color3.fromRGB(220, 255, 150))
			table.insert(flies, {
				p = f,
				bx = f.Position.X, bz = f.Position.Z,
				ph = math.random() * 6.28, sp = 0.5 + math.random(),
			})
		end
		phaseLoop = task.spawn(function()
			local t = 0
			while true do
				t += 0.12
				for _, fl in flies do
					if fl.p.Parent then
						fl.p.Position = Vector3.new(
							fl.bx + math.sin(t * fl.sp + fl.ph) * 6,
							4 + math.sin(t * fl.sp * 1.3 + fl.ph) * 2,
							fl.bz + math.cos(t * fl.sp * 0.7 + fl.ph) * 6)
					end
				end
				task.wait(0.12)
			end
		end)
	else
		ball("Sun", 30, Vector3.new(190, 150, -230), Color3.fromRGB(255, 225, 130))
	end
	return parts
end

local function fadeParts(parts: { Part }, to: number, dur: number)
	for _, p in parts do
		if p.Parent then
			TweenSvc:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ Transparency = to }):Play()
		end
	end
end

applyPhase = function(phase: string, instant: boolean?)
	phaseGen += 1
	local g = phaseGen
	-- 🌗 v23: twilight dimension overrides the phase — each half is eternal
	local tw = twilightMode
	if tw then phase = if tw == "Light" then "Day" else "Night" end
	phaseId = phase
	phaseLabel.Text = if tw then (if tw == "Light" then "🌗 Twilight · Day side" else "🌑 Twilight · Night side")
		elseif phase == "Night" then "🌙 Night" else "☀️ Day"
	local night = phase == "Night"
	local look = if night then PHASE_LOOK.Night else PHASE_LOOK.Day
	local L = game:GetService("Lighting")
	if instant then
		-- joining player: snap, no transition show
		clearPhaseFX()
		L.ClockTime = look.Clock
		L.Brightness = look.Brightness
		L.OutdoorAmbient = look.Ambient
		local atm = L:FindFirstChildOfClass("Atmosphere")
		if atm then
			atm.Density = look.Density
			atm.Color = look.AtmColor
			atm.Decay = look.AtmDecay
		end
		fadeParts(buildCelestial(night), 0, 0.01)
		applyEventVisual(eventId) -- layer the current weather onto the base
		return
	end
	task.spawn(function()
		if night then
			-- dusk: sweep the clock to sunset, warm the air, then go dark
			TweenSvc:Create(L, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ ClockTime = 17.9 }):Play()
			tweenLighting({
				Brightness = 1.7, Ambient = Color3.fromRGB(200, 130, 90), Density = 0.3,
				AtmColor = Color3.fromRGB(255, 170, 130), AtmDecay = Color3.fromRGB(160, 90, 70),
			}, 5)
			task.wait(5.2)
			if g ~= phaseGen then return end
			clearPhaseFX() -- the old sun is gone
			L.ClockTime = 0
			local parts = buildCelestial(true)
			tweenLighting(look, 4)
			fadeParts(parts, 0, 4)
			task.wait(4.2)
		else
			-- dawn: fade the moon + fireflies, time-lapse the clock to midday
			if phaseFX then
				local olds: { Part } = {}
				for _, d in phaseFX:GetDescendants() do
					if d:IsA("BasePart") then table.insert(olds, d :: Part) end
				end
				fadeParts(olds, 1, 3)
			end
			TweenSvc:Create(L, TweenInfo.new(7, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ ClockTime = look.Clock }):Play()
			tweenLighting(look, 7)
			task.wait(3.2)
			if g ~= phaseGen then return end
			clearPhaseFX()
			fadeParts(buildCelestial(false), 0, 3)
			task.wait(3.2)
		end
		if g ~= phaseGen then return end
		applyEventVisual(eventId) -- re-layer weather onto the new phase base
	end)
end

end
-- ============================================================================
-- 🌗 v23: TWILIGHT DIMENSION WATCHER
-- Snaps the lighting to the dimension's forced day/night per half while the
-- player is inside, and restores the true global phase on exit. The server
-- forces the same logic for wild spawns, so visuals and pets always agree.
do
-- ============================================================================
local function twilightZoneAt(p: Vector3): string?
	local lz = (Config.TwilightLightZone :: { [string]: any })
	if p.X >= (lz.MinX :: number) and p.X <= (lz.MaxX :: number)
		and p.Z >= (lz.MinZ :: number) and p.Z <= (lz.MaxZ :: number) then
		return "Light"
	end
	local dz = (Config.TwilightDarkZone :: { [string]: any })
	if p.X >= (dz.MinX :: number) and p.X <= (dz.MaxX :: number)
		and p.Z >= (dz.MinZ :: number) and p.Z <= (dz.MaxZ :: number) then
		return "Dark"
	end
	return nil
end
task.spawn(function()
	while true do
		task.wait(0.5)
		local plr = game:GetService("Players").LocalPlayer
		local char = plr and plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local mode: string? = nil
		if hrp and (hrp :: BasePart) then mode = twilightZoneAt((hrp :: BasePart).Position) end
		if mode ~= twilightMode then
			twilightMode = mode
			if mode then
				applyPhase(if mode == "Light" then "Day" else "Night", true) -- snap to the half's eternal look
			elseif phaseInit then
				applyPhase(truePhase, true) -- stepped out: restore the real global phase
			end
		end
	end
end)

R("Leaderboards").OnClientEvent:Connect(function(b: { [string]: any }, labels: { [string]: string })
	boards = b
	boardLabels = labels
	if openPanel == "Boards" then refreshBoards() end
end)
R("DailyInfo").OnClientEvent:Connect(function(day: number, can: boolean, streak: number)
	dailyDay, dailyCan, dailyStreak = day, can, streak
	if openPanel == "Daily" then refreshDaily() end
end)
R("QuestInfo").OnClientEvent:Connect(function(list: { { [string]: any } })
	quests = list
	if openPanel == "Quests" then refreshQuests() end
end)
R("VisitList").OnClientEvent:Connect(function(list: { { [string]: any } })
	visitList = list
	if openPanel == "Visit" then refreshVisit() end
end)
R("OpenShop").OnClientEvent:Connect(function() R("RequestShopStock"):FireServer() refreshShop() togglePanel("Shop") end)
R("OpenSell").OnClientEvent:Connect(function() togglePanel("Bag") end) -- v46: Trader opens Pets bag for individual selling

R("StarterPrompt").OnClientEvent:Connect(function()
	relayoutStarters() -- v47: pick the phone/desktop card layout with the real viewport size
	starterFrame.Visible = true
end)
R("StarterChanged").OnClientEvent:Connect(function(petId: string?)
	starterPetId = petId
	starterFrame.Visible = false
end)
-- ask the server to (re)send the starter prompt now that the UI is ready
R("RequestStarter"):FireServer()
-- same for the shop stock: the onJoin push can arrive before this handler connects
R("RequestShopStock"):FireServer()
-- same for the current event (kicks off the event visuals)
R("RequestEvent"):FireServer()
-- same for the day/night phase (kicks off phase lighting + indicator)
R("RequestPhase"):FireServer()

R("TeamChanged").OnClientEvent:Connect(function(t: { [string]: any })
	teamSlots = (t :: { [string]: any }).Slots or {}
	followerUid = (t :: { [string]: any }).FollowerUid
	if openPanel == "Team" then refreshTeam() end
end)

-- battle
R("BattleInvite").OnClientEvent:Connect(function(fromUserId: number, fromName: string)
	askYesNo("⚔️ " .. tostring(fromName) .. " challenged you to a pet battle! Accept?",
		function(yes) R("BattleRespond"):FireServer(fromUserId, yes) end)
end)
R("BattleInviteExpired").OnClientEvent:Connect(function() toast("Battle challenge expired.", "warn") end)
R("BattleStart").OnClientEvent:Connect(function(id: number)
	battleId = id
	battleView = nil
	battleFrame.Visible = false
	openFighterPicker()
end)
end
-- ============================================================================
-- BATTLE FX (damage numbers, screen shake, hit flash, KO banner)
do
-- ============================================================================
local battleFlash: Frame? = nil

local function battleDmgNumber(xOff: number, yPos: number, amount: number, heal: boolean)
	local l = Instance.new("TextLabel")
	l.Text = (if heal then "+" else "-") .. tostring(amount)
	l.Font = Enum.Font.FredokaOne
	l.TextSize = 32
	l.TextColor3 = if heal then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(255, 110, 110)
	l.TextStrokeTransparency = 0.4
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(0, 200, 0, 44)
	l.Position = UDim2.new(0.5, xOff, 0, yPos)
	l.ZIndex = 60
	l.Parent = battleFrame
	game:GetService("TweenService"):Create(l, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, xOff, 0, yPos - 60),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	game:GetService("Debris"):AddItem(l, 1)
end

local function battleShake()
	task.spawn(function()
		local orig = battleFrame.Position
		for _ = 1, 5 do
			battleFrame.Position = orig + UDim2.new(0, math.random(-9, 9), 0, math.random(-9, 9))
			task.wait(0.045)
		end
		battleFrame.Position = orig
	end)
end

local function battleHitFlash()
	if not battleFlash then
		local f = Instance.new("Frame")
		f.Size = UDim2.new(1, 0, 1, 0)
		f.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.ZIndex = 55
		f.Parent = battleFrame
		corner(f, 14)
		battleFlash = f
	end
	local fl = battleFlash :: Frame
	fl.BackgroundTransparency = 0.6
	game:GetService("TweenService"):Create(fl, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
end

local function battleKOBanner(youWon: boolean)
	local l = Instance.new("TextLabel")
	l.Text = if youWon then "🏆 YOU WIN!" else "💀 K.O.!"
	l.Font = Enum.Font.FredokaOne
	l.TextSize = 48
	l.TextColor3 = if youWon then Color3.fromRGB(255, 215, 120) else Color3.fromRGB(255, 120, 120)
	l.TextStrokeTransparency = 0.2
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(0.8, 0, 0, 90)
	l.Position = UDim2.new(0.1, 0, 0.35, 0)
	l.ZIndex = 60
	l.Parent = battleFrame
	game:GetService("TweenService"):Create(l, TweenInfo.new(0.45, Enum.EasingStyle.Back), { TextSize = 62 }):Play()
	task.delay(2.4, function() l:Destroy() end)
end

R("BattleUpdate").OnClientEvent:Connect(function(v: { [string]: any })
	local old = battleView
	battleAwaiting = false -- v47.5: server answered, tap feedback ends
	if old and v.BothPicked then
		local wasYourTurn = (old :: { [string]: any }).YourTurn == true
		if v.YourTurn == true and not wasYourTurn then
			-- v47.5: your-turn pop — the turn label punches so the moment reads instantly
			battleTurn.TextSize = 26
			game:GetService("TweenService"):Create(battleTurn,
				TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ TextSize = 16 }):Play()
		end
		local function hpOf(w: { [string]: any }?): number?
			if not w then return nil end
			return w.HP :: number
		end
		local oy, ny = hpOf(old.You), hpOf(v.You)
		local of_, nf = hpOf(old.Foe), hpOf(v.Foe)
		if oy and ny and ny < oy then
			battleDmgNumber(-80, 198, math.floor(oy - ny), false) -- v47: over the new you-bar
			battleShake()
			battleHitFlash()
		elseif oy and ny and ny > oy then
			battleDmgNumber(-80, 198, math.floor(ny - oy), true) -- v47: over the new you-bar
		end
		if of_ and nf and nf < of_ then
			battleDmgNumber(-80, 96, math.floor(of_ - nf), false) -- v47: over the new foe-bar
			battleShake()
			battleHitFlash()
		elseif of_ and nf and nf > of_ then
			battleDmgNumber(-80, 96, math.floor(nf - of_), true) -- v47: over the new foe-bar
		end
		if nf and of_ and nf <= 0 and of_ > 0 then
			battleKOBanner(true)
		elseif ny and oy and ny <= 0 and oy > 0 then
			battleKOBanner(false)
		end
	end
	battleView = v
	refreshBattleUI()
end)
R("BattleEnd").OnClientEvent:Connect(function(res: { [string]: any })
	battleId = nil
	battleView = nil
	battleFrame.Visible = false
	pickFrame.Visible = false
	announce("⚔️ Battle over!", tostring((res :: { [string]: any }).Msg))
end)

-- trade
R("TradeInvite").OnClientEvent:Connect(function(fromUserId: number, fromName: string)
	askYesNo("🔄 " .. tostring(fromName) .. " wants to trade pets! Accept?",
		function(yes) R("TradeRespond"):FireServer(fromUserId, yes) end)
end)
R("TradeInviteExpired").OnClientEvent:Connect(function() toast("Trade request expired.", "warn") end)
R("TradeStart").OnClientEvent:Connect(function(id: number)
	tradeId = id
	tradeView = nil
	tradeOfferUid = nil
	tradeOfferCoins = 0
	coinBox.Text = "0"
	tradeFrame.Visible = true
	toast("Trade started! Pick a pet and/or coins, then Confirm. 🔄", "ok")
end)
R("TradeUpdate").OnClientEvent:Connect(function(v: { [string]: any })
	tradeView = v
	refreshTradeUI()
end)
R("TradeEnd").OnClientEvent:Connect(function(msg: string)
	tradeId = nil
	tradeView = nil
	tradeFrame.Visible = false
	tradePickFrame.Visible = false
	toast(tostring(msg), "ok")
end)

end
-- ============================================================================
-- v18: TRADING BOOTH UI (async plaza trading)
do
-- ============================================================================
local boothListings: { { [string]: any } } = {}
local boothFocus = 1

local boothFrame = Instance.new("Frame")
boothFrame.Size = UDim2.new(0.94, 0, 0.84, 0)
boothFrame.Position = UDim2.new(0.03, 0, 0.08, 0)
boothFrame.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
boothFrame.Visible = false
boothFrame.ZIndex = 55 -- v47: above panels, below the category popup (60) and pickers (65)
boothFrame.Parent = gui
corner(boothFrame, 14)
local boothTitle = label(boothFrame, "🏪 TRADING BOOTHS", UDim2.new(1, -20, 0, 40), UDim2.new(0, 10, 0, 6), 24, Color3.fromRGB(255, 220, 150))
boothTitle.TextXAlignment = Enum.TextXAlignment.Center
local boothX = button(boothFrame, "X", UDim2.new(0, 40, 0, 32), UDim2.new(1, -48, 0, 8), Color3.fromRGB(170, 70, 70))
boothX.MouseButton1Click:Connect(function() boothFrame.Visible = false end)
local boothScroll = Instance.new("ScrollingFrame")
boothScroll.Size = UDim2.new(1, -16, 1, -110)
boothScroll.Position = UDim2.new(0, 8, 0, 56)
boothScroll.BackgroundTransparency = 1
boothScroll.ScrollBarThickness = 6
boothScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
boothScroll.Parent = boothFrame
local boothLayout = Instance.new("UIListLayout")
boothLayout.Padding = UDim.new(0, 10)
boothLayout.Parent = boothScroll
local boothHint = label(boothFrame, "Claim a booth and list ONE pet — others can buy it while you're away!",
	UDim2.new(1, -20, 0, 44), UDim2.new(0, 10, 1, -50), 13, Color3.fromRGB(190, 180, 200))
boothHint.TextWrapped = true
boothHint.TextXAlignment = Enum.TextXAlignment.Center

-- pet picker used by both listing and accepting
local boothPickFrame = Instance.new("Frame")
boothPickFrame.Size = UDim2.new(0.9, 0, 0.7, 0)
boothPickFrame.Position = UDim2.new(0.05, 0, 0.15, 0)
boothPickFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
boothPickFrame.Visible = false
boothPickFrame.ZIndex = 56 -- v47: picker above its booth frame
boothPickFrame.Parent = gui
corner(boothPickFrame, 12)
local boothPickTitle = label(boothPickFrame, "", UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 0, 8), 17, Color3.fromRGB(255, 200, 150))
boothPickTitle.TextXAlignment = Enum.TextXAlignment.Center
local boothPickX = button(boothPickFrame, "X", UDim2.new(0, 40, 0, 32), UDim2.new(1, -48, 0, 8), Color3.fromRGB(170, 70, 70))
boothPickX.MouseButton1Click:Connect(function() boothPickFrame.Visible = false end)
local boothPickScroll = Instance.new("ScrollingFrame")
boothPickScroll.Size = UDim2.new(1, -16, 1, -56)
boothPickScroll.Position = UDim2.new(0, 8, 0, 48)
boothPickScroll.BackgroundTransparency = 1
boothPickScroll.ScrollBarThickness = 6
boothPickScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
boothPickScroll.Parent = boothPickFrame
local boothPickLayout = Instance.new("UIListLayout")
boothPickLayout.Padding = UDim.new(0, 8)
boothPickLayout.Parent = boothPickScroll

local boothListUid: string? = nil -- pet chosen for listing
local boothOfferUid: string? = nil -- buyer's offered pet
local boothOfferCoins = 0

local function termsText(t: { [string]: any }?): string
	if not t then return "no listing yet" end
	local mode = tostring((t :: { [string]: any }).Mode)
	if mode == "price" then
		return "💰 Price: " .. tostring((t :: { [string]: any }).Price) .. " coins"
	elseif mode == "wanted" then
		local def = (PetData.PETS :: { [string]: any })[tostring((t :: { [string]: any }).Wanted)]
		return "🔎 Wants: " .. ((def and (def.Name :: string)) or "???")
	else
		return "💬 Open offers"
	end
end

local function openBoothPetPicker(title: string, onPick: (string) -> ())
	for _, c in boothPickScroll:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	boothPickTitle.Text = title
	local order = 0
	for _, rec in inventory do
		if not (rec :: { [string]: any }).IsStarter then
			order += 1
			local uid = (rec :: { [string]: any }).Uid
			local locked = (rec :: { [string]: any }).Reserved == true
			addPetCard(boothPickScroll, rec, order, {
				{ Text = if locked then "🏪 Listed" else "Pick", Color = if locked then Color3.fromRGB(90, 90, 100) else Color3.fromRGB(70, 110, 200),
					OnClick = function()
						if locked then
							toast("Already listed in your booth!", "warn")
						else
							boothPickFrame.Visible = false
							onPick(uid)
						end
					end },
			})
		end
	end
	boothPickFrame.Visible = true
end

-- 5-second hold-to-confirm on booth acceptance (shows the exact terms)
local function confirmHold(btn: TextButton, label: string, onFire: () -> ())
	if not btn or not btn.Parent then return end
	task.spawn(function()
		for i = 5, 1, -1 do
			if not btn.Parent then return end
			btn.Text = label .. " (" .. i .. ")..."
			task.wait(1)
		end
		if not btn.Parent then return end
		btn.Text = label
		onFire()
	end)
end

local function refreshBoothUI()
	for _, c in boothScroll:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	local order = 0
	for _, b in boothListings do
		order += 1
		local idx: number = (b :: { [string]: any }).Idx
		local ownerName: string? = (b :: { [string]: any }).OwnerName
		local pet = (b :: { [string]: any }).Pet
		local terms = (b :: { [string]: any }).Terms
		local mine = ownerName ~= nil and (b :: { [string]: any }).Owner == player.UserId
		local card = Instance.new("Frame")
		card.Name = "BoothCard"
		card.Size = UDim2.new(1, 0, 0, 150)
		card.BackgroundColor3 = if idx == boothFocus then Color3.fromRGB(48, 42, 66) else Color3.fromRGB(38, 38, 54)
		card.LayoutOrder = order
		card.Parent = boothScroll
		corner(card, 10)
		label(card, "🏪 Booth " .. idx, UDim2.new(0, 200, 0, 28), UDim2.new(0, 10, 0, 6), 17, Color3.fromRGB(255, 220, 160))
		if not ownerName then
			label(card, "Empty — claim it and start selling!", UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 36), 14, Color3.fromRGB(170, 170, 180))
			local claimB = button(card, "Claim booth", UDim2.new(0.6, 0, 0, 42), UDim2.new(0, 10, 0, 96), Color3.fromRGB(70, 130, 70)) -- v47: scale so narrow cards fit
			claimB.MouseButton1Click:Connect(function() R("BoothClaim"):FireServer(idx) end)
		elseif mine and not pet then
			label(card, "Yours! List a pet below:", UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 36), 14, Color3.fromRGB(170, 220, 170))
			-- v47: the two buttons split the card width (the old 200+160px pair overflowed phones)
			local listB = button(card, "🐾 List a pet...", UDim2.new(0.46, 0, 0, 42), UDim2.new(0, 10, 0, 64), Color3.fromRGB(70, 110, 200))
			listB.MouseButton1Click:Connect(function()
				openBoothPetPicker("Pick a pet to list (stays safe in your bag)", function(uid)
					boothListUid = uid
					-- terms entry row
					boothFocus = idx
					refreshBoothUI()
				end)
			end)
			local closeB = button(card, "Close booth", UDim2.new(0.46, 0, 0, 42), UDim2.new(0.54, -10, 0, 64), Color3.fromRGB(150, 70, 70))
			closeB.MouseButton1Click:Connect(function() R("BoothCancel"):FireServer(idx, "booth") end)
			if boothListUid and idx == boothFocus then
				-- terms form for the just-picked pet
				local picked: { [string]: any }? = nil
				for _, rec in inventory do
					if (rec :: { [string]: any }).Uid == boothListUid then picked = rec break end
				end
				local pname = if picked then PetData.PetName(picked) else "???"
				label(card, "Listing: " .. pname .. " — set terms:", UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 112), 13, Color3.fromRGB(255, 230, 170))
				card.Size = UDim2.new(1, 0, 0, 280) -- v47: taller for the stacked terms form
				-- v47: terms form stacks vertically with scale widths (the old fixed
				-- 150px boxes + side-by-side layout overflowed narrow cards)
				local priceBox = Instance.new("TextBox")
				priceBox.Size = UDim2.new(0.46, 0, 0, 36)
				priceBox.Position = UDim2.new(0, 10, 0, 140)
				priceBox.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
				priceBox.Text = ""
				priceBox.PlaceholderText = "💰 Price (coins)"
				priceBox.TextSize = 14
				priceBox.TextColor3 = Color3.fromRGB(255, 220, 120)
				priceBox.Font = Enum.Font.FredokaOne
				priceBox.Parent = card
				corner(priceBox, 8)
				local wantBox = Instance.new("TextBox")
				wantBox.Size = UDim2.new(0.46, 0, 0, 36)
				wantBox.Position = UDim2.new(0.54, -10, 0, 140)
				wantBox.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
				wantBox.Text = ""
				wantBox.PlaceholderText = "🔎 Wanted species"
				wantBox.TextSize = 14
				wantBox.TextColor3 = Color3.fromRGB(180, 220, 255)
				wantBox.Font = Enum.Font.FredokaOne
				wantBox.Parent = card
				corner(wantBox, 8)
				local goB = button(card, "✅ List it", UDim2.new(1, -20, 0, 40), UDim2.new(0, 10, 0, 182), Color3.fromRGB(70, 150, 70))
				goB.MouseButton1Click:Connect(function()
					local price = math.max(0, math.floor(tonumber(priceBox.Text) or 0))
					local want = string.gsub(tostring(wantBox.Text or ""), "%s+", "")
					-- match species name -> id (case-insensitive)
					local wantId: string? = nil
					if want ~= "" then
						for pid, def in (PetData.PETS :: { [string]: any }) do
							if string.lower(tostring((def :: { [string]: any }).Name)) == string.lower(want)
								or string.lower(tostring(pid)) == string.lower(want) then
								wantId = tostring(pid)
								break
							end
						end
						if not wantId then
							toast("Unknown species! Check the name.", "warn")
							return
						end
					end
					R("BoothList"):FireServer(idx, boothListUid, price, wantId or "")
					boothListUid = nil
				end)
				local termsHint = label(card, "Fill price OR wanted species — or neither for open offers.",
					UDim2.new(1, -20, 0, 40), UDim2.new(0, 10, 0, 226), 12, Color3.fromRGB(170, 160, 180))
				termsHint.TextWrapped = true -- v47
			end
		elseif mine then
			local p = (pet :: { [string]: any })
			label(card, "Yours: " .. tostring(p.Name) .. " [" .. tostring(p.Type) .. "] "
				.. string.rep("⭐", math.min(p.Stars or 0, 5)) .. (if p.Shiny then " ✨" else "") .. (if p.Titan then " 👑" else ""),
				UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 36), 14, Color3.fromRGB(200, 230, 200))
			label(card, termsText(terms), UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 62), 14, Color3.fromRGB(255, 230, 170))
			local cancelB = button(card, "Cancel listing", UDim2.new(0.46, 0, 0, 40), UDim2.new(0, 10, 0, 100), Color3.fromRGB(150, 110, 60))
			cancelB.MouseButton1Click:Connect(function() R("BoothCancel"):FireServer(idx, "listing") end)
			local closeB = button(card, "Close booth", UDim2.new(0.46, 0, 0, 40), UDim2.new(0.54, -10, 0, 100), Color3.fromRGB(150, 70, 70)) -- v47: scale pair, old 180+160px overflowed
			closeB.MouseButton1Click:Connect(function() R("BoothCancel"):FireServer(idx, "booth") end)
		else
			label(card, "Seller: " .. tostring(ownerName), UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 36), 14, Color3.fromRGB(200, 170, 170))
			if pet then
				local p = (pet :: { [string]: any })
				label(card, tostring(p.Name) .. " [" .. tostring(p.Type) .. "] "
					.. string.rep("⭐", math.min(p.Stars or 0, 5)) .. (if p.Shiny then " ✨" else "") .. (if p.Titan then " 👑" else ""),
					UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 60), 14, Color3.fromRGB(220, 220, 230))
				label(card, termsText(terms), UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 84), 14, Color3.fromRGB(255, 230, 170))
				local mode = tostring(((terms :: { [string]: any }) or {}).Mode)
				local buyB = button(card,
					if mode == "price" then "💰 Buy" else "🤝 Accept",
					UDim2.new(0.6, 0, 0, 42), UDim2.new(0, 10, 0, 100), Color3.fromRGB(70, 130, 70)) -- v47: scale (was fixed 200px)
				buyB.MouseButton1Click:Connect(function()
					if mode == "wanted" or mode == "open" then
						-- buyer picks their offered pet first
						boothOfferUid = nil
						boothOfferCoins = 0
						openBoothPetPicker("Pick YOUR pet to offer", function(uid)
							boothOfferUid = uid
							boothFocus = idx
							refreshBoothUI()
						end)
					else
						boothOfferUid = nil
						boothOfferCoins = 0
						boothFocus = idx
						refreshBoothUI()
					end
				end)
				if boothOfferUid and idx == boothFocus and (mode == "wanted" or mode == "open") then
					card.Size = UDim2.new(1, 0, 0, 210)
					local offering: { [string]: any }? = nil
					for _, rec in inventory do
						if (rec :: { [string]: any }).Uid == boothOfferUid then offering = rec break end
					end
					local oname = if offering then PetData.PetName(offering) else "???"
					label(card, "You offer: " .. oname, UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 146), 13, Color3.fromRGB(200, 220, 255))
					local goB = button(card, "✅ Accept deal", UDim2.new(0.6, 0, 0, 40), UDim2.new(0, 10, 0, 172), Color3.fromRGB(70, 150, 70)) -- v47: scale (was fixed 200px)
					goB.MouseButton1Click:Connect(function()
						goB.Active = false
						confirmHold(goB, "✅ Accept deal", function()
							R("BoothAccept"):FireServer(idx, boothOfferUid, boothOfferCoins)
							boothOfferUid = nil
						end)
					end)
				elseif idx == boothFocus and mode == "price" and boothOfferUid == nil and boothOfferCoins == 0 then
					-- price mode: straight to the 5s confirm
					card.Size = UDim2.new(1, 0, 0, 200)
					label(card, "Exact terms: pay " .. tostring(((terms :: { [string]: any }) or {}).Price) .. " coins.",
						UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 146), 13, Color3.fromRGB(255, 230, 170))
					local goB = button(card, "✅ Buy now", UDim2.new(0, 200, 0, 40), UDim2.new(0, 10, 0, 172), Color3.fromRGB(70, 150, 70))
					goB.MouseButton1Click:Connect(function()
						goB.Active = false
						confirmHold(goB, "✅ Buy now", function()
							R("BoothAccept"):FireServer(idx, "", 0)
						end)
					end)
				end
			else
				label(card, "No pet listed yet.", UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 60), 14, Color3.fromRGB(170, 170, 180))
			end
		end
	end
	boothFrame.Visible = true
end

R("BoothInfo").OnClientEvent:Connect(function(snap: { { [string]: any } })
	boothListings = snap
	if boothFrame.Visible then refreshBoothUI() end
end)

R("BoothOpen").OnClientEvent:Connect(function(idx: number, snap: { { [string]: any } })
	boothListings = snap
	boothFocus = idx
	boothListUid = nil
	boothOfferUid = nil
	refreshBoothUI()
end)

end
-- ============================================================================
-- ⛲ LUCKY FOUNTAIN (v22)
do
-- ============================================================================
local fountainPanel, fountainList = makePanel("Fountain", "⛲ Lucky Fountain", true)
local fountainState: { [string]: any }? = nil -- {Id, Until, Left}

local function blessingDisplay(id: string): (string, string)
	if id == "Jackpot" then return "🌈", "Fountain Jackpot (ALL blessings!)" end
	local b = (Config.Blessings :: { [string]: any })[id]
	if not b then return "⛲", id end
	return ((b :: { [string]: any }).Icon :: string), ((b :: { [string]: any }).Name :: string)
end

local confirmTier: string? = nil -- armed two-tap confirm when replacing a blessing

local function refreshFountainUI()
	for _, c in fountainList:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	local st = fountainState
	if st then
		local icon, name = blessingDisplay(st.Id :: string)
		label(fountainList, icon .. " " .. name .. " — " .. math.floor((st.Left or 0) / 60) .. "m left",
			UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 0), 16, Color3.fromRGB(160, 230, 255))
	else
		label(fountainList, "Toss a coin, make a wish! ✨",
			UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 0), 16, Color3.fromRGB(200, 220, 255))
	end
	local poolDesc = "Possible: 🌱 Growth +50% · 🍀 2x shiny · 🎣 fishing luck · 🪙 +25% sells · ✨ mutation luck"
	for i, t in (Config.WishTiers :: { { [string]: any } }) do
		local tier = t :: { [string]: any }
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 96)
		row.BackgroundColor3 = Color3.fromRGB(44, 52, 72)
		row.LayoutOrder = i
		row.Parent = fountainList
		corner(row, 8)
		label(row, "🪙 " .. (tier.Name :: string) .. " — " .. tostring(tier.Cost) .. "c",
			UDim2.new(1, -140, 0, 28), UDim2.new(0, 10, 0, 4), 17, Color3.fromRGB(255, 225, 160))
		label(row, (tier.Desc :: string) .. " · 🌈 jackpot " .. math.floor((tier.JackpotChance :: number) * 100) .. "%",
			UDim2.new(1, -140, 0, 30), UDim2.new(0, 10, 0, 32), 13, Color3.fromRGB(190, 205, 235))
		label(row, poolDesc, UDim2.new(1, -140, 0, 30), UDim2.new(0, 10, 0, 60), 11, Color3.fromRGB(150, 165, 195))
		local armed = confirmTier == (tier.Id :: string)
		local b = button(row, if armed then "Tap again\nto replace!" else "Make a\nwish!",
			UDim2.new(0, 118, 0, 76), UDim2.new(1, -128, 0, 10),
			if armed then Color3.fromRGB(190, 120, 40) else Color3.fromRGB(60, 130, 190))
		b.TextSize = 14
		b.MouseButton1Click:Connect(function()
			if fountainState and confirmTier ~= (tier.Id :: string) then
				confirmTier = tier.Id :: string -- two-tap confirm: a new wish replaces the old blessing
				refreshFountainUI()
				return
			end
			confirmTier = nil
			R("MakeWish"):FireServer(tier.Id)
		end)
	end
	fountainPanel.Visible = true
	openPanel = "Fountain"
end

-- the fountain glows while YOU have an active blessing (client-side light)
local function refreshFountainGlow()
	local decor = workspace:FindFirstChild("MapDecor")
	local light = decor and (decor :: Instance):FindFirstChild("FountainLight", true)
	if light and light:IsA("PointLight") then
		(light :: PointLight).Enabled = fountainState ~= nil
	end
end

R("FountainOpen").OnClientEvent:Connect(function(state: { [string]: any }?)
	fountainState = state
	confirmTier = nil
	refreshFountainGlow()
	refreshFountainUI()
end)
R("FountainState").OnClientEvent:Connect(function(state: { [string]: any }?)
	fountainState = state
	confirmTier = nil
	refreshFountainGlow()
	refreshTop()
	if openPanel == "Fountain" then refreshFountainUI() end
end)
R("FountainFX").OnClientEvent:Connect(function() -- coin splash + chime, fired by the server
	local decor = workspace:FindFirstChild("MapDecor")
	if decor then
		local splash = (decor :: Instance):FindFirstChild("FountainSplash", true)
		if splash and splash:IsA("ParticleEmitter") then
			(splash :: ParticleEmitter):Emit(40)
		end
	end
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	s.Volume = 0.6
	s.Parent = gui
	s:Play()
	task.delay(2, function() s:Destroy() end)
end)

-- event countdown ticker
task.spawn(function()
	while true do
		task.wait(1)
		local left = math.max(0, eventEndsAt - os.time())
		if left > 0 then
			eventLabel.Text = eventLabel.Text:gsub(" %(%d+m?%)$", "") .. " (" .. math.floor(left / 60) .. "m)"
		end
		-- v22: live blessing countdown (server clears on next access; client just dims the chip)
		local bb = buffs.Blessing
		if bb and (bb.Left or 0) > 0 then
			bb.Left = (bb.Left :: number) - 1
			if (bb.Left :: number) <= 0 then
				buffs.Blessing = nil
				fountainState = nil
				refreshFountainGlow()
			end
			refreshTop()
		end
		if battleView and battleFrame.Visible then
			-- refresh turn timer each second
			local v = battleView
			if v.BothPicked then
				battleTurn.Text = if v.YourTurn
					then "🟢 YOUR TURN! (" .. math.max(0, v.TurnEndsIn - 1) .. "s)"
					else "🔴 Opponent's turn... (" .. math.max(0, v.TurnEndsIn - 1) .. "s)"
				v.TurnEndsIn = math.max(0, v.TurnEndsIn - 1)
			end
		end
	end
end)

refreshTop()
print("[GrowAPet] Client HUD ready 🌷🐾⚔️")

end
-- ============================================================================
-- HEAL PICKER (choose which pet a Healing Potion heals)
do
-- ============================================================================
local healPickFrame = Instance.new("Frame")
healPickFrame.Size = UDim2.new(0.9, 0, 0.7, 0)
healPickFrame.Position = UDim2.new(0.05, 0, 0.15, 0)
healPickFrame.BackgroundColor3 = Color3.fromRGB(28, 34, 42)
healPickFrame.Visible = false
healPickFrame.ZIndex = 65 -- v47: modal picker above panels + popups
healPickFrame.Parent = gui
corner(healPickFrame, 12)
label(healPickFrame, "🧪 Who gets healed to full HP?", UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 0, 8), 18, Color3.fromRGB(180, 220, 255)).TextXAlignment = Enum.TextXAlignment.Center
local healX = button(healPickFrame, "X", UDim2.new(0, 40, 0, 32), UDim2.new(1, -48, 0, 8), Color3.fromRGB(170, 70, 70))
healX.MouseButton1Click:Connect(function() healPickFrame.Visible = false end)
local healPickScroll = Instance.new("ScrollingFrame")
healPickScroll.Size = UDim2.new(1, -16, 1, -56)
healPickScroll.Position = UDim2.new(0, 8, 0, 48)
healPickScroll.BackgroundTransparency = 1
healPickScroll.ScrollBarThickness = 6
healPickScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
healPickScroll.Parent = healPickFrame
local healPickLayout = Instance.new("UIListLayout")
healPickLayout.Padding = UDim.new(0, 8)
healPickLayout.Parent = healPickScroll

openHealPicker = function()
	for _, c in healPickScroll:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	local order = 0
	local anyHurt = false
	for _, rec in inventory do
		if math.floor(rec.HP or 0) < (rec.MaxHP or 0) then
			anyHurt = true
			order += 1
			local uid = rec.Uid
			addPetCard(healPickScroll, rec, order, {
				{ Text = "🧪 Heal", Color = Color3.fromRGB(60, 130, 180),
					OnClick = function()
						healPickFrame.Visible = false
						R("UsePotion"):FireServer("HealingPotion", uid)
					end },
			})
		end
	end
	if not anyHurt then
		order += 1
		label(healPickScroll, "All your pets are at full HP! ❤️", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 0), 15, Color3.fromRGB(170, 200, 170)).LayoutOrder = order
	end
	healPickFrame.Visible = true
end

end
-- ============================================================================
-- AMBIENT LIFE (client-side: butterflies + gentle plot-pet bobbing)
do
-- ============================================================================
local ambientFolder = Instance.new("Folder")
ambientFolder.Name = "AmbientLife"
ambientFolder.Parent = workspace

local BUTTERFLY_COLORS = {
	Color3.fromRGB(255, 150, 200),
	Color3.fromRGB(150, 200, 255),
	Color3.fromRGB(255, 220, 150),
	Color3.fromRGB(200, 160, 255),
	Color3.fromRGB(150, 255, 180),
	Color3.fromRGB(255, 170, 120),
}

local butterflies: { { m: Model, body: Part, wl: Part, wr: Part, cx: number, cz: number, ph: number, sp: number, r: number } } = {}
for i = 1, 8 do
	local b = Instance.new("Model")
	b.Name = "Butterfly"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(0.3, 0.3, 0.5)
	body.Color = Color3.fromRGB(60, 40, 30)
	body.Anchored = true
	body.CanCollide = false
	body.Parent = b
	local wingColor = BUTTERFLY_COLORS[(i - 1) % #BUTTERFLY_COLORS + 1]
	local wl = Instance.new("Part")
	wl.Name = "WingL"
	wl.Size = Vector3.new(0.8, 0.08, 0.6)
	wl.Color = wingColor
	wl.Material = Enum.Material.SmoothPlastic
	wl.Anchored = true
	wl.CanCollide = false
	wl.Parent = b
	local wr = wl:Clone()
	wr.Name = "WingR"
	wr.Parent = b
	b.PrimaryPart = body
	local cx, cz = math.random(-160, 160), math.random(-120, 120)
	b:PivotTo(CFrame.new(cx, 6 + math.random() * 6, cz))
	b.Parent = ambientFolder
	table.insert(butterflies, {
		m = b, body = body, wl = wl, wr = wr,
		cx = cx, cz = cz, ph = math.random() * 6.28,
		sp = 0.25 + math.random() * 0.3, r = 14 + math.random() * 22,
	})
end

-- gentle bob for plot pets only (parented under Garden_* folders; followers excluded)
local bobPets: { { m: Model, pivot: CFrame, ph: number } } = {}
local lastBobTick = 0
task.spawn(function()
	while true do
		local found: { { [string]: any } } = {}
		for _, d in workspace:GetDescendants() do
			if d:IsA("Model") and string.sub(d.Name, 1, 4) == "Pet_" then
				local par = d.Parent
				if par and par:IsA("Folder") and string.sub(par.Name, 1, 7) == "Garden_" then
					table.insert(found, { m = d, pivot = d:GetPivot(), ph = math.random() * 6.28 })
				end
			end
		end
		bobPets = found
		task.wait(5)
	end
end)

game:GetService("RunService").RenderStepped:Connect(function()
	local t = os.clock()
	-- butterflies: wander + flap
	for _, bf in butterflies do
		local a = t * bf.sp + bf.ph
		local px = bf.cx + math.cos(a) * bf.r
		local pz = bf.cz + math.sin(a * 0.8) * bf.r
		local py = 7 + math.sin(t * 1.7 + bf.ph) * 2.5
		local flap = math.sin(t * 14 + bf.ph) * 0.9
		bf.m:PivotTo(CFrame.new(px, py, pz) * CFrame.Angles(0, -a, 0))
		local bc = bf.body.CFrame
		bf.wl.CFrame = bc * CFrame.new(-0.45, 0.1, 0) * CFrame.Angles(0, 0, flap)
		bf.wr.CFrame = bc * CFrame.new(0.45, 0.1, 0) * CFrame.Angles(0, 0, -flap)
	end
	-- plot pets: soft bob, throttled to ~12 Hz (PivotTo keeps anchored parts together)
	if t - lastBobTick >= 0.08 then
		lastBobTick = t
		for _, bp in bobPets do
			if bp.m.Parent then
				local m, pivot, ph = bp.m, bp.pivot, bp.ph
				pcall(function()
					m:PivotTo(pivot * CFrame.new(0, math.sin(t * 2 + ph) * 0.18, 0))
				end)
			end
		end
	end
end)

end
-- ============================================================================
-- PHOTO MODE (assigned to the forward-declared setter above)
-- Hides all UI, frames the player, follower does a happy bounce.
-- Take the actual screenshot with your device's capture button. 📸
do
-- ============================================================================
local photoOverlay: Frame? = nil
local savedCamType: Enum.CameraType? = nil

local function followerHappyBounce()
	local m = workspace:FindFirstChild("Follower_" .. player.Name)
	if not (m and m:IsA("Model")) then return end
	local model = m :: Model
	task.spawn(function()
		pcall(function()
			for _ = 1, 3 do
				local base = model:GetPivot()
				for i = 1, 6 do
					model:PivotTo(base * CFrame.new(0, math.sin(i / 6 * math.pi) * 2.2, 0))
					task.wait(0.06)
				end
				model:PivotTo(base)
				task.wait(0.15)
			end
		end)
	end)
end

setPhotoMode = function(on: boolean)
	photoMode = on
	local cam = workspace.CurrentCamera
	if on then
		closePanels()
		closeRename()
		savedCamType = cam.CameraType
		-- hide the HUD (questPanel/others already hidden by closePanels)
		for _, v in { sidePanel, bottomBar, fishCard, toastHolder, announceFrame } do
			(v :: GuiObject).Visible = false
		end
		closeCat() -- v33: dismiss any open category menu
		-- overlay: subtle frame + hint + exit button
		local ov = Instance.new("Frame")
		ov.Name = "PhotoOverlay"
		ov.Size = UDim2.new(1, 0, 1, 0)
		ov.BackgroundTransparency = 1
		ov.ZIndex = 40
		ov.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 10
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Transparency = 0.55
		stroke.Parent = ov
		label(ov, "📸 Smile! Use your device's screenshot button to capture.",
			UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 30), 18, Color3.fromRGB(255, 255, 255))
		local exitB = button(ov, "X Exit Photo", UDim2.new(0, 170, 0, 52), UDim2.new(1, -186, 1, -140), Color3.fromRGB(60, 60, 80))
		exitB.MouseButton1Click:Connect(function()
			if setPhotoMode then setPhotoMode(false) end
		end)
		photoOverlay = ov
		-- frame the player nicely
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			local hp = (hrp :: BasePart).Position
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = CFrame.new(hp + Vector3.new(10, 5.5, 12), hp + Vector3.new(0, 3, 0))
		end
		followerHappyBounce()
	else
		if photoOverlay then photoOverlay:Destroy() photoOverlay = nil end
		sidePanel.Visible = true
		bottomBar.Visible = true
		toastHolder.Visible = true
		announceFrame.Visible = false
		if savedCamType then cam.CameraType = savedCamType end
	end
end

-- respawning mid-photo returns to normal (avoid a stuck scriptable camera)
player.CharacterAdded:Connect(function()
	if photoMode and setPhotoMode then setPhotoMode(false) end
end)

end