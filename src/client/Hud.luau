--!strict
-- HUD: Leben, Ausdauer, Elementladung, Bossleiste, Ziel, Hinweise, Menü- und Handy-Tasten.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local UI = require(script.Parent.UI)
local Store = require(script.Parent.Store)

local player = Players.LocalPlayer

local Hud = {}

local gui: ScreenGui
local toastList: Frame
local objective: TextLabel
local weaponLabel: TextLabel
local chargeBack: Frame
local bossFrame: Frame
local bossFill: Frame
local bossText: TextLabel
local burstText: TextLabel
local runFrame: Frame
local runTime: TextLabel
local runBag: TextLabel
local downedFrame: Frame
local vignette: Frame

local TOAST_COLORS = {
	info = UI.C.Card,
	good = Color3.fromRGB(34, 74, 52),
	bad = Color3.fromRGB(86, 34, 34),
	loot = Color3.fromRGB(30, 50, 62),
	loot_protected = Color3.fromRGB(70, 56, 24),
	milestone = Color3.fromRGB(24, 78, 72),
	boss = Color3.fromRGB(80, 30, 70),
}

function Hud.Toast(text: string, kind: string?)
	local color = TOAST_COLORS[kind or "info"] or UI.C.Card
	local card = UI.new("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = 0.08,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = -math.floor(os.clock() * 100),
		Parent = toastList,
	}, { UI.Corner(8), UI.Pad(8), UI.Stroke(if kind == "milestone" then UI.C.Rift else UI.C.Stroke) })
	UI.Label(text, 14, UI.C.Text, if kind == "milestone" or kind == "boss" then UI.FontBold else UI.Font, { Parent = card })
	local children = toastList:GetChildren()
	local frames = {}
	for _, c in children do
		if c:IsA("Frame") then
			table.insert(frames, c)
		end
	end
	if #frames > 6 then
		table.sort(frames, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		frames[1]:Destroy()
	end
	task.delay(if kind == "milestone" or kind == "boss" then 6 else 4, function()
		if card.Parent then
			TweenService:Create(card, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			task.wait(0.4)
			card:Destroy()
		end
	end)
end

function Hud.Flash(color: Color3)
	vignette.BackgroundColor3 = color
	vignette.BackgroundTransparency = 0.6
	TweenService:Create(vignette, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
end

local function nextObjective(): string
	local s = Store.state
	for _, m in Config.Milestones do
		if not s.milestones[m.id] then
			return "<b>Ziel:</b> " .. m.hint
		end
	end
	return "<b>Ziel:</b> Probiere neue Kombinationen und fordere den Warden auf <b>Hart</b> heraus."
end

local function refresh()
	local s = Store.state
	objective.Text = nextObjective()
	local w = Store.Equipped()
	if w then
		local q = Config.Quality[w.quality or 1]
		local colored = UI.WeaponName(w)
		if w.e1 then
			colored = UI.Colored(colored, Config.Elements[w.e1].color)
		end
		weaponLabel.Text = colored .. '  <font color="#8CA0AC">(' .. (q and q.name or "") .. (if w.part then ", " .. UI.ItemName(w.part) else "") .. ")</font>"
	else
		weaponLabel.Text = UI.Colored("Keine Waffe – geh zur Schmiede!", UI.C.Danger)
	end
	runFrame.Visible = s.inRun
	if s.inRun then
		local total = 0
		for _, n in s.backpack do
			total += n
		end
		local prot = 0
		for _, n in s.protectedLoot do
			prot += n
		end
		runBag.Text = "Rucksack: <b>" .. total .. "</b> ungesichert" .. (if prot > 0 then "  ·  " .. prot .. " Bossbeute" else "")
	end
end

local function makeBars(parent: Instance)
	local box = UI.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = parent,
	}, { UI.List(5) })
	local title = UI.Label("RIFTBOUND", 16, UI.C.Rift, UI.FontBlack, { LayoutOrder = 0, Parent = box })
	title.TextStrokeTransparency = 0.6
	local hpBack, hpFill, hpText = UI.Bar(UI.C.Danger, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 18), Parent = box })
	local _, stFill, _ = UI.Bar(UI.C.Stamina, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 8), Parent = box })
	local chBack, chFill, chText = UI.Bar(UI.C.Rift, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 12), Parent = box })
	chargeBack = chBack
	weaponLabel = UI.Label("", 13, UI.C.Text, UI.FontBold, { LayoutOrder = 4, Parent = box })
	weaponLabel.TextStrokeTransparency = 0.6

	RunService.RenderStepped:Connect(function()
		local hp = player:GetAttribute("HP") or 100
		local maxHp = player:GetAttribute("MaxHP") or 100
		local st = player:GetAttribute("Stamina") or 100
		local ch = player:GetAttribute("Charge") or 0
		hpFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
		hpText.Text = hp .. " / " .. maxHp
		stFill.Size = UDim2.fromScale(math.clamp(st / Config.Player.MaxStamina, 0, 1), 1)
		chargeBack.Visible = player:GetAttribute("HasElement") == true
		chFill.Size = UDim2.fromScale(math.clamp(ch / 100, 0, 1), 1)
		local w = Store.Equipped()
		if w and w.e1 then
			chFill.BackgroundColor3 = Config.Elements[w.e1].color
		end
		chText.Text = if ch >= 100 then "ELEMENT BEREIT  [F]" else ""
		hpBack.Visible = true
	end)
