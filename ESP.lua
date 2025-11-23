local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera
local esp, enabled = {}, true

local gui = Instance.new("ScreenGui")
gui.ResetOnSpawn = false
gui.Parent = lp:WaitForChild("PlayerGui")

local function makeLabel()
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(0, 200, 0, 18)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.SourceSansBold
	l.TextScaled = true
	l.TextStrokeTransparency = 0.3
	l.Parent = gui
	return l
end

local function teamColor(p)
	if p.Team and p.TeamColor then return p.TeamColor.Color end
	return Color3.new(1, 1, 1)
end

local function clear(p)
	local d = esp[p]
	if d then
		for _, v in ipairs(d.parts or {}) do
			if v and v.Parent then
				if v:IsA("BasePart") then
					v.LocalTransparencyModifier = 0
					v.Material = Enum.Material.Plastic
				else
					v:Destroy()
				end
			end
		end
		if d.label then d.label:Destroy() end
	end
	esp[p] = nil
end

local function highlight(char, p)
	local parts, label = {}, makeLabel()

	for _, v in ipairs(char:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Material = Enum.Material.ForceField
			v.LocalTransparencyModifier = 0.65

			local outline = Instance.new("SelectionBox")
			outline.Adornee = v
			outline.LineThickness = 0.03
			outline.Color3 = Color3.new(1, 1, 1)
			outline.Transparency = 0
			outline.Parent = gui

			table.insert(parts, v)
			table.insert(parts, outline)
		end
	end

	esp[p] = {parts = parts, label = label, char = char}
end

local function monitor(p)
	if p == lp then return end
	p.CharacterAdded:Connect(function(c)
		clear(p)
		c:WaitForChild("HumanoidRootPart")
		highlight(c, p)
	end)
	p.CharacterRemoving:Connect(function() clear(p) end)
	if p.Character then highlight(p.Character, p) end
end

for _, p in ipairs(Players:GetPlayers()) do monitor(p) end
Players.PlayerAdded:Connect(monitor)
Players.PlayerRemoving:Connect(clear)

UIS.InputBegan:Connect(function(i, g)
	if g then return end
	if i.KeyCode == Enum.KeyCode.K then
		enabled = not enabled
		for _, d in pairs(esp) do
			if d.label then d.label.Visible = enabled end
			for _, v in ipairs(d.parts or {}) do
				if v:IsA("BasePart") then
					v.LocalTransparencyModifier = enabled and 0.65 or 0
					v.Material = enabled and Enum.Material.ForceField or Enum.Material.Plastic
				elseif v:IsA("SelectionBox") then
					v.Visible = enabled
				end
			end
		end
	end
end)

RS.RenderStepped:Connect(function()
	if not enabled then return end

	local char = lp.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	for p, d in pairs(esp) do
		local c = p.Character
		if not c then clear(p) continue end

		local hrp = c:FindFirstChild("HumanoidRootPart")
		local hum = c:FindFirstChild("Humanoid")
		local head = c:FindFirstChild("Head")

		if not hrp or not hum or not head then clear(p) continue end

		local col = teamColor(p)  -- real-time color refresh

		for _, v in ipairs(d.parts or {}) do
			if v:IsA("BasePart") then
				v.Color = col
			elseif v:IsA("SelectionBox") then
				v.Color3 = Color3.new(1, 1, 1)
			end
		end

		local dist = (hrp.Position - root.Position).Magnitude
		d.label.Text = string.format("%s | %d HP | %.1fm", p.Name, math.floor(hum.Health), dist)

		local pos = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 2, 0))
		d.label.Position = UDim2.new(0, pos.X - 100, 0, pos.Y - 10)
		d.label.TextColor3 = col
		d.label.Visible = enabled
	end
end)
