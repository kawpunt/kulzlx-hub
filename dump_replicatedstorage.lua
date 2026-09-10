--[[
	Dump ReplicatedStorage → clipboard
	Executor: Synapse / Fluxus / Solara / Wave / etc.
	Uses setclipboard / toclipboard / Clipboard.set when available.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getClipboard()
	return setclipboard
		or toclipboard
		or set_clipboard
		or (Clipboard and Clipboard.set)
end

local function toClipboard(text)
	local cb = getClipboard()
	if not cb then
		warn("[RS Dump] No clipboard function on this executor")
		print(text)
		return false
	end
	cb(tostring(text))
	return true
end

local function pathOf(inst)
	local parts = {}
	local cur = inst
	while cur and cur ~= game do
		local name = cur.Name
		if name:find("[%s%p]") then
			name = '["' .. name:gsub('"', '\\"') .. '"]'
			table.insert(parts, 1, name)
		else
			table.insert(parts, 1, "." .. name)
		end
		cur = cur.Parent
	end
	local joined = table.concat(parts)
	if joined:sub(1, 1) == "." then
		joined = joined:sub(2)
	end
	return "game." .. joined
end

local function dumpInstance(inst, depth, lines, seen)
	seen = seen or {}
	if seen[inst] then
		return
	end
	seen[inst] = true

	depth = depth or 0
	local indent = string.rep("  ", depth)
	local attrs = {}

	pcall(function()
		for k, v in pairs(inst:GetAttributes()) do
			attrs[#attrs + 1] = k .. "=" .. tostring(v)
		end
	end)

	local attrStr = (#attrs > 0) and (" attrs{" .. table.concat(attrs, ", ") .. "}") or ""
	lines[#lines + 1] = string.format(
		"%s%s [%s]%s",
		indent,
		inst.Name,
		inst.ClassName,
		attrStr
	)

	-- useful value dumps for common RS types
	if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction")
		or inst:IsA("UnreliableRemoteEvent")
		or inst:IsA("BindableEvent") or inst:IsA("BindableFunction") then
		lines[#lines + 1] = indent .. "  path: " .. pathOf(inst)
	elseif inst:IsA("ModuleScript") then
		lines[#lines + 1] = indent .. "  path: " .. pathOf(inst)
		local ok, src = pcall(function()
			return inst.Source
		end)
		if ok and type(src) == "string" and #src > 0 then
			-- Source only readable in Studio / some executors
			lines[#lines + 1] = indent .. "  -- Source length: " .. #src
		end
	elseif inst:IsA("StringValue") or inst:IsA("NumberValue")
		or inst:IsA("BoolValue") or inst:IsA("IntValue")
		or inst:IsA("ObjectValue") then
		pcall(function()
			lines[#lines + 1] = indent .. "  Value = " .. tostring(inst.Value)
		end)
	end

	local children = inst:GetChildren()
	table.sort(children, function(a, b)
		return a.Name:lower() < b.Name:lower()
	end)
	for _, child in ipairs(children) do
		dumpInstance(child, depth + 1, lines, seen)
	end
end

local function buildTreeDump()
	local lines = {
		"-- ReplicatedStorage dump",
		"-- PlaceId: " .. tostring(game.PlaceId),
		"-- JobId: " .. tostring(game.JobId),
		"-- Time: " .. os.date("%Y-%m-%d %H:%M:%S"),
		"",
	}
	dumpInstance(ReplicatedStorage, 0, lines, {})
	return table.concat(lines, "\n")
end

local function buildJsonDump()
	local function node(inst, seen)
		seen = seen or {}
		if seen[inst] then
			return { Name = inst.Name, ClassName = inst.ClassName, cycle = true }
		end
		seen[inst] = true

		local kids = {}
		for _, child in ipairs(inst:GetChildren()) do
			kids[#kids + 1] = node(child, seen)
		end
		table.sort(kids, function(a, b)
			return (a.Name or ""):lower() < (b.Name or ""):lower()
		end)

		local out = {
			Name = inst.Name,
			ClassName = inst.ClassName,
			Path = pathOf(inst),
			Children = kids,
		}

		local attrs = {}
		pcall(function()
			for k, v in pairs(inst:GetAttributes()) do
				attrs[k] = tostring(v)
			end
		end)
		if next(attrs) then
			out.Attributes = attrs
		end

		if inst:IsA("StringValue") or inst:IsA("NumberValue")
			or inst:IsA("BoolValue") or inst:IsA("IntValue") then
			pcall(function()
				out.Value = tostring(inst.Value)
			end)
		end

		return out
	end

	return HttpService:JSONEncode({
		PlaceId = game.PlaceId,
		JobId = game.JobId,
		Time = os.date("%Y-%m-%d %H:%M:%S"),
		ReplicatedStorage = node(ReplicatedStorage),
	})
end

-- mode: "tree" (default) or "json"
local MODE = "tree"

local payload
if MODE == "json" then
	payload = buildJsonDump()
else
	payload = buildTreeDump()
end

local ok = toClipboard(payload)
local lines = select(2, payload:gsub("\n", "\n")) + 1
if ok then
	print(string.format("[RS Dump] Copied %d lines / %d chars to clipboard (%s)", lines, #payload, MODE))
else
	print(string.format("[RS Dump] Printed only — %d lines / %d chars (%s)", lines, #payload, MODE))
end
