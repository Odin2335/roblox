--!nonstrict
-- Expeditionen: Lobby an der Tafel, Start, zufällige Bestückung von
-- Verdant Scar, Rückkehr/Beutesicherung, Niederschlag, Wiederbeleben, Teamwipe.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Expedition = {}
local ctx: any

local MAX_PARTY = 4
local LOBBY_TIME = 20
local TAG = "Run"

local phase: string = "Idle"
local difficulty = "Normal"
local leader: Player? = nil
local members: { Player } = {}
local participants: { Player } = {}
local lobbyEnds = 0
local runStart = 0
local bossDead = false
local runFolder: Folder? = nil
local arenaPortalPrompt: ProximityPrompt? = nil
local arenaSurface: BasePart? = nil
local disconnected: { [number]: { backpack: { [string]: number }, protectedLoot: { [string]: number } } } = {}
local revivePrompts: { [Player]: ProximityPrompt } = {}

--------------------------------------------------------------------------------
-- Öffentliche Infos
--------------------------------------------------------------------------------
local function names(list: { Player }): { string }
	local out = {}
	for _, p in list do
		table.insert(out, p.DisplayName)
	end
	return out
end

function Expedition.PublicInfo()
	return {
		phase = phase,
		difficulty = difficulty,
		leader = if leader then leader.DisplayName else nil,
		leaderId = if leader then leader.UserId else nil,
		members = names(members),
		participants = names(participants),
		lobbyEnds = lobbyEnds,
		runStart = runStart,
		bossDead = bossDead,
	}
end

function Expedition.Participants(): { Player }
	return participants
end

local function isParticipant(p: Player): boolean
	return table.find(participants, p) ~= nil
end

local function removeFrom(list: { Player }, p: Player)
	local i = table.find(list, p)
	if i then
		table.remove(list, i)
	end
end

local function teleport(player: Player, pos: Vector3)
	local char = player.Character
	if char then
		local offset = Vector3.new(math.random(-4, 4), 3.5, math.random(-4, 4))
		char:PivotTo(CFrame.new(pos + offset) * CFrame.Angles(0, math.pi, 0))
	end
end

local function hasWeapon(player: Player): boolean
	return ctx.PlayerState.GetWeapon(player) ~= nil
end