end

local function makeBoss(parent: Instance)
	bossFrame = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(0.44, 0, 0, 46),
		Visible = false,
		Parent = parent,
	})
	bossText = UI.Label("Hollow Warden", 16, UI.C.Text, UI.FontBlack, { Parent = bossFrame, TextXAlignment = Enum.TextXAlignment.Center })
	bossText.TextStrokeTransparency = 0.4
	local _, fill = UI.Bar(Color3.fromRGB(200, 60, 80), { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 14), Parent = bossFrame })
	bossFill = fill
	burstText =
		UI.Label("", 15, UI.C.Rift, UI.FontBlack, { Position = UDim2.fromOffset(0, 40), Parent = bossFrame, TextXAlignment = Enum.TextXAlignment.Center })
	burstText.TextStrokeTransparency = 0.3

	RunService.Heartbeat:Connect(function()
		local active = ReplicatedStorage:GetAttribute("BossActive") == true and Store.state.inRun
		bossFrame.Visible = active
		if active then
			local hp = ReplicatedStorage:GetAttribute("BossHP") or 0
			local maxHp = ReplicatedStorage:GetAttribute("BossMaxHP") or 1
			bossFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
			bossText.Text = (ReplicatedStorage:GetAttribute("BossName") or "Boss") .. "  ·  " .. hp .. " / " .. maxHp
			local burst = ReplicatedStorage:GetAttribute("BossBurst") or 0
			burstText.Text = if burst > 0 then "RIFT-AUSBRUCH in " .. burst .. " s – Kristalle zerstören!" else ""
		end
		if runFrame.Visible then
			local start = ReplicatedStorage:GetAttribute("RunStart") or 0
			if start > 0 then
				local t = math.max(0, workspace:GetServerTimeNow() - start)
				runTime.Text = string.format("Expedition  %02d:%02d", math.floor(t / 60), math.floor(t % 60))
				runTime.TextColor3 = if t > 15 * 60 then UI.C.Stamina else UI.C.Text
			end
		end
	end)
end

local function makeRunInfo(parent: Instance)
	runFrame = UI.new("Frame", {
		BackgroundColor3 = UI.C.Panel,
		BackgroundTransparency = 0.2,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = parent,
	}, { UI.Corner(8), UI.Pad(8), UI.List(3), UI.Stroke() })
	runTime = UI.Label("Expedition 00:00", 15, UI.C.Text, UI.FontBlack, { Parent = runFrame })
	runBag = UI.Label("", 13, UI.C.Dim, UI.Font, { Parent = runFrame })
	UI.Label("Beute am <b>Rückkehrportal</b> sichern.", 12, UI.C.Dim, UI.Font, { Parent = runFrame })
end

