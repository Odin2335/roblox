--!nonstrict
-- RIFTBOUND – zentrale, datengetriebene Spielkonfiguration.
-- Server und Client lesen dieselben Werte; nur der Server entscheidet.

local Config = {}

Config.Version = "MVP v2 – Die Elementarschmiede"

--------------------------------------------------------------------------------
-- Farben
--------------------------------------------------------------------------------
Config.Colors = {
	Rift = Color3.fromRGB(63, 224, 197),
	Copper = Color3.fromRGB(217, 119, 58),
	Panel = Color3.fromRGB(18, 26, 34),
	PanelLight = Color3.fromRGB(30, 42, 54),
	Text = Color3.fromRGB(230, 238, 242),
	TextDim = Color3.fromRGB(140, 160, 172),
	Danger = Color3.fromRGB(235, 70, 70),
	Good = Color3.fromRGB(110, 220, 120),
	Stamina = Color3.fromRGB(240, 200, 80),
}

--------------------------------------------------------------------------------
-- Materialien, Kerne, Monsterteile
--------------------------------------------------------------------------------
export type ItemDef = {
	name: string,
	kind: "Basic" | "Core" | "Part",
	color: Color3,
	desc: string,
}

Config.Items = {
	CopperOre = { name = "Kupfererz", kind = "Basic", color = Color3.fromRGB(196, 110, 60), desc = "Im Schmelzofen zu Barren verarbeiten." },
	CopperBar = { name = "Kupferbarren", kind = "Basic", color = Config.Colors.Copper, desc = "Grundmetall für alle Waffenformen." },
	Stone = { name = "Stein", kind = "Basic", color = Color3.fromRGB(130, 140, 150), desc = "Für schwere Waffenköpfe." },
	Wood = { name = "Holz", kind = "Basic", color = Color3.fromRGB(120, 80, 50), desc = "Griffe und Schäfte." },
	RiftCrystal = { name = "Riftkristall", kind = "Basic", color = Config.Colors.Rift, desc = "Bindet Elementkerne an eine Waffe." },

	CoreEmber = { name = "Glutkern", kind = "Core", color = Color3.fromRGB(255, 120, 40), desc = "Element Glut." },
	CoreFrost = { name = "Frostkern", kind = "Core", color = Color3.fromRGB(120, 200, 255), desc = "Element Frost." },
	CoreStorm = { name = "Sturmkern", kind = "Core", color = Color3.fromRGB(250, 230, 90), desc = "Element Sturm." },
	CoreShadow = { name = "Schattenkern", kind = "Core", color = Color3.fromRGB(150, 90, 230), desc = "Element Schatten." },

	PartWardenHorn = {
		name = "Warden-Horn",
		kind = "Part",
		color = Color3.fromRGB(200, 150, 90),
		desc = "Schwere Angriffe brechen Rift-Schilde und -Kristalle dreimal so schnell.",
	},
	PartCrawlerClaw = {
		name = "Rift-Crawler-Klaue",
		kind = "Part",
		color = Color3.fromRGB(90, 220, 200),
		desc = "Nach einem perfekten Ausweichen: nächster Angriff +60 % Schaden.",
	},
	PartWraithCore = {
		name = "Lantern-Wraith-Kern",
		kind = "Part",
		color = Color3.fromRGB(255, 230, 150),
		desc = "Elementfähigkeit erhält 50 % mehr Reichweite.",
	},
	PartStalkerBark = {
		name = "Rootstalker-Rinde",
		kind = "Part",
		color = Color3.fromRGB(110, 80, 50),
		desc = "Schwere Angriffe unterbrechen gegnerische Angriffe zuverlässig.",
	},
	PartMimicTooth = {
		name = "Mimic-Zahn",
		kind = "Part",
		color = Color3.fromRGB(240, 230, 210),
		desc = "Erster Treffer gegen einen unversehrten Gegner: +60 % Schaden.",
	},
} :: { [string]: ItemDef }

Config.ItemOrder = {
	"CopperOre",
	"CopperBar",
	"Stone",
	"Wood",
	"RiftCrystal",
	"CoreEmber",
	"CoreFrost",
	"CoreStorm",
	"CoreShadow",
	"PartWardenHorn",
	"PartCrawlerClaw",
	"PartWraithCore",
	"PartStalkerBark",
	"PartMimicTooth",
}

