--!nonstrict
-- Laufzeitzustand der Spieler: Leben, Ausdauer, Elementladung, Rucksack,
-- ausgerüstete Waffe und Synchronisation zum Client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

export type State = {
	hp: number,
	stamina: number,
	charge: number,
	lastStaminaUse: number,
	iframesUntil: number,
	lastDodge: number,
	cooldownUntil: number,
	downed: boolean,
	downedAt: number,
	rootedUntil: number,
	stormCharge: number,
	perfectDodgeUntil: number,
	inRun: boolean,
	backpack: { [string]: number },
	protectedLoot: { [string]: number },
}

local PlayerState = {}
local ctx: any

local states: { [Player]: State } = {}
local syncQueued: { [Player]: boolean } = {}

local StateEvent = Net.Event("State")
local NotifyEvent = Net.Event("Notify")

local function newState(): State
	return {
		hp = Config.Player.MaxHP,
		stamina = Config.Player.MaxStamina,
		charge = 0,
		lastStaminaUse = 0,
		iframesUntil = 0,
		lastDodge = 0,
		cooldownUntil = 0,
		downed = false,
		downedAt = 0,
		rootedUntil = 0,
		stormCharge = 0,
		perfectDodgeUntil = 0,
		inRun = false,
		backpack = {},
		protectedLoot = {},
	}
end

function PlayerState.Init(context)
	ctx = context
end

function PlayerState.Get(player: Player): State?
	return states[player]
end

function PlayerState.Notify(player: Player, text: string, kind: string?)
	NotifyEvent:FireClient(player, text, kind or "info")
end

function PlayerState.NotifyAll(players: { Player }, text: string, kind: string?)
	for _, p in players do
		NotifyEvent:FireClient(p, text, kind or "info")
	end
end

