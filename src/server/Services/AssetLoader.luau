--!nonstrict
-- AssetLoader: liefert Modelle für Stationen, Ressourcen, Gegner und Deko.
--
-- 1. Liegt in ServerStorage.RiftboundAssets ein Modell mit dem passenden Namen
--    (z. B. ein per 3D-Importer importiertes "Riftling" aus dem Asset-Pack oder ein
--    Modell aus dem Creator Store), wird es geklont und auf die Zielgröße skaliert.
--    Optionales Attribut "Yaw" (Grad) am Vorlagenmodell dreht es beim Einsetzen.
-- 2. Sonst wird ein prozedurales Low-Poly-Ersatzmodell aus Parts gebaut, damit das
--    Spiel sofort spielbar ist.

local ServerStorage = game:GetService("ServerStorage")

local AssetLoader = {}

local builders: { [string]: (Model) -> () } = {}

-- Zielhöhen in Studs (ein Spieler ist etwa 5 Studs groß)
AssetLoader.Heights = {
	Workbench = 4.2,
	Smelting_Furnace = 7,
	Storage_Chest = 2.8,
	Return_Portal = 11,
	Research_Table = 4.5,
	Expedition_Board = 7,
	Training_Dummy = 5.5,
	Copper_Deposit = 3.4,
	Stone_Deposit = 3.4,
	Rift_Deposit = 4.2,
	Timber_Pile = 3,
	Riftling = 5,
	Rootstalker = 6.5,
	Lantern_Wraith = 4,
	Rift_Crawler = 2.6,
	Burrow_Mimic = 3,
	Hollow_Warden = 12,
	Tree = 16,
	Rock = 5,
	Tent = 6,
	Ruin_Pillar = 12,
	Ruin_Wall = 8,
	Mine_Beam = 14,
	Lantern = 6,
	Campfire = 2,
	Stone_Sword = 4,
}

--------------------------------------------------------------------------------
-- Hilfsfunktionen für prozedurale Modelle (Ursprung = Mitte unten, Y nach oben)
--------------------------------------------------------------------------------
type PartOpts = {
	shape: Enum.PartType?,
	material: Enum.Material?,
	transparency: number?,
	name: string?,
	light: number?,
}

local function P(model: Model, size: Vector3, cf: CFrame, color: Color3, opts: PartOpts?): BasePart
	local o = opts or {} :: PartOpts
	local part: BasePart
	if o.shape == Enum.PartType.Wedge then
		part = Instance.new("WedgePart")
	elseif o.shape == Enum.PartType.CornerWedge then
		part = Instance.new("CornerWedgePart")
	else
		local p = Instance.new("Part")
		if o.shape then
			p.Shape = o.shape
		end
		part = p
	end
	part.Name = o.name or "Part"
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = o.material or Enum.Material.SmoothPlastic
	part.Transparency = o.transparency or 0
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if o.light then
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = o.light
		l.Brightness = 1.5
		l.Parent = part
	end
	part.Parent = model
	return part
end

