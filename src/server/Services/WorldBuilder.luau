--!nonstrict
-- Baut beim Serverstart die Welt: das Rift Camp und das Expeditionsgebiet
-- "Verdant Scar" (Außenposten, Ruinen, Kupfermine mit zwei Routen, Rift-Kammer).
-- Eigene Deko kannst du in Studio einfach dazubauen; Stationen und Spawnpunkte
-- kommen aus diesem Skript.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local WorldBuilder = {}
local ctx: any

local world: Model
local terrain = workspace.Terrain

--------------------------------------------------------------------------------
-- Wichtige Punkte (werden von Expedition genutzt)
--------------------------------------------------------------------------------
local V = Vector3.new
WorldBuilder.Points = {
	CampSpawn = V(0, 0, 26),
	CampArrival = V(0, 0, -26),
	ZoneArrival = V(0, 0, -590),
	OutpostPortal = V(-22, 0, -592),
	RiftSeal = V(78, 0, -740),
	Shrine = V(108, 0, -740),
	FrostSeal = V(70, 0, -910),
	Cache = V(108, 0, -910),
	ArenaCenter = V(0, 0, -1050),
	ArenaPortal = V(0, 0, -1094),
}

-- Kandidaten für zufällige Platzierung pro Lauf
WorldBuilder.Spawns = {
	Outpost = {
		enemies = { { "Riftling", V(-10, 0, -650) }, { "Riftling", V(12, 0, -655) }, { "Riftling", V(0, 0, -668) }, { "Riftling", V(-22, 0, -662) } },
		enemyCount = 3,
		nodes = { V(25, 0, -600), V(-35, 0, -625), V(30, 0, -640), V(-32, 0, -590), V(12, 0, -662) },
		nodeKinds = { "Copper_Deposit", "Stone_Deposit", "Timber_Pile" },
		nodeCount = 3,
	},
	Ruins = {
		enemies = {
			{ "Riftling", V(-30, 0, -715) },
			{ "Riftling", V(-24, 0, -722) },
			{ "Riftling", V(30, 0, -745) },
			{ "Riftling", V(38, 0, -752) },
			{ "Rootstalker", V(-45, 0, -770) },
			{ "Rootstalker", V(20, 0, -792) },
			{ "Rift_Crawler", V(0, 0, -805) },
			{ "Rift_Crawler", V(-50, 0, -740) },
		},
		enemyCount = 6,
		nodes = { V(-55, 0, -700), V(50, 0, -705), V(-62, 0, -760), V(55, 0, -780), V(-10, 0, -742), V(15, 0, -815), V(-40, 0, -812) },
		nodeKinds = { "Copper_Deposit", "Stone_Deposit", "Timber_Pile", "Rift_Deposit" },
		nodeCount = 4,
		chests = { V(-58, 0, -730), V(45, 0, -725), V(-22, 0, -800), V(52, 0, -810) },
		chestCount = 2,
		mimicChance = 0.25,
	},
	SafeMine = {
		enemies = { { "Riftling", V(-40, 0, -870) }, { "Riftling", V(-30, 0, -930) }, { "Rootstalker", V(-45, 0, -955) }, { "Riftling", V(-26, 0, -890) } },
		enemyCount = 3,
		nodes = { V(-50, 0, -850), V(-26, 0, -870), V(-52, 0, -895), V(-22, 0, -912), V(-50, 0, -935), V(-24, 0, -955), V(-50, 0, -975) },
		nodeKinds = { "Copper_Deposit", "Copper_Deposit", "Stone_Deposit", "Copper_Deposit", "Stone_Deposit", "Timber_Pile" },
		nodeCount = 5,
	},
	RiskyMine = {
		enemies = {
			{ "Lantern_Wraith", V(35, 0, -880) },
			{ "Lantern_Wraith", V(45, 0, -948) },
			{ "Rift_Crawler", V(25, 0, -900) },
			{ "Rift_Crawler", V(42, 0, -918) },
			{ "Riftling", V(30, 0, -962) },
			{ "Rootstalker", V(48, 0, -860) },
		},
		enemyCount = 5,
		hpMult = 1.25,
		nodes = { V(25, 0, -850), V(52, 0, -872), V(22, 0, -932), V(52, 0, -902), V(50, 0, -968) },
		nodeKinds = { "Rift_Deposit", "Rift_Deposit", "Copper_Deposit" },
		nodeCount = 3,
		chests = { V(50, 0, -855), V(24, 0, -975), V(52, 0, -932) },
		chestCount = 2,
		mimicCount = 1,
		rare = true,
	},
}

