--!nonstrict
-- Expeditionsausrüstung: Kupferbogen, Heiltränke, Rückruf-Signalgeber,
-- Seilwerfer-Ankerpunkte und die sichtbaren Camp-Ausbauten.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Gear = {}
local ctx: any

local FxEvent = Net.Event("Fx")

--------------------------------------------------------------------------------
-- Aktionen (über das Action-Remote)
--------------------------------------------------------------------------------
local function shootBow(player: Player, dir: any)
	local s = ctx.PlayerState.Get(player)
	local profile = ctx.DataService.Get(player)
	local root = ctx.PlayerState.GetRoot(player)
	if not s or not profile or not root then
		return
	end
	if not profile.tools.CopperBow then
		ctx.PlayerState.Notify(player, "Du hast keinen Kupferbogen. Bauplan finden und an der Werkbank herstellen.", "bad")
		return
	end
	if typeof(dir) ~= "Vector3" or dir.Magnitude < 0.1 or dir.Magnitude ~= dir.Magnitude then
		return
	end
	local now = os.clock()
	if now - s.lastBow < Config.Bow.Cooldown * 0.9 then
		return
	end
	if (profile.stash.Arrow or 0) < 1 then
		ctx.PlayerState.Notify(player, "Keine Pfeile! An der Werkbank herstellen.", "bad")
		return
	end
	if not ctx.PlayerState.UseStamina(player, Config.Bow.Stamina) then
		return
	end
	s.lastBow = now
	ctx.DataService.Take(player, { Arrow = 1 })
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local unit = dir.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter = { workspace:FindFirstChild("Telegraphs") }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(filter, p.Character)
		end
	end
	params.FilterDescendantsInstances = filter
	local hit = workspace:Raycast(origin, unit * Config.Bow.Range, params)
	local finish = if hit then hit.Position else origin + unit * Config.Bow.Range
	FxEvent:FireAllClients("Arrow", player, origin, finish)
	if hit then
		local e = ctx.Entities.FromPart(hit.Instance)
		if e then
			local dmg = Config.Bow.Damage * (if e.kind == "Lantern_Wraith" then 1.6 else 1)
			ctx.Entities.Damage(e, dmg, { player = player, color = Color3.fromRGB(230, 210, 170) })
		end
	end
	ctx.PlayerState.Sync(player)
end

local function drinkPotion(player: Player)
	local s = ctx.PlayerState.Get(player)
	local profile = ctx.DataService.Get(player)
	if not s or not profile then
		return
	end
	local now = os.clock()
	if now - s.lastPotion < Config.Potion.Cooldown then
		return
	end
	if s.hp >= Config.Player.MaxHP then
		ctx.PlayerState.Notify(player, "Du bist schon voll geheilt.", "info")
		return
	end
	if not ctx.DataService.Take(player, { Potion = 1 }) then
		ctx.PlayerState.Notify(player, "Keine Heiltränke. Braue sie an der Werkbank aus Heilkräutern.", "bad")
		return
	end
	s.lastPotion = now
	ctx.PlayerState.Heal(player, Config.Potion.Heal)
	FxEvent:FireAllClients("Heal", player)
	ctx.PlayerState.Sync(player)
end

local function recall(player: Player)
	local s = ctx.PlayerState.Get(player)
	local profile = ctx.DataService.Get(player)
	if not s or not profile or not s.inRun or s.recalling then
		return
	end
	if s.usedRecall then
		ctx.PlayerState.Notify(player, "Der Signalgeber wurde in dieser Expedition schon benutzt.", "bad")
		return
	end
	if (profile.stash.RecallBeacon or 0) < 1 then
		ctx.PlayerState.Notify(player, "Kein Rückruf-Signalgeber. An der Werkbank herstellen.", "bad")
		return
	end
	s.recalling = true
	ctx.PlayerState.Notify(player, "Rückruf in " .. Config.Recall.Channel .. " s … nicht getroffen werden!", "info")
	FxEvent:FireAllClients("Recall", player, Config.Recall.Channel)
	task.delay(Config.Recall.Channel, function()
		local cur = ctx.PlayerState.Get(player)
		if cur ~= s or not s.recalling or not s.inRun or s.downed then
			return
		end
		s.recalling = false
		if not ctx.DataService.Take(player, { RecallBeacon = 1 }) then
			return
		end
		s.usedRecall = true
		ctx.PlayerState.Notify(player, "Notflucht geglückt!", "good")
		ctx.Expedition.ReturnPlayer(player, true, true)
	end)
end

-- Liefert true, wenn die Aktion hier behandelt wurde.
function Gear.Action(player: Player, action: string, arg: any): boolean
	if action == "Bow" then
		shootBow(player, arg)
	elseif action == "Potion" then
		drinkPotion(player)
	elseif action == "Recall" then
		recall(player)
	else
		return false
	end
	return true
end

