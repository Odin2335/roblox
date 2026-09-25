--!nonstrict
-- Erstellt (Server) bzw. findet (Client) alle Remotes an einer Stelle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"Action", -- Client -> Server: Kampfabsichten ("Light", "Heavy", "Dodge", "Ability")
	"Request", -- Client -> Server: Menü-Aktionen (Schmelzen, Ausrüsten, Expedition ...)
	"State", -- Server -> Client: Profil-Snapshot
	"Notify", -- Server -> Client: Hinweis-Toast
	"OpenUI", -- Server -> Client: Station geöffnet
	"Fx", -- Server -> alle: visuelle Effekte (Schwung, Treffer, Elementeffekte)
}

local FUNCTIONS = {
	"ForgeBegin",
	"ForgeFinish",
}

local Net = {}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		folder = existing :: Folder
	else
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteFunction")
			r.Name = name
			r.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.Event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Net