local function at(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

local C = {
	Wood = Color3.fromRGB(125, 82, 50),
	WoodDark = Color3.fromRGB(80, 52, 34),
	Plank = Color3.fromRGB(168, 112, 66),
	Iron = Color3.fromRGB(70, 78, 88),
	IronDark = Color3.fromRGB(38, 42, 50),
	Stone = Color3.fromRGB(110, 120, 130),
	StoneDark = Color3.fromRGB(62, 70, 80),
	Rift = Color3.fromRGB(63, 224, 197),
	Copper = Color3.fromRGB(217, 119, 58),
	Fire = Color3.fromRGB(255, 150, 60),
	Leaf = Color3.fromRGB(70, 130, 70),
	LeafDark = Color3.fromRGB(46, 96, 56),
	Bark = Color3.fromRGB(95, 66, 44),
	Straw = Color3.fromRGB(214, 184, 110),
	Cloth = Color3.fromRGB(150, 60, 50),
}
AssetLoader.Colors = C

local Neon = { material = Enum.Material.Neon }

local function fire(part: BasePart, size: number)
	local f = Instance.new("Fire")
	f.Size = size
	f.Heat = size * 1.5
	f.Color = Color3.fromRGB(255, 140, 40)
	f.SecondaryColor = Color3.fromRGB(255, 60, 20)
	f.Parent = part
end

local function rockCluster(m: Model, cx: number, cz: number, radius: number, height: number, color: Color3, n: number, seed: number)
	local rng = Random.new(seed)
	P(
		m,
		Vector3.new(radius * 2, height * 0.55, radius * 1.6),
		at(cx, height * 0.27, cz, 0, rng:NextNumber(0, 90), 0),
		color,
		{ material = Enum.Material.Slate }
	)
	for i = 1, n do
		local a = (i / n) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local r = radius * rng:NextNumber(0.3, 0.75)
		local s = height * rng:NextNumber(0.35, 0.6)
		P(
			m,
			Vector3.new(s * 1.2, s, s * 1.1),
			at(cx + math.cos(a) * r, height * 0.35 + s * 0.35, cz + math.sin(a) * r, rng:NextNumber(-25, 25), rng:NextNumber(0, 90), rng:NextNumber(-25, 25)),
			color,
			{ material = Enum.Material.Slate }
		)
	end
end

--------------------------------------------------------------------------------
-- Stationen
--------------------------------------------------------------------------------
builders.Workbench = function(m)
	P(m, Vector3.new(7, 0.6, 3.6), at(0, 3, 0), C.Plank, { material = Enum.Material.WoodPlanks })
	for _, x in { -3.1, 3.1 } do
		for _, z in { -1.4, 1.4 } do
			P(m, Vector3.new(0.6, 3, 0.6), at(x, 1.5, z), C.WoodDark, { material = Enum.Material.Wood })
		end
	end
	P(m, Vector3.new(6.2, 0.3, 2.8), at(0, 0.9, 0), C.Wood, { material = Enum.Material.WoodPlanks })
	-- Amboss
	P(m, Vector3.new(1.2, 0.5, 1), at(1.5, 3.55, 0), C.IronDark, { material = Enum.Material.Metal })
	P(m, Vector3.new(0.7, 0.5, 0.6), at(1.5, 3.95, 0), C.IronDark, { material = Enum.Material.Metal })
	P(m, Vector3.new(2.4, 0.5, 0.9), at(1.5, 4.3, 0), C.Iron, { material = Enum.Material.Metal, name = "Anvil" })
	P(m, Vector3.new(0.9, 0.5, 0.5), at(3, 4.3, 0, 0, 0, -12), C.Iron, { material = Enum.Material.Metal, shape = Enum.PartType.Wedge })
	-- Werkzeuge
	P(m, Vector3.new(0.25, 0.25, 1.6), at(-1.5, 3.45, 0.6, 0, 20, 0), C.Wood, {})
	P(m, Vector3.new(0.7, 0.45, 0.45), at(-1.25, 3.5, -0.15, 0, 20, 0), C.IronDark, { material = Enum.Material.Metal })
	for i = 0, 2 do
		P(m, Vector3.new(0.9, 0.35, 0.5), at(-2 + i * 1.1, 1.25, 0), C.Copper, { material = Enum.Material.Metal })
	end
	-- Esse daneben
	P(m, Vector3.new(2.6, 2.4, 2.6), at(-5.4, 1.2, 0), C.StoneDark, { material = Enum.Material.Cobblestone })
	local coal = P(m, Vector3.new(1.8, 0.3, 1.8), at(-5.4, 2.5, 0), C.Fire, { material = Enum.Material.Neon, light = 14 })
	fire(coal, 2)
end

builders.Smelting_Furnace = function(m)
	P(m, Vector3.new(5.4, 0.5, 5.4), at(0, 0.25, 0), C.IronDark, { material = Enum.Material.Slate })
	P(m, Vector3.new(5, 4.2, 5), at(0, 2.6, 0), C.StoneDark, { material = Enum.Material.Cobblestone })
	P(m, Vector3.new(5.4, 0.6, 5.4), at(0, 4.9, 0), C.Stone, { material = Enum.Material.Slate })
	P(m, Vector3.new(1.8, 2.2, 1.8), at(0.6, 6.3, 0.6), C.IronDark, { material = Enum.Material.Slate })
	local glow = P(m, Vector3.new(2.6, 1.8, 0.3), at(0, 1.9, -2.45), C.Fire, { material = Enum.Material.Neon, light = 16 })
	fire(glow, 2.5)
	for i = -1, 1 do
		P(m, Vector3.new(0.2, 1.9, 0.2), at(i * 0.8, 1.9, -2.65), C.IronDark, { material = Enum.Material.Metal })
	end
end

builders.Storage_Chest = function(m)
	P(m, Vector3.new(4, 1.8, 2.6), at(0, 0.9, 0), C.Plank, { material = Enum.Material.WoodPlanks, name = "Body" })
	P(m, Vector3.new(4.2, 0.7, 2.8), at(0, 2.15, 0), C.Wood, { material = Enum.Material.WoodPlanks, name = "Lid" })
	for _, x in { -1.4, 1.4 } do
		P(m, Vector3.new(0.3, 2.6, 2.9), at(x, 1.3, 0), C.IronDark, { material = Enum.Material.Metal })
	end
	P(m, Vector3.new(0.5, 0.6, 0.15), at(0, 1.7, -1.35), C.Copper, { material = Enum.Material.Metal })
end

builders.Return_Portal = function(m)
	P(m, Vector3.new(12, 0.6, 4.5), at(0, 0.3, 0), C.IronDark, { material = Enum.Material.Slate })
	local n = 14
	for i = 0, n do
		local a = math.pi * (i / n)
		local x, y = math.cos(a) * 4.6, 0.6 + math.sin(a) * 9.2
		P(m, Vector3.new(1.8, 1.8, 1.9), at(x, y + 0.3, 0, 0, 0, math.deg(a)), C.Stone, { material = Enum.Material.Slate })
	end
	for i = 0, 20 do
		local a = math.pi * 2 * (i / 20)
		P(m, Vector3.new(0.35, 1.5, 0.35), at(math.cos(a) * 3.6, 5 + math.sin(a) * 4.2, 0, 0, 0, math.deg(a)), C.Rift, Neon)
	end
	local surface = P(
		m,
		Vector3.new(0.2, 7.6, 8.4),
		at(0, 5, 0, 0, 90, 0),
		C.Rift,
		{ material = Enum.Material.ForceField, transparency = 0.25, name = "Surface", shape = Enum.PartType.Cylinder }
	)
	surface.CFrame = at(0, 5, 0, 0, 90, 0)
	surface.Size = Vector3.new(0.2, 8.4, 7.6)
	local l = Instance.new("PointLight")
	l.Color = C.Rift
	l.Range = 18
	l.Brightness = 2
	l.Parent = surface
	for _, x in { -5.2, 5.2 } do
		P(m, Vector3.new(0.8, 2.2, 0.8), at(x, 1.7, 1.5, 0, 0, 10), C.Rift, Neon)
	end
end

builders.Research_Table = function(m)
	P(m, Vector3.new(5, 0.5, 3), at(0, 3, 0), C.WoodDark, { material = Enum.Material.WoodPlanks })
	for _, x in { -2.1, 2.1 } do
		P(m, Vector3.new(0.5, 3, 2.4), at(x, 1.5, 0), C.Wood, { material = Enum.Material.Wood })
	end
	P(m, Vector3.new(2.2, 0.08, 1.5), at(-0.8, 3.3, 0, 0, 8, 0), Color3.fromRGB(225, 210, 170), {})
	P(m, Vector3.new(0.8, 0.5, 1.1), at(1.6, 3.5, -0.6, 0, -15, 0), C.Cloth, {})
	P(m, Vector3.new(0.8, 0.4, 1.1), at(1.6, 3.95, -0.6, 0, 5, 0), Color3.fromRGB(60, 80, 140), {})
	P(m, Vector3.new(0.6, 1.4, 0.6), at(1.2, 4, 0.7, 10, 30, 8), C.Rift, { material = Enum.Material.Neon, light = 10 })
	P(m, Vector3.new(0.9, 0.3, 0.9), at(1.2, 3.35, 0.7), C.IronDark, { material = Enum.Material.Metal })
end

builders.Expedition_Board = function(m)
	for _, x in { -3, 3 } do
		P(m, Vector3.new(0.6, 7, 0.6), at(x, 3.5, 0), C.WoodDark, { material = Enum.Material.Wood })
	end
	local board = P(m, Vector3.new(6.8, 4, 0.4), at(0, 4.4, 0), C.Plank, { material = Enum.Material.WoodPlanks, name = "Board" })
	P(m, Vector3.new(7.4, 0.5, 0.9), at(0, 6.7, 0), C.WoodDark, { material = Enum.Material.Wood })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(340, 200)
	gui.Parent = board
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "EXPEDITIONEN\nVerdant Scar"
	t.TextColor3 = Color3.fromRGB(40, 25, 15)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.Parent = gui
	P(m, Vector3.new(1, 1, 0.1), at(2.4, 5.4, -0.25), C.Rift, Neon)
end

builders.Training_Dummy = function(m)
	P(m, Vector3.new(2.4, 0.4, 2.4), at(0, 0.2, 0), C.WoodDark, { material = Enum.Material.Wood })
	P(m, Vector3.new(0.5, 2.6, 0.5), at(0, 1.5, 0), C.Wood, { material = Enum.Material.Wood })
	P(m, Vector3.new(2, 2.4, 1.3), at(0, 3.4, 0), C.Straw, { material = Enum.Material.Fabric, name = "Body" })
	P(m, Vector3.new(4, 0.4, 0.4), at(0, 4, 0), C.Wood, { material = Enum.Material.Wood })
	P(m, Vector3.new(1.4, 1.4, 1.4), at(0, 5.2, 0), C.Straw, { material = Enum.Material.Fabric, shape = Enum.PartType.Ball })
	P(m, Vector3.new(1.4, 0.3, 0.1), at(0, 3.6, -0.66), C.Cloth, {})
end

--------------------------------------------------------------------------------
-- Ressourcen
--------------------------------------------------------------------------------
builders.Stone_Deposit = function(m)
	rockCluster(m, 0, 0, 2.2, 3.4, C.StoneDark, 5, 1)
	for i = 1, 4 do
		local a = i * 1.6
		P(m, Vector3.new(1.1, 1, 1.1), at(math.cos(a) * 1, 2.6, math.sin(a) * 0.8, i * 20, i * 40, 0), C.Stone, { material = Enum.Material.Slate })
	end
end

builders.Copper_Deposit = function(m)
	rockCluster(m, 0, 0, 2.2, 3.2, C.StoneDark, 4, 2)
	for i = 1, 6 do
		local a = i * 1.05
		P(
			m,
			Vector3.new(0.8, 0.6, 0.8),
			at(math.cos(a) * 1.6, 1.4 + (i % 3) * 0.55, math.sin(a) * 1.2, i * 30, i * 25, 0),
			C.Copper,
			{ material = Enum.Material.Metal }
		)
	end
end

builders.Rift_Deposit = function(m)
	rockCluster(m, 0, 0, 2.2, 2.2, C.StoneDark, 3, 3)
	local spots = { { -0.9, 0.2, 2.6, -12 }, { 0, -0.4, 3.2, 6 }, { 1.1, 0.4, 2.4, 16 }, { 0.5, 0.9, 1.6, -20 } }
	for i, s in spots do
		P(
			m,
			Vector3.new(0.7, s[3], 0.7),
			at(s[1], 1.2 + s[3] / 2, s[2], s[4], i * 35, s[4] * 0.5),
			C.Rift,
			{ material = Enum.Material.Neon, light = if i == 1 then 10 else nil }
		)
	end
end

builders.Timber_Pile = function(m)
	local logs = { { -0.9, 0.8 }, { 0.9, 0.8 }, { 0, 2.2 } }
	for _, l in logs do
		P(m, Vector3.new(5, 1.6, 1.6), at(0, l[2], l[1], 0, 90, 0), C.Bark, { material = Enum.Material.Wood, shape = Enum.PartType.Cylinder })
	end
	for _, z in { -1.8, 1.8 } do
		P(m, Vector3.new(3.4, 0.15, 0.15), at(0, 1.6, z, 90, 0, 0), C.Plank, {})
	end
end

--------------------------------------------------------------------------------
-- Deko
--------------------------------------------------------------------------------
builders.Tree = function(m)
	local rng = Random.new(#m:GetChildren() + 7)
	P(m, Vector3.new(1.4, 8, 1.4), at(0, 4, 0), C.Bark, { material = Enum.Material.Wood })
	P(m, Vector3.new(7, 5, 7), at(0, 9, 0, 0, 20, 0), C.LeafDark, { material = Enum.Material.Grass })
	P(m, Vector3.new(5.5, 4, 5.5), at(0.4, 12, 0.2, 0, 50, 0), C.Leaf, { material = Enum.Material.Grass })
	P(m, Vector3.new(3.4, 3, 3.4), at(-0.2, 14.5, 0, 0, rng:NextNumber(0, 90), 0), C.Leaf, { material = Enum.Material.Grass })
end

builders.Rock = function(m)
	rockCluster(m, 0, 0, 2.6, 5, C.StoneDark, 3, 5)
end

builders.Tent = function(m)
	P(m, Vector3.new(6, 5, 3), at(0, 2.5, -1.5), C.Cloth, { material = Enum.Material.Fabric, shape = Enum.PartType.Wedge })
	P(m, Vector3.new(6, 5, 3), at(0, 2.5, 1.5, 0, 180, 0), C.Cloth, { material = Enum.Material.Fabric, shape = Enum.PartType.Wedge })
	P(m, Vector3.new(0.3, 5.6, 0.3), at(-3.1, 2.8, 0), C.WoodDark, {})
	P(m, Vector3.new(0.3, 5.6, 0.3), at(3.1, 2.8, 0), C.WoodDark, {})
end

builders.Ruin_Pillar = function(m)
	local rng = Random.new(11)
	P(m, Vector3.new(3.4, 1, 3.4), at(0, 0.5, 0), C.Stone, { material = Enum.Material.Slate })
	local h = 1
	for i = 1, 4 do
		local s = 2.4 - i * 0.05
		P(
			m,
			Vector3.new(s, 2.6, s),
			at(rng:NextNumber(-0.15, 0.15), h + 1.3, 0, 0, rng:NextNumber(-8, 8), rng:NextNumber(-3, 3)),
			C.Stone,
			{ material = Enum.Material.Slate }
		)
		h += 2.6
	end
	P(m, Vector3.new(0.8, 1.2, 0.3), at(0, 5, -1.25), C.Rift, Neon)
end

builders.Ruin_Wall = function(m)
	for i = -2, 2 do
		local h = 8 - math.abs(i) * 1.4 - (if i == 1 then 3 else 0)
		P(m, Vector3.new(3, h, 1.8), at(i * 3, h / 2, 0, 0, 0, 0), C.Stone, { material = Enum.Material.Cobblestone })
	end
	P(m, Vector3.new(4, 0.8, 2), at(4.5, 0.4, 2, 0, 30, 10), C.Stone, { material = Enum.Material.Slate })
end

builders.Mine_Beam = function(m)
	for _, x in { -7, 7 } do
		P(m, Vector3.new(1.2, 13, 1.2), at(x, 6.5, 0), C.WoodDark, { material = Enum.Material.Wood })
	end
	P(m, Vector3.new(16, 1.2, 1.4), at(0, 13.4, 0), C.Wood, { material = Enum.Material.Wood })
	P(m, Vector3.new(0.6, 0.9, 0.6), at(0, 12.3, 0), C.Fire, { material = Enum.Material.Neon, light = 18 })
end

builders.Lantern = function(m)
	P(m, Vector3.new(0.4, 5, 0.4), at(0, 2.5, 0), C.WoodDark, {})
	P(m, Vector3.new(0.9, 1.1, 0.9), at(0, 5.3, 0), C.Fire, { material = Enum.Material.Neon, light = 16 })
	P(m, Vector3.new(1.1, 0.25, 1.1), at(0, 5.95, 0), C.IronDark, { material = Enum.Material.Metal })
end

builders.Campfire = function(m)
	for i = 0, 5 do
		local a = i * 60
		P(m, Vector3.new(0.8, 0.8, 0.8), at(math.cos(math.rad(a)) * 2, 0.35, math.sin(math.rad(a)) * 2), C.StoneDark, { material = Enum.Material.Slate })
	end
	P(m, Vector3.new(2.8, 0.5, 0.5), at(0, 0.3, 0, 0, 30, 0), C.Bark, { material = Enum.Material.Wood })
	P(m, Vector3.new(2.8, 0.5, 0.5), at(0, 0.5, 0, 0, -40, 0), C.Bark, { material = Enum.Material.Wood })
	local core = P(m, Vector3.new(1, 0.4, 1), at(0, 0.7, 0), C.Fire, { material = Enum.Material.Neon, light = 22 })
	fire(core, 4)
end

--------------------------------------------------------------------------------
-- Gegner (nur Optik – das Rig mit HumanoidRootPart baut Entities)
--------------------------------------------------------------------------------
builders.Riftling = function(m)
	local body = Color3.fromRGB(78, 88, 100)
	P(m, Vector3.new(0.8, 1.5, 0.8), at(-0.55, 0.75, 0), C.IronDark, { name = "LeftLeg" })
	P(m, Vector3.new(0.8, 1.5, 0.8), at(0.55, 0.75, 0), C.IronDark, { name = "RightLeg" })
	P(m, Vector3.new(2.4, 2, 1.5), at(0, 2.5, 0), body, { material = Enum.Material.Slate, name = "Torso" })
	P(m, Vector3.new(0.6, 0.8, 0.2), at(0, 2.6, -0.8), C.Rift, Neon)
	P(m, Vector3.new(1.6, 1.2, 1.4), at(0, 4.1, 0), body, { material = Enum.Material.Slate, name = "Head" })
	P(m, Vector3.new(0.3, 0.2, 0.1), at(-0.35, 4.15, -0.72), C.Rift, Neon)
	P(m, Vector3.new(0.3, 0.2, 0.1), at(0.35, 4.15, -0.72), C.Rift, Neon)
	P(m, Vector3.new(0.2, 0.8, 0.2), at(-0.5, 5, 0, 0, 0, 20), C.IronDark, {})
	P(m, Vector3.new(0.2, 0.8, 0.2), at(0.5, 5, 0, 0, 0, -20), C.IronDark, {})
	P(m, Vector3.new(0.8, 2, 0.8), at(-1.6, 2.4, 0, 0, 0, 8), body, { material = Enum.Material.Slate, name = "LeftArm" })
	P(m, Vector3.new(0.8, 2, 0.8), at(1.6, 2.4, 0, 0, 0, -8), body, { material = Enum.Material.Slate, name = "RightArm" })
	P(m, Vector3.new(0.3, 0.6, 0.3), at(1.7, 1.2, -0.3), C.Copper, { shape = Enum.PartType.Wedge })
	P(m, Vector3.new(0.3, 0.6, 0.3), at(-1.7, 1.2, -0.3), C.Copper, { shape = Enum.PartType.Wedge })
end

builders.Rootstalker = function(m)
	P(m, Vector3.new(0.6, 2.6, 0.6), at(-0.5, 1.3, 0, 0, 0, 6), C.Bark, { material = Enum.Material.Wood })
	P(m, Vector3.new(0.6, 2.6, 0.6), at(0.5, 1.3, 0, 0, 0, -6), C.Bark, { material = Enum.Material.Wood })
	P(m, Vector3.new(1.8, 2.4, 1.2), at(0, 3.7, 0), C.Bark, { material = Enum.Material.Wood, name = "Torso" })
	P(m, Vector3.new(0.5, 0.7, 0.2), at(0, 3.8, -0.65), Color3.fromRGB(110, 230, 120), Neon)
	P(m, Vector3.new(1.2, 1.2, 1.1), at(0, 5.5, 0), C.Wood, { material = Enum.Material.Wood, name = "Head" })
	P(m, Vector3.new(0.7, 0.15, 0.1), at(0, 5.55, -0.56), Color3.fromRGB(110, 230, 120), Neon)
	P(m, Vector3.new(0.2, 1.4, 0.2), at(-0.5, 6.5, 0, 0, 0, 30), C.WoodDark, {})
	P(m, Vector3.new(0.2, 1.4, 0.2), at(0.5, 6.5, 0, 0, 0, -30), C.WoodDark, {})
	P(m, Vector3.new(0.5, 2.8, 0.5), at(-1.3, 3.3, -0.2, 20, 0, 12), C.Bark, { material = Enum.Material.Wood })
	P(m, Vector3.new(0.5, 2.8, 0.5), at(1.3, 3.3, -0.2, 20, 0, -12), C.Bark, { material = Enum.Material.Wood })
	P(m, Vector3.new(0.9, 0.6, 0.9), at(-1.5, 2, -0.6), C.Copper, {})
	P(m, Vector3.new(0.9, 0.6, 0.9), at(1.5, 2, -0.6), C.Copper, {})
end

builders.Lantern_Wraith = function(m)
	local cloak = Color3.fromRGB(40, 36, 60)
	P(m, Vector3.new(2.2, 2.4, 1.6), at(0, 1.6, 0), cloak, { material = Enum.Material.Fabric, name = "Torso" })
	P(m, Vector3.new(1.4, 1.1, 0.8), at(0, 0.25, 0.3, 0, 180, 0), cloak, { material = Enum.Material.Fabric, shape = Enum.PartType.Wedge })
	P(m, Vector3.new(1.5, 1.4, 1.4), at(0, 3.3, 0), cloak, { material = Enum.Material.Fabric, name = "Head" })
	P(m, Vector3.new(1, 0.9, 0.1), at(0, 3.2, -0.72), Color3.fromRGB(10, 10, 16), {})
	P(m, Vector3.new(0.25, 0.15, 0.05), at(-0.22, 3.3, -0.78), Color3.fromRGB(255, 230, 150), Neon)
	P(m, Vector3.new(0.25, 0.15, 0.05), at(0.22, 3.3, -0.78), Color3.fromRGB(255, 230, 150), Neon)
	P(m, Vector3.new(0.12, 1.4, 0.12), at(1.4, 1.9, -0.6), C.IronDark, {})
	local lantern =
		P(m, Vector3.new(0.8, 0.9, 0.8), at(1.4, 0.9, -0.6), Color3.fromRGB(255, 220, 130), { material = Enum.Material.Neon, name = "LanternLight" })
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 210, 120)
	l.Range = 20
	l.Brightness = 3
	l.Parent = lantern
end

builders.Rift_Crawler = function(m)
	local shell = Color3.fromRGB(46, 56, 66)
	P(m, Vector3.new(2.6, 1.2, 3.6), at(0, 1.3, 0), shell, { material = Enum.Material.Slate, name = "Torso" })
	P(m, Vector3.new(1.6, 0.9, 1.2), at(0, 1.3, -2.2), shell, { material = Enum.Material.Slate, name = "Head" })
	P(m, Vector3.new(0.3, 0.2, 0.1), at(-0.4, 1.4, -2.85), C.Rift, Neon)
	P(m, Vector3.new(0.3, 0.2, 0.1), at(0.4, 1.4, -2.85), C.Rift, Neon)
	for i = -1, 1 do
		for _, s in { -1, 1 } do
			P(m, Vector3.new(1.8, 0.3, 0.3), at(s * 1.8, 0.7, i * 1.1, 0, 0, s * -35), C.IronDark, {})
		end
	end
	for i = 1, 3 do
		P(m, Vector3.new(0.4, 1.2, 0.4), at((i - 2) * 0.6, 2.3, (i - 2) * 0.8, 15, 0, (i - 2) * 15), C.Rift, Neon)
	end
end

builders.Burrow_Mimic = function(m)
	builders.Storage_Chest(m)
	for _, part in m:GetChildren() do
		if part:IsA("BasePart") and part.Name == "Lid" then
			part.Name = "MimicLid"
		end
	end
	for i = -3, 3 do
		local t = P(m, Vector3.new(0.3, 0.45, 0.3), at(i * 0.5, 1.95, -1.25), Color3.fromRGB(240, 230, 210), { name = "Tooth" })
		t.Transparency = 1
	end
	local tongue = P(m, Vector3.new(0.9, 0.2, 1.4), at(0, 1.85, -0.2), Color3.fromRGB(190, 60, 80), { name = "Tongue" })
	tongue.Transparency = 1
end

builders.Hollow_Warden = function(m)
	local rock = Color3.fromRGB(70, 78, 88)
	P(m, Vector3.new(2, 4.2, 2), at(-1.7, 2.1, 0), rock, { material = Enum.Material.Slate })
	P(m, Vector3.new(2, 4.2, 2), at(1.7, 2.1, 0), rock, { material = Enum.Material.Slate })
	P(m, Vector3.new(2.6, 0.9, 3), at(-1.7, 0.45, -0.3), C.StoneDark, { material = Enum.Material.Slate })
	P(m, Vector3.new(2.6, 0.9, 3), at(1.7, 0.45, -0.3), C.StoneDark, { material = Enum.Material.Slate })
	P(m, Vector3.new(6.4, 4.6, 3.8), at(0, 6.4, 0), rock, { material = Enum.Material.Slate, name = "Torso" })
	P(m, Vector3.new(1.4, 1.8, 0.4), at(0, 6.6, -1.95), C.Rift, { material = Enum.Material.Neon, light = 16, name = "Core" })
	P(m, Vector3.new(2, 0.4, 0.4), at(0, 7.7, -2), C.Copper, { material = Enum.Material.Metal })
	P(m, Vector3.new(2.6, 2, 2.4), at(0, 9.7, 0), C.IronDark, { material = Enum.Material.Slate, name = "Head" })
	P(m, Vector3.new(1.6, 0.25, 0.1), at(0, 9.8, -1.22), C.Rift, Neon)
	P(m, Vector3.new(0.5, 2.2, 0.5), at(-1.3, 11.4, 0, 0, 0, 25), C.Copper, { shape = Enum.PartType.Block })
	P(m, Vector3.new(0.5, 2.2, 0.5), at(1.3, 11.4, 0, 0, 0, -25), C.Copper, { shape = Enum.PartType.Block })
	P(m, Vector3.new(2.6, 2.6, 2.6), at(-4.2, 7.8, 0), rock, { material = Enum.Material.Slate })
	P(m, Vector3.new(2.6, 2.6, 2.6), at(4.2, 7.8, 0), rock, { material = Enum.Material.Slate })
	P(m, Vector3.new(1.8, 4, 1.8), at(-4.4, 4.8, 0), rock, { material = Enum.Material.Slate, name = "LeftArm" })
	P(m, Vector3.new(1.8, 4, 1.8), at(4.4, 4.8, 0), rock, { material = Enum.Material.Slate, name = "RightArm" })
	P(m, Vector3.new(2.6, 2, 2.6), at(-4.4, 2.2, 0), C.IronDark, { material = Enum.Material.Slate })
	P(m, Vector3.new(2.6, 2, 2.6), at(4.4, 2.2, 0), C.IronDark, { material = Enum.Material.Slate })
	for i = 1, 3 do
		P(m, Vector3.new(0.5, 1.6, 0.5), at(-4.6 + i * 0.35, 9.6, (i - 2) * 0.6, 0, 0, 10 - i * 10), C.Rift, Neon)
		P(m, Vector3.new(0.5, 1.6, 0.5), at(3.9 + i * 0.35, 9.6, (i - 2) * 0.6, 0, 0, i * 10 - 10), C.Rift, Neon)
	end
end

builders.Stone_Sword = function(m)
	P(m, Vector3.new(0.3, 1.2, 0.3), at(0, 0.6, 0), C.WoodDark, {})
	P(m, Vector3.new(1.4, 0.3, 0.4), at(0, 1.3, 0), C.Copper, {})
	P(m, Vector3.new(0.6, 2.6, 0.15), at(0, 2.75, 0), C.Stone, { material = Enum.Material.Slate })
end

--------------------------------------------------------------------------------
-- Öffentliche API
--------------------------------------------------------------------------------
local function assetFolder(): Instance?
	return ServerStorage:FindFirstChild("RiftboundAssets")
end

function AssetLoader.HasImported(name: string): boolean
	local folder = assetFolder()
	return folder ~= nil and folder:FindFirstChild(name) ~= nil
end

-- Liefert ein Modell mit Ursprung Mitte unten; alle Parts sind verankert.
function AssetLoader.Model(name: string, height: number?): Model
	local targetHeight = height or AssetLoader.Heights[name]
	local folder = assetFolder()
	local template = folder and folder:FindFirstChild(name)
	local model: Model
	if template then
		local clone = template:Clone()
		if clone:IsA("Model") then
			model = clone
		else
			model = Instance.new("Model")
			clone.Parent = model
		end
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			elseif d:IsA("Script") or d:IsA("LocalScript") then
				d:Destroy() -- Creator-Store-Modelle ohne fremde Skripte verwenden
			end
		end
		local yaw = template:GetAttribute("Yaw")
		local cf, size = model:GetBoundingBox()
		if targetHeight and size.Y > 0 then
			model:ScaleTo(model:GetScale() * (targetHeight / size.Y))
			cf, size = model:GetBoundingBox()
		end
		-- Pivot auf Mitte unten setzen
		local bottom = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0))
		if typeof(yaw) == "number" then
			bottom *= CFrame.Angles(0, math.rad(-yaw), 0)
		end
		model.WorldPivot = bottom
		model:SetAttribute("Imported", true)
	else
		model = Instance.new("Model")
		local builder = builders[name]
		if builder then
			builder(model)
		else
			P(model, Vector3.new(3, 3, 3), at(0, 1.5, 0), Color3.fromRGB(255, 0, 255), { name = "Missing_" .. name })
		end
		model.WorldPivot = CFrame.new()
	end
	model.Name = name
	return model
