--!nonstrict
-- Menüs: Schmiede (mit Härtungsschritt), Schmelzofen, Forschung, Lagerkiste,
-- Expeditionstafel, Arsenal, Aufgaben und Hilfe.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local UI = require(script.Parent.UI)
local Store = require(script.Parent.Store)

local player = Players.LocalPlayer
local Request = Net.Event("Request")

local Panels = {}

local gui: ScreenGui
local window: Frame
local titleLabel: TextLabel
local content: Frame
local current: string? = nil
local hardeningActive = false
local toast: (string, string?) -> () = function() end

local TITLES = {
	Forge = "Schmiede",
	Furnace = "Schmelzofen",
	Research = "Forschungstisch",
	Chest = "Gemeinsame Lagerkiste",
	Board = "Expeditionstafel",
	Inventory = "Arsenal & Inventar",
	Quests = "Aufgaben & Meilensteine",
	Help = "So spielst du RIFTBOUND",
}

local function send(action: string, a: any?, b: any?)
	Request:FireServer(action, a, b)
end

local function section(parent: Instance, text: string, order: number)
	UI.Label(text, 13, UI.C.Rift, UI.FontBlack, { LayoutOrder = order, Parent = parent })
end

local function row(parent: Instance, order: number, height: number?): Frame
	local r = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height or 34),
		LayoutOrder = order,
		Parent = parent,
	}, { UI.List(6, true) })
	return r
end

local function costText(cost: { [string]: number }): string
	local parts = {}
	for _, id in Config.ItemOrder do
		local need = cost[id]
		if need then
			local have = Store.Count(id)
			local color = if have >= need then UI.C.Good else UI.C.Danger
			table.insert(parts, UI.Colored(UI.ItemName(id) .. " " .. have .. "/" .. need, color))
		end
	end
	return table.concat(parts, "   ")
end

local function hasAll(cost: { [string]: number }): boolean
	for id, n in cost do
		if Store.Count(id) < n then
			return false
		end
	end
	return true
end

local function twoColumns(): (ScrollingFrame, Frame)
	local left = UI.Scroll({ Size = UDim2.new(0.56, -6, 1, 0), Parent = content })
	UI.List(8).Parent = left
	UI.new("UIPadding", { PaddingRight = UDim.new(0, 8), Parent = left })
	local right = UI.new("Frame", {
		BackgroundColor3 = UI.C.Bg,
		Position = UDim2.new(0.56, 6, 0, 0),
		Size = UDim2.new(0.44, -6, 1, 0),
		Parent = content,
	}, { UI.Corner(8), UI.Pad(10) })
	return left, right
end

--------------------------------------------------------------------------------
-- Schmiede
--------------------------------------------------------------------------------
local sel = { form = "Sword", e1 = nil :: string?, e2 = nil :: string?, part = nil :: string?, blueprint = nil :: number? }

local function recipeCost(): { [string]: number }
	local cost: { [string]: number } = {}
	for k, v in Config.Forms[sel.form].cost do
		cost[k] = (cost[k] or 0) + v
	end
	for _, el in { sel.e1, sel.e2 } do
		if el then
			local core = Config.Elements[el].core
			cost[core] = (cost[core] or 0) + 1
			for k, v in Config.ElementCost do
				cost[k] = (cost[k] or 0) + v
			end
		end
	end
	if sel.part then
		cost[sel.part] = (cost[sel.part] or 0) + 1
	end
	return cost
end

