--!nonstrict
-- Entities: alles, was Schaden nehmen kann (Gegner, Boss, Übungspuppen,
-- Barrieren, Riftkristalle) inkl. Statuseffekte und Gegner-KI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Entities = {}
local ctx: any

export type Entity = {
	id: number,
	kind: string,
	name: string,
	def: any?,
	model: Model,
	root: BasePart,
	humanoid: Humanoid?,
	hp: number,
	maxHp: number,
	dead: boolean,
	isEnemy: boolean,
	isBoss: boolean,
	isDummy: boolean,
	light: boolean,
	requires: { string }?,
	shield: boolean,
	dmgMult: number,
	lootMult: number,
	tag: string,
	home: Vector3,
	status: {
		burnStacks: number,
		burnUntil: number,
		nextBurn: number,
		frostStacks: number,
		slowUntil: number,
		frozenUntil: number,
		stunnedUntil: number,
		markUntil: number,
		thermoCount: number,
		thermoHot: boolean,
	},
	ai: { [string]: any },
	pristine: boolean,
	lastHitBy: Player?,
	onDeath: ((Entity, Player?) -> ())?,
	bar: Frame?,
	radius: number,
}

local FxEvent = Net.Event("Fx")

local entities: { [number]: Entity } = {}
local byModel: { [Model]: Entity } = {}
local nextId = 0

local folder: Folder
local telegraphFolder: Folder

--------------------------------------------------------------------------------
-- Hilfen
--------------------------------------------------------------------------------
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundAt(pos: Vector3): Vector3
	local filter: { Instance } = { folder, telegraphFolder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(filter, p.Character)
		end
	end
	groundParams.FilterDescendantsInstances = filter
	local hit = workspace:Raycast(pos + Vector3.new(0, 8, 0), Vector3.new(0, -40, 0), groundParams)
	return if hit then hit.Position else Vector3.new(pos.X, 0, pos.Z)
end
Entities.GroundAt = groundAt

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function makeBar(e: Entity, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HPBar"
	gui.Size = UDim2.fromOffset(if e.isBoss then 0 else 90, 22)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.Enabled = not e.isBoss
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0, 12)
	name.BackgroundTransparency = 1
	name.Text = e.name
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.4
	name.Font = Enum.Font.GothamBold
	name.TextSize = 11
	name.Parent = gui
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 14)
	back.Size = UDim2.new(1, 0, 0, 7)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = if e.isDummy then Color3.fromRGB(200, 180, 110) else Color3.fromRGB(220, 70, 70)
	fill.BorderSizePixel = 0
	fill.Parent = back
	gui.Parent = e.root
	e.bar = fill
end

local function updateBar(e: Entity)
	if e.bar then
		e.bar.Size = UDim2.fromScale(math.clamp(e.hp / e.maxHp, 0, 1), 1)
	end
	if e.isBoss then
		ReplicatedStorage:SetAttribute("BossHP", math.max(0, math.floor(e.hp)))
		ReplicatedStorage:SetAttribute("BossMaxHP", math.floor(e.maxHp))
	end
end

local function setHighlight(e: Entity, color: Color3?)
	local h = e.model:FindFirstChild("StatusHighlight") :: Highlight?
	if not color then
		if h then
			h:Destroy()
		end
		return
	end
	if not h then
		local nh = Instance.new("Highlight")
		nh.Name = "StatusHighlight"
		nh.FillTransparency = 0.55
		nh.OutlineTransparency = 0
		nh.DepthMode = Enum.HighlightDepthMode.Occluded
		nh.Parent = e.model
		h = nh
	end
	local hl = h :: Highlight
	hl.FillColor = color
	hl.OutlineColor = color
end

local function register(e: Entity)
	entities[e.id] = e
	byModel[e.model] = e
	e.model:SetAttribute("EntityId", e.id)
end

local function newEntity(kind: string, name: string, model: Model, root: BasePart, hp: number): Entity
	nextId += 1
	local e: Entity = {
		id = nextId,
		kind = kind,
		name = name,
		def = nil,
		model = model,
		root = root,
		humanoid = nil,
		hp = hp,
		maxHp = hp,
		dead = false,
		isEnemy = false,
		isBoss = false,
		isDummy = false,
		light = false,
		requires = nil,
		shield = false,
		dmgMult = 1,
		lootMult = 1,
		tag = "",
		home = root.Position,
		status = {
			burnStacks = 0,
			burnUntil = 0,
			nextBurn = 0,
			frostStacks = 0,
			slowUntil = 0,
			frozenUntil = 0,
			stunnedUntil = 0,
			markUntil = 0,
			thermoCount = 0,
			thermoHot = false,
		},
		ai = {},
		pristine = true,
		lastHitBy = nil,
		onDeath = nil,
		bar = nil,
		radius = math.max(root.Size.X, root.Size.Z) / 2,
	}
	return e
