--!strict
-- PetData (ModuleScript -> ReplicatedStorage > Shared > PetData)
-- 58 pets: 3 starter lines (linear, 3 stages), 15 wild basics each with
-- 2-3 BRANCHING evolutions (incl. a sky-only flying line), 3 event-gated
-- secret final forms, 6 fossil pets (digging only).
-- No external assets: everything is Parts + Particles.
--
-- Growing loop: Pet Egg -> random basic (stage 1) -> grow the pet in a plot ->
-- evolution roll -> one of its branches (weighted; secrets need their event).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TypeChart = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TypeChart"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PetData = {}

export type PetDef = {
	Name: string,
	Rarity: string,
	Type: string,
	Stage: number, -- 1 = basic, 2 = evolved, 3 = final/secret
	Value: number, -- base sell price
	Nocturnal: boolean,
	Body: Color3,
	Ear: string, -- "point" | "flop" | "horn" | "fin" | "wing" | "none"
	Tail: boolean,
	Shell: boolean,
	Size: number,
	Move2: string?, -- coverage move type (defaults to own type)
	Starter: boolean?, -- true for the 9 starter-line pets
	ActiveTime: string, -- "Day" | "Night" | "Any": when this species comes out
	Fossil: boolean?, -- v14: fossil pets (digging only, never wild/egg)
	Sky: boolean?, -- v16: sky-island pets (sky zones only, never wild-lowlands/egg)
	Rot: boolean?, -- v21: rot-only pets (infestation only, never wild/egg)
	Twilight: boolean?, -- v23: twilight-dimension exclusives (never wild-lowlands/egg)
	Extras: { [string]: any }?, -- signature visuals: LeafCrown | Flippers | BackSpikes
		-- FireMane | AquaFins | Comb | CottonTail | VoltCheeks | IceShards
		-- RockSpikes | LavaSpikes | EyeDiscs | HeadCrest | TailTip | MoonMark
		-- AmberCore | WindSwirl | GlowEyes (value = eye Color3)
		-- Snout | Beak | Sprout | LeafRuff | BubbleDome | FlameTail | SparkTail | BigJaw
	Build: string?, -- body silhouette: "pup" (default) | "stocky" | "slim" | "blob" | "long"
}

local C = Color3.fromRGB

local P: { [string]: PetDef } = {}
local function pet(id: string, name: string, rarity: string, ptype: string, stage: number,
	value: number, noct: boolean, body: Color3, ear: string, tail: boolean, shell: boolean,
	size: number, move2: string?, starter: boolean?, extras: { [string]: any }?, active: string?, fossil: boolean?,
	sky: boolean?, rot: boolean?, twilight: boolean?)
	P[id] = { Name = name, Rarity = rarity, Type = ptype, Stage = stage, Value = value,
		Nocturnal = noct, Body = body, Ear = ear, Tail = tail, Shell = shell, Size = size,
		Move2 = move2, Starter = starter, Extras = extras, ActiveTime = active or "Any", Fossil = fossil,
		Sky = sky, Rot = rot, Twilight = twilight }
end

-- ============ STARTERS (linear lines, picked on first join, never sellable) ============
-- Grass line
pet("Leafpup", "Leafpup", "Rare", "Grass", 1, 5000, false, C(55, 195, 55), "point", true, false, 0.95, "Ground", true, { LeafCrown = true })
pet("Florawolf", "Florawolf", "Epic", "Grass", 2, 20000, false, C(40, 181, 40), "point", true, false, 1.1, "Ground", true, { LeafCrown = true })
pet("Terragrowl", "Terragrowl", "Legendary", "Grass", 3, 80000, false, C(25, 168, 25), "horn", true, false, 1.3, "Ground", true, { LeafCrown = true })
-- Fire line
pet("Cindercub", "Cindercub", "Rare", "Fire", 1, 5000, false, C(241, 85, 0), "point", true, false, 0.95, "Flying", true, { FireMane = true })
pet("Flamane", "Flamane", "Epic", "Fire", 2, 20000, false, C(237, 72, 0), "point", true, false, 1.1, "Flying", true, { FireMane = true })
pet("Infernoar", "Infernoar", "Legendary", "Fire", 3, 80000, false, C(223, 57, 0), "wing", true, false, 1.3, "Flying", true, { FireMane = true })
-- Water line
pet("Bubblin", "Bubblin", "Rare", "Water", 1, 5000, false, C(19, 122, 241), "fin", true, false, 0.95, "Ice", true, { AquaFins = true })
pet("Riptide", "Riptide", "Epic", "Water", 2, 20000, false, C(0, 101, 237), "fin", true, false, 1.1, "Ice", true, { AquaFins = true })
pet("Abyssjaw", "Abyssjaw", "Legendary", "Water", 3, 80000, false, C(0, 89, 223), "fin", true, false, 1.3, "Ice", true, { AquaFins = true })

-- ============ CLAUDE BATCH (2026-10-04): 6 new lines x 3 stages, 50c shop preview ============
-- Grass: Mossbun bunny line
pet("Mossbun", "Mossbun", "Common", "Grass", 1, 150, false, C(243, 235, 210), "point", true, false, 0.85, "Ground", nil, { CottonTail = true, LeafCrown = true }, "Day")
pet("Clovelop", "Clovelop", "Uncommon", "Grass", 2, 800, false, C(240, 232, 200), "point", true, false, 1.05, "Ground", nil, { CottonTail = true, LeafCrown = true }, "Day")
pet("Meadowhare", "Meadowhare", "Rare", "Grass", 3, 4000, false, C(238, 230, 195), "point", true, false, 1.3, "Ground", nil, { CottonTail = true, LeafCrown = true }, "Day")
-- Grass: Leafling caterpillar -> butterfly line
pet("Leafling", "Leafling", "Common", "Grass", 1, 150, false, C(168, 214, 90), "none", false, false, 0.8, nil, nil, { Sprout = true }, "Day")
pet("Budwing", "Budwing", "Uncommon", "Grass", 2, 800, false, C(150, 200, 90), "none", false, false, 1.0, nil, nil, { Sprout = true }, "Day")
pet("Blossomwing", "Blossomwing", "Rare", "Grass", 3, 4000, false, C(246, 205, 215), "wing", false, false, 1.1, "Flying", nil, { Sprout = true }, "Day")
-- Fire: Cinderkit fox line
pet("Cinderkit", "Cinderkit", "Common", "Fire", 1, 150, false, C(242, 118, 46), "point", true, false, 0.85, "Flying", nil, { FireMane = true }, "Day")
pet("Flarefox", "Flarefox", "Uncommon", "Fire", 2, 800, false, C(245, 110, 40), "point", true, false, 1.05, "Flying", nil, { FireMane = true, TailTip = true }, "Day")
pet("Solarfox", "Solarfox", "Rare", "Fire", 3, 4000, false, C(250, 120, 45), "point", true, false, 1.3, "Flying", nil, { FireMane = true, TailTip = true }, "Day")
-- Fire: Emberchick phoenix line
pet("Emberchick", "Emberchick", "Common", "Fire", 1, 150, false, C(232, 69, 44), "wing", true, false, 0.8, "Flying", nil, { Beak = true, HeadCrest = true }, "Day")
pet("Blazewing", "Blazewing", "Uncommon", "Fire", 2, 800, false, C(240, 90, 40), "wing", true, false, 1.05, "Flying", nil, { Beak = true, HeadCrest = true }, "Day")
pet("Sunphoenix", "Sunphoenix", "Rare", "Fire", 3, 4000, false, C(245, 120, 47), "wing", true, false, 1.3, "Flying", nil, { Beak = true, HeadCrest = true }, "Day")
-- Water: Ripplet otter line
pet("Ripplet", "Ripplet", "Common", "Water", 1, 150, false, C(91, 155, 213), "fin", true, false, 0.85, "Ice", nil, { AquaFins = true, Snout = true }, "Day")
pet("Brookotter", "Brookotter", "Uncommon", "Water", 2, 800, false, C(80, 145, 205), "fin", true, false, 1.05, "Ice", nil, { AquaFins = true, Snout = true }, "Day")
pet("Tidalotter", "Tidalotter", "Rare", "Water", 3, 4000, false, C(70, 135, 200), "fin", true, false, 1.2, "Ice", nil, { AquaFins = true, Snout = true, BackSpikes = true }, "Day")
-- Water: Foamclaw crab line
pet("Foamclaw", "Foamclaw", "Common", "Water", 1, 150, false, C(63, 184, 175), "none", false, true, 0.9, nil, nil, nil, "Day")
pet("Pearlclaw", "Pearlclaw", "Uncommon", "Water", 2, 800, false, C(70, 190, 180), "none", false, true, 1.1, nil, nil, nil, "Day")
pet("Reefking", "Reefking", "Rare", "Water", 3, 4000, false, C(75, 195, 185), "none", false, true, 1.35, nil, nil, { RockSpikes = true }, "Day")

