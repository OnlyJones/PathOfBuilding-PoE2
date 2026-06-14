-- Path of Building: PoE2 — Corpus Pattern Extractor
-- Usage: luajit tools/extract_patterns.lua <corpus_dir> [output.json]
--
-- Loads every PoB2 XML in a directory and emits frequency tables for archetype patterns.

local corpusDir = arg[1]
if not corpusDir then
	print("Usage: luajit tools/extract_patterns.lua <corpus_dir> [output.json]")
	os.exit(1)
end

local outputPath = arg[2] or "corpus_patterns.json"

local pob = dofile("tools/lib/pob_env.lua")
pob.bootstrap()

local api = dofile("tools/lib/build_api.lua")
local dkjson = dofile("runtime/lua/dkjson.lua")

local t_insert = table.insert

local function listXMLFiles(dir)
	local files = { }
	local cmd = 'cmd /c "dir /b \"' .. dir:gsub("/", "\\") .. '\\*.xml\""'
	local pipe = io.popen(cmd, "r")
	if pipe then
		for line in pipe:lines() do
			t_insert(files, dir .. "/" .. line)
		end
		pipe:close()
	end
	return files
end

local counts = {
	builds = 0,
	classes = {},
	ascendancies = {},
	skills = {},
	uniqueItems = {},
	rareBases = {},
	supportGems = {},
	notableNodes = {},
	masteryNodes = {},
	configFlags = {},
	metrics = {
		TotalDPS = { },
		TotalEHP = { },
		Life = { },
	},
}

local function addCount(tbl, key)
	tbl[key] = (tbl[key] or 0) + 1
end

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

local function processBuild(path)
	local f, err = io.open(path, "r")
	if not f then
		print("SKIP " .. path .. ": " .. tostring(err))
		return
	end
	local xml = f:read("*a")
	f:close()

	local ok = pcall(function() api.loadBuildXML(xml, path) end)
	if not ok then
		print("FAIL " .. path)
		return
	end

	counts.builds = counts.builds + 1
	addCount(counts.classes, build.spec.curClassName or "Unknown")
	addCount(counts.ascendancies, build.spec.curAscendClassName or "None")

	for _, group in ipairs(build.skillsTab.socketGroupList) do
		for i, gem in ipairs(group.gemList) do
			if i == 1 then
				addCount(counts.skills, gem.nameSpec)
			else
				addCount(counts.supportGems, gem.nameSpec)
			end
		end
	end

	for _, item in pairs(build.itemsTab.items) do
		if item.rarity == "UNIQUE" then
			addCount(counts.uniqueItems, item.title or item.name or "Unknown")
		elseif item.baseName then
			addCount(counts.rareBases, item.baseName)
		end
	end

	for id, node in pairs(build.spec.allocNodes) do
		if node.type == "Notable" then
			addCount(counts.notableNodes, node.name)
		elseif node.type == "Mastery" then
			addCount(counts.masteryNodes, node.name)
		end
	end

	for k, v in pairs(build.configTab.input) do
		if v == true then
			addCount(counts.configFlags, k)
		end
	end

	local out = build.calcsTab.mainOutput
	t_insert(counts.metrics.TotalDPS, out.TotalDPS or 0)
	t_insert(counts.metrics.TotalEHP, out.TotalEHP or 0)
	t_insert(counts.metrics.Life, out.Life or 0)

	print("OK   " .. path .. " -> " .. (out.TotalDPS and string.format("%.2f DPS", out.TotalDPS) or "no DPS"))
end

for _, path in ipairs(listXMLFiles(corpusDir)) do
	processBuild(path)
end

local function topN(tbl, n)
	n = n or 30
	local list = { }
	for k, v in pairs(tbl) do
		t_insert(list, { key = k, count = v })
	end
	table.sort(list, function(a, b) return a.count > b.count end)
	local result = { }
	for i = 1, math.min(n, #list) do
		result[list[i].key] = list[i].count
	end
	return result
end

local summary = {
	builds = counts.builds,
	classes = counts.classes,
	ascendancies = counts.ascendancies,
	topSkills = topN(counts.skills, 30),
	topSupportGems = topN(counts.supportGems, 30),
	topUniqueItems = topN(counts.uniqueItems, 30),
	topRareBases = topN(counts.rareBases, 30),
	topNotableNodes = topN(counts.notableNodes, 50),
	topMasteryNodes = topN(counts.masteryNodes, 30),
	topConfigFlags = topN(counts.configFlags, 30),
	metrics = { },
}

for metric, samples in pairs(counts.metrics) do
	local mean, std = meanAndStd(samples)
	summary.metrics[metric] = {
		mean = mean,
		std = std,
		min = samples[1] and math.min(unpack(samples)) or nil,
		max = samples[1] and math.max(unpack(samples)) or nil,
	}
end

local f = io.open(outputPath, "w")
f:write(dkjson.encode(summary, { indent = true }))
f:close()

print("")
print("Processed " .. counts.builds .. " builds.")
print("Wrote " .. outputPath)