end

--------------------------------------------------------------------------------
-- Erzeugen
--------------------------------------------------------------------------------
export type SpawnOpts = {
	tag: string?,
	hpMult: number?,
	dmgMult: number?,
	lootMult: number?,
	onDeath: ((Entity, Player?) -> ())?,
	dormant: boolean?,
	yaw: number?,
}

function Entities.SpawnEnemy(kind: string, pos: Vector3, opts: SpawnOpts?): Entity
	local o = opts or {} :: SpawnOpts
	local def = Config.Enemies[kind]
	assert(def, "Unbekannter Gegner " .. kind)
	local ground = groundAt(pos)
	local scale = def.height / 5
	local model = Instance.new("Model")
	model.Name = kind

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1) * math.max(scale, 0.5)
	root.Transparency = 1
	root.CanCollide = true
	root.CanQuery = true
	root.CanTouch = false
	local yaw = CFrame.Angles(0, math.rad(o.yaw or math.random(0, 359)), 0)
	root.CFrame = CFrame.new(ground + Vector3.new(0, def.hip + root.Size.Y / 2, 0)) * yaw
	root.Parent = model

	local visual = ctx.AssetLoader.Model(kind, def.height)
	local lift = if kind == "Lantern_Wraith" then def.hip - 1.2 else 0
	visual:PivotTo(CFrame.new(ground + Vector3.new(0, lift, 0)) * yaw)
	for _, d in visual:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = true
			d.CanTouch = false
			d.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
		end
	end
	visual.Name = "Visual"
	visual.Parent = model

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = def.hip
	hum.WalkSpeed = if o.dormant then 0 else def.speed
	hum.MaxHealth = 1e6
	hum.Health = 1e6
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.Parent = model
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

	model.PrimaryPart = root
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local hp = def.hp * (o.hpMult or 1)
	local e = newEntity(kind, def.name, model, root, hp)
	e.def = def
	e.humanoid = hum
	e.isEnemy = true
	e.isBoss = kind == "Hollow_Warden"
	e.light = def.light
	e.dmgMult = o.dmgMult or 1
	e.lootMult = o.lootMult or 1
	e.tag = o.tag or ""
	e.home = ground
	e.onDeath = o.onDeath
	e.radius = if e.isBoss then 4 else e.radius
	e.ai = { nextAttack = os.clock() + 1, token = 0, busyUntil = 0, dormant = o.dormant or false, side = if math.random() < 0.5 then -1 else 1 }
	if kind == "Lantern_Wraith" then
		hum.HipHeight = def.hip
	end
	makeBar(e, root.Size.Y / 2 + def.height - def.hip + 1)
	register(e)
	return e
end

export type StaticOpts = {
	kind: string,
	name: string,
	hp: number,
	requires: { string }?,
	shield: boolean?,
	dummy: boolean?,
	tag: string?,
	onDeath: ((Entity, Player?) -> ())?,
	barHeight: number?,
}

-- Registriert ein vorhandenes Modell als beschädigbares Objekt (ohne KI).
function Entities.RegisterStatic(model: Model, o: StaticOpts): Entity
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true) :: BasePart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = true
		end
	end
	local e = newEntity(o.kind, o.name, model, root, o.hp)
	e.requires = o.requires
	e.shield = o.shield or false
	e.isDummy = o.dummy or false
	e.light = true
	e.tag = o.tag or ""
	e.onDeath = o.onDeath
	local _, size = model:GetBoundingBox()
	e.radius = math.max(size.X, size.Z) / 2
	if model.Parent ~= folder then
		model.Parent = folder
	end
	makeBar(e, o.barHeight or (size.Y / 2 + 1.5))
	register(e)
	return e
end

--------------------------------------------------------------------------------
-- Abfragen
--------------------------------------------------------------------------------
function Entities.FromPart(part: Instance): Entity?
	local node: Instance? = part
	while node and node ~= folder do
		if node:IsA("Model") and byModel[node] then
			return byModel[node]
		end
		node = node.Parent
	end
	return nil
end

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

function Entities.InBox(cf: CFrame, size: Vector3): { Entity }
	overlap.FilterDescendantsInstances = { folder }
	local found: { [Entity]: boolean } = {}
	local list = {}
	for _, part in workspace:GetPartBoundsInBox(cf, size, overlap) do
		local e = Entities.FromPart(part)
		if e and not e.dead and not found[e] then
			found[e] = true
			table.insert(list, e)
		end
	end
	return list
