--[[
	Better script dumper (fixed)
	Keeps Instance hierarchy on disk via writefile / makefolder

	Fixes vs original (fyz#7690):
	- actually walks game (original only hit nil + settings)
	- optional ReplicatedStorage-only mode
	- GetFullName split by "." no longer used for path (names with dots break)
	- makevalid uses :gsub correctly
	- duplicate names get a numeric suffix instead of silent ignore

	Discord credit: fyz#7690
]]

-- ============ config ============
-- "all" = game + nil instances + settings (original intent, fixed)
-- also: "game" | "nil" | "ReplicatedStorage"
local SCOPE = "all"
local ignore_empty_scripts = true
local randomize_name = false
--[[ randomize_name: filesystem cannot have two same names in one folder.
     leave false for consistent names; duplicates get _2, _3 suffixes. ]]
local include_cores = false -- CoreGui / CorePackages (usually useless + huge)
local prefix = "scripts_" .. tostring(game.PlaceId)
-- =================================

local CoreGui = game:GetService("CoreGui")
local CorePackages = game:GetService("CorePackages")

local decomp_idx = 0
local scripts = {}
local tree = {}

local invalid_chars = { string.char(127), "\\", ":", "*", "?", "\"", "<", ">", "|" }
for i = 0, 32 do table.insert(invalid_chars, string.char(i)) end
for i = 128, 255 do table.insert(invalid_chars, string.char(i)) end

local function makevalid(str)
	str = tostring(str)
	for _, c in ipairs(invalid_chars) do
		str = str:gsub(c, "")
	end
	if str == "" then
		str = "_unnamed"
	end
	return str
end

local function isScript(inst)
	return inst.ClassName == "LocalScript" or inst.ClassName == "ModuleScript"
end

local function shouldSkip(inst)
	if include_cores then
		return false
	end
	return inst:IsDescendantOf(CoreGui) or inst:IsDescendantOf(CorePackages)
end

-- collect by scope
local function addUnique(inst)
	if not isScript(inst) or shouldSkip(inst) then
		return
	end
	for _, s in ipairs(scripts) do
		if s == inst then
			return
		end
	end
	table.insert(scripts, inst)
end

local function gatherscripts(inst)
	addUnique(inst)
	for _, child in ipairs(inst:GetChildren()) do
		gatherscripts(child)
	end
end

if SCOPE == "ReplicatedStorage" then
	gatherscripts(game:GetService("ReplicatedStorage"))
elseif SCOPE == "game" then
	gatherscripts(game)
elseif SCOPE == "nil" then
	if getnilinstances then
		for _, v in ipairs(getnilinstances()) do
			gatherscripts(v)
		end
	else
		warn("[Dumper] getnilinstances missing — nil scope empty")
	end
elseif SCOPE == "all" then
	-- walk entire DataModel (Workspace, RS, SS, Players, Starter*, Lighting, etc.)
	gatherscripts(game)

	-- every service that might not show under game children cleanly
	for _, svc in ipairs(game:GetChildren()) do
		pcall(gatherscripts, svc)
	end

	-- nil-parented instances (original dumper)
	if getnilinstances then
		for _, v in ipairs(getnilinstances()) do
			gatherscripts(v)
		end
	else
		warn("[Dumper] getnilinstances missing — skipped nil")
	end

	-- settings() (original dumper)
	pcall(function()
		gatherscripts(settings())
	end)

	-- executor getscripts / getrunningscripts if present (more than tree walk)
	if getscripts then
		local ok, list = pcall(getscripts)
		if ok and type(list) == "table" then
			for _, s in ipairs(list) do
				addUnique(s)
			end
			print("[Dumper] Merged getscripts()")
		end
	end
	if getrunningscripts then
		local ok, list = pcall(getrunningscripts)
		if ok and type(list) == "table" then
			for _, s in ipairs(list) do
				addUnique(s)
			end
			print("[Dumper] Merged getrunningscripts()")
		end
	end
else
	error("[Dumper] bad SCOPE: " .. tostring(SCOPE))
end

print(string.format("[Dumper] Found %d scripts (scope=%s)", #scripts, SCOPE))

-- build hierarchy tree using real Parent chain (not GetFullName split)
local function insertIntoTree(inst)
	local chain = {} -- root → ... → parent of script
	local cur = inst
	while cur do
		table.insert(chain, 1, cur)
		cur = cur.Parent
	end

	-- nil-parented scripts sit under "_nil"
	local rootKey
	if not inst.Parent then
		rootKey = "_nil"
		if not tree[rootKey] then
			tree[rootKey] = {}
		end
		local filename
		if randomize_name then
			filename = inst:GetDebugId() .. "_" .. inst.Name .. "." .. inst.ClassName .. ".lua"
		else
			filename = inst.Name .. "." .. inst.ClassName .. ".lua"
		end
		filename = makevalid(filename)
		local ct = tree[rootKey]
		if ct[filename] and not randomize_name then
			local n = 2
			local base = filename:gsub("%.lua$", "")
			while ct[base .. "_" .. n .. ".lua"] do
				n = n + 1
			end
			filename = base .. "_" .. n .. ".lua"
			warn("[Dumper] Duplicate in nil, renamed:", inst:GetFullName(), "->", filename)
		end
		ct[filename] = inst
		return
	end

	-- first in chain is game or a service or a nil-root instance
	rootKey = makevalid(chain[1].Name)
	if not tree[rootKey] then
		tree[rootKey] = {}
	end
	local ct = tree[rootKey]

	-- walk folders for everything except the script itself
	for i = 2, #chain - 1 do
		local folder = makevalid(chain[i].Name)
		if not ct[folder] then
			ct[folder] = {}
		elseif typeof(ct[folder]) ~= "table" then
			-- name collision with a script file — nest under folder-ish key
			folder = folder .. "_folder"
			if not ct[folder] then
				ct[folder] = {}
			end
		end
		ct = ct[folder]
	end

	local filename
	if randomize_name then
		filename = inst:GetDebugId() .. "_" .. inst.Name .. "." .. inst.ClassName .. ".lua"
	else
		filename = inst.Name .. "." .. inst.ClassName .. ".lua"
	end
	filename = makevalid(filename)

	if ct[filename] and typeof(ct[filename]) == "Instance" and not randomize_name then
		local n = 2
		local base = filename:gsub("%.lua$", "")
		while ct[base .. "_" .. n .. ".lua"] do
			n = n + 1
		end
		filename = base .. "_" .. n .. ".lua"
		warn("[Dumper] Duplicate, renamed:", inst:GetFullName(), "->", filename)
	end

	ct[filename] = inst
end

for _, v in ipairs(scripts) do
	insertIntoTree(v)
end

local scriptslen = #scripts

local function isCommentOnly(src)
	for _, line in ipairs(string.split(src, "\n")) do
		local trimmed = line:match("^%s*(.-)%s*$") or ""
		if trimmed ~= "" and trimmed:sub(1, 2) ~= "--" then
			return false
		end
	end
	return true
end

local function walk_tree(t, path)
	for name, v in pairs(t) do
		name = makevalid(name)
		if typeof(v) == "table" then
			local nextPath = (path == "") and name or (path .. "/" .. name)
			walk_tree(v, nextPath)
		elseif typeof(v) == "Instance" then
			decomp_idx = decomp_idx + 1
			print(string.format("[Dumper] Decompile %d/%d  %s", decomp_idx, scriptslen, v:GetFullName()))

			if not decompile then
				error("[Dumper] decompile() missing — executor cannot dump bytecode")
			end

			local ok, src = pcall(decompile, v)
			if not ok then
				warn("[Dumper] No bytecode:", v:GetFullName(), src)
				continue
			end

			src = tostring(src or "")
			if ignore_empty_scripts and #src < 200 and isCommentOnly(src) then
				print("[Dumper] Skip empty:", v:GetFullName())
				continue
			end

			local dir = prefix .. ((path == "") and "" or ("/" .. path))
			if not isfolder(dir) then
				makefolder(dir)
			end

			local full = dir .. "/" .. name
			local wrote, err = pcall(writefile, full, src)
			if not wrote then
				error("[Dumper] writefile failed: " .. full .. "\n" .. tostring(err))
			end
		else
			warn("[Dumper] unexpected node type under", path, name, typeof(v))
		end
	end
end

if not writefile or not makefolder or not isfolder then
	error("[Dumper] Missing writefile / makefolder / isfolder")
end

if not isfolder(prefix) then
	makefolder(prefix)
end

walk_tree(tree, "")
print(string.format("[Dumper] Done. Wrote under '%s/' (%d attempted)", prefix, decomp_idx))
