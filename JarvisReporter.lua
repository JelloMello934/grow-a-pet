--!strict
-- JarvisReporter (ModuleScript -> ReplicatedStorage > JarvisReporter)
-- Lets Jarvis SEE the game: ships Studio Play-session errors back automatically,
-- plus a once-a-minute heartbeat with game health (wild population, titans,
-- garden claims, plot states, FPS). STUDIO-ONLY: silent in a published game.
-- Sends: Lua error text, game-state numbers, timestamps. Nothing personal.

local REPORT_URL = "https://webhook.site/2eacd88f-7592-4605-a211-1e154d7cb272"

local Reporter = {}

local function post(payload: { [string]: any })
	pcall(function()
		local HttpService = game:GetService("HttpService")
		HttpService:PostAsync(REPORT_URL, HttpService:JSONEncode(payload), Enum.HttpContentType.ApplicationJson)
	end)
end

function Reporter.start(tag: string)
	local RunService = game:GetService("RunService")
	if not RunService:IsStudio() then
		return
	end
	local LogService = game:GetService("LogService")

	-- 1. Error stream (unchanged): every Lua error, deduped, flushed regularly
	local seen: { [string]: number } = {}
	local order: { string } = {}

	local function flushErrors()
		if #order == 0 then
			return
		end
		local batch: { { msg: string, count: number } } = {}
		for _, msg in ipairs(order) do
			table.insert(batch, { msg = msg, count = seen[msg] })
		end
		post({ source = "studio-play", tag = tag, at = os.time(), errors = batch })
		seen = {}
		order = {}
	end

	LogService.MessageOut:Connect(function(msg: string, msgType: Enum.MessageType)
		if msgType == Enum.MessageType.MessageError then
			if not seen[msg] then
				seen[msg] = 1
				table.insert(order, msg)
			else
				seen[msg] += 1
			end
			if #order >= 25 then
				task.spawn(flushErrors)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(45)
			pcall(flushErrors)
		end
	end)

	-- 2. Heartbeat: once a minute, snapshot of what the game is DOING
	local startClock = os.clock()
	local frames = 0
	if tag == "server" then
		RunService.Heartbeat:Connect(function()
			frames += 1
		end)
	else
		RunService.RenderStepped:Connect(function()
			frames += 1
		end)
	end

	task.spawn(function()
		task.wait(75) -- let the game settle before the first snapshot
		while true do
			local ok = pcall(function()
				local snap: { [string]: any } = {
					source = "studio-heartbeat",
					tag = tag,
					at = os.time(),
					uptime = math.floor(os.clock() - startClock),
					fps = math.floor(frames / 60 + 0.5),
				}
				frames = 0
				if tag == "server" then
					local Players = game:GetService("Players")
					local SSS = game:GetService("ServerScriptService")
					snap.players = #Players:GetPlayers()
					local WS = require(SSS:WaitForChild("WildSystem"))
					local GM = require(SSS:WaitForChild("GardenManager"))
					snap.wild = WS.GetHealth()
					snap.gardens = GM.GetHealth()
				end
				post(snap)
			end)
			if not ok then
				-- heartbeat must never break the game; just skip this round
			end
			task.wait(60)
		end
	end)

	print("[JarvisReporter] watching for errors + heartbeat (" .. tag .. ")")
end

return Reporter