local function startHardening()
	if hardeningActive then
		return
	end
	local result = Net.Function("ForgeBegin"):InvokeServer({ form = sel.form, e1 = sel.e1, e2 = sel.e2, part = sel.part, blueprint = sel.blueprint })
	if not result or not result.ok then
		toast(if result then result.msg else "Fehler", "bad")
		return
	end
	hardeningActive = true
	local start = result.start
	local overlay = UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(8, 10, 14),
		BackgroundTransparency = 0.1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Active = true,
		Parent = window,
	}, { UI.Corner(12) })
	local info = UI.Label("<b>Härten:</b> Schlag, wenn der Marker in der Mitte ist! (Leertaste, Klick oder Knopf)", 16, UI.C.Text, UI.Font, {
		Position = UDim2.new(0.1, 0, 0.14, 0),
		Size = UDim2.new(0.8, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 21,
		Parent = overlay,
	})
	local bar = UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 30, 26),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0.8, 0, 0, 34),
		ZIndex = 21,
		Parent = overlay,
	}, { UI.Corner(6), UI.Stroke(UI.C.Copper, 2) })
	UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(200, 120, 50),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(Config.Hardening.Good * 2, 1),
		ZIndex = 22,
		Parent = bar,
	})
	UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 230, 140),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(Config.Hardening.Perfect * 2, 1),
		ZIndex = 23,
		Parent = bar,
	})
	local marker = UI.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 6, 1, 16),
		ZIndex = 24,
		Parent = bar,
	}, { UI.Corner(3) })
	local feedback = UI.Label("", 20, UI.C.Text, UI.FontBlack, {
		Position = UDim2.new(0.1, 0, 0.52, 0),
		Size = UDim2.new(0.8, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 21,
		Parent = overlay,
	})
	local strikeButton = UI.Button("SCHLAG!", UI.C.Copper, nil, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.66),
		Size = UDim2.fromOffset(220, 56),
		TextSize = 22,
		ZIndex = 21,
		Parent = overlay,
	})
	local times: { number } = {}
	local words = {}
	local done = false
	local conns: { RBXScriptConnection } = {}

	local function finish()
		if done then
			return
		end
		done = true
		for _, c in conns do
			c:Disconnect()
		end
		strikeButton.Visible = false
		info.Text = "Die Klinge kühlt ab ..."
		local res = Net.Function("ForgeFinish"):InvokeServer(times)
		if res and res.ok then
			feedback.Text = UI.Colored(res.msg, UI.C.Rift)
			toast(res.msg, "milestone")
		else
			feedback.Text = UI.Colored(if res then res.msg else "Fehler", UI.C.Danger)
		end
		task.wait(1.6)
		overlay:Destroy()
		hardeningActive = false
	end

	local function strike()
		if done or #times >= Config.Hardening.Strikes then
			return
		end
		local now = workspace:GetServerTimeNow()
		if now < start then
			return
		end
		table.insert(times, now)
		local off = math.abs(Config.HardeningPos(now - start) - 0.5)
		local word = if off <= Config.Hardening.Perfect
			then UI.Colored("PERFEKT", Color3.fromRGB(255, 230, 140))
			elseif off <= Config.Hardening.Good then UI.Colored("GUT", UI.C.Copper)
			else UI.Colored("daneben", UI.C.Dim)
		table.insert(words, word)
		feedback.Text = table.concat(words, "  ·  ")
		if #times >= Config.Hardening.Strikes then
			task.spawn(finish)
		end
	end
	strikeButton.Activated:Connect(strike)
	table.insert(
		conns,
		UserInputService.InputBegan:Connect(function(input, processed)
			if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
				strike()
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
				strike()
			end
		end)
	)
	table.insert(
		conns,
		RunService.RenderStepped:Connect(function()
			local now = workspace:GetServerTimeNow()
			if now < start then
				marker.Position = UDim2.fromScale(0, 0.5)
				return
			end
			marker.Position = UDim2.fromScale(Config.HardeningPos(now - start), 0.5)
			if now - start > Config.Hardening.Timeout then
				task.spawn(finish)
			end
		end)
	)
end