end

function Entities.InRadius(pos: Vector3, radius: number, exclude: Entity?): { Entity }
	local list = {}
	for _, e in entities do
		if not e.dead and e ~= exclude then
			local d = (flat(e.root.Position) - flat(pos)).Magnitude - e.radius
			if d <= radius and math.abs(e.root.Position.Y - pos.Y) < 25 then
				table.insert(list, e)
			end
		end
	end
	return list
end

function Entities.Nearest(pos: Vector3, radius: number, filter: ((Entity) -> boolean)?): Entity?
	local best, bestD = nil, radius
	for _, e in entities do
		if not e.dead and (not filter or filter(e)) then
			local d = (e.root.Position - pos).Magnitude - e.radius
			if d < bestD then
				best, bestD = e, d
			end
		end
	end
	return best
end

--------------------------------------------------------------------------------
-- Schaden & Tod
--------------------------------------------------------------------------------
local function rollDrops(e: Entity): { [string]: number }
	local items = {}
	if not e.def then
		return items
	end
	for _, d in e.def.drops do
		local chance = math.min(1, d.chance * (if Config.Items[d.item].kind == "Basic" then 1 else e.lootMult))
		if math.random() <= chance then
			local n = math.random(d.min, d.max)
			if Config.Items[d.item].kind == "Basic" then
				n = math.max(1, math.floor(n * e.lootMult + 0.5))
			end
			items[d.item] = (items[d.item] or 0) + n
		end
	end
	return items
end

local function die(e: Entity, killer: Player?)
	if e.dead then
		return
	end
	e.dead = true
	e.hp = 0
	updateBar(e)
	e.ai.token = (e.ai.token or 0) + 1
	FxEvent:FireAllClients("Death", e.root.Position, e.isBoss)
	if e.isEnemy then
		local participants = ctx.Expedition.Participants()
		for _, p in participants do
			if ctx.PlayerState.IsActive(p) or p == killer then
				local drops = rollDrops(e)
				ctx.PlayerState.AddLoot(p, drops, e.isBoss)
			end
		end
	end
	if e.onDeath then
		task.spawn(e.onDeath, e, killer)
	end
	entities[e.id] = nil
	byModel[e.model] = nil
	for _, d in e.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.CanCollide = false
			TweenService:Create(d, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end
	end
	task.delay(0.6, function()
		e.model:Destroy()
	end)
end

export type DamageInfo = {
	player: Player?,
	elements: { string }?,
	heavy: boolean?,
	color: Color3?,
	silent: boolean?,
	shieldMult: number?,
}

-- Fügt Schaden zu und liefert den tatsächlich verursachten Wert.
function Entities.Damage(e: Entity, amount: number, info: DamageInfo?): number
	local i = info or {} :: DamageInfo
	if e.dead or amount <= 0 then
		return 0
	end
	if e.requires then
		local ok = false
		for _, el in i.elements or {} do
			if table.find(e.requires, el) then
				ok = true
			end
		end
		if not ok then
			if i.player then
				local names = {}
				for _, el in e.requires do
					table.insert(names, Config.Elements[el].name)
				end
				ctx.PlayerState.Notify(i.player, e.name .. ": braucht eine Waffe mit " .. table.concat(names, " oder "), "bad")
			end
			FxEvent:FireAllClients("Immune", e.root.Position)
			return 0
		end
	end
	if e.shield and i.shieldMult then
		amount *= i.shieldMult
	end
	e.pristine = false
	e.lastHitBy = i.player or e.lastHitBy
	e.hp -= amount
	if not i.silent then
		FxEvent:FireAllClients("Damage", e.root.Position + Vector3.new(0, e.root.Size.Y / 2 + 1, 0), math.floor(amount + 0.5), i.color)
	end
	if e.isDummy then
		if e.hp <= 0 then
			e.hp = e.maxHp
		end
		updateBar(e)
		return amount
	end
	if e.ai.dormant then
		Entities.Wake(e)
	end
	updateBar(e)
	if e.hp <= 0 then
		die(e, i.player)
	end
	return amount
end

function Entities.Kill(e: Entity)
	die(e, nil)
end

--------------------------------------------------------------------------------
-- Statuseffekte (werden vom Kampfsystem gesetzt)
--------------------------------------------------------------------------------
function Entities.Interrupt(e: Entity, stun: number)
	if e.dead or e.isBoss then
		return
	end
	e.ai.token = (e.ai.token or 0) + 1
	if e.ai.telegraph then
		e.ai.telegraph:Destroy()
		e.ai.telegraph = nil
	end
	e.status.stunnedUntil = math.max(e.status.stunnedUntil, os.clock() + stun)
end

function Entities.AddBurn(e: Entity, stacks: number, player: Player?)
	local s = e.status
	s.burnStacks = math.min(6, s.burnStacks + stacks)
	s.burnUntil = os.clock() + 3.5
	if s.nextBurn < os.clock() then
		s.nextBurn = os.clock() + 0.5
	end
	e.lastHitBy = player or e.lastHitBy
	if not e.root:FindFirstChild("BurnFire") then
		local f = Instance.new("Fire")
		f.Name = "BurnFire"
		f.Size = 3
		f.Heat = 4
		f.Parent = e.root
	end
end

-- Liefert true, wenn das Ziel durch diesen Treffer eingefroren wurde.
function Entities.AddFrost(e: Entity, stacks: number): boolean
	local s = e.status
	local now = os.clock()
	s.slowUntil = now + 2.5
	if s.frozenUntil > now then
		return false
	end
	s.frostStacks += stacks
	if s.frostStacks >= 4 then
		s.frostStacks = 0
		if e.light then
			s.frozenUntil = now + 1.6
			Entities.Interrupt(e, 0)
			setHighlight(e, Color3.fromRGB(150, 220, 255))
			FxEvent:FireAllClients("Freeze", e.root.Position)
			return true
		end
	end
	return false
end

function Entities.Mark(e: Entity)
	e.status.markUntil = os.clock() + 6
end

function Entities.IsMarked(e: Entity): boolean
	return e.status.markUntil > os.clock()
end

function Entities.ConsumeMark(e: Entity): boolean
	if e.status.markUntil > os.clock() then
		e.status.markUntil = 0
		return true
	end
	return false
end

function Entities.Freeze(e: Entity, duration: number)
	if not e.light then
		e.status.slowUntil = os.clock() + duration
		return
	end
	e.status.frozenUntil = os.clock() + duration
	e.status.frostStacks = 0
	Entities.Interrupt(e, 0)
	setHighlight(e, Color3.fromRGB(150, 220, 255))
end

--------------------------------------------------------------------------------
-- Telegraphen (angekündigte Angriffe)
--------------------------------------------------------------------------------
local TELEGRAPH_COLOR = Color3.fromRGB(255, 70, 50)

function Entities.TelegraphCircle(center: Vector3, radius: number, duration: number, color: Color3?): BasePart
	local g = groundAt(center)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.15, radius * 2, radius * 2)
	p.CFrame = CFrame.new(g + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color or TELEGRAPH_COLOR
	p.Transparency = 0.75
	p.Parent = telegraphFolder
	TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Transparency = 0.35 }):Play()
	return p