--------------------------------------------------------------------------------
-- Lauf bestücken
--------------------------------------------------------------------------------
local function shuffle<T>(list: { T }): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = math.random(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function jitter(pos: Vector3, amount: number): Vector3
	return pos + Vector3.new(math.random(-amount, amount), 0, math.random(-amount, amount))
end

local function lootAll(items: { [string]: number }, protected: boolean?)
	for _, p in participants do
		ctx.PlayerState.AddLoot(p, table.clone(items), protected)
	end
end

local function scaleLoot(items: { [string]: number }): { [string]: number }
	local mult = Config.Difficulties[difficulty].loot
	for k, v in items do
		if Config.Items[k].kind == "Basic" then
			items[k] = math.max(1, math.floor(v * mult + 0.5))
		end
	end
	return items
end

local function randomCore(): string
	local el = Config.ElementOrder[math.random(1, #Config.ElementOrder)]
	return Config.Elements[el].core
end

local function randomPart(): string
	local parts = { "PartCrawlerClaw", "PartWraithCore", "PartStalkerBark", "PartMimicTooth" }
	return parts[math.random(1, #parts)]
end

-- Ressourcenknoten: Ertrag und benötigtes Werkzeug
local NODES = {
	Copper_Deposit = { item = "CopperOre", min = 3, max = 4, tool = "StonePickaxe" },
	Stone_Deposit = { item = "Stone", min = 2, max = 3, tool = "StonePickaxe" },
	Rift_Deposit = { item = "RiftCrystal", min = 2, max = 3, tool = "StonePickaxe" },
	Hard_Copper_Deposit = { item = "CopperOre", min = 5, max = 7, tool = "CopperPickaxe", bonus = { RiftCrystal = 1 }, label = "Harte Kupferader" },
	Timber_Pile = { item = "Wood", min = 2, max = 3 },
	Fiber_Bush = { item = "Fiber", min = 2, max = 3 },
	Herb_Patch = { item = "Herb", min = 1, max = 2 },
}

local function spawnNode(kind: string, pos: Vector3)
	local def = NODES[kind]
	local folder = runFolder :: Folder
	local m = ctx.WorldBuilder.Place(kind, pos, math.random(0, 359), nil, folder)
	local title = def.label or Config.Items[def.item].name
	if def.tool then
		title ..= " (" .. Config.Gear[def.tool].name .. ")"
	end
	local verb = if def.tool then "Abbauen" else "Sammeln"
	local prompt = ctx.WorldBuilder.Prompt(ctx.WorldBuilder.PromptAnchor(m), verb, title, if def.tool then 1.1 else 0.6)
	local used = false
	prompt.Triggered:Connect(function(player)
		if used or not isParticipant(player) or not ctx.PlayerState.IsActive(player) then
			return
		end
		local profile = ctx.DataService.Get(player)
		if def.tool and not (profile and profile.tools[def.tool]) then
			ctx.PlayerState.Notify(player, "Dafür brauchst du eine " .. Config.Gear[def.tool].name .. " (Werkbank).", "bad")
			return
		end
		used = true
		local loot = { [def.item] = math.random(def.min, def.max) }
		if def.bonus then
			for k, v in def.bonus do
				loot[k] = (loot[k] or 0) + v
			end
		end
		ctx.PlayerState.AddLoot(player, scaleLoot(loot))
		Net.Event("Fx"):FireAllClients("Harvest", pos, def.tool)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				TweenService:Create(d, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end
		task.delay(0.45, function()
			m:Destroy()
		end)
	end)
end

-- Bauplan-Chance in Truhen (nur Baupläne, die der Spieler noch nicht hat)
local function blueprintFor(player: Player, chance: number): string?
	if math.random() > chance then
		return nil
	end
	local profile = ctx.DataService.Get(player)
	if not profile then
		return nil
	end
	local options = {}
	for _, pair in { { "BlueprintGrapple", "Grapple" }, { "BlueprintBow", "Bow" } } do
		if not profile.unlocked[pair[2]] and (profile.stash[pair[1]] or 0) == 0 then
			table.insert(options, pair[1])
		end
	end
	return if #options > 0 then options[math.random(1, #options)] else nil
end

local function spawnChest(pos: Vector3, rare: boolean, mimic: boolean)
	local diff = Config.Difficulties[difficulty]
	if mimic then
		local e = ctx.Entities.SpawnEnemy(
			"Burrow_Mimic",
			pos,
			{ tag = TAG, dormant = true, hpMult = diff.hp, dmgMult = diff.damage, lootMult = diff.loot, yaw = math.random(0, 359) }
		)
		e.name = "Truhe"
		local label = e.root:FindFirstChild("HPBar") :: BillboardGui?
		if label then
			label.Enabled = false
		end
		local prompt = ctx.WorldBuilder.Prompt(e.root, "Öffnen", "Truhe")
		prompt.Triggered:Connect(function()
			ctx.Entities.Wake(e)
		end)
		return
	end
	local folder = runFolder :: Folder
	local m = ctx.WorldBuilder.Place("Storage_Chest", pos, math.random(0, 359), 2.4, folder)
	local prompt = ctx.WorldBuilder.Prompt(ctx.WorldBuilder.PromptAnchor(m), "Öffnen", if rare then "Seltene Truhe" else "Truhe", 0.5)
	prompt.Triggered:Connect(function(player)
		if not isParticipant(player) or not ctx.PlayerState.IsActive(player) or not prompt.Parent then
			return
		end
		prompt:Destroy()
		local loot: { [string]: number }
		if rare then
			loot = { RiftCrystal = math.random(2, 3) }
			if math.random() < 0.45 then
				loot[randomCore()] = 1
			end
			if math.random() < 0.3 then
				loot[randomPart()] = 1
			end
		else
			loot = { CopperBar = math.random(1, 2), RiftCrystal = math.random(1, 2) }
			if math.random() < 0.15 then
				loot[randomCore()] = 1
			end
		end
		lootAll(scaleLoot(loot))
		for _, p in participants do
			local bp = blueprintFor(p, if rare then 0.45 else 0.35)
			if bp then
				ctx.PlayerState.AddLoot(p, { [bp] = 1 })
			end
		end
		Net.Event("Fx"):FireAllClients("ChestOpen", m)
		task.delay(1.5, function()
			m:Destroy()
		end)
	end)
end

local function forParticipants(fn: (Player) -> ())
	for _, p in participants do
		fn(p)
	end
end

local function buildBarriers()
	local folder = runFolder :: Folder
	-- Rift-Barriere vor dem Schrein (jede Waffe, schwere Angriffe wirken doppelt)
	local seal = Instance.new("Model")
	seal.Name = "RiftSeal"
	local sp = Instance.new("Part")
	sp.Size = Vector3.new(2, 15, 17)
	sp.CFrame = CFrame.new(ctx.WorldBuilder.Points.RiftSeal + Vector3.new(0, 7.5, 0))
	sp.Anchored = true
	sp.Material = Enum.Material.ForceField
	sp.Color = Config.Colors.Rift
	sp.Parent = seal
	seal.PrimaryPart = sp
	seal.Parent = folder
	ctx.Entities.RegisterStatic(seal, {
		kind = "RiftSeal",
		name = "Rift-Barriere",
		hp = 160,
		shield = true,
		tag = TAG,
		barHeight = 9,
		onDeath = function()
			ctx.PlayerState.NotifyAll(participants, "Die Rift-Barriere ist gebrochen! Der Schrein ist offen.", "good")
			forParticipants(function(p)
				ctx.Progress.Milestone(p, "Barrier")
			end)
		end,
	})

	-- Frostsiegel vor dem Versteck (nur Glut oder Frost)
	local frost = Instance.new("Model")
	frost.Name = "FrostSeal"
	local fp = Instance.new("Part")
	fp.Size = Vector3.new(3, 15, 15)
	fp.CFrame = CFrame.new(ctx.WorldBuilder.Points.FrostSeal + Vector3.new(0, 7.5, 0))
	fp.Anchored = true
	fp.Material = Enum.Material.Ice
	fp.Color = Color3.fromRGB(160, 220, 255)
	fp.Transparency = 0.15
	fp.Parent = frost
	frost.PrimaryPart = fp
	frost.Parent = folder
	ctx.Entities.RegisterStatic(frost, {
		kind = "FrostSeal",
		name = "Frostsiegel",
		hp = 120,
		requires = { "Ember", "Frost" },
		tag = TAG,
		barHeight = 9,
		onDeath = function()
			ctx.PlayerState.NotifyAll(participants, "Das Frostsiegel ist offen – ein verborgenes Versteck!", "good")
			forParticipants(function(p)
				ctx.Progress.Milestone(p, "Barrier")
				ctx.Progress.CompleteQuest(p, "Explore")
			end)
		end,
	})

	-- Schrein: jeder Teilnehmer darf einmal einen Kern bergen
	local taken: { [number]: boolean } = {}
	local anchor = Instance.new("Part")
	anchor.Size = Vector3.new(1.4, 1.4, 1.4)
	anchor.Shape = Enum.PartType.Ball
	anchor.Material = Enum.Material.Neon
	anchor.Color = Color3.fromRGB(255, 255, 255)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CFrame = CFrame.new(ctx.WorldBuilder.Points.Shrine + Vector3.new(0, 3, 0))
	anchor.Parent = folder
	local light = Instance.new("PointLight")
	light.Range = 12
	light.Parent = anchor
	local prompt = ctx.WorldBuilder.Prompt(anchor, "Kern bergen", "Elementschrein", 1)
	prompt.Triggered:Connect(function(player)
		if not isParticipant(player) or taken[player.UserId] then
			return
		end
		taken[player.UserId] = true
		ctx.PlayerState.AddLoot(player, { [randomCore()] = 1 })
		ctx.PlayerState.Notify(player, "Bring den Kern sicher zurück, um ihn zu behalten!", "info")
	end)

	-- Versteck hinter dem Frostsiegel
	spawnChest(ctx.WorldBuilder.Points.Cache, true, false)
	spawnChest(ctx.WorldBuilder.Points.Cache + Vector3.new(6, 0, 8), true, false)
end

local function buildPortals()
	local folder = runFolder :: Folder
	local points = ctx.WorldBuilder.Points
	-- Außenposten: Beute sichern oder zurückkehren
	local outpost = ctx.WorldBuilder.Place("Return_Portal", points.OutpostPortal, 90, nil, folder)
	local anchor = ctx.WorldBuilder.PromptAnchor(outpost)
	local secure = ctx.WorldBuilder.Prompt(anchor, "Beute sichern", "Außenposten", 0.5, Enum.KeyCode.G)
	secure.Triggered:Connect(function(player)
		if isParticipant(player) and ctx.PlayerState.IsActive(player) then
			if not ctx.PlayerState.SecureLoot(player) then
				ctx.PlayerState.Notify(player, "Dein Rucksack ist leer.", "info")
			end
		end
	end)
	local back = ctx.WorldBuilder.Prompt(anchor, "Zurück ins Camp", "Rückkehrportal", 1)
	back.Triggered:Connect(function(player)
		if isParticipant(player) and ctx.PlayerState.IsActive(player) then
			Expedition.ReturnPlayer(player, true, true)
		end
	end)

	-- Rift-Kammer: öffnet nach dem Boss
	local arena = ctx.WorldBuilder.Place("Return_Portal", points.ArenaPortal, 0, nil, folder)
	arenaSurface = arena:FindFirstChild("Surface", true) :: BasePart?
	if arenaSurface then
		arenaSurface.Transparency = 1
	end
	arenaPortalPrompt = ctx.WorldBuilder.Prompt(ctx.WorldBuilder.PromptAnchor(arena), "Zurück ins Camp", "Rückkehrportal", 1)
	local ap = arenaPortalPrompt :: ProximityPrompt
	ap.Enabled = false
	ap.Triggered:Connect(function(player)
		if bossDead and isParticipant(player) and ctx.PlayerState.IsActive(player) then
			Expedition.ReturnPlayer(player, true, true)
		end
	end)
end

local function spawnBoss(partySize: number)
	local diff = Config.Difficulties[difficulty]
	local hpMult = diff.hp * (1 + Config.Boss.HPPerExtraPlayer * (partySize - 1))
	local points = ctx.WorldBuilder.Points
	local boss = ctx.Entities.SpawnEnemy("Hollow_Warden", points.ArenaCenter, {
		tag = TAG,
		hpMult = hpMult,
		dmgMult = diff.damage,
		lootMult = diff.loot,
		yaw = 0,
		onDeath = function()
			bossDead = true
			ReplicatedStorage:SetAttribute("BossActive", false)
			ctx.PlayerState.NotifyAll(participants, "Der Hollow Warden ist besiegt! Das Rückkehrportal ist offen.", "milestone")
			forParticipants(function(p)
				ctx.Progress.Milestone(p, "Warden")
				local w = ctx.PlayerState.GetWeapon(p)
				if w and w.forged then
					ctx.Progress.CompleteQuest(p, "Boss")
				end
			end)
			if arenaPortalPrompt then
				arenaPortalPrompt.Enabled = true
			end
			if arenaSurface then
				arenaSurface.Transparency = 0.25
			end
			ctx.PlayerState.SyncAll()
		end,
	})
	ctx.Entities.SetupBoss(boss, points.ArenaCenter)
end

local function populate(partySize: number)
	local diff = Config.Difficulties[difficulty]
	for _, section in ctx.WorldBuilder.Spawns do
		local hpMult = diff.hp * (section.hpMult or 1)
		for i, entry in shuffle(section.enemies) do
			if i > section.enemyCount then
				break
			end
			ctx.Entities.SpawnEnemy(entry[1], jitter(entry[2], 5), { tag = TAG, hpMult = hpMult, dmgMult = diff.damage, lootMult = diff.loot })
		end
		-- Zusätzliche Gegner für größere Gruppen
		for i = 1, partySize - 1 do
			local entry = section.enemies[math.random(1, #section.enemies)]
			if i <= 2 then
				ctx.Entities.SpawnEnemy(entry[1], jitter(entry[2], 8), { tag = TAG, hpMult = hpMult, dmgMult = diff.damage, lootMult = diff.loot })
			end
		end
		for i, pos in shuffle(section.nodes) do
			if i > section.nodeCount then
				break
			end
			spawnNode(section.nodeKinds[math.random(1, #section.nodeKinds)], jitter(pos, 3))
		end
		if section.chests then
			local mimics = section.mimicCount or 0
			for i, pos in shuffle(section.chests) do
				if i > section.chestCount then
					break
				end
				local mimic = mimics > 0 or math.random() < (section.mimicChance or 0)
				if mimics > 0 then
					mimics -= 1
				end
				spawnChest(pos, section.rare == true, mimic)
			end
		end
	end
	buildBarriers()
	buildPortals()
	spawnBoss(partySize)
end

--------------------------------------------------------------------------------
-- Ablauf
--------------------------------------------------------------------------------
local function endRun(reason: string?)
	ctx.Entities.ClearTag(TAG)
	if runFolder then
		runFolder:Destroy()
		runFolder = nil
	end
	for p, prompt in revivePrompts do
		prompt:Destroy()
		revivePrompts[p] = nil
	end
	phase = "Idle"
	participants = {}
	members = {}
	leader = nil
	bossDead = false
	arenaPortalPrompt = nil
	arenaSurface = nil
	disconnected = {}
	runStart = 0
	ReplicatedStorage:SetAttribute("RunStart", 0)
	ReplicatedStorage:SetAttribute("RiftDanger", 0)
	if reason then
		ctx.PlayerState.NotifyAll(Players:GetPlayers(), reason, "info")
	end
	ctx.PlayerState.SyncAll()
end

local function joinRun(player: Player)
	local s = ctx.PlayerState.Get(player)
	if not s then
		return
	end
	if not isParticipant(player) then
		table.insert(participants, player)
	end
	s.inRun = true
	s.backpack = {}
	s.protectedLoot = {}
	s.usedRecall = false
	s.recalling = false
	ctx.PlayerState.ResetVitals(player)
	teleport(player, ctx.WorldBuilder.Points.ZoneArrival)
	ctx.PlayerState.Sync(player)
end

-- Rift-Gefahr: je länger das Team bleibt, desto mehr Gegner tauchen auf.
local function dangerLoop(myStart: number)
	local cfg = Config.RiftDanger
	local level = 0
	local nextWave = 0
	while phase == "Running" and runStart == myStart do
		task.wait(1)
		if phase ~= "Running" or runStart ~= myStart then
			break
		end
		local delay = cfg.StartAfter
		for _, p in participants do
			local profile = ctx.DataService.Get(p)
			if profile and profile.upgrades.Watchtower then
				delay += cfg.TowerDelay
				break
			end
		end
		local t = workspace:GetServerTimeNow() - myStart
		local newLevel = if t < delay then 0 else math.min(cfg.MaxLevel, math.floor((t - delay) / cfg.LevelEvery) + 1)
		if newLevel ~= level then
			level = newLevel
			ReplicatedStorage:SetAttribute("RiftDanger", level)
			if level > 0 then
				ctx.PlayerState.NotifyAll(participants, "Die Rift-Gefahr steigt: Stufe " .. level .. ". Mehr Gegner strömen herbei!", "bad")
			end
		end
		if level > 0 and os.clock() >= nextWave then
			nextWave = os.clock() + cfg.WaveEvery
			local active = {}
			for _, p in participants do
				local root = ctx.PlayerState.GetRoot(p)
				if ctx.PlayerState.IsActive(p) and root and (root.Position - ctx.WorldBuilder.Points.ArenaCenter).Magnitude > 60 then
					table.insert(active, p)
				end
			end
			if #active > 0 then
				local target = active[math.random(1, #active)]
				local center = (ctx.PlayerState.GetRoot(target) :: BasePart).Position
				local diff = Config.Difficulties[difficulty]
				local count = math.min(6, level + #participants - 1)
				local kinds = { "Riftling", "Rift_Crawler" }
				if level >= 3 then
					table.insert(kinds, "Rootstalker")
				end
				for _ = 1, count do
					for _try = 1, 5 do
						local a = math.random() * math.pi * 2
						local pos = center + Vector3.new(math.cos(a) * 26, 0, math.sin(a) * 26)
						local ground = ctx.Entities.GroundAt(pos)
						if math.abs(ground.Y - center.Y) < 6 then
							ctx.Entities.SpawnEnemy(kinds[math.random(1, #kinds)], ground, {
								tag = TAG,
								hpMult = diff.hp * (1 + 0.1 * level),
								dmgMult = diff.damage,
								lootMult = 0.5,
							})
							break
						end
					end
				end
				Net.Event("Fx"):FireAllClients("RiftWave", center)
			end
		end
	end
end

local function launch()
	if phase ~= "Lobby" then
		return
	end
	local ready = {}
	for _, p in members do
		if p.Parent == Players and hasWeapon(p) and ctx.PlayerState.Get(p) then
			table.insert(ready, p)
		end
	end
	if #ready == 0 then
		endRun("Expedition abgebrochen – niemand ist bereit.")
		return
	end
	phase = "Running"
	participants = {}
	runStart = workspace:GetServerTimeNow()
	ReplicatedStorage:SetAttribute("RunStart", runStart)
	local folder = Instance.new("Folder")
	folder.Name = "RunObjects"
	folder.Parent = workspace
	runFolder = folder
	populate(#ready)
	ReplicatedStorage:SetAttribute("RiftDanger", 0)
	task.spawn(dangerLoop, runStart)
	for _, p in ready do
		joinRun(p)
	end
	ctx.PlayerState.NotifyAll(
		participants,
		"Verdant Scar (" .. Config.Difficulties[difficulty].name .. "). Sammle Beute, finde Elementkerne – und kehre rechtzeitig zurück!",
		"boss"
	)
	ctx.PlayerState.SyncAll()
end

-- Spieler verlässt die Expedition. secure = Beute sichern, survived = regulär zurückgekehrt.
function Expedition.ReturnPlayer(player: Player, secure: boolean, survived: boolean?)
	local s = ctx.PlayerState.Get(player)
	if not s then
		return
	end
	if secure then
		ctx.PlayerState.SecureLoot(player)
	end
	if survived then
		ctx.Progress.Milestone(player, "SurviveRun")
	end
	s.recalling = false
	removeFrom(participants, player)
	local prompt = revivePrompts[player]
	if prompt then
		prompt:Destroy()
		revivePrompts[player] = nil
	end
	s.inRun = false
	s.backpack = {}
	s.protectedLoot = {}
	local hum = ctx.PlayerState.GetHumanoid(player)
	if hum and hum.Health > 0 then
		ctx.PlayerState.ResetVitals(player)
		teleport(player, ctx.WorldBuilder.Points.CampArrival)
	end
	ctx.PlayerState.Sync(player)
	if phase == "Running" and #participants == 0 then
		endRun(nil)
	end
end

local function checkWipe()
	if phase ~= "Running" or #participants == 0 then
		return
	end
	for _, p in participants do
		local s = ctx.PlayerState.Get(p)
		if s and not s.downed then
			return
		end
	end
	-- Teamwipe
	local list = table.clone(participants)
	ctx.PlayerState.NotifyAll(list, "Das Team ist gefallen. Ein Teil der ungesicherten Grundmaterialien ist verloren.", "bad")
	task.wait(2.5)
	for _, p in list do
		local s = ctx.PlayerState.Get(p)
		if s and s.inRun then
			ctx.PlayerState.LoseLoot(p, 0.5)
			Expedition.ReturnPlayer(p, true)
		end
	end
end

function Expedition.OnPlayerDowned(player: Player)
	if not isParticipant(player) then
		return
	end
	ctx.PlayerState.Notify(player, "Du bist niedergeschlagen! Ein Teammitglied kann dich wiederbeleben.", "bad")
	for _, p in participants do
		if p ~= player then
			ctx.PlayerState.Notify(p, player.DisplayName .. " ist niedergeschlagen – belebe ihn/sie wieder (E halten)!", "bad")
		end
	end
	local root = ctx.PlayerState.GetRoot(player)
	if root then
		local prompt = ctx.WorldBuilder.Prompt(root, "Wiederbeleben", player.DisplayName, Config.Player.ReviveTime)
		prompt.Triggered:Connect(function(helper)
			if helper == player or not isParticipant(helper) or not ctx.PlayerState.IsActive(helper) then
				return
			end
			prompt:Destroy()
			revivePrompts[player] = nil
			ctx.PlayerState.Revive(player, Config.Player.ReviveHealth)
			ctx.PlayerState.Notify(player, helper.DisplayName .. " hat dich wiederbelebt!", "good")
		end)
		revivePrompts[player] = prompt
	end
	local s = ctx.PlayerState.Get(player)
	local downedAt = s and s.downedAt
	task.delay(Config.Player.BleedoutTime, function()
		local cur = ctx.PlayerState.Get(player)
		if cur and cur.downed and cur.inRun and cur.downedAt == downedAt then
			Expedition.OnPlayerOut(player, "bleedout")
		end
	end)
	task.spawn(checkWipe)
end

-- Spieler scheidet aus (Ausbluten, Sturz): Teilverlust, zurück ins Camp.
function Expedition.OnPlayerOut(player: Player, reason: string)
	if not isParticipant(player) then
		return
	end
	ctx.PlayerState.LoseLoot(player, 0.5)
	ctx.PlayerState.Notify(player, if reason == "fall" then "Du bist abgestürzt." else "Du hast es nicht geschafft und kehrst ins Camp zurück.", "bad")
	Expedition.ReturnPlayer(player, true)
	task.spawn(checkWipe)
end

function Expedition.OnPlayerLeft(player: Player, s: any)
	disconnected[player.UserId] = { backpack = s.backpack, protectedLoot = s.protectedLoot }
	removeFrom(participants, player)
	removeFrom(members, player)
	local prompt = revivePrompts[player]
	if prompt then
		prompt:Destroy()
		revivePrompts[player] = nil
	end
	if phase == "Running" and #participants == 0 then
		endRun(nil)
	else
		task.spawn(checkWipe)
	end
end

-- Nach Verbindungsabbruch: zurück in den laufenden Lauf, Rucksack bleibt erhalten.
function Expedition.TryRestore(player: Player)
	local saved = disconnected[player.UserId]
	if not saved or phase ~= "Running" or #participants >= MAX_PARTY then
		return
	end
	disconnected[player.UserId] = nil
	joinRun(player)
	local s = ctx.PlayerState.Get(player)
	if s then
		s.backpack = saved.backpack
		s.protectedLoot = saved.protectedLoot
	end
	ctx.PlayerState.Notify(player, "Willkommen zurück – dein Rucksack ist noch da.", "good")
	ctx.PlayerState.Sync(player)
end

--------------------------------------------------------------------------------
-- Anfragen von der Tafel
--------------------------------------------------------------------------------
function Expedition.Handle(player: Player, action: string, a: any): boolean
	if action == "ExpCreate" then
		if phase ~= "Idle" then
			ctx.PlayerState.Notify(player, "Es läuft bereits eine Expedition.", "bad")
		elseif not hasWeapon(player) then
			ctx.PlayerState.Notify(player, "Schmiede zuerst eine Waffe!", "bad")
		else
			difficulty = if a == "Hard" then "Hard" else "Normal"
			phase = "Lobby"
			leader = player
			members = { player }
			lobbyEnds = workspace:GetServerTimeNow() + LOBBY_TIME
			local myEnds = lobbyEnds
			ctx.PlayerState.NotifyAll(
				Players:GetPlayers(),
				player.DisplayName .. " plant eine Expedition (" .. Config.Difficulties[difficulty].name .. "). An der Tafel beitreten!",
				"info"
			)
			task.delay(LOBBY_TIME, function()
				if phase == "Lobby" and lobbyEnds == myEnds then
					launch()
				end
			end)
		end
	elseif action == "ExpJoin" then
		if not hasWeapon(player) then
			ctx.PlayerState.Notify(player, "Schmiede zuerst eine Waffe!", "bad")
		elseif phase == "Lobby" then
			if not table.find(members, player) and #members < MAX_PARTY then
				table.insert(members, player)
			end
		elseif phase == "Running" then
			local s = ctx.PlayerState.Get(player)
			if s and not s.inRun and #participants < MAX_PARTY then
				joinRun(player)
				ctx.PlayerState.NotifyAll(participants, player.DisplayName .. " ist der Expedition beigetreten.", "info")
			end
		end
	elseif action == "ExpLeave" then
		removeFrom(members, player)
		if phase == "Lobby" then
			if #members == 0 then
				endRun(nil)
			elseif leader == player then
				leader = members[1]
			end
		end
	elseif action == "ExpLaunch" then
		if phase == "Lobby" and leader == player then
			launch()
		end
	elseif action == "ExpDifficulty" then
		if phase == "Lobby" and leader == player then
			difficulty = if a == "Hard" then "Hard" else "Normal"
		end
	elseif action == "ExpAbandon" then
		-- Expedition freiwillig verlassen (ohne Portal): wie Ausscheiden
		local s = ctx.PlayerState.Get(player)
		if s and s.inRun then
			Expedition.OnPlayerOut(player, "abandon")
		end
	else
		return false
	end
	ctx.PlayerState.SyncAll()
	return true
end

function Expedition.Init(context)
	ctx = context
end

function Expedition.Start()
	Players.PlayerRemoving:Connect(function(player)
		removeFrom(members, player)
		if phase == "Lobby" and #members == 0 then
			endRun(nil)
		elseif leader == player then
			leader = members[1]
		end
	end)
end

return Expedition