local function renderForge()
	local s = Store.state
	local left, right = twoColumns()
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	section(left, "WAFFENFORM", nextOrder())
	local formRow = row(left, nextOrder(), 40)
	for _, id in Config.FormOrder do
		local def = Config.Forms[id]
		local unlocked = s.unlocked[id] == true
		local active = sel.form == id
		UI.Button(def.name .. (if unlocked then "" else "\n(erforschen)"), if active then UI.C.Copper elseif unlocked then UI.C.Card else UI.C.Bg, function()
			if not unlocked then
				toast(def.name .. " musst du erst am Forschungstisch freischalten.", "bad")
				return
			end
			sel.form = id
			Panels.Refresh()
		end, { Size = UDim2.new(1 / 3, -4, 1, 0), TextSize = 13, Parent = formRow })
	end

	local function elementRow(label: string, slot: string)
		section(left, label, nextOrder())
		local r = row(left, nextOrder(), 44)
		local current = (sel :: any)[slot]
		local other = if slot == "e1" then sel.e2 else sel.e1
		UI.Button("Kein", if current == nil then UI.C.Copper else UI.C.Card, function()
			(sel :: any)[slot] = nil
			if slot == "e1" then
				sel.e1, sel.e2 = sel.e2, nil
			end
			Panels.Refresh()
		end, { Size = UDim2.new(0.2, -5, 1, 0), TextSize = 12, Parent = r })
		for _, el in Config.ElementOrder do
			local def = Config.Elements[el]
			local count = Store.Count(def.core)
			local disabled = el == other or (slot == "e2" and sel.e1 == nil)
			local b = UI.Button(def.name .. "\n" .. count .. "×", if current == el then def.color else UI.C.Card, function()
				if disabled then
					return
				end
				(sel :: any)[slot] = el
				Panels.Refresh()
			end, { Size = UDim2.new(0.2, -5, 1, 0), TextSize = 12, Parent = r })
			b.TextColor3 = if current == el then Color3.fromRGB(20, 20, 20) else def.color
			if disabled or count == 0 then
				b.BackgroundTransparency = 0.5
				b.TextTransparency = 0.4
			end
		end
	end
	elementRow("ERSTER ELEMENTKERN (Haupteffekt)", "e1")
	elementRow("ZWEITER ELEMENTKERN (optional, Kombination)", "e2")

	section(left, "MONSTERTEIL (optional, jederzeit wieder entfernbar)", nextOrder())
	local partRow = UI.new(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), Parent = left },
		{
			UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 32), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		}
	)
	UI.Button("Kein Monsterteil", if sel.part == nil then UI.C.Copper else UI.C.Card, function()
		sel.part = nil
		Panels.Refresh()
	end, { TextSize = 12, Parent = partRow })
	for _, id in Config.ItemOrder do
		if Config.Items[id].kind == "Part" and Store.Count(id) > 0 then
			UI.Button(UI.ItemName(id) .. " (" .. Store.Count(id) .. ")", if sel.part == id then UI.C.Copper else UI.C.Card, function()
				sel.part = id
				Panels.Refresh()
			end, { TextSize = 12, Parent = partRow })
		end
	end

	section(left, "GESPEICHERTE BAUPLÄNE", nextOrder())
	if #s.blueprints == 0 then
		UI.Label("Noch keine. Speichere im Arsenal einen Bauplan deiner Lieblingswaffe.", 12, UI.C.Dim, UI.Font, { LayoutOrder = nextOrder(), Parent = left })
	end
	for i, bp in s.blueprints do
		local r = row(left, nextOrder(), 30)
		UI.Label(bp.name, 13, UI.C.Text, UI.FontBold, { Size = UDim2.new(0.6, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.None, Parent = r })
		UI.Button("Laden", UI.C.Card, function()
			if not s.unlocked[bp.form] then
				toast("Waffenform noch nicht erforscht.", "bad")
				return
			end
			sel.form, sel.e1, sel.e2, sel.blueprint = bp.form, bp.e1, bp.e2, i
			Panels.Refresh()
		end, { Size = UDim2.new(0.25, 0, 1, 0), TextSize = 12, Parent = r })
		UI.Button("✕", UI.C.Bg, function()
			send("DeleteBlueprint", i)
		end, { Size = UDim2.new(0.1, 0, 1, 0), TextSize = 12, Parent = r })
	end

	-- Vorschau
	UI.List(6).Parent = right
	local preview = { form = sel.form, e1 = sel.e1, e2 = sel.e2 }
	local nameText = UI.WeaponName(preview)
	if sel.e1 then
		nameText = UI.Colored(nameText, Config.Elements[sel.e1].color)
	end
	UI.Label(nameText, 20, UI.C.Text, UI.FontBlack, { LayoutOrder = 1, Parent = right })
	local form = Config.Forms[sel.form]
	UI.Label(form.desc, 12, UI.C.Dim, UI.Font, { LayoutOrder = 2, Parent = right })
	UI.Label(
		string.format("Schaden: leicht %d · schwer %d · Reichweite %d", form.light, form.heavy, form.range),
		12,
		UI.C.Dim,
		UI.Font,
		{ LayoutOrder = 3, Parent = right }
	)
	local lines = {}
	for _, el in { sel.e1, sel.e2 } do
		if el then
			local def = Config.Elements[el]
			table.insert(lines, UI.Colored("<b>" .. def.name .. ":</b> ", def.color) .. def.desc)
		end
	end
	if sel.e1 then
		table.insert(lines, UI.Colored("<b>Elementfähigkeit [F]:</b> ", Config.Elements[sel.e1].color) .. Config.Elements[sel.e1].ability)
	end
	local key = Config.ComboKey(sel.e1, sel.e2)
	if key then
		local c = Config.Combos[key]
		table.insert(lines, UI.Colored("<b>Kombination – " .. c.name .. ":</b> ", UI.C.Rift) .. c.desc)
	end
	if sel.part then
		table.insert(lines, UI.Colored("<b>" .. UI.ItemName(sel.part) .. ":</b> ", UI.C.Copper) .. Config.Items[sel.part].desc)
	end
	if #lines == 0 then
		table.insert(lines, "Ohne Element: solide Grundwaffe. Elementkerne findest du auf Expeditionen.")
	end
	UI.Label(table.concat(lines, "\n"), 13, UI.C.Text, UI.Font, { LayoutOrder = 4, Parent = right })
	local cost = recipeCost()
	UI.Label("<b>Kosten:</b>  " .. costText(cost), 12, UI.C.Text, UI.Font, { LayoutOrder = 5, Parent = right })
	UI.Label(
		"Danach folgt der Härtungsschritt: 3 Schläge im richtigen Moment verbessern die Qualität leicht. Misslingen kann nichts.",
		11,
		UI.C.Dim,
		UI.Font,
		{ LayoutOrder = 6, Parent = right }
	)
	local can = hasAll(cost)
	local b = UI.Button(if can then "SCHMIEDEN" else "Materialien fehlen", if can then UI.C.Copper else UI.C.Card, function()
		if can then
			task.spawn(startHardening)
		end
	end, { LayoutOrder = 7, Size = UDim2.new(1, 0, 0, 46), TextSize = 18, Parent = right })
	b.AutoButtonColor = can
end

--------------------------------------------------------------------------------
-- Schmelzofen, Forschung, Lagerkiste
--------------------------------------------------------------------------------
local function renderFurnace()
	local box = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = content }, { UI.List(10) })
	local ore, bars = Store.Count("CopperOre"), Store.Count("CopperBar")
	UI.Label("Der Schmelzofen verarbeitet Kupfererz zu Barren – dem Grundmetall jeder Waffe.", 14, UI.C.Dim, UI.Font, { Parent = box })
	UI.Label(string.format("<b>Kupfererz:</b> %d      <b>Kupferbarren:</b> %d", ore, bars), 18, UI.C.Text, UI.Font, { Parent = box })
	UI.Label(Config.Smelt.inputAmount .. " Kupfererz → 1 Kupferbarren", 14, UI.C.Copper, UI.FontBold, { Parent = box })
	local r = row(box, 10, 44)
	UI.Button("1 Barren schmelzen", UI.C.Copper, function()
		send("Smelt", 1)
	end, { Size = UDim2.new(0.5, -4, 1, 0), Parent = r })
	UI.Button("Alles schmelzen (" .. math.floor(ore / Config.Smelt.inputAmount) .. ")", UI.C.Card, function()
		send("Smelt", 999)
	end, { Size = UDim2.new(0.5, -4, 1, 0), Parent = r })
