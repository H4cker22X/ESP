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
	if p and p.Team and p.TeamColor then return p.TeamColor.Color end
	return Color3.new(1, 1, 1)
end

local function safeRestorePart(part)
	if not part or not part.Parent then return end
	if part:IsA("BasePart") then
		part.LocalTransparencyModifier = 0
		pcall(function() part.Material = Enum.Material.Plastic end)
	end
end

local function clear(p)
	if not p then return end
	local d = esp[p]
	if d then
		-- restore or destroy stored parts/outlines
		for _, v in ipairs(d.parts or {}) do
			if not v then
				-- skip
			elseif v:IsA("BasePart") then
				-- try to safely restore appearance
				pcall(safeRestorePart, v)
			elseif v:IsA("SelectionBox") then
				-- selection boxes were created by us; destroy them
				if v and v.Parent then
					pcall(function() v:Destroy() end)
				end
			else
				-- leftover UI/other object: destroy if safe
				if v and v.Parent then
					pcall(function() v:Destroy() end)
				end
			end
		end
		if d.label and d.label.Parent then
			pcall(function() d.label:Destroy() end)
		end
	end
	esp[p] = nil
end

local function attachDeathListener(p, char)
	if not p or not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		-- on death, clear esp (character will respawn and CharacterAdded will re-highlight)
		if not hum:IsDescendantOf(game) then return end
		pcall(function()
			hum.Died:Connect(function()
				clear(p)
			end)
		end)
	end
end

local function highlight(char, p)
	if not char or not p then return end
	clear(p) -- ensure no duplicate entries
	local parts, label = {}, makeLabel()
	local col = teamColor(p)

	for _, v in ipairs(char:GetDescendants()) do
		if v:IsA("BasePart") then
			-- change visuals
			pcall(function()
				v.Material = Enum.Material.ForceField
				v.LocalTransparencyModifier = 0.65
				v.Color = col
			end)

			-- create selection outline
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
	attachDeathListener(p, char)
end

local function monitor(p)
	if not p or p == lp then return end

	-- cleanup if player leaves
	Players.PlayerRemoving:Connect(function(removed)
		if removed == p then
			clear(p)
		end
	end)

	-- character added/removed
	p.CharacterAdded:Connect(function(c)
		-- clear previous esp (if any) then highlight new character once HRP exists
		clear(p)
		if c then
			local ok = pcall(function() c:WaitForChild("HumanoidRootPart", 5) end)
			if ok then
				highlight(c, p)
			end
		end
	end)

	p.CharacterRemoving:Connect(function()
		-- clear immediately when the character is being removed
		clear(p)
	end)

	-- if character already exists, highlight it and attach death listener
	if p.Character then
		local ok = pcall(function() p.Character:WaitForChild("HumanoidRootPart", 1) end)
		if ok then
			highlight(p.Character, p)
		end
	end
end

-- initial monitor for all current players
for _, p in ipairs(Players:GetPlayers()) do
	monitor(p)
end

-- monitor new players
Players.PlayerAdded:Connect(function(p)
	monitor(p)
end)

-- make sure PlayerRemoving clears too (extra safety)
Players.PlayerRemoving:Connect(function(p)
	clear(p)
end)

-- toggle key (K) behavior preserved
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
		-- guard: ensure player still exists in game
		if not p or not Players:FindFirstChild(p.Name) then
			clear(p)
			goto continue
		end

		local c = p.Character
		if not c then
			clear(p)
			goto continue
		end

		local hrp = c:FindFirstChild("HumanoidRootPart")
		local hum = c:FindFirstChildOfClass("Humanoid")
		local head = c:FindFirstChild("Head")

		if not hrp or not hum or not head then
			clear(p)
			goto continue
		end

		-- realtime team color update
		local col = teamColor(p)
		for _, v in ipairs(d.parts or {}) do
			if v:IsA("BasePart") then
				pcall(function() v.Color = col end)
			elseif v:IsA("SelectionBox") then
				pcall(function() v.Color3 = Color3.new(1, 1, 1) end)
			end
		end

		local dist = (hrp.Position - root.Position).Magnitude
		d.label.Text = string.format("%s | %d HP | %.1fm", p.Name, math.floor(hum.Health), dist)
		local sx, sy, onScreen = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 2, 0))
		d.label.Position = UDim2.new(0, sx - 100, 0, sy - 10)
		d.label.TextColor3 = col
		d.label.Visible = enabled and onScreen

		::continue::
	end
end)