-- ============ WILD BASICS (stage 1, hatch from Pet Eggs) ============
pet("Chick", "Chick", "Common", "Normal", 1, 120, false, C(255, 211, 0), "none", false, false, 0.7, nil, nil, { Comb = true }, "Day")
pet("Bunny", "Bunny", "Common", "Normal", 1, 120, false, C(246, 246, 246), "flop", true, false, 0.9, nil, nil, { CottonTail = true }, "Night")
pet("Voltpup", "Voltpup", "Uncommon", "Electric", 1, 400, false, C(255, 201, 0), "point", true, false, 0.9, nil, nil, { VoltCheeks = true }, "Day")
pet("Pinnipup", "Pinnipup", "Common", "Water", 1, 150, false, C(85, 154, 223), "fin", true, false, 0.9, nil, nil, { AquaFins = true })
pet("Pebblor", "Pebblor", "Common", "Ground", 1, 160, false, C(186, 133, 81), "none", false, false, 0.85, nil, nil, { RockSpikes = true })
pet("Hootlet", "Hootlet", "Common", "Flying", 1, 140, false, C(177, 124, 71), "none", false, false, 0.85, nil, nil, { EyeDiscs = true }, "Night")
pet("Sproutie", "Sproutie", "Common", "Grass", 1, 150, false, C(65, 204, 65), "none", false, false, 0.8, nil, nil, { LeafCrown = true }, "Day")
pet("Cindert", "Cindert", "Uncommon", "Fire", 1, 450, false, C(241, 80, 0), "fin", true, false, 0.9, nil, nil, { FireMane = true }, "Day")
pet("Gustling", "Gustling", "Common", "Flying", 1, 170, false, C(177, 194, 237), "wing", false, false, 0.85, nil, nil, { HeadCrest = true })
pet("Turtle", "Turtle", "Uncommon", "Water", 1, 500, false, C(63, 186, 63), "none", true, true, 0.9, nil, nil, { Flippers = true })
pet("Fox", "Fox", "Uncommon", "Normal", 1, 550, true, C(232, 96, 0), "point", true, false, 1.0, nil, nil, { TailTip = true }, "Night")
pet("Drakeling", "Drakeling", "Rare", "Fire", 1, 2500, false, C(204, 29, 0), "wing", true, false, 0.9, nil, nil, { BackSpikes = true }, "Night")
-- ============ STAGE 2 BRANCHES ============
pet("Cluckwing", "Cluckwing", "Uncommon", "Flying", 2, 700, false, C(255, 230, 77), "wing", true, false, 1.0, nil, nil, { Comb = true }, "Day")
pet("Pyrochick", "Pyrochick", "Uncommon", "Fire", 2, 800, false, C(255, 118, 0), "wing", true, false, 1.0, "Flying", nil, { Comb = true }, "Day")
pet("Jackalope", "Jackalope", "Uncommon", "Normal", 2, 800, false, C(237, 219, 185), "horn", true, false, 1.05, nil, nil, { CottonTail = true }, "Night")
pet("Moonhare", "Moonhare", "Rare", "Normal", 2, 1500, true, C(181, 189, 232), "flop", true, false, 1.05, nil, nil, { CottonTail = true }, "Night")
pet("Dunehopper", "Dunehopper", "Uncommon", "Ground", 2, 900, false, C(223, 171, 85), "point", true, false, 1.0, nil, nil, { CottonTail = true }, "Day")
pet("Amperion", "Amperion", "Rare", "Electric", 2, 3000, false, C(255, 193, 0), "horn", true, false, 1.15, nil, nil, { VoltCheeks = true }, "Day")
pet("Sparkstriker", "Sparkstriker", "Rare", "Flying", 2, 2800, false, C(250, 208, 46), "wing", true, false, 1.1, "Electric", nil, { VoltCheeks = true }, "Day")
pet("Glacipup", "Glacipup", "Uncommon", "Ice", 2, 900, false, C(169, 220, 246), "point", true, false, 1.0, "Water", nil, { IceShards = true })
pet("Tidecaller", "Tidecaller", "Uncommon", "Water", 2, 1000, false, C(9, 112, 232), "fin", true, false, 1.05, nil, nil, { AquaFins = true }, "Night")
pet("Bouldurr", "Bouldurr", "Uncommon", "Ground", 2, 1000, false, C(158, 122, 87), "none", false, false, 1.15, nil, nil, { RockSpikes = true })
pet("Magmite", "Magmite", "Rare", "Fire", 2, 2600, false, C(186, 29, 0), "horn", false, false, 1.0, "Ground", nil, { LavaSpikes = true })
pet("Noctowl", "Noctowl", "Uncommon", "Dark", 2, 1100, true, C(84, 75, 122), "none", false, false, 1.0, "Flying", nil, { EyeDiscs = true, GlowEyes = C(150, 200, 255) }, "Night")
pet("Stormowl", "Stormowl", "Rare", "Electric", 2, 2800, false, C(102, 137, 223), "wing", false, false, 1.1, "Flying", nil, { EyeDiscs = true, VoltCheeks = true }, "Day")
pet("Thornback", "Thornback", "Uncommon", "Grass", 2, 950, false, C(45, 186, 45), "horn", true, false, 1.0, nil, nil, { BackSpikes = true }, "Day")
pet("Mosshorn", "Mosshorn", "Rare", "Ground", 2, 2400, false, C(124, 177, 88), "horn", true, false, 1.15, "Grass", nil, { RockSpikes = true })
pet("Cragmite", "Cragmite", "Rare", "Ground", 2, 3200, false, C(140, 103, 76), "none", true, true, 1.15, "Fire", nil, { RockSpikes = true })
pet("Infernite", "Infernite", "Rare", "Fire", 2, 3400, false, C(232, 52, 0), "horn", true, false, 1.15, nil, nil, { FireMane = true }, "Day")
pet("Tempestra", "Tempestra", "Uncommon", "Flying", 2, 1050, false, C(139, 173, 241), "wing", true, false, 1.05, "Electric", nil, { HeadCrest = true }, "Day")
pet("Skyshriek", "Skyshriek", "Rare", "Dark", 2, 3000, true, C(70, 60, 117), "wing", true, false, 1.1, "Flying", nil, { HeadCrest = true, GlowEyes = C(255, 80, 80) }, "Night")
pet("Shellguard", "Shellguard", "Rare", "Water", 2, 3500, false, C(48, 172, 128), "none", true, true, 1.15, nil, nil, { Flippers = true })
pet("Tidalord", "Tidalord", "Epic", "Water", 2, 12000, false, C(0, 119, 204), "fin", true, false, 1.3, nil, nil, { Flippers = true }, "Night")
pet("Emberfox", "Emberfox", "Rare", "Fire", 2, 3800, false, C(237, 100, 0), "point", true, false, 1.1, nil, nil, { FireMane = true, TailTip = true }, "Day")
pet("Duskfox", "Duskfox", "Rare", "Dark", 2, 4000, true, C(113, 77, 149), "point", true, false, 1.1, nil, nil, { TailTip = true, GlowEyes = C(255, 240, 170) }, "Night")
pet("Drakewing", "Drakewing", "Epic", "Flying", 2, 22000, false, C(195, 21, 3), "wing", true, false, 1.25, "Fire", nil, { BackSpikes = true }, "Day")
pet("Cinderdrake", "Cinderdrake", "Epic", "Fire", 2, 25000, false, C(214, 28, 0), "wing", true, false, 1.25, nil, nil, { BackSpikes = true }, "Day")
-- ============ SECRETS (stage 3, event-gated evolution branches) ============
pet("PrimordialTurtle", "Primordial Turtle", "Secret", "Water", 3, 750000, false, C(59, 149, 95), "none", true, true, 1.4, nil, nil, { Flippers = true })
pet("LunarFox", "Lunar Fox", "Secret", "Dark", 3, 1200000, true, C(125, 160, 237), "point", true, false, 1.2, nil, nil, { MoonMark = true, GlowEyes = C(230, 240, 255) }, "Night")
pet("VoidDragon", "Void Dragon", "Secret", "Dark", 3, 2500000, true, C(46, 9, 122), "wing", true, false, 1.4, nil, nil, { BackSpikes = true, GlowEyes = C(180, 120, 255) }, "Night")
-- ============ FOSSILS (v14: dug up, never wild, never from eggs) ============
-- Two linear 3-stage Ground lines (the game's rock type), revived from
-- fossil fragments found by digging. Rare -> Epic -> Legendary.
pet("Relikub", "Relikub", "Rare", "Ground", 1, 3000, false, C(195, 143, 90), "none", false, false, 0.85, "Grass", nil, { RockSpikes = true, AmberCore = true }, "Any", true)
pet("Fossilith", "Fossilith", "Epic", "Ground", 2, 20000, false, C(168, 132, 87), "none", true, false, 1.15, "Grass", nil, { RockSpikes = true, AmberCore = true }, "Any", true)
pet("Monolithon", "Monolithon", "Legendary", "Ground", 3, 70000, false, C(140, 113, 76), "horn", true, false, 1.35, "Grass", nil, { RockSpikes = true, AmberCore = true, GlowEyes = C(255, 180, 60) }, "Any", true)
pet("Sedimite", "Sedimite", "Rare", "Ground", 1, 3000, false, C(204, 161, 109), "none", false, false, 0.85, "Fire", nil, { AmberCore = true }, "Any", true)
pet("Excavore", "Excavore", "Epic", "Ground", 2, 20000, false, C(181, 137, 93), "none", true, false, 1.15, "Fire", nil, { RockSpikes = true, AmberCore = true }, "Any", true)
pet("Cragolith", "Cragolith", "Legendary", "Ground", 3, 70000, false, C(149, 122, 86), "horn", true, false, 1.35, "Fire", nil, { RockSpikes = true, AmberCore = true }, "Any", true)

-- ============ SKY LINE (v16: sky-island only, never wild-lowlands, never eggs) ============
-- The Zephyric line rides the winds above the west lake. Stage 1 only spawns
-- on the sky islands; stage 2/3 are reached by growing like any other pet.
pet("Zephyric", "Zephyric", "Uncommon", "Flying", 1, 600, false, C(135, 186, 246), "wing", false, false, 0.85, "Electric", nil, { HeadCrest = true, WindSwirl = true }, "Day", nil, true)
pet("Gustwing", "Gustwing", "Rare", "Flying", 2, 3200, false, C(87, 156, 241), "wing", true, false, 1.1, "Electric", nil, { HeadCrest = true, WindSwirl = true }, "Day", nil, true)
pet("Stormsoar", "Stormsoar", "Epic", "Flying", 3, 24000, false, C(43, 112, 232), "wing", true, false, 1.3, "Electric", nil, { HeadCrest = true, WindSwirl = true, GlowEyes = C(200, 230, 255) }, "Day", nil, true)

-- ============ BUG LINE (v21: rot-only — never wild, never from eggs) ============
-- Leave a Ready plot unclaimed too long (online) and the pet rots into these
-- creepy-crawlies. Neglect becomes discovery: they evolve/fuse/battle/trade
-- like any other pet. Linear 3-stage line, like the starters.
pet("Grublet", "Grublet", "Uncommon", "Bug", 1, 600, false, C(137, 181, 32), "none", true, false, 0.8, "Dark", nil, { EyeDiscs = true }, "Any", nil, nil, true)
pet("Miasmite", "Miasmite", "Rare", "Bug", 2, 3200, false, C(114, 168, 7), "horn", true, false, 1.05, "Dark", nil, { BackSpikes = true }, "Any", nil, nil, true)
pet("Blightwing", "Blightwing", "Epic", "Bug", 3, 18000, true, C(88, 149, 0), "wing", true, false, 1.25, "Dark", nil, { BackSpikes = true, GlowEyes = C(190, 230, 90) }, "Night", nil, nil, true)

-- ============ TWILIGHT DIMENSION (v23: exclusive to the dimension — never wild-lowlands, never eggs) ============
-- A light line that only roams Daybreak Meadows (eternal day) and a dark line
-- that only roams the Umbral Fields (eternal night). Linear 3-stage lines.
pet("Brightpup", "Brightpup", "Uncommon", "Electric", 1, 700, false, C(255, 216, 77), "point", true, false, 0.9, nil, nil, { HeadCrest = true, GlowEyes = C(255, 200, 80) }, "Day", nil, nil, nil, true)
pet("Glimmerolt", "Glimmerolt", "Rare", "Electric", 2, 3400, false, C(250, 199, 46), "point", true, false, 1.1, nil, nil, { HeadCrest = true, GlowEyes = C(255, 205, 90) }, "Day", nil, nil, nil, true)
pet("Aurorion", "Aurorion", "Epic", "Electric", 3, 20000, false, C(246, 178, 16), "wing", true, false, 1.3, nil, nil, { HeadCrest = true, GlowEyes = C(255, 210, 100) }, "Day", nil, nil, nil, true)
pet("Duskit", "Duskit", "Uncommon", "Dark", 1, 700, false, C(72, 54, 145), "point", true, false, 0.9, nil, nil, { GlowEyes = C(190, 130, 255) }, "Night", nil, nil, nil, true)
pet("Shadetail", "Shadetail", "Rare", "Dark", 2, 3400, true, C(57, 38, 131), "point", true, false, 1.1, nil, nil, { TailTip = true, GlowEyes = C(195, 135, 255) }, "Night", nil, nil, nil, true)
pet("Eclipsire", "Eclipsire", "Epic", "Dark", 3, 20000, true, C(37, 18, 122), "wing", true, false, 1.3, nil, nil, { MoonMark = true, GlowEyes = C(200, 140, 255) }, "Night", nil, nil, nil, true)
PetData.PETS = P

-- v47 visual identity pass: distinct body silhouettes + signature extras per
-- species, so pets read as different animals instead of recolors. (v48: all
-- parts converted to chunky BGS-style cubes.) The three
-- starter lines are the most distinct: grass = stocky forest guardian with a
-- sprout/leaf collar, fire = slim ember predator with muzzle + flame mane,
-- water = round blob with bubble helmet / heavy jaw.
local VISUALS: { [string]: { build: string?, add: { [string]: any }? } } = {
	-- STARTERS: grass line (stocky guardian, sprout + leaf ruff)
	Leafpup = { build = "stocky", add = { Sprout = true } },
	Florawolf = { build = "stocky", add = { Sprout = true, LeafRuff = true } },
	Terragrowl = { build = "stocky", add = { Sprout = true, LeafRuff = true } },
	-- STARTERS: fire line (slim predator, muzzle + flame mane)
	Cindercub = { build = "slim", add = { Snout = true } },
	Flamane = { build = "slim", add = { Snout = true } },
	Infernoar = { build = "slim", add = { Snout = true, FlameTail = true } },
	-- STARTERS: water line (round blob, bubble helmet / heavy jaw)
	Bubblin = { build = "blob", add = { BubbleDome = true } },
	Riptide = { build = "blob", add = { BubbleDome = true } },
	Abyssjaw = { build = "blob", add = { BigJaw = true } },
	-- WILD BASICS
	Chick = { add = { Beak = true } },
	Bunny = { build = "long" },
	Voltpup = { add = { Snout = true, SparkTail = true } },
	Pinnipup = { build = "blob", add = { Snout = true } },
	Pebblor = { build = "stocky" },
	Hootlet = { add = { Beak = true } },
	Sproutie = { add = { Sprout = true } },
	Cindert = { build = "slim", add = { Snout = true } },
	Gustling = { build = "slim", add = { Beak = true } },
	Turtle = { build = "stocky" },
	Fox = { build = "slim", add = { Snout = true } },
	Drakeling = { build = "slim", add = { Snout = true } },
	-- STAGE 2 BRANCHES
	Cluckwing = { add = { Beak = true } },
	Pyrochick = { add = { Beak = true } },
	Jackalope = { build = "long" },
	Moonhare = { build = "long" },
	Dunehopper = { build = "long" },
	Amperion = { build = "slim", add = { Snout = true, SparkTail = true } },
	Sparkstriker = { build = "slim", add = { SparkTail = true } },
	Glacipup = { add = { Snout = true } },
	Tidecaller = { build = "blob" },
	Bouldurr = { build = "stocky" },
	Magmite = { build = "stocky" },
	Noctowl = { add = { Beak = true } },
	Stormowl = { add = { Beak = true, SparkTail = true } },
	Thornback = { build = "stocky" },
	Mosshorn = { build = "stocky" },
	Cragmite = { build = "stocky" },
	Infernite = { build = "slim", add = { Snout = true } },
	Tempestra = { build = "slim", add = { Beak = true } },
	Skyshriek = { build = "slim", add = { Beak = true } },
	Shellguard = { build = "stocky" },
	Tidalord = { build = "blob" },
	Emberfox = { build = "slim", add = { Snout = true, FlameTail = true } },
	Duskfox = { build = "slim", add = { Snout = true } },
	Drakewing = { build = "slim", add = { Snout = true } },
	Cinderdrake = { build = "slim", add = { Snout = true } },
	-- SECRETS
	PrimordialTurtle = { build = "stocky" },
	LunarFox = { build = "slim", add = { Snout = true } },
	VoidDragon = { build = "slim", add = { Snout = true } },
	-- FOSSILS (heavy rock bodies)
	Relikub = { build = "stocky" },
	Fossilith = { build = "stocky" },
	Monolithon = { build = "stocky" },
	Sedimite = { build = "stocky" },
	Excavore = { build = "stocky" },
	Cragolith = { build = "stocky" },
	-- SKY LINE (sleek fliers)
	Zephyric = { build = "slim", add = { Beak = true } },
	Gustwing = { build = "slim", add = { Beak = true } },
	Stormsoar = { build = "slim", add = { Beak = true } },
	-- BUG LINE (long grubs)
	Grublet = { build = "long" },
	Miasmite = { build = "long" },
	Blightwing = { build = "long" },
	-- TWILIGHT DIMENSION
	Brightpup = { add = { Snout = true } },
	Glimmerolt = { build = "slim", add = { Snout = true, SparkTail = true } },
	Aurorion = { build = "slim", add = { SparkTail = true } },
	Duskit = { add = { Snout = true } },
	Shadetail = { build = "slim", add = { Snout = true } },
	Eclipsire = { build = "slim", add = { Snout = true } },
}
for id, v in VISUALS do
	local d = P[id]
	if d then
		if v.build then d.Build = v.build end
		if v.add then
			local x = d.Extras or {}
			d.Extras = x
			for k, val in v.add do x[k] = val end
		end
	end
end

-- Starter pick options (stage-1 of each starter line)
PetData.STARTERS = { "Leafpup", "Cindercub", "Bubblin" }
-- v14: fossil species revivable from fragments (stage-1 ids)
PetData.FOSSIL_STARTERS = { "Relikub", "Sedimite" }
PetData.STARTER_DESC = {
	Leafpup = "The loyal Grass pup. Strong vs Water, evolves into Florawolf then Terragrowl.",
	Cindercub = "The fiery cub. Strong vs Grass, evolves into Flamane then Infernoar.",
	Bubblin = "The bubbly swimmer. Strong vs Fire, evolves into Riptide then Abyssjaw.",
}

-- Evolution branches: petId -> list of {To, Weight, Event?}
-- Event-gated branches only roll while that event is active.
PetData.EVOLUTIONS = {
	Leafpup = { { To = "Florawolf", Weight = 100 } },
	Florawolf = { { To = "Terragrowl", Weight = 100 } },
	Cindercub = { { To = "Flamane", Weight = 100 } },
	Flamane = { { To = "Infernoar", Weight = 100 } },
	Bubblin = { { To = "Riptide", Weight = 100 } },
	Riptide = { { To = "Abyssjaw", Weight = 100 } },
	Chick = { { To = "Cluckwing", Weight = 50 }, { To = "Pyrochick", Weight = 50 } },
	Bunny = { { To = "Jackalope", Weight = 40 }, { To = "Moonhare", Weight = 35 }, { To = "Dunehopper", Weight = 25 } },
	Voltpup = { { To = "Amperion", Weight = 55 }, { To = "Sparkstriker", Weight = 45 } },
	Pinnipup = { { To = "Glacipup", Weight = 50 }, { To = "Tidecaller", Weight = 50 } },
	Pebblor = { { To = "Bouldurr", Weight = 55 }, { To = "Magmite", Weight = 45 } },
	Hootlet = { { To = "Noctowl", Weight = 50 }, { To = "Stormowl", Weight = 50 } },
	Sproutie = { { To = "Thornback", Weight = 55 }, { To = "Mosshorn", Weight = 45 } },
	Cindert = { { To = "Cragmite", Weight = 50 }, { To = "Infernite", Weight = 50 } },
	Gustling = { { To = "Tempestra", Weight = 55 }, { To = "Skyshriek", Weight = 45 } },
	Turtle = { { To = "Shellguard", Weight = 40 }, { To = "Tidalord", Weight = 40 },
		{ To = "PrimordialTurtle", Weight = 20, Event = "Rain" } },
	Fox = { { To = "Emberfox", Weight = 40 }, { To = "Duskfox", Weight = 40 },
		{ To = "LunarFox", Weight = 20, Event = "Night" } },
	Drakeling = { { To = "Drakewing", Weight = 40 }, { To = "Cinderdrake", Weight = 40 },
		{ To = "VoidDragon", Weight = 20, Event = "Meteor" } },
	-- v14: fossil lines evolve linearly like the starters
	Relikub = { { To = "Fossilith", Weight = 100 } },
	Fossilith = { { To = "Monolithon", Weight = 100 } },
	Sedimite = { { To = "Excavore", Weight = 100 } },
	Excavore = { { To = "Cragolith", Weight = 100 } },
	-- v16: sky line evolves linearly too
	Zephyric = { { To = "Gustwing", Weight = 100 } },
	Gustwing = { { To = "Stormsoar", Weight = 100 } },
	-- v21: rot-only bug line (linear)
	Grublet = { { To = "Miasmite", Weight = 100 } },
	Miasmite = { { To = "Blightwing", Weight = 100 } },
	-- v23: twilight-dimension lines (linear)
	Brightpup = { { To = "Glimmerolt", Weight = 100 } },
	Glimmerolt = { { To = "Aurorion", Weight = 100 } },
	Duskit = { { To = "Shadetail", Weight = 100 } },
	Shadetail = { { To = "Eclipsire", Weight = 100 } },
	-- Claude batch (2026-10-04): linear 3-stage lines
	Mossbun = { { To = "Clovelop", Weight = 100 } },
	Clovelop = { { To = "Meadowhare", Weight = 100 } },
	Leafling = { { To = "Budwing", Weight = 100 } },
	Budwing = { { To = "Blossomwing", Weight = 100 } },
	Cinderkit = { { To = "Flarefox", Weight = 100 } },
	Flarefox = { { To = "Solarfox", Weight = 100 } },
	Emberchick = { { To = "Blazewing", Weight = 100 } },
	Blazewing = { { To = "Sunphoenix", Weight = 100 } },
	Ripplet = { { To = "Brookotter", Weight = 100 } },
	Brookotter = { { To = "Tidalotter", Weight = 100 } },
	Foamclaw = { { To = "Pearlclaw", Weight = 100 } },
	Pearlclaw = { { To = "Reefking", Weight = 100 } },
}

-- ============ EVOLUTION STONES (v24) — pick your branch ============
-- One stone per evolution branch of every multi-branch species. Using the
-- matching stone on a growing pet FORCES that branch at harvest (the stone
-- is consumed only if the evolution actually happens). Without a stone,
-- evolution rolls branches exactly as before — stones are pure agency,
-- never required. Event-gated branches (secrets) still need their event:
-- a stone can't force a branch whose gate isn't open.
-- stoneId -> {Name, To (branch target petId), From (source species petId), Price}
PetData.EVO_STONES = {
	-- Chick
	CluckwingStone = { Name = "🪨 Skyplume Stone", To = "Cluckwing", From = "Chick", Price = 250,
		Desc = "Forces Chick → Cluckwing" },
	PyrochickStone = { Name = "🪨 Emberquill Stone", To = "Pyrochick", From = "Chick", Price = 250,
		Desc = "Forces Chick → Pyrochick" },
	-- Bunny
	JackalopeStone = { Name = "🪨 Horncrest Stone", To = "Jackalope", From = "Bunny", Price = 250,
		Desc = "Forces Bunny → Jackalope" },
	MoonhareStone = { Name = "🪨 Moonlace Stone", To = "Moonhare", From = "Bunny", Price = 350,
		Desc = "Forces Bunny → Moonhare" },
	DunehopperStone = { Name = "🪨 Sandpaw Stone", To = "Dunehopper", From = "Bunny", Price = 250,
		Desc = "Forces Bunny → Dunehopper" },
	-- Voltpup
	AmperionStone = { Name = "🪨 Voltcore Stone", To = "Amperion", From = "Voltpup", Price = 350,
		Desc = "Forces Voltpup → Amperion" },
	SparkstrikerStone = { Name = "🪨 Stormpinion Stone", To = "Sparkstriker", From = "Voltpup", Price = 350,
		Desc = "Forces Voltpup → Sparkstriker" },
	-- Pinnipup
	GlacipupStone = { Name = "🪨 Glacier Stone", To = "Glacipup", From = "Pinnipup", Price = 250,
		Desc = "Forces Pinnipup → Glacipup" },
	TidecallerStone = { Name = "🪨 Tidebell Stone", To = "Tidecaller", From = "Pinnipup", Price = 250,
		Desc = "Forces Pinnipup → Tidecaller" },
	-- Pebblor
	BouldurrStone = { Name = "🪨 Boulderheart Stone", To = "Bouldurr", From = "Pebblor", Price = 250,
		Desc = "Forces Pebblor → Bouldurr" },
	MagmiteStone = { Name = "🪨 Magmaheart Stone", To = "Magmite", From = "Pebblor", Price = 350,
		Desc = "Forces Pebblor → Magmite" },
	-- Hootlet
	NoctowlStone = { Name = "🪨 Nightgaze Stone", To = "Noctowl", From = "Hootlet", Price = 250,
		Desc = "Forces Hootlet → Noctowl" },
	StormowlStone = { Name = "🪨 Tempest Stone", To = "Stormowl", From = "Hootlet", Price = 350,
		Desc = "Forces Hootlet → Stormowl" },
	-- Sproutie
	ThornbackStone = { Name = "🪨 Thornmail Stone", To = "Thornback", From = "Sproutie", Price = 250,
		Desc = "Forces Sproutie → Thornback" },
	MosshornStone = { Name = "🪨 Mosshide Stone", To = "Mosshorn", From = "Sproutie", Price = 350,
		Desc = "Forces Sproutie → Mosshorn" },
	-- Cindert
	CragmiteStone = { Name = "🪨 Cragscale Stone", To = "Cragmite", From = "Cindert", Price = 350,
		Desc = "Forces Cindert → Cragmite" },
	InferniteStone = { Name = "🪨 Cinderheart Stone", To = "Infernite", From = "Cindert", Price = 350,
		Desc = "Forces Cindert → Infernite" },
	-- Gustling
	TempestraStone = { Name = "🪨 Galeheart Stone", To = "Tempestra", From = "Gustling", Price = 250,
		Desc = "Forces Gustling → Tempestra" },
	SkyshriekStone = { Name = "🪨 Nightshriek Stone", To = "Skyshriek", From = "Gustling", Price = 350,
		Desc = "Forces Gustling → Skyshriek" },
	-- Turtle
	ShellguardStone = { Name = "🪨 Shellwarden Stone", To = "Shellguard", From = "Turtle", Price = 350,
		Desc = "Forces Turtle → Shellguard" },
	TidalordStone = { Name = "🪨 Tidecrown Stone", To = "Tidalord", From = "Turtle", Price = 450,
		Desc = "Forces Turtle → Tidalord" },
	PrimordialTurtleStone = { Name = "🪨 Rainrelic Stone", To = "PrimordialTurtle", From = "Turtle", Price = 550,
		Desc = "Forces Turtle → Primordial Turtle (needs 🌧️ Rain)" },
	-- Fox
	EmberfoxStone = { Name = "🪨 Emberpelt Stone", To = "Emberfox", From = "Fox", Price = 350,
		Desc = "Forces Fox → Emberfox" },
	DuskfoxStone = { Name = "🪨 Duskpelt Stone", To = "Duskfox", From = "Fox", Price = 350,
		Desc = "Forces Fox → Duskfox" },
	LunarFoxStone = { Name = "🪨 Moonmark Stone", To = "LunarFox", From = "Fox", Price = 550,
		Desc = "Forces Fox → Lunar Fox (needs 🌙 night)" },
	-- Drakeling
	DrakewingStone = { Name = "🪨 Drakescale Stone", To = "Drakewing", From = "Drakeling", Price = 450,
		Desc = "Forces Drakeling → Drakewing" },
	CinderdrakeStone = { Name = "🪨 Ashscale Stone", To = "Cinderdrake", From = "Drakeling", Price = 450,
		Desc = "Forces Drakeling → Cinderdrake" },
	VoidDragonStone = { Name = "🪨 Voidshard Stone", To = "VoidDragon", From = "Drakeling", Price = 550,
		Desc = "Forces Drakeling → Void Dragon (needs ☄️ Meteor)" },
}

-- branch target petId -> stoneId (reverse lookup)
local stoneByBranch: { [string]: string } = {}
for sid, sdef in PetData.EVO_STONES do
	stoneByBranch[(sdef :: { [string]: any }).To] = sid
end
function PetData.StoneForBranch(toId: string): string?
	return stoneByBranch[toId]
end

-- Hatch weights for the single Pet Egg (stage-1 wild pets only)
local HATCH_W = { Common = 40, Uncommon = 12, Rare = 5 }

function PetData.RollPet(): string
	local pool: { { Id: string, W: number } } = {}
	local total = 0
	for id, def in P do
		if def.Stage == 1 and not def.Starter and not def.Fossil and not def.Sky and not def.Rot and not def.Twilight then -- v14/v16/v21/v23: fossils, sky pets, rot bugs & twilight exclusives never hatch from eggs
			local w: number = (HATCH_W :: { [string]: number })[def.Rarity] or 1
			total += w
			table.insert(pool, { Id = id, W = w })
		end
	end
	assert(#pool > 0, "No hatchable pets")
	local roll = math.random() * total
	for _, e in pool do
		roll -= e.W
		if roll <= 0 then return e.Id end
	end
	return pool[1].Id
end

function PetData.GetRarity(petId: string): string
	local d = P[petId]
	return d and d.Rarity or "Common"
end

-- Shiny roll: 1 in 4000, cosmetic only (no stat/value change).
-- mult: event multiplier (e.g. Rainbow doubles it).
function PetData.RollShiny(mult: number?): boolean
	return math.random() < (Config.ShinyChance :: number) * (mult or 1)
end

function PetData.GetType(petId: string): string
	local d = P[petId]
	return d and d.Type or "Normal"
end

-- v25: can this species be ridden into the sky? Winged pets and Flying-type
-- pets can fly (Hootlet the owl, the whole Zephyric line, Blightwing...).
-- Everything else is ground-only.
function PetData.IsFlying(petId: string): boolean
	local d = P[petId]
	return d ~= nil and (d.Ear == "wing" or d.Type == "Flying")
end

-- Battle stats: rarity base x stage mult x mutation mult x star mult x bond HP mult
local STAT_BASE = {
	Common = { 40, 32, 32, 32 },
	Uncommon = { 52, 42, 42, 42 },
	Rare = { 65, 55, 52, 55 },
	Epic = { 80, 70, 65, 65 },
	Legendary = { 95, 85, 80, 80 },
	Secret = { 115, 100, 95, 95 },
}
local STAGE_MULT = { [1] = 1.0, [2] = 1.25, [3] = 1.5 }

-- Bond (petting your follower) milestone HP multiplier. Kept tiny on purpose.
function PetData.BondHPMult(bond: number?): number
	local b = bond or 0
	local mult = 1
	for _, m in (Config.BondMilestones :: { { [string]: any } }) do
		if b >= (m.Count :: number) then mult = (m.Mult :: number) end
	end
	return mult
end

function PetData.GetBattleStats(petId: string, mutation: string?, stars: number?, bond: number?): { [string]: number }
	local def = P[petId]
	assert(def, "Unknown pet " .. tostring(petId))
	local base: { number } = (STAT_BASE :: { [string]: { number } })[def.Rarity] or STAT_BASE.Common
	local sm = STAGE_MULT[def.Stage] or 1
	local mm = 1
	if mutation then
		local mdef = (Config.Mutations :: { [string]: { [string]: number } })[mutation]
		if mdef then mm = mdef.StatMult end
	end
	local starm = math.pow(Config.StarStatMult, stars or 0)
	local bondm = PetData.BondHPMult(bond)
	local function v(i: number): number
		local x = base[i] * sm * mm * starm
		if i == 1 then x *= bondm end -- bond boosts HP only
		return math.floor(x)
	end
	return { HP = v(1), Atk = v(2), Def = v(3), Spd = v(4) }
end

-- Display name: nickname if the player set one, else the species name.
function PetData.PetName(rec: { [string]: any }): string
	local nick = rec.Nickname
	if type(nick) == "string" and nick ~= "" then return nick end
	local d = P[rec.PetId]
	return (d and d.Name) or "???"
end

-- Sell value: base x mutation value mult x star value mult
function PetData.GetValue(petId: string, mutation: string?, stars: number?): number
	local def = P[petId]
	local base = def and def.Value or 100
	local mm = 1
	if mutation then
		local mdef = (Config.Mutations :: { [string]: { [string]: number } })[mutation]
		if mdef then mm = mdef.ValueMult end
	end
	return math.floor(base * mm * math.pow(Config.StarValueMult, stars or 0))
end

-- Move set: basic move (own type, infinite) + strong move (coverage type, 5 PP)
function PetData.GetMoveSet(petId: string): { { [string]: any } }
	local def = P[petId]
	assert(def, "Unknown pet " .. tostring(petId))
	local t1 = def.Type
	local t2 = def.Move2 or t1
	local n1 = (TypeChart.MOVES :: { [string]: { string } })[t1]
	local n2 = (TypeChart.MOVES :: { [string]: { string } })[t2]
	return {
		{ Name = n1[1], Type = t1, Power = 40, MaxPP = -1 }, -- -1 = infinite
		{ Name = n2[2], Type = t2, Power = 75, MaxPP = Config.Move2PP },
	}
end

-- ============ models ============
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

-- Egg model for the single Pet Egg. Returns Model.
function PetData.BuildEggModel(cracking: boolean): Model
	local m = Instance.new("Model")
	m.Name = "EggModel"
	local col = C(140, 220, 120)
	part(m, "Nest", Vector3.new(3.2, 0.6, 3.2), CFrame.new(0, 0.3, 0), C(120, 85, 55), Enum.PartType.Cylinder).Orientation = Vector3.new(0, 0, 90)
	local e = part(m, "Egg", Vector3.new(1.8, 2.4, 1.8), CFrame.new(0, 1.7, 0), col, Enum.PartType.Block)
	if cracking then
		for i = 1, 3 do
			local a = math.rad(i * 120)
			part(m, "Crack", Vector3.new(0.12, 1.4, 0.12),
				CFrame.new(math.cos(a) * 0.8, 1.7, math.sin(a) * 0.8) * CFrame.Angles(0.3, 0, 0.2),
				C(255, 255, 255))
		end
		e.Orientation = Vector3.new(0, 0, 12)
	end
	local pp = Instance.new("Part")
	pp.Name = "Primary"
	pp.Size = Vector3.new(2, 2.4, 2)
	pp.Transparency = 1
	pp.Anchored = true
	pp.CanCollide = false
	pp.CFrame = CFrame.new(0, 1.5, 0)
	pp.Parent = m
	m.PrimaryPart = pp
	return m
end

-- Custom skins: cosmetic tint + one particle accent per skin. Applied after
-- mutation/shiny visuals so the skin wins on tint. Purely cosmetic.
local SKIN_TINTS: { [string]: { Color3 } } = {
	Shadow = { C(48, 34, 74), C(150, 90, 255) }, -- dark purple tint, violet wisps
	Golden = { C(255, 200, 60), C(255, 225, 120) }, -- gold tint, gold sparkles
	Frost = { C(170, 220, 255), C(220, 240, 255) }, -- ice-blue tint, snow sparkles
}

function PetData.ApplySkin(m: Model, skin: string?)
	local cols = skin and SKIN_TINTS[skin] or nil
	if not cols then return end
	local tint, pcol = cols[1], cols[2]
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Primary" and d.Name ~= "TypeGem" then
			d.Color = tint
		end
	end
	local body = m:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		local sp = Instance.new("Sparkles")
		sp.Name = "SkinSparkles"
		sp.SparkleColor = pcol
		sp.Parent = body
	end
end

-- Claude custom designs (2026-10-04): data-driven part lists from Claude's
-- redesign batches. Entry: { shape, size{x,y,z}, pos{x,y,z}, color, rot?, mat?, trans?, name? }
-- color: "body" | "light" | "dark" | Color3. Front is +Z, ground is y=0.
-- Sizes/positions are authored per pet; BuildPetModel scales by s as usual.
local PetDesigns: { [string]: { any } } = {}
local function pd_(shape: string, sx: number, sy: number, sz: number, x: number, y: number, z: number,
	col: any, rot: { number }?, mat: string?, trans: number?, name: string?)
	return { shape, { sx, sy, sz }, { x, y, z }, col, rot, mat, trans, name }
end
local function buildDesign(m: Model, design: { any }, s: number, body: Color3, light: Color3, dark: Color3)
	for _, e in design do
		local shape: string = e[1]
		local sz: { number } = e[2]
		local ps: { number } = e[3]
		local cf = CFrame.new(Vector3.new(ps[1], ps[2], ps[3]) * s)
		if e[5] then
			cf *= CFrame.Angles(math.rad(e[5][1]), math.rad(e[5][2]), math.rad(e[5][3]))
		end
		local col: Color3 = body
		if type(e[4]) == "string" then
			col = if e[4] == "light" then light elseif e[4] == "dark" then dark else body
		elseif typeof(e[4]) == "Color3" then
			col = e[4]
		end
		local p: BasePart
		if shape == "Wedge" then
			local w = Instance.new("WedgePart")
			w.Size = Vector3.new(sz[1], sz[2], sz[3]) * s
			w.CFrame = cf
			p = w
		else
			local bp = Instance.new("Part")
			bp.Size = Vector3.new(sz[1], sz[2], sz[3]) * s
			bp.CFrame = cf
			bp.Shape = if shape == "Cylinder" then Enum.PartType.Cylinder else Enum.PartType.Ball
			p = bp
		end
		p.Name = e[8] or "Part"
		p.Color = col
		p.Material = if e[6] == "Neon" then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.Transparency = e[7] or 0
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Parent = m
	end
end

PetDesigns.Mossbun = {
	pd_("Ball", 2.0, 1.8, 2.2, 0, 1.0, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.5, 1.5, 1.5, 0, 2.1, 0.5, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.5, 1.5, 0.4, -0.4, 3.2, 0.3, "body", { -15, 0, 0 }),
	pd_("Ball", 0.5, 1.5, 0.4, 0.4, 3.2, 0.3, "body", { -15, 0, 0 }),
	pd_("Ball", 0.3, 1.0, 0.15, -0.4, 3.2, 0.52, C(244, 169, 184)),
	pd_("Ball", 0.3, 1.0, 0.15, 0.4, 3.2, 0.52, C(244, 169, 184)),
	pd_("Ball", 0.28, 0.28, 0.28, -0.35, 2.2, 1.15, C(43, 43, 43)),
	pd_("Ball", 0.28, 0.28, 0.28, 0.35, 2.2, 1.15, C(43, 43, 43)),
	pd_("Ball", 0.22, 0.22, 0.22, 0, 2.0, 1.2, C(244, 169, 184)),
	pd_("Ball", 0.55, 0.55, 0.55, -0.5, 0.3, 0.9, "body"),
	pd_("Ball", 0.55, 0.55, 0.55, 0.5, 0.3, 0.9, "body"),
	pd_("Ball", 0.7, 0.5, 1.0, -0.6, 0.25, -0.3, "body"),
	pd_("Ball", 0.7, 0.5, 1.0, 0.6, 0.25, -0.3, "body"),
	pd_("Ball", 0.6, 0.6, 0.6, 0, 1.1, -1.15, "light"),
	pd_("Ball", 1.4, 0.7, 1.4, 0, 1.95, -0.2, C(127, 176, 90)),
}
PetDesigns.Clovelop = {
	pd_("Ball", 2.1, 1.9, 2.3, 0, 1.05, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.6, 1.6, 1.6, 0, 2.25, 0.5, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.5, 1.95, 0.4, -0.42, 3.5, 0.28, "body", { -15, 0, 0 }),
	pd_("Ball", 0.5, 1.95, 0.4, 0.42, 3.5, 0.28, "body", { -15, 0, 0 }),
	pd_("Ball", 0.5, 0.15, 0.5, -0.5, 4.45, 0.05, C(127, 176, 90)),
	pd_("Ball", 0.5, 0.15, 0.5, 0.5, 4.45, 0.05, C(127, 176, 90)),
	pd_("Ball", 0.3, 1.3, 0.15, -0.42, 3.5, 0.5, C(244, 169, 184)),
	pd_("Ball", 0.3, 1.3, 0.15, 0.42, 3.5, 0.5, C(244, 169, 184)),
	pd_("Ball", 0.28, 0.28, 0.28, -0.37, 2.35, 1.22, C(43, 43, 43)),
	pd_("Ball", 0.28, 0.28, 0.28, 0.37, 2.35, 1.22, C(43, 43, 43)),
	pd_("Ball", 0.22, 0.22, 0.22, 0, 2.15, 1.28, C(244, 169, 184)),
	pd_("Ball", 0.55, 0.55, 0.55, -0.52, 0.3, 0.95, "body"),
	pd_("Ball", 0.55, 0.55, 0.55, 0.52, 0.3, 0.95, "body"),
	pd_("Ball", 0.7, 0.5, 1.0, -0.62, 0.25, -0.3, "body"),
	pd_("Ball", 0.7, 0.5, 1.0, 0.62, 0.25, -0.3, "body"),
	pd_("Ball", 0.65, 0.65, 0.65, 0, 1.15, -1.2, "light"),
	pd_("Ball", 1.7, 0.85, 1.7, 0, 2.05, -0.2, C(127, 176, 90)),
	pd_("Ball", 0.35, 0.35, 0.35, -0.5, 2.5, 0.1, "light"),
	pd_("Ball", 0.35, 0.35, 0.35, 0.3, 2.55, -0.5, "light"),
	pd_("Ball", 0.35, 0.35, 0.35, 0.55, 2.45, 0.35, "light"),
}
PetDesigns.Meadowhare = {
	pd_("Ball", 2.3, 2.0, 2.5, 0, 1.3, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.7, 1.7, 1.7, 0, 2.9, 0.55, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.6, 2.4, 0.5, -0.45, 4.4, 0.3, "body", { -12, 0, 0 }),
	pd_("Ball", 0.6, 2.4, 0.5, 0.45, 4.4, 0.3, "body", { -12, 0, 0 }),
	pd_("Ball", 0.35, 1.6, 0.15, -0.45, 4.4, 0.55, C(244, 169, 184)),
	pd_("Ball", 0.35, 1.6, 0.15, 0.45, 4.4, 0.55, C(244, 169, 184)),
	pd_("Ball", 0.3, 0.3, 0.3, -0.4, 3.0, 1.3, C(43, 43, 43)),
	pd_("Ball", 0.3, 0.3, 0.3, 0.4, 3.0, 1.3, C(43, 43, 43)),
	pd_("Ball", 0.24, 0.24, 0.24, 0, 2.8, 1.38, C(244, 169, 184)),
	pd_("Ball", 0.4, 0.4, 0.4, -0.8, 3.9, 0.6, C(244, 169, 184)),
	pd_("Ball", 0.4, 0.4, 0.4, -0.45, 4.15, 0.75, "light"),
	pd_("Ball", 0.4, 0.4, 0.4, 0, 4.25, 0.8, C(255, 213, 79)),
	pd_("Ball", 0.4, 0.4, 0.4, 0.45, 4.15, 0.75, C(244, 169, 184)),
	pd_("Ball", 0.4, 0.4, 0.4, 0.8, 3.9, 0.6, "light"),
	pd_("Ball", 0.4, 0.4, 0.4, 0, 3.8, 0.55, C(255, 213, 79)),
	pd_("Cylinder", 1.6, 0.6, 0.6, -0.7, 0.8, -0.5, "dark", { 0, 0, 90 }),
	pd_("Cylinder", 1.6, 0.6, 0.6, 0.7, 0.8, -0.5, "dark", { 0, 0, 90 }),
	pd_("Ball", 0.8, 0.55, 1.2, -0.7, 0.28, 0.6, "body"),
	pd_("Ball", 0.8, 0.55, 1.2, 0.7, 0.28, 0.6, "body"),
	pd_("Ball", 0.7, 0.7, 0.7, 0, 1.5, -1.35, "light"),
	pd_("Ball", 3.0, 0.8, 3.0, 0, 2.35, -0.2, C(127, 176, 90)),
	pd_("Ball", 0.4, 0.4, 0.4, -0.8, 2.8, 0.3, C(244, 169, 184)),
	pd_("Ball", 0.4, 0.4, 0.4, 0.6, 2.85, -0.6, "light"),
	pd_("Ball", 0.4, 0.4, 0.4, 0, 2.9, 0.6, C(255, 213, 79)),
	pd_("Ball", 0.4, 0.4, 0.4, -0.3, 2.8, -0.9, C(244, 169, 184)),
	pd_("Ball", 0.4, 0.4, 0.4, 0.9, 2.75, 0.5, "light"),
}
PetDesigns.Leafling = {
	pd_("Ball", 1.5, 1.5, 1.5, 0, 0.8, 0.9, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.4, 1.4, 1.4, 0, 0.85, -0.1, "body"),
	pd_("Ball", 1.2, 1.2, 1.2, 0, 0.8, -1.0, "body"),
	pd_("Ball", 1.0, 1.0, 1.0, 0, 0.75, -1.8, "body"),
	pd_("Ball", 1.7, 1.7, 1.7, 0, 1.1, 1.9, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.4, 0.4, 0.4, -0.4, 1.25, 2.6, C(43, 43, 43)),
	pd_("Ball", 0.4, 0.4, 0.4, 0.4, 1.25, 2.6, C(43, 43, 43)),
	pd_("Cylinder", 0.9, 0.12, 0.12, -0.35, 2.2, 1.8, "dark", { 0, 0, 25 }),
	pd_("Cylinder", 0.9, 0.12, 0.12, 0.35, 2.2, 1.8, "dark", { 0, 0, -25 }),
	pd_("Ball", 0.25, 0.25, 0.25, -0.55, 2.6, 1.8, C(95, 168, 68)),
	pd_("Ball", 0.25, 0.25, 0.25, 0.55, 2.6, 1.8, C(95, 168, 68)),
	pd_("Wedge", 1.2, 0.15, 1.4, 0, 2.05, 1.75, C(95, 168, 68), { -15, 0, 0 }),
	pd_("Ball", 0.35, 0.35, 0.35, -0.5, 0.18, 0.9, C(246, 240, 200)),
	pd_("Ball", 0.35, 0.35, 0.35, 0.5, 0.18, 0.9, C(246, 240, 200)),
	pd_("Ball", 0.35, 0.35, 0.35, -0.45, 0.18, -0.6, C(246, 240, 200)),
	pd_("Ball", 0.35, 0.35, 0.35, 0.45, 0.18, -0.6, C(246, 240, 200)),
}
PetDesigns.Budwing = {
	pd_("Ball", 2.2, 3.0, 2.2, 0, 1.6, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 2.35, 0.28, 2.35, 0, 1.1, 0, C(246, 240, 200)),
	pd_("Ball", 2.35, 0.28, 2.35, 0, 1.75, 0, C(246, 240, 200)),
	pd_("Ball", 2.3, 0.28, 2.3, 0, 2.4, 0, C(246, 240, 200)),
	pd_("Ball", 1.5, 1.5, 1.5, 0, 3.3, 0.15, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.35, 0.35, 0.35, -0.35, 3.45, 0.8, C(43, 43, 43)),
	pd_("Ball", 0.35, 0.35, 0.35, 0.35, 3.45, 0.8, C(43, 43, 43)),
	pd_("Wedge", 1.0, 1.4, 0.12, -1.15, 2.2, -0.2, C(242, 156, 184), { 0, 0, 20 }),
	pd_("Wedge", 1.0, 1.4, 0.12, 1.15, 2.2, -0.2, C(242, 156, 184), { 0, 0, -20 }),
	pd_("Ball", 0.5, 0.4, 0.8, -0.5, 0.2, 0.5, C(246, 240, 200)),
	pd_("Ball", 0.5, 0.4, 0.8, 0.5, 0.2, 0.5, C(246, 240, 200)),
}
PetDesigns.Blossomwing = {
	pd_("Ball", 1.0, 2.4, 1.0, 0, 1.5, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.2, 1.2, 1.2, 0, 2.95, 0.15, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.3, 0.3, 0.3, -0.3, 3.1, 0.65, C(43, 43, 43)),
	pd_("Ball", 0.3, 0.3, 0.3, 0.3, 3.1, 0.65, C(43, 43, 43)),
	pd_("Cylinder", 0.8, 0.1, 0.1, -0.25, 3.8, 0.1, "dark", { 0, 0, 35 }),
	pd_("Cylinder", 0.8, 0.1, 0.1, 0.25, 3.8, 0.1, "dark", { 0, 0, -35 }),
	pd_("Ball", 0.22, 0.22, 0.22, -0.45, 4.15, 0.1, C(242, 156, 184)),
	pd_("Ball", 0.22, 0.22, 0.22, 0.45, 4.15, 0.1, C(242, 156, 184)),
	pd_("Wedge", 3.6, 0.15, 2.6, -1.9, 2.6, -0.3, C(242, 156, 184), { 0, 25, 0 }),
	pd_("Wedge", 3.6, 0.15, 2.6, 1.9, 2.6, -0.3, C(242, 156, 184), { 0, -25, 0 }),
	pd_("Ball", 1.2, 0.12, 1.2, -2.2, 2.65, -0.5, C(246, 240, 200)),
	pd_("Ball", 1.2, 0.12, 1.2, 2.2, 2.65, -0.5, C(246, 240, 200)),
	pd_("Wedge", 2.4, 0.15, 1.8, -1.4, 1.9, -0.5, C(242, 156, 184), { 0, 25, 0 }),
	pd_("Wedge", 2.4, 0.15, 1.8, 1.4, 1.9, -0.5, C(242, 156, 184), { 0, -25, 0 }),
	pd_("Ball", 0.2, 0.5, 0.2, -0.3, 0.25, 0.25, "dark"),
	pd_("Ball", 0.2, 0.5, 0.2, 0.3, 0.25, 0.25, "dark"),
	pd_("Ball", 0.2, 0.5, 0.2, -0.3, 0.25, -0.25, "dark"),
	pd_("Ball", 0.2, 0.5, 0.2, 0.3, 0.25, -0.25, "dark"),
}

PetDesigns.Cinderkit = {
	pd_("Ball", 1.8, 1.6, 2.2, 0, 1.0, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.6, 1.4, 1.5, 0, 2.05, 0.55, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.8, 0.6, 0.9, 0, 1.85, 1.15, C(255, 241, 214)),
	pd_("Ball", 0.22, 0.22, 0.22, 0, 2.0, 1.55, C(40, 35, 35)),
	pd_("Ball", 0.3, 0.3, 0.3, -0.38, 2.2, 1.2, C(43, 43, 43)),
	pd_("Ball", 0.3, 0.3, 0.3, 0.38, 2.2, 1.2, C(43, 43, 43)),
	pd_("Wedge", 0.7, 1.0, 0.3, -0.5, 2.95, 0.35, "body", { -10, 0, 8 }),
	pd_("Wedge", 0.7, 1.0, 0.3, 0.5, 2.95, 0.35, "body", { -10, 0, -8 }),
	pd_("Ball", 1.0, 0.8, 0.8, 0, 1.35, 0.95, C(255, 241, 214)),
	pd_("Ball", 0.6, 0.6, 0.6, -0.55, 0.3, 0.75, C(74, 59, 54)),
	pd_("Ball", 0.6, 0.6, 0.6, 0.55, 0.3, 0.75, C(74, 59, 54)),
	pd_("Ball", 0.6, 0.6, 0.6, -0.55, 0.3, -0.75, C(74, 59, 54)),
	pd_("Ball", 0.6, 0.6, 0.6, 0.55, 0.3, -0.75, C(74, 59, 54)),
	pd_("Ball", 1.0, 1.0, 1.0, 0, 1.2, -1.35, "body"),
	pd_("Ball", 0.9, 0.9, 0.9, 0, 1.6, -1.7, "body"),
	pd_("Ball", 0.7, 0.7, 0.7, 0, 1.95, -1.95, "body"),
	pd_("Ball", 0.5, 0.5, 0.5, 0, 2.25, -2.1, C(255, 193, 69)),
	pd_("Wedge", 0.6, 0.9, 0.2, 0, 2.6, -2.15, C(255, 193, 69), { -20, 0, 0 }),
	pd_("Wedge", 0.5, 0.7, 0.2, 0.25, 2.45, -2.2, C(255, 193, 69), { -20, 0, 25 }),
}
PetDesigns.Flarefox = {
	pd_("Ball", 1.9, 1.7, 2.3, 0, 1.05, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.7, 1.5, 1.6, 0, 2.2, 0.55, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.85, 0.65, 0.95, 0, 2.0, 1.2, C(255, 241, 214)),
	pd_("Ball", 0.24, 0.24, 0.24, 0, 2.15, 1.62, C(40, 35, 35)),
	pd_("Ball", 0.32, 0.32, 0.32, -0.4, 2.35, 1.28, C(43, 43, 43)),
	pd_("Ball", 0.32, 0.32, 0.32, 0.4, 2.35, 1.28, C(43, 43, 43)),
	pd_("Wedge", 0.75, 1.1, 0.3, -0.55, 3.15, 0.35, "body", { -10, 0, 8 }),
	pd_("Wedge", 0.75, 1.1, 0.3, 0.55, 3.15, 0.35, "body", { -10, 0, -8 }),
	pd_("Wedge", 0.5, 1.1, 0.2, 0, 3.2, 0.5, C(255, 193, 69)),
	pd_("Wedge", 0.5, 1.1, 0.2, -0.3, 3.15, 0.45, C(255, 193, 69), { 0, 0, 15 }),
	pd_("Wedge", 0.5, 1.1, 0.2, 0.3, 3.15, 0.45, C(255, 193, 69), { 0, 0, -15 }),
	pd_("Ball", 1.05, 0.85, 0.85, 0, 1.45, 1.0, C(255, 241, 214)),
	pd_("Cylinder", 0.8, 0.5, 0.5, -0.6, 0.45, 0.8, C(74, 59, 54), { 0, 0, 90 }),
	pd_("Cylinder", 0.8, 0.5, 0.5, 0.6, 0.45, 0.8, C(74, 59, 54), { 0, 0, 90 }),
	pd_("Cylinder", 0.8, 0.5, 0.5, -0.6, 0.45, -0.8, C(74, 59, 54), { 0, 0, 90 }),
	pd_("Cylinder", 0.8, 0.5, 0.5, 0.6, 0.45, -0.8, C(74, 59, 54), { 0, 0, 90 }),
	pd_("Ball", 1.0, 1.0, 1.0, -0.35, 1.25, -1.4, "body"),
	pd_("Ball", 0.9, 0.9, 0.9, -0.45, 1.7, -1.75, "body"),
	pd_("Ball", 0.65, 0.65, 0.65, -0.5, 2.1, -1.95, C(255, 193, 69)),
	pd_("Ball", 1.0, 1.0, 1.0, 0.35, 1.25, -1.4, "body"),
	pd_("Ball", 0.9, 0.9, 0.9, 0.45, 1.7, -1.75, "body"),
	pd_("Ball", 0.65, 0.65, 0.65, 0.5, 2.1, -1.95, C(255, 193, 69)),
}
PetDesigns.Solarfox = {
	pd_("Ball", 2.1, 1.8, 2.5, 0, 1.2, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.8, 1.6, 1.7, 0, 2.5, 0.6, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.9, 0.7, 1.0, 0, 2.3, 1.3, C(255, 241, 214)),
	pd_("Ball", 0.25, 0.25, 0.25, 0, 2.45, 1.75, C(40, 35, 35)),
	pd_("Ball", 0.34, 0.34, 0.34, -0.42, 2.65, 1.38, C(43, 43, 43)),
	pd_("Ball", 0.34, 0.34, 0.34, 0.42, 2.65, 1.38, C(43, 43, 43)),
	pd_("Wedge", 0.8, 1.2, 0.3, -0.6, 3.5, 0.4, "body", { -10, 0, 8 }),
	pd_("Wedge", 0.8, 1.2, 0.3, 0.6, 3.5, 0.4, "body", { -10, 0, -8 }),
	pd_("Cylinder", 0.15, 0.8, 0.8, 0, 3.35, 0.85, C(255, 193, 69), { 90, 0, 0 }, "Neon"),
	pd_("Ball", 1.15, 0.9, 0.9, 0, 1.65, 1.05, C(255, 241, 214)),
	pd_("Ball", 0.7, 0.7, 0.7, -0.65, 0.35, 0.85, C(74, 59, 54)),
	pd_("Ball", 0.7, 0.7, 0.7, 0.65, 0.35, 0.85, C(74, 59, 54)),
	pd_("Ball", 0.7, 0.7, 0.7, -0.65, 0.35, -0.85, C(74, 59, 54)),
	pd_("Ball", 0.7, 0.7, 0.7, 0.65, 0.35, -0.85, C(74, 59, 54)),
	pd_("Wedge", 1.0, 1.6, 0.2, 0, 3.3, -0.6, C(255, 193, 69), { -25, 0, 0 }),
	pd_("Wedge", 0.9, 1.4, 0.2, -0.55, 3.15, -0.65, C(255, 150, 60), { -25, 0, 20 }),
	pd_("Wedge", 0.9, 1.4, 0.2, 0.55, 3.15, -0.65, C(255, 150, 60), { -25, 0, -20 }),
	pd_("Wedge", 0.8, 1.2, 0.2, -1.0, 2.95, -0.6, C(242, 118, 46), { -20, 0, 35 }),
	pd_("Wedge", 0.8, 1.2, 0.2, 1.0, 2.95, -0.6, C(242, 118, 46), { -20, 0, -35 }),
	pd_("Ball", 1.05, 1.05, 1.05, -0.6, 1.4, -1.5, "body"),
	pd_("Ball", 0.95, 0.95, 0.95, -0.75, 1.9, -1.85, "body"),
	pd_("Ball", 0.7, 0.7, 0.7, -0.85, 2.35, -2.05, C(255, 193, 69)),
	pd_("Ball", 1.05, 1.05, 1.05, 0, 1.45, -1.6, "body"),
	pd_("Ball", 0.95, 0.95, 0.95, 0, 2.0, -2.0, "body"),
	pd_("Ball", 0.7, 0.7, 0.7, 0, 2.5, -2.25, C(255, 193, 69)),
	pd_("Ball", 1.05, 1.05, 1.05, 0.6, 1.4, -1.5, "body"),
	pd_("Ball", 0.95, 0.95, 0.95, 0.75, 1.9, -1.85, "body"),
	pd_("Ball", 0.7, 0.7, 0.7, 0.85, 2.35, -2.05, C(255, 193, 69)),
}
PetDesigns.Emberchick = {
	pd_("Ball", 1.9, 1.9, 1.9, 0, 1.15, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.3, 1.0, 0.6, 0, 0.95, 0.75, C(255, 232, 176)),
	pd_("Ball", 1.4, 1.4, 1.4, 0, 2.35, 0.35, "body", nil, nil, nil, "Head"),
	pd_("Wedge", 0.5, 0.35, 0.6, 0, 2.25, 1.15, C(255, 210, 90), { 90, 0, 0 }),
	pd_("Ball", 0.3, 0.3, 0.3, -0.36, 2.5, 0.95, C(43, 43, 43)),
	pd_("Ball", 0.3, 0.3, 0.3, 0.36, 2.5, 0.95, C(43, 43, 43)),
	pd_("Wedge", 0.3, 0.8, 0.15, 0, 3.25, 0.3, C(255, 210, 90)),
	pd_("Wedge", 0.3, 0.7, 0.15, -0.25, 3.15, 0.28, C(245, 154, 47), { 0, 0, 15 }),
	pd_("Wedge", 0.3, 0.7, 0.15, 0.25, 3.15, 0.28, C(245, 154, 47), { 0, 0, -15 }),
	pd_("Wedge", 0.9, 0.2, 1.1, -0.95, 1.5, -0.1, C(245, 154, 47), { 0, 0, 15 }),
	pd_("Wedge", 0.9, 0.2, 1.1, 0.95, 1.5, -0.1, C(245, 154, 47), { 0, 0, -15 }),
	pd_("Wedge", 0.5, 1.2, 0.15, 0, 1.5, -1.05, C(245, 154, 47), { -30, 0, 0 }),
	pd_("Wedge", 0.5, 1.1, 0.15, -0.3, 1.45, -1.05, C(255, 210, 90), { -30, 0, 12 }),
	pd_("Wedge", 0.5, 1.1, 0.15, 0.3, 1.45, -1.05, C(255, 210, 90), { -30, 0, -12 }),
	pd_("Ball", 0.5, 0.2, 0.7, -0.35, 0.12, 0.35, C(255, 210, 90)),
	pd_("Ball", 0.5, 0.2, 0.7, 0.35, 0.12, 0.35, C(255, 210, 90)),
}
PetDesigns.Blazewing = {
	pd_("Ball", 2.0, 2.0, 2.0, 0, 1.35, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.4, 1.1, 0.6, 0, 1.15, 0.8, C(255, 232, 176)),
	pd_("Ball", 1.5, 1.5, 1.5, 0, 2.75, 0.4, "body", nil, nil, nil, "Head"),
	pd_("Wedge", 0.55, 0.4, 0.65, 0, 2.65, 1.25, C(255, 210, 90), { 90, 0, 0 }),
	pd_("Ball", 0.32, 0.32, 0.32, -0.38, 2.9, 1.05, C(43, 43, 43)),
	pd_("Ball", 0.32, 0.32, 0.32, 0.38, 2.9, 1.05, C(43, 43, 43)),
	pd_("Wedge", 0.3, 0.9, 0.15, 0, 3.7, 0.35, C(255, 210, 90)),
	pd_("Wedge", 0.3, 0.8, 0.15, -0.28, 3.6, 0.33, C(245, 154, 47), { 0, 0, 15 }),
	pd_("Wedge", 0.3, 0.8, 0.15, 0.28, 3.6, 0.33, C(245, 154, 47), { 0, 0, -15 }),
	pd_("Wedge", 0.3, 0.75, 0.15, -0.52, 3.5, 0.3, C(232, 69, 44), { 0, 0, 28 }),
	pd_("Wedge", 0.3, 0.75, 0.15, 0.52, 3.5, 0.3, C(232, 69, 44), { 0, 0, -28 }),
	pd_("Wedge", 2.0, 0.2, 1.8, -1.35, 2.0, -0.2, C(245, 154, 47), { 0, 15, 12 }),
	pd_("Wedge", 2.0, 0.2, 1.8, 1.35, 2.0, -0.2, C(245, 154, 47), { 0, -15, -12 }),
	pd_("Wedge", 0.7, 0.18, 0.8, -2.2, 2.15, -0.5, C(255, 210, 90), { 0, 15, 12 }),
	pd_("Wedge", 0.7, 0.18, 0.8, 2.2, 2.15, -0.5, C(255, 210, 90), { 0, -15, -12 }),
	pd_("Cylinder", 1.0, 0.25, 0.25, -0.35, 0.5, 0.3, C(245, 154, 47), { 0, 0, 90 }),
	pd_("Cylinder", 1.0, 0.25, 0.25, 0.35, 0.5, 0.3, C(245, 154, 47), { 0, 0, 90 }),
	pd_("Ball", 0.5, 0.2, 0.75, -0.35, 0.12, 0.4, C(255, 210, 90)),
	pd_("Ball", 0.5, 0.2, 0.75, 0.35, 0.12, 0.4, C(255, 210, 90)),
	pd_("Wedge", 0.5, 1.5, 0.15, 0, 1.6, -1.3, C(245, 154, 47), { -35, 0, 0 }),
	pd_("Wedge", 0.5, 1.4, 0.15, -0.35, 1.55, -1.3, C(255, 210, 90), { -35, 0, 14 }),
	pd_("Wedge", 0.5, 1.4, 0.15, 0.35, 1.55, -1.3, C(255, 210, 90), { -35, 0, -14 }),
	pd_("Wedge", 0.45, 1.3, 0.15, -0.68, 1.5, -1.28, C(232, 69, 44), { -35, 0, 26 }),
	pd_("Wedge", 0.45, 1.3, 0.15, 0.68, 1.5, -1.28, C(232, 69, 44), { -35, 0, -26 }),
}
PetDesigns.Sunphoenix = {
	pd_("Ball", 2.2, 2.2, 2.2, 0, 1.6, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.5, 1.2, 0.7, 0, 1.4, 0.9, C(255, 232, 176)),
	pd_("Ball", 1.6, 1.6, 1.6, 0, 3.2, 0.45, "body", nil, nil, nil, "Head"),
	pd_("Wedge", 0.6, 0.45, 0.7, 0, 3.1, 1.4, C(255, 210, 90), { 90, 0, 0 }),
	pd_("Ball", 0.34, 0.34, 0.34, -0.4, 3.35, 1.15, C(43, 43, 43)),
	pd_("Ball", 0.34, 0.34, 0.34, 0.4, 3.35, 1.15, C(43, 43, 43)),
	pd_("Wedge", 0.35, 1.2, 0.15, 0, 4.3, 0.4, C(255, 210, 90), nil, "Neon"),
	pd_("Wedge", 0.35, 1.05, 0.15, -0.3, 4.2, 0.38, C(245, 154, 47), { 0, 0, 14 }),
	pd_("Wedge", 0.35, 1.05, 0.15, 0.3, 4.2, 0.38, C(245, 154, 47), { 0, 0, -14 }),
	pd_("Wedge", 0.32, 0.95, 0.15, -0.58, 4.05, 0.35, C(232, 69, 44), { 0, 0, 28 }),
	pd_("Wedge", 0.32, 0.95, 0.15, 0.58, 4.05, 0.35, C(232, 69, 44), { 0, 0, -28 }),
	pd_("Wedge", 3.0, 0.22, 2.0, -1.8, 2.7, -0.3, C(245, 154, 47), { 0, 15, 18 }),
	pd_("Wedge", 3.0, 0.22, 2.0, 1.8, 2.7, -0.3, C(245, 154, 47), { 0, -15, -18 }),
	pd_("Wedge", 2.4, 0.2, 1.7, -1.65, 2.4, -0.45, C(255, 210, 90), { 0, 15, 14 }),
	pd_("Wedge", 2.4, 0.2, 1.7, 1.65, 2.4, -0.45, C(255, 210, 90), { 0, -15, -14 }),
	pd_("Wedge", 1.8, 0.2, 1.4, -1.45, 2.1, -0.6, C(232, 69, 44), { 0, 15, 10 }),
	pd_("Wedge", 1.8, 0.2, 1.4, 1.45, 2.1, -0.6, C(232, 69, 44), { 0, -15, -10 }),
	pd_("Cylinder", 1.3, 0.28, 0.28, -0.4, 0.65, 0.35, C(245, 154, 47), { 0, 0, 90 }),
	pd_("Cylinder", 1.3, 0.28, 0.28, 0.4, 0.65, 0.35, C(245, 154, 47), { 0, 0, 90 }),
	pd_("Ball", 0.55, 0.22, 0.8, -0.4, 0.12, 0.5, C(255, 210, 90)),
	pd_("Ball", 0.55, 0.22, 0.8, 0.4, 0.12, 0.5, C(255, 210, 90)),
	pd_("Wedge", 0.55, 2.0, 0.15, 0, 1.8, -1.6, C(255, 210, 90), { -40, 0, 0 }, "Neon"),
	pd_("Wedge", 0.55, 1.9, 0.15, -0.4, 1.75, -1.6, C(245, 154, 47), { -40, 0, 12 }),
	pd_("Wedge", 0.55, 1.9, 0.15, 0.4, 1.75, -1.6, C(245, 154, 47), { -40, 0, -12 }),
	pd_("Wedge", 0.5, 1.8, 0.15, -0.78, 1.7, -1.58, C(232, 69, 44), { -40, 0, 24 }),
	pd_("Wedge", 0.5, 1.8, 0.15, 0.78, 1.7, -1.58, C(232, 69, 44), { -40, 0, -24 }),
	pd_("Wedge", 0.5, 1.7, 0.15, -1.12, 1.65, -1.55, C(245, 154, 47), { -40, 0, 36 }),
	pd_("Wedge", 0.5, 1.7, 0.15, 1.12, 1.65, -1.55, C(245, 154, 47), { -40, 0, -36 }),
	pd_("Ball", 0.3, 0.3, 0.3, -1.05, 4.35, 0.3, C(255, 210, 90), nil, "Neon"),
	pd_("Ball", 0.3, 0.3, 0.3, -0.55, 4.6, 0.3, C(255, 210, 90), nil, "Neon"),
	pd_("Ball", 0.3, 0.3, 0.3, 0, 4.7, 0.3, C(255, 210, 90), nil, "Neon"),
	pd_("Ball", 0.3, 0.3, 0.3, 0.55, 4.6, 0.3, C(255, 210, 90), nil, "Neon"),
	pd_("Ball", 0.3, 0.3, 0.3, 1.05, 4.35, 0.3, C(255, 210, 90), nil, "Neon"),
	pd_("Ball", 0.3, 0.3, 0.3, -1.3, 4.05, 0.3, C(255, 210, 90), nil, "Neon"),
	pd_("Ball", 0.3, 0.3, 0.3, 1.3, 4.05, 0.3, C(255, 210, 90), nil, "Neon"),
	pd_("Ball", 0.3, 0.3, 0.3, 0, 4.75, 0.3, C(255, 210, 90), nil, "Neon"),
}

PetDesigns.Ripplet = {
	pd_("Ball", 1.5, 1.3, 2.6, 0, 0.85, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.1, 0.9, 2.0, 0, 0.75, 0.35, C(207, 232, 247)),
	pd_("Ball", 1.5, 1.3, 1.5, 0, 1.35, 1.45, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.8, 0.6, 0.8, 0, 1.15, 2.05, "light"),
	pd_("Ball", 0.25, 0.25, 0.25, 0, 1.3, 2.4, C(47, 95, 143)),
	pd_("Ball", 0.3, 0.3, 0.3, -0.36, 1.5, 2.05, C(43, 43, 43)),
	pd_("Ball", 0.3, 0.3, 0.3, 0.36, 1.5, 2.05, C(43, 43, 43)),
	pd_("Ball", 0.4, 0.4, 0.4, -0.55, 1.95, 1.35, "body"),
	pd_("Ball", 0.4, 0.4, 0.4, 0.55, 1.95, 1.35, "body"),
	pd_("Ball", 0.5, 0.5, 0.5, -0.6, 0.45, 1.0, "body"),
	pd_("Ball", 0.5, 0.5, 0.5, 0.6, 0.45, 1.0, "body"),
	pd_("Ball", 0.6, 0.3, 0.9, -0.55, 0.18, -0.85, C(47, 95, 143)),
	pd_("Ball", 0.6, 0.3, 0.9, 0.55, 0.18, -0.85, C(47, 95, 143)),
	pd_("Ball", 0.9, 0.9, 0.9, 0, 0.95, -1.6, "body"),
	pd_("Ball", 0.8, 0.8, 0.8, 0, 1.15, -2.1, "body"),
	pd_("Ball", 0.6, 0.6, 0.6, 0, 1.3, -2.5, C(47, 95, 143)),
	pd_("Ball", 0.4, 0.4, 0.4, 0, 1.42, -2.8, C(47, 95, 143)),
	pd_("Ball", 0.35, 0.45, 0.35, 0, 2.35, 1.5, C(140, 200, 245), nil, nil, 0.3),
}
PetDesigns.Brookotter = {
	pd_("Ball", 1.6, 1.4, 2.8, 0, 0.9, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.2, 1.0, 2.2, 0, 0.8, 0.4, C(207, 232, 247)),
	pd_("Ball", 1.6, 1.4, 1.6, 0, 1.45, 1.6, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.85, 0.65, 0.85, 0, 1.25, 2.25, "light"),
	pd_("Ball", 0.26, 0.26, 0.26, 0, 1.4, 2.62, C(47, 95, 143)),
	pd_("Ball", 0.32, 0.32, 0.32, -0.38, 1.6, 2.22, C(43, 43, 43)),
	pd_("Ball", 0.32, 0.32, 0.32, 0.38, 1.6, 2.22, C(43, 43, 43)),
	pd_("Ball", 0.42, 0.42, 0.42, -0.58, 2.1, 1.5, "body"),
	pd_("Ball", 0.42, 0.42, 0.42, 0.58, 2.1, 1.5, "body"),
	pd_("Ball", 0.7, 0.7, 0.7, 0, 0.95, 1.35, C(150, 150, 150)),
	pd_("Ball", 0.95, 0.95, 0.95, 0, 1.0, -1.7, "body"),
	pd_("Ball", 0.85, 0.85, 0.85, 0, 1.2, -2.25, "body"),
	pd_("Ball", 0.65, 0.65, 0.65, 0, 1.35, -2.65, C(47, 95, 143)),
	pd_("Wedge", 0.8, 0.1, 1.2, 0, 1.55, -2.9, C(207, 232, 247), { -15, 0, 0 }),
	pd_("Wedge", 0.8, 0.1, 1.2, 0, 1.35, -3.05, C(207, 232, 247), { -25, 0, 0 }),
	pd_("Ball", 0.35, 0.35, 0.35, -0.9, 1.9, 0.9, C(140, 200, 245), nil, nil, 0.35),
	pd_("Ball", 0.35, 0.35, 0.35, 0.9, 1.7, 1.3, C(140, 200, 245), nil, nil, 0.35),
	pd_("Ball", 0.35, 0.35, 0.35, 0, 2.2, 0.6, C(140, 200, 245), nil, nil, 0.35),
}
PetDesigns.Tidalotter = {
	pd_("Ball", 1.7, 1.5, 3.0, 0, 0.95, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.3, 1.1, 2.4, 0, 0.85, 0.45, C(207, 232, 247)),
	pd_("Ball", 1.7, 1.5, 1.7, 0, 1.55, 1.75, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.9, 0.7, 0.9, 0, 1.35, 2.4, "light"),
	pd_("Ball", 0.28, 0.28, 0.28, 0, 1.5, 2.8, C(47, 95, 143)),
	pd_("Ball", 0.34, 0.34, 0.34, -0.4, 1.7, 2.4, C(43, 43, 43)),
	pd_("Ball", 0.34, 0.34, 0.34, 0.4, 1.7, 2.4, C(43, 43, 43)),
	pd_("Ball", 0.45, 0.45, 0.45, -0.62, 2.25, 1.65, "body"),
	pd_("Ball", 0.45, 0.45, 0.45, 0.62, 2.25, 1.65, "body"),
	pd_("Ball", 1.0, 0.5, 1.0, 0, 1.35, 1.1, C(240, 248, 255)),
	pd_("Wedge", 0.2, 1.5, 2.0, 0, 2.05, 0.5, C(207, 232, 247), { 90, 0, 0 }),
	pd_("Wedge", 0.2, 1.3, 1.8, 0, 2.15, -0.4, C(255, 255, 255), { 90, 0, 0 }),
	pd_("Wedge", 0.2, 1.1, 1.6, 0, 2.2, -1.2, C(207, 232, 247), { 90, 0, 0 }),
	pd_("Ball", 0.55, 0.55, 0.55, -0.65, 0.5, 1.1, "body"),
	pd_("Ball", 0.55, 0.55, 0.55, 0.65, 0.5, 1.1, "body"),
	pd_("Ball", 1.0, 1.0, 1.0, 0, 1.05, -1.85, "body"),
	pd_("Ball", 0.9, 0.9, 0.9, 0, 1.3, -2.4, "body"),
	pd_("Ball", 0.7, 0.7, 0.7, 0, 1.5, -2.8, C(47, 95, 143)),
	pd_("Wedge", 0.9, 0.12, 1.3, 0, 1.8, -3.1, C(255, 255, 255), { -15, 0, 0 }),
	pd_("Ball", 0.4, 0.4, 0.4, -1.0, 2.0, 0.8, C(140, 200, 245), nil, nil, 0.35),
	pd_("Ball", 0.4, 0.4, 0.4, 1.0, 1.8, 1.2, C(140, 200, 245), nil, nil, 0.35),
	pd_("Ball", 0.4, 0.4, 0.4, -0.8, 1.6, 1.8, C(140, 200, 245), nil, nil, 0.35),
	pd_("Ball", 0.4, 0.4, 0.4, 0.8, 2.1, 0.4, C(140, 200, 245), nil, nil, 0.35),
	pd_("Ball", 0.4, 0.4, 0.4, 0, 2.4, 1.0, C(140, 200, 245), nil, nil, 0.35),
}
PetDesigns.Foamclaw = {
	pd_("Ball", 2.6, 1.4, 2.2, 0, 0.95, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 2.2, 0.9, 1.9, 0, 0.55, 0.05, C(246, 231, 193)),
	pd_("Cylinder", 0.6, 0.15, 0.15, -0.45, 1.85, 0.75, C(47, 95, 90), { 0, 0, 90 }),
	pd_("Cylinder", 0.6, 0.15, 0.15, 0.45, 1.85, 0.75, C(47, 95, 90), { 0, 0, 90 }),
	pd_("Ball", 0.4, 0.4, 0.4, -0.45, 2.2, 0.75, C(43, 43, 43)),
	pd_("Ball", 0.4, 0.4, 0.4, 0.45, 2.2, 0.75, C(43, 43, 43)),
	pd_("Cylinder", 0.8, 0.25, 0.25, -1.35, 0.75, 0.7, C(245, 143, 122), { 0, 0, 55 }),
	pd_("Cylinder", 0.8, 0.25, 0.25, 1.35, 0.75, 0.7, C(245, 143, 122), { 0, 0, -55 }),
	pd_("Ball", 0.9, 0.9, 0.9, -1.75, 0.95, 0.95, C(245, 143, 122)),
	pd_("Ball", 0.9, 0.9, 0.9, 1.75, 0.95, 0.95, C(245, 143, 122)),
	pd_("Wedge", 0.4, 0.3, 0.7, -1.95, 1.15, 1.35, C(245, 143, 122), { 0, -25, 0 }),
	pd_("Wedge", 0.4, 0.3, 0.7, 1.95, 1.15, 1.35, C(245, 143, 122), { 0, 25, 0 }),
	pd_("Cylinder", 1.0, 0.18, 0.18, -1.25, 0.5, 0.35, C(47, 95, 90), { 35, 0, 55 }),
	pd_("Cylinder", 1.0, 0.18, 0.18, 1.25, 0.5, 0.35, C(47, 95, 90), { 35, 0, -55 }),
	pd_("Cylinder", 1.0, 0.18, 0.18, -1.3, 0.5, -0.45, C(47, 95, 90), { -25, 0, 55 }),
	pd_("Cylinder", 1.0, 0.18, 0.18, 1.3, 0.5, -0.45, C(47, 95, 90), { -25, 0, -55 }),
	pd_("Ball", 0.4, 0.4, 0.4, -0.7, 1.75, 0.6, C(255, 255, 255), nil, nil, 0.3),
	pd_("Ball", 0.3, 0.3, 0.3, 0.2, 1.8, 0.85, C(255, 255, 255), nil, nil, 0.3),
	pd_("Ball", 0.25, 0.25, 0.25, 0.75, 1.72, 0.5, C(255, 255, 255), nil, nil, 0.3),
}
PetDesigns.Pearlclaw = {
	pd_("Ball", 2.9, 1.6, 2.5, 0, 1.05, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 2.5, 1.0, 2.2, 0, 0.6, 0.05, C(246, 231, 193)),
	pd_("Ball", 1.0, 1.0, 1.0, 0, 1.45, 1.35, C(250, 250, 255), nil, "Neon"),
	pd_("Wedge", 0.3, 0.7, 0.3, -1.15, 1.75, 0.55, C(246, 231, 193), { -15, 0, 12 }),
	pd_("Wedge", 0.3, 0.7, 0.3, 1.15, 1.75, 0.55, C(246, 231, 193), { -15, 0, -12 }),
	pd_("Wedge", 0.3, 0.7, 0.3, -1.25, 1.65, -0.35, C(246, 231, 193), { 10, 0, 12 }),
	pd_("Wedge", 0.3, 0.7, 0.3, 1.25, 1.65, -0.35, C(246, 231, 193), { 10, 0, -12 }),
	pd_("Cylinder", 0.65, 0.16, 0.16, -0.5, 2.0, 0.85, C(47, 95, 90), { 0, 0, 90 }),
	pd_("Cylinder", 0.65, 0.16, 0.16, 0.5, 2.0, 0.85, C(47, 95, 90), { 0, 0, 90 }),
	pd_("Ball", 0.42, 0.42, 0.42, -0.5, 2.38, 0.85, C(43, 43, 43)),
	pd_("Ball", 0.42, 0.42, 0.42, 0.5, 2.38, 0.85, C(43, 43, 43)),
	pd_("Cylinder", 0.95, 0.28, 0.28, -1.55, 0.8, 0.8, C(245, 143, 122), { 0, 0, 55 }),
	pd_("Cylinder", 0.95, 0.28, 0.28, 1.55, 0.8, 0.8, C(245, 143, 122), { 0, 0, -55 }),
	pd_("Ball", 1.15, 1.15, 1.15, -2.0, 1.0, 1.05, C(245, 143, 122)),
	pd_("Ball", 1.15, 1.15, 1.15, 2.0, 1.0, 1.05, C(245, 143, 122)),
	pd_("Wedge", 0.45, 0.35, 0.8, -2.25, 1.2, 1.5, C(245, 143, 122), { 0, -25, 0 }),
	pd_("Wedge", 0.45, 0.35, 0.8, 2.25, 1.2, 1.5, C(245, 143, 122), { 0, 25, 0 }),
	pd_("Cylinder", 1.1, 0.2, 0.2, -1.45, 0.55, 0.4, C(47, 95, 90), { 35, 0, 55 }),
	pd_("Cylinder", 1.1, 0.2, 0.2, 1.45, 0.55, 0.4, C(47, 95, 90), { 35, 0, -55 }),
	pd_("Cylinder", 1.1, 0.2, 0.2, -1.5, 0.55, -0.5, C(47, 95, 90), { -25, 0, 55 }),
	pd_("Cylinder", 1.1, 0.2, 0.2, 1.5, 0.55, -0.5, C(47, 95, 90), { -25, 0, -55 }),
	pd_("Ball", 0.45, 0.45, 0.45, -0.8, 1.95, 0.7, C(255, 255, 255), nil, nil, 0.3),
	pd_("Ball", 0.32, 0.32, 0.32, 0.35, 2.0, 0.95, C(255, 255, 255), nil, nil, 0.3),
	pd_("Ball", 0.28, 0.28, 0.28, 0.9, 1.9, 0.6, C(255, 255, 255), nil, nil, 0.3),
}
PetDesigns.Reefking = {
	pd_("Ball", 5.0, 1.5, 4.5, 0, 1.3, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 4.4, 1.1, 3.9, 0, 0.7, 0.05, C(246, 231, 193)),
	pd_("Ball", 1.6, 1.6, 1.6, 0, 1.9, 2.35, C(250, 250, 255), nil, "Neon"),
	pd_("Cylinder", 1.6, 0.3, 0.3, -1.2, 2.8, -0.6, C(245, 143, 122), { 0, 0, 90 }),
	pd_("Ball", 0.35, 0.35, 0.35, -1.2, 3.65, -0.6, C(255, 190, 170)),
	pd_("Cylinder", 1.6, 0.3, 0.3, -0.6, 2.9, -1.1, C(245, 143, 122), { 0, 0, 90 }),
	pd_("Ball", 0.35, 0.35, 0.35, -0.6, 3.75, -1.1, C(255, 190, 170)),
	pd_("Cylinder", 1.6, 0.3, 0.3, 0, 3.0, -1.3, C(245, 143, 122), { 0, 0, 90 }),
	pd_("Ball", 0.35, 0.35, 0.35, 0, 3.85, -1.3, C(255, 190, 170)),
	pd_("Cylinder", 1.6, 0.3, 0.3, 0.6, 2.9, -1.1, C(245, 143, 122), { 0, 0, 90 }),
	pd_("Ball", 0.35, 0.35, 0.35, 0.6, 3.75, -1.1, C(255, 190, 170)),
	pd_("Cylinder", 1.6, 0.3, 0.3, 1.2, 2.8, -0.6, C(245, 143, 122), { 0, 0, 90 }),
	pd_("Ball", 0.35, 0.35, 0.35, 1.2, 3.65, -0.6, C(255, 190, 170)),
	pd_("Ball", 0.5, 0.5, 0.5, -1.8, 1.95, 0.9, C(246, 231, 193)),
	pd_("Ball", 0.5, 0.5, 0.5, 1.8, 1.95, 0.9, C(246, 231, 193)),
	pd_("Ball", 0.5, 0.5, 0.5, -2.1, 1.8, -0.2, C(246, 231, 193)),
	pd_("Ball", 0.5, 0.5, 0.5, 2.1, 1.8, -0.2, C(246, 231, 193)),
	pd_("Ball", 0.5, 0.5, 0.5, -1.5, 2.05, -1.5, C(246, 231, 193)),
	pd_("Ball", 0.5, 0.5, 0.5, 1.5, 2.05, -1.5, C(246, 231, 193)),
	pd_("Cylinder", 0.7, 0.18, 0.18, -0.6, 2.45, 1.85, C(47, 95, 90), { 0, 0, 90 }),
	pd_("Cylinder", 0.7, 0.18, 0.18, 0.6, 2.45, 1.85, C(47, 95, 90), { 0, 0, 90 }),
	pd_("Ball", 0.48, 0.48, 0.48, -0.6, 2.85, 1.85, C(43, 43, 43)),
	pd_("Ball", 0.48, 0.48, 0.48, 0.6, 2.85, 1.85, C(43, 43, 43)),
	pd_("Cylinder", 1.3, 0.35, 0.35, -2.5, 0.95, 1.3, C(245, 143, 122), { 0, 0, 55 }),
	pd_("Cylinder", 1.3, 0.35, 0.35, 2.5, 0.95, 1.3, C(245, 143, 122), { 0, 0, -55 }),
	pd_("Ball", 1.8, 1.8, 1.8, -3.1, 1.2, 1.7, C(245, 143, 122)),
	pd_("Ball", 1.8, 1.8, 1.8, 3.1, 1.2, 1.7, C(245, 143, 122)),
	pd_("Wedge", 1.4, 0.5, 0.9, -3.45, 1.5, 2.35, C(245, 143, 122), { 0, -25, 0 }),
	pd_("Wedge", 1.4, 0.5, 0.9, 3.45, 1.5, 2.35, C(245, 143, 122), { 0, 25, 0 }),
	pd_("Cylinder", 1.4, 0.25, 0.25, -2.3, 0.65, 0.6, C(47, 95, 90), { 35, 0, 55 }),
	pd_("Cylinder", 1.4, 0.25, 0.25, 2.3, 0.65, 0.6, C(47, 95, 90), { 35, 0, -55 }),
	pd_("Cylinder", 1.4, 0.25, 0.25, -2.4, 0.65, -0.8, C(47, 95, 90), { -25, 0, 55 }),
	pd_("Cylinder", 1.4, 0.25, 0.25, 2.4, 0.65, -0.8, C(47, 95, 90), { -25, 0, -55 }),
	pd_("Ball", 0.55, 0.55, 0.55, -1.0, 2.2, 1.5, C(255, 255, 255), nil, nil, 0.3),
	pd_("Ball", 0.4, 0.4, 0.4, 0.4, 2.3, 1.8, C(255, 255, 255), nil, nil, 0.3),
	pd_("Ball", 0.35, 0.35, 0.35, 1.1, 2.15, 1.3, C(255, 255, 255), nil, nil, 0.3),
}

PetDesigns.Sproutie = {
	pd_("Ball", 1.8, 1.7, 1.7, 0, 0.95, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 0.3, 0.3, 0.3, -0.38, 1.1, 0.78, C(43, 43, 43)),
	pd_("Ball", 0.3, 0.3, 0.3, 0.38, 1.1, 0.78, C(43, 43, 43)),
	pd_("Ball", 0.3, 0.2, 0.1, -0.62, 0.9, 0.8, C(244, 169, 184)),
	pd_("Ball", 0.3, 0.2, 0.1, 0.62, 0.9, 0.8, C(244, 169, 184)),
	pd_("Cylinder", 0.6, 0.15, 0.15, 0, 2.05, 0, C(107, 170, 69), { 0, 0, 90 }),
	pd_("Wedge", 0.9, 0.15, 0.5, -0.4, 2.4, 0, C(79, 164, 68), { 0, 0, 35 }),
	pd_("Wedge", 0.9, 0.15, 0.5, 0.4, 2.4, 0, C(79, 164, 68), { 0, 0, -35 }),
	pd_("Ball", 0.3, 0.3, 0.3, 0, 2.45, 0, C(244, 169, 184)),
	pd_("Ball", 0.4, 0.4, 0.4, -0.9, 0.95, 0.3, "body"),
	pd_("Ball", 0.4, 0.4, 0.4, 0.9, 0.95, 0.3, "body"),
	pd_("Ball", 0.55, 0.35, 0.7, -0.4, 0.18, 0.35, "dark"),
	pd_("Ball", 0.55, 0.35, 0.7, 0.4, 0.18, 0.35, "dark"),
}
PetDesigns.Thornback = {
	pd_("Ball", 2.2, 1.9, 2.6, 0, 1.1, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.7, 1.5, 1.6, 0, 1.7, 1.1, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.9, 0.7, 0.9, 0, 1.5, 1.75, "light"),
	pd_("Ball", 0.24, 0.24, 0.24, 0, 1.62, 2.15, C(60, 45, 40)),
	pd_("Ball", 0.3, 0.3, 0.3, -0.38, 1.85, 1.8, C(43, 43, 43)),
	pd_("Ball", 0.3, 0.3, 0.3, 0.38, 1.85, 1.8, C(43, 43, 43)),
	pd_("Wedge", 0.35, 1.0, 0.35, -0.55, 2.65, 0.95, C(230, 225, 200), { -15, 0, 10 }),
	pd_("Wedge", 0.35, 1.0, 0.35, 0.55, 2.65, 0.95, C(230, 225, 200), { -15, 0, -10 }),
	pd_("Wedge", 0.5, 1.1, 0.4, 0, 2.35, 0.4, C(90, 60, 45), { -20, 0, 0 }),
	pd_("Wedge", 0.5, 1.25, 0.4, 0, 2.45, -0.35, C(90, 60, 45), { -12, 0, 0 }),
	pd_("Wedge", 0.5, 1.1, 0.4, 0, 2.35, -1.1, C(90, 60, 45), { -5, 0, 0 }),
	pd_("Wedge", 0.45, 0.9, 0.35, -0.6, 2.2, -0.35, C(90, 60, 45), { -12, 0, 15 }),
	pd_("Wedge", 0.45, 0.9, 0.35, 0.6, 2.2, -0.35, C(90, 60, 45), { -12, 0, -15 }),
	pd_("Ball", 0.65, 0.65, 0.65, -0.7, 0.35, 0.9, "dark"),
	pd_("Ball", 0.65, 0.65, 0.65, 0.7, 0.35, 0.9, "dark"),
	pd_("Ball", 0.65, 0.65, 0.65, -0.7, 0.35, -0.9, "dark"),
	pd_("Ball", 0.65, 0.65, 0.65, 0.7, 0.35, -0.9, "dark"),
	pd_("Ball", 0.9, 0.9, 0.9, 0, 1.2, -1.55, "body"),
	pd_("Ball", 0.7, 0.7, 0.7, 0, 1.45, -1.95, "body"),
	pd_("Wedge", 0.3, 0.6, 0.3, 0, 1.9, -2.2, C(90, 60, 45), { -25, 0, 0 }),
}
PetDesigns.Mosshorn = {
	pd_("Ball", 2.9, 2.4, 3.2, 0, 1.35, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 2.0, 1.8, 2.1, 0, 1.95, 1.35, "body", nil, nil, nil, "Head"),
	pd_("Ball", 1.1, 0.8, 1.0, 0, 1.7, 2.2, "light"),
	pd_("Ball", 0.12, 0.12, 0.12, -0.2, 1.8, 2.65, C(60, 50, 45)),
	pd_("Ball", 0.12, 0.12, 0.12, 0.2, 1.8, 2.65, C(60, 50, 45)),
	pd_("Ball", 0.34, 0.34, 0.34, -0.45, 2.1, 2.3, C(43, 43, 43)),
	pd_("Ball", 0.34, 0.34, 0.34, 0.45, 2.1, 2.3, C(43, 43, 43)),
	pd_("Cylinder", 1.0, 0.4, 0.4, -0.95, 3.0, 1.1, C(191, 174, 146), { 30, 0, 55 }),
	pd_("Cylinder", 1.0, 0.4, 0.4, 0.95, 3.0, 1.1, C(191, 174, 146), { 30, 0, -55 }),
	pd_("Cylinder", 1.0, 0.35, 0.35, -1.25, 3.55, 1.0, C(191, 174, 146), { 55, 0, 35 }),
	pd_("Cylinder", 1.0, 0.35, 0.35, 1.25, 3.55, 1.0, C(191, 174, 146), { 55, 0, -35 }),
	pd_("Ball", 0.4, 0.4, 0.4, -1.45, 3.95, 0.95, C(111, 160, 85)),
	pd_("Ball", 0.4, 0.4, 0.4, 1.45, 3.95, 0.95, C(111, 160, 85)),
	pd_("Ball", 0.5, 0.5, 0.5, -1.0, 2.2, 1.2, "body"),
	pd_("Ball", 0.5, 0.5, 0.5, 1.0, 2.2, 1.2, "body"),
	pd_("Ball", 2.6, 0.9, 2.8, 0, 2.65, -0.3, C(111, 160, 85)),
	pd_("Ball", 0.5, 0.5, 0.5, -0.7, 3.15, 0.2, C(111, 160, 85)),
	pd_("Ball", 0.5, 0.5, 0.5, 0.5, 3.2, -0.6, C(111, 160, 85)),
	pd_("Ball", 0.5, 0.5, 0.5, -0.2, 3.1, -1.0, C(111, 160, 85)),
	pd_("Ball", 0.5, 0.5, 0.5, 0.8, 3.05, 0.5, C(111, 160, 85)),
	pd_("Ball", 0.3, 0.3, 0.3, -0.5, 3.25, -0.3, C(242, 216, 107)),
	pd_("Ball", 0.3, 0.3, 0.3, 0.65, 3.3, 0.1, C(242, 216, 107)),
	pd_("Cylinder", 1.2, 0.8, 0.8, -0.85, 0.6, 1.0, "dark", { 0, 0, 90 }),
	pd_("Cylinder", 1.2, 0.8, 0.8, 0.85, 0.6, 1.0, "dark", { 0, 0, 90 }),
	pd_("Cylinder", 1.2, 0.8, 0.8, -0.85, 0.6, -1.0, "dark", { 0, 0, 90 }),
	pd_("Cylinder", 1.2, 0.8, 0.8, 0.85, 0.6, -1.0, "dark", { 0, 0, 90 }),
	pd_("Ball", 0.9, 0.5, 1.0, -0.85, 0.25, 1.05, C(90, 75, 60)),
	pd_("Ball", 0.9, 0.5, 1.0, 0.85, 0.25, 1.05, C(90, 75, 60)),
	pd_("Ball", 0.9, 0.5, 1.0, -0.85, 0.25, -0.95, C(90, 75, 60)),
	pd_("Ball", 0.9, 0.5, 1.0, 0.85, 0.25, -0.95, C(90, 75, 60)),
	pd_("Wedge", 0.5, 0.6, 0.8, 0, 1.6, -1.8, "dark", { 20, 0, 0 }),
}
PetDesigns.Turtle = {
	pd_("Ball", 3.0, 1.5, 2.6, 0, 1.05, 0, C(75, 168, 155), nil, nil, nil, "Body"),
	pd_("Ball", 3.2, 0.4, 2.8, 0, 0.62, 0, C(75, 168, 155)),
	pd_("Ball", 2.6, 0.6, 2.2, 0, 0.42, 0, C(241, 228, 184)),
	pd_("Ball", 0.8, 0.15, 0.8, 0, 1.85, 0, C(47, 127, 120)),
	pd_("Ball", 0.8, 0.15, 0.8, -1.0, 1.78, 0.7, C(47, 127, 120)),
	pd_("Ball", 0.8, 0.15, 0.8, 1.0, 1.78, 0.7, C(47, 127, 120)),
	pd_("Ball", 0.8, 0.15, 0.8, -1.0, 1.78, -0.7, C(47, 127, 120)),
	pd_("Ball", 0.8, 0.15, 0.8, 1.0, 1.78, -0.7, C(47, 127, 120)),
	pd_("Cylinder", 0.7, 0.6, 0.6, 0, 0.95, 1.45, "body", { 90, 0, 0 }),
	pd_("Ball", 1.2, 1.1, 1.3, 0, 1.15, 1.95, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.28, 0.28, 0.28, -0.32, 1.3, 2.5, C(43, 43, 43)),
	pd_("Ball", 0.28, 0.28, 0.28, 0.32, 1.3, 2.5, C(43, 43, 43)),
	pd_("Ball", 1.1, 0.3, 0.9, -1.35, 0.55, 0.85, "body", nil, nil, nil, "Part"),
	pd_("Ball", 1.1, 0.3, 0.9, 1.35, 0.55, 0.85, "body"),
	pd_("Ball", 0.8, 0.3, 0.8, -1.25, 0.5, -0.85, "body"),
	pd_("Ball", 0.8, 0.3, 0.8, 1.25, 0.5, -0.85, "body"),
	pd_("Wedge", 0.3, 0.25, 0.6, 0, 0.8, -1.5, "body", { 180, 0, 0 }),
}
PetDesigns.Shellguard = {
	pd_("Ball", 4.4, 2.2, 3.8, 0, 1.5, 0, C(63, 158, 150), nil, nil, nil, "Body"),
	pd_("Ball", 4.6, 0.55, 4.0, 0, 0.85, 0, C(216, 200, 144)),
	pd_("Ball", 4.0, 0.8, 3.4, 0, 0.55, 0, C(241, 228, 184)),
	pd_("Ball", 1.0, 0.2, 1.0, 0, 2.68, 0, C(37, 112, 106)),
	pd_("Ball", 1.0, 0.2, 1.0, -1.3, 2.55, 0.9, C(37, 112, 106)),
	pd_("Ball", 1.0, 0.2, 1.0, 1.3, 2.55, 0.9, C(37, 112, 106)),
	pd_("Ball", 1.0, 0.2, 1.0, -1.3, 2.55, -0.9, C(37, 112, 106)),
	pd_("Ball", 1.0, 0.2, 1.0, 1.3, 2.55, -0.9, C(37, 112, 106)),
	pd_("Ball", 1.0, 0.2, 1.0, 0, 2.55, 1.25, C(37, 112, 106)),
	pd_("Ball", 1.0, 0.2, 1.0, 0, 2.55, -1.25, C(37, 112, 106)),
	pd_("Wedge", 0.4, 0.6, 0.4, -2.2, 1.3, 0.8, C(37, 112, 106), { 0, 0, 25 }),
	pd_("Wedge", 0.4, 0.6, 0.4, 2.2, 1.3, 0.8, C(37, 112, 106), { 0, 0, -25 }),
	pd_("Wedge", 0.4, 0.6, 0.4, -2.2, 1.3, -0.8, C(37, 112, 106), { 0, 0, 25 }),
	pd_("Wedge", 0.4, 0.6, 0.4, 2.2, 1.3, -0.8, C(37, 112, 106), { 0, 0, -25 }),
	pd_("Cylinder", 1.0, 0.9, 0.9, 0, 1.3, 2.0, "body", { 90, 0, 0 }),
	pd_("Ball", 1.7, 1.5, 1.8, 0, 1.6, 2.7, "body", nil, nil, nil, "Head"),
	pd_("Wedge", 1.2, 0.2, 0.4, 0, 2.25, 2.95, "dark", { 90, 0, 0 }),
	pd_("Ball", 0.34, 0.34, 0.34, -0.42, 1.8, 3.45, C(43, 43, 43)),
	pd_("Ball", 0.34, 0.34, 0.34, 0.42, 1.8, 3.45, C(43, 43, 43)),
	pd_("Ball", 1.6, 0.4, 1.3, -1.95, 0.7, 1.15, "body"),
	pd_("Ball", 1.6, 0.4, 1.3, 1.95, 0.7, 1.15, "body"),
	pd_("Ball", 1.2, 0.4, 1.2, -1.85, 0.65, -1.15, "body"),
	pd_("Ball", 1.2, 0.4, 1.2, 1.85, 0.65, -1.15, "body"),
	pd_("Wedge", 0.4, 0.3, 0.8, 0, 1.0, -2.1, "body", { 180, 0, 0 }),
}
PetDesigns.Tidalord = {
	pd_("Ball", 6.0, 3.0, 5.2, 0, 2.1, 0, C(47, 120, 184), nil, nil, nil, "Body"),
	pd_("Ball", 6.2, 0.7, 5.4, 0, 1.15, 0, C(242, 201, 76)),
	pd_("Ball", 5.4, 1.0, 4.6, 0, 0.75, 0, C(230, 240, 245)),
	pd_("Ball", 1.4, 0.25, 1.4, 0, 3.68, 0.6, C(31, 79, 138)),
	pd_("Ball", 1.4, 0.25, 1.4, -1.7, 3.5, 1.2, C(31, 79, 138)),
	pd_("Ball", 1.4, 0.25, 1.4, 1.7, 3.5, 1.2, C(31, 79, 138)),
	pd_("Ball", 1.4, 0.25, 1.4, -1.7, 3.5, -1.0, C(31, 79, 138)),
	pd_("Ball", 1.4, 0.25, 1.4, 1.7, 3.5, -1.0, C(31, 79, 138)),
	pd_("Ball", 1.4, 0.25, 1.4, 0, 3.55, -1.6, C(31, 79, 138)),
	pd_("Ball", 1.4, 0.25, 1.4, 0, 3.6, 1.7, C(31, 79, 138)),
	pd_("Cylinder", 1.8, 0.35, 0.35, -1.0, 4.3, -0.9, C(245, 143, 122), { 0, 0, 90 }),
	pd_("Ball", 0.45, 0.45, 0.45, -1.0, 5.25, -0.9, C(255, 190, 170)),
	pd_("Cylinder", 1.8, 0.35, 0.35, -0.5, 4.4, -1.3, C(245, 143, 122), { 0, 0, 90 }),
	pd_("Ball", 0.45, 0.45, 0.45, -0.5, 5.35, -1.3, C(255, 190, 170)),
	pd_("Cylinder", 1.8, 0.35, 0.35, 0, 4.45, -1.45, C(245, 143, 122), { 0, 0, 90 }),
	pd_("Ball", 0.45, 0.45, 0.45, 0, 5.4, -1.45, C(255, 190, 170)),
	pd_("Cylinder", 1.8, 0.35, 0.35, 0.5, 4.4, -1.3, C(245, 143, 122), { 0, 0, 90 }),
	pd_("Ball", 0.45, 0.45, 0.45, 0.5, 5.35, -1.3, C(255, 190, 170)),
	pd_("Cylinder", 1.8, 0.35, 0.35, 1.0, 4.3, -0.9, C(245, 143, 122), { 0, 0, 90 }),
	pd_("Ball", 0.45, 0.45, 0.45, 1.0, 5.25, -0.9, C(255, 190, 170)),
	pd_("Ball", 1.2, 1.2, 1.2, 0, 3.4, 2.6, C(250, 250, 255), nil, "Neon"),
	pd_("Cylinder", 1.4, 1.3, 1.3, 0, 1.9, 2.9, "body", { 90, 0, 0 }),
	pd_("Ball", 2.2, 2.0, 2.4, 0, 2.3, 3.9, "body", nil, nil, nil, "Head"),
	pd_("Wedge", 0.4, 1.0, 0.2, 0, 3.6, 4.1, C(242, 201, 76), nil, "Neon"),
	pd_("Wedge", 0.4, 0.9, 0.2, -0.4, 3.5, 4.05, C(242, 201, 76), { 0, 0, 15 }, "Neon"),
	pd_("Wedge", 0.4, 0.9, 0.2, 0.4, 3.5, 4.05, C(242, 201, 76), { 0, 0, -15 }, "Neon"),
	pd_("Ball", 0.4, 0.4, 0.4, -0.55, 2.5, 4.95, C(43, 43, 43)),
	pd_("Ball", 0.4, 0.4, 0.4, 0.55, 2.5, 4.95, C(43, 43, 43)),
	pd_("Ball", 2.2, 0.5, 1.8, -2.7, 0.95, 1.6, "body"),
	pd_("Ball", 2.2, 0.5, 1.8, 2.7, 0.95, 1.6, "body"),
	pd_("Ball", 1.6, 0.5, 1.5, -2.55, 0.85, -1.6, "body"),
	pd_("Ball", 1.6, 0.5, 1.5, 2.55, 0.85, -1.6, "body"),
	pd_("Wedge", 0.5, 0.4, 1.0, 0, 1.4, -2.9, "body", { 180, 0, 0 }),
	pd_("Ball", 0.5, 0.5, 0.5, -2.9, 2.6, 1.9, C(140, 200, 245), nil, nil, 0.4),
	pd_("Ball", 0.5, 0.5, 0.5, 2.9, 2.4, 2.2, C(140, 200, 245), nil, nil, 0.4),
	pd_("Ball", 0.5, 0.5, 0.5, -2.7, 2.2, -2.0, C(140, 200, 245), nil, nil, 0.4),
	pd_("Ball", 0.5, 0.5, 0.5, 2.7, 2.8, -1.7, C(140, 200, 245), nil, nil, 0.4),
}

PetDesigns.Drakeling = {
	pd_("Ball", 1.8, 1.6, 2.4, 0, 1.05, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.3, 1.1, 1.8, 0, 0.85, 0.35, C(255, 217, 154)),
	pd_("Ball", 1.7, 1.4, 1.7, 0, 1.95, 0.85, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.9, 0.6, 1.0, 0, 1.7, 1.55, "body"),
	pd_("Ball", 0.12, 0.12, 0.12, -0.2, 1.85, 2.0, C(120, 40, 30)),
	pd_("Ball", 0.12, 0.12, 0.12, 0.2, 1.85, 2.0, C(120, 40, 30)),
	pd_("Ball", 0.32, 0.32, 0.32, -0.4, 2.1, 1.55, C(255, 210, 63)),
	pd_("Ball", 0.32, 0.32, 0.32, 0.4, 2.1, 1.55, C(255, 210, 63)),
	pd_("Wedge", 0.3, 0.8, 0.3, -0.55, 2.75, 0.6, C(255, 233, 184), { -25, 0, 12 }),
	pd_("Wedge", 0.3, 0.8, 0.3, 0.55, 2.75, 0.6, C(255, 233, 184), { -25, 0, -12 }),
	pd_("Wedge", 0.35, 0.7, 0.5, 0, 2.15, 0.35, C(255, 233, 184), { -15, 0, 0 }),
	pd_("Wedge", 0.35, 0.95, 0.5, 0, 2.3, -0.3, C(255, 233, 184), { -8, 0, 0 }),
	pd_("Wedge", 0.35, 0.8, 0.5, 0, 2.2, -0.95, C(255, 233, 184), { 0, 0, 0 }),
	pd_("Wedge", 0.35, 0.65, 0.5, 0, 2.05, -1.5, C(255, 233, 184), { 8, 0, 0 }),
	pd_("Wedge", 0.3, 0.5, 0.4, 0, 1.9, -2.0, C(255, 233, 184), { 15, 0, 0 }),
	pd_("Wedge", 1.4, 1.5, 0.12, -1.15, 2.0, -0.15, C(242, 163, 58), { 0, 20, -18 }),
	pd_("Wedge", 1.4, 1.5, 0.12, 1.15, 2.0, -0.15, C(242, 163, 58), { 0, -20, 18 }),
	pd_("Ball", 0.7, 0.7, 0.7, -0.6, 0.42, 0.8, "body"),
	pd_("Ball", 0.7, 0.7, 0.7, 0.6, 0.42, 0.8, "body"),
	pd_("Ball", 0.6, 0.35, 0.9, -0.6, 0.2, 1.05, "body"),
	pd_("Ball", 0.6, 0.35, 0.9, 0.6, 0.2, 1.05, "body"),
	pd_("Ball", 1.0, 1.0, 1.0, 0, 1.15, -1.55, "body"),
	pd_("Ball", 0.85, 0.85, 0.85, 0, 1.4, -2.05, "body"),
	pd_("Ball", 0.7, 0.7, 0.7, 0, 1.6, -2.45, "body"),
	pd_("Ball", 0.5, 0.5, 0.5, 0, 1.78, -2.75, "body"),
	pd_("Ball", 0.35, 0.35, 0.35, 0, 1.92, -2.98, "body"),
	pd_("Wedge", 0.5, 0.8, 0.15, 0, 2.2, -3.1, C(255, 193, 69), { -25, 0, 0 }, "Neon"),
}
PetDesigns.Drakewing = {
	pd_("Ball", 2.4, 2.2, 3.4, 0, 1.5, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.6, 1.4, 2.4, 0, 1.25, 0.5, C(244, 235, 208)),
	pd_("Ball", 1.2, 1.8, 1.2, 0, 2.6, 1.3, "body"),
	pd_("Ball", 1.9, 1.6, 2.0, 0, 3.3, 1.9, "body", nil, nil, nil, "Head"),
	pd_("Ball", 1.0, 0.7, 1.2, 0, 3.05, 2.75, "body"),
	pd_("Ball", 0.12, 0.12, 0.12, -0.22, 3.2, 3.3, C(70, 90, 140)),
	pd_("Ball", 0.12, 0.12, 0.12, 0.22, 3.2, 3.3, C(70, 90, 140)),
	pd_("Ball", 0.34, 0.34, 0.34, -0.48, 3.45, 2.75, C(255, 210, 63)),
	pd_("Ball", 0.34, 0.34, 0.34, 0.48, 3.45, 2.75, C(255, 210, 63)),
	pd_("Wedge", 0.4, 1.4, 0.4, -0.65, 4.15, 1.6, C(242, 232, 200), { -25, 0, 12 }),
	pd_("Wedge", 0.4, 1.4, 0.4, 0.65, 4.15, 1.6, C(242, 232, 200), { -25, 0, -12 }),
	pd_("Wedge", 0.3, 0.9, 0.2, 0, 4.05, 1.85, C(242, 232, 200), { -15, 0, 0 }),
	pd_("Wedge", 0.4, 0.9, 0.5, 0, 2.9, 0.9, C(242, 232, 200), { -15, 0, 0 }),
	pd_("Wedge", 0.4, 1.2, 0.5, 0, 3.05, 0.15, C(242, 232, 200), { -8, 0, 0 }),
	pd_("Wedge", 0.4, 1.05, 0.5, 0, 2.98, -0.6, C(242, 232, 200), { 0, 0, 0 }),
	pd_("Wedge", 0.4, 0.9, 0.5, 0, 2.85, -1.3, C(242, 232, 200), { 8, 0, 0 }),
	pd_("Wedge", 0.35, 0.7, 0.45, 0, 2.65, -1.95, C(242, 232, 200), { 15, 0, 0 }),
	pd_("Cylinder", 2.2, 0.25, 0.25, -1.7, 3.1, 0.3, "body", { 0, 0, 55 }),
	pd_("Cylinder", 2.2, 0.25, 0.25, 1.7, 3.1, 0.3, "body", { 0, 0, -55 }),
	pd_("Wedge", 2.2, 0.1, 1.8, -2.6, 3.3, -0.5, C(168, 208, 248), { 0, 15, -12 }),
	pd_("Wedge", 2.2, 0.1, 1.8, 2.6, 3.3, -0.5, C(168, 208, 248), { 0, -15, 12 }),
	pd_("Wedge", 1.7, 0.1, 1.4, -2.75, 3.0, -0.9, C(168, 208, 248), { 0, 15, -8 }),
	pd_("Wedge", 1.7, 0.1, 1.4, 2.75, 3.0, -0.9, C(168, 208, 248), { 0, -15, 8 }),
	pd_("Cylinder", 1.3, 0.8, 0.8, -0.75, 0.65, 0.9, "body", { 0, 0, 90 }),
	pd_("Cylinder", 1.3, 0.8, 0.8, 0.75, 0.65, 0.9, "body", { 0, 0, 90 }),
	pd_("Ball", 0.9, 0.4, 1.2, -0.75, 0.2, 1.15, "body"),
	pd_("Ball", 0.9, 0.4, 1.2, 0.75, 0.2, 1.15, "body"),
	pd_("Ball", 1.2, 1.2, 1.2, 0, 1.6, -2.1, "body"),
	pd_("Ball", 1.0, 1.0, 1.0, 0, 1.85, -2.7, "body"),
	pd_("Ball", 0.8, 0.8, 0.8, 0, 2.05, -3.2, "body"),
	pd_("Ball", 0.6, 0.6, 0.6, 0, 2.22, -3.6, "body"),
	pd_("Ball", 0.4, 0.4, 0.4, 0, 2.35, -3.9, "body"),
	pd_("Wedge", 0.6, 0.9, 0.2, 0, 2.6, -4.15, C(242, 232, 200), { -20, 90, 0 }),
}
PetDesigns.Cinderdrake = {
	pd_("Ball", 2.6, 2.4, 3.4, 0, 1.55, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.7, 1.5, 2.5, 0, 1.3, 0.5, C(255, 200, 120)),
	pd_("Ball", 0.8, 0.8, 0.8, 0, 1.6, 1.6, C(255, 150, 50), nil, "Neon"),
	pd_("Ball", 1.2, 1.9, 1.2, 0, 2.75, 1.3, "body"),
	pd_("Ball", 2.0, 1.7, 2.1, 0, 3.5, 1.9, "body", nil, nil, nil, "Head"),
	pd_("Ball", 1.05, 0.75, 1.25, 0, 3.25, 2.8, "body"),
	pd_("Ball", 0.13, 0.13, 0.13, -0.24, 3.4, 3.35, C(90, 40, 30)),
	pd_("Ball", 0.13, 0.13, 0.13, 0.24, 3.4, 3.35, C(90, 40, 30)),
	pd_("Ball", 0.36, 0.36, 0.36, -0.5, 3.65, 2.8, C(255, 210, 63)),
	pd_("Ball", 0.36, 0.36, 0.36, 0.5, 3.65, 2.8, C(255, 210, 63)),
	pd_("Wedge", 0.5, 1.8, 0.5, -0.7, 4.5, 1.55, C(63, 47, 42), { -25, 0, 12 }),
	pd_("Wedge", 0.5, 1.8, 0.5, 0.7, 4.5, 1.55, C(63, 47, 42), { -25, 0, -12 }),
	pd_("Wedge", 0.9, 0.25, 0.4, -0.55, 4.05, 2.2, C(63, 47, 42), { 90, 0, 0 }),
	pd_("Wedge", 0.9, 0.25, 0.4, 0.55, 4.05, 2.2, C(63, 47, 42), { 90, 0, 0 }),
	pd_("Wedge", 0.4, 1.0, 0.5, 0, 3.1, 0.9, C(255, 210, 90), { -15, 0, 0 }),
	pd_("Wedge", 0.4, 1.3, 0.5, 0, 3.25, 0.1, C(255, 210, 90), { -8, 0, 0 }),
	pd_("Wedge", 0.4, 1.15, 0.5, 0, 3.18, -0.7, C(255, 193, 69), { 0, 0, 0 }),
	pd_("Wedge", 0.4, 1.0, 0.5, 0, 3.05, -1.45, C(255, 193, 69), { 8, 0, 0 }),
	pd_("Wedge", 0.35, 0.8, 0.45, 0, 2.9, -2.1, C(242, 118, 46), { 15, 0, 0 }),
	pd_("Cylinder", 1.8, 0.25, 0.25, -1.6, 3.0, 0.2, "body", { 0, 0, 65 }),
	pd_("Cylinder", 1.8, 0.25, 0.25, 1.6, 3.0, 0.2, "body", { 0, 0, -65 }),
	pd_("Wedge", 1.8, 0.1, 1.4, -2.2, 3.05, -0.6, C(242, 118, 46), { 0, 15, -10 }),
	pd_("Wedge", 1.8, 0.1, 1.4, 2.2, 3.05, -0.6, C(242, 118, 46), { 0, -15, 10 }),
	pd_("Cylinder", 1.4, 1.0, 1.0, -0.8, 0.7, 0.9, "body", { 0, 0, 90 }),
	pd_("Cylinder", 1.4, 1.0, 1.0, 0.8, 0.7, 0.9, "body", { 0, 0, 90 }),
	pd_("Ball", 0.95, 0.45, 1.25, -0.8, 0.22, 1.15, "body"),
	pd_("Ball", 0.95, 0.45, 1.25, 0.8, 0.22, 1.15, "body"),
	pd_("Ball", 1.25, 1.25, 1.25, 0, 1.65, -2.1, "body"),
	pd_("Ball", 1.05, 1.05, 1.05, 0, 1.9, -2.75, "body"),
	pd_("Ball", 0.85, 0.85, 0.85, 0, 2.1, -3.25, "body"),
	pd_("Ball", 0.6, 0.6, 0.6, 0, 2.28, -3.65, "body"),
	pd_("Wedge", 0.5, 1.0, 0.15, 0, 2.6, -3.85, C(255, 210, 90), { -25, 0, 0 }, "Neon"),
	pd_("Wedge", 0.5, 0.9, 0.15, -0.3, 2.5, -3.85, C(245, 154, 47), { -25, 0, 18 }),
	pd_("Wedge", 0.5, 0.9, 0.15, 0.3, 2.5, -3.85, C(245, 154, 47), { -25, 0, -18 }),
}
PetDesigns.VoidDragon = {
	pd_("Ball", 3.8, 3.4, 5.4, 0, 2.2, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 2.4, 0.5, 0.9, 0, 1.6, 1.9, C(90, 79, 138)),
	pd_("Ball", 2.4, 0.5, 0.9, 0, 1.55, 0.9, C(90, 79, 138)),
	pd_("Ball", 2.4, 0.5, 0.9, 0, 1.55, -0.1, C(90, 79, 138)),
	pd_("Ball", 2.3, 0.5, 0.9, 0, 1.6, -1.1, C(90, 79, 138)),
	pd_("Ball", 2.2, 0.5, 0.85, 0, 1.7, -2.0, C(90, 79, 138)),
	pd_("Ball", 1.8, 2.6, 1.8, 0, 3.6, 2.2, "body"),
	pd_("Ball", 2.8, 2.3, 3.0, 0, 4.6, 3.1, "body", nil, nil, nil, "Head"),
	pd_("Ball", 1.5, 1.0, 1.7, 0, 4.3, 4.3, "body"),
	pd_("Ball", 0.2, 0.2, 0.2, -0.3, 4.5, 5.05, C(40, 35, 70)),
	pd_("Ball", 0.2, 0.2, 0.2, 0.3, 4.5, 5.05, C(40, 35, 70)),
	pd_("Ball", 0.5, 0.5, 0.5, -0.65, 4.85, 4.4, C(201, 168, 255), nil, "Neon"),
	pd_("Ball", 0.5, 0.5, 0.5, 0.65, 4.85, 4.4, C(201, 168, 255), nil, "Neon"),
	pd_("Wedge", 0.7, 2.8, 0.7, -0.9, 6.0, 2.6, C(216, 208, 240), { -25, 0, 12 }),
	pd_("Wedge", 0.7, 2.8, 0.7, 0.9, 6.0, 2.6, C(216, 208, 240), { -25, 0, -12 }),
	pd_("Wedge", 0.4, 1.2, 0.4, -1.05, 5.3, 2.45, C(216, 208, 240), { -30, 0, 20 }),
	pd_("Wedge", 0.4, 1.2, 0.4, 1.05, 5.3, 2.45, C(216, 208, 240), { -30, 0, -20 }),
	pd_("Wedge", 1.3, 0.3, 0.6, -0.7, 5.35, 3.6, "dark", { 90, 0, 0 }),
	pd_("Wedge", 1.3, 0.3, 0.6, 0.7, 5.35, 3.6, "dark", { 90, 0, 0 }),
	pd_("Wedge", 0.6, 1.3, 0.8, 0, 4.3, 1.4, C(155, 107, 255), { -15, 0, 0 }, "Neon"),
	pd_("Wedge", 0.6, 1.7, 0.8, 0, 4.5, 0.5, C(155, 107, 255), { -8, 0, 0 }, "Neon"),
	pd_("Wedge", 0.6, 2.0, 0.8, 0, 4.6, -0.5, C(155, 107, 255), { 0, 0, 0 }, "Neon"),
	pd_("Wedge", 0.6, 1.8, 0.8, 0, 4.5, -1.5, C(120, 85, 220), { 8, 0, 0 }),
	pd_("Wedge", 0.6, 1.5, 0.8, 0, 4.3, -2.4, C(120, 85, 220), { 15, 0, 0 }),
	pd_("Cylinder", 3.6, 0.4, 0.4, -2.5, 4.3, 1.6, "body", { 0, 0, 55 }),
	pd_("Cylinder", 3.6, 0.4, 0.4, 2.5, 4.3, 1.6, "body", { 0, 0, -55 }),
	pd_("Wedge", 3.4, 0.12, 2.6, -3.8, 4.6, 0.2, C(75, 63, 122), { 0, 15, -12 }),
	pd_("Wedge", 3.4, 0.12, 2.6, 3.8, 4.6, 0.2, C(75, 63, 122), { 0, -15, 12 }),
	pd_("Wedge", 2.8, 0.12, 2.1, -4.0, 4.2, -0.5, C(75, 63, 122), { 0, 15, -8 }),
	pd_("Wedge", 2.8, 0.12, 2.1, 4.0, 4.2, -0.5, C(75, 63, 122), { 0, -15, 8 }),
	pd_("Cylinder", 2.0, 1.3, 1.3, -1.2, 1.0, -1.6, "body", { 0, 0, 90 }),
	pd_("Cylinder", 2.0, 1.3, 1.3, 1.2, 1.0, -1.6, "body", { 0, 0, 90 }),
	pd_("Cylinder", 1.6, 0.9, 0.9, -1.1, 0.8, 1.9, "body", { 0, 0, 90 }),
	pd_("Cylinder", 1.6, 0.9, 0.9, 1.1, 0.8, 1.9, "body", { 0, 0, 90 }),
	pd_("Ball", 1.3, 0.6, 1.8, -1.2, 0.3, -1.4, "body"),
	pd_("Ball", 1.3, 0.6, 1.8, 1.2, 0.3, -1.4, "body"),
	pd_("Ball", 1.3, 0.6, 1.8, -1.1, 0.3, 2.1, "body"),
	pd_("Ball", 1.3, 0.6, 1.8, 1.1, 0.3, 2.1, "body"),
	pd_("Cylinder", 0.12, 1.4, 1.4, 0, 2.6, 2.35, C(155, 107, 255), { 90, 0, 0 }, "Neon"),
	pd_("Cylinder", 0.2, 1.0, 1.0, 0, 2.6, 2.3, "body", { 90, 0, 0 }),
	pd_("Ball", 1.8, 1.8, 1.8, 0, 2.3, -3.2, "body"),
	pd_("Ball", 1.5, 1.5, 1.5, 0, 2.6, -3.9, "body"),
	pd_("Ball", 1.2, 1.2, 1.2, 0, 2.85, -4.5, "body"),
	pd_("Ball", 0.9, 0.9, 0.9, 0, 3.05, -5.0, "body"),
	pd_("Ball", 0.6, 0.6, 0.6, 0, 3.2, -5.45, "body"),
	pd_("Wedge", 1.0, 1.5, 0.3, 0, 3.5, -5.8, C(155, 107, 255), { -20, 90, 0 }, "Neon"),
	pd_("Ball", 0.5, 0.5, 0.5, -2.3, 3.4, 2.6, C(155, 107, 255), nil, "Neon"),
	pd_("Ball", 0.5, 0.5, 0.5, 2.4, 3.9, 1.8, C(155, 107, 255), nil, "Neon"),
	pd_("Ball", 0.5, 0.5, 0.5, -2.5, 4.4, 0.8, C(155, 107, 255), nil, "Neon"),
	pd_("Ball", 0.5, 0.5, 0.5, 2.3, 3.2, 3.2, C(155, 107, 255), nil, "Neon"),
	pd_("Ball", 0.5, 0.5, 0.5, 0, 4.9, 0.2, C(155, 107, 255), nil, "Neon"),
}

PetDesigns.PrimordialTurtle = {
	pd_("Ball", 8.0, 4.0, 7.0, 0, 2.6, 0, C(44, 110, 122), nil, nil, nil, "Body"),
	pd_("Ball", 8.4, 1.0, 7.4, 0, 1.35, 0, C(44, 110, 122)),
	pd_("Ball", 7.2, 1.2, 6.2, 0, 0.85, 0, C(232, 221, 184)),
	pd_("Ball", 1.8, 0.3, 1.8, 0, 4.7, 0.8, C(29, 74, 85)),
	pd_("Ball", 1.8, 0.3, 1.8, -2.2, 4.5, 1.6, C(29, 74, 85)),
	pd_("Ball", 1.8, 0.3, 1.8, 2.2, 4.5, 1.6, C(29, 74, 85)),
	pd_("Ball", 1.8, 0.3, 1.8, -2.4, 4.45, -0.6, C(29, 74, 85)),
	pd_("Ball", 1.8, 0.3, 1.8, 2.4, 4.45, -0.6, C(29, 74, 85)),
	pd_("Ball", 1.8, 0.3, 1.8, -1.8, 4.4, -2.2, C(29, 74, 85)),
	pd_("Ball", 1.8, 0.3, 1.8, 1.8, 4.4, -2.2, C(29, 74, 85)),
	pd_("Ball", 1.7, 0.3, 1.7, 0, 4.55, -2.6, C(29, 74, 85)),
	pd_("Ball", 1.7, 0.3, 1.7, 0, 4.62, 2.6, C(29, 74, 85)),
	pd_("Ball", 1.6, 0.3, 1.6, -1.2, 4.6, 2.2, C(94, 143, 90)),
	pd_("Ball", 1.6, 0.3, 1.6, 1.5, 4.65, 0.2, C(94, 143, 90)),
	pd_("Ball", 1.6, 0.3, 1.6, -0.6, 4.5, -1.4, C(94, 143, 90)),
	pd_("Ball", 1.5, 0.3, 1.5, 2.0, 4.55, -2.4, C(94, 143, 90)),
	pd_("Ball", 1.5, 0.3, 1.5, -2.2, 4.5, -1.8, C(94, 143, 90)),
	pd_("Cylinder", 2.0, 0.4, 0.4, -2.8, 5.3, 1.4, C(232, 180, 154), { 0, 0, 90 }),
	pd_("Ball", 0.5, 0.5, 0.5, -2.8, 6.35, 1.4, C(255, 205, 185)),
	pd_("Cylinder", 1.5, 0.35, 0.35, -2.5, 5.15, 1.9, C(232, 180, 154), { 0, 0, 90 }),
	pd_("Ball", 0.45, 0.45, 0.45, -2.5, 5.95, 1.9, C(255, 205, 185)),
	pd_("Cylinder", 2.0, 0.4, 0.4, 2.9, 5.3, 0.6, C(232, 180, 154), { 0, 0, 90 }),
	pd_("Ball", 0.5, 0.5, 0.5, 2.9, 6.35, 0.6, C(255, 205, 185)),
	pd_("Cylinder", 1.6, 0.35, 0.35, 3.1, 5.2, 1.2, C(232, 180, 154), { 0, 0, 90 }),
	pd_("Ball", 0.45, 0.45, 0.45, 3.1, 6.05, 1.2, C(255, 205, 185)),
	pd_("Cylinder", 1.8, 0.4, 0.4, 0.4, 5.35, -2.9, C(232, 180, 154), { 0, 0, 90 }),
	pd_("Ball", 0.5, 0.5, 0.5, 0.4, 6.3, -2.9, C(255, 205, 185)),
	pd_("Ball", 0.5, 0.5, 0.5, -1.9, 3.9, 2.9, C(245, 240, 220)),
	pd_("Ball", 0.5, 0.5, 0.5, 1.9, 3.9, 2.9, C(245, 240, 220)),
	pd_("Ball", 0.5, 0.5, 0.5, -3.3, 3.4, 0.9, C(245, 240, 220)),
	pd_("Ball", 0.5, 0.5, 0.5, 3.3, 3.4, 0.9, C(245, 240, 220)),
	pd_("Ball", 0.5, 0.5, 0.5, -3.2, 3.5, -1.6, C(245, 240, 220)),
	pd_("Ball", 0.5, 0.5, 0.5, 3.2, 3.5, -1.6, C(245, 240, 220)),
	pd_("Ball", 0.3, 0.3, 0.3, -1.4, 4.85, 3.1, C(127, 240, 224), nil, "Neon"),
	pd_("Ball", 0.3, 0.3, 0.3, 0, 4.95, 3.35, C(127, 240, 224), nil, "Neon"),
	pd_("Ball", 0.3, 0.3, 0.3, 1.4, 4.85, 3.1, C(127, 240, 224), nil, "Neon"),
	pd_("Ball", 0.3, 0.3, 0.3, -2.2, 4.7, 2.5, C(127, 240, 224), nil, "Neon"),
	pd_("Ball", 0.3, 0.3, 0.3, 2.2, 4.7, 2.5, C(127, 240, 224), nil, "Neon"),
	pd_("Ball", 0.3, 0.3, 0.3, 0, 4.8, 3.9, C(127, 240, 224), nil, "Neon"),
	pd_("Cylinder", 0.3, 3.0, 3.0, 0, 4.85, -0.4, C(160, 130, 95), { 0, 0, 90 }),
	pd_("Cylinder", 2.0, 1.8, 1.8, 0, 2.4, 4.0, "body", { 90, 0, 0 }),
	pd_("Ball", 3.0, 2.6, 3.2, 0, 3.0, 5.3, "body", nil, nil, nil, "Head"),
	pd_("Ball", 1.4, 1.0, 1.3, 0, 2.7, 6.6, "body"),
	pd_("Wedge", 2.2, 0.4, 0.8, 0, 4.15, 5.6, "dark", { 90, 0, 0 }),
	pd_("Ball", 0.5, 0.5, 0.5, -0.75, 3.3, 6.75, C(242, 201, 76)),
	pd_("Ball", 0.5, 0.5, 0.5, 0.75, 3.3, 6.75, C(242, 201, 76)),
	pd_("Wedge", 0.4, 1.4, 0.3, -1.3, 3.9, 4.9, "body", { 0, 0, 20 }),
	pd_("Wedge", 0.4, 1.4, 0.3, 0, 4.05, 4.8, "body"),
	pd_("Wedge", 0.4, 1.4, 0.3, 1.3, 3.9, 4.9, "body", { 0, 0, -20 }),
	pd_("Ball", 3.4, 0.7, 2.6, -3.6, 1.3, 2.2, "body"),
	pd_("Ball", 3.4, 0.7, 2.6, 3.6, 1.3, 2.2, "body"),
	pd_("Ball", 2.4, 0.7, 2.2, -3.4, 1.2, -2.2, "body"),
	pd_("Ball", 2.4, 0.7, 2.2, 3.4, 1.2, -2.2, "body"),
	pd_("Wedge", 0.8, 0.6, 1.6, 0, 1.8, -3.9, "body", { 180, 0, 0 }),
	pd_("Ball", 0.6, 0.6, 0.6, -3.9, 2.2, 3.4, C(200, 235, 245), nil, nil, 0.4),
	pd_("Ball", 0.6, 0.6, 0.6, 3.9, 2.2, 3.3, C(200, 235, 245), nil, nil, 0.4),
	pd_("Ball", 0.6, 0.6, 0.6, -4.1, 2.0, -3.2, C(200, 235, 245), nil, nil, 0.4),
	pd_("Ball", 0.6, 0.6, 0.6, 4.1, 2.0, -3.1, C(200, 235, 245), nil, nil, 0.4),
}

PetDesigns.Leafpup = {
	pd_("Ball", 1.9, 1.7, 2.4, 0, 1.05, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.8, 1.6, 1.7, 0, 2.0, 0.6, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.9, 0.7, 1.0, 0, 1.8, 1.3, C(243, 240, 207)),
	pd_("Ball", 0.25, 0.25, 0.25, 0, 1.95, 1.75, C(60, 45, 45)),
	pd_("Ball", 0.32, 0.32, 0.32, -0.4, 2.15, 1.35, C(43, 43, 43)),
	pd_("Ball", 0.32, 0.32, 0.32, 0.4, 2.15, 1.35, C(43, 43, 43)),
	pd_("Wedge", 0.7, 1.0, 0.35, -0.55, 2.95, 0.45, "body", { -10, 0, 8 }),
	pd_("Wedge", 0.7, 1.0, 0.35, 0.55, 2.95, 0.45, "body", { -10, 0, -8 }),
	pd_("Wedge", 0.5, 1.2, 0.15, 0, 3.15, 0.55, C(79, 158, 72), { -15, 0, 0 }),
	pd_("Wedge", 0.5, 1.1, 0.15, -0.3, 3.05, 0.5, C(79, 158, 72), { -15, 0, 18 }),
	pd_("Wedge", 0.5, 1.1, 0.15, 0.3, 3.05, 0.5, C(79, 158, 72), { -15, 0, -18 }),
	pd_("Ball", 1.0, 0.8, 0.7, 0, 1.4, 0.95, C(243, 240, 207)),
	pd_("Ball", 0.65, 0.65, 0.65, -0.6, 0.33, 0.8, C(122, 91, 58)),
	pd_("Ball", 0.65, 0.65, 0.65, 0.6, 0.33, 0.8, C(122, 91, 58)),
	pd_("Ball", 0.65, 0.65, 0.65, -0.6, 0.33, -0.8, C(122, 91, 58)),
	pd_("Ball", 0.65, 0.65, 0.65, 0.6, 0.33, -0.8, C(122, 91, 58)),
	pd_("Ball", 1.0, 1.0, 1.0, 0, 1.25, -1.45, "body"),
	pd_("Ball", 0.8, 0.8, 0.8, 0, 1.6, -1.8, "body"),
	pd_("Ball", 0.55, 0.55, 0.55, 0, 1.9, -2.05, "body"),
	pd_("Wedge", 0.5, 0.9, 0.15, 0, 2.25, -2.2, C(79, 158, 72), { -25, 0, 0 }),
}
PetDesigns.Florawolf = {
	pd_("Ball", 2.0, 1.8, 2.6, 0, 1.15, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.9, 1.7, 1.8, 0, 2.2, 0.65, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.95, 0.75, 1.05, 0, 2.0, 1.4, C(243, 240, 207)),
	pd_("Ball", 0.26, 0.26, 0.26, 0, 2.15, 1.88, C(60, 45, 45)),
	pd_("Ball", 0.34, 0.34, 0.34, -0.42, 2.35, 1.45, C(43, 43, 43)),
	pd_("Ball", 0.34, 0.34, 0.34, 0.42, 2.35, 1.45, C(43, 43, 43)),
	pd_("Wedge", 0.75, 1.1, 0.35, -0.6, 3.2, 0.5, "body", { -10, 0, 8 }),
	pd_("Wedge", 0.75, 1.1, 0.35, 0.6, 3.2, 0.5, "body", { -10, 0, -8 }),
	pd_("Wedge", 0.5, 1.3, 0.15, 0, 3.45, 0.6, C(79, 158, 72), { -15, 0, 0 }),
	pd_("Wedge", 0.5, 1.2, 0.15, -0.32, 3.35, 0.55, C(79, 158, 72), { -15, 0, 18 }),
	pd_("Wedge", 0.5, 1.2, 0.15, 0.32, 3.35, 0.55, C(79, 158, 72), { -15, 0, -18 }),
	pd_("Wedge", 0.45, 1.1, 0.15, -0.6, 3.3, 0.5, C(101, 175, 90), { -15, 0, 32 }),
	pd_("Wedge", 0.45, 1.1, 0.15, 0.6, 3.3, 0.5, C(101, 175, 90), { -15, 0, -32 }),
	pd_("Ball", 0.35, 0.35, 0.35, -0.2, 3.55, 0.45, C(244, 169, 184)),
	pd_("Ball", 0.35, 0.35, 0.35, 0.25, 3.5, 0.4, C(244, 169, 184)),
	pd_("Wedge", 1.0, 1.1, 0.15, -0.95, 2.2, 0.3, C(79, 158, 72), { 0, 10, 20 }),
	pd_("Wedge", 1.0, 1.1, 0.15, 0.95, 2.2, 0.3, C(79, 158, 72), { 0, -10, -20 }),
	pd_("Wedge", 1.0, 1.1, 0.15, -0.95, 2.15, -0.6, C(101, 175, 90), { 0, 10, 20 }),
	pd_("Wedge", 1.0, 1.1, 0.15, 0.95, 2.15, -0.6, C(101, 175, 90), { 0, -10, -20 }),
	pd_("Ball", 1.05, 0.85, 0.75, 0, 1.55, 1.05, C(243, 240, 207)),
	pd_("Cylinder", 0.9, 0.6, 0.6, -0.62, 0.45, 0.85, C(122, 91, 58), { 0, 0, 90 }),
	pd_("Cylinder", 0.9, 0.6, 0.6, 0.62, 0.45, 0.85, C(122, 91, 58), { 0, 0, 90 }),
	pd_("Cylinder", 0.9, 0.6, 0.6, -0.62, 0.45, -0.85, C(122, 91, 58), { 0, 0, 90 }),
	pd_("Cylinder", 0.9, 0.6, 0.6, 0.62, 0.45, -0.85, C(122, 91, 58), { 0, 0, 90 }),
	pd_("Ball", 0.68, 0.68, 0.68, -0.62, 0.34, 0.9, C(122, 91, 58)),
	pd_("Ball", 0.68, 0.68, 0.68, 0.62, 0.34, 0.9, C(122, 91, 58)),
	pd_("Ball", 0.68, 0.68, 0.68, -0.62, 0.34, -0.8, C(122, 91, 58)),
	pd_("Ball", 0.68, 0.68, 0.68, 0.62, 0.34, -0.8, C(122, 91, 58)),
	pd_("Ball", 1.05, 1.05, 1.05, 0, 1.35, -1.6, "body"),
	pd_("Ball", 0.85, 0.85, 0.85, 0, 1.75, -1.95, "body"),
	pd_("Ball", 0.6, 0.6, 0.6, 0, 2.05, -2.2, "body"),
	pd_("Wedge", 0.5, 0.95, 0.15, 0, 2.4, -2.35, C(79, 158, 72), { -25, 0, 0 }),
	pd_("Wedge", 0.45, 0.85, 0.15, -0.25, 2.3, -2.3, C(101, 175, 90), { -25, 0, 15 }),
}
PetDesigns.Terragrowl = {
	pd_("Ball", 2.3, 2.0, 2.9, 0, 1.35, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 2.1, 1.9, 2.0, 0, 2.6, 0.75, "body", nil, nil, nil, "Head"),
	pd_("Ball", 1.05, 0.85, 1.15, 0, 2.35, 1.6, C(243, 240, 207)),
	pd_("Ball", 0.28, 0.28, 0.28, 0, 2.5, 2.1, C(60, 45, 45)),
	pd_("Ball", 0.36, 0.36, 0.36, -0.46, 2.75, 1.65, C(43, 43, 43)),
	pd_("Ball", 0.36, 0.36, 0.36, 0.46, 2.75, 1.65, C(43, 43, 43)),
	pd_("Wedge", 0.8, 1.2, 0.35, -0.65, 3.6, 0.55, "body", { -10, 0, 8 }),
	pd_("Wedge", 0.8, 1.2, 0.35, 0.65, 3.6, 0.55, "body", { -10, 0, -8 }),
	pd_("Wedge", 0.7, 1.8, 0.15, 0, 4.15, 0.85, C(79, 158, 72), { -12, 0, 0 }),
	pd_("Wedge", 0.65, 1.6, 0.15, -0.55, 4.05, 0.75, C(101, 175, 90), { -12, 0, 20 }),
	pd_("Wedge", 0.65, 1.6, 0.15, 0.55, 4.05, 0.75, C(101, 175, 90), { -12, 0, -20 }),
	pd_("Wedge", 0.6, 1.5, 0.15, -0.95, 3.9, 0.6, C(79, 158, 72), { -12, 0, 38 }),
	pd_("Wedge", 0.6, 1.5, 0.15, 0.95, 3.9, 0.6, C(79, 158, 72), { -12, 0, -38 }),
	pd_("Wedge", 0.55, 1.35, 0.15, -1.25, 3.65, 0.45, C(101, 175, 90), { -10, 0, 55 }),
	pd_("Wedge", 0.55, 1.35, 0.15, 1.25, 3.65, 0.45, C(101, 175, 90), { -10, 0, -55 }),
	pd_("Ball", 0.5, 0.5, 0.5, -0.35, 4.0, 0.35, C(244, 169, 184)),
	pd_("Ball", 0.5, 0.5, 0.5, 0.4, 4.1, 0.3, C(255, 213, 79)),
	pd_("Ball", 0.5, 0.5, 0.5, 0.05, 3.8, 0.15, C(244, 169, 184)),
	pd_("Cylinder", 1.6, 0.2, 0.2, -0.8, 4.35, 0.5, C(122, 91, 58), { 40, 0, 50 }),
	pd_("Cylinder", 1.6, 0.2, 0.2, 0.8, 4.35, 0.5, C(122, 91, 58), { 40, 0, -50 }),
	pd_("Wedge", 0.5, 0.8, 0.12, -1.15, 4.6, 0.35, C(79, 158, 72), { 0, 0, 30 }),
	pd_("Wedge", 0.5, 0.8, 0.12, 1.15, 4.6, 0.35, C(79, 158, 72), { 0, 0, -30 }),
	pd_("Ball", 2.4, 0.9, 3.0, 0, 2.6, -0.3, C(111, 160, 85)),
	pd_("Ball", 0.4, 0.4, 0.4, -0.7, 3.1, 0.3, C(244, 169, 184)),
	pd_("Ball", 0.4, 0.4, 0.4, 0.6, 3.15, -0.6, C(255, 213, 79)),
	pd_("Ball", 0.4, 0.4, 0.4, 0, 3.05, -1.0, C(244, 169, 184)),
	pd_("Wedge", 0.9, 0.6, 1.0, 0, 2.75, 0.5, C(138, 124, 106), { 90, 0, 0 }),
	pd_("Wedge", 0.9, 0.6, 1.0, 0, 2.8, -0.5, C(138, 124, 106), { 90, 0, 0 }),
	pd_("Wedge", 0.9, 0.6, 1.0, 0, 2.7, -1.4, C(138, 124, 106), { 90, 0, 0 }),
	pd_("Ball", 0.5, 0.5, 0.5, 0, 1.85, 1.35, C(120, 255, 140), nil, "Neon"),
	pd_("Ball", 1.15, 0.9, 0.8, 0, 1.75, 1.2, C(243, 240, 207)),
	pd_("Ball", 0.72, 0.72, 0.72, -0.68, 0.36, 0.95, C(122, 91, 58)),
	pd_("Ball", 0.72, 0.72, 0.72, 0.68, 0.36, 0.95, C(122, 91, 58)),
	pd_("Ball", 0.72, 0.72, 0.72, -0.68, 0.36, -0.95, C(122, 91, 58)),
	pd_("Ball", 0.72, 0.72, 0.72, 0.68, 0.36, -0.95, C(122, 91, 58)),
	pd_("Wedge", 0.15, 0.35, 0.15, -0.85, 0.18, 1.35, C(230, 225, 200), { 90, 0, 0 }),
	pd_("Wedge", 0.15, 0.35, 0.15, -0.6, 0.18, 1.4, C(230, 225, 200), { 90, 0, 0 }),
	pd_("Wedge", 0.15, 0.35, 0.15, -0.35, 0.18, 1.42, C(230, 225, 200), { 90, 0, 0 }),
	pd_("Wedge", 0.15, 0.35, 0.15, 0.85, 0.18, 1.35, C(230, 225, 200), { 90, 0, 0 }),
	pd_("Wedge", 0.15, 0.35, 0.15, 0.6, 0.18, 1.4, C(230, 225, 200), { 90, 0, 0 }),
	pd_("Wedge", 0.15, 0.35, 0.15, 0.35, 0.18, 1.42, C(230, 225, 200), { 90, 0, 0 }),
	pd_("Ball", 1.1, 1.1, 1.1, 0, 1.55, -1.85, "body"),
	pd_("Ball", 0.9, 0.9, 0.9, 0, 1.95, -2.2, "body"),
	pd_("Ball", 0.62, 0.62, 0.62, 0, 2.3, -2.5, "body"),
	pd_("Wedge", 0.55, 1.0, 0.15, 0, 2.65, -2.6, C(79, 158, 72), { -25, 0, 0 }),
}
PetDesigns.Cindercub = {
	pd_("Ball", 1.9, 1.6, 2.3, 0, 1.0, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.8, 1.6, 1.6, 0, 2.0, 0.55, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.7, 0.7, 0.7, -0.62, 2.15, 0.15, C(232, 85, 44)),
	pd_("Ball", 0.7, 0.7, 0.7, 0.62, 2.15, 0.15, C(232, 85, 44)),
	pd_("Ball", 0.7, 0.7, 0.7, -0.7, 1.85, 0.45, C(232, 85, 44)),
	pd_("Ball", 0.7, 0.7, 0.7, 0.7, 1.85, 0.45, C(232, 85, 44)),
	pd_("Ball", 0.7, 0.7, 0.7, -0.55, 1.8, -0.2, C(232, 85, 44)),
	pd_("Ball", 0.7, 0.7, 0.7, 0.55, 1.8, -0.2, C(232, 85, 44)),
	pd_("Wedge", 0.4, 0.9, 0.15, 0, 2.95, 0.35, C(255, 210, 90), { -10, 0, 0 }, "Neon"),
	pd_("Wedge", 0.4, 0.8, 0.15, -0.3, 2.85, 0.3, C(255, 170, 60), { -10, 0, 16 }),
	pd_("Wedge", 0.4, 0.8, 0.15, 0.3, 2.85, 0.3, C(255, 170, 60), { -10, 0, -16 }),
	pd_("Wedge", 0.35, 0.7, 0.15, 0, 2.8, 0.05, C(232, 85, 44), { -15, 0, 0 }),
	pd_("Ball", 0.9, 0.65, 0.9, 0, 1.8, 1.25, C(255, 240, 208)),
	pd_("Ball", 0.28, 0.28, 0.28, 0, 1.95, 1.65, C(63, 51, 46)),
	pd_("Ball", 0.32, 0.32, 0.32, -0.4, 2.15, 1.25, C(43, 43, 43)),
	pd_("Ball", 0.32, 0.32, 0.32, 0.4, 2.15, 1.25, C(43, 43, 43)),
	pd_("Ball", 0.5, 0.5, 0.5, -0.5, 2.75, 0.5, "body"),
	pd_("Ball", 0.5, 0.5, 0.5, 0.5, 2.75, 0.5, "body"),
	pd_("Ball", 1.1, 0.9, 0.7, 0, 1.35, 0.95, C(255, 240, 208)),
	pd_("Ball", 0.65, 0.65, 0.65, -0.6, 0.33, 0.8, "body"),
	pd_("Ball", 0.65, 0.65, 0.65, 0.6, 0.33, 0.8, "body"),
	pd_("Ball", 0.65, 0.65, 0.65, -0.6, 0.33, -0.8, "body"),
	pd_("Ball", 0.65, 0.65, 0.65, 0.6, 0.33, -0.8, "body"),
	pd_("Ball", 0.45, 0.45, 0.45, 0, 1.15, -1.35, "body"),
	pd_("Ball", 0.35, 0.35, 0.35, 0, 1.35, -1.6, "body"),
	pd_("Ball", 0.3, 0.3, 0.3, 0, 1.52, -1.8, "body"),
	pd_("Wedge", 0.5, 0.9, 0.15, 0, 1.85, -1.9, C(255, 210, 90), { -25, 0, 0 }, "Neon"),
	pd_("Wedge", 0.45, 0.8, 0.15, 0.2, 1.75, -1.95, C(255, 170, 60), { -25, 0, -15 }),
}
PetDesigns.Flamane = {
	pd_("Ball", 2.0, 1.7, 2.5, 0, 1.1, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.9, 1.7, 1.7, 0, 2.2, 0.6, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.8, 0.8, 0.8, -0.7, 2.5, 0.2, C(232, 85, 44)),
	pd_("Ball", 0.8, 0.8, 0.8, 0.7, 2.5, 0.2, C(232, 85, 44)),
	pd_("Ball", 0.8, 0.8, 0.8, -0.82, 2.2, 0.5, C(232, 85, 44)),
	pd_("Ball", 0.8, 0.8, 0.8, 0.82, 2.2, 0.5, C(232, 85, 44)),
	pd_("Ball", 0.8, 0.8, 0.8, -0.8, 1.95, 0.1, C(232, 85, 44)),
	pd_("Ball", 0.8, 0.8, 0.8, 0.8, 1.95, 0.1, C(232, 85, 44)),
	pd_("Ball", 0.85, 0.85, 0.85, -0.6, 2.35, -0.35, C(255, 170, 60)),
	pd_("Ball", 0.85, 0.85, 0.85, 0.6, 2.35, -0.35, C(255, 170, 60)),
	pd_("Ball", 0.85, 0.85, 0.85, -0.5, 2.05, -0.55, C(255, 170, 60)),
	pd_("Ball", 0.85, 0.85, 0.85, 0.5, 2.05, -0.55, C(255, 170, 60)),
	pd_("Ball", 0.8, 0.8, 0.8, 0, 2.6, -0.3, C(232, 85, 44)),
	pd_("Ball", 0.8, 0.8, 0.8, 0, 2.2, -0.7, C(255, 170, 60)),
	pd_("Wedge", 0.5, 1.3, 0.15, 0, 3.4, 0.45, C(255, 210, 90), { -10, 0, 0 }, "Neon"),
	pd_("Wedge", 0.5, 1.2, 0.15, -0.35, 3.3, 0.4, C(255, 170, 60), { -10, 0, 16 }),
	pd_("Wedge", 0.5, 1.2, 0.15, 0.35, 3.3, 0.4, C(255, 170, 60), { -10, 0, -16 }),
	pd_("Wedge", 0.45, 1.1, 0.15, -0.65, 3.15, 0.3, C(232, 85, 44), { -12, 0, 30 }),
	pd_("Wedge", 0.45, 1.1, 0.15, 0.65, 3.15, 0.3, C(232, 85, 44), { -12, 0, -30 }),
	pd_("Wedge", 0.45, 1.0, 0.15, 0, 3.25, 0.05, C(255, 210, 90), { -18, 0, 0 }, "Neon"),
	pd_("Ball", 0.95, 0.7, 0.95, 0, 2.0, 1.35, C(255, 240, 208)),
	pd_("Ball", 0.3, 0.3, 0.3, 0, 2.15, 1.78, C(63, 51, 46)),
	pd_("Ball", 0.34, 0.34, 0.34, -0.42, 2.35, 1.35, C(43, 43, 43)),
	pd_("Ball", 0.34, 0.34, 0.34, 0.42, 2.35, 1.35, C(43, 43, 43)),
	pd_("Ball", 0.52, 0.52, 0.52, -0.52, 3.0, 0.55, "body"),
	pd_("Ball", 0.52, 0.52, 0.52, 0.52, 3.0, 0.55, "body"),
	pd_("Ball", 1.15, 0.95, 0.75, 0, 1.5, 1.05, C(255, 240, 208)),
	pd_("Cylinder", 0.3, 0.62, 0.62, -0.62, 0.55, 0.85, C(63, 51, 46), { 0, 0, 90 }),
	pd_("Cylinder", 0.3, 0.62, 0.62, 0.62, 0.55, 0.85, C(63, 51, 46), { 0, 0, 90 }),
	pd_("Cylinder", 0.3, 0.62, 0.62, -0.62, 0.55, -0.85, C(63, 51, 46), { 0, 0, 90 }),
	pd_("Cylinder", 0.3, 0.62, 0.62, 0.62, 0.55, -0.85, C(63, 51, 46), { 0, 0, 90 }),
	pd_("Ball", 0.68, 0.68, 0.68, -0.62, 0.34, 0.88, "body"),
	pd_("Ball", 0.68, 0.68, 0.68, 0.62, 0.34, 0.88, "body"),
	pd_("Ball", 0.68, 0.68, 0.68, -0.62, 0.34, -0.82, "body"),
	pd_("Ball", 0.68, 0.68, 0.68, 0.62, 0.34, -0.82, "body"),
	pd_("Ball", 0.5, 0.5, 0.5, 0, 1.3, -1.5, "body"),
	pd_("Ball", 0.4, 0.4, 0.4, 0, 1.55, -1.8, "body"),
	pd_("Ball", 0.32, 0.32, 0.32, 0, 1.75, -2.02, "body"),
	pd_("Wedge", 0.5, 1.0, 0.15, 0, 2.1, -2.1, C(255, 210, 90), { -25, 0, 0 }, "Neon"),
	pd_("Wedge", 0.45, 0.9, 0.15, 0.22, 2.0, -2.15, C(255, 170, 60), { -25, 0, -15 }),
	pd_("Wedge", 0.45, 0.85, 0.15, -0.22, 1.98, -2.12, C(232, 85, 44), { -25, 0, 15 }),
}
PetDesigns.Infernoar = {
	pd_("Ball", 2.3, 1.9, 2.8, 0, 1.3, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 2.1, 1.9, 1.9, 0, 2.6, 0.7, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.9, 0.9, 0.9, -0.78, 2.95, 0.25, C(232, 85, 44)),
	pd_("Ball", 0.9, 0.9, 0.9, 0.78, 2.95, 0.25, C(232, 85, 44)),
	pd_("Ball", 0.9, 0.9, 0.9, -0.92, 2.6, 0.6, C(232, 85, 44)),
	pd_("Ball", 0.9, 0.9, 0.9, 0.92, 2.6, 0.6, C(232, 85, 44)),
	pd_("Ball", 0.9, 0.9, 0.9, -0.9, 2.3, 0.15, C(232, 85, 44)),
	pd_("Ball", 0.9, 0.9, 0.9, 0.9, 2.3, 0.15, C(232, 85, 44)),
	pd_("Ball", 0.95, 0.95, 0.95, -0.68, 2.8, -0.4, C(255, 170, 60)),
	pd_("Ball", 0.95, 0.95, 0.95, 0.68, 2.8, -0.4, C(255, 170, 60)),
	pd_("Ball", 0.95, 0.95, 0.95, -0.58, 2.45, -0.65, C(255, 170, 60)),
	pd_("Ball", 0.95, 0.95, 0.95, 0.58, 2.45, -0.65, C(255, 170, 60)),
	pd_("Ball", 0.9, 0.9, 0.9, 0, 3.05, -0.35, C(232, 85, 44)),
	pd_("Ball", 0.9, 0.9, 0.9, 0, 2.65, -0.8, C(255, 170, 60)),
	pd_("Wedge", 0.8, 2.2, 0.15, 0, 4.3, 0.5, C(255, 210, 90), { -8, 0, 0 }, "Neon"),
	pd_("Wedge", 0.7, 2.0, 0.15, -0.45, 4.15, 0.45, C(255, 170, 60), { -8, 0, 14 }),
	pd_("Wedge", 0.7, 2.0, 0.15, 0.45, 4.15, 0.45, C(255, 170, 60), { -8, 0, -14 }),
	pd_("Wedge", 0.65, 1.8, 0.15, -0.85, 3.95, 0.35, C(232, 85, 44), { -10, 0, 28 }),
	pd_("Wedge", 0.65, 1.8, 0.15, 0.85, 3.95, 0.35, C(232, 85, 44), { -10, 0, -28 }),
	pd_("Wedge", 0.6, 1.6, 0.15, -1.15, 3.7, 0.25, C(255, 170, 60), { -10, 0, 42 }),
	pd_("Wedge", 0.6, 1.6, 0.15, 1.15, 3.7, 0.25, C(255, 170, 60), { -10, 0, -42 }),
	pd_("Wedge", 0.55, 1.5, 0.15, 0, 4.05, 0.05, C(255, 210, 90), { -16, 0, 0 }, "Neon"),
	pd_("Wedge", 0.5, 1.0, 0.2, 0, 3.85, 1.0, C(255, 210, 90), { -20, 0, 0 }, "Neon"),
	pd_("Ball", 1.05, 0.8, 1.05, 0, 2.35, 1.55, C(255, 240, 208)),
	pd_("Ball", 0.32, 0.32, 0.32, 0, 2.52, 2.02, C(63, 51, 46)),
	pd_("Ball", 0.38, 0.38, 0.38, -0.48, 2.75, 1.55, C(43, 43, 43)),
	pd_("Ball", 0.38, 0.38, 0.38, 0.48, 2.75, 1.55, C(43, 43, 43)),
	pd_("Ball", 0.55, 0.55, 0.55, -0.55, 3.45, 0.6, "body"),
	pd_("Ball", 0.55, 0.55, 0.55, 0.55, 3.45, 0.6, "body"),
	pd_("Ball", 1.25, 1.05, 0.85, 0, 1.8, 1.2, C(255, 240, 208)),
	pd_("Ball", 0.75, 0.75, 0.75, -0.7, 0.38, 1.0, "body"),
	pd_("Ball", 0.75, 0.75, 0.75, 0.7, 0.38, 1.0, "body"),
	pd_("Ball", 0.75, 0.75, 0.75, -0.7, 0.38, -1.0, "body"),
	pd_("Ball", 0.75, 0.75, 0.75, 0.7, 0.38, -1.0, "body"),
	pd_("Wedge", 0.3, 0.7, 0.12, -0.85, 1.35, 1.35, C(255, 210, 90), { 0, 0, 0 }, "Neon"),
	pd_("Wedge", 0.3, 0.7, 0.12, 0.85, 1.35, 1.35, C(255, 210, 90), { 0, 0, 0 }, "Neon"),
	pd_("Wedge", 0.3, 0.7, 0.12, -0.85, 1.35, -1.35, C(255, 210, 90), { 0, 0, 0 }, "Neon"),
	pd_("Wedge", 0.3, 0.7, 0.12, 0.85, 1.35, -1.35, C(255, 210, 90), { 0, 0, 0 }, "Neon"),
	pd_("Ball", 0.55, 0.55, 0.55, 0, 1.5, -1.75, "body"),
	pd_("Ball", 0.45, 0.45, 0.45, 0, 1.8, -2.05, "body"),
	pd_("Ball", 0.36, 0.36, 0.36, 0, 2.02, -2.3, "body"),
	pd_("Wedge", 0.55, 1.1, 0.15, 0, 2.4, -2.4, C(255, 210, 90), { -25, 0, 0 }, "Neon"),
	pd_("Wedge", 0.5, 1.0, 0.15, 0.25, 2.3, -2.45, C(255, 170, 60), { -25, 0, -15 }),
	pd_("Wedge", 0.5, 0.95, 0.15, -0.25, 2.28, -2.42, C(232, 85, 44), { -25, 0, 15 }),
	pd_("Wedge", 0.45, 0.85, 0.15, 0, 2.15, -2.5, C(255, 210, 90), { -30, 0, 0 }, "Neon"),
	pd_("Ball", 0.25, 0.25, 0.25, -1.5, 3.3, 0.9, C(255, 150, 50), nil, "Neon"),
	pd_("Ball", 0.25, 0.25, 0.25, 1.5, 3.5, 0.7, C(255, 150, 50), nil, "Neon"),
	pd_("Ball", 0.25, 0.25, 0.25, -1.6, 2.9, -0.3, C(255, 180, 60), nil, "Neon"),
	pd_("Ball", 0.25, 0.25, 0.25, 1.6, 3.0, -0.5, C(255, 180, 60), nil, "Neon"),
	pd_("Ball", 0.25, 0.25, 0.25, -1.3, 3.8, 0.2, C(255, 150, 50), nil, "Neon"),
	pd_("Ball", 0.25, 0.25, 0.25, 1.3, 3.9, 0.1, C(255, 180, 60), nil, "Neon"),
}

PetDesigns.Bubblin = {
	pd_("Ball", 1.8, 1.6, 1.9, 0, 1.0, 0.3, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.2, 1.1, 1.6, 0, 0.95, -1.0, "body"),
	pd_("Ball", 1.2, 0.8, 2.0, 0, 0.8, 0.1, C(242, 250, 255)),
	pd_("Ball", 1.9, 1.6, 1.8, 0, 1.5, 1.35, "body", nil, nil, nil, "Head"),
	pd_("Ball", 1.0, 0.7, 0.9, 0, 1.3, 2.1, "body"),
	pd_("Ball", 0.42, 0.42, 0.42, -0.45, 1.65, 2.1, C(255, 255, 255)),
	pd_("Ball", 0.42, 0.42, 0.42, 0.45, 1.65, 2.1, C(255, 255, 255)),
	pd_("Ball", 0.22, 0.22, 0.22, -0.45, 1.63, 2.28, C(30, 40, 60)),
	pd_("Ball", 0.22, 0.22, 0.22, 0.45, 1.63, 2.28, C(30, 40, 60)),
	pd_("Wedge", 0.2, 1.3, 1.2, 0, 2.2, 0.6, "dark", { -10, 0, 0 }),
	pd_("Wedge", 1.0, 0.15, 0.8, -1.0, 1.1, 0.6, "dark", { 0, 20, -15 }),
	pd_("Wedge", 1.0, 0.15, 0.8, 1.0, 1.1, 0.6, "dark", { 0, -20, 15 }),
	pd_("Cylinder", 0.9, 0.5, 0.5, 0, 1.1, -1.9, "body", { 90, 0, 0 }),
	pd_("Wedge", 0.2, 1.1, 0.9, 0, 1.85, -2.3, "dark", { -15, 0, 0 }),
	pd_("Wedge", 0.2, 0.8, 0.7, 0, 0.75, -2.3, "dark", { 160, 0, 0 }),
	pd_("Wedge", 0.05, 0.35, 0.05, -0.85, 1.5, 1.6, C(31, 74, 122), { 90, 0, 0 }),
	pd_("Wedge", 0.05, 0.35, 0.05, 0.85, 1.5, 1.6, C(31, 74, 122), { 90, 0, 0 }),
	pd_("Wedge", 0.05, 0.35, 0.05, -0.88, 1.35, 1.5, C(31, 74, 122), { 90, 0, 0 }),
	pd_("Wedge", 0.05, 0.35, 0.05, 0.88, 1.35, 1.5, C(31, 74, 122), { 90, 0, 0 }),
	pd_("Ball", 0.55, 0.55, 0.55, -0.6, 0.3, 0.9, "dark"),
	pd_("Ball", 0.55, 0.55, 0.55, 0.6, 0.3, 0.9, "dark"),
	pd_("Ball", 0.55, 0.55, 0.55, -0.55, 0.3, -0.7, "dark"),
	pd_("Ball", 0.55, 0.55, 0.55, 0.55, 0.3, -0.7, "dark"),
	pd_("Ball", 0.3, 0.3, 0.3, -0.75, 1.35, 1.9, C(180, 225, 250), nil, nil, 0.4),
	pd_("Ball", 0.3, 0.3, 0.3, 0.75, 1.3, 1.95, C(180, 225, 250), nil, nil, 0.4),
}
PetDesigns.Riptide = {
	pd_("Ball", 1.9, 1.7, 2.1, 0, 1.1, 0.3, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.3, 1.2, 1.8, 0, 1.05, -1.1, "body"),
	pd_("Ball", 1.3, 0.9, 2.2, 0, 0.9, 0.1, C(242, 250, 255)),
	pd_("Ball", 2.0, 1.7, 1.9, 0, 1.65, 1.5, "body", nil, nil, nil, "Head"),
	pd_("Ball", 1.05, 0.75, 0.95, 0, 1.45, 2.3, "body"),
	pd_("Ball", 0.44, 0.44, 0.44, -0.48, 1.8, 2.3, C(255, 255, 255)),
	pd_("Ball", 0.44, 0.44, 0.44, 0.48, 1.8, 2.3, C(255, 255, 255)),
	pd_("Ball", 0.23, 0.23, 0.23, -0.48, 1.78, 2.5, C(30, 40, 60)),
	pd_("Ball", 0.23, 0.23, 0.23, 0.48, 1.78, 2.5, C(30, 40, 60)),
	pd_("Wedge", 0.2, 1.8, 1.5, 0, 2.6, 0.6, "dark", { -10, 0, 0 }),
	pd_("Wedge", 0.2, 1.0, 0.9, 0, 2.35, -0.5, "dark", { -15, 0, 0 }),
	pd_("Wedge", 1.4, 0.15, 1.1, -1.15, 1.2, 0.65, "dark", { 0, 20, -15 }),
	pd_("Wedge", 1.4, 0.15, 1.1, 1.15, 1.2, 0.65, "dark", { 0, -20, 15 }),
	pd_("Wedge", 0.05, 0.4, 1.2, -0.98, 1.35, 0.2, C(31, 74, 122), { 90, 0, 0 }),
	pd_("Wedge", 0.05, 0.4, 1.2, 0.98, 1.35, 0.2, C(31, 74, 122), { 90, 0, 0 }),
	pd_("Cylinder", 1.0, 0.55, 0.55, 0, 1.2, -2.2, "body", { 90, 0, 0 }),
	pd_("Wedge", 0.2, 1.3, 1.1, 0, 2.05, -2.7, "dark", { -15, 0, 0 }),
	pd_("Wedge", 0.2, 1.0, 0.85, 0, 0.8, -2.7, "dark", { 160, 0, 0 }),
	pd_("Wedge", 0.2, 0.8, 0.7, 0, 1.45, -2.85, "dark", { 90, 0, 0 }),
	pd_("Wedge", 0.15, 0.25, 0.12, -0.3, 1.05, 2.62, C(255, 255, 255), { 180, 0, 0 }),
	pd_("Wedge", 0.15, 0.25, 0.12, -0.1, 1.02, 2.68, C(255, 255, 255), { 180, 0, 0 }),
	pd_("Wedge", 0.15, 0.25, 0.12, 0.12, 1.02, 2.68, C(255, 255, 255), { 180, 0, 0 }),
	pd_("Wedge", 0.15, 0.25, 0.12, 0.32, 1.05, 2.62, C(255, 255, 255), { 180, 0, 0 }),
	pd_("Ball", 0.58, 0.58, 0.58, -0.65, 0.32, 1.0, "dark"),
	pd_("Ball", 0.58, 0.58, 0.58, 0.65, 0.32, 1.0, "dark"),
	pd_("Ball", 0.58, 0.58, 0.58, -0.6, 0.32, -0.8, "dark"),
	pd_("Ball", 0.58, 0.58, 0.58, 0.6, 0.32, -0.8, "dark"),
}
PetDesigns.Abyssjaw = {
	pd_("Ball", 2.2, 2.0, 2.5, 0, 1.3, 0.3, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.5, 1.4, 2.0, 0, 1.25, -1.3, "body"),
	pd_("Ball", 1.5, 1.0, 2.6, 0, 1.05, 0.1, C(205, 232, 245)),
	pd_("Ball", 2.3, 1.9, 2.1, 0, 1.95, 1.7, "body", nil, nil, nil, "Head"),
	pd_("Ball", 1.2, 0.85, 1.1, 0, 1.75, 2.6, "body"),
	pd_("Wedge", 1.5, 0.5, 1.4, 0, 1.15, 2.45, "dark", { 8, 0, 0 }),
	pd_("Wedge", 0.2, 0.35, 0.2, -0.45, 0.95, 2.9, C(255, 255, 255), { 180, 0, 0 }),
	pd_("Wedge", 0.2, 0.35, 0.2, -0.15, 0.92, 3.0, C(255, 255, 255), { 180, 0, 0 }),
	pd_("Wedge", 0.2, 0.35, 0.2, 0.15, 0.92, 3.0, C(255, 255, 255), { 180, 0, 0 }),
	pd_("Wedge", 0.2, 0.35, 0.2, 0.45, 0.95, 2.9, C(255, 255, 255), { 180, 0, 0 }),
	pd_("Wedge", 0.2, 0.3, 0.2, -0.3, 1.5, 2.95, C(255, 255, 255)),
	pd_("Wedge", 0.2, 0.3, 0.2, 0.3, 1.5, 2.95, C(255, 255, 255)),
	pd_("Ball", 0.48, 0.48, 0.48, -0.55, 2.15, 2.55, C(255, 255, 255)),
	pd_("Ball", 0.48, 0.48, 0.48, 0.55, 2.15, 2.55, C(255, 255, 255)),
	pd_("Ball", 0.25, 0.25, 0.25, -0.55, 2.13, 2.78, C(20, 30, 55)),
	pd_("Ball", 0.25, 0.25, 0.25, 0.55, 2.13, 2.78, C(20, 30, 55)),
	pd_("Wedge", 0.22, 1.8, 1.5, 0, 3.1, 0.7, "dark", { -10, 0, 0 }),
	pd_("Wedge", 0.22, 1.4, 1.2, 0, 2.9, -0.4, "dark", { -12, 0, 0 }),
	pd_("Wedge", 0.22, 1.0, 0.9, 0, 2.65, -1.4, "dark", { -15, 0, 0 }),
	pd_("Wedge", 1.5, 0.18, 1.2, -1.3, 1.45, 0.7, "dark", { 0, 20, -15 }),
	pd_("Wedge", 1.5, 0.18, 1.2, 1.3, 1.45, 0.7, "dark", { 0, -20, 15 }),
	pd_("Wedge", 0.2, 0.7, 0.3, -1.15, 1.8, 0.2, "dark", { 0, 0, 25 }),
	pd_("Wedge", 0.2, 0.7, 0.3, 1.15, 1.8, 0.2, "dark", { 0, 0, -25 }),
	pd_("Wedge", 0.2, 0.7, 0.3, -1.2, 1.7, -0.9, "dark", { 0, 0, 25 }),
	pd_("Wedge", 0.2, 0.7, 0.3, 1.2, 1.7, -0.9, "dark", { 0, 0, -25 }),
	pd_("Ball", 0.5, 0.5, 0.5, 0, 1.5, 1.45, C(120, 230, 255), nil, "Neon"),
	pd_("Ball", 0.2, 0.2, 0.2, -1.05, 1.35, 1.3, C(120, 230, 255), nil, "Neon"),
	pd_("Ball", 0.2, 0.2, 0.2, 1.05, 1.35, 1.3, C(120, 230, 255), nil, "Neon"),
	pd_("Ball", 0.2, 0.2, 0.2, -1.12, 1.25, 0.5, C(120, 230, 255), nil, "Neon"),
	pd_("Ball", 0.2, 0.2, 0.2, 1.12, 1.25, 0.5, C(120, 230, 255), nil, "Neon"),
	pd_("Ball", 0.2, 0.2, 0.2, -1.15, 1.15, -0.3, C(120, 230, 255), nil, "Neon"),
	pd_("Ball", 0.2, 0.2, 0.2, 1.15, 1.15, -0.3, C(120, 230, 255), nil, "Neon"),
	pd_("Cylinder", 1.1, 0.6, 0.6, 0, 1.4, -2.6, "body", { 90, 0, 0 }),
	pd_("Wedge", 0.22, 2.0, 1.2, 0, 2.5, -3.3, "dark", { -8, 0, 0 }),
	pd_("Wedge", 0.22, 1.7, 1.0, 0, 2.2, -3.7, "dark", { -4, 35, 0 }),
	pd_("Wedge", 0.22, 1.7, 1.0, 0, 2.2, -3.7, "dark", { -4, -35, 0 }),
	pd_("Wedge", 0.22, 1.3, 0.85, 0, 1.0, -3.3, "dark", { 165, 0, 0 }),
	pd_("Ball", 0.62, 0.62, 0.62, -0.72, 0.36, 1.1, "dark"),
	pd_("Ball", 0.62, 0.62, 0.62, 0.72, 0.36, 1.1, "dark"),
	pd_("Ball", 0.62, 0.62, 0.62, -0.68, 0.36, -0.9, "dark"),
	pd_("Ball", 0.62, 0.62, 0.62, 0.68, 0.36, -0.9, "dark"),
}

PetDesigns.Chick = {
	pd_("Ball", 1.6, 1.6, 1.6, 0, 0.95, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.2, 1.2, 1.2, 0, 1.95, 0.25, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.3, 0.35, 0.3, -0.25, 2.65, 0.2, C(232, 68, 58)),
	pd_("Ball", 0.35, 0.4, 0.35, 0, 2.7, 0.22, C(232, 68, 58)),
	pd_("Ball", 0.3, 0.35, 0.3, 0.25, 2.65, 0.2, C(232, 68, 58)),
	pd_("Wedge", 0.4, 0.3, 0.5, 0, 1.9, 0.9, C(245, 154, 47), { 90, 0, 0 }),
	pd_("Ball", 0.2, 0.25, 0.2, 0, 1.65, 0.82, C(232, 68, 58)),
	pd_("Ball", 0.22, 0.22, 0.22, -0.3, 2.05, 0.78, C(43, 43, 43)),
	pd_("Ball", 0.22, 0.22, 0.22, 0.3, 2.05, 0.78, C(43, 43, 43)),
	pd_("Ball", 0.3, 0.8, 1.0, -0.8, 1.1, -0.1, "light"),
	pd_("Ball", 0.3, 0.8, 1.0, 0.8, 1.1, -0.1, "light"),
	pd_("Wedge", 0.3, 0.6, 0.15, 0, 1.5, -0.85, "light", { -25, 0, 0 }),
	pd_("Wedge", 0.3, 0.55, 0.15, 0.18, 1.45, -0.85, "light", { -25, 0, -12 }),
	pd_("Ball", 0.5, 0.15, 0.7, -0.3, 0.1, 0.3, C(245, 154, 47)),
	pd_("Ball", 0.5, 0.15, 0.7, 0.3, 0.1, 0.3, C(245, 154, 47)),
}
PetDesigns.Bunny = {
	pd_("Ball", 1.7, 1.5, 1.9, 0, 0.95, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.4, 1.4, 1.4, 0, 1.95, 0.45, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.5, 1.3, 0.3, -0.38, 2.6, 0.25, "body", { 15, 0, 20 }),
	pd_("Ball", 0.5, 1.3, 0.3, 0.38, 2.6, 0.25, "body", { 15, 0, -20 }),
	pd_("Ball", 0.3, 0.9, 0.12, -0.38, 2.55, 0.45, C(244, 182, 194)),
	pd_("Ball", 0.3, 0.9, 0.12, 0.38, 2.55, 0.45, C(244, 182, 194)),
	pd_("Ball", 0.25, 0.25, 0.25, -0.32, 2.05, 1.05, C(43, 43, 43)),
	pd_("Ball", 0.25, 0.25, 0.25, 0.32, 2.05, 1.05, C(43, 43, 43)),
	pd_("Ball", 0.2, 0.2, 0.2, 0, 1.9, 1.12, C(244, 182, 194)),
	pd_("Ball", 0.45, 0.45, 0.45, -0.45, 0.4, 0.85, "body"),
	pd_("Ball", 0.45, 0.45, 0.45, 0.45, 0.4, 0.85, "body"),
	pd_("Ball", 0.6, 0.4, 0.9, -0.5, 0.22, -0.35, "body"),
	pd_("Ball", 0.6, 0.4, 0.9, 0.5, 0.22, -0.35, "body"),
	pd_("Ball", 0.7, 0.7, 0.7, 0, 1.15, -1.05, "light"),
	pd_("Ball", 0.4, 0.4, 0.4, -0.25, 1.35, -1.15, "light"),
	pd_("Ball", 0.4, 0.4, 0.4, 0.25, 1.3, -1.18, "light"),
}
PetDesigns.Voltpup = {
	pd_("Ball", 1.7, 1.5, 2.1, 0, 1.0, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.7, 1.5, 1.5, 0, 2.0, 0.5, "body", nil, nil, nil, "Head"),
	pd_("Wedge", 0.6, 1.3, 0.3, -0.55, 2.95, 0.35, "body", { -8, 0, 8 }),
	pd_("Wedge", 0.6, 1.3, 0.3, 0.55, 2.95, 0.35, "body", { -8, 0, -8 }),
	pd_("Wedge", 0.6, 0.4, 0.3, -0.55, 3.55, 0.3, C(43, 58, 103)),
	pd_("Wedge", 0.6, 0.4, 0.3, 0.55, 3.55, 0.3, C(43, 58, 103)),
	pd_("Ball", 0.3, 0.3, 0.3, -0.4, 2.1, 1.2, C(43, 43, 43)),
	pd_("Ball", 0.3, 0.3, 0.3, 0.4, 2.1, 1.2, C(43, 43, 43)),
	pd_("Ball", 0.22, 0.22, 0.22, 0, 1.95, 1.28, C(60, 45, 45)),
	pd_("Ball", 0.5, 0.5, 0.5, -0.78, 1.9, 1.05, C(127, 232, 255), nil, "Neon"),
	pd_("Ball", 0.5, 0.5, 0.5, 0.78, 1.9, 1.05, C(127, 232, 255), nil, "Neon"),
	pd_("Ball", 1.15, 0.85, 0.6, 0, 1.3, 0.95, C(255, 243, 194)),
	pd_("Ball", 0.55, 0.55, 0.55, -0.55, 0.3, 0.8, "body"),
	pd_("Ball", 0.55, 0.55, 0.55, 0.55, 0.3, 0.8, "body"),
	pd_("Ball", 0.55, 0.55, 0.55, -0.55, 0.3, -0.8, "body"),
	pd_("Ball", 0.55, 0.55, 0.55, 0.55, 0.3, -0.8, "body"),
	pd_("Wedge", 0.4, 1.0, 0.2, 0, 1.7, -1.25, C(255, 210, 63), { -30, 0, 0 }),
	pd_("Wedge", 0.4, 1.0, 0.2, 0, 2.15, -1.45, C(255, 210, 63), { 30, 0, 0 }),
	pd_("Wedge", 0.4, 1.0, 0.2, 0, 2.55, -1.3, C(43, 58, 103), { -30, 0, 0 }),
}
PetDesigns.Pinnipup = {
	pd_("Ball", 1.6, 1.4, 1.6, 0, 0.85, 0.5, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.6, 1.4, 1.6, 0, 0.85, -0.7, "body"),
	pd_("Ball", 1.2, 0.7, 2.0, 0, 0.6, 0, C(232, 244, 251)),
	pd_("Ball", 1.5, 1.4, 1.4, 0, 1.35, 1.45, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.8, 0.55, 0.7, 0, 1.15, 2.05, "light"),
	pd_("Ball", 0.3, 0.3, 0.3, 0, 1.32, 2.38, C(60, 50, 55)),
	pd_("Ball", 0.38, 0.38, 0.38, -0.36, 1.5, 2.05, C(43, 43, 43)),
	pd_("Ball", 0.38, 0.38, 0.38, 0.36, 1.5, 2.05, C(43, 43, 43)),
	pd_("Cylinder", 0.7, 0.04, 0.04, -0.55, 1.15, 2.3, C(255, 255, 255), { 0, 90, 0 }),
	pd_("Cylinder", 0.7, 0.04, 0.04, 0.55, 1.15, 2.3, C(255, 255, 255), { 0, 90, 0 }),
	pd_("Cylinder", 0.7, 0.04, 0.04, -0.58, 1.05, 2.25, C(255, 255, 255), { 0, 80, 0 }),
	pd_("Cylinder", 0.7, 0.04, 0.04, 0.58, 1.05, 2.25, C(255, 255, 255), { 0, 80, 0 }),
	pd_("Wedge", 1.0, 0.15, 0.8, -0.85, 0.75, 0.8, "dark", { 0, 20, -12 }),
	pd_("Wedge", 1.0, 0.15, 0.8, 0.85, 0.75, 0.8, "dark", { 0, -20, 12 }),
	pd_("Wedge", 0.9, 0.15, 0.7, -0.7, 0.6, -1.35, "dark", { 0, 30, -8 }),
	pd_("Wedge", 0.9, 0.15, 0.7, 0.7, 0.6, -1.35, "dark", { 0, -30, 8 }),
}
PetDesigns.Pebblor = {
	pd_("Ball", 2.0, 1.7, 2.0, 0, 1.0, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.5, 1.5, 1.5, 0, 1.6, 0.45, "body", nil, nil, nil, "Head"),
	pd_("Wedge", 1.2, 0.25, 0.4, 0, 2.15, 0.95, "dark", { 90, 0, 0 }),
	pd_("Ball", 0.3, 0.3, 0.3, -0.35, 1.8, 1.1, C(43, 43, 43)),
	pd_("Ball", 0.3, 0.3, 0.3, 0.35, 1.8, 1.1, C(43, 43, 43)),
	pd_("Ball", 0.35, 0.35, 0.35, 0, 2.45, 0.55, C(242, 179, 61)),
	pd_("Wedge", 0.5, 1.2, 0.5, 0, 2.2, -0.6, "dark", { -10, 0, 0 }),
	pd_("Wedge", 0.5, 1.0, 0.5, -0.55, 2.1, -0.45, "dark", { -8, 0, 10 }),
	pd_("Wedge", 0.5, 1.0, 0.5, 0.55, 2.1, -0.45, "dark", { -8, 0, -10 }),
	pd_("Wedge", 0.5, 0.8, 0.5, -0.5, 2.0, -1.05, "dark", { 5, 0, 10 }),
	pd_("Wedge", 0.5, 0.7, 0.5, 0.5, 1.95, -1.05, "dark", { 5, 0, -10 }),
	pd_("Ball", 1.3, 1.1, 0.5, 0, 0.85, 0.85, C(201, 183, 156)),
	pd_("Ball", 0.7, 0.7, 0.7, -0.95, 0.9, 0.5, "body"),
	pd_("Ball", 0.7, 0.7, 0.7, 0.95, 0.9, 0.5, "body"),
	pd_("Ball", 0.8, 0.5, 1.0, -0.55, 0.26, 0.55, "dark"),
	pd_("Ball", 0.8, 0.5, 1.0, 0.55, 0.26, 0.55, "dark"),
}
PetDesigns.Hootlet = {
	pd_("Ball", 1.7, 2.0, 1.6, 0, 1.15, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.8, 1.4, 1.5, 0, 2.15, 0.25, "body", nil, nil, nil, "Head"),
	pd_("Cylinder", 0.12, 0.7, 0.7, -0.42, 2.25, 0.95, C(242, 227, 196), { 90, 0, 0 }),
	pd_("Cylinder", 0.12, 0.7, 0.7, 0.42, 2.25, 0.95, C(242, 227, 196), { 90, 0, 0 }),
	pd_("Cylinder", 0.14, 0.45, 0.45, -0.42, 2.25, 1.0, C(255, 201, 59), { 90, 0, 0 }),
	pd_("Cylinder", 0.14, 0.45, 0.45, 0.42, 2.25, 1.0, C(255, 201, 59), { 90, 0, 0 }),
	pd_("Ball", 0.25, 0.25, 0.25, -0.42, 2.25, 1.05, C(40, 35, 35)),
	pd_("Ball", 0.25, 0.25, 0.25, 0.42, 2.25, 1.05, C(40, 35, 35)),
	pd_("Wedge", 0.3, 0.4, 0.4, 0, 2.0, 1.05, C(245, 168, 59), { 90, 0, 0 }),
	pd_("Wedge", 0.35, 0.8, 0.25, -0.6, 3.05, 0.2, "dark", { -10, 0, 10 }),
	pd_("Wedge", 0.35, 0.8, 0.25, 0.6, 3.05, 0.2, "dark", { -10, 0, -10 }),
	pd_("Wedge", 0.5, 1.4, 1.0, -0.95, 1.3, -0.1, "dark", { 0, 10, 12 }),
	pd_("Wedge", 0.5, 1.4, 1.0, 0.95, 1.3, -0.1, "dark", { 0, -10, -12 }),
	pd_("Ball", 0.5, 0.3, 0.1, 0, 1.25, 0.82, C(242, 227, 196)),
	pd_("Ball", 0.5, 0.3, 0.1, 0, 0.95, 0.85, C(242, 227, 196)),
	pd_("Ball", 0.5, 0.3, 0.1, 0, 0.65, 0.82, C(242, 227, 196)),
	pd_("Wedge", 0.6, 0.7, 0.25, 0, 0.75, -0.85, "dark", { 180, 0, 0 }),
	pd_("Ball", 0.5, 0.2, 0.5, -0.35, 0.12, 0.4, C(245, 168, 59)),
	pd_("Ball", 0.5, 0.2, 0.5, 0.35, 0.12, 0.4, C(245, 168, 59)),
}
PetDesigns.Cindert = {
	pd_("Ball", 1.6, 1.5, 1.7, 0, 0.95, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.6, 1.4, 1.4, 0, 1.95, 0.4, "body", nil, nil, nil, "Head"),
	pd_("Wedge", 0.3, 0.8, 0.3, -0.5, 2.75, 0.25, C(255, 233, 184), { -20, 0, 12 }),
	pd_("Wedge", 0.3, 0.8, 0.3, 0.5, 2.75, 0.25, C(255, 233, 184), { -20, 0, -12 }),
	pd_("Wedge", 0.5, 1.0, 0.15, 0, 2.9, 0.1, C(255, 170, 60), { -15, 0, 0 }, "Neon"),
	pd_("Wedge", 0.5, 0.9, 0.15, -0.32, 2.8, 0.08, C(255, 120, 45), { -15, 0, 16 }),
	pd_("Wedge", 0.5, 0.9, 0.15, 0.32, 2.8, 0.08, C(255, 120, 45), { -15, 0, -16 }),
	pd_("Wedge", 0.5, 0.85, 0.15, -0.55, 2.7, 0.05, C(255, 201, 57), { -15, 0, 28 }, "Neon"),
	pd_("Wedge", 0.5, 0.85, 0.15, 0.55, 2.7, 0.05, C(255, 201, 57), { -15, 0, -28 }, "Neon"),
	pd_("Ball", 0.3, 0.25, 0.2, -0.38, 2.05, 1.05, C(50, 35, 35), nil, nil, nil, "Part"),
	pd_("Ball", 0.3, 0.25, 0.2, 0.38, 2.05, 1.05, C(50, 35, 35)),
	pd_("Wedge", 0.1, 0.15, 0.1, -0.15, 1.78, 1.12, C(255, 255, 255), { 180, 0, 0 }),
	pd_("Wedge", 0.1, 0.15, 0.1, 0.15, 1.78, 1.12, C(255, 255, 255), { 180, 0, 0 }),
	pd_("Ball", 1.0, 0.8, 0.5, 0, 0.85, 0.7, C(255, 200, 120)),
	pd_("Ball", 0.45, 0.45, 0.45, -0.8, 1.0, 0.4, "body"),
	pd_("Ball", 0.45, 0.45, 0.45, 0.8, 1.0, 0.4, "body"),
	pd_("Ball", 0.55, 0.35, 0.8, -0.4, 0.2, 0.35, "body"),
	pd_("Ball", 0.55, 0.35, 0.8, 0.4, 0.2, 0.35, "body"),
	pd_("Ball", 0.4, 0.4, 0.4, 0, 1.05, -0.95, "body"),
	pd_("Ball", 0.3, 0.3, 0.3, 0, 1.3, -1.15, "body"),
	pd_("Ball", 0.25, 0.25, 0.25, 0, 1.52, -1.3, "body"),
	pd_("Wedge", 0.35, 0.6, 0.15, 0, 1.85, -1.38, C(255, 201, 57), { -25, 0, 0 }, "Neon"),
}
PetDesigns.Gustling = {
	pd_("Ball", 1.7, 1.6, 1.7, 0, 1.0, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.2, 1.1, 0.5, 0, 0.85, 0.72, C(244, 250, 255)),
	pd_("Ball", 1.2, 1.2, 1.2, 0, 2.0, 0.3, "body", nil, nil, nil, "Head"),
	pd_("Wedge", 0.35, 1.1, 0.15, 0, 2.85, 0.25, "dark", { -18, 0, 0 }),
	pd_("Wedge", 0.35, 1.05, 0.15, -0.26, 2.78, 0.22, C(79, 143, 216), { -18, 0, 15 }),
	pd_("Wedge", 0.35, 1.05, 0.15, 0.26, 2.78, 0.22, C(79, 143, 216), { -18, 0, -15 }),
	pd_("Wedge", 0.45, 0.3, 0.55, 0, 1.95, 0.95, C(255, 194, 74), { 90, 0, 0 }),
	pd_("Ball", 0.25, 0.25, 0.25, -0.3, 2.1, 0.82, C(43, 43, 43)),
	pd_("Ball", 0.25, 0.25, 0.25, 0.3, 2.1, 0.82, C(43, 43, 43)),
	pd_("Wedge", 1.6, 0.2, 1.1, -1.05, 1.45, -0.15, "body", { 0, 15, -10 }),
	pd_("Wedge", 1.6, 0.2, 1.1, 1.05, 1.45, -0.15, "body", { 0, -15, 10 }),
	pd_("Wedge", 0.3, 0.7, 0.15, 0, 1.35, -0.95, "dark", { -25, 0, 0 }),
	pd_("Wedge", 0.3, 0.65, 0.15, -0.2, 1.3, -0.95, "dark", { -25, 0, 12 }),
	pd_("Wedge", 0.3, 0.65, 0.15, 0.2, 1.3, -0.95, "dark", { -25, 0, -12 }),
	pd_("Ball", 0.5, 0.15, 0.7, -0.32, 0.1, 0.32, C(255, 194, 74)),
	pd_("Ball", 0.5, 0.15, 0.7, 0.32, 0.1, 0.32, C(255, 194, 74)),
}
PetDesigns.Fox = {
	pd_("Ball", 1.7, 1.5, 2.2, 0, 1.0, 0, "body", nil, nil, nil, "Body"),
	pd_("Ball", 1.6, 1.4, 1.5, 0, 2.05, 0.55, "body", nil, nil, nil, "Head"),
	pd_("Ball", 0.8, 0.6, 0.9, 0, 1.85, 1.2, C(255, 241, 220)),
	pd_("Ball", 0.22, 0.22, 0.22, 0, 2.0, 1.6, C(50, 40, 40)),
	pd_("Ball", 0.28, 0.28, 0.28, -0.37, 2.2, 1.3, C(43, 43, 43)),
	pd_("Ball", 0.28, 0.28, 0.28, 0.37, 2.2, 1.3, C(43, 43, 43)),
	pd_("Wedge", 0.7, 1.1, 0.3, -0.52, 2.95, 0.4, "body", { -8, 0, 8 }),
	pd_("Wedge", 0.7, 1.1, 0.3, 0.52, 2.95, 0.4, "body", { -8, 0, -8 }),
	pd_("Wedge", 0.4, 0.7, 0.15, -0.52, 2.9, 0.58, C(255, 241, 220)),
	pd_("Wedge", 0.4, 0.7, 0.15, 0.52, 2.9, 0.58, C(255, 241, 220)),
	pd_("Wedge", 0.5, 0.5, 0.2, -0.78, 1.85, 0.95, "light", { 0, 25, 0 }),
	pd_("Wedge", 0.5, 0.5, 0.2, 0.78, 1.85, 0.95, "light", { 0, -25, 0 }),
	pd_("Ball", 1.0, 0.9, 0.7, 0, 1.4, 0.95, C(255, 241, 220)),
	pd_("Cylinder", 0.8, 0.45, 0.45, -0.55, 0.4, 0.8, C(74, 58, 50), { 0, 0, 90 }),
	pd_("Cylinder", 0.8, 0.45, 0.45, 0.55, 0.4, 0.8, C(74, 58, 50), { 0, 0, 90 }),
	pd_("Cylinder", 0.8, 0.45, 0.45, -0.55, 0.4, -0.8, C(74, 58, 50), { 0, 0, 90 }),
	pd_("Cylinder", 0.8, 0.45, 0.45, 0.55, 0.4, -0.8, C(74, 58, 50), { 0, 0, 90 }),
	pd_("Ball", 0.55, 0.55, 0.55, -0.55, 0.28, 0.85, "body"),
	pd_("Ball", 0.55, 0.55, 0.55, 0.55, 0.28, 0.85, "body"),
	pd_("Ball", 0.55, 0.55, 0.55, -0.55, 0.28, -0.75, "body"),
	pd_("Ball", 0.55, 0.55, 0.55, 0.55, 0.28, -0.75, "body"),
	pd_("Ball", 1.1, 1.1, 1.1, 0, 1.2, -1.5, "body"),
	pd_("Ball", 1.0, 1.0, 1.0, 0, 1.6, -1.85, "body"),
	pd_("Ball", 0.8, 0.8, 0.8, 0, 1.95, -2.1, "body"),
	pd_("Ball", 0.5, 0.5, 0.5, 0, 2.25, -2.3, "body"),
	pd_("Ball", 0.6, 0.6, 0.6, 0, 2.3, -2.35, C(255, 241, 220)),
}

-- Cute pet model (v50 smooth animals -- not blocky at all).
-- scale ~0.6 baby/growing, 1.0 adult. Round ball head/body, big round
-- BGS-style eyes (white ball + pupil ball + glossy highlight), rounded
-- muzzle/beak. 5 smooth body builds (pup/stocky/slim/blob/long) keep species
-- distinct; smooth cylinder legs, wedge ears/beaks/fins/spikes, and family
-- tails (bushy fox, tapering dragon + spade, fanned feathers, curved wag).
-- shiny: cosmetic-only gold treatment -- Sparkles + a big "SHINY" billboard
-- (AlwaysOnTop) so wild shinies read from across the forest.
-- skin: optional cosmetic skin id ("Shadow" | "Golden" | "Frost") -- a tint +
-- one particle accent. Purely cosmetic, stacks with mutation/shiny visuals.
function PetData.BuildPetModel(petId: string, scale: number, mutation: string?, shiny: boolean?, skin: string?): Model
	local def = P[petId]
	assert(def, "Unknown pet " .. tostring(petId))
	local m = Instance.new("Model")
	m.Name = "Pet_" .. petId
	local body = def.Body
	local s = scale * def.Size
	local dark = C(
		math.clamp(body.R * 255 - 40, 0, 255),
		math.clamp(body.G * 255 - 40, 0, 255),
		math.clamp(body.B * 255 - 40, 0, 255))
	local light = C(
		math.clamp(body.R * 255 + 55, 0, 255),
		math.clamp(body.G * 255 + 55, 0, 255),
		math.clamp(body.B * 255 + 55, 0, 255))
	local ex = def.Extras or {}

	-- Claude custom design (2026-10-04): pets with a data-driven part list
	-- build from it instead of the parametric animal builder.
	local design = PetDesigns[petId]
	if design then
		buildDesign(m, design, s, body, light, dark)
		local ppd = Instance.new("Part")
		ppd.Name = "Primary"
		ppd.Size = Vector3.new(2.4, 3.4, 2.4) * s
		ppd.Transparency = 1
		ppd.Anchored = true
		ppd.CanCollide = false
		ppd.CFrame = CFrame.new(0, 1.7 * s, 0)
		ppd.Parent = m
		m.PrimaryPart = ppd
		PetData.ApplySkin(m, skin)
		return m
	end

	-- v50 smooth-animals: no blocky anatomy anywhere. Ball heads/bodies/
	-- cheeks/paws/tail segments, cylinder legs/snouts/horns/whiskers, wedge
	-- ears/beaks/fins/spikes. Big round BGS-style eyes (white ball + pupil
	-- ball + glossy highlight). 5 smooth body builds keep species
	-- silhouettes distinct. Same overall footprint (~3.5s tall) so plots,
	-- followers, riding, wild spawns and bosses all still fit. "Body" name
	-- is kept: ClientMain attaches particles/lights to it.

	-- smooth body builds: species silhouettes as rounded forms
	local buildDefs = {
		pup = { size = Vector3.new(1.9, 1.6, 1.9), y = 0.85, leg = 0.45 },
		stocky = { size = Vector3.new(2.4, 1.6, 2.4), y = 0.85, leg = 0.42 },
		slim = { size = Vector3.new(1.6, 2.0, 1.7), y = 1.05, leg = 0.50 },
		blob = { size = Vector3.new(2.3, 2.0, 2.3), y = 1.05, leg = 0.38 },
		long = { size = Vector3.new(1.7, 1.5, 2.9), y = 0.80, leg = 0.45 },
	}
	local bd = buildDefs[def.Build or "pup"] or buildDefs.pup
	-- round body
	part(m, "Body", bd.size * s, CFrame.new(0, bd.y * s, 0), body, Enum.PartType.Ball)
	-- light belly patch (flattened ball, everyone except grubs)
	if def.Type ~= "Bug" then
		part(m, "Belly", Vector3.new(bd.size.X * 0.62, bd.size.Y * 0.52, 0.55) * s,
			CFrame.new(0, (bd.y - 0.18) * s, (bd.size.Z / 2 - 0.12) * s), light, Enum.PartType.Ball)
	end
	-- big round head
	part(m, "Head", Vector3.new(2.0, 1.9, 1.9) * s,
		CFrame.new(0, 2.05 * s, 0.25 * s), body, Enum.PartType.Ball)

	-- big glossy eyes, Inferno-Cube cute: oversized whites, big pupils and a
	-- double highlight for the wet look. v47.3: ~30% bigger than before.
	for _, sx in { -1, 1 } do
		local side = if sx < 0 then "L" else "R"
		part(m, "EyeWhite" .. side, Vector3.new(0.78, 0.86, 0.46) * s,
			CFrame.new(sx * 0.58 * s, 2.32 * s, 1.06 * s), C(255, 255, 255), Enum.PartType.Ball)
		part(m, "Pupil" .. side, Vector3.new(0.40, 0.48, 0.24) * s,
			CFrame.new(sx * 0.58 * s, 2.30 * s, 1.28 * s), C(25, 25, 35), Enum.PartType.Ball)
		part(m, "EyeShine" .. side, Vector3.new(0.14, 0.14, 0.14) * s,
			CFrame.new(sx * 0.48 * s, 2.44 * s, 1.40 * s), C(255, 255, 255), Enum.PartType.Ball)
		part(m, "EyeShine2" .. side, Vector3.new(0.07, 0.07, 0.07) * s,
			CFrame.new(sx * 0.68 * s, 2.20 * s, 1.40 * s), C(255, 255, 255), Enum.PartType.Ball)
	end

	-- animal family flags drive tails, horns, whiskers
	local ear = def.Ear
	local idLower = petId:lower()
	local isFox = idLower:find("fox") ~= nil
	local isDragon = (ex.Snout and ear == "wing" and not ex.FireMane) or false
	local isBird = ex.Beak or false
	local tb = bd.size.Z / 2 -- body back edge, for tail placement

	if not (ex.Snout or ex.Beak or ex.BigJaw) then
		-- small smile + round nose
		part(m, "Mouth", Vector3.new(0.42, 0.14, 0.18) * s,
			CFrame.new(0, 1.72 * s, 1.10 * s), C(90, 50, 60), Enum.PartType.Ball)
		part(m, "Nose", Vector3.new(0.20, 0.20, 0.20) * s,
			CFrame.new(0, 1.92 * s, 1.16 * s), C(60, 40, 50), Enum.PartType.Ball)
	end
	if ex.Snout then
		-- rounded muzzle + nose (dogs, foxes, dragons, seals)
		part(m, "Snout", Vector3.new(0.95, 0.62, 0.65) * s,
			CFrame.new(0, 1.92 * s, 1.00 * s), dark, Enum.PartType.Ball)
		part(m, "Nose", Vector3.new(0.30, 0.24, 0.22) * s,
			CFrame.new(0, 2.02 * s, 1.30 * s), C(30, 25, 30), Enum.PartType.Ball)
	end
	if ex.Beak then
		-- wedge beak: thick at the face, tapering forward-down
		part(m, "Beak", Vector3.new(0.55, 0.45, 0.65) * s,
			CFrame.new(0, 2.02 * s, 1.20 * s), C(255, 165, 40), Enum.PartType.Wedge)
		part(m, "BeakLow", Vector3.new(0.40, 0.22, 0.45) * s,
			CFrame.new(0, 1.82 * s, 1.18 * s), C(230, 140, 30), Enum.PartType.Wedge)
	end
	if ex.Sprout then
		-- seedling sprout: cylinder stem + two rounded leaves
		local leafCol = C(70, 185, 90)
		part(m, "SproutStem", Vector3.new(0.14, 0.55, 0.14) * s,
			CFrame.new(0, 3.22 * s, 0.15 * s) * CFrame.Angles(0, 0, math.pi / 2),
			leafCol, Enum.PartType.Cylinder)
		part(m, "SproutLeafL", Vector3.new(0.55, 0.18, 0.32) * s,
			CFrame.new(-0.32 * s, 3.48 * s, 0.15 * s) * CFrame.Angles(0, 0, 0.40),
			leafCol, Enum.PartType.Ball)
		part(m, "SproutLeafR", Vector3.new(0.55, 0.18, 0.32) * s,
			CFrame.new(0.32 * s, 3.48 * s, 0.15 * s) * CFrame.Angles(0, 0, -0.40),
			leafCol, Enum.PartType.Ball)
	end
	if ex.LeafRuff then
		-- leafy collar: rounded leaves ringing the neck
		local leafCol = C(55, 170, 75)
		for i = 0, 7 do
			local ang = i * (math.pi * 2 / 8)
			part(m, "RuffLeaf", Vector3.new(0.65, 0.30, 0.45) * s,
				CFrame.new(math.cos(ang) * 1.15 * s, 1.20 * s, math.sin(ang) * 1.15 * s)
					* CFrame.Angles(0, -ang, 0), leafCol, Enum.PartType.Ball)
		end
	end
	if ex.BubbleDome then
		-- clear bubble helmet (water starters)
		local bub = part(m, "Bubble", Vector3.new(2.70, 2.70, 2.70) * s,
			CFrame.new(0, 2.70 * s, 0.25 * s), C(180, 225, 255), Enum.PartType.Ball)
		bub.Transparency = 0.65
	end
	if ex.FlameTail then
		-- burning tail: layered neon flame balls
		local ft = part(m, "FlameTail", Vector3.new(0.50, 0.50, 0.50) * s,
			CFrame.new(0, 1.00 * s, -(tb + 0.25) * s), C(255, 130, 30), Enum.PartType.Ball)
		ft.Material = Enum.Material.Neon
		local ft2 = part(m, "FlameTip", Vector3.new(0.34, 0.34, 0.34) * s,
			CFrame.new(0, 1.38 * s, -(tb + 0.35) * s), C(255, 210, 90), Enum.PartType.Ball)
		ft2.Material = Enum.Material.Neon
	end
	if ex.SparkTail then
		-- crackling electric tail: layered neon sparks
		local st = part(m, "SparkTail", Vector3.new(0.46, 0.46, 0.46) * s,
			CFrame.new(0, 1.00 * s, -(tb + 0.25) * s), C(255, 220, 80), Enum.PartType.Ball)
		st.Material = Enum.Material.Neon
		local st2 = part(m, "SparkTip", Vector3.new(0.30, 0.30, 0.30) * s,
			CFrame.new(0, 1.36 * s, -(tb + 0.35) * s), C(200, 235, 255), Enum.PartType.Ball)
		st2.Material = Enum.Material.Neon
	end
	if ex.BigJaw then
		-- wide heavy rounded jaw (Abyssjaw) + fangs
		part(m, "Jaw", Vector3.new(1.50, 0.80, 1.20) * s,
			CFrame.new(0, 1.50 * s, 0.55 * s), dark, Enum.PartType.Ball)
		for _, sx in { -1, 1 } do
			part(m, "Fang" .. (if sx < 0 then "L" else "R"), Vector3.new(0.16, 0.28, 0.16) * s,
				CFrame.new(sx * 0.45 * s, 1.28 * s, 1.05 * s), C(245, 245, 245), Enum.PartType.Ball)
		end
	end

	-- smooth ears
	if ear == "point" then
		-- perky ears: stacked rounded balls read as smooth cones
		for _, sx in { -1, 1 } do
			local side = if sx < 0 then "L" else "R"
			part(m, "Ear" .. side, Vector3.new(0.52, 0.62, 0.40) * s,
				CFrame.new(sx * 0.62 * s, 2.95 * s, 0.10 * s), body, Enum.PartType.Ball)
			part(m, "EarTip" .. side, Vector3.new(0.34, 0.42, 0.30) * s,
				CFrame.new(sx * 0.66 * s, 3.32 * s, 0.10 * s), body, Enum.PartType.Ball)
			part(m, "InnerEar", Vector3.new(0.28, 0.38, 0.16) * s,
				CFrame.new(sx * 0.62 * s, 2.92 * s, 0.30 * s), light, Enum.PartType.Ball)
		end
	elseif ear == "flop" then
		-- floppy ears: flattened balls hanging beside the head
		for _, sx in { -1, 1 } do
			local side = if sx < 0 then "L" else "R"
			part(m, "Ear" .. side, Vector3.new(0.50, 0.95, 0.34) * s,
				CFrame.new(sx * 1.00 * s, 2.25 * s, 0.15 * s) * CFrame.Angles(0, 0, sx * -0.22),
				dark, Enum.PartType.Ball)
			part(m, "InnerEar", Vector3.new(0.30, 0.60, 0.16) * s,
				CFrame.new(sx * 1.00 * s, 2.20 * s, 0.32 * s) * CFrame.Angles(0, 0, sx * -0.22),
				light, Enum.PartType.Ball)
		end
	elseif ear == "horn" then
		-- single smooth horn with a rounded tip
		part(m, "Horn", Vector3.new(0.30, 0.80, 0.30) * s,
			CFrame.new(0, 3.20 * s, 0.25 * s) * CFrame.Angles(0, 0, math.pi / 2),
			C(245, 240, 220), Enum.PartType.Cylinder)
		part(m, "HornTip", Vector3.new(0.18, 0.18, 0.18) * s,
			CFrame.new(0, 3.62 * s, 0.25 * s), C(255, 250, 235), Enum.PartType.Ball)
	elseif ear == "fin" then
		-- rounded side fins (water line)
		for _, sx in { -1, 1 } do
			local side = if sx < 0 then "L" else "R"
			part(m, "Fin" .. side, Vector3.new(0.30, 0.70, 0.90) * s,
				CFrame.new(sx * 1.00 * s, 1.75 * s, 0.10 * s) * CFrame.Angles(0, 0, sx * -0.30),
				dark, Enum.PartType.Ball)
		end
	elseif ear == "wing" then
		-- layered feathered wings: rounded slabs with light tips
		for _, sx in { -1, 1 } do
			local side = if sx < 0 then "L" else "R"
			part(m, "Wing" .. side, Vector3.new(0.40, 0.95, 1.50) * s,
				CFrame.new(sx * 1.15 * s, 2.05 * s, -0.45 * s) * CFrame.Angles(0, 0, sx * -0.50),
				dark, Enum.PartType.Ball)
			part(m, "WingFeather", Vector3.new(0.32, 0.70, 1.05) * s,
				CFrame.new(sx * 1.52 * s, 1.68 * s, -0.60 * s) * CFrame.Angles(0, 0, sx * -0.50),
				light, Enum.PartType.Ball)
		end
	end

	-- dragon horns: smooth cylinders tilted outward
	if isDragon then
		for _, sx in { -1, 1 } do
			part(m, "DragonHorn", Vector3.new(0.24, 0.62, 0.24) * s,
				CFrame.new(sx * 0.55 * s, 3.18 * s, 0.05 * s) * CFrame.Angles(0, 0, math.pi / 2 - sx * 0.30),
				C(245, 240, 220), Enum.PartType.Cylinder)
		end
	end
	-- fox whiskers (thin cylinders) + cheek fluff
	if isFox and ex.Snout then
		for _, sx in { -1, 1 } do
			part(m, "CheekFluff", Vector3.new(0.38, 0.38, 0.38) * s,
				CFrame.new(sx * 0.80 * s, 1.85 * s, 0.80 * s), light, Enum.PartType.Ball)
			for i = 0, 1 do
				part(m, "Whisker", Vector3.new(0.60, 0.05, 0.05) * s,
					CFrame.new(sx * 0.72 * s, (1.88 + i * 0.12) * s, 1.22 * s) * CFrame.Angles(0, 0, sx * -0.08),
					C(245, 245, 245), Enum.PartType.Cylinder)
			end
		end
	end
	-- bunny buck teeth
	if ex.CottonTail then
		part(m, "BuckTeeth", Vector3.new(0.26, 0.30, 0.16) * s,
			CFrame.new(0, 1.58 * s, 1.12 * s), C(250, 250, 250), Enum.PartType.Ball)
	end
	-- electric cheek pouches
	if ex.VoltCheeks then
		for _, sx in { -1, 1 } do
			local vc = part(m, "VoltCheek", Vector3.new(0.34, 0.34, 0.34) * s,
				CFrame.new(sx * 0.85 * s, 1.88 * s, 1.00 * s), C(255, 215, 60), Enum.PartType.Ball)
			vc.Material = Enum.Material.Neon
		end
	end

	-- smooth cylinder legs + round paws
	local legX, legZ = bd.size.X * 0.30, bd.size.Z * 0.28
	local legH = bd.leg + 0.15
	for _, xs in { -1, 1 } do
		for _, zs in { -1, 1 } do
			part(m, "Leg", Vector3.new(bd.leg, legH, bd.leg) * s,
				CFrame.new(xs * legX * s, (legH / 2) * s, zs * legZ * s) * CFrame.Angles(0, 0, math.pi / 2),
				dark, Enum.PartType.Cylinder)
			if not ex.Flippers then
				part(m, "Paw", Vector3.new(bd.leg * 1.15, bd.leg * 0.70, bd.leg * 1.30) * s,
					CFrame.new(xs * legX * s, 0.18 * s, (zs * legZ + bd.leg * 0.35) * s),
					light, Enum.PartType.Ball)
			end
		end
	end
	if ex.Flippers then
		-- turtles: swap legs for rounded flippers
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Leg" then d:Destroy() end
		end
		for _, xz in { { -0.85, 0.45 }, { 0.85, 0.45 }, { -0.85, -0.45 }, { 0.85, -0.45 } } do
			part(m, "Flipper", Vector3.new(1.00, 0.30, 0.70) * s,
				CFrame.new(xz[1] * s, 0.22 * s, xz[2] * s)
					* CFrame.Angles(0, if xz[1] < 0 then 0.30 else -0.30, 0), dark, Enum.PartType.Ball)
		end
	end
	if ex.LeafCrown then
		-- rounded leaf ring on the head
		local leafCol = C(70, 185, 90)
		for i = 0, 5 do
			local ang = i * (math.pi * 2 / 6)
			part(m, "Leaf", Vector3.new(0.45, 0.45, 0.45) * s,
				CFrame.new(math.cos(ang) * 0.70 * s, 3.05 * s, 0.15 * s + math.sin(ang) * 0.70 * s),
				leafCol, Enum.PartType.Ball)
		end
	end
	-- top of the body ellipsoid at a given z, so spikes sit ON the back
	local function backTop(z: number): number
		local zn = z / (bd.size.Z / 2)
		return bd.y + (bd.size.Y / 2) * math.sqrt(math.max(0.05, 1 - zn * zn))
	end
	if ex.BackSpikes then
		-- smooth swept-back spikes riding the spine
		for _, z in { -0.35, -0.55, -0.75, -0.92 } do
			part(m, "Spike", Vector3.new(0.36, 0.60, 0.36) * s,
				CFrame.new(0, (backTop(z) + 0.12) * s, z * s) * CFrame.Angles(-0.45, 0, 0),
				C(245, 240, 220), Enum.PartType.Wedge)
		end
	end
	if ex.FireMane then
		-- puffy flame mane: neon balls ringing the neck
		for i = 0, 5 do
			local ang = i * (math.pi * 2 / 6)
			local fcol = if i % 2 == 0 then C(255, 120, 40) else C(255, 200, 70)
			local f = part(m, "Flame", Vector3.new(0.60, 0.60, 0.60) * s,
				CFrame.new(math.cos(ang) * 1.00 * s, 1.40 * s, 0.10 * s + math.sin(ang) * 1.00 * s),
				fcol, Enum.PartType.Ball)
			f.Material = Enum.Material.Neon
		end
	end
	if ex.AquaFins then
		-- rounded dorsal fin + tail fin
		local finCol = C(140, 200, 255)
		part(m, "DorsalFin", Vector3.new(0.28, 0.90, 1.10) * s,
			CFrame.new(0, 2.35 * s, -0.55 * s) * CFrame.Angles(-0.40, 0, 0), finCol, Enum.PartType.Wedge)
		part(m, "TailFin", Vector3.new(0.22, 0.70, 0.55) * s,
			CFrame.new(0, 1.00 * s, -(tb + 0.30) * s), finCol, Enum.PartType.Wedge)
	end
	if ex.Comb then
		-- round red comb bumps along the head
		for i, z in { 0.95, 0.55, 0.15 } do
			part(m, "Comb", Vector3.new(0.36, 0.36, 0.36) * s,
				CFrame.new(0, (2.95 + (if i == 2 then 0.10 else 0)) * s, z * s),
				C(225, 70, 70), Enum.PartType.Ball)
		end
	end
	if ex.CottonTail then
		-- fluffy round tail
		part(m, "CottonTail", Vector3.new(0.60, 0.60, 0.60) * s,
			CFrame.new(0, 0.80 * s, -(tb + 0.10) * s), C(245, 245, 245), Enum.PartType.Ball)
	end
	if ex.IceShards then
		-- ice shards riding the back
		for _, z in { -0.35, -0.60, -0.85 } do
			part(m, "IceShard", Vector3.new(0.34, 0.55, 0.34) * s,
				CFrame.new(0, (backTop(z) + 0.12) * s, z * s) * CFrame.Angles(-0.35, 0, 0),
				C(170, 220, 255), Enum.PartType.Wedge)
		end
	end
	if ex.RockSpikes or ex.LavaSpikes then
		-- rocky nubs down the back (glowing for magma)
		local rcol = if ex.LavaSpikes then C(255, 110, 40) else C(120, 110, 100)
		for _, z in { -0.35, -0.55, -0.75, -0.92 } do
			local rsp = part(m, "RockSpike", Vector3.new(0.42, 0.55, 0.42) * s,
				CFrame.new(0, (backTop(z) + 0.12) * s, z * s) * CFrame.Angles(-0.40, 0, 0),
				rcol, Enum.PartType.Wedge)
			if ex.LavaSpikes then rsp.Material = Enum.Material.Neon end
		end
	end
	if ex.EyeDiscs then
		-- owls: pale rounded facial discs framing the big eyes
		part(m, "DiscL", Vector3.new(0.95, 1.00, 0.30) * s,
			CFrame.new(-0.55 * s, 2.32 * s, 0.92 * s), C(240, 240, 240), Enum.PartType.Ball)
		part(m, "DiscR", Vector3.new(0.95, 1.00, 0.30) * s,
			CFrame.new(0.55 * s, 2.32 * s, 0.92 * s), C(240, 240, 240), Enum.PartType.Ball)
	end
	if ex.HeadCrest then
		-- sleek swept-back crest
		part(m, "Crest", Vector3.new(0.34, 0.80, 0.55) * s,
			CFrame.new(0, 3.05 * s, -0.30 * s) * CFrame.Angles(-0.50, 0, 0), dark, Enum.PartType.Ball)
	end
	if ex.TailTip and not isFox then
		-- light-colored tip on the nub tail (foxes get a full bushy tail below)
		part(m, "TailTip", Vector3.new(0.34, 0.34, 0.34) * s,
			CFrame.new(0, 0.98 * s, -(tb + 0.22) * s), C(250, 245, 230), Enum.PartType.Ball)
	end
	if ex.MoonMark then
		-- lunar fox: glowing mark on the forehead
		local mk = part(m, "MoonMark", Vector3.new(0.42, 0.42, 0.20) * s,
			CFrame.new(0, 2.85 * s, 0.78 * s), C(255, 245, 170), Enum.PartType.Ball)
		mk.Material = Enum.Material.Neon
	end
	if ex.AmberCore then
		-- fossil pets: glowing amber core on the chest
		local core = part(m, "AmberCore", Vector3.new(0.62, 0.62, 0.62) * s,
			CFrame.new(0, 0.95 * s, (bd.size.Z / 2 - 0.15) * s), C(255, 170, 60), Enum.PartType.Ball)
		core.Material = Enum.Material.Neon
	end
	if ex.WindSwirl then
		-- sky line: soft glowing wisps circling the body
		for i = 0, 2 do
			local a = i * (math.pi * 2 / 3)
			local w = part(m, "WindWisp" .. i, Vector3.new(0.45, 0.45, 0.45) * s,
				CFrame.new(math.cos(a) * 1.35 * s, 0.95 * s, math.sin(a) * 1.35 * s),
				C(235, 245, 255), Enum.PartType.Ball)
			w.Material = Enum.Material.Neon
			w.Transparency = 0.4
		end
	end
	if ex.GlowEyes then
		-- dark pets: glowing pupils (extras value is the eye Color3)
		local ecol: Color3 = ex.GlowEyes
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and (d.Name == "PupilL" or d.Name == "PupilR") then
				d.Color = ecol
				d.Material = Enum.Material.Neon
			end
		end
	end
	if def.Tail and not ex.FlameTail and not ex.SparkTail then
		-- smooth tails by animal family; tb = body back edge
		if isFox then
			-- big bushy fox tail: swelling middle + light tip
			part(m, "Tail1", Vector3.new(0.55, 0.55, 0.55) * s,
				CFrame.new(0, 0.95 * s, -(tb + 0.15) * s), body, Enum.PartType.Ball)
			part(m, "Tail2", Vector3.new(0.74, 0.74, 0.74) * s,
				CFrame.new(0, 1.22 * s, -(tb + 0.62) * s), body, Enum.PartType.Ball)
			part(m, "TailTip", Vector3.new(0.50, 0.50, 0.50) * s,
				CFrame.new(0, 1.58 * s, -(tb + 0.95) * s), C(250, 245, 230), Enum.PartType.Ball)
		elseif isDragon then
			-- long tapering dragon tail with a wedge spade tip
			part(m, "Tail1", Vector3.new(0.45, 0.45, 0.45) * s,
				CFrame.new(0, 0.80 * s, -(tb + 0.20) * s), dark, Enum.PartType.Ball)
			part(m, "Tail2", Vector3.new(0.36, 0.36, 0.36) * s,
				CFrame.new(0, 0.72 * s, -(tb + 0.65) * s), dark, Enum.PartType.Ball)
			part(m, "Tail3", Vector3.new(0.27, 0.27, 0.27) * s,
				CFrame.new(0, 0.68 * s, -(tb + 1.02) * s), dark, Enum.PartType.Ball)
			part(m, "TailSpade", Vector3.new(0.50, 0.55, 0.22) * s,
				CFrame.new(0, 0.70 * s, -(tb + 1.35) * s), dark, Enum.PartType.Wedge)
		elseif isBird then
			-- fanned rounded tail feathers
			for i = -1, 1 do
				part(m, "TailFeather", Vector3.new(0.34, 0.16, 0.95) * s,
					CFrame.new(i * 0.30 * s, 0.95 * s, -(tb + 0.40) * s) * CFrame.Angles(0, i * 0.35, 0),
					dark, Enum.PartType.Ball)
			end
		elseif ear == "fin" or def.Type == "Water" then
			-- aquatic nub tail (AquaFins pets get a wedge tail fin above)
			part(m, "Tail", Vector3.new(0.50, 0.50, 0.50) * s,
				CFrame.new(0, 0.85 * s, -(tb + 0.05) * s), dark, Enum.PartType.Ball)
		elseif def.Type == "Bug" then
			-- grub: tiny nub
			part(m, "Tail", Vector3.new(0.40, 0.40, 0.40) * s,
				CFrame.new(0, 0.70 * s, -(tb + 0.05) * s), dark, Enum.PartType.Ball)
		else
			-- mammals: curved tail of shrinking balls
			part(m, "Tail1", Vector3.new(0.42, 0.42, 0.42) * s,
				CFrame.new(0, 0.95 * s, -(tb + 0.12) * s), dark, Enum.PartType.Ball)
			part(m, "Tail2", Vector3.new(0.34, 0.34, 0.34) * s,
				CFrame.new(0, 1.28 * s, -(tb + 0.30) * s), dark, Enum.PartType.Ball)
		end
	end
	if def.Shell then
		-- smooth dome shell over the back
		part(m, "Shell", Vector3.new(2.50, 1.70, 2.50) * s,
			CFrame.new(0, 1.20 * s, -0.35 * s), dark, Enum.PartType.Ball)
		-- rounded shell plates (scutes) on the dome
		part(m, "ShellPlate", Vector3.new(0.90, 0.40, 0.90) * s,
			CFrame.new(0, 1.95 * s, -0.35 * s), light, Enum.PartType.Ball)
		for _, xz in { { -0.70, -0.35 }, { 0.70, -0.35 }, { 0, -1.05 } } do
			part(m, "ShellPlate", Vector3.new(0.70, 0.35, 0.70) * s,
				CFrame.new(xz[1] * s, 1.78 * s, (xz[2] - 0.35) * s), light, Enum.PartType.Ball)
		end
	end
	-- mutation visuals (skip the type gem)
	if mutation == "Golden" or mutation == "Double" then
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "Primary" and d.Name ~= "TypeGem" then d.Color = C(255, 200, 40) end
		end
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = C(255, 220, 80)
		sp.Parent = m:FindFirstChild("Body")
	elseif mutation == "Rainbow" or mutation == "Double" then
		local cols = { C(255, 90, 90), C(255, 200, 90), C(140, 255, 140), C(120, 180, 255), C(200, 140, 255) }
		local i = 1
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "Primary" and d.Name ~= "TypeGem" then
				d.Color = cols[i]
				i = i % #cols + 1
			end
		end
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = C(255, 255, 255)
		sp.Parent = m:FindFirstChild("Body")
	elseif mutation == "Void" then
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "Primary" and d.Name ~= "TypeGem" then
				d.Color = C(45, 30, 70)
			end
		end
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(C(120, 60, 200))
		pe.Size = NumberSequence.new(0.6)
		pe.Rate = 12
		pe.Lifetime = NumberRange.new(0.8, 1.4)
		pe.Speed = NumberRange.new(1, 3)
		pe.Parent = m:FindFirstChild("Body")
	end

	-- v47.3: elemental aura — soft type-colored particles around every pet, like
	-- the flames around the Inferno Cube. Low rate so a garden of pets stays fast.
	local auraByType = {
		Fire = { C(255, 110, 25), C(255, 195, 70) },
		Water = { C(70, 160, 255), C(170, 225, 255) },
		Grass = { C(85, 195, 85), C(175, 255, 145) },
		Electric = { C(255, 215, 75), C(255, 255, 175) },
		Dark = { C(115, 55, 195), C(175, 115, 255) },
		Ice = { C(150, 215, 255), C(230, 250, 255) },
		Ground = { C(195, 150, 95), C(235, 205, 150) },
		Flying = { C(180, 200, 235), C(235, 245, 255) },
		Bug = { C(150, 200, 70), C(210, 245, 140) },
		Normal = { C(200, 190, 175), C(240, 235, 225) },
	}
	local auraCols = auraByType[def.Type] or auraByType.Normal
	do
		local bodyPart = m:FindFirstChild("Body")
		if bodyPart then
			local aura = Instance.new("ParticleEmitter")
			aura.Name = "TypeAura"
			aura.Color = ColorSequence.new(auraCols[1], auraCols[2])
			aura.Size = NumberSequence.new(0.45)
			aura.Rate = 8
			aura.Lifetime = NumberRange.new(0.9, 1.5)
			aura.Speed = NumberRange.new(1, 2.5)
			aura.SpreadAngle = Vector2.new(360, 360)
			aura.Parent = bodyPart
		end
	end

	-- shiny treatment: gold sparkles + a billboard visible from far away.
	-- Purely cosmetic -- no stat or value change.
	if shiny then
		local body = m:FindFirstChild("Body")
		if body then
			local sp = Instance.new("Sparkles")
			sp.Name = "ShinySparkles"
			sp.SparkleColor = C(255, 215, 90)
			sp.Parent = body
			local bb = Instance.new("BillboardGui")
			bb.Name = "ShinyTag"
			bb.Size = UDim2.new(0, 150, 0, 40)
			bb.StudsOffset = Vector3.new(0, 4.0 * s, 0)
			bb.AlwaysOnTop = true
			local tl = Instance.new("TextLabel")
			tl.Size = UDim2.new(1, 0, 1, 0)
			tl.BackgroundTransparency = 0.25
			tl.BackgroundColor3 = C(120, 80, 10)
			tl.Text = "✨ SHINY"
			tl.TextScaled = true
			tl.TextColor3 = C(255, 235, 150)
			tl.Font = Enum.Font.FredokaOne
			tl.Parent = bb
			bb.Adornee = body
			bb.Parent = body
		end
	end

	local pp = Instance.new("Part")
	pp.Name = "Primary"
	pp.Size = Vector3.new(2.4, 3.4, 2.4) * s
	pp.Transparency = 1
	pp.Anchored = true
	pp.CanCollide = false
	pp.CFrame = CFrame.new(0, 1.7 * s, 0)
	pp.Parent = m
	m.PrimaryPart = pp

	PetData.ApplySkin(m, skin)

	return m
end

return PetData