end

local function renderResearch()
	local box = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = content }, { UI.List(10) })
	UI.Label(
		"Hier schaltest du neue Waffenformen frei. Riftkristalle findest du in den Ruinen und auf dem riskanten Pfad.",
		14,
		UI.C.Dim,
		UI.Font,
		{ Parent = box }
	)
	for _, id in Config.FormOrder do
		local def = Config.Forms[id]
		local card = UI.Card({ Parent = box })
		UI.List(4).Parent = card
		UI.Label("<b>" .. def.name .. "</b>", 16, UI.C.Text, UI.Font, { Parent = card })
		UI.Label(def.desc, 12, UI.C.Dim, UI.Font, { Parent = card })
		if Store.state.unlocked[id] then
			UI.Label(UI.Colored("✔ Erforscht", UI.C.Good), 13, UI.C.Text, UI.FontBold, { Parent = card })
		elseif def.research then
			UI.Label("Forschung: " .. costText(def.research), 12, UI.C.Text, UI.Font, { Parent = card })
			UI.Button("Erforschen", if hasAll(def.research) then UI.C.Copper else UI.C.Bg, function()
				send("Research", id)
			end, { Size = UDim2.new(0, 160, 0, 32), Parent = card })
		end
	end
end

local chestTarget: number? = nil
local function renderChest()
	local left, right = twoColumns()
	UI.Label(
		"Teile Materialien mit deinem Team. Wähle rechts einen Mitspieler und gib Gegenstände einzeln ab.",
		13,
		UI.C.Dim,
		UI.Font,
		{ LayoutOrder = 0, Parent = left }
	)
	local any = false
	for i, id in Config.ItemOrder do
		local n = Store.Count(id)
		if n > 0 then
			any = true
			local r = row(left, i, 30)
			UI.Label(
				UI.Colored(UI.ItemName(id), Config.Items[id].color) .. "  ×" .. n,
				14,
				UI.C.Text,
				UI.FontBold,
				{ Size = UDim2.new(0.65, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.None, Parent = r }
			)
			UI.Button("Geben", if chestTarget then UI.C.Copper else UI.C.Bg, function()
				if chestTarget then
					send("GiveItem", chestTarget, id)
				else
					toast("Wähle zuerst rechts einen Mitspieler.", "bad")
				end
			end, { Size = UDim2.new(0.3, 0, 1, 0), TextSize = 12, Parent = r })
		end
	end
	if not any then
		UI.Label("Dein Lager ist leer.", 14, UI.C.Dim, UI.Font, { LayoutOrder = 1, Parent = left })
	end
	UI.List(6).Parent = right
	UI.Label("<b>Empfänger</b>", 14, UI.C.Text, UI.Font, { Parent = right })
	local others = 0
	for _, p in Players:GetPlayers() do
		if p ~= player then
			others += 1
			UI.Button(p.DisplayName, if chestTarget == p.UserId then UI.C.Rift else UI.C.Card, function()
				chestTarget = p.UserId
				Panels.Refresh()
			end, { Parent = right })
		end
	end
	if others == 0 then
		UI.Label("Keine Mitspieler auf dem Server.", 13, UI.C.Dim, UI.Font, { Parent = right })
	end
end

--------------------------------------------------------------------------------
-- Expeditionstafel
--------------------------------------------------------------------------------
local chosenDifficulty = "Normal"
local function renderBoard()
	local exp = Store.state.expedition or {}
	local left, right = twoColumns()
	UI.Label("<b>Verdant Scar</b>", 20, UI.C.Rift, UI.FontBlack, { LayoutOrder = 1, Parent = left })
	UI.Label(
		"Außenposten → Überwucherte Ruinen → Kupfermine (sicherer oder riskanter Pfad) → Rift-Kammer mit dem <b>Hollow Warden</b>.",
		13,
		UI.C.Text,
		UI.Font,
		{ LayoutOrder = 2, Parent = left }
	)
	UI.Label(
		"• Beute landet im Rucksack und ist erst am <b>Rückkehrportal</b> sicher.\n• Niedergeschlagen? Teammitglieder beleben dich wieder.\n• Teamwipe: die Hälfte der ungesicherten Grundmaterialien geht verloren. Kerne, Monsterteile und Bossbeute bleiben.\n• Ein <b>Frostsiegel</b> in der Mine öffnet sich nur mit Glut oder Frost.",
		12,
		UI.C.Dim,
		UI.Font,
		{ LayoutOrder = 3, Parent = left }
	)
	section(left, "SCHWIERIGKEIT", 4)
	local r = row(left, 5, 40)
	for _, id in { "Normal", "Hard" } do
		local d = Config.Difficulties[id]
		local isLeader = exp.leaderId == player.UserId
		local active = if exp.phase == "Lobby" then exp.difficulty == id else chosenDifficulty == id
		UI.Button(d.name .. (if id == "Hard" then "  (mehr Beute)" else ""), if active then UI.C.Copper else UI.C.Card, function()
			chosenDifficulty = id
			if exp.phase == "Lobby" and isLeader then
				send("ExpDifficulty", id)
			end
			Panels.Refresh()
		end, { Size = UDim2.new(0.5, -4, 1, 0), Parent = r })
	end

	UI.List(8).Parent = right
	local hasWeapon = Store.Equipped() ~= nil
	if exp.phase == "Idle" or exp.phase == nil then
		UI.Label("Keine Expedition geplant.", 15, UI.C.Text, UI.FontBold, { Parent = right })
		UI.Label("Plane eine Expedition. Mitspieler haben 20 Sekunden, um beizutreten (max. 4).", 12, UI.C.Dim, UI.Font, { Parent = right })
		UI.Button(if hasWeapon then "Expedition planen" else "Erst eine Waffe schmieden", if hasWeapon then UI.C.Copper else UI.C.Bg, function()
			send("ExpCreate", chosenDifficulty)
		end, { Size = UDim2.new(1, 0, 0, 44), Parent = right })
	elseif exp.phase == "Lobby" then
		local left_ = math.max(0, math.ceil((exp.lobbyEnds or 0) - workspace:GetServerTimeNow()))
		UI.Label("Start in <b>" .. left_ .. " s</b>  ·  " .. Config.Difficulties[exp.difficulty].name, 15, UI.C.Text, UI.Font, { Parent = right })
		UI.Label("Gruppe: " .. table.concat(exp.members, ", "), 13, UI.C.Dim, UI.Font, { Parent = right })
		local inLobby = table.find(exp.members, player.DisplayName) ~= nil
		if not inLobby then
			UI.Button("Beitreten", UI.C.Copper, function()
				send("ExpJoin")
			end, { Parent = right })
		else
			if exp.leaderId == player.UserId then
				UI.Button("Jetzt starten", UI.C.Copper, function()
					send("ExpLaunch")
				end, { Size = UDim2.new(1, 0, 0, 44), Parent = right })
			end
			UI.Button("Gruppe verlassen", UI.C.Card, function()
				send("ExpLeave")
			end, { Parent = right })
		end
	elseif exp.phase == "Running" then
		UI.Label("Expedition läuft", 15, UI.C.Text, UI.FontBold, { Parent = right })
		UI.Label("Team: " .. table.concat(exp.participants, ", "), 13, UI.C.Dim, UI.Font, { Parent = right })
		if exp.bossDead then
			UI.Label(UI.Colored("Der Warden wurde besiegt.", UI.C.Good), 13, UI.C.Text, UI.Font, { Parent = right })
		end
		if not Store.state.inRun and #exp.participants < 4 then
			UI.Button("Team beitreten", UI.C.Copper, function()
				send("ExpJoin")
			end, { Parent = right })
		end
	end
end

--------------------------------------------------------------------------------
-- Arsenal & Inventar
--------------------------------------------------------------------------------
local confirmScrap: string? = nil
local confirmAbandon = false
local partPicker: string? = nil

local function itemList(parent: Instance, items: { [string]: number }, order: number, empty: string)
	local any = false
	for i, id in Config.ItemOrder do
		local n = items[id]
		if n and n > 0 then
			any = true
			UI.Label(
				UI.Colored(UI.ItemName(id), Config.Items[id].color) .. "  ×" .. n,
				13,
				UI.C.Text,
				UI.FontBold,
				{ LayoutOrder = order + i, Parent = parent }
			)
		end
	end
	if not any then
		UI.Label(empty, 12, UI.C.Dim, UI.Font, { LayoutOrder = order, Parent = parent })
	end
end

local function renderInventory()
	local s = Store.state
	local left, right = twoColumns()
	right:Destroy()
	local weapons = UI.Scroll({ Position = UDim2.new(0.56, 6, 0, 0), Size = UDim2.new(0.44, -6, 1, 0), Parent = content })
	UI.List(8).Parent = weapons

	if s.inRun then
		section(left, "RUCKSACK (ungesichert)", 1)
		itemList(left, s.backpack, 2, "Leer.")
		section(left, "BOSSBEUTE (geschützt)", 100)
		itemList(left, s.protectedLoot, 101, "–")
		local b = UI.Button(if confirmAbandon then "Wirklich aufgeben? (Teilverlust)" else "Expedition aufgeben", UI.C.Danger, function()
			if confirmAbandon then
				confirmAbandon = false
				send("ExpAbandon")
			else
				confirmAbandon = true
				Panels.Refresh()
			end
		end, { LayoutOrder = 150, Parent = left })
		b.BackgroundTransparency = 0.3
	end
	section(left, "LAGER (gesichert)", 200)
	itemList(left, s.stash, 201, "Leer.")

	section(weapons, "WAFFEN (" .. #s.weapons .. "/" .. Config.MaxWeapons .. ")", 0)
	if #s.weapons == 0 then
		UI.Label("Noch keine Waffe. Geh zur Schmiede im Camp.", 13, UI.C.Dim, UI.Font, { LayoutOrder = 1, Parent = weapons })
	end
	for i, w in s.weapons do
		local card = UI.Card({ LayoutOrder = i, Parent = weapons })
		UI.List(5).Parent = card
		local equipped = s.equipped == w.id
		if equipped then
			UI.Stroke(UI.C.Rift, 2).Parent = card
		end
		local name = UI.WeaponName(w)
		if w.e1 then
			name = UI.Colored(name, Config.Elements[w.e1].color)
		end
		local q = Config.Quality[w.quality or 1]
		UI.Label(
			"<b>" .. name .. "</b>  " .. UI.Colored(q.name, UI.C.Dim) .. (if equipped then UI.Colored("  · ausgerüstet", UI.C.Rift) else ""),
			14,
			UI.C.Text,
			UI.Font,
			{ Parent = card }
		)
		UI.Label("Monsterteil: " .. (if w.part then UI.Colored(UI.ItemName(w.part), UI.C.Copper) else "–"), 12, UI.C.Dim, UI.Font, { Parent = card })
		if not s.inRun then
			local r = row(card, 10, 28)
			if not equipped then
				UI.Button("Ausrüsten", UI.C.Copper, function()
					send("Equip", w.id)
				end, { Size = UDim2.new(0.25, -4, 1, 0), TextSize = 11, Parent = r })
			end
			UI.Button("Monsterteil", UI.C.Card, function()
				partPicker = if partPicker == w.id then nil else w.id
				Panels.Refresh()
			end, { Size = UDim2.new(0.25, -4, 1, 0), TextSize = 11, Parent = r })
			UI.Button("Bauplan", UI.C.Card, function()
				send("SaveBlueprint", w.id)
			end, { Size = UDim2.new(0.22, -4, 1, 0), TextSize = 11, Parent = r })
			UI.Button(if confirmScrap == w.id then "Sicher?" else "Einschmelzen", UI.C.Bg, function()
				if confirmScrap == w.id then
					confirmScrap = nil
					send("Scrap", w.id)
				else
					confirmScrap = w.id
					Panels.Refresh()
				end
			end, { Size = UDim2.new(0.28, -4, 1, 0), TextSize = 11, Parent = r })
			if partPicker == w.id then
				local pr = UI.new(
					"Frame",
					{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 11, Parent = card },
					{
						UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 28), CellPadding = UDim2.fromOffset(4, 4) }),
					}
				)
				if w.part then
					UI.Button("Entfernen", UI.C.Bg, function()
						partPicker = nil
						send("SetPart", w.id, nil)
					end, { TextSize = 11, Parent = pr })
				end
				local anyPart = false
				for _, id in Config.ItemOrder do
					if Config.Items[id].kind == "Part" and Store.Count(id) > 0 then
						anyPart = true
						UI.Button(UI.ItemName(id), UI.C.Card, function()
							partPicker = nil
							send("SetPart", w.id, id)
						end, { TextSize = 11, Parent = pr })
					end
				end
				if not anyPart and not w.part then
					UI.Label("Keine Monsterteile im Lager.", 11, UI.C.Dim, UI.Font, { Parent = pr })
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Aufgaben & Hilfe
--------------------------------------------------------------------------------
local function renderQuests()
	local s = Store.state
	local left, right = twoColumns()
	section(left, "AUFGABEN", 0)
	for i, q in Config.Quests do
		local status = s.quests[q.id] or "open"
		local card = UI.Card({ LayoutOrder = i, Parent = left })
		UI.List(4).Parent = card
		UI.Label("<b>" .. q.title .. "</b>", 15, UI.C.Text, UI.Font, { Parent = card })
		UI.Label(q.desc, 12, UI.C.Dim, UI.Font, { Parent = card })
		local rewards = {}
		for id, n in q.reward do
			table.insert(rewards, n .. "× " .. UI.ItemName(id))
		end
		UI.Label("Belohnung: " .. table.concat(rewards, ", "), 12, UI.C.Copper, UI.Font, { Parent = card })
		if status == "done" then
			UI.Button("Belohnung abholen", UI.C.Copper, function()
				send("ClaimQuest", q.id)
			end, { Size = UDim2.new(0, 170, 0, 30), Parent = card })
		elseif status == "claimed" then
			UI.Label(UI.Colored("✔ Abgeschlossen", UI.C.Good), 12, UI.C.Text, UI.FontBold, { Parent = card })
		end
	end
	UI.List(6).Parent = right
	UI.Label("<b>MEILENSTEINE</b>", 13, UI.C.Rift, UI.FontBlack, { Parent = right })
	for _, m in Config.Milestones do
		local done = s.milestones[m.id]
		UI.Label(
			(if done then UI.Colored("✔ ", UI.C.Good) else UI.Colored("○ ", UI.C.Dim)) .. m.text,
			13,
			if done then UI.C.Text else UI.C.Dim,
			UI.Font,
			{ Parent = right }
		)
	end