--------------------------------------------------------------------------------
-- Hilfen
--------------------------------------------------------------------------------
local function fill(center: Vector3, size: Vector3, material: Enum.Material)
	terrain:FillBlock(CFrame.new(center), size, material)
end

local function place(name: string, pos: Vector3, yaw: number?, height: number?, parent: Instance?): Model
	return ctx.AssetLoader.Place(name, CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw or 0), 0), parent or world, height)
end

local function part(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or world
	return p
end

local function label(model: Model, text: string, height: number, color: Color3?)
	local _, size = model:GetBoundingBox()
	local anchor = Instance.new("Part")
	anchor.Name = "LabelAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CFrame = model:GetPivot() + Vector3.new(0, math.max(size.Y, height), 0)
	anchor.Parent = model
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 34)
	gui.StudsOffset = Vector3.new(0, 1.5, 0)
	gui.MaxDistance = 70
	gui.Parent = anchor
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextColor3 = color or Color3.fromRGB(235, 240, 245)
	t.TextStrokeTransparency = 0.3
	t.Font = Enum.Font.GothamBlack
	t.TextSize = 18
	t.Parent = gui
end

function WorldBuilder.Prompt(parentPart: BasePart, action: string, object: string, hold: number?, key: Enum.KeyCode?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold or 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = key or Enum.KeyCode.E
	if key and key ~= Enum.KeyCode.E then
		-- zweite Aktion am selben Objekt: eigene Controller-Taste
		prompt.GamepadKeyCode = Enum.KeyCode.DPadUp
	end
	prompt.Parent = parentPart
	return prompt
end

local function promptAnchor(model: Model, offsetY: number?): Part
	local cf, size = model:GetBoundingBox()
	local anchor = Instance.new("Part")
	anchor.Name = "PromptAnchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CFrame = CFrame.new(cf.Position.X, model:GetPivot().Y + (offsetY or math.min(size.Y * 0.5, 3)), cf.Position.Z)
	anchor.Parent = model
	return anchor
end
WorldBuilder.PromptAnchor = promptAnchor

local function station(name: string, asset: string, pos: Vector3, yaw: number, title: string, ui: string)
	local m = place(asset, pos, yaw)
	label(m, title, 5, Color3.fromRGB(63, 224, 197))
	local prompt = WorldBuilder.Prompt(promptAnchor(m), "Öffnen", title)
	prompt.Triggered:Connect(function(player)
		Net.Event("OpenUI"):FireClient(player, ui)
	end)
	m:SetAttribute("Station", name)
	return m
end

local function scatter(name: string, center: Vector3, radius: number, count: number, seed: number, minRadius: number?)
	local rng = Random.new(seed)
	for _ = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(minRadius or 0, radius)
		local h = ctx.AssetLoader.Heights[name] * rng:NextNumber(0.8, 1.25)
		place(name, center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), rng:NextNumber(0, 360), h)
	end
end