local function makeDowned(parent: Instance)
	downedFrame = UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(60, 0, 0),
		BackgroundTransparency = 0.65,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	})
	local text = UI.Label("", 26, UI.C.Text, UI.FontBlack, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.new(0.8, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 6,
		Parent = downedFrame,
	})
	local since = 0
	player:GetAttributeChangedSignal("Downed"):Connect(function()
		local d = player:GetAttribute("Downed") == true
		downedFrame.Visible = d
		since = os.clock()
	end)
	RunService.Heartbeat:Connect(function()
		if downedFrame.Visible then
			local left = math.max(0, Config.Player.BleedoutTime - (os.clock() - since))
			text.Text = 'NIEDERGESCHLAGEN\n<font size="18">Ein Teammitglied kann dich wiederbeleben · ' .. math.ceil(left) .. " s</font>"
		end
	end)
end

export type Actions = {
	openPanel: (string) -> (),
	action: (string) -> (),
}

local function makeMenuButtons(parent: Instance, actions: Actions)
	local bar = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = parent,
	}, { UI.List(8, true) })
	UI.Button("Arsenal [I]", UI.C.Panel, function()
		actions.openPanel("Inventory")
	end, { Size = UDim2.fromOffset(120, 40), Parent = bar })
	UI.Button("Aufgaben [J]", UI.C.Panel, function()
		actions.openPanel("Quests")
	end, { Size = UDim2.fromOffset(120, 40), Parent = bar })
	UI.Button("Hilfe [H]", UI.C.Panel, function()
		actions.openPanel("Help")
	end, { Size = UDim2.fromOffset(90, 40), Parent = bar })
end

local function makeTouchButtons(parent: Instance, actions: Actions)
	local holder = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -150),
		Size = UDim2.fromOffset(220, 200),
		Parent = parent,
	})
	local function btn(text: string, pos: UDim2, size: number, color: Color3, action: string)
		local b = UI.new("TextButton", {
			Text = text,
			Font = UI.FontBlack,
			TextSize = if size > 80 then 16 else 12,
			TextColor3 = UI.C.Text,
			BackgroundColor3 = color,
			BackgroundTransparency = 0.15,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = pos,
			Size = UDim2.fromOffset(size, size),
			Parent = holder,
		}, { UI.Corner(size), UI.Stroke(Color3.fromRGB(255, 255, 255), 1.5) })
		b.Activated:Connect(function()
			actions.action(action)
		end)
		return b
	end
	btn("ANGRIFF", UDim2.fromOffset(150, 140), 92, Color3.fromRGB(70, 80, 92), "Light")
	btn("SCHWER", UDim2.fromOffset(60, 150), 64, Color3.fromRGB(120, 70, 50), "Heavy")
	btn("AUS-\nWEICHEN", UDim2.fromOffset(170, 50), 62, Color3.fromRGB(60, 90, 70), "Dodge")
	local el = btn("ELEMENT", UDim2.fromOffset(80, 64), 60, Color3.fromRGB(30, 110, 100), "Ability")
	RunService.Heartbeat:Connect(function()
		el.Visible = player:GetAttribute("HasElement") == true
		el.BackgroundTransparency = if (player:GetAttribute("Charge") or 0) >= 100 then 0 else 0.6
	end)
end

function Hud.Init(actions: Actions)
	gui = UI.new("ScreenGui", {
		Name = "RiftboundHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	vignette = UI.new("Frame", {
		BackgroundColor3 = Color3.new(1, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = gui,
	})
	makeBars(gui)
	makeBoss(gui)
	makeRunInfo(gui)
	makeDowned(gui)
	makeMenuButtons(gui, actions)

	objective = UI.Label("", 14, UI.C.Text, UI.Font, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -70),
		Size = UDim2.new(0.5, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = gui,
	})
	objective.TextStrokeTransparency = 0.4

	toastList = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 120),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = gui,
	}, { UI.List(6) })

	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if touch then
		makeTouchButtons(gui, actions)
	else
		local hint = UI.Label("Linksklick: leicht · R / Rechtsklick: schwer · Q: ausweichen · F: Element · E: interagieren", 12, UI.C.Dim, UI.Font, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(0.6, 0, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = gui,
		})
		hint.TextStrokeTransparency = 0.6
	end

	Net.Event("Notify").OnClientEvent:Connect(Hud.Toast)
	Store.Changed:Connect(refresh)
	refresh()
end

return Hud
