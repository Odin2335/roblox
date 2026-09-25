--!nonstrict
-- Eingaben (Maus/Tastatur, Controller, Touch) → Kampfabsichten an den Server.
-- Ausweichen bewegt den eigenen Charakter sofort (Client besitzt die Physik),
-- Unverwundbarkeit und Ausdauer prüft der Server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Store)

local player = Players.LocalPlayer
local ActionEvent = Net.Event("Action")

local Input = {}

local isOpen: () -> boolean = function()
	return false
end
local lastAttack = 0
local lastDodge = 0
local rightDownAt = 0

local function root(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function canAct(): boolean
	if isOpen() or player:GetAttribute("Downed") == true then
		return false
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

-- Richtet den Charakter aus: PC → zur Maus, sonst zum nächsten Gegner vor dir.
local function aim(range: number)
	local r = root()
	if not r then
		return
	end
	local targetPos: Vector3? = nil
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		local mouse = player:GetMouse()
		local hit = mouse.Hit.Position
		if (hit - r.Position).Magnitude < 300 then
			targetPos = hit
		end
	end
	if not targetPos then
		local folder = workspace:FindFirstChild("Entities")
		local best, bestD = nil, range + 6
		if folder then
			local look = r.CFrame.LookVector
			for _, m in folder:GetChildren() do
				if m:IsA("Model") and m.PrimaryPart then
					local offset = m.PrimaryPart.Position - r.Position
					local d = offset.Magnitude
					local flatOff = Vector3.new(offset.X, 0, offset.Z)
					if d < bestD and flatOff.Magnitude > 0.1 and look:Dot(flatOff.Unit) > 0.2 then
						best, bestD = m.PrimaryPart.Position, d
					end
				end
			end
		end
		targetPos = best
	end
	if targetPos then
		local flatTarget = Vector3.new(targetPos.X, r.Position.Y, targetPos.Z)
		if (flatTarget - r.Position).Magnitude > 0.5 then
			r.CFrame = CFrame.lookAt(r.Position, flatTarget)
		end
	end
end

local function attack(heavy: boolean)
	if not canAct() then
		return
	end
	local w = Store.Equipped()
	if not w then
		ActionEvent:FireServer("Light") -- Server meldet "keine Waffe"
		return
	end
	local form = Config.Forms[w.form]
	local cd = if heavy then form.heavyCd else form.lightCd
	local now = os.clock()
	if now - lastAttack < cd then
		return
	end
	local cost = if heavy then Config.Player.HeavyStamina else Config.Player.LightStamina
	if (player:GetAttribute("Stamina") or 0) < cost then
		return
	end
	lastAttack = now
	aim(form.range)
	ActionEvent:FireServer(if heavy then "Heavy" else "Light")
end

local function dodge()
	if not canAct() then
		return
	end
	local now = os.clock()
	if now - lastDodge < Config.Player.DodgeCooldown then
		return
	end
	if (player:GetAttribute("Stamina") or 0) < Config.Player.DodgeStamina then
		return
	end
	local r = root()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not r or not hum or hum.WalkSpeed <= 0 then
		return
	end
	lastDodge = now
	ActionEvent:FireServer("Dodge")
	local dir = hum.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = -r.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local att = Instance.new("Attachment")
	att.Parent = r
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = 1e5
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = dir * 62
	lv.Parent = r
	task.delay(0.2, function()
		lv:Destroy()
		att:Destroy()
	end)
end

local function ability()
	if not canAct() then
		return
	end
	if (player:GetAttribute("Charge") or 0) < 100 then
		return
	end
	local w = Store.Equipped()
	aim(if w then Config.Forms[w.form].range else 8)
	ActionEvent:FireServer("Ability")
end

function Input.Action(action: string)
	if action == "Light" then
		attack(false)
	elseif action == "Heavy" then
		attack(true)
	elseif action == "Dodge" then
		dodge()
	elseif action == "Ability" then
		ability()
	end
end

export type Callbacks = {
	isOpen: () -> boolean,
	toggle: (string) -> (),
	close: () -> (),
}

function Input.Init(cb: Callbacks)
	isOpen = cb.isOpen
	UserInputService.InputBegan:Connect(function(input, processed)
		local key = input.KeyCode
		-- Menütasten funktionieren auch, wenn ein Menü offen ist
		if not processed or input.UserInputType == Enum.UserInputType.Keyboard then
			if key == Enum.KeyCode.I or key == Enum.KeyCode.ButtonSelect then
				if not UserInputService:GetFocusedTextBox() then
					cb.toggle("Inventory")
				end
				return
			elseif key == Enum.KeyCode.J then
				if not UserInputService:GetFocusedTextBox() then
					cb.toggle("Quests")
				end
				return
			elseif key == Enum.KeyCode.H then
				if not UserInputService:GetFocusedTextBox() then
					cb.toggle("Help")
				end
				return
			elseif key == Enum.KeyCode.Escape or key == Enum.KeyCode.ButtonB and isOpen() then
				cb.close()
				return
			end
		end
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			attack(false)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			rightDownAt = os.clock()
		elseif key == Enum.KeyCode.R or key == Enum.KeyCode.ButtonR1 then
			attack(true)
		elseif key == Enum.KeyCode.ButtonR2 then
			attack(false)
		elseif key == Enum.KeyCode.Q or key == Enum.KeyCode.ButtonB or key == Enum.KeyCode.LeftControl then
			dodge()
		elseif key == Enum.KeyCode.F or key == Enum.KeyCode.ButtonY then
			ability()
		end
	end)
	UserInputService.InputEnded:Connect(function(input, processed)
		-- Kurzer Rechtsklick = schwerer Angriff (langes Halten dreht weiterhin die Kamera)
		if input.UserInputType == Enum.UserInputType.MouseButton2 and not processed then
			if os.clock() - rightDownAt < 0.22 then
				attack(true)
			end
		end
	end)
end

return Input
