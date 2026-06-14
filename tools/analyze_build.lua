-- Path of Building: PoE2 — Build Analyzer
-- Usage: luajit tools/analyze_build.lua <path/to/build.xml>
--
-- Emits a JSON summary of a PoB2 build: class, tree, items, skills, config, metrics.

local buildPath = arg[1]
if not buildPath then
	print("Usage: luajit tools/analyze_build.lua <path/to/build.xml>")
	os.exit(1)
end

local pob = dofile("tools/lib/pob_env.lua")
pob.bootstrap()

local dkjson = dofile("runtime/lua/dkjson.lua")
local t_insert = table.insert

local function readFile(path)
	local f, err = io.open(path, "r")
	if not f then
		error("Cannot open build file: " .. tostring(path) .. " (" .. tostring(err) .. ")")
	end
	local content = f:read("*a")
	f:close()
	return content
end

local xmlText = readFile(buildPath)
local api = dofile("tools/lib/build_api.lua")
api.loadBuildXML(xmlText, buildPath)

local function summarizeItems()
	local items = { }
	for slotName, slot in pairs(build.itemsTab.slots) do
		local itemId = slot.selItemId
		if itemId and itemId ~= 0 then
			local item = build.itemsTab.items[itemId]
			if item then
				t_insert(items, {
					slot = slotName,
					name = item.name,
					rarity = item.rarity,
					baseName = item.baseName,
					itemLevel = item.itemLevel,
					quality = item.quality,
				})
			end
		end
	end
	return items
end

local function summarizeSkills()
	local groups = { }
	for i, group in ipairs(build.skillsTab.socketGroupList) do
		local gems = { }
		for _, gem in ipairs(group.gemList) do
			t_insert(gems, {
				name = gem.nameSpec,
				level = gem.level,
				quality = gem.quality,
				count = gem.count,
				enabled = gem.enabled,
			})
		end
		t_insert(groups, {
			index = i,
			label = group.label,
			mainActiveSkill = group.mainActiveSkill,
			includeInFullDPS = group.includeInFullDPS,
			gems = gems,
		})
	end
	return groups
end

local function summarizeTree()
	local nodes = { }
	for id, node in pairs(build.spec.allocNodes) do
		t_insert(nodes, {
			id = id,
			name = node.name,
			type = node.type,
		})
	end
	return {
		class = build.spec.curClassName,
		ascendClass = build.spec.curAscendClassName,
		secondaryAscendClass = build.spec.curSecondaryAscendClassName,
		level = build.characterLevel,
		allocatedNodes = nodes,
		usedPassivePoints = build.spec:CountAllocNodes(),
	}
end

local function summarizeConfig()
	local cfg = { }
	for k, v in pairs(build.configTab.input) do
		if type(v) == "boolean" or type(v) == "number" or type(v) == "string" then
			cfg[k] = v
		end
	end
	return cfg
end

local out = build.calcsTab.mainOutput
local summary = {
	buildPath = buildPath,
	class = build.spec.curClassName,
	ascendancy = build.spec.curAscendClassName,
	secondaryAscendancy = build.spec.curSecondaryAscendClassName,
	level = build.characterLevel,
	mainSocketGroup = build.mainSocketGroup,
	tree = summarizeTree(),
	items = summarizeItems(),
	skills = summarizeSkills(),
	config = summarizeConfig(),
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

print(dkjson.encode(summary, { indent = true }))