end

function Entities.TelegraphRect(from: Vector3, dir: Vector3, width: number, length: number, duration: number): BasePart
	local g = groundAt(from)
	local d = flat(dir).Unit
	local center = g + d * (length / 2) + Vector3.new(0, 0.12, 0)
	local p = Instance.new("Part")
	p.Size = Vector3.new(width, 0.15, length)
	p.CFrame = CFrame.lookAt(center, center + d)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = TELEGRAPH_COLOR
	p.Transparency = 0.75
	p.Parent = telegraphFolder
	TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Transparency = 0.35 }):Play()
	return p
end

local function playersInCircle(center: Vector3, radius: number): { Player }
	local list = {}
	for _, p in ctx.Expedition.Participants() do
		local root = ctx.PlayerState.GetRoot(p)
		if root and (flat(root.Position) - flat(center)).Magnitude <= radius + 1 and math.abs(root.Position.Y - center.Y) < 12 then
			table.insert(list, p)
		end
	end
	return list
end

local function playersInRect(part: BasePart): { Player }
	local list = {}
	for _, p in ctx.Expedition.Participants() do
		local root = ctx.PlayerState.GetRoot(p)
		if root then
			local rel = part.CFrame:PointToObjectSpace(root.Position)
			if math.abs(rel.X) <= part.Size.X / 2 + 1 and math.abs(rel.Z) <= part.Size.Z / 2 + 1 and math.abs(rel.Y) < 12 then
				table.insert(list, p)
			end
		end
	end
	return list
end

--------------------------------------------------------------------------------
-- KI
--------------------------------------------------------------------------------
local function canAct(e: Entity): boolean
	local now = os.clock()
	return not e.dead and e.status.frozenUntil < now and e.status.stunnedUntil < now
end

