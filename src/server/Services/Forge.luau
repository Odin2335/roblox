--!nonstrict
-- Schmiede, Schmelzofen, Forschungstisch, Arsenal und Lagerkiste.
-- Alle Aktionen sind nur im Camp möglich und werden serverseitig geprüft.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Forge = {}
local ctx: any

type Recipe = { form: string, e1: string?, e2: string?, part: string?, blueprint: number? }
type Session = { recipe: Recipe, start: number, created: number }

local sessions: { [Player]: Session } = {}

local function inCamp(player: Player): boolean
	local s = ctx.PlayerState.Get(player)
	return s ~= nil and not s.inRun
end

-- Prüft ein Rezept und liefert die Gesamtkosten (oder nil + Grund).
local function validate(player: Player, raw: any): (Recipe?, { [string]: number }?, string?)
	if type(raw) ~= "table" then
		return nil, nil, "Ungültiges Rezept"
	end
	local profile = ctx.DataService.Get(player)
	if not profile then
		return nil, nil, "Profil lädt noch"
	end
	local form = raw.form
	if type(form) ~= "string" or not Config.Forms[form] then
		return nil, nil, "Unbekannte Waffenform"
	end
	if not profile.unlocked[form] then
		return nil, nil, Config.Forms[form].name .. " ist noch nicht erforscht"
	end
	local e1 = if type(raw.e1) == "string" and Config.Elements[raw.e1] then raw.e1 else nil
	local e2 = if type(raw.e2) == "string" and Config.Elements[raw.e2] then raw.e2 else nil
	if not e1 and e2 then
		e1, e2 = e2, nil
	end
	if e1 and e1 == e2 then
		return nil, nil, "Zwei verschiedene Elemente wählen"
	end
	local part = if type(raw.part) == "string" and Config.Items[raw.part] and Config.Items[raw.part].kind == "Part" then raw.part else nil
	if #profile.weapons >= Config.MaxWeapons then
		return nil, nil, "Arsenal voll (max. " .. Config.MaxWeapons .. "). Schmelze eine Waffe ein."
	end
	local cost: { [string]: number } = {}
	for k, v in Config.Forms[form].cost do
		cost[k] = (cost[k] or 0) + v
	end
	for _, el in { e1, e2 } do
		if el then
			local core = Config.Elements[el].core
			cost[core] = (cost[core] or 0) + 1
			for k, v in Config.ElementCost do
				cost[k] = (cost[k] or 0) + v
			end
		end
	end
	if part then
		cost[part] = (cost[part] or 0) + 1
	end
	if not ctx.DataService.Has(player, cost) then
		return nil, nil, "Nicht genug Materialien"
	end
	local bp = if type(raw.blueprint) == "number" then raw.blueprint else nil
	return { form = form, e1 = e1, e2 = e2, part = part, blueprint = bp }, cost, nil
end

