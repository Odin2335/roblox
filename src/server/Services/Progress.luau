--!nonstrict
-- Meilensteine und Aufgaben.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Progress = {}
local ctx: any

function Progress.Init(context)
	ctx = context
end

function Progress.OnLoaded(player: Player)
	local profile = ctx.DataService.Get(player)
	if not profile then
		return
	end
	for _, q in Config.Quests do
		if not profile.quests[q.id] then
			profile.quests[q.id] = "open"
		end
	end
end

function Progress.Milestone(player: Player, id: string)
	local profile = ctx.DataService.Get(player)
	if not profile or profile.milestones[id] then
		return
	end
	profile.milestones[id] = true
	ctx.DataService.MarkDirty(player)
	for _, m in Config.Milestones do
		if m.id == id then
			ctx.PlayerState.Notify(player, "Meilenstein: " .. m.text, "milestone")
		end
	end
	ctx.PlayerState.Sync(player)
end

function Progress.CompleteQuest(player: Player, id: string)
	local profile = ctx.DataService.Get(player)
	if not profile or profile.quests[id] ~= "open" then
		return
	end
	profile.quests[id] = "done"
	ctx.DataService.MarkDirty(player)
	for _, q in Config.Quests do
		if q.id == id then
			ctx.PlayerState.Notify(player, "Aufgabe erfüllt: " .. q.title .. " – Belohnung im Aufgabenmenü abholen (J).", "milestone")
		end
	end
	ctx.PlayerState.Sync(player)
end

function Progress.Claim(player: Player, id: string)
	local profile = ctx.DataService.Get(player)
	if not profile or profile.quests[id] ~= "done" then
		return
	end
	for _, q in Config.Quests do
		if q.id == id then
			profile.quests[id] = "claimed"
			ctx.DataService.Give(player, q.reward)
			ctx.PlayerState.Notify(player, "Belohnung erhalten: " .. q.title, "good")
		end
	end
	ctx.PlayerState.Sync(player)
end

return Progress