function PlayerState.GetRoot(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function PlayerState.GetHumanoid(player: Player): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

function PlayerState.IsActive(player: Player): boolean
	local s = states[player]
	local hum = PlayerState.GetHumanoid(player)
	return s ~= nil and not s.downed and hum ~= nil and hum.Health > 0
end

--------------------------------------------------------------------------------
-- Waffe
--------------------------------------------------------------------------------
function PlayerState.GetWeapon(player: Player): any?
	local profile = ctx.DataService.Get(player)
	if not profile or not profile.equipped then
		return nil
	end
	for _, w in profile.weapons do
		if w.id == profile.equipped then
			return w
		end
	end
	return nil
end

function PlayerState.WeaponColors(w: any): { Color3 }
	local colors = {}
	if w.e1 then
		table.insert(colors, Config.Elements[w.e1].color)
	end
	if w.e2 then
		table.insert(colors, Config.Elements[w.e2].color)
	end
	if #colors == 0 then
		table.insert(colors, Color3.fromRGB(150, 160, 170))
	end
	return colors
end

function PlayerState.AttachWeapon(player: Player)
	local char = player.Character
	if not char then
		return
	end
	local old = char:FindFirstChild("Weapon")
	if old then
		old:Destroy()
	end
	local w = PlayerState.GetWeapon(player)
	if not w then
		return
	end
	local hand = (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")) :: BasePart?
	if not hand then
		return
	end
	local model = ctx.AssetLoader.Weapon(w.form, PlayerState.WeaponColors(w), w.quality)
	local handle = model.PrimaryPart :: BasePart
	local weld = Instance.new("Weld")
	weld.Part0 = hand
	weld.Part1 = handle
	local down = if hand.Name == "RightHand" then -0.15 else -0.9
	weld.C0 = CFrame.new(0, down, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	weld.Parent = handle
	model:SetAttribute("Form", w.form)
	model.Parent = char
end

--------------------------------------------------------------------------------
-- Synchronisation
--------------------------------------------------------------------------------
function PlayerState.Sync(player: Player)
	if syncQueued[player] then
		return
	end
	syncQueued[player] = true
	task.defer(function()
		syncQueued[player] = nil
		local profile = ctx.DataService.Get(player)
		local s = states[player]
		if not profile or not s or player.Parent ~= Players then
			return
		end
		StateEvent:FireClient(player, {
			stash = profile.stash,
			weapons = profile.weapons,
			equipped = profile.equipped,
			unlocked = profile.unlocked,
			blueprints = profile.blueprints,
			milestones = profile.milestones,
			quests = profile.quests,
			backpack = s.backpack,
			protectedLoot = s.protectedLoot,
			inRun = s.inRun,
			expedition = ctx.Expedition.PublicInfo(),
		})
	end)
end

function PlayerState.SyncAll()
	for player in states do
		PlayerState.Sync(player)
	end
end

--------------------------------------------------------------------------------
-- Leben, Schaden, Niederschlag
--------------------------------------------------------------------------------
local function applyAttributes(player: Player, s: State)
	player:SetAttribute("HP", math.floor(s.hp + 0.5))
	player:SetAttribute("MaxHP", Config.Player.MaxHP)
	player:SetAttribute("Stamina", math.floor(s.stamina))
	player:SetAttribute("Charge", math.floor(s.charge))
	player:SetAttribute("Downed", s.downed)
	player:SetAttribute("InRun", s.inRun)
	player:SetAttribute(
		"HasElement",
		(function()
			local w = PlayerState.GetWeapon(player)
			return w ~= nil and w.e1 ~= nil
		end)()
	)
end

local function updateMovement(player: Player, s: State)
	local hum = PlayerState.GetHumanoid(player)
	if not hum then
		return
	end
	local speed = Config.Player.WalkSpeed
	if s.downed then
		speed = 4
	elseif s.rootedUntil > os.clock() then
		speed = 0
	end
	hum.WalkSpeed = speed
	hum.JumpPower = if s.downed or s.rootedUntil > os.clock() then 0 else 50
	hum.UseJumpPower = true
end

-- Liefert true, wenn der Schaden wirklich getroffen hat.
function PlayerState.Damage(player: Player, amount: number, _source: string?): boolean
	local s = states[player]
	if not s or s.downed or not s.inRun then
		return false
	end
	local now = os.clock()
	if s.iframesUntil > now then
		-- Perfektes Ausweichen
		s.perfectDodgeUntil = now + 2
		Net.Event("Fx"):FireAllClients("PerfectDodge", player)
		return false
	end
	s.hp = math.max(0, s.hp - amount)
	local hum = PlayerState.GetHumanoid(player)
	if hum then
		hum.Health = math.max(1, (s.hp / Config.Player.MaxHP) * hum.MaxHealth)
	end
	Net.Event("Fx"):FireAllClients("PlayerHit", player, amount)
	if s.hp <= 0 then
		s.downed = true
		s.downedAt = now
		s.charge = 0
		ctx.Expedition.OnPlayerDowned(player)
	end
	applyAttributes(player, s)
	updateMovement(player, s)
	return true
end

function PlayerState.Heal(player: Player, fraction: number)
	local s = states[player]
	if not s then
		return
	end
	s.hp = math.min(Config.Player.MaxHP, s.hp + Config.Player.MaxHP * fraction)
	local hum = PlayerState.GetHumanoid(player)
	if hum then
		hum.Health = math.max(1, (s.hp / Config.Player.MaxHP) * hum.MaxHealth)
	end
	applyAttributes(player, s)
end

function PlayerState.Revive(player: Player, fraction: number)
	local s = states[player]
	if not s then
		return
	end
	s.downed = false
	s.hp = 0
	PlayerState.Heal(player, fraction)
	updateMovement(player, s)
	applyAttributes(player, s)
end

function PlayerState.ResetVitals(player: Player)
	local s = states[player]
	if not s then
		return
	end
	s.downed = false
	s.hp = Config.Player.MaxHP
	s.stamina = Config.Player.MaxStamina
	s.rootedUntil = 0
	s.stormCharge = 0
	local hum = PlayerState.GetHumanoid(player)
	if hum then
		hum.Health = hum.MaxHealth
	end
	updateMovement(player, s)
	applyAttributes(player, s)
end

function PlayerState.Root(player: Player, duration: number)
	local s = states[player]
	if not s then
		return
	end
	s.rootedUntil = os.clock() + duration
	updateMovement(player, s)
	task.delay(duration + 0.05, function()
		if states[player] == s then
			updateMovement(player, s)
		end
	end)
end

function PlayerState.UseStamina(player: Player, amount: number): boolean
	local s = states[player]
	if not s or s.stamina < amount then
		return false
	end
	s.stamina -= amount
	s.lastStaminaUse = os.clock()
	return true
end

function PlayerState.AddCharge(player: Player, amount: number)
	local s = states[player]
	local w = PlayerState.GetWeapon(player)
	if not s or not w or not w.e1 then
		return
	end
	local mult = Config.Forms[w.form].chargeMult
	s.charge = math.min(100, s.charge + amount * mult)
end

--------------------------------------------------------------------------------
-- Rucksack (ungesicherte Expeditionsbeute)
--------------------------------------------------------------------------------
function PlayerState.AddLoot(player: Player, items: { [string]: number }, protected: boolean?)
	local s = states[player]
	if not s then
		return
	end
	local bag = if protected then s.protectedLoot else s.backpack
	local parts = {}
	for item, n in items do
		if n > 0 and Config.Items[item] then
			bag[item] = (bag[item] or 0) + n
			table.insert(parts, "+" .. n .. " " .. Config.Items[item].name)
		end
	end
	if #parts > 0 then
		PlayerState.Notify(player, table.concat(parts, "   "), if protected then "loot_protected" else "loot")
	end
	PlayerState.Sync(player)
end

-- Verschiebt den Rucksack ins dauerhafte Lager.
function PlayerState.SecureLoot(player: Player): boolean
	local s = states[player]
	if not s then
		return false
	end
	local any = next(s.backpack) ~= nil or next(s.protectedLoot) ~= nil
	ctx.DataService.Give(player, s.backpack)
	ctx.DataService.Give(player, s.protectedLoot)
	if (s.backpack.PartStalkerBark or 0) > 0 or (s.protectedLoot.PartStalkerBark or 0) > 0 then
		ctx.Progress.CompleteQuest(player, "Hunter")
	end
	local hasCore = false
	for _, e in Config.Elements do
		if (s.backpack[e.core] or 0) > 0 or (s.protectedLoot[e.core] or 0) > 0 then
			hasCore = true
		end
	end
	if hasCore then
		ctx.Progress.Milestone(player, "FirstCore")
	end
	s.backpack = {}
	s.protectedLoot = {}
	if any then
		PlayerState.Notify(player, "Beute gesichert!", "good")
	end
	PlayerState.Sync(player)
	return any
end

-- Verlust bei Niederlage: ein Teil der ungesicherten Grundmaterialien geht verloren.
function PlayerState.LoseLoot(player: Player, fraction: number)
	local s = states[player]
	if not s then
		return
	end
	local lost = 0
	for item, n in s.backpack do
		if Config.Items[item].kind == "Basic" then
			local loss = math.floor(n * fraction + 0.5)
			s.backpack[item] = n - loss
			lost += loss
			if s.backpack[item] <= 0 then
				s.backpack[item] = nil
			end
		end
	end
	if lost > 0 then
		PlayerState.Notify(player, lost .. " Grundmaterialien verloren. Kerne, Monsterteile und Bossbeute bleiben erhalten.", "bad")
	end
	PlayerState.Sync(player)
end

--------------------------------------------------------------------------------
-- Lebenszyklus
--------------------------------------------------------------------------------
local function onCharacter(player: Player, char: Model)
	local s = states[player]
	if not s then
		return
	end
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	s.inRun = false
	s.charge = 0
	PlayerState.ResetVitals(player)
	hum.BreakJointsOnDeath = false
	hum.Died:Connect(function()
		if states[player] == s and s.inRun then
			ctx.Expedition.OnPlayerOut(player, "fall")
		end
	end)
	task.defer(PlayerState.AttachWeapon, player)
	task.defer(ctx.Expedition.TryRestore, player)
	PlayerState.Sync(player)
end

function PlayerState.OnProfileLoaded(player: Player)
	states[player] = newState()
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	ctx.Progress.OnLoaded(player)
	PlayerState.Sync(player)
end

function PlayerState.Start()
	Players.PlayerRemoving:Connect(function(player)
		local s = states[player]
		if s and s.inRun then
			ctx.Expedition.OnPlayerLeft(player, s)
		end
		states[player] = nil
	end)

	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for player, s in states do
			if not s.downed and now - s.lastStaminaUse > Config.Player.StaminaDelay then
				s.stamina = math.min(Config.Player.MaxStamina, s.stamina + Config.Player.StaminaRegen * dt)
			end
		end
		accum += dt
		if accum >= 0.1 then
			accum = 0
			for player, s in states do
				applyAttributes(player, s)
				if s.rootedUntil > 0 and s.rootedUntil < now then
					s.rootedUntil = 0
					updateMovement(player, s)
				end
			end
		end
	end)
end

return PlayerState
