--!strict
-- Profile laden/speichern (DataStore) und Lagerbestand verwalten.
-- In Studio ohne API-Zugriff läuft das Spiel mit Sitzungsdaten weiter.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Weapon = {
	id: string,
	form: string,
	e1: string?,
	e2: string?,
	part: string?,
	quality: number,
	forged: boolean,
}

export type Blueprint = { name: string, form: string, e1: string?, e2: string? }

export type Profile = {
	version: number,
	stash: { [string]: number },
	weapons: { Weapon },
	equipped: string?,
	nextWeaponId: number,
	unlocked: { [string]: boolean },
	blueprints: { Blueprint },
	milestones: { [string]: boolean },
	quests: { [string]: string }, -- "open" | "done" | "claimed"
	stats: { [string]: number },
}

local DataService = {}
local ctx: any

local STORE_NAME = "RIFTBOUND_v2"
local store: DataStore? = nil
local profiles: { [Player]: Profile } = {}
local dirty: { [Player]: boolean } = {}
local loaded: { [Player]: boolean } = {}

local function newProfile(): Profile
	local stash = {}
	for k, v in Config.StarterStash do
		stash[k] = v
	end
	return {
		version = 2,
		stash = stash,
		weapons = {},
		equipped = nil,
		nextWeaponId = 1,
		unlocked = { Sword = true },
		blueprints = {},
		milestones = {},
		quests = {},
		stats = {},
	}
end

local function reconcile(data: any): Profile
	local base = newProfile()
	if type(data) ~= "table" then
		return base
	end
	for k, v in base :: any do
		if data[k] == nil then
			data[k] = v
		end
	end
	return data :: Profile
end

function DataService.Init(context)
	ctx = context
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[RIFTBOUND] DataStore nicht verfügbar – Fortschritt wird nicht gespeichert:", result)
	end
end

function DataService.Get(player: Player): Profile?
	return profiles[player]
end

function DataService.MarkDirty(player: Player)
	dirty[player] = true
end

local function save(player: Player)
	local profile = profiles[player]
	if not profile or not store or not loaded[player] then
		return
	end
	local key = "u_" .. player.UserId
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key, function()
				return profile
			end)
		end)
		if ok then
			dirty[player] = nil
			return
		end
		warn("[RIFTBOUND] Speichern fehlgeschlagen (Versuch " .. attempt .. "):", err)
		task.wait(1.5 * attempt)
	end
end

local function load(player: Player)
	local profile: Profile = newProfile()
	local success = true
	if store then
		local key = "u_" .. player.UserId
		local ok, data = false, nil
		for _ = 1, 3 do
			ok, data = pcall(function()
				return (store :: DataStore):GetAsync(key)
			end)
			if ok then
				break
			end
			task.wait(1)
		end
		if ok then
			profile = reconcile(data)
		else
			success = false
			warn("[RIFTBOUND] Laden fehlgeschlagen – Sitzung wird nicht gespeichert:", data)
		end
	end
	if player.Parent ~= Players then
		return
	end
	profiles[player] = profile
	loaded[player] = success
	ctx.PlayerState.OnProfileLoaded(player)
end

-- Lagerbestand ---------------------------------------------------------------

function DataService.Has(player: Player, cost: { [string]: number }): boolean
	local p = profiles[player]
	if not p then
		return false
	end
	for item, n in cost do
		if (p.stash[item] or 0) < n then
			return false
		end
	end
	return true
end

function DataService.Take(player: Player, cost: { [string]: number }): boolean
	if not DataService.Has(player, cost) then
		return false
	end
	local p = profiles[player] :: Profile
	for item, n in cost do
		p.stash[item] -= n
		if p.stash[item] <= 0 then
			p.stash[item] = nil
		end
	end
	dirty[player] = true
	return true
end

function DataService.Give(player: Player, items: { [string]: number })
	local p = profiles[player]
	if not p then
		return
	end
	for item, n in items do
		if Config.Items[item] and n > 0 then
			p.stash[item] = (p.stash[item] or 0) + n
		end
	end
	dirty[player] = true
end

function DataService.Start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
		dirty[player] = nil
		loaded[player] = nil
	end)
	game:BindToClose(function()
		local threads = 0
		for player in profiles do
			threads += 1
			task.spawn(function()
				save(player)
				threads -= 1
			end)
		end
		local t = os.clock()
		while threads > 0 and os.clock() - t < 20 do
			task.wait(0.2)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for player in dirty do
				task.spawn(save, player)
			end
		end
	end)
end

DataService.Save = save

return DataService