Config.StarterStash = { CopperBar = 5, Wood = 4, Stone = 2, RiftCrystal = 2 }

--------------------------------------------------------------------------------
-- Elemente & Kombinationen
--------------------------------------------------------------------------------
Config.ElementOrder = { "Ember", "Frost", "Storm", "Shadow" }

Config.Elements = {
	Ember = {
		name = "Glut",
		core = "CoreEmber",
		color = Color3.fromRGB(255, 120, 40),
		desc = "Treffer bauen Brand auf und verursachen Schaden über Zeit.",
		ability = "Flammenstoß: Feuerwelle um dich, setzt alle Gegner in Brand.",
	},
	Frost = {
		name = "Frost",
		core = "CoreFrost",
		color = Color3.fromRGB(120, 200, 255),
		desc = "Verlangsamt; wiederholte Treffer frieren leichte Gegner kurz ein.",
		ability = "Frostnova: friert leichte Gegner in der Nähe ein.",
	},
	Storm = {
		name = "Sturm",
		core = "CoreStorm",
		color = Color3.fromRGB(250, 230, 90),
		desc = "Treffer laden Energie auf, die auf nahe Gegner überspringt.",
		ability = "Blitzschlag: trifft bis zu vier Gegner.",
	},
	Shadow = {
		name = "Schatten",
		core = "CoreShadow",
		color = Color3.fromRGB(150, 90, 230),
		desc = "Markiert Gegner; ein schwerer Treffer auf ein Mal löst Zusatzschaden aus.",
		ability = "Schattenschritt: Sprint nach vorn, markiert und trifft alles im Weg.",
	},
}

-- Schlüssel = beide Elemente in Config.ElementOrder-Reihenfolge, mit "+" verbunden.
Config.Combos = {
	["Ember+Frost"] = { name = "Thermobruch", desc = "Treffer erhitzen oder kühlen das Ziel. Jeder Wechsel löst Splitterschaden aus." },
	["Ember+Storm"] = { name = "Funkensturm", desc = "Entlädt sich die Sturmladung, explodiert das Ziel in Flammen." },
	["Ember+Shadow"] = { name = "Brandmal", desc = "Ein schwerer Treffer auf ein markiertes Ziel hinterlässt eine Feuerbahn." },
	["Frost+Storm"] = { name = "Kälteschock", desc = "Friert ein Ziel ein, springt ein Kältestoß auf nahe Gegner über." },
	["Frost+Shadow"] = { name = "Nachhall", desc = "Nach einem schweren Treffer folgt verzögert ein zweiter Schattenhieb." },
	["Storm+Shadow"] = { name = "Sprungblitz", desc = "Die Sturmentladung reißt dich zum nächsten markierten Gegner." },
}

function Config.ComboKey(a: string?, b: string?): string?
	if not a or not b or a == b then
		return nil
	end
	local ia = table.find(Config.ElementOrder, a) or 0
	local ib = table.find(Config.ElementOrder, b) or 0
	if ia > ib then
		a, b = b, a
	end
	return (a :: string) .. "+" .. (b :: string)
end

--------------------------------------------------------------------------------
-- Waffenformen
--------------------------------------------------------------------------------
export type FormDef = {
	name: string,
	desc: string,
	light: number,
	heavy: number,
	lightCd: number,
	heavyCd: number,
	range: number,
	width: number,
	chargeMult: number,
	radiusMult: number,
	reachMult: number,
	cost: { [string]: number },
	research: { [string]: number }?,
}

Config.FormOrder = { "Sword", "Hammer", "Spear" }

Config.Forms = {
	Sword = {
		name = "Schwert",
		desc = "Schnelle Schläge, vielseitige Kombos. Elementladung baut sich 30 % schneller auf.",
		light = 12,
		heavy = 26,
		lightCd = 0.42,
		heavyCd = 0.95,
		range = 7,
		width = 7,
		chargeMult = 1.3,
		radiusMult = 1,
		reachMult = 1,
		cost = { CopperBar = 3, Wood = 2 },
	},
	Hammer = {
		name = "Kriegshammer",
		desc = "Langsam, hoher Schaden, schwere Treffer betäuben. Elementexplosionen sind größer.",
		light = 18,
		heavy = 44,
		lightCd = 0.8,
		heavyCd = 1.55,
		range = 6.5,
		width = 9,
		chargeMult = 1,
		radiusMult = 1.6,
		reachMult = 1,
		cost = { CopperBar = 4, Stone = 3, Wood = 1 },
		research = { RiftCrystal = 3, Stone = 2 },
	},
	Spear = {
		name = "Speer",
		desc = "Große Reichweite, sichere Stiche. Schwächer direkt am Gegner. Effekte reichen weiter.",
		light = 11,
		heavy = 24,
		lightCd = 0.5,
		heavyCd = 1.05,
		range = 12,
		width = 4,
		chargeMult = 1,
		radiusMult = 1,
		reachMult = 1.5,
		cost = { CopperBar = 2, Wood = 3 },
		research = { RiftCrystal = 3, Wood = 3 },
	},
} :: { [string]: FormDef }

