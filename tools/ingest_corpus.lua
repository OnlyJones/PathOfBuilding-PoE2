-- Path of Building: PoE2 — Corpus Ingestion Pipeline
-- Usage: luajit tools/ingest_corpus.lua <codes.txt> <output_dir> [summary.json]
--
-- Fetches/decodes share codes, loads each build headlessly, records metrics,
-- extracts patterns, and emits a structured summary.

local codesPath = arg[1]
local outDir = arg[2]
local summaryPath = arg[3] or "corpus_summary.json"

if not codesPath or not outDir then
	print("Usage: luajit tools/ingest_corpus.lua <codes.txt> <output_dir> [summary.json]")
	os.exit(1)
end

local pob = dofile("tools/lib/pob_env.lua")
pob.bootstrap()

local share = dofile("tools/lib/share_code.lua")
local api = dofile("tools/lib/build_api.lua")
local dkjson = dofile("runtime/lua/dkjson.lua")

local t_insert = table.insert

os.execute('cmd /c "if not exist \"' .. outDir:gsub("/", "\\") .. '\" mkdir \"' .. outDir:gsub("/", "\\") .. '\""')

local summary = {
	date = os.date("%Y-%m-%d %H:%M:%S"),
	codesFile = codesPath,
	outputDir = outDir,
	builds = { },
	patterns = {
		classes = { },
		ascendancies = { },
		skills = { },
		supportGems = { },
		uniqueItems = { },
		rareBases = { },
		notableNodes = { },
		masteryNodes = { },
		configFlags = { },
	},
	metrics = {
		TotalDPS = { },
		TotalEHP = { },
		Life = { },
		Speed = { },
		CritChance = { },
	},
}

local function addCount(tbl, key)
	tbl[key] = (tbl[key] or 0) + 1
end

local function recordBuild(idx, code, xml)
	local buildPath = outDir .. "/" .. idx .. ".xml"
	local f = io.open(buildPath, "w")
	f:write(xml)
	f:close()

	local ok = pcall(function() api.loadBuildXML(xml, buildPath) end)
	if not ok then
		return nil, "loadBuildXML failed"
	end

	local out = build.calcsTab.mainOutput
	local entry = {
		index = idx,
		code = code:sub(1, 120),
		file = buildPath,
		class = build.spec.curClassName,
		ascendancy = build.spec.curAscendClassName,
		secondaryAscendancy = build.spec.curSecondaryAscendClassName,
		level = build.characterLevel,
		mainSkill = nil,
		metrics = {
			TotalDPS = out.TotalDPS,
			FullDPS = out.FullDPS,
			AverageDamage = out.AverageDamage,
			Speed = out.Speed,
			CritChance = out.CritChance,
			TotalEHP = out.TotalEHP,
			Life = out.Life,
			LifeUnreserved = out.LifeUnreserved,
			ManaUnreserved = out.ManaUnreserved,
			EnergyShield = out.EnergyShield,
			FireResist = out.FireResist,
			ColdResist = out.ColdResist,
			LightningResist = out.LightningResist,
			ChaosResist = out.ChaosResist,
			Armour = out.Armour,
			Evasion = out.Evasion,
		},
	}

	local mainGroup = build.skillsTab.socketGroupList[build.mainSocketGroup or 1]
	if mainGroup and mainGroup.gemList[1] then
		entry.mainSkill = mainGroup.gemList[1].nameSpec
	end

	addCount(summary.patterns.classes, entry.class or "Unknown")
	addCount(summary.patterns.ascendancies, entry.ascendancy or "None")

	for _, group in ipairs(build.skillsTab.socketGroupList) do
		for i, gem in ipairs(group.gemList) do
			if i == 1 then
				addCount(summary.patterns.skills, gem.nameSpec)
			else
				addCount(summary.patterns.supportGems, gem.nameSpec)
			end
		end
	end

	for _, item in pairs(build.itemsTab.items) do
		if item.rarity == "UNIQUE" then
			addCount(summary.patterns.uniqueItems, item.title or item.name or "Unknown")
		elseif item.baseName then
			addCount(summary.patterns.rareBases, item.baseName)
		end
	end

	for id, node in pairs(build.spec.allocNodes) do
		if node.type == "Notable" then
			addCount(summary.patterns.notableNodes, node.name)
		elseif node.type == "Mastery" then
			addCount(summary.patterns.masteryNodes, node.name)
		end
	end

	for k, v in pairs(build.configTab.input) do
		if v == true then
			addCount(summary.patterns.configFlags, k)
		end
	end

	for metric, samples in pairs(summary.metrics) do
		t_insert(samples, out[metric] or 0)
	end

	return entry
end

local f, err = io.open(codesPath, "r")
if not f then
	error("Cannot open " .. codesPath .. ": " .. tostring(err))
end

local idx = 1
for line in f:lines() do
	line = line:gsub("^%s+", ""):gsub("%s+$", "")
	if line ~= "" and not line:match("^#") then
		print("[" .. idx .. "] " .. line:sub(1, 60) .. (#line > 60 and "..." or ""))
		local ok, xml = pcall(function() return share.decodeInput(line) end)
		if ok and xml and xml:match("PathOfBuilding2") then
			local entry, err2 = recordBuild(idx, line, xml)
			if entry then
				t_insert(summary.builds, entry)
				print("      -> " .. (entry.class or "?") .. " / " .. (entry.ascendancy or "?") .. " | DPS " .. string.format("%.2f", entry.metrics.TotalDPS or 0) .. " | Life " .. math.floor(entry.metrics.Life or 0))
			else
				print("      -> FAILED to load: " .. tostring(err2))
			end
		else
			print("      -> FAILED to decode: " .. tostring(xml))
		end
		idx = idx + 1
	end
end
f:close()

local function meanAndStd(samples)
	local n = #samples
	if n == 0 then return nil, nil end
	local sum = 0
	for _, v in ipairs(samples) do sum = sum + v end
	local mean = sum / n
	local var = 0
	for _, v in ipairs(samples) do var = var + (v - mean) ^ 2 end
	return mean, math.sqrt(var / n)
end

for metric, samples in pairs(summary.metrics) do
	local mean, std = meanAndStd(samples)
	summary.metrics[metric] = {
		mean = mean,
		std = std,
		min = samples[1] and math.min(unpack(samples)) or nil,
		max = samples[1] and math.max(unpack(samples)) or nil,
	}
end

local sf, serr = io.open(summaryPath, "w")
if not sf then
	error("Cannot write summary: " .. tostring(serr))
end
sf:write(dkjson.encode(summary, { indent = true }))
sf:close()

print("")
print("Ingested " .. #summary.builds .. " builds.")
print("Summary written to " .. summaryPath)
