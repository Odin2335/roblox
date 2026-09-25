--!nonstrict
-- Kampf: Der Client sendet nur Absichten, der Server prüft Abklingzeiten und
-- Ausdauer, bestimmt Treffer, Schaden und alle Element-/Kombinationseffekte.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Combat = {}
local ctx: any

local FxEvent = Net.Event("Fx")

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function has(w: any, el: string): boolean
	return w.e1 == el or w.e2 == el
end

local function elementsOf(w: any): { string }
	local list = {}
	if w.e1 then
		table.insert(list, w.e1)
	end
	if w.e2 then
		table.insert(list, w.e2)
	end
	return list
end

local function combo(w: any): string?
	return Config.ComboKey(w.e1, w.e2)
end

local function colorOf(w: any): Color3?
	return if w.e1 then Config.Elements[w.e1].color else nil
end

local function qualityMult(w: any): number
	local q = Config.Quality[w.quality or 1]
	return if q then q.mult else 1
end

--------------------------------------------------------------------------------
-- Kombinations-Bausteine
--------------------------------------------------------------------------------
local function areaDamage(player: Player, w: any, center: Vector3, radius: number, amount: number, color: Color3, exclude: any?, extra: ((any) -> ())?)
	local els = elementsOf(w)
	for _, e in ctx.Entities.InRadius(center, radius, exclude) do
		local dealt = ctx.Entities.Damage(e, amount, { player = player, elements = els, color = color })
		if dealt > 0 and extra then
			extra(e)
		end
	end
end

local function thermoBreak(player: Player, w: any, e: any)
	local s = e.status
	s.thermoCount += 1
	if s.thermoCount < 3 then
		return
	end
	s.thermoCount = 0
	s.thermoHot = not s.thermoHot
	local form = Config.Forms[w.form]
	local dmg = form.heavy * 0.3 * qualityMult(w)
	local pos = e.root.Position
	FxEvent:FireAllClients("Shards", pos, 8 * form.radiusMult)
	ctx.Entities.Damage(e, dmg, { player = player, elements = elementsOf(w), color = Color3.fromRGB(255, 200, 220) })
	areaDamage(player, w, pos, 8 * form.radiusMult, dmg * 0.6, Color3.fromRGB(255, 200, 220), e)
end

local function coldShock(player: Player, w: any, e: any)
	local form = Config.Forms[w.form]
	local r = 10 * form.radiusMult * form.reachMult
	FxEvent:FireAllClients("Nova", e.root.Position, r, Config.Elements.Frost.color)
	areaDamage(player, w, e.root.Position, r, 10 * qualityMult(w), Config.Elements.Frost.color, e, function(other)
		ctx.Entities.AddFrost(other, 2)
	end)
end

local function shadowEcho(player: Player, w: any, e: any)
	local form = Config.Forms[w.form]
	local dmg = form.heavy * 0.5 * qualityMult(w)
	task.delay(0.6, function()
		if e.dead then
			return
		end
		FxEvent:FireAllClients("Echo", e.root.Position, Config.Elements.Shadow.color)
		ctx.Entities.Damage(e, dmg, { player = player, elements = elementsOf(w), color = Config.Elements.Shadow.color })
	end)
end

local function fireTrail(player: Player, w: any, from: Vector3, to: Vector3)
	local form = Config.Forms[w.form]
	local points = {}
	local dir = flat(to - from)
	local len = math.max(dir.Magnitude, 6) * form.reachMult
	local unit = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(0, 0, -1)
	for i = 1, 4 do
		table.insert(points, from + unit * (len * i / 4))
	end
	FxEvent:FireAllClients("Trail", points, 3.5, 3)
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < 3 do
			for _, p in points do
				for _, e in ctx.Entities.InRadius(p, 3.5) do
					ctx.Entities.AddBurn(e, 1, player)
					ctx.Entities.Damage(e, 3, { player = player, elements = { "Ember" }, color = Config.Elements.Ember.color, silent = true })
				end
			end
			task.wait(0.5)
		end
	end)
end