end

local function renderHelp()
	local scroll = UI.Scroll({ Parent = content })
	UI.List(8).Parent = scroll
	local text = {
		"<b>Der Kreislauf:</b> Waffe schmieden → Expedition starten → Beute und Elementkerne sammeln → rechtzeitig am Rückkehrportal sichern → neue Waffe schmieden → tiefer ins Rift.",
		"<b>Steuerung (PC):</b> Linksklick leichter Angriff · R oder Rechtsklick schwerer Angriff · Q Ausweichen (kurz unverwundbar) · F Elementfähigkeit · E interagieren · I Arsenal · J Aufgaben.",
		"<b>Controller:</b> R2 leicht · R1 schwer · B ausweichen · Y Element · X interagieren.   <b>Handy:</b> Knöpfe rechts unten.",
		"<b>Ausdauer</b> (gelb) sinkt bei Angriffen und beim Ausweichen. <b>Elementladung</b> füllt sich durch Treffer und Ausweichen – ist sie voll, drücke F.",
		"<b>Perfektes Ausweichen:</b> Weiche genau dann aus, wenn ein angekündigter Angriff (rote Fläche) trifft.",
	}
	for i, t in text do
		UI.Label(t, 13, UI.C.Text, UI.Font, { LayoutOrder = i, Parent = scroll })
	end
	UI.Label("<b>ELEMENTE</b>", 13, UI.C.Rift, UI.FontBlack, { LayoutOrder = 10, Parent = scroll })
	for i, el in Config.ElementOrder do
		local d = Config.Elements[el]
		UI.Label(UI.Colored("<b>" .. d.name .. "</b>", d.color) .. " – " .. d.desc, 12, UI.C.Text, UI.Font, { LayoutOrder = 10 + i, Parent = scroll })
	end
	UI.Label("<b>KOMBINATIONEN</b>", 13, UI.C.Rift, UI.FontBlack, { LayoutOrder = 20, Parent = scroll })
	local i = 0
	for key, c in Config.Combos do
		i += 1
		local a, b = string.match(key, "(%a+)%+(%a+)")
		local names = Config.Elements[a :: string].name .. " + " .. Config.Elements[b :: string].name
		UI.Label("<b>" .. names .. " – " .. c.name .. ":</b> " .. c.desc, 12, UI.C.Text, UI.Font, { LayoutOrder = 20 + i, Parent = scroll })
	end
