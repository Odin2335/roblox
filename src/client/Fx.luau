--!nonstrict
-- Rein visuelle Effekte (lokal): Schwünge, Schadenszahlen, Elementeffekte, Boss.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer

local Fx = {}

local folder = Instance.new("Folder")
folder.Name = "ClientFx"
folder.Parent = workspace

local flash: (Color3) -> () = function() end

local function part(size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Parent = folder
	return p
end

local function fade(p: BasePart, t: number, props: { [string]: any }?)
	local goal: { [string]: any } = { Transparency = 1 }
	if props then
		for k, v in props do
			goal[k] = v
		end
	end
	TweenService:Create(p, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(p, t + 0.05)
end

local function ring(pos: Vector3, radius: number, color: Color3, t: number?)
	local p = part(Vector3.new(0.3, 1, 1), CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder)
	p.Transparency = 0.2
	fade(p, t or 0.45, { Size = Vector3.new(0.3, radius * 2, radius * 2) })
end

local function sphere(pos: Vector3, radius: number, color: Color3, t: number?)
	local p = part(Vector3.new(1, 1, 1), CFrame.new(pos), color, Enum.PartType.Ball)
	p.Transparency = 0.3
	p.Material = Enum.Material.ForceField
	fade(p, t or 0.4, { Size = Vector3.one * radius * 2 })
end

local function burst(pos: Vector3, color: Color3, count: number, speed: number)
	for _ = 1, count do
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit
		local p = part(Vector3.one * (0.3 + math.random() * 0.4), CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), color)
		fade(p, 0.5, { CFrame = CFrame.new(pos + dir * speed) * CFrame.Angles(math.random() * 6, math.random() * 6, 0) })
	end
end

local function shake(intensity: number, duration: number)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local h = hum :: Humanoid
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < duration do
			local k = intensity * (1 - (os.clock() - t0) / duration)
			h.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
			task.wait()
		end
		h.CameraOffset = Vector3.zero
	end)
end

local function nearMe(pos: Vector3, range: number): boolean
	local char = player.Character
	local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return r ~= nil and (r.Position - pos).Magnitude < range
end

local function floatText(pos: Vector3, text: string, color: Color3, size: number?)
	local anchor = part(Vector3.new(0.1, 0.1, 0.1), CFrame.new(pos), color)
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	gui.Parent = anchor
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Text = text
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.2
	l.Font = Enum.Font.GothamBlack
	l.TextSize = size or 22
	l.Parent = gui
	local offset = Vector3.new((math.random() - 0.5) * 2, 0, 0)
	TweenService:Create(gui, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = Vector3.new(0, 3, 0) + offset })
		:Play()
	TweenService:Create(l, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 0.9)
end

local function lightning(a: Vector3, b: Vector3, color: Color3)
	local segments = 6
	local prev = a
	for i = 1, segments do
		local t = i / segments
		local target = a:Lerp(b, t)
		if i < segments then
			target += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2.4
		end
		local len = (target - prev).Magnitude
		local p = part(Vector3.new(0.25, 0.25, len), CFrame.lookAt((prev + target) / 2, target), color)
		fade(p, 0.3)
		prev = target
	end
end