local function face(e: Entity, pos: Vector3)
	local from = e.root.Position
	local to = Vector3.new(pos.X, from.Y, pos.Z)
	if (to - from).Magnitude > 0.1 then
		e.root.CFrame = CFrame.lookAt(from, to)
	end
end

local function stop(e: Entity)
	if e.humanoid then
		e.humanoid:Move(Vector3.zero)
		e.humanoid.WalkSpeed = 0
	end
end

-- Führt einen angekündigten Angriff aus; bricht ab, wenn der Gegner unterbrochen wird.
local function windupAttack(e: Entity, windup: number, telegraph: BasePart, resolve: () -> ())
	local token = e.ai.token
	e.ai.telegraph = telegraph
	e.ai.busyUntil = os.clock() + windup + 0.3
	FxEvent:FireAllClients("Windup", e.model, windup)
	task.delay(windup, function()
		if telegraph.Parent then
			telegraph:Destroy()
		end
		if e.ai.telegraph == telegraph then
			e.ai.telegraph = nil
		end
		if e.ai.token ~= token or not canAct(e) then
			return
		end
		FxEvent:FireAllClients("EnemyStrike", e.model)
		resolve()
	end)
end

local function meleeAttack(e: Entity, target: Player)
	local def = e.def
	local root = ctx.PlayerState.GetRoot(target)
	if not root then
		return
	end
	face(e, root.Position)
	stop(e)
	local center = e.root.Position + e.root.CFrame.LookVector * (def.attackRange * 0.55)
	local radius = def.attackRange * 0.65 + 1
	local tel = Entities.TelegraphCircle(center, radius, def.windup)
	windupAttack(e, def.windup, tel, function()
		for _, p in playersInCircle(center, radius) do
			ctx.PlayerState.Damage(p, def.damage * e.dmgMult, e.kind)
		end
	end)
end

local function rootAttack(e: Entity, target: Player)
	local root = ctx.PlayerState.GetRoot(target)
	if not root then
		return
	end
	face(e, root.Position)
	stop(e)
	local center = root.Position
	local tel = Entities.TelegraphCircle(center, 5.5, 1.1, Color3.fromRGB(120, 200, 80))
	windupAttack(e, 1.1, tel, function()
		FxEvent:FireAllClients("Roots", groundAt(center), 5.5)
		for _, p in playersInCircle(center, 5.5) do
			if ctx.PlayerState.Damage(p, e.def.damage * e.dmgMult, e.kind) then
				ctx.PlayerState.Root(p, 1.5)
			end
		end
	end)
end

local function projectileAttack(e: Entity, target: Player)
	local root = ctx.PlayerState.GetRoot(target)
	if not root then
		return
	end
	face(e, root.Position)
	stop(e)
	local token = e.ai.token
	e.ai.busyUntil = os.clock() + 1
	FxEvent:FireAllClients("Windup", e.model, 0.6)
	task.delay(0.6, function()
		if e.ai.token ~= token or not canAct(e) then
			return
		end
		local tRoot = ctx.PlayerState.GetRoot(target)
		if not tRoot then
			return
		end
		local start = e.root.Position + Vector3.new(0, 0.5, 0)
		local orb = Instance.new("Part")
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.new(1.4, 1.4, 1.4)
		orb.Material = Enum.Material.Neon
		orb.Color = Color3.fromRGB(255, 220, 120)
		orb.Anchored = true
		orb.CanCollide = false
		orb.CanQuery = false
		orb.CFrame = CFrame.new(start)
		local light = Instance.new("PointLight")
		light.Color = orb.Color
		light.Range = 10
		light.Parent = orb
		orb.Parent = telegraphFolder
		local speed = 34
		local vel = (tRoot.Position - start).Unit * speed
		local t0 = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			if os.clock() - t0 > 3 or not orb.Parent then
				conn:Disconnect()
				orb:Destroy()
				return
			end
			-- leichtes Nachsteuern
			local cur = ctx.PlayerState.GetRoot(target)
			if cur and os.clock() - t0 < 0.8 then
				local desired = (cur.Position - orb.Position).Unit * speed
				vel = vel:Lerp(desired, math.min(1, dt * 1.5))
			end
			orb.CFrame = orb.CFrame + vel * dt
			for _, p in ctx.Expedition.Participants() do
				local pr = ctx.PlayerState.GetRoot(p)
				if pr and (pr.Position - orb.Position).Magnitude < 2.6 then
					ctx.PlayerState.Damage(p, e.def.damage * e.dmgMult, e.kind)
					conn:Disconnect()
					orb:Destroy()
					return
				end
			end
		end)
	end)