end

local RENDER: { [string]: () -> () } = {
	Forge = renderForge,
	Furnace = renderFurnace,
	Research = renderResearch,
	Chest = renderChest,
	Board = renderBoard,
	Inventory = renderInventory,
	Quests = renderQuests,
	Help = renderHelp,
}

--------------------------------------------------------------------------------
-- Öffentliche API
--------------------------------------------------------------------------------
function Panels.Refresh()
	if not current or hardeningActive then
		return
	end
	UI.Clear(content)
	titleLabel.Text = TITLES[current] or current
	RENDER[current]()
end

function Panels.Open(name: string)
	if not RENDER[name] then
		return
	end
	if hardeningActive then
		return
	end
	current = name
	window.Visible = true
	Panels.Refresh()
end

function Panels.Close()
	if hardeningActive then
		return
	end
	current = nil
	window.Visible = false
	confirmScrap = nil
	confirmAbandon = false
	partPicker = nil
end

function Panels.Toggle(name: string)
	if current == name then
		Panels.Close()
	else
		Panels.Open(name)
	end
end

function Panels.IsOpen(): boolean
	return current ~= nil or hardeningActive
end

function Panels.Init(toastFn: (string, string?) -> ())
	toast = toastFn
	gui = UI.new("ScreenGui", {
		Name = "RiftboundMenus",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	window = UI.new("Frame", {
		BackgroundColor3 = UI.C.Panel,
		BackgroundTransparency = 0.03,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.84),
		Visible = false,
		Active = true,
		Parent = gui,
	}, {
		UI.Corner(12),
		UI.Stroke(UI.C.Stroke, 1.5),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(860, 560) }),
	})
	titleLabel = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -80, 0, 30),
		Font = UI.FontBlack,
		TextSize = 22,
		TextColor3 = UI.C.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = window,
	})
	UI.Button("✕", UI.C.Card, Panels.Close, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(36, 32),
		Parent = window,
	})
	content = UI.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 52),
		Size = UDim2.new(1, -32, 1, -68),
		Parent = window,
	})

	Net.Event("OpenUI").OnClientEvent:Connect(Panels.Open)
	Store.Changed:Connect(Panels.Refresh)

	-- Lobby-Countdown aktuell halten
	task.spawn(function()
		while true do
			task.wait(1)
			if current == "Board" and (Store.state.expedition or {}).phase == "Lobby" then
				Panels.Refresh()
			end
		end
	end)

	-- Menü schließen, wenn man sich von der Station entfernt
	RunService.Heartbeat:Connect(function()
		if current and current ~= "Inventory" and current ~= "Quests" and current ~= "Help" and not hardeningActive then
			if Store.state.inRun then
				Panels.Close()
			end
		end
	end)
end

return Panels