local function stormDischarge(player: Player, w: any, primary: any)
	local form = Config.Forms[w.form]
	local q = qualityMult(w)
	local reach = 12 * form.reachMult
	local color = Config.Elements.Storm.color
	-- Sprung auf bis zu zwei nahe Gegner
	local others = ctx.Entities.InRadius(primary.root.Position, reach, primary)
	table.sort(others, function(a, b)
		return (a.root.Position - primary.root.Position).Magnitude < (b.root.Position - primary.root.Position).Magnitude
	end)
	for i = 1, math.min(2, #others) do
		local o = others[i]
		FxEvent:FireAllClients("Chain", primary.root.Position, o.root.Position, color)
		ctx.Entities.Damage(o, form.heavy * 0.4 * q, { player = player, elements = elementsOf(w), color = color })
	end
	if #others == 0 then
		FxEvent:FireAllClients("Chain", primary.root.Position + Vector3.new(0, 6, 0), primary.root.Position, color)
	end
	local key = combo(w)
	if key == "Ember+Storm" then
		local r = 8 * form.radiusMult
		FxEvent:FireAllClients("Explosion", primary.root.Position, r, Config.Elements.Ember.color)
		areaDamage(player, w, primary.root.Position, r, form.heavy * 0.35 * q, Config.Elements.Ember.color, nil, function(e)
			ctx.Entities.AddBurn(e, 2, player)
		end)
	elseif key == "Storm+Shadow" then
		local target = ctx.Entities.Nearest(primary.root.Position, 20 * form.reachMult, function(e)
			return ctx.Entities.IsMarked(e) and e ~= primary
		end) or primary
		local root = ctx.PlayerState.GetRoot(player)
		if root and not target.dead then
			local tPos = target.root.Position
			local dir = flat(tPos - root.Position)
			local unit = if dir.Magnitude > 0.1 then dir.Unit else root.CFrame.LookVector
			local dest = tPos - unit * (target.radius + 3)
			local ground = ctx.Entities.GroundAt(dest)
			local from = root.Position
			root.CFrame = CFrame.lookAt(ground + Vector3.new(0, 3, 0), Vector3.new(tPos.X, ground.Y + 3, tPos.Z))
			FxEvent:FireAllClients("Teleport", from, root.Position, color)
			ctx.Entities.Damage(target, form.heavy * 0.5 * q, { player = player, elements = elementsOf(w), color = color })
		end
	end
end

--------------------------------------------------------------------------------
-- Treffer anwenden
--------------------------------------------------------------------------------
local function hitEntity(player: Player, w: any, e: any, heavy: boolean, s: any): number
	local form = Config.Forms[w.form]
	local root = ctx.PlayerState.GetRoot(player) :: BasePart
	local amount = (if heavy then form.heavy else form.light) * qualityMult(w)
	local dist = (flat(e.root.Position) - flat(root.Position)).Magnitude - e.radius
	if w.form == "Spear" and dist < 2.5 then
		amount *= 0.7
	end
	if w.part == "PartMimicTooth" and e.pristine and e.isEnemy then
		amount *= 1.6
	end
	if w.part == "PartCrawlerClaw" and s.perfectDodgeUntil > os.clock() then
		amount *= 1.6
	end
	local consumedMark = false
	if heavy and has(w, "Shadow") and ctx.Entities.ConsumeMark(e) then
		amount *= 1.6
		consumedMark = true
		FxEvent:FireAllClients("Echo", e.root.Position, Config.Elements.Shadow.color)
	end
	local shieldMult = if heavy then 2 else 1
	if heavy and w.part == "PartWardenHorn" then
		shieldMult *= 3
	end
	local dealt = ctx.Entities.Damage(e, amount, {
		player = player,
		elements = elementsOf(w),
		heavy = heavy,
		color = colorOf(w),
		shieldMult = shieldMult,
	})
	if dealt <= 0 or e.dead and not e.isDummy then
		if dealt > 0 and consumedMark and combo(w) == "Ember+Shadow" then
			fireTrail(player, w, root.Position, e.root.Position)
		end
		return dealt
	end

	-- Unterbrechen / Betäuben
	if heavy and w.form == "Hammer" then
		ctx.Entities.Interrupt(e, 1)
	elseif heavy and w.part == "PartStalkerBark" then
		ctx.Entities.Interrupt(e, 0.5)
	end

	-- Grundelemente
	if has(w, "Ember") then
		ctx.Entities.AddBurn(e, if heavy then 2 else 1, player)
	end
	if has(w, "Frost") then
		local froze = ctx.Entities.AddFrost(e, if heavy then 2 else 1)
		if froze and combo(w) == "Frost+Storm" then
			coldShock(player, w, e)
		end
	end
	if has(w, "Shadow") and not heavy then
		ctx.Entities.Mark(e)
	end

	-- Kombinationen
	local key = combo(w)
	if key == "Ember+Frost" then
		thermoBreak(player, w, e)
	elseif key == "Frost+Shadow" and heavy then
		shadowEcho(player, w, e)
	elseif key == "Ember+Shadow" and consumedMark then
		fireTrail(player, w, root.Position, e.root.Position)
	end
	return dealt
end

local function swing(player: Player, heavy: boolean)
	local s = ctx.PlayerState.Get(player)
	local w = ctx.PlayerState.GetWeapon(player)
	local root = ctx.PlayerState.GetRoot(player)
	if not s or not w or not root then
		return
	end
	local form = Config.Forms[w.form]
	local look = flat(root.CFrame.LookVector)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local range = form.range + (if heavy then 1 else 0)
	local width = form.width * (if heavy and w.form == "Hammer" then 1.3 else 1)
	local center = root.Position + look * (range / 2 - 0.5)
	local cf = CFrame.lookAt(center, center + look)
	local targets = ctx.Entities.InBox(cf, Vector3.new(width, 8, range + 1))

	local primary = nil
	local any = false
	for _, e in targets do
		local dealt = hitEntity(player, w, e, heavy, s)
		if dealt > 0 then
			any = true
			if not primary or (e.isEnemy and not primary.isEnemy) then
				primary = e
			end
		end
	end
	if w.part == "PartCrawlerClaw" and any then
		s.perfectDodgeUntil = 0
	end
	if not any then
		return
	end
	ctx.PlayerState.AddCharge(player, if heavy then Config.Player.ChargeHeavy else Config.Player.ChargeLight)
	if has(w, "Storm") and primary then
		s.stormCharge += if heavy then 2 else 1
		if s.stormCharge >= 4 then
			s.stormCharge = 0
			stormDischarge(player, w, primary)
		end
	end
end

--------------------------------------------------------------------------------
-- Elementfähigkeit
--------------------------------------------------------------------------------
local function ability(player: Player)
	local s = ctx.PlayerState.Get(player)
	local w = ctx.PlayerState.GetWeapon(player)
	local root = ctx.PlayerState.GetRoot(player)
	if not s or not w or not root or not w.e1 then
		return
	end
	if s.charge < 100 then
		return
	end
	s.charge = 0
	local form = Config.Forms[w.form]
	local q = qualityMult(w)
	local radius = Config.Player.AbilityRadius * form.radiusMult * (if w.part == "PartWraithCore" then 1.5 else 1)
	local pos = root.Position
	local el = w.e1
	local color = Config.Elements[el].color
	local els = elementsOf(w)
	local function secondary(e: any)
		if w.e2 == "Ember" then
			ctx.Entities.AddBurn(e, 2, player)
		elseif w.e2 == "Frost" then
			ctx.Entities.AddFrost(e, 2)
		elseif w.e2 == "Shadow" then
			ctx.Entities.Mark(e)
		elseif w.e2 == "Storm" then
			s.stormCharge += 1
		end
	end

	if el == "Ember" then
		FxEvent:FireAllClients("Nova", pos, radius, color)
		areaDamage(player, w, pos, radius, 30 * q, color, nil, function(e)
			ctx.Entities.AddBurn(e, 3, player)
			secondary(e)
		end)
	elseif el == "Frost" then
		FxEvent:FireAllClients("Nova", pos, radius, color)
		areaDamage(player, w, pos, radius, 18 * q, color, nil, function(e)
			ctx.Entities.Freeze(e, 2.2)
			secondary(e)
		end)
	elseif el == "Storm" then
		local list = ctx.Entities.InRadius(pos, radius * 1.6)
		table.sort(list, function(a, b)
			return (a.root.Position - pos).Magnitude < (b.root.Position - pos).Magnitude
		end)
		for i = 1, math.min(4, #list) do
			local e = list[i]
			FxEvent:FireAllClients("Chain", e.root.Position + Vector3.new(0, 25, 0), e.root.Position, color)
			local dealt = ctx.Entities.Damage(e, 42 * q, { player = player, elements = els, color = color })
			if dealt > 0 then
				secondary(e)
			end
		end
		if #list == 0 then
			FxEvent:FireAllClients("Nova", pos, 6, color)
		end
	elseif el == "Shadow" then
		local look = flat(root.CFrame.LookVector)
		look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
		local dist = 18 * (if w.part == "PartWraithCore" then 1.4 else 1)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character :: Model, workspace:FindFirstChild("Entities") :: Instance }
		local hit = workspace:Raycast(pos, look * dist, params)
		if hit then
			dist = math.max(0, hit.Distance - 2)
		end
		local dest = pos + look * dist
		local mid = pos + look * (dist / 2)
		local targets = ctx.Entities.InBox(CFrame.lookAt(mid, mid + look), Vector3.new(7, 8, dist + 4))
		root.CFrame = CFrame.lookAt(dest, dest + look)
		FxEvent:FireAllClients("Teleport", pos, dest, color)
		for _, e in targets do
			local dealt = ctx.Entities.Damage(e, 38 * q, { player = player, elements = els, color = color })
			if dealt > 0 then
				ctx.Entities.Mark(e)
				secondary(e)
			end
		end
	end
	FxEvent:FireAllClients("Ability", player, el)
end

--------------------------------------------------------------------------------
-- Eingang
--------------------------------------------------------------------------------
local function onAction(player: Player, action: any, arg: any)
	if type(action) ~= "string" then
		return
	end
	local s = ctx.PlayerState.Get(player)
	if not s or not ctx.PlayerState.IsActive(player) then
		return
	end
	if ctx.Gear.Action(player, action, arg) then
		return
	end
	local now = os.clock()
	if s.rootedUntil > now and action == "Dodge" then
		return
	end
	if action == "Dodge" then
		if now - s.lastDodge < Config.Player.DodgeCooldown * 0.85 then
			return
		end
		if not ctx.PlayerState.UseStamina(player, Config.Player.DodgeStamina) then
			return
		end
		s.lastDodge = now
		s.iframesUntil = now + Config.Player.DodgeIFrames
		ctx.PlayerState.AddCharge(player, Config.Player.ChargeDodge)
		FxEvent:FireAllClients("Dodge", player)
		return
	end
	local w = ctx.PlayerState.GetWeapon(player)
	if not w then
		ctx.PlayerState.Notify(player, "Du hast keine Waffe. Schmiede zuerst eine!", "bad")
		return
	end
	if action == "Ability" then
		ability(player)
		return
	end
	if action ~= "Light" and action ~= "Heavy" then
		return
	end
	local heavy = action == "Heavy"
	if now < s.cooldownUntil then
		return
	end
	local form = Config.Forms[w.form]
	if not ctx.PlayerState.UseStamina(player, if heavy then Config.Player.HeavyStamina else Config.Player.LightStamina) then
		return
	end
	-- 10 % Toleranz für Latenz
	s.cooldownUntil = now + (if heavy then form.heavyCd else form.lightCd) * 0.9
	FxEvent:FireAllClients("Swing", player, heavy, w.form, colorOf(w))
	if heavy then
		task.delay(0.18, swing, player, true)
	else
		swing(player, false)
	end
end

function Combat.Init(context)
	ctx = context
end

function Combat.Start()
	Net.Event("Action").OnServerEvent:Connect(onAction)
end

return Combat