local function finish(player: Player, session: Session, times: { number }): (boolean, string, number?)
	local recipe, cost, err = validate(player, session.recipe)
	if not recipe or not cost then
		return false, err or "Fehler"
	end
	-- Timing auswerten (Serverzeit-Stempel; Werte außerhalb des Fensters zählen nicht)
	local now = workspace:GetServerTimeNow()
	local score = 0
	local last = session.start
	for i = 1, math.min(#times, Config.Hardening.Strikes) do
		local t = times[i]
		if type(t) == "number" and t >= last and t <= now + 0.1 then
			last = t
			local pos = Config.HardeningPos(t - session.start)
			local off = math.abs(pos - 0.5)
			if off <= Config.Hardening.Perfect then
				score += 2
			elseif off <= Config.Hardening.Good then
				score += 1
			end
		end
	end
	local quality = Config.QualityFromScore(score)
	if not ctx.DataService.Take(player, cost) then
		return false, "Nicht genug Materialien"
	end
	local profile = ctx.DataService.Get(player)
	local id = "w" .. profile.nextWeaponId
	profile.nextWeaponId += 1
	local weapon = {
		id = id,
		form = recipe.form,
		e1 = recipe.e1,
		e2 = recipe.e2,
		part = recipe.part,
		quality = quality,
		forged = true,
	}
	table.insert(profile.weapons, weapon)
	profile.equipped = id
	ctx.DataService.MarkDirty(player)

	ctx.Progress.Milestone(player, "FirstWeapon")
	if recipe.e1 then
		ctx.Progress.Milestone(player, "ElementWeapon")
	end
	if recipe.e1 and recipe.e2 then
		ctx.Progress.CompleteQuest(player, "Smith")
	end
	if recipe.part then
		ctx.Progress.Milestone(player, "MonsterPart")
	end
	if recipe.blueprint then
		local bp = profile.blueprints[recipe.blueprint]
		if bp and bp.form == recipe.form and (bp.e1 ~= recipe.e1 or bp.e2 ~= recipe.e2) and recipe.e1 then
			ctx.Progress.Milestone(player, "Rebuild")
		end
	end
	ctx.PlayerState.AttachWeapon(player)
	ctx.PlayerState.Sync(player)
	return true, "Geschmiedet: " .. Forge.WeaponName(weapon) .. " (" .. Config.Quality[quality].name .. ")", quality
end

function Forge.WeaponName(w: any): string
	local name = Config.Forms[w.form].name
	local key = Config.ComboKey(w.e1, w.e2)
	if key then
		return Config.Combos[key].name .. "-" .. name
	elseif w.e1 then
		return Config.Elements[w.e1].name .. "-" .. name
	end
	return name
end

--------------------------------------------------------------------------------
-- Weitere Stationen (über das "Request"-Remote)
--------------------------------------------------------------------------------
local handlers: { [string]: (Player, any, any) -> () } = {}

handlers.Smelt = function(player, amount)
	local n = if type(amount) == "number" then math.clamp(math.floor(amount), 1, 999) else 1
	local profile = ctx.DataService.Get(player)
	local big = profile.upgrades.BigFurnace == true
	local input = if big then Config.Smelt.bigInput else Config.Smelt.inputAmount
	local output = if big then Config.Smelt.bigOutput else 1
	local have = profile.stash[Config.Smelt.input] or 0
	n = math.min(n, math.floor(have / input))
	if n <= 0 then
		ctx.PlayerState.Notify(player, "Du brauchst " .. input .. " Kupfererz pro Schmelzvorgang.", "bad")
		return
	end
	ctx.DataService.Take(player, { [Config.Smelt.input] = n * input })
	ctx.DataService.Give(player, { [Config.Smelt.output] = n * output })
	ctx.PlayerState.Notify(player, (n * output) .. " Kupferbarren geschmolzen.", "good")
	ctx.Progress.Milestone(player, "SmeltCopper")
	Net.Event("Fx"):FireAllClients("Smelt", player)
end

handlers.Research = function(player, id)
	local profile = ctx.DataService.Get(player)
	if type(id) ~= "string" or profile.unlocked[id] then
		return
	end
	local form = Config.Forms[id]
	local extra = Config.Research[id]
	local cost = if form then form.research elseif extra then extra.cost else nil
	if not cost then
		return
	end
	if not ctx.DataService.Take(player, cost) then
		ctx.PlayerState.Notify(player, "Dir fehlen Bauplan oder Materialien.", "bad")
		return
	end
	profile.unlocked[id] = true
	ctx.PlayerState.Notify(
		player,
		"Erforscht: " .. (if form then form.name else extra.name) .. (if extra then " – jetzt an der Werkbank herstellbar." else ""),
		"milestone"
	)
end

handlers.CraftGear = function(player, id)
	local def = type(id) == "string" and Config.Gear[id]
	local profile = ctx.DataService.Get(player)
	if not def then
		return
	end
	if not def.item and profile.tools[id] then
		ctx.PlayerState.Notify(player, "Du besitzt " .. def.name .. " bereits.", "info")
		return
	end
	if def.requires and not profile.tools[def.requires] then
		ctx.PlayerState.Notify(player, "Benötigt zuerst: " .. Config.Gear[def.requires].name, "bad")
		return
	end
	if def.research and not profile.unlocked[def.research] then
		ctx.PlayerState.Notify(player, "Erst den Bauplan am Forschungstisch entschlüsseln.", "bad")
		return
	end
	if not ctx.DataService.Take(player, def.cost) then
		ctx.PlayerState.Notify(player, "Nicht genug Materialien.", "bad")
		return
	end
	if def.item then
		local n = def.amount or 1
		if def.item == "Potion" and profile.upgrades.HerbGarden then
			n *= 2
		end
		ctx.DataService.Give(player, { [def.item] = n })
		ctx.PlayerState.Notify(player, "Hergestellt: " .. n .. "× " .. Config.Items[def.item].name, "good")
		return
	end
	profile.tools[id] = true
	ctx.PlayerState.Notify(player, "Hergestellt: " .. def.name, "milestone")
	if id == "StonePickaxe" or id == "CopperPickaxe" or id == "Locator" then
		ctx.Progress.Milestone(player, id)
	end
	if id == "Locator" then
		ctx.PlayerState.Notify(player, "Das Ortungsgerät pulsiert: Jenseits von Verdant Scar liegen die Glutadern ... (nächstes Gebiet)", "boss")
	end
end

handlers.BuildUpgrade = function(player, id)
	local def = type(id) == "string" and Config.Upgrades[id]
	local profile = ctx.DataService.Get(player)
	if not def or profile.upgrades[id] then
		return
	end
	if def.requires and not profile.milestones[def.requires] then
		ctx.PlayerState.Notify(player, "Überlebe zuerst eine Expedition.", "bad")
		return
	end
	if not ctx.DataService.Take(player, def.cost) then
		ctx.PlayerState.Notify(player, "Nicht genug Materialien.", "bad")
		return
	end
	profile.upgrades[id] = true
	ctx.PlayerState.Notify(player, "Camp-Ausbau fertig: " .. def.name, "milestone")
	ctx.Progress.Milestone(player, "BaseUpgrade")
	ctx.Gear.RefreshCamp()
end

handlers.Equip = function(player, id)
	local profile = ctx.DataService.Get(player)
	for _, w in profile.weapons do
		if w.id == id then
			profile.equipped = id
			ctx.PlayerState.AttachWeapon(player)
			ctx.PlayerState.Notify(player, "Ausgerüstet: " .. Forge.WeaponName(w), "info")
		end
	end
end

handlers.Scrap = function(player, id)
	local profile = ctx.DataService.Get(player)
	for i, w in profile.weapons do
		if w.id == id then
			if w.part then
				ctx.DataService.Give(player, { [w.part] = 1 })
			end
			ctx.DataService.Give(player, { CopperBar = 1 })
			table.remove(profile.weapons, i)
			if profile.equipped == id then
				profile.equipped = nil
				ctx.PlayerState.AttachWeapon(player)
			end
			ctx.PlayerState.Notify(player, "Eingeschmolzen (+1 Kupferbarren" .. (if w.part then ", Monsterteil zurück" else "") .. ").", "info")
			return
		end
	end
end

handlers.SetPart = function(player, id, part)
	local profile = ctx.DataService.Get(player)
	if part ~= nil and not (type(part) == "string" and Config.Items[part] and Config.Items[part].kind == "Part") then
		return
	end
	for _, w in profile.weapons do
		if w.id == id then
			if part and (profile.stash[part] or 0) < 1 then
				ctx.PlayerState.Notify(player, "Dieses Monsterteil hast du nicht im Lager.", "bad")
				return
			end
			if w.part then
				ctx.DataService.Give(player, { [w.part] = 1 })
			end
			w.part = nil
			if part then
				ctx.DataService.Take(player, { [part] = 1 })
				w.part = part
				ctx.Progress.Milestone(player, "MonsterPart")
			end
			ctx.PlayerState.Notify(player, if part then Config.Items[part].name .. " eingesetzt." else "Monsterteil entfernt.", "info")
			return
		end
	end
end

handlers.SaveBlueprint = function(player, id)
	local profile = ctx.DataService.Get(player)
	if #profile.blueprints >= 12 then
		ctx.PlayerState.Notify(player, "Maximal 12 Baupläne.", "bad")
		return
	end
	for _, w in profile.weapons do
		if w.id == id then
			for _, bp in profile.blueprints do
				if bp.form == w.form and bp.e1 == w.e1 and bp.e2 == w.e2 then
					ctx.PlayerState.Notify(player, "Diesen Bauplan hast du schon.", "info")
					return
				end
			end
			table.insert(profile.blueprints, { name = Forge.WeaponName(w), form = w.form, e1 = w.e1, e2 = w.e2 })
			ctx.PlayerState.Notify(player, "Bauplan gespeichert: " .. Forge.WeaponName(w), "good")
		end
	end
end

handlers.DeleteBlueprint = function(player, index)
	local profile = ctx.DataService.Get(player)
	if type(index) == "number" and profile.blueprints[index] then
		table.remove(profile.blueprints, index)
	end
end

handlers.GiveItem = function(player, targetUserId, item)
	local target = type(targetUserId) == "number" and Players:GetPlayerByUserId(targetUserId)
	if not target or target == player or type(item) ~= "string" or not Config.Items[item] then
		return
	end
	if not inCamp(target) then
		ctx.PlayerState.Notify(player, target.DisplayName .. " ist gerade auf Expedition.", "bad")
		return
	end
	if not ctx.DataService.Take(player, { [item] = 1 }) then
		return
	end
	ctx.DataService.Give(target, { [item] = 1 })
	ctx.PlayerState.Notify(player, "1 " .. Config.Items[item].name .. " an " .. target.DisplayName .. " gegeben.", "info")
	ctx.PlayerState.Notify(target, player.DisplayName .. " hat dir 1 " .. Config.Items[item].name .. " gegeben.", "good")
	ctx.PlayerState.Sync(target)
end

handlers.ClaimQuest = function(player, id)
	if type(id) == "string" then
		ctx.Progress.Claim(player, id)
	end
end

-- Aktionen, die auch während einer Expedition erlaubt sind
local ANYWHERE = { ClaimQuest = true }

function Forge.Handle(player: Player, action: string, a: any, b: any)
	local handler = handlers[action]
	if not handler or not ctx.DataService.Get(player) then
		return false
	end
	if not ANYWHERE[action] and not inCamp(player) then
		ctx.PlayerState.Notify(player, "Das geht nur im Camp.", "bad")
		return true
	end
	handler(player, a, b)
	ctx.DataService.MarkDirty(player)
	ctx.PlayerState.Sync(player)
	return true
end

function Forge.Init(context)
	ctx = context
end

function Forge.Start()
	Net.Function("ForgeBegin").OnServerInvoke = function(player, raw)
		if not inCamp(player) then
			return { ok = false, msg = "Schmieden geht nur im Camp." }
		end
		local recipe, _, err = validate(player, raw)
		if not recipe then
			return { ok = false, msg = err }
		end
		local start = workspace:GetServerTimeNow() + 0.6
		sessions[player] = { recipe = recipe, start = start, created = os.clock() }
		return { ok = true, start = start, period = Config.Hardening.Period }
	end
	Net.Function("ForgeFinish").OnServerInvoke = function(player, times)
		local session = sessions[player]
		sessions[player] = nil
		if not session then
			return { ok = false, msg = "Kein Schmiedevorgang aktiv." }
		end
		if os.clock() - session.created > Config.Hardening.Timeout + 5 then
			times = {}
		end
		local list = {}
		if type(times) == "table" then
			for i = 1, Config.Hardening.Strikes do
				if type(times[i]) == "number" then
					table.insert(list, times[i])
				end
			end
		end
		local ok, msg, quality = finish(player, session, list)
		return { ok = ok, msg = msg, quality = quality }
	end
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

return Forge
