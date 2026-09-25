--!nonstrict
-- Letzter Profil-Snapshot vom Server + Änderungssignal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local Store = {}

Store.state = {
	stash = {},
	weapons = {},
	equipped = nil,
	unlocked = { Sword = true },
	blueprints = {},
	milestones = {},
	quests = {},
	backpack = {},
	protectedLoot = {},
	inRun = false,
	expedition = { phase = "Idle", members = {}, participants = {} },
} :: { [string]: any }

Store.loaded = false

local changed = Instance.new("BindableEvent")
Store.Changed = changed.Event

function Store.Equipped(): any?
	for _, w in Store.state.weapons do
		if w.id == Store.state.equipped then
			return w
		end
	end
	return nil
end

function Store.Count(item: string): number
	return Store.state.stash[item] or 0
end

Net.Event("State").OnClientEvent:Connect(function(snapshot)
	Store.state = snapshot
	Store.loaded = true
	changed:Fire()
end)

return Store