end

-- Boss: Hollow Warden -------------------------------------------------------

local function bossSlam(e: Entity)
	stop(e)
	local center = e.root.Position
	local tel = Entities.TelegraphCircle(center, 16, 1.5)
	windupAttack(e, 1.5, tel, function()
		FxEvent:FireAllClients("Slam", groundAt(center), 16)
		for _, p in playersInCircle(center, 16) do
			ctx.PlayerState.Damage(p, 24 * e.dmgMult, "Bodenstoß")
		end
	end)
end

local function bossRootStrike(e: Entity, target: Player)
	local root = ctx.PlayerState.GetRoot(target)
	if not root then
		return
	end
	face(e, root.Position)
	stop(e)
	local tel = Entities.TelegraphRect(e.root.Position, e.root.CFrame.LookVector, 7, 44, 1.2)
	windupAttack(e, 1.2, tel, function()
		FxEvent:FireAllClients("RootLine", tel.CFrame, 44)
		for _, p in playersInRect(tel) do
			if ctx.PlayerState.Damage(p, 20 * e.dmgMult, "Wurzelschlag") then
				ctx.PlayerState.Root(p, 1)
			end
		end
	end)
end

local function bossBurst(e: Entity)
	local arena = e.ai.arenaCenter :: Vector3
	local participants = ctx.Expedition.Participants()
	local party = math.max(1, #participants)
	e.ai.busyUntil = os.clock() + 2.5
	stop(e)
	ctx.PlayerState.NotifyAll(participants, "Rift-Ausbruch! Zerstört die Riftkristalle, bevor sie explodieren!", "boss")
	FxEvent:FireAllClients("BossRoar", e.root.Position)
	local crystals: { Entity } = {}
	local remaining = 3
	local startAngle = math.random() * math.pi * 2
	for i = 1, 3 do
		local a = startAngle + (i / 3) * math.pi * 2
		local pos = arena + Vector3.new(math.cos(a) * 28, 0, math.sin(a) * 28)
		local g = groundAt(pos)
		local m = Instance.new("Model")
		m.Name = "RiftCrystal"
		local p = Instance.new("Part")
		p.Size = Vector3.new(2.4, 6, 2.4)
		p.CFrame = CFrame.new(g + Vector3.new(0, 3, 0)) * CFrame.Angles(0, a, math.rad(8))
		p.Color = Config.Colors.Rift
		p.Material = Enum.Material.Neon
		p.Anchored = true
		p.Parent = m
		local l = Instance.new("PointLight")
		l.Color = Config.Colors.Rift
		l.Range = 16
		l.Parent = p
		m.PrimaryPart = p
		local ce = Entities.RegisterStatic(m, {
			kind = "WardenCrystal",
			name = "Riftkristall",
			hp = Config.Boss.BurstCrystalHP * (1 + 0.5 * (party - 1)),
			shield = true,
			tag = e.tag,
			onDeath = function()
				remaining -= 1
			end,
		})
		table.insert(crystals, ce)
	end
	-- kleine Gegner passend zur Gruppengröße
	for i = 1, math.min(4, party) do
		local a = math.random() * math.pi * 2
		Entities.SpawnEnemy("Riftling", arena + Vector3.new(math.cos(a) * 36, 0, math.sin(a) * 36), { tag = e.tag, dmgMult = e.dmgMult, lootMult = 0.5 })
	end
	local token = e.ai.token
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < Config.Boss.BurstTime and remaining > 0 and not e.dead do
			ReplicatedStorage:SetAttribute("BossBurst", math.ceil(Config.Boss.BurstTime - (os.clock() - t0)))
			task.wait(0.25)
		end
		ReplicatedStorage:SetAttribute("BossBurst", 0)
		if e.dead then
			for _, c in crystals do
				Entities.Kill(c)
			end
			return
		end
		if remaining <= 0 then
			ctx.PlayerState.NotifyAll(ctx.Expedition.Participants(), "Alle Kristalle zerstört – der Warden taumelt!", "good")
			e.status.stunnedUntil = os.clock() + 3.5
			setHighlight(e, Color3.fromRGB(255, 255, 255))
			task.delay(3.5, function()
				if not e.dead then
					setHighlight(e, nil)
				end
			end)
		else
			FxEvent:FireAllClients("Slam", arena, Config.Boss.ArenaRadius)
			for _, p in playersInCircle(arena, Config.Boss.ArenaRadius + 4) do
				ctx.PlayerState.Damage(p, Config.Boss.BurstDamage * remaining * e.dmgMult, "Rift-Ausbruch")
			end
			for _, c in crystals do
				if not c.dead then
					c.dead = true
					entities[c.id] = nil
					byModel[c.model] = nil
					c.model:Destroy()
				end
			end
		end
		if e.ai.token == token then
			e.ai.busyUntil = 0
		end
	end)
	e.ai.busyUntil = os.clock() + Config.Boss.BurstTime + 0.5