end

function AssetLoader.Place(name: string, cf: CFrame, parent: Instance, height: number?): Model
	local m = AssetLoader.Model(name, height)
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

-- Waffenmodell für die Hand des Spielers. Griff liegt bei (0,0,0), Klinge zeigt nach +Y.
function AssetLoader.Weapon(form: string, colors: { Color3 }, quality: number): Model
	local m = Instance.new("Model")
	m.Name = "Weapon"
	local metal = C.Copper
	local accent = colors[1] or C.Iron
	local accent2 = colors[2] or accent
	local fine = quality >= 3
	local function trim(part: BasePart)
		if fine then
			part.Material = Enum.Material.Neon
		end
	end
	if form == "Hammer" then
		P(m, Vector3.new(0.35, 4.2, 0.35), at(0, 1.6, 0), C.WoodDark, { name = "Handle" })
		P(m, Vector3.new(2.4, 1.3, 1.3), at(0, 3.9, 0), metal, { material = Enum.Material.Metal })
		P(m, Vector3.new(0.35, 1.4, 1.4), at(-1.25, 3.9, 0), accent, { material = Enum.Material.Neon })
		P(m, Vector3.new(0.35, 1.4, 1.4), at(1.25, 3.9, 0), accent2, { material = Enum.Material.Neon })
		trim(P(m, Vector3.new(0.5, 0.3, 0.5), at(0, 0.4, 0), accent, {}))
	elseif form == "Spear" then
		P(m, Vector3.new(0.25, 7, 0.25), at(0, 2.6, 0), C.WoodDark, { name = "Handle" })
		P(m, Vector3.new(0.5, 1.6, 0.18), at(0, 6.9, 0), metal, { material = Enum.Material.Metal })
		P(m, Vector3.new(0.3, 0.9, 0.2), at(0, 7.9, 0), accent, { material = Enum.Material.Neon })
		P(m, Vector3.new(0.35, 0.35, 0.35), at(0, 6, 0), accent2, { material = Enum.Material.Neon })
		trim(P(m, Vector3.new(0.35, 0.25, 0.35), at(0, -0.8, 0), accent, {}))
	else
		P(m, Vector3.new(0.3, 1.2, 0.3), at(0, 0, 0), C.WoodDark, { name = "Handle" })
		P(m, Vector3.new(1.4, 0.3, 0.45), at(0, 0.7, 0), metal, { material = Enum.Material.Metal })
		P(m, Vector3.new(0.5, 3.2, 0.14), at(0, 2.45, 0), metal, { material = Enum.Material.Metal })
		P(m, Vector3.new(0.16, 3, 0.16), at(0, 2.4, 0), accent, { material = Enum.Material.Neon })
		if colors[2] then
			P(m, Vector3.new(0.3, 0.3, 0.3), at(0, 0.7, -0.25), accent2, { material = Enum.Material.Neon })
		end
		trim(P(m, Vector3.new(0.35, 0.35, 0.35), at(0, -0.7, 0), accent, {}))
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	m.PrimaryPart = m:FindFirstChild("Handle") :: BasePart
	return m
end

return AssetLoader