--------------------------------------------------------------------------------
-- Camp
--------------------------------------------------------------------------------
local function buildCamp()
	fill(V(0, -6, 0), V(260, 12, 260), Enum.Material.Grass)
	fill(V(0, -0.5, -8), V(12, 1, 60), Enum.Material.Ground)
	fill(V(0, -0.5, 30), V(40, 1, 12), Enum.Material.Ground)
	-- Hügel rundherum
	local rng = Random.new(4)
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local r = 118 + rng:NextNumber(-6, 6)
		terrain:FillBall(V(math.cos(a) * r, 0, math.sin(a) * r), rng:NextNumber(16, 26), Enum.Material.Rock)
	end
	scatter("Tree", V(0, 0, 0), 100, 36, 21, 70)
	scatter("Rock", V(0, 0, 0), 95, 10, 22, 65)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CampSpawn"
	spawn.Size = V(10, 1, 10)
	spawn.CFrame = CFrame.new(WorldBuilder.Points.CampSpawn + V(0, 0.5, 0))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Material = Enum.Material.Slate
	spawn.Color = Color3.fromRGB(70, 78, 88)
	spawn.Parent = world

	station("Forge", "Workbench", V(-26, 0, -6), 90, "Schmiede", "Forge")
	station("Furnace", "Smelting_Furnace", V(-42, 0, 16), 60, "Schmelzofen", "Furnace")
	station("Research", "Research_Table", V(26, 0, -6), -90, "Forschungstisch", "Research")
	station("Chest", "Storage_Chest", V(42, 0, 16), -60, "Lagerkiste", "Chest")
	station("Board", "Expedition_Board", V(0, 0, -36), 180, "Expeditionstafel", "Board")
	local gate = place("Return_Portal", V(0, 0, -52), 0)
	label(gate, "Rift-Tor → Verdant Scar", 11, Color3.fromRGB(63, 224, 197))

	place("Campfire", V(0, 0, 6))
	place("Tent", V(-24, 0, 38), 30)
	place("Tent", V(24, 0, 40), -30)
	place("Timber_Pile", V(-34, 0, 30), 20)
	for _, p in { V(-14, 0, -20), V(14, 0, -20), V(-34, 0, 2), V(34, 0, 2), V(-12, 0, 44), V(12, 0, 44) } do
		place("Lantern", p)
	end

	-- Trainingsplatz
	local yard = V(0, 0, 62)
	fill(yard - V(0, 0.5, 0), V(44, 1, 26), Enum.Material.Sand)
	for x = -22, 22, 4 do
		part(V(0.5, 3, 0.5), CFrame.new(yard + V(x, 1.5, 13)), Color3.fromRGB(95, 66, 44), Enum.Material.Wood)
	end
	part(V(44, 0.4, 0.3), CFrame.new(yard + V(0, 2.6, 13)), Color3.fromRGB(125, 82, 50), Enum.Material.Wood)
	local sign = Instance.new("Model")
	sign.Name = "TrainingSign"
	sign.WorldPivot = CFrame.new(yard + V(0, 0, -12))
	sign.Parent = world
	label(sign, "Trainingsplatz", 4, Color3.fromRGB(240, 200, 80))
	for i, x in { -12, 0, 12 } do
		local dummy = place("Training_Dummy", yard + V(x, 0, if i == 2 then 4 else 0), 180)
		ctx.Entities.RegisterStatic(dummy, { kind = "Dummy", name = "Übungspuppe", hp = 500, dummy = true, barHeight = 7 })
	end
end

--------------------------------------------------------------------------------
-- Verdant Scar
--------------------------------------------------------------------------------
local function mineGate(xMin: number, xMax: number, z: number)
	local wood = Color3.fromRGB(80, 52, 34)
	part(V(1.4, 14, 1.4), CFrame.new(xMin + 1, 7, z), wood, Enum.Material.Wood)
	part(V(1.4, 14, 1.4), CFrame.new(xMax - 1, 7, z), wood, Enum.Material.Wood)
	part(V(xMax - xMin, 1.4, 1.6), CFrame.new((xMin + xMax) / 2, 14.2, z), Color3.fromRGB(125, 82, 50), Enum.Material.Wood)
	local lamp = part(V(0.8, 1, 0.8), CFrame.new((xMin + xMax) / 2, 13, z), Color3.fromRGB(255, 150, 60), Enum.Material.Neon)
	local l = Instance.new("PointLight")
	l.Color = lamp.Color
	l.Range = 24
	l.Brightness = 2
	l.Parent = lamp