--------------------------------------------------------------------------------
-- Schwung-Animation über die Schulter (funktioniert ohne Animations-Assets)
--------------------------------------------------------------------------------
local originals: { [Motor6D]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

local function shoulder(char: Model): Motor6D?
	local upper = char:FindFirstChild("RightUpperArm")
	if upper then
		return upper:FindFirstChild("RightShoulder") :: Motor6D?
	end
	local torso = char:FindFirstChild("Torso")
	return torso and torso:FindFirstChild("Right Shoulder") :: Motor6D?
end

local function swingAnim(char: Model, heavy: boolean)
	local m = shoulder(char)
	if not m then
		return
	end
	local motor = m :: Motor6D
	local base = originals[motor]
	if not base then
		base = motor.C0
		originals[motor] = base
	end
	local r15 = motor.Name == "RightShoulder"
	local raise = if r15 then CFrame.Angles(math.rad(150), 0, math.rad(-20)) else CFrame.Angles(0, 0, math.rad(150))
	local strike = if r15 then CFrame.Angles(math.rad(-30), 0, math.rad(20)) else CFrame.Angles(0, 0, math.rad(-20))
	local up = if heavy then 0.18 else 0.08
	local down = if heavy then 0.14 else 0.1
	TweenService:Create(motor, TweenInfo.new(up, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = base * raise }):Play()
	task.delay(up, function()
		TweenService:Create(motor, TweenInfo.new(down, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { C0 = base * strike }):Play()
		task.delay(down + 0.08, function()
			TweenService:Create(motor, TweenInfo.new(0.2), { C0 = base }):Play()
		end)
	end)
end

local function slashArc(char: Model, heavy: boolean, form: string, color: Color3?)
	local r = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not r then
		return
	end
	local c = color or Color3.fromRGB(235, 240, 245)
	local range = Config.Forms[form].range
	task.delay(if heavy then 0.18 else 0.06, function()
		if form == "Spear" then
			local p = part(Vector3.new(0.4, 0.4, range), r.CFrame * CFrame.new(0, 0.5, -range / 2 - 0.5), c)
			p.Transparency = 0.3
			fade(p, 0.2)
			return
		end
		local radius = range * 0.75
		local n = if heavy then 9 else 7
		for i = 0, n do
			local a = math.rad(-70 + 140 * i / n)
			local pos = r.CFrame * CFrame.new(math.sin(a) * radius, 0.4 - i * 0.12, -math.cos(a) * radius)
			local p = part(
				Vector3.new(0.25, if heavy then 0.8 else 0.5, radius * 0.35),
				CFrame.lookAt(pos.Position, r.Position) * CFrame.Angles(0, math.rad(90), 0),
				c
			)
			p.Transparency = 0.35
			fade(p, 0.18 + i * 0.01)
		end
		if heavy and form == "Hammer" then
			ring(r.Position + r.CFrame.LookVector * (range * 0.6) - Vector3.new(0, 2.5, 0), range * 0.8, c, 0.35)
		end
	end)
end

--------------------------------------------------------------------------------
-- Ereignisse vom Server
--------------------------------------------------------------------------------
local handlers: { [string]: (...any) -> () } = {}

handlers.Swing = function(p: Player, heavy: boolean, form: string, color: Color3?)
	local char = p.Character
	if not char then
		return
	end
	swingAnim(char, heavy)
	slashArc(char, heavy, form, color)
end

handlers.Damage = function(pos: Vector3, amount: number, color: Color3?)
	floatText(pos, tostring(amount), color or Color3.fromRGB(255, 255, 255), if amount >= 30 then 26 else 20)
end

handlers.Immune = function(pos: Vector3)
	floatText(pos + Vector3.new(0, 3, 0), "IMMUN", Color3.fromRGB(160, 170, 180), 18)
end

handlers.Death = function(pos: Vector3, isBoss: boolean)
	burst(pos, Config.Colors.Rift, if isBoss then 30 else 10, if isBoss then 18 else 7)
	if isBoss then
		sphere(pos, 25, Config.Colors.Rift, 1.2)
		shake(1.2, 1)
	end
end

handlers.Windup = function(model: Model, t: number)
	if not model or not model.Parent then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor = Color3.fromRGB(255, 60, 40)
	h.OutlineColor = Color3.fromRGB(255, 120, 80)
	h.FillTransparency = 0.7
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	Debris:AddItem(h, t)
end

handlers.EnemyStrike = function(model: Model)
	local root = model and model.PrimaryPart
	if root then
		burst(root.Position + root.CFrame.LookVector * 3, Color3.fromRGB(255, 120, 80), 4, 3)
	end
end

handlers.PlayerHit = function(p: Player, amount: number)
	if p == player then
		flash(Color3.fromRGB(255, 0, 0))
		shake(0.4 + amount / 40, 0.2)
	end
	local char = p.Character
	local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if r then
		floatText(r.Position + Vector3.new(0, 3, 0), "-" .. math.floor(amount), Color3.fromRGB(255, 90, 90), 18)
	end
end

handlers.PerfectDodge = function(p: Player)
	local char = p.Character
	local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if r then
		floatText(r.Position + Vector3.new(0, 4, 0), "PERFEKT!", Config.Colors.Rift, 22)
	end
end

handlers.Dodge = function(p: Player)
	local char = p.Character
	local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if r then
		ring(r.Position - Vector3.new(0, 2.8, 0), 3, Color3.fromRGB(220, 230, 240), 0.3)
	end
end

handlers.Freeze = function(pos: Vector3)
	burst(pos, Config.Elements.Frost.color, 8, 4)
end

handlers.Roots = function(pos: Vector3, radius: number)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local p = part(
			Vector3.new(0.6, 4, 0.6),
			CFrame.new(pos + Vector3.new(math.cos(a) * radius * 0.6, 2, math.sin(a) * radius * 0.6)) * CFrame.Angles(math.rad(15), a, 0),
			Color3.fromRGB(110, 80, 50)
		)
		p.Material = Enum.Material.Wood
		fade(p, 1.2)
	end
end

handlers.Slam = function(pos: Vector3, radius: number)
	ring(pos, radius, Color3.fromRGB(255, 120, 80), 0.5)
	burst(pos + Vector3.new(0, 1, 0), Color3.fromRGB(120, 110, 100), 12, radius * 0.5)
	if nearMe(pos, radius + 30) then
		shake(1, 0.4)
	end
end

handlers.RootLine = function(cf: CFrame, length: number)
	for i = 0, 8 do
		local pos = (cf * CFrame.new(0, 0, -length / 2 + length * i / 8)).Position
		local p = part(
			Vector3.new(1, 5, 1),
			CFrame.new(pos + Vector3.new(0, 2.5, 0)) * CFrame.Angles(math.rad(math.random(-15, 15)), 0, math.rad(math.random(-15, 15))),
			Color3.fromRGB(110, 80, 50)
		)
		p.Material = Enum.Material.Wood
		fade(p, 1)
	end
end

handlers.BossRoar = function(pos: Vector3)
	if nearMe(pos, 150) then
		shake(0.8, 0.8)
	end
	ring(pos, 30, Config.Colors.Rift, 0.8)
end

handlers.MimicReveal = function(model: Model)
	local root = model and model.PrimaryPart
	if root then
		floatText(root.Position + Vector3.new(0, 4, 0), "MIMIC!", Color3.fromRGB(255, 100, 100), 26)
	end
end

handlers.Shards = function(pos: Vector3, radius: number)
	burst(pos, Color3.fromRGB(255, 200, 220), 10, radius)
	ring(pos - Vector3.new(0, 2, 0), radius, Color3.fromRGB(255, 180, 200), 0.3)
end

handlers.Nova = function(pos: Vector3, radius: number, color: Color3)
	ring(pos - Vector3.new(0, 2.5, 0), radius, color, 0.45)
	sphere(pos, radius * 0.8, color, 0.4)
end

handlers.Explosion = function(pos: Vector3, radius: number, color: Color3)
	sphere(pos, radius, color, 0.45)
	burst(pos, color, 10, radius)
	if nearMe(pos, 40) then
		shake(0.5, 0.25)
	end
end

handlers.Chain = function(a: Vector3, b: Vector3, color: Color3)
	lightning(a, b, color)
	burst(b, color, 4, 3)
end

handlers.Teleport = function(a: Vector3, b: Vector3, color: Color3)
	lightning(a, b, color)
	sphere(a, 3, color, 0.3)
	sphere(b, 3, color, 0.3)
end

handlers.Echo = function(pos: Vector3, color: Color3)
	for _, angle in { 45, -45 } do
		local p = part(Vector3.new(0.4, 7, 0.4), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(angle)), color)
		p.Transparency = 0.1
		fade(p, 0.35)
	end
end

handlers.Trail = function(points: { Vector3 }, radius: number, duration: number)
	for _, pos in points do
		local p = part(
			Vector3.new(0.2, radius * 2, radius * 2),
			CFrame.new(pos - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Config.Elements.Ember.color,
			Enum.PartType.Cylinder
		)
		p.Transparency = 0.45
		local f = Instance.new("Fire")
		f.Size = 4
		f.Heat = 6
		f.Parent = p
		task.delay(duration - 0.4, function()
			f.Enabled = false
			fade(p, 0.4)
		end)
	end
end

handlers.Ability = function(p: Player, el: string)
	local char = p.Character
	local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if r then
		local color = Config.Elements[el].color
		burst(r.Position, color, 12, 6)
		if p == player then
			flash(color)
		end
	end
end

handlers.Harvest = function(pos: Vector3)
	burst(pos + Vector3.new(0, 1.5, 0), Color3.fromRGB(200, 170, 120), 8, 4)
end

handlers.ChestOpen = function(model: Model)
	if model and model.Parent then
		local cf = model:GetBoundingBox()
		burst(cf.Position + Vector3.new(0, 1, 0), Color3.fromRGB(255, 220, 120), 12, 5)
	end
end

handlers.Smelt = function() end

handlers.Arrow = function(p: Player, from: Vector3, to: Vector3)
	local len = (to - from).Magnitude
	if len < 0.5 then
		return
	end
	local arrow = part(Vector3.new(0.15, 0.15, 2.2), CFrame.lookAt(from, to), Color3.fromRGB(230, 210, 170))
	arrow.Material = Enum.Material.SmoothPlastic
	local t = math.min(0.4, len / 160)
	TweenService:Create(arrow, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + (to - from).Unit) }):Play()
	Debris:AddItem(arrow, t + 0.05)
	local trail = part(Vector3.new(0.05, 0.05, len), CFrame.lookAt((from + to) / 2, to), Color3.fromRGB(255, 255, 255))
	trail.Transparency = 0.6
	fade(trail, 0.25)
	local _ = p