Config.ElementCost = { RiftCrystal = 2 } -- pro eingesetztem Kern (plus der Kern selbst)
Config.MaxWeapons = 20

Config.Quality = {
	{ name = "Grob", mult = 1.0 },
	{ name = "Solide", mult = 1.03 },
	{ name = "Fein", mult = 1.06 },
	{ name = "Meisterhaft", mult = 1.1 },
}

-- Härtungsschritt: Marker pendelt 0..1..0; Zielzone in der Mitte.
Config.Hardening = {
	Period = 1.3, -- Sekunden für hin und zurück
	Perfect = 0.05,
	Good = 0.13,
	Strikes = 3,
	Timeout = 25,
}

function Config.HardeningPos(elapsed: number): number
	local p = (elapsed % Config.Hardening.Period) / Config.Hardening.Period
	return if p < 0.5 then p * 2 else 2 - p * 2
end

function Config.QualityFromScore(score: number): number
	if score >= 6 then
		return 4
	elseif score >= 4 then
		return 3
	elseif score >= 2 then
		return 2
	end
	return 1
end

Config.Smelt = { input = "CopperOre", inputAmount = 2, output = "CopperBar" }

--------------------------------------------------------------------------------
-- Spieler
--------------------------------------------------------------------------------
Config.Player = {
	MaxHP = 100,
	MaxStamina = 100,
	StaminaRegen = 28,
	StaminaDelay = 0.7,
	LightStamina = 7,
	HeavyStamina = 18,
	DodgeStamina = 24,
	DodgeIFrames = 0.4,
	DodgeCooldown = 0.55,
	ChargeLight = 7,
	ChargeHeavy = 14,
	ChargeDodge = 10,
	AbilityRadius = 13,
	BleedoutTime = 30,
	ReviveTime = 2.5,
	ReviveHealth = 0.4,
	WalkSpeed = 18,
}

--------------------------------------------------------------------------------
-- Gegner
--------------------------------------------------------------------------------
export type EnemyDef = {
	name: string,
	hp: number,
	damage: number,
	speed: number,
	height: number,
	hip: number,
	attackRange: number,
	windup: number,
	cooldown: number,
	light: boolean, -- leichte Gegner können eingefroren werden
	drops: { { item: string, min: number, max: number, chance: number } },
}