end

local function nearestTarget(e: Entity, range: number): (Player?, number)
	local best, bestD = nil, range
	for _, p in ctx.Expedition.Participants() do
		if ctx.PlayerState.IsActive(p) then
			local root = ctx.PlayerState.GetRoot(p)
			if root then
				local d = (root.Position - e.root.Position).Magnitude
				if d < bestD then
					best, bestD = p, d
				end
			end
		end
	end
	return best, bestD
end

function Entities.Wake(e: Entity)
	if not e.ai.dormant then
		return
	end
	e.ai.dormant = false
	e.ai.nextAttack = os.clock() + 0.4
	if e.kind == "Burrow_Mimic" then
		FxEvent:FireAllClients("MimicReveal", e.model)
		e.name = e.def.name
		local gui = e.root:FindFirstChild("HPBar") :: BillboardGui?
		if gui then
			gui.Enabled = true
			local label = gui:FindFirstChildOfClass("TextLabel")
			if label then
				label.Text = e.name
			end
		end
		for _, d in e.model:GetDescendants() do
			if d:IsA("BasePart") and (d.Name == "Tooth" or d.Name == "Tongue") then
				d.Transparency = 0
			elseif d:IsA("BasePart") and d.Name == "MimicLid" then
				local weld = d:FindFirstChildOfClass("WeldConstraint")
				if weld then
					weld.Enabled = false
					d.CFrame = d.CFrame * CFrame.new(0, 0.8, 0.9) * CFrame.Angles(math.rad(-50), 0, 0)
					weld.Enabled = true
				end
			elseif d:IsA("ProximityPrompt") then
				d:Destroy()
			end
		end
	end
	if e.isBoss then
		ReplicatedStorage:SetAttribute("BossActive", true)
		ReplicatedStorage:SetAttribute("BossName", e.name)
		updateBar(e)
		ctx.PlayerState.NotifyAll(ctx.Expedition.Participants(), "Der Hollow Warden erwacht!", "boss")
		FxEvent:FireAllClients("BossRoar", e.root.Position)
	end
end

local function think(e: Entity, now: number)
	local def = e.def
	local hum = e.humanoid :: Humanoid
	if not def or not hum then
		return
	end
	if not canAct(e) then
		hum:Move(Vector3.zero)
		hum.WalkSpeed = 0
		return
	end
	if e.ai.dormant then
		local target, dist = nearestTarget(e, if e.isBoss then 999 else 7)
		if target then
			if e.isBoss then
				local root = ctx.PlayerState.GetRoot(target)
				if root and (flat(root.Position) - flat(e.ai.arenaCenter)).Magnitude < Config.Boss.ArenaRadius - 4 then
					Entities.Wake(e)
				end
			elseif dist <= 7 then
				Entities.Wake(e)
			end
		end
		return
	end
	if now < e.ai.busyUntil then
		hum:Move(Vector3.zero)
		return
	end
	local speed = def.speed * (if e.status.slowUntil > now then 0.5 else 1)
	hum.WalkSpeed = speed

	local aggro = if e.isBoss then 120 else 55
	local target, dist = nearestTarget(e, aggro)
	if not target then
		-- zurück nach Hause
		if (flat(e.root.Position) - flat(e.home)).Magnitude > 6 then
			hum:MoveTo(e.home)
		else
			hum:Move(Vector3.zero)
		end
		return
	end
	local tRoot = ctx.PlayerState.GetRoot(target) :: BasePart
	local tPos = tRoot.Position
	local ready = now >= e.ai.nextAttack

	if e.isBoss then
		if ready then
			local hpFrac = e.hp / e.maxHp
			local thresholds = e.ai.burstThresholds
			if thresholds[1] and hpFrac <= thresholds[1] then
				table.remove(thresholds, 1)
				e.ai.nextAttack = now + Config.Boss.BurstTime + 2
				bossBurst(e)
				return
			end
			if dist <= 13 then
				e.ai.nextAttack = now + def.cooldown + 1.2
				bossSlam(e)
				return
			elseif dist <= 40 then
				e.ai.nextAttack = now + def.cooldown + 0.8
				-- Wurzelschlag trifft bevorzugt, wer zuletzt angegriffen hat
				local attacker = e.lastHitBy
				local aRoot = attacker and ctx.PlayerState.IsActive(attacker) and ctx.PlayerState.GetRoot(attacker)
				if attacker and aRoot and (aRoot.Position - e.root.Position).Magnitude <= 45 then
					bossRootStrike(e, attacker)
				else
					bossRootStrike(e, target)
				end
				return
			end
		end
		hum:MoveTo(tPos)
		return
	end

	if e.kind == "Lantern_Wraith" then
		if dist < 14 then
			local away = flat(e.root.Position - tPos)
			if away.Magnitude < 0.1 then
				away = Vector3.new(1, 0, 0)
			end
			hum:MoveTo(e.root.Position + away.Unit * 10)
		elseif dist > 24 then
			hum:MoveTo(tPos)
		else
			hum:Move(Vector3.zero)
			face(e, tPos)
		end
		if ready and dist <= def.attackRange + 4 then
			e.ai.nextAttack = now + def.cooldown
			projectileAttack(e, target)
		end
		return
	end

	if e.kind == "Rootstalker" and ready and dist > 7 and dist < 28 and now >= (e.ai.nextRoot or 0) then
		e.ai.nextRoot = now + 5
		e.ai.nextAttack = now + def.cooldown
		rootAttack(e, target)
		return
	end

	if dist <= def.attackRange + 1 then
		if ready then
			e.ai.nextAttack = now + def.cooldown
			meleeAttack(e, target)
		else
			hum:Move(Vector3.zero)
			face(e, tPos)
		end
		return
	end

	if e.kind == "Rift_Crawler" and dist > 11 then
		-- Flankieren: seitlich um den Spieler herum
		local toTarget = flat(tPos - e.root.Position).Unit
		local side = Vector3.new(-toTarget.Z, 0, toTarget.X) * e.ai.side
		hum:MoveTo(tPos + side * 9)
		return
	end
	hum:MoveTo(tPos)
