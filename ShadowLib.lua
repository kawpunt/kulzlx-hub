--[[
  Shadow Lib (clean rebuild — same API as ShaddowScripts)
  CreateWindow / CreateTab / CreateButton / CreateToggle /
  CreateSlider / CreateCheckbox / CreateDropdown / Show
]]

local library = {}

local function play(id)
	for _, v in ipairs(workspace:GetChildren()) do
		if v.Name == "GUISound" then
			v:Destroy()
		end
	end
	local Sound = Instance.new("Sound")
	Sound.Name = "GUISound"
	Sound.Volume = 2
	Sound.SoundId = id
	Sound.Parent = workspace
	Sound:Play()
	task.delay(3, function()
		if Sound then
			Sound:Destroy()
		end
	end)
end

function library:CreateWindow(name, theme)
	local themes = {
		Normal = { Color3.fromRGB(32, 32, 32), Color3.fromRGB(26, 26, 26), Color3.fromRGB(176, 148, 255) },
		Reverse = { Color3.fromRGB(26, 26, 26), Color3.fromRGB(32, 32, 32), Color3.fromRGB(176, 148, 255) },
		Blood = { Color3.fromRGB(32, 32, 32), Color3.fromRGB(26, 26, 26), Color3.fromRGB(138, 3, 3) },
		Gainsboro = { Color3.fromRGB(32, 32, 32), Color3.fromRGB(26, 26, 26), Color3.fromRGB(220, 220, 221) },
		Canary = { Color3.fromRGB(32, 32, 32), Color3.fromRGB(26, 26, 26), Color3.fromRGB(255, 253, 130) },
		Emerald = { Color3.fromRGB(32, 32, 32), Color3.fromRGB(26, 26, 26), Color3.fromRGB(68, 207, 108) },
		Crimson = { Color3.fromRGB(32, 32, 32), Color3.fromRGB(26, 26, 26), Color3.fromRGB(214, 40, 57) },
		["Deep Sea"] = { Color3.fromRGB(32, 32, 32), Color3.fromRGB(26, 26, 26), Color3.fromRGB(40, 81, 214) },
	}
	local pal = themes[theme] or themes.Crimson
	local theme1, theme2, theme3 = pal[1], pal[2], pal[3]
	local toolight = (theme == "Gainsboro")

	for _, v in ipairs(game:GetService("CoreGui"):GetChildren()) do
		if v.Name == "By Shaddow" then
			v:Destroy()
		end
	end

	local Screen = Instance.new("ScreenGui")
	Screen.Name = "By Shaddow"
	Screen.ResetOnSpawn = false
	Screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function()
		Screen.Parent = game:GetService("CoreGui")
	end)
	if not Screen.Parent then
		Screen.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	end

	local Top = Instance.new("ImageLabel")
	Top.Name = "Top"
	Top.Parent = Screen
	Top.AnchorPoint = Vector2.new(0.5, 0.5)
	Top.BackgroundTransparency = 1
	Top.Active = true
	Top.Position = UDim2.new(0.5, 0, 0.22, 0)
	Top.Size = UDim2.new(0, 560, 0, 28)
	Top.Image = "rbxassetid://3570695787"
	Top.ImageColor3 = theme1
	Top.ScaleType = Enum.ScaleType.Slice
	Top.SliceCenter = Rect.new(100, 100, 100, 100)
	Top.SliceScale = 0.03

	local Title = Instance.new("TextLabel")
	Title.Parent = Top
	Title.BackgroundTransparency = 1
	Title.Position = UDim2.new(0.04, 0, 0, 0)
	Title.Size = UDim2.new(1, -40, 1, 0)
	Title.Font = Enum.Font.SourceSansSemibold
	Title.Text = name or "Shadow"
	Title.TextColor3 = Color3.new(1, 1, 1)
	Title.TextSize = 14
	Title.TextXAlignment = Enum.TextXAlignment.Left

	local ToggleBtn = Instance.new("TextButton")
	ToggleBtn.Name = "Toggle"
	ToggleBtn.Parent = Top
	ToggleBtn.BackgroundTransparency = 1
	ToggleBtn.Position = UDim2.new(0, 4, 0, 4)
	ToggleBtn.Size = UDim2.new(0, 18, 0, 18)
	ToggleBtn.Font = Enum.Font.SourceSansBold
	ToggleBtn.Text = "-"
	ToggleBtn.TextColor3 = Color3.new(1, 1, 1)
	ToggleBtn.TextSize = 16

	local Main = Instance.new("ImageLabel")
	Main.Name = "Main"
	Main.Parent = Top
	Main.AnchorPoint = Vector2.new(0.5, 0)
	Main.BackgroundTransparency = 1
	Main.Position = UDim2.new(0.5, 0, 1, 4)
	Main.Size = UDim2.new(0, 560, 0, 340)
	Main.Image = "rbxassetid://3570695787"
	Main.ImageColor3 = theme2
	Main.ScaleType = Enum.ScaleType.Slice
	Main.SliceCenter = Rect.new(100, 100, 100, 100)
	Main.SliceScale = 0.03

	local Tabs = Instance.new("Frame")
	Tabs.Name = "Tabs"
	Tabs.Parent = Main
	Tabs.BackgroundColor3 = theme1
	Tabs.BorderSizePixel = 0
	Tabs.Position = UDim2.new(0.015, 0, 0.03, 0)
	Tabs.Size = UDim2.new(0, 110, 0, 320)
	Instance.new("UICorner", Tabs).CornerRadius = UDim.new(0, 6)

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.Parent = Tabs
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 4)

	local Items = Instance.new("Frame")
	Items.Name = "Items"
	Items.Parent = Main
	Items.BackgroundColor3 = theme1
	Items.BorderSizePixel = 0
	Items.Position = UDim2.new(0.23, 0, 0.03, 0)
	Items.Size = UDim2.new(0, 420, 0, 320)
	Instance.new("UICorner", Items).CornerRadius = UDim.new(0, 6)

	local opened = true
	ToggleBtn.MouseButton1Click:Connect(function()
		opened = not opened
		Main.Visible = opened
		ToggleBtn.Text = opened and "-" or "+"
		play("rbxassetid://178104975")
	end)

	-- drag
	do
		local UIS = game:GetService("UserInputService")
		local dragging, start, pos
		Top.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				start = input.Position
				pos = Top.Position
			end
		end)
		UIS.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				local d = input.Position - start
				Top.Position = UDim2.new(pos.X.Scale, pos.X.Offset + d.X, pos.Y.Scale, pos.Y.Offset + d.Y)
			end
		end)
		UIS.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end)
	end

	local InsideLibrary = {}

	function InsideLibrary:CreateTab(text)
		local page = Instance.new("ScrollingFrame")
		page.Name = text
		page.Parent = Items
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.Size = UDim2.new(1, -10, 1, -10)
		page.Position = UDim2.new(0, 5, 0, 5)
		page.ScrollBarThickness = 4
		page.ScrollBarImageColor3 = theme3
		page.CanvasSize = UDim2.new(0, 0, 0, 0)
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.Visible = false

		local list = Instance.new("UIListLayout")
		list.Parent = page
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 4)

		local tabBtn = Instance.new("TextButton")
		tabBtn.Name = text .. " Button"
		tabBtn.Parent = Tabs
		tabBtn.BackgroundTransparency = 1
		tabBtn.Size = UDim2.new(1, -4, 0, 26)
		tabBtn.Font = Enum.Font.SourceSansSemibold
		tabBtn.Text = text
		tabBtn.TextColor3 = Color3.new(1, 1, 1)
		tabBtn.TextSize = 14

		tabBtn.MouseButton1Click:Connect(function()
			for _, child in ipairs(Items:GetChildren()) do
				if child:IsA("ScrollingFrame") then
					child.Visible = false
				end
			end
			for _, t in ipairs(Tabs:GetChildren()) do
				if t:IsA("TextButton") then
					t.TextColor3 = Color3.new(1, 1, 1)
				end
			end
			tabBtn.TextColor3 = theme3
			page.Visible = true
			play("rbxassetid://1412830636")
		end)

		local function row(labelText, h)
			local holder = Instance.new("Frame")
			holder.Parent = page
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.new(1, -6, 0, h or 28)
			local lab = Instance.new("TextLabel")
			lab.Parent = holder
			lab.BackgroundTransparency = 1
			lab.Size = UDim2.new(0.45, 0, 1, 0)
			lab.Font = Enum.Font.SourceSansSemibold
			lab.Text = labelText
			lab.TextColor3 = Color3.new(1, 1, 1)
			lab.TextSize = 13
			lab.TextXAlignment = Enum.TextXAlignment.Left
			return holder
		end

		local InsideTab = {}

		function InsideTab:Show()
			for _, child in ipairs(Items:GetChildren()) do
				if child:IsA("ScrollingFrame") then
					child.Visible = false
				end
			end
			page.Visible = true
			tabBtn.TextColor3 = theme3
		end

		function InsideTab:CreateButton(text, callback)
			callback = callback or function() end
			local holder = row(text)
			local btn = Instance.new("TextButton")
			btn.Parent = holder
			btn.Position = UDim2.new(0.5, 0, 0.1, 0)
			btn.Size = UDim2.new(0.48, 0, 0.8, 0)
			btn.BackgroundColor3 = theme2
			btn.BorderSizePixel = 0
			btn.Font = Enum.Font.SourceSansSemibold
			btn.Text = "run"
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.TextSize = 13
			Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
			btn.MouseButton1Click:Connect(function()
				pcall(callback)
				play("rbxassetid://178104975")
			end)
		end

		function InsideTab:CreateToggle(text, callback)
			callback = callback or function() end
			local holder = row(text)
			local enabled = false
			local btn = Instance.new("TextButton")
			btn.Parent = holder
			btn.Position = UDim2.new(0.55, 0, 0.2, 0)
			btn.Size = UDim2.new(0, 44, 0, 16)
			btn.BackgroundColor3 = theme2
			btn.BorderSizePixel = 0
			btn.Text = ""
			Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
			local knob = Instance.new("Frame")
			knob.Parent = btn
			knob.Size = UDim2.new(0, 12, 0, 12)
			knob.Position = UDim2.new(0, 2, 0, 2)
			knob.BackgroundColor3 = Color3.new(1, 1, 1)
			knob.BorderSizePixel = 0
			Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

			local actions = {}
			local function apply()
				if enabled then
					btn.BackgroundColor3 = theme3
					knob.Position = UDim2.new(1, -14, 0, 2)
					if toolight then
						knob.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
					end
				else
					btn.BackgroundColor3 = theme2
					knob.Position = UDim2.new(0, 2, 0, 2)
					knob.BackgroundColor3 = Color3.new(1, 1, 1)
				end
				pcall(callback, enabled)
			end

			btn.MouseButton1Click:Connect(function()
				enabled = not enabled
				apply()
				play("rbxassetid://6309164078")
			end)

			function actions:Set(state)
				enabled = not not state
				apply()
			end
			return actions
		end

		function InsideTab:CreateCheckbox(text, callback)
			return self:CreateToggle(text, callback)
		end

		function InsideTab:CreateSlider(text, minvalue, maxvalue, callback)
			minvalue = minvalue or 0
			maxvalue = maxvalue or 100
			callback = callback or function() end
			local holder = row(text, 36)
			local mouse = game:GetService("Players").LocalPlayer:GetMouse()
			local UIS = game:GetService("UserInputService")
			local valLabel = Instance.new("TextLabel")
			valLabel.Parent = holder
			valLabel.BackgroundTransparency = 1
			valLabel.Position = UDim2.new(0.88, 0, 0, 0)
			valLabel.Size = UDim2.new(0.12, 0, 0.45, 0)
			valLabel.Font = Enum.Font.SourceSansBold
			valLabel.Text = tostring(minvalue)
			valLabel.TextColor3 = theme3
			valLabel.TextSize = 12
			local bar = Instance.new("TextButton")
			bar.Parent = holder
			bar.Position = UDim2.new(0.48, 0, 0.55, 0)
			bar.Size = UDim2.new(0.5, 0, 0, 8)
			bar.BackgroundColor3 = theme2
			bar.BorderSizePixel = 0
			bar.Text = ""
			Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)
			local fill = Instance.new("Frame")
			fill.Parent = bar
			fill.BackgroundColor3 = theme3
			fill.BorderSizePixel = 0
			fill.Size = UDim2.new(0, 0, 1, 0)
			Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

			local function setFromX(x)
				local abs = bar.AbsolutePosition.X
				local w = bar.AbsoluteSize.X
				local a = 0
				if w > 0 then
					a = math.clamp((x - abs) / w, 0, 1)
				end
				fill.Size = UDim2.new(a, 0, 1, 0)
				local value = math.floor(minvalue + (maxvalue - minvalue) * a + 0.5)
				valLabel.Text = tostring(value)
				pcall(callback, value)
			end

			bar.MouseButton1Down:Connect(function()
				setFromX(mouse.X)
				local move, rel
				move = mouse.Move:Connect(function()
					setFromX(mouse.X)
				end)
				rel = UIS.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						move:Disconnect()
						rel:Disconnect()
					end
				end)
			end)
		end

		function InsideTab:CreateDropdown(text, list, callback)
			list = list or {}
			callback = callback or function() end
			local holder = row(text)
			local idx = 1
			local btn = Instance.new("TextButton")
			btn.Parent = holder
			btn.Position = UDim2.new(0.5, 0, 0.1, 0)
			btn.Size = UDim2.new(0.48, 0, 0.8, 0)
			btn.BackgroundColor3 = theme2
			btn.BorderSizePixel = 0
			btn.Font = Enum.Font.SourceSansSemibold
			btn.Text = tostring(list[1] or "")
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.TextSize = 12
			Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
			btn.MouseButton1Click:Connect(function()
				if #list == 0 then
					return
				end
				idx = idx % #list + 1
				btn.Text = tostring(list[idx])
				pcall(callback, list[idx])
				play("rbxassetid://178104975")
			end)
		end

		return InsideTab
	end

	return InsideLibrary
end

return library