end

local function sign(pos: Vector3, text: string, color: Color3)
	part(V(0.5, 5, 0.5), CFrame.new(pos + V(0, 2.5, 0)), Color3.fromRGB(80, 52, 34), Enum.Material.Wood)
	local board = part(V(6, 2, 0.3), CFrame.new(pos + V(0, 4.6, 0)), Color3.fromRGB(168, 112, 66), Enum.Material.WoodPlanks)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(300, 100)
		gui.Parent = board
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = text
		t.TextColor3 = color
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.Parent = gui
	end
end

local function buildZone()
	-- Grundfläche und Begrenzung
	fill(V(0, -6, -850), V(280, 12, 640), Enum.Material.Grass)
	fill(V(-148, 18, -850), V(24, 48, 640), Enum.Material.Rock)
	fill(V(148, 18, -850), V(24, 48, 640), Enum.Material.Rock)
	fill(V(0, 18, -540), V(300, 48, 20), Enum.Material.Rock)
	fill(V(0, 18, -1160), V(300, 48, 20), Enum.Material.Rock)
	-- Wege
	fill(V(0, -0.5, -700), V(16, 1, 260), Enum.Material.Ground)

	-- 1. Verlassener Außenposten
	local outpost = V(0, 0, -612)
	for i = 0, 27 do
		local a = i / 28 * math.pi * 2
		local open = (a > math.rad(80) and a < math.rad(100)) or (a > math.rad(260) and a < math.rad(280))
		if not open then
			local h = 7 + (i % 3)
			part(
				V(1.6, h, 1.6),
				CFrame.new(outpost + V(math.cos(a) * 36, h / 2, math.sin(a) * 36)) * CFrame.Angles(0, -a, math.rad(4)),
				Color3.fromRGB(95, 66, 44),
				Enum.Material.Wood
			)
		end
	end
	place("Tent", outpost + V(-20, 0, -8), 70)
	place("Tent", outpost + V(20, 0, -12), -80)
	place("Campfire", outpost + V(0, 0, 4))
	place("Lantern", outpost + V(-8, 0, 30))
	place("Lantern", outpost + V(8, 0, 30))
	sign(outpost + V(6, 0, 34), "Außenposten", Color3.fromRGB(40, 25, 15))

	-- 2. Überwucherte Ruinen
	local rng = Random.new(77)
	for _, p in { V(-40, 0, -700), V(40, 0, -698), V(-48, 0, -748), V(46, 0, -770), V(-30, 0, -790), V(26, 0, -812), V(-60, 0, -805), V(60, 0, -735) } do
		place("Ruin_Pillar", p, rng:NextNumber(0, 360), rng:NextNumber(8, 14))
	end
	for _, p in { V(-20, 0, -732), V(28, 0, -720), V(-66, 0, -780), V(8, 0, -782) } do
		place("Ruin_Wall", p, rng:NextNumber(0, 360))
	end
	scatter("Tree", V(0, 0, -750), 110, 22, 31, 60)
	scatter("Rock", V(0, 0, -750), 100, 10, 32, 30)

	-- Schrein hinter der Rift-Barriere
	fill(V(100, 18, -740), V(60, 48, 76), Enum.Material.Rock)
	fill(V(104, 9, -740), V(30, 18, 40), Enum.Material.Air)
	fill(V(79, 8, -740), V(22, 16, 16), Enum.Material.Air)
	fill(V(104, -0.5, -740), V(30, 1, 40), Enum.Material.Slate)
	local altarBase = part(V(4, 2, 4), CFrame.new(WorldBuilder.Points.Shrine + V(0, 1, 0)), Color3.fromRGB(62, 70, 80), Enum.Material.Slate)
	altarBase.Name = "ShrineAltar"
	for i = 0, 3 do
		local a = i * math.pi / 2
		local c = part(
			V(1, 5, 1),
			CFrame.new(WorldBuilder.Points.Shrine + V(math.cos(a) * 8, 2.5, math.sin(a) * 8)) * CFrame.Angles(0, a, math.rad(10)),
			Color3.fromRGB(63, 224, 197),
			Enum.Material.Neon
		)
		local l = Instance.new("PointLight")
		l.Color = c.Color
		l.Range = 14
		l.Parent = c
	end

	-- 3. Gabelung und Kupfermine
	sign(V(-30, 0, -826), "← Sicherer Pfad", Color3.fromRGB(40, 90, 40))
	sign(V(30, 0, -826), "Riskanter Pfad →", Color3.fromRGB(140, 30, 20))
	fill(V(-101, 18, -910), V(82, 48, 160), Enum.Material.Rock)
	fill(V(101, 18, -910), V(82, 48, 160), Enum.Material.Rock)
	fill(V(0, 18, -906), V(30, 48, 132), Enum.Material.Slate)
	fill(V(-38, -0.5, -910), V(46, 1, 160), Enum.Material.Slate)
	fill(V(38, -0.5, -910), V(46, 1, 160), Enum.Material.Slate)
	for z = -845, -985, -35 do
		mineGate(-60, -15, z)
		mineGate(15, 60, z)
	end
	-- Versteck hinter dem Frostsiegel
	fill(V(104, 9, -910), V(30, 18, 34), Enum.Material.Air)
	fill(V(76, 8, -910), V(30, 16, 14), Enum.Material.Air)
	fill(V(104, -0.5, -910), V(30, 1, 34), Enum.Material.Glacier)

	-- 4. Rift-Kammer
	local arena = WorldBuilder.Points.ArenaCenter
	fill(V(0, 18, -1075), V(300, 48, 150), Enum.Material.Rock)
	terrain:FillCylinder(CFrame.new(arena + V(0, 12, 0)), 24, 50, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(arena + V(0, -1, 0)), 2, 50, Enum.Material.Slate)
	fill(V(0, 10, -998), V(26, 20, 16), Enum.Material.Air)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local deg = math.deg(a)
		if math.abs(deg - 90) > 20 and math.abs(deg - 270) > 20 then
			local c = part(
				V(2, 9, 2),
				CFrame.new(arena + V(math.cos(a) * 47, 4, math.sin(a) * 47)) * CFrame.Angles(math.rad(10), a, math.rad(-8)),
				Color3.fromRGB(63, 224, 197),
				Enum.Material.Neon
			)
			local l = Instance.new("PointLight")
			l.Color = c.Color
			l.Range = 20
			l.Parent = c
		end
	end
	sign(V(14, 0, -990), "Rift-Kammer", Color3.fromRGB(63, 224, 197))
end

--------------------------------------------------------------------------------
-- Licht
--------------------------------------------------------------------------------
local function setupLighting()
	Lighting.ClockTime = 16.8
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(70, 80, 90)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 130, 140)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atm = Instance.new("Atmosphere")
		atm.Density = 0.32
		atm.Offset = 0.1
		atm.Color = Color3.fromRGB(190, 215, 220)
		atm.Decay = Color3.fromRGB(90, 120, 130)
		atm.Glare = 0.2
		atm.Haze = 1.4
		atm.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.6
		bloom.Size = 20
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Saturation = 0.08
		cc.Contrast = 0.06
		cc.Parent = Lighting
	end
end

function WorldBuilder.Init(context)
	ctx = context
end

function WorldBuilder.Start()
	setupLighting()
	local old = workspace:FindFirstChild("RiftboundWorld")
	if old then
		old:Destroy()
	end
	world = Instance.new("Model")
	world.Name = "RiftboundWorld"
	world.Parent = workspace
	buildCamp()
	buildZone()
end

function WorldBuilder.Place(name: string, pos: Vector3, yaw: number?, height: number?, parent: Instance?): Model
	return place(name, pos, yaw, height, parent)
end

return WorldBuilder
