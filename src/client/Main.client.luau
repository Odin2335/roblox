--!nonstrict
-- RIFTBOUND – Client-Einstiegspunkt.

local Store = require(script.Parent.Store)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local Input = require(script.Parent.Input)
local Fx = require(script.Parent.Fx)

Panels.Init(Hud.Toast)
Hud.Init({
	openPanel = Panels.Toggle,
	action = Input.Action,
})
Input.Init({
	isOpen = Panels.IsOpen,
	toggle = Panels.Toggle,
	close = Panels.Close,
})
Fx.Init(Hud.Flash)

local _ = Store
