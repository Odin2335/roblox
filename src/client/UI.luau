--!nonstrict
-- Kleine UI-Bibliothek: einheitlicher Look für HUD und Menüs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local UI = {}

UI.C = {
	Bg = Color3.fromRGB(14, 20, 27),
	Panel = Config.Colors.Panel,
	Card = Config.Colors.PanelLight,
	CardHover = Color3.fromRGB(40, 56, 70),
	Stroke = Color3.fromRGB(52, 70, 84),
	Text = Config.Colors.Text,
	Dim = Config.Colors.TextDim,
	Rift = Config.Colors.Rift,
	Copper = Config.Colors.Copper,
	Danger = Config.Colors.Danger,
	Good = Config.Colors.Good,
	Stamina = Config.Colors.Stamina,
}

UI.Font = Enum.Font.GothamMedium
UI.FontBold = Enum.Font.GothamBold
UI.FontBlack = Enum.Font.GothamBlack

function UI.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UI.Corner(r: number?): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, r or 8) })
end

function UI.Stroke(color: Color3?, thickness: number?): UIStroke
	return UI.new("UIStroke", { Color = color or UI.C.Stroke, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function UI.Pad(px: number): UIPadding
	local u = UDim.new(0, px)
	return UI.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function UI.List(padding: number?, horizontal: boolean?, align: Enum.HorizontalAlignment?): UIListLayout
	return UI.new("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top,
	})
end

function UI.Label(text: string, size: number?, color: Color3?, font: Enum.Font?, props: { [string]: any }?): TextLabel
	local l = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size or 14,
		TextColor3 = color or UI.C.Text,
		Font = font or UI.Font,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		RichText = true,
	})
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
	return l
end

function UI.Button(text: string, color: Color3?, onClick: (() -> ())?, props: { [string]: any }?): TextButton
	local base = color or UI.C.Card
	local b = UI.new("TextButton", {
		Text = text,
		TextSize = 14,
		Font = UI.FontBold,
		TextColor3 = UI.C.Text,
		BackgroundColor3 = base,
		AutoButtonColor = true,
		Size = UDim2.new(1, 0, 0, 34),
		TextWrapped = true,
	}, { UI.Corner(7) })
	if props then
		for k, v in props do
			(b :: any)[k] = v
		end
	end
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

function UI.Scroll(props: { [string]: any }?): ScrollingFrame
	local s = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = UI.C.Stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
	})
	if props then
		for k, v in props do
			(s :: any)[k] = v
		end
	end
	return s
end

function UI.Card(props: { [string]: any }?): Frame
	local f = UI.new("Frame", {
		BackgroundColor3 = UI.C.Card,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, { UI.Corner(8), UI.Pad(8) })
	if props then
		for k, v in props do
			(f :: any)[k] = v
		end
	end
	return f
end

function UI.Clear(frame: Instance)
	for _, c in frame:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIGridLayout") and not c:IsA("UIPadding") and not c:IsA("UICorner") and not c:IsA("UIStroke") then
			c:Destroy()
		end
	end
end

function UI.Bar(color: Color3, props: { [string]: any }?): (Frame, Frame, TextLabel)
	local back = UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(10, 14, 18),
		BackgroundTransparency = 0.15,
		Size = UDim2.new(1, 0, 0, 16),
	}, { UI.Corner(5), UI.Stroke(UI.C.Stroke) })
	local fill = UI.new("Frame", {
		BackgroundColor3 = color,
		Size = UDim2.fromScale(1, 1),
		Parent = back,
	}, { UI.Corner(5) })
	local text = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextSize = 11,
		Font = UI.FontBold,
		TextColor3 = UI.C.Text,
		TextStrokeTransparency = 0.5,
		ZIndex = 3,
		Parent = back,
	})
	if props then
		for k, v in props do
			(back :: any)[k] = v
		end
	end
	return back, fill, text
end

function UI.ItemName(id: string): string
	local def = Config.Items[id]
	return if def then def.name else id
end

function UI.Hex(c: Color3): string
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

function UI.Colored(text: string, c: Color3): string
	return string.format('<font color="%s">%s</font>', UI.Hex(c), text)
end

function UI.WeaponName(w: any): string
	local name = Config.Forms[w.form].name
	local key = Config.ComboKey(w.e1, w.e2)
	if key then
		return Config.Combos[key].name .. "-" .. name
	elseif w.e1 then
		return Config.Elements[w.e1].name .. "-" .. name
	end
	return name
end

return UI