end

function Entities.SetupBoss(e: Entity, arenaCenter: Vector3)
	e.ai.dormant = true
	e.ai.arenaCenter = arenaCenter
	e.ai.burstThresholds = { 0.7, 0.4, 0.15 }
	ReplicatedStorage:SetAttribute("BossActive", false)
end

--------------------------------------------------------------------------------
-- Aufräumen
--------------------------------------------------------------------------------
function Entities.ClearTag(tag: string)
	for id, e in entities do
		if e.tag == tag then
			e.dead = true
			entities[id] = nil
			byModel[e.model] = nil
			e.model:Destroy()
		end
	end
	telegraphFolder:ClearAllChildren()
	ReplicatedStorage:SetAttribute("BossActive", false)
	ReplicatedStorage:SetAttribute("BossBurst", 0)
end

function Entities.All(): { [number]: Entity }
	return entities
end

--------------------------------------------------------------------------------
-- Start
--------------------------------------------------------------------------------
function Entities.Init(context)
	ctx = context
	folder = Instance.new("Folder")
	folder.Name = "Entities"
	folder.Parent = workspace
	telegraphFolder = Instance.new("Folder")
	telegraphFolder.Name = "Telegraphs"
	telegraphFolder.Parent = workspace
end

function Entities.Start()
	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		accum += dt
		if accum < 0.1 then
			return
		end
		accum = 0
		local now = os.clock()
		for _, e in entities do
			if e.dead then
				continue
			end
			local s = e.status
			-- Brand
			if s.burnStacks > 0 then
				if now > s.burnUntil then
					s.burnStacks = 0
					local f = e.root:FindFirstChild("BurnFire")
					if f then
						f:Destroy()
					end
				elseif now >= s.nextBurn then
					s.nextBurn = now + 0.5
					Entities.Damage(e, 2.5 * s.burnStacks, { player = e.lastHitBy, color = Config.Elements.Ember.color, elements = { "Ember" } })
					if e.dead then
						continue
					end
				end
			end
			-- Frost-Highlight entfernen
			if s.frozenUntil > 0 and s.frozenUntil < now then
				s.frozenUntil = 0
				setHighlight(e, if s.markUntil > now then Config.Elements.Shadow.color else nil)
			elseif s.frozenUntil < now then
				local marked = s.markUntil > now
				local h = e.model:FindFirstChild("StatusHighlight") :: Highlight?
				if marked and not h then
					setHighlight(e, Config.Elements.Shadow.color)
				elseif not marked and h and not (e.isBoss and s.stunnedUntil > now) then
					setHighlight(e, nil)
				end
			end
			if e.isEnemy then
				think(e, now)
			end
		end
	end)
end

return Entities