Config.Enemies = {
	Riftling = {
		name = "Riftling",
		hp = 60,
		damage = 8,
		speed = 17,
		height = 5,
		hip = 1.6,
		attackRange = 5,
		windup = 0.55,
		cooldown = 1.4,
		light = true,
		drops = {
			{ item = "CopperOre", min = 1, max = 2, chance = 0.7 },
			{ item = "RiftCrystal", min = 1, max = 1, chance = 0.3 },
		},
	},
	Rootstalker = {
		name = "Rootstalker",
		hp = 95,
		damage = 10,
		speed = 12,
		height = 6.5,
		hip = 2.2,
		attackRange = 6,
		windup = 0.7,
		cooldown = 1.8,
		light = true,
		drops = {
			{ item = "Wood", min = 2, max = 3, chance = 1 },
			{ item = "PartStalkerBark", min = 1, max = 1, chance = 0.35 },
		},
	},
	Lantern_Wraith = {
		name = "Lantern Wraith",
		hp = 55,
		damage = 9,
		speed = 13,
		height = 5.5,
		hip = 4.5,
		attackRange = 26,
		windup = 0.6,
		cooldown = 2.6,
		light = true,
		drops = {
			{ item = "RiftCrystal", min = 1, max = 2, chance = 0.8 },
			{ item = "PartWraithCore", min = 1, max = 1, chance = 0.3 },
		},
	},
	Rift_Crawler = {
		name = "Rift Crawler",
		hp = 45,
		damage = 7,
		speed = 22,
		height = 2.6,
		hip = 0.9,
		attackRange = 5,
		windup = 0.4,
		cooldown = 1.2,
		light = true,
		drops = {
			{ item = "RiftCrystal", min = 1, max = 1, chance = 0.5 },
			{ item = "PartCrawlerClaw", min = 1, max = 1, chance = 0.3 },
		},
	},
	Burrow_Mimic = {
		name = "Burrow Mimic",
		hp = 130,
		damage = 14,
		speed = 14,
		height = 4,
		hip = 1.4,
		attackRange = 6,
		windup = 0.6,
		cooldown = 1.6,
		light = false,
		drops = {
			{ item = "CopperBar", min = 2, max = 3, chance = 1 },
			{ item = "PartMimicTooth", min = 1, max = 1, chance = 0.6 },
		},
	},
	Hollow_Warden = {
		name = "Hollow Warden",
		hp = 1100,
		damage = 22,
		speed = 11,
		height = 12,
		hip = 4.2,
		attackRange = 10,
		windup = 1.2,
		cooldown = 2.2,
		light = false,
		drops = {
			{ item = "PartWardenHorn", min = 1, max = 1, chance = 1 },
			{ item = "RiftCrystal", min = 4, max = 6, chance = 1 },
		},
	},
} :: { [string]: EnemyDef }

Config.Boss = {
	HPPerExtraPlayer = 0.6, -- +60 % Leben pro weiterem Spieler
	BurstCrystalHP = 70,
	BurstTime = 8,
	BurstDamage = 18, -- pro verbliebenem Kristall
	ArenaRadius = 46,
}

Config.Difficulties = {
	Normal = { name = "Normal", hp = 1, damage = 1, loot = 1 },
	Hard = { name = "Hart", hp = 1.5, damage = 1.35, loot = 1.6 },
}

--------------------------------------------------------------------------------
-- Aufgaben & Meilensteine
--------------------------------------------------------------------------------
Config.Quests = {
	{ id = "Smith", title = "Schmied", desc = "Stelle eine Waffe mit zwei Elementen her.", reward = { RiftCrystal = 3, CopperBar = 2 } },
	{
		id = "Explore",
		title = "Erkundung",
		desc = "Öffne das Frostsiegel in der Kupfermine (braucht Glut oder Frost).",
		reward = { RiftCrystal = 4, Stone = 3 },
	},
	{ id = "Hunter", title = "Jäger", desc = "Besiege Rootstalker und bringe eine Rootstalker-Rinde sicher zurück.", reward = { CopperBar = 4, Wood = 3 } },
	{
		id = "Boss",
		title = "Bossauftrag",
		desc = "Besiege den Hollow Warden mit einer selbst geschmiedeten Waffe.",
		reward = { RiftCrystal = 6, CopperBar = 4 },
	},
}

Config.Milestones = {
	{ id = "FirstWeapon", text = "Erste Waffe schmieden", hint = "Geh zur Schmiede (links) und stelle ein Schwert her." },
	{
		id = "Barrier",
		text = "Eine Barriere im Gebiet überwinden",
		hint = "Starte eine Expedition. In den Ruinen versperrt eine Rift-Barriere einen Schrein (schwere Angriffe!).",
	},
	{ id = "FirstCore", text = "Den ersten Elementkern bergen", hint = "Hinter der Rift-Barriere wartet ein Elementkern. Bring ihn sicher zurück." },
	{ id = "ElementWeapon", text = "Eine Elementwaffe schmieden", hint = "Setze in der Schmiede einen Elementkern in eine Waffe ein." },
	{ id = "MonsterPart", text = "Ein Monsterteil einsetzen", hint = "Bring ein Monsterteil zurück und setze es in der Schmiede oder im Arsenal ein." },
	{ id = "Warden", text = "Den Hollow Warden besiegen", hint = "Die Rift-Kammer liegt hinter der Kupfermine." },
	{
		id = "Rebuild",
		text = "Einen Bauplan mit neuer Elementkombination nachbauen",
		hint = "Speichere einen Bauplan, lade ihn in der Schmiede und ändere ein Element.",
	},
}

return Config
