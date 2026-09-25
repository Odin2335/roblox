--!strict
-- RIFTBOUND – Server-Einstiegspunkt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Services = script.Parent:WaitForChild("Services")

local ctx: { [string]: any } = {}
local order = {
	"AssetLoader",
	"DataService",
	"PlayerState",
	"Progress",
	"Entities",
	"WorldBuilder",
	"Combat",
	"Forge",
	"Expedition",
}

for _, name in order do
	ctx[name] = require(Services:WaitForChild(name) :: ModuleScript)
end
for _, name in order do
	local service = ctx[name]
	if service.Init then
		service.Init(ctx)
	end
end

-- Menüaktionen der Clients verteilen
Net.Event("Request").OnServerEvent:Connect(function(player, action, a, b)
	if type(action) ~= "string" then
		return
	end
	if ctx.Expedition.Handle(player, action, a) then
		return
	end
	ctx.Forge.Handle(player, action, a, b)
end)

-- Startreihenfolge: Welt vor den Spielern
for _, name in { "Entities", "WorldBuilder", "PlayerState", "Combat", "Forge", "Expedition", "DataService" } do
	local service = ctx[name]
	if service.Start then
		service.Start()
	end
end

print("[RIFTBOUND] Server bereit.")