--------------------------------------------------------------------------------
-- Seilwerfer
--------------------------------------------------------------------------------
function Gear.SetupGrapple(anchor: BasePart, destination: Vector3, reachesCave: boolean)
	local prompt = ctx.WorldBuilder.Prompt(anchor, "Seilwerfer benutzen", if reachesCave then "Abgrund → Höhle" else "Abgrund → zurück", 0.3)
	prompt.MaxActivationDistance = 14
	prompt.Triggered:Connect(function(player)
		local profile = ctx.DataService.Get(player)
		if not profile or not ctx.PlayerState.IsActive(player) then
			return
		end
		if not profile.tools.Grapple then
			ctx.PlayerState.Notify(player, "Hier brauchst du einen Seilwerfer. Den Bauplan findest du in Truhen.", "bad")
			return
		end
		local char = player.Character
		local root = ctx.PlayerState.GetRoot(player)
		if not char or not root then
			return
		end
		FxEvent:FireAllClients("Rope", player, root.Position, destination + Vector3.new(0, 3, 0))
		-- kurze Flugbahn in Schritten
		local from = root.Position
		local to = destination + Vector3.new(0, 3.5, 0)
		local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
		local rot = if flat.Magnitude > 0.1 then CFrame.lookAt(Vector3.zero, flat).Rotation else CFrame.identity
		for i = 1, 8 do
			local t = i / 8
			local pos = from:Lerp(to, t) + Vector3.new(0, math.sin(t * math.pi) * 6, 0)
			char:PivotTo(CFrame.new(pos) * rot)
			task.wait(0.05)
		end
		root.AssemblyLinearVelocity = Vector3.zero
		if reachesCave then
			ctx.Progress.Milestone(player, "ReachCave")
		end
	end)
end

--------------------------------------------------------------------------------
-- Camp-Ausbauten (sichtbar, sobald ein Spieler auf dem Server sie besitzt)
--------------------------------------------------------------------------------
local upgradeFolder: Folder? = nil
local upgradeModels: { [string]: Model } = {}

local function part(model: Model, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function buildUpgradeModels()
	local C = ctx.AssetLoader.Colors
	-- Großer Schmelzofen
	local furnace = ctx.AssetLoader.Model("Smelting_Furnace", 10)
	furnace:PivotTo(CFrame.new(-54, 0, 28) * CFrame.Angles(0, math.rad(60), 0))
	local pipe = part(furnace, Vector3.new(1.2, 1.2, 12), CFrame.new(-48, 7.5, 22) * CFrame.Angles(0, math.rad(45), 0), C.IronDark, Enum.Material.Metal)
	pipe.Name = "Pipe"
	furnace.Name = "BigFurnace"
	upgradeModels.BigFurnace = furnace

	-- Kräuterbeet
	local garden = Instance.new("Model")
	garden.Name = "HerbGarden"
	local base = Vector3.new(34, 0, -24)
	part(garden, Vector3.new(12, 0.8, 7), CFrame.new(base + Vector3.new(0, 0.4, 0)), Color3.fromRGB(90, 62, 40), Enum.Material.Ground)
	for x = -4, 4, 2 do
		for z = -2, 2, 2 do
			local h = 0.8 + ((x + z) % 3) * 0.3
			part(
				garden,
				Vector3.new(0.8, h, 0.8),
				CFrame.new(base + Vector3.new(x, 0.8 + h / 2, z)) * CFrame.Angles(0, math.rad(x * 20), 0),
				Color3.fromRGB(80, 190, 100),
				Enum.Material.Grass
			)
		end
	end
	for _, dx in { -6.2, 6.2 } do
		part(garden, Vector3.new(0.4, 1.2, 7.4), CFrame.new(base + Vector3.new(dx, 0.6, 0)), C.Wood, Enum.Material.Wood)
	end
	upgradeModels.HerbGarden = garden

	-- Rift-Wachturm
	local tower = Instance.new("Model")
	tower.Name = "Watchtower"
	local tb = Vector3.new(-22, 0, -46)
	for _, o in { Vector3.new(-2.5, 0, -2.5), Vector3.new(2.5, 0, -2.5), Vector3.new(-2.5, 0, 2.5), Vector3.new(2.5, 0, 2.5) } do
		part(tower, Vector3.new(0.9, 16, 0.9), CFrame.new(tb + o + Vector3.new(0, 8, 0)), C.WoodDark, Enum.Material.Wood)
	end
	part(tower, Vector3.new(7, 0.6, 7), CFrame.new(tb + Vector3.new(0, 16, 0)), C.Plank, Enum.Material.WoodPlanks)
	part(tower, Vector3.new(7, 3.5, 0.4), CFrame.new(tb + Vector3.new(0, 17.8, 3.3)), C.Wood, Enum.Material.WoodPlanks)
	part(tower, Vector3.new(7, 3.5, 0.4), CFrame.new(tb + Vector3.new(0, 17.8, -3.3)), C.Wood, Enum.Material.WoodPlanks)
	local beacon = part(tower, Vector3.new(1.4, 2.4, 1.4), CFrame.new(tb + Vector3.new(0, 18, 0)), C.Rift, Enum.Material.Neon)
	local l = Instance.new("PointLight")
	l.Color = C.Rift
	l.Range = 30
	l.Brightness = 2
	l.Parent = beacon
	upgradeModels.Watchtower = tower
end

function Gear.RefreshCamp()
	if not upgradeFolder then
		return
	end
	local owned: { [string]: boolean } = {}
	for _, p in Players:GetPlayers() do
		local profile = ctx.DataService.Get(p)
		if profile then
			for id in profile.upgrades do
				owned[id] = true
			end
		end
	end
	for id, model in upgradeModels do
		model.Parent = if owned[id] then upgradeFolder else nil
	end
end

function Gear.Init(context)
	ctx = context
end

function Gear.Start()
	local folder = Instance.new("Folder")
	folder.Name = "CampUpgrades"
	folder.Parent = workspace
	upgradeFolder = folder
	buildUpgradeModels()
	Players.PlayerRemoving:Connect(function()
		task.defer(Gear.RefreshCamp)
	end)
	Gear.RefreshCamp()
end

return Gear