end

handlers.Heal = function(p: Player)
	local char = p.Character
	local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if r then
		burst(r.Position, Color3.fromRGB(110, 230, 130), 10, 4)
		floatText(r.Position + Vector3.new(0, 4, 0), "+ HEILUNG", Color3.fromRGB(110, 230, 130), 18)
	end
	if p == player then
		flash(Color3.fromRGB(80, 220, 110))
	end
end

handlers.Recall = function(p: Player, duration: number)
	local char = p.Character
	local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not r then
		return
	end
	local beam = part(
		Vector3.new(0.2, 3, 3),
		CFrame.new(r.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(120, 230, 255),
		Enum.PartType.Cylinder
	)
	beam.Transparency = 0.3
	TweenService:Create(
		beam,
		TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{ Size = Vector3.new(40, 3, 3), CFrame = CFrame.new(r.Position + Vector3.new(0, 17, 0)) * CFrame.Angles(0, 0, math.rad(90)) }
	):Play()
	Debris:AddItem(beam, duration + 0.1)
end

handlers.Rope = function(p: Player, from: Vector3, to: Vector3)
	local len = (to - from).Magnitude
	local rope = part(Vector3.new(0.2, 0.2, len), CFrame.lookAt((from + to) / 2, to), Color3.fromRGB(170, 140, 90))
	rope.Material = Enum.Material.Fabric
	fade(rope, 0.6)
	local _ = p
end

handlers.RiftWave = function(pos: Vector3)
	ring(pos - Vector3.new(0, 2.5, 0), 28, Config.Colors.Rift, 0.8)
	if nearMe(pos, 50) then
		flash(Config.Colors.Rift)
	end
end

function Fx.Init(flashFn: (Color3) -> ())
	flash = flashFn
	Net.Event("Fx").OnClientEvent:Connect(function(kind: string, ...)
		local h = handlers[kind]
		if h then
			local ok, err = pcall(h, ...)
			if not ok then
				warn("[RIFTBOUND] Fx-Fehler", kind, err)
			end
		end
	end)
end

return Fx
