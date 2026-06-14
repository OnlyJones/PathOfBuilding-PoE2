-- Path of Building: PoE2 — Build Improver
-- Usage: luajit tools/improve_build.lua <seed.xml|share_code_url> [options]
--
-- Loads any PoB2 build, analyzes it, then suggests improvements by searching
-- over gear and tree while keeping the build's identity (class, ascendancy,
-- main skill, supports, tree strategy) intact.

local args = {}
for i = 1, #arg do
	if arg[i] == "--output" then args.output = arg[i + 1] end
	if arg[i] == "--points" then args.points = tonumber(arg[i + 1]) end
	if arg[i] == "--level" then args.level = tonumber(arg[i + 1]) end
	if arg[i] == "--gear-sets" then args.gearSets = tonumber(arg[i + 1]) end
	if arg[i] == "--beam-width" then args.beamWidth = tonumber(arg[i + 1]) end
	if arg[i] == "--seed" then args.seed = tonumber(arg[i + 1]) end
	if arg[i] == "--budget" then args.budget = arg[i + 1] end
	if arg[i] == "--slots" then args.slots = arg[i + 1] end
	if arg[i] == "--keep-uniques" then args.keepUniques = true end
	if arg[i] == "--replace-uniques" then args.keepUniques = false end
	if arg[i] == "--focus" then args.focus = arg[i + 1] end
	if arg[i] == "--optimize-gems" then args.optimizeGems = true end
	if arg[i] == "--no-optimize-gems" then args.optimizeGems = false end
	if arg[i] == "--max-supports" then args.maxSupports = tonumber(arg[i + 1]) end
end

local input = arg[1]
if not input then
	print("Usage: luajit tools/improve_build.lua <seed.xml|share_code_url> [--output out.xml] [--points N] [--level N] [--gear-sets N] [--beam-width N] [--seed N] [--budget mid|high|low] [--slots weapon,body,gloves,...] [--keep-uniques | --replace-uniques] [--focus dps|balance|defence] [--optimize-gems | --no-optimize-gems] [--max-supports N]")
	os.exit(1)
end

local outputPath = args.output or "improved_build.xml"
local maxPoints = args.points or 100
local charLevel = args.level or 90
local gearSetCount = args.gearSets or 12
local beamWidth = args.beamWidth or 1
local seed = args.seed or os.time()
local budget = args.budget or "mid"
local keepUniques = args.keepUniques ~= false
local focus = args.focus or "dps"
local optimizeGems = args.optimizeGems ~= false
local maxSupportsOverride = args.maxSupports
math.randomseed(seed)

local t_insert = table.insert

local function tableCount(tbl)
	local n = 0
	for _ in pairs(tbl) do n = n + 1 end
	return n
end

local pob = dofile("tools/lib/pob_env.lua")
pob.bootstrap()

-- Re-seed after POB bootstrap
math.randomseed(seed)

local api = dofile("tools/lib/build_api.lua")
local share = dofile("tools/lib/share_code.lua")
local itemPool = dofile("tools/lib/adaptive_item_pool.lua")
local gemPool = dofile("tools/lib/gem_pool.lua")
local buffPool = dofile("tools/lib/buff_pool.lua")
local objective = dofile("tools/lib/objective.lua")

-- Compute a single primary-damage number that works across archetypes.
local function effectiveDPS(out)
	out = out or build.calcsTab.mainOutput
	if not out then return 0 end
	local dps = out.TotalDPS or 0
	if dps > 0 then return dps end
	dps = out.FullDPS or 0
	if dps > 0 then return dps end
	dps = (out.AverageDamage or 0) * (out.Speed or 0)
	if dps > 0 then return dps end
	if out.Minion then
		dps = out.Minion.TotalDPS or 0
		if dps > 0 then return dps end
		dps = (out.Minion.AverageDamage or 0) * (out.Minion.Speed or 0)
		if dps > 0 then return dps end
	end
	return 0
end

-- === Load seed build ===
local xmlText, sourceName
if input:match("^https?://") or input:match("^%s*[a-zA-Z0-9]+%.[a-zA-Z]") then
	local code = input:gsub("^%s+", ""):gsub("%s+$", "")
	if code:match("^https?://") then
		xmlText = share.decodeURL(code)
		sourceName = code
	else
		xmlText = share.decodeInput(code)
		sourceName = "share_code"
	end
	if not xmlText or not xmlText:match("PathOfBuilding2") then
		print("Failed to decode share code / URL: " .. input)
		os.exit(1)
	end
else
	local f, err = io.open(input, "r")
	if not f then
		print("Cannot open seed build: " .. tostring(err))
		os.exit(1)
	end
	xmlText = f:read("*a")
	f:close()
	sourceName = input
end

api.loadBuildXML(xmlText, sourceName)

-- === Extract seed identity ===
local seedInfo = {
	classId = build.spec.curClassId,
	ascendClassId = build.spec.curAscendClassId,
	secondaryAscendClassId = build.spec.curSecondaryAscendClassId,
	mainSocketGroup = build.mainSocketGroup,
	skills = {},
	items = {},
	treeNodes = {},
	level = build.characterLevel or charLevel,
}

for i, group in ipairs(build.skillsTab.socketGroupList) do
	local gems = {}
	for _, gem in ipairs(group.gemList) do
		t_insert(gems, {
			name = gem.nameSpec,
			level = gem.level,
			quality = gem.quality,
		})
	end
	t_insert(seedInfo.skills, {
		index = i,
		label = group.label,
		mainActiveSkill = group.mainActiveSkill,
		includeInFullDPS = group.includeInFullDPS,
		gems = gems,
	})
end

local mainSkillName = ""
local mainGroup = build.skillsTab.socketGroupList[build.mainSocketGroup or 1]
if mainGroup and mainGroup.gemList[1] then
	mainSkillName = mainGroup.gemList[1].nameSpec
end

-- Capture main-skill gem and all non-main groups for support optimization.
seedInfo.mainGem = nil
seedInfo.otherGroups = {}
if mainGroup and mainGroup.gemList[1] then
	local mg = mainGroup.gemList[1]
	seedInfo.mainGem = {
		name = mg.nameSpec,
		level = mg.level,
		quality = mg.quality,
		count = mg.count or 1,
	}
	seedInfo.mainGroupLabel = mainGroup.label
	seedInfo.mainGroupMainActiveSkill = mainGroup.mainActiveSkill
	seedInfo.mainGroupIncludeInFullDPS = mainGroup.includeInFullDPS
end
for i, group in ipairs(build.skillsTab.socketGroupList) do
	if i ~= (build.mainSocketGroup or 1) then
		local gems = {}
		for _, gem in ipairs(group.gemList) do
			if gem.enabled then
				t_insert(gems, {
					name = gem.nameSpec,
					level = gem.level,
					quality = gem.quality,
					count = gem.count or 1,
				})
			end
		end
		t_insert(seedInfo.otherGroups, {
			label = group.label,
			mainActiveSkill = group.mainActiveSkill,
			includeInFullDPS = group.includeInFullDPS,
			gems = gems,
		})
	end
end

for slotName, slot in pairs(build.itemsTab.slots) do
	local itemId = slot.selItemId
	if itemId and itemId ~= 0 then
		local item = build.itemsTab.items[itemId]
		if item then
			seedInfo.items[slotName] = {
				name = item.name,
				rarity = item.rarity,
				baseName = item.baseName,
				slot = slotName,
				raw = item.raw,
			}
		end
	end
end

for id, node in pairs(build.spec.allocNodes) do
	seedInfo.treeNodes[id] = {
		name = node.name,
		type = node.type,
	}
end

-- Configure adaptive item pool from seed identity
itemPool.configure({ mainSkill = mainSkillName, items = seedInfo.items, level = seedInfo.level, budget = budget })

-- Slots that have unique items in the seed; we can preserve them by default.
local seedUniqueSlots = {}
for slotName, saved in pairs(seedInfo.items) do
	if saved.rarity == "UNIQUE" then
		seedUniqueSlots[slotName] = true
	end
end
if keepUniques and next(seedUniqueSlots) then
	local list = {}
	for s in pairs(seedUniqueSlots) do t_insert(list, s) end
	print(string.format("  Keeping seed uniques in slots: %s", table.concat(list, ", ")))
end

print("Loaded seed build: " .. sourceName)
print(string.format("  Class: %s / %s", build.spec.curClassName or "?", build.spec.curAscendClassName or "?"))
print(string.format("  Level: %d", seedInfo.level))
print(string.format("  Main skill: %s", mainSkillName))
print(string.format("  Skill groups: %d", #seedInfo.skills))
print(string.format("  Equipped items: %d", tableCount(seedInfo.items)))
print(string.format("  Allocated nodes: %d", tableCount(seedInfo.treeNodes)))

-- Capture baseline metrics before modifying
build.buildFlag = true
runCallback("OnFrame")
seedInfo.baseDPS = effectiveDPS(build.calcsTab.mainOutput)
seedInfo.baseLife = build.calcsTab.mainOutput.Life
seedInfo.baseEHP = build.calcsTab.mainOutput.TotalEHP
print(string.format("  Baseline: DPS %.2f | Life %.0f | EHP %.2f", seedInfo.baseDPS, seedInfo.baseLife, seedInfo.baseEHP))

-- === Objective config ===
local objConfig = {
	weights = {
		TotalDPS = 1.0,
		FullDPS = 0.5,
		TotalEHP = 0.002,
		Life = 0.8,
		Evasion = 0.001,
	},
	gates = {
		minLife = 1500,
		minUncappedResist = 0,
		minDex = 0,
		minInt = 0,
		minStr = 0,
	},
	penalties = {
		resistBelowCap = 10000,
		lifeBelowMin = 100,
		attributeShortfall = 1000,
	},
}

if focus == "balance" then
	objConfig.weights.TotalDPS = 0.7
	objConfig.weights.TotalEHP = 0.008
	objConfig.weights.Life = 1.2
	objConfig.weights.Evasion = 0.003
	objConfig.gates.minLife = 2000
elseif focus == "defence" then
	objConfig.weights.TotalDPS = 0.3
	objConfig.weights.TotalEHP = 0.015
	objConfig.weights.Life = 2.0
	objConfig.weights.Evasion = 0.005
	objConfig.gates.minLife = 2500
end

-- Archetype-aware defensive weights: scale Armour/ES so armour-stackers and ES builds
-- do not collapse their defensive identity when DPS is optimized.
local seedArmour = build.calcsTab.mainOutput.Armour or 0
local seedES = build.calcsTab.mainOutput.EnergyShield or 0
local seedEHP = build.calcsTab.mainOutput.TotalEHP or 0
if seedArmour > 10000 then
	objConfig.weights.Armour = 0.002 + math.min(0.008, seedArmour / 5000000)
elseif seedArmour > 5000 then
	objConfig.weights.Armour = 0.001
end
if seedES > 2000 then
	objConfig.weights.EnergyShield = 0.002 + math.min(0.008, seedES / 500000)
end
-- Hard floor: do not allow EHP to drop below a fraction of the seed unless focus is dps.
if focus ~= "dps" and seedEHP > 0 then
	objConfig.gates.minEHP = math.floor(seedEHP * 0.50)
end

local function evalBuild()
	build.buildFlag = true
	runCallback("OnFrame")
	return objective.evaluate(objConfig)
end

-- === Tree improvement strategy ===
local function getCandidateNodes(maxHop)
	maxHop = maxHop or 2
	local nodes = {}
	local seen = {}
	local allocSet = {}
	for id, _ in pairs(build.spec.allocNodes) do
		allocSet[id] = true
	end

	local function visit(nodeId, hop)
		if hop > maxHop then return end
		local node = build.spec.nodes[nodeId]
		if not node then return end
		if node.type == "Notable" and not allocSet[nodeId] and not seen[nodeId] then
			seen[nodeId] = true
			t_insert(nodes, node)
		end
		for _, linkId in ipairs(node.linked or {}) do
			visit(linkId, hop + 1)
		end
	end

	for id, _ in pairs(allocSet) do
		visit(id, 0)
	end
	return nodes
end

local calcs = LoadModule("Modules/Calcs")

-- === Greedy / beam tree optimization ===
local function optimizeTree(candidateNodes, pointsBudget)
	local base = evalBuild()
	local baseNodes = {}
	for id, _ in pairs(build.spec.allocNodes) do
		baseNodes[id] = true
	end

	local calcFunc = calcs.getNodeCalculator(build)
	local function incrementalEval(nodeList)
		calcFunc(nodeList)
		return objective.evaluate(objConfig)
	end

	local states = { { alloc = {}, score = base.score, result = base } }

	for step = 1, pointsBudget do
		local newStates = {}
		for _, state in ipairs(states) do
			for _, node in ipairs(candidateNodes) do
				if not state.alloc[node.id] then
					local pathNodes = build.spec:GetAllocationPath(node, 0, false, nil)
					if pathNodes then
						local pathCost = 0
						for _, pn in ipairs(pathNodes) do
							if not state.alloc[pn.id] and not baseNodes[pn.id] then
								pathCost = pathCost + 1
							end
						end
						if pathCost > 0 and pathCost <= (pointsBudget - step + 1) then
							local addNodes = {}
							for id, _ in pairs(state.alloc) do
								t_insert(addNodes, build.spec.nodes[id])
							end
							for _, pn in ipairs(pathNodes) do
								if not state.alloc[pn.id] and not baseNodes[pn.id] then
									t_insert(addNodes, pn)
								end
							end
							local result = incrementalEval(addNodes)
							local newAlloc = {}
							for id, _ in pairs(state.alloc) do newAlloc[id] = true end
							for _, pn in ipairs(pathNodes) do
								if not state.alloc[pn.id] and not baseNodes[pn.id] then
									newAlloc[pn.id] = true
								end
							end
							t_insert(newStates, { alloc = newAlloc, score = result.score, result = result, lastNode = node.name })
						end
					end
				end
			end
		end

		if #newStates == 0 then
			break
		end
		table.sort(newStates, function(a, b) return a.score > b.score end)
		local kept = {}
		for i = 1, math.min(beamWidth, #newStates) do
			kept[i] = newStates[i]
		end
		states = kept
	end

	local best = states[1]
	for id, _ in pairs(build.spec.allocNodes) do
		if not best.alloc[id] and not baseNodes[id] then
			build.spec:DeallocNode(build.spec.nodes[id])
		end
	end
	for id, _ in pairs(best.alloc) do
		if not build.spec.allocNodes[id] then
			build.spec:AllocNode(build.spec.nodes[id])
		end
	end
	return evalBuild()
end

-- === Prune low-value allocated notables ===
local function pruneTree()
	local base = evalBuild()
	local baseScore = base.score
	local calcFunc = calcs.getNodeCalculator(build)
	local function incrementalEval(nodeList)
		calcFunc(nodeList)
		return objective.evaluate(objConfig)
	end

	local improved = true
	while improved do
		improved = false
		local currentNodes = {}
		for id, _ in pairs(build.spec.allocNodes) do
			t_insert(currentNodes, build.spec.nodes[id])
		end
		for i, node in ipairs(currentNodes) do
			if node.type == "Notable" and not node.ascendancyName then
				local trial = {}
				for j, n in ipairs(currentNodes) do
					if j ~= i then t_insert(trial, n) end
				end
				local res = incrementalEval(trial)
				if res.score > baseScore then
					build.spec:DeallocNode(node)
					baseScore = res.score
					improved = true
					break
				end
			end
		end
	end
	return evalBuild()
end

-- === Preserve seed skills on a fresh build ===
local function recreateSkills()
	local savedGroups = {}
	for i, group in ipairs(build.skillsTab.socketGroupList) do
		savedGroups[i] = group
	end
	build.skillsTab.socketGroupList = {}
	for _, group in ipairs(savedGroups) do
		local gemStrings = {}
		for _, gem in ipairs(group.gemList) do
			if gem.enabled then
				local count = gem.count or 1
				t_insert(gemStrings, string.format("%s %d/%d  %d", gem.nameSpec, gem.level, gem.quality, count))
			end
		end
		if #gemStrings > 0 then
			build.skillsTab:PasteSocketGroup(table.concat(gemStrings, "\n"))
			local newGroup = build.skillsTab.socketGroupList[#build.skillsTab.socketGroupList]
			if newGroup then
				newGroup.label = group.label
				newGroup.mainActiveSkill = group.mainActiveSkill
				newGroup.includeInFullDPS = group.includeInFullDPS
			end
		end
	end
	build.mainSocketGroup = seedInfo.mainSocketGroup or 1
end

-- === Support-gem optimization ===
local function buildGroupPasteString(gems)
	local lines = {}
	for _, gem in ipairs(gems) do
		if gem.enabled ~= false then
			t_insert(lines, string.format("%s %d/%d  %d", gem.name, gem.level, gem.quality, gem.count or 1))
		end
	end
	return table.concat(lines, "\n")
end

-- Replace the main skill group's gem list in-place, preserving the group's
-- identity so save/load keeps it at the same index.
local function setMainGroupGems(supports, returnOriginal)
	local idx = build.mainSocketGroup or 1
	local originalGroup = build.skillsTab.socketGroupList[idx]
	local originalGemList = originalGroup.gemList
	local originalSlotSrcList = originalGroup.slotSrcList

	local gems = { { name = seedInfo.mainGem.name, level = seedInfo.mainGem.level, quality = seedInfo.mainGem.quality, count = seedInfo.mainGem.count } }
	for _, s in ipairs(supports) do
		t_insert(gems, s)
	end

	local tempList = build.skillsTab.socketGroupList
	build.skillsTab.socketGroupList = {}
	build.skillsTab:PasteSocketGroup(buildGroupPasteString(gems))
	local newGroup = build.skillsTab.socketGroupList[1]

	build.skillsTab.socketGroupList = tempList
	build.mainSocketGroup = idx
	originalGroup.gemList = newGroup.gemList
	originalGroup.slotSrcList = newGroup.slotSrcList

	if returnOriginal then
		return originalGemList, originalSlotSrcList
	end
end

local function optimizeSupports()
	if not seedInfo.mainGem or not seedInfo.mainGem.name or seedInfo.mainGem.name == "" then
		return nil
	end

	local idx = build.mainSocketGroup or 1
	local mainGroup = build.skillsTab.socketGroupList[idx]

	local maxSupports = maxSupportsOverride or 6
	local seedSupportCount = 0
	for i = 2, #mainGroup.gemList do
		if mainGroup.gemList[i].enabled then
			seedSupportCount = seedSupportCount + 1
		end
	end
	if seedSupportCount > 0 then
		maxSupports = math.max(maxSupports, seedSupportCount)
	end

	local candidates = gemPool.getCandidates(seedInfo.mainGem.name, { max = 15 })
	if #candidates == 0 then
		return nil
	end

	-- Seed support baseline.
	local seedSupports = {}
	for i = 2, #mainGroup.gemList do
		local gem = mainGroup.gemList[i]
		if gem.enabled then
			t_insert(seedSupports, { name = gem.nameSpec, level = gem.level, quality = gem.quality, count = gem.count or 1 })
		end
	end

	local function scoreSupports(supports)
		local origGemList, origSlotSrcList = setMainGroupGems(supports, true)
		build.configTab.input.conditionBoss = true
		build.configTab.input.conditionCombat = true
		build.configTab.input.conditionEffective = true
		build.configTab:BuildModList()
		local res = evalBuild()
		-- Restore original gems so the next trial starts clean.
		mainGroup.gemList = origGemList
		mainGroup.slotSrcList = origSlotSrcList
		return res.score, res
	end

	local bestScore, bestResult = scoreSupports(seedSupports)
	local bestSupports = {}
	for _, s in ipairs(seedSupports) do t_insert(bestSupports, s) end

	-- Greedy support selection starting from empty.
	local current = {}
	for slot = 1, maxSupports do
		local localBestName = nil
		local localBestScore = bestScore
		local localBestResult = bestResult
		for _, cand in ipairs(candidates) do
			local already = false
			for _, s in ipairs(current) do
				if s.name == cand.name then
					already = true
					break
				end
			end
			if not already then
				local trial = {}
				for _, s in ipairs(current) do t_insert(trial, s) end
				t_insert(trial, { name = cand.name, level = cand.naturalMaxLevel or 20, quality = 20, count = 1 })
				local sc, res = scoreSupports(trial)
				if sc > localBestScore then
					localBestScore = sc
					localBestResult = res
					localBestName = cand.name
				end
			end
		end
		if localBestName then
			t_insert(current, { name = localBestName, level = (function()
				for _, c in ipairs(candidates) do
					if c.name == localBestName then return c.naturalMaxLevel or 20 end
				end
				return 20
			end)(), quality = 20, count = 1 })
			bestScore = localBestScore
			bestResult = localBestResult
			bestSupports = {}
			for _, s in ipairs(current) do t_insert(bestSupports, s) end
		else
			break
		end
	end

	-- Apply the best support set permanently.
	setMainGroupGems(bestSupports)
	return bestResult
end

local function candForName(candidates, name)
	for _, c in ipairs(candidates) do
		if c.name == name then return c end
	end
	return { naturalMaxLevel = 20 }
end

-- === Buff / aura / herald / mark optimization ===
local function optimizeBuffs()
	if not seedInfo.mainGem or not seedInfo.mainGem.name or seedInfo.mainGem.name == "" then
		return nil
	end

	local activeTags = gemPool.getActiveSkillTags(seedInfo.mainGem.name)
	local candidates = buffPool.getCandidates(activeTags, { focus = focus })
	if #candidates == 0 then
		return nil
	end

	-- Identify an existing separate aura/mark group or create a new one.
	local function getAuraGroup()
		for _, group in ipairs(build.skillsTab.socketGroupList) do
			if group ~= build.skillsTab.socketGroupList[build.mainSocketGroup or 1] then
				for _, gem in ipairs(group.gemList) do
					if gem.gemType == "Buff" or gem.gemType == "Mark" or gem.gemType == "Banner" then
						return group
					end
				end
			end
		end
		return nil
	end

	local auraGroup = getAuraGroup()
	local function buildAuraGroupPaste(buffGems)
		local lines = {}
		for _, gem in ipairs(buffGems) do
			t_insert(lines, string.format("%s %d/%d  %d", gem.name, gem.level, gem.quality, gem.count or 1))
		end
		return table.concat(lines, "\n")
	end

	local function applyBuffs(buffGems)
		if #buffGems == 0 then
			return
		end
		if auraGroup then
			local oldGemList = auraGroup.gemList
			local oldSlotSrcList = auraGroup.slotSrcList
			local tempList = build.skillsTab.socketGroupList
			build.skillsTab.socketGroupList = {}
			build.skillsTab:PasteSocketGroup(buildAuraGroupPaste(buffGems))
			local newGroup = build.skillsTab.socketGroupList[1]
			build.skillsTab.socketGroupList = tempList
			auraGroup.gemList = newGroup.gemList
			auraGroup.slotSrcList = newGroup.slotSrcList
			auraGroup.mainActiveSkill = 1
			auraGroup.mainActiveSkillCalcs = 1
		else
			build.skillsTab:PasteSocketGroup(buildAuraGroupPaste(buffGems))
			local newGroup = build.skillsTab.socketGroupList[#build.skillsTab.socketGroupList]
			if newGroup then
				newGroup.mainActiveSkill = 1
				newGroup.mainActiveSkillCalcs = 1
			end
		end
	end

	local function scoreBuffs(buffGems)
		local origGemList, origSlotSrcList
		if auraGroup then
			origGemList = auraGroup.gemList
			origSlotSrcList = auraGroup.slotSrcList
		end
		applyBuffs(buffGems)
		build.configTab.input.conditionBoss = true
		build.configTab.input.conditionCombat = true
		build.configTab.input.conditionEffective = true
		build.configTab:BuildModList()
		local res = evalBuild()
		-- Restore original aura group gems.
		if auraGroup and origGemList then
			auraGroup.gemList = origGemList
			auraGroup.slotSrcList = origSlotSrcList
		elseif not auraGroup and #buffGems > 0 then
			-- Remove the temporary group we appended.
			table.remove(build.skillsTab.socketGroupList)
		end
		return res.score, res
	end

	-- Build baseline from existing buff gems in the aura group.
	local current = {}
	if auraGroup then
		for _, gem in ipairs(auraGroup.gemList) do
			if gem.enabled then
				t_insert(current, { name = gem.nameSpec, level = gem.level, quality = gem.quality, count = gem.count or 1 })
			end
		end
	end

	local bestScore, bestResult = scoreBuffs(current)
	local bestBuffs = {}
	for _, b in ipairs(current) do t_insert(bestBuffs, b) end

	-- Greedy add.
	local maxBuffs = 4
	for slot = 1, maxBuffs do
		local localBestName = nil
		local localBestScore = bestScore
		local localBestResult = bestResult
		for _, cand in ipairs(candidates) do
			local already = false
			for _, b in ipairs(current) do
				if b.name == cand.name then
					already = true
					break
				end
			end
			if not already then
				local trial = {}
				for _, b in ipairs(current) do t_insert(trial, b) end
				t_insert(trial, { name = cand.name, level = cand.naturalMaxLevel or 20, quality = 20, count = 1 })
				local sc, res = scoreBuffs(trial)
				if sc > localBestScore then
					localBestScore = sc
					localBestResult = res
					localBestName = cand.name
				end
			end
		end
		if localBestName then
			t_insert(current, { name = localBestName, level = candForName(candidates, localBestName).naturalMaxLevel or 20, quality = 20, count = 1 })
			bestScore = localBestScore
			bestResult = localBestResult
			bestBuffs = {}
			for _, b in ipairs(current) do t_insert(bestBuffs, b) end
		else
			break
		end
	end

	applyBuffs(bestBuffs)
	return bestResult
end

-- === Gear improvement ===
local targetSlots = args.slots and {} or nil
if targetSlots then
	for s in args.slots:gmatch("([^,]+)") do
		targetSlots[s:gsub("^%s+", ""):gsub("%s+$", "")] = true
	end
end

local function improveGear(gearSet)
	local generatedSlots = {}
	for _, entry in ipairs(gearSet) do
		-- Skip generation for slots where the seed has a unique we want to keep.
		if keepUniques and seedUniqueSlots[entry.slot] then
			-- do not generate; will re-add original below
		else
			generatedSlots[entry.slot] = true
			build.itemsTab:CreateDisplayItemFromRaw(entry.raw)
			if build.itemsTab.displayItem then
				build.itemsTab:AddDisplayItem()
				-- Equip generated flask/charm into the target slot.
				if entry.slot:find("Flask") or entry.slot:find("Charm") then
					local newId = build.itemsTab.itemOrderList[#build.itemsTab.itemOrderList]
					if newId and build.itemsTab.slots[entry.slot] then
						build.itemsTab.slots[entry.slot].selItemId = newId
					end
				end
			end
		end
	end

	-- Re-add seed uniques we are preserving.
	for slotName, saved in pairs(seedInfo.items) do
		if keepUniques and saved.rarity == "UNIQUE" and saved.raw then
			build.itemsTab:CreateDisplayItemFromRaw(saved.raw)
			if build.itemsTab.displayItem then
				build.itemsTab:AddDisplayItem()
			end
		end
	end

	-- Keep original items for slots we didn't target or generate.
	for slotName, saved in pairs(seedInfo.items) do
		local isTarget = not targetSlots or targetSlots[slotName]
		if not generatedSlots[slotName] and isTarget and saved.raw then
			-- Avoid duplicating uniques we already re-added above.
			if not (keepUniques and saved.rarity == "UNIQUE") then
				build.itemsTab:CreateDisplayItemFromRaw(saved.raw)
				if build.itemsTab.displayItem then
					build.itemsTab:AddDisplayItem()
				end
			end
		end
	end
end

-- === Main improvement loop ===
local bestOverall = { score = -math.huge }
local allResults = {}
local gearSets = {}

for i = 1, gearSetCount do
	gearSets[i] = itemPool.generateSet({ quality = 20, affixCount = 5 })
end

for i = 1, gearSetCount do
	print(string.format("=== Gear set %d/%d ===", i, gearSetCount))
	local ok, result = pcall(function()
	api.loadBuildXML(xmlText, sourceName)
	build.characterLevel = charLevel
	build.characterLevelAutoMode = false

	-- Reset item state before applying new gear
	build.itemsTab.items = {}
	build.itemsTab.itemOrderList = {}
	for _, slot in pairs(build.itemsTab.slots) do
		slot.selItemId = 0
		if slot.active then slot.active = false end
	end

		improveGear(gearSets[i])
		if not optimizeGems then
			recreateSkills()
		else
			optimizeSupports()
		end
		optimizeBuffs()

		build.configTab.input.conditionBoss = true
		build.configTab.input.conditionCombat = true
		build.configTab.input.conditionEffective = true
		build.configTab:BuildModList()

		api.saveBuildXML("__improve_template__.xml")
		api.loadBuildXML(io.open("__improve_template__.xml"):read("*a"), "__improve_template__.xml")

		local candidateNodes = getCandidateNodes()
		local treeResult = optimizeTree(candidateNodes, maxPoints)
		return pruneTree()
	end)

	if ok and result then
		local out = result.raw
		print(string.format("  DPS %.2f | Life %.0f | EHP %.2f | Score %.2f | Valid %s",
			effectiveDPS(out), out.Life or 0, out.TotalEHP or 0, result.score, tostring(result.valid)))
		for _, r in ipairs(result.reasons) do
			print("    ! " .. r)
		end
		t_insert(allResults, result)
		if result.score > bestOverall.score then
			bestOverall = result
			api.saveBuildXML(outputPath)
			print("  *** New best, saved to " .. outputPath)
		end
	else
		print("  FAILED: " .. tostring(result))
	end
end

os.remove("__improve_template__.xml")

if bestOverall.score > -math.huge then
	local out = bestOverall.raw
	local improvedDPS = effectiveDPS(out)
	print("")
	print(string.format("Best improved build: DPS %.2f | Life %.0f | EHP %.2f | Score %.2f | Valid %s",
		improvedDPS, out.Life or 0, out.TotalEHP or 0, bestOverall.score, tostring(bestOverall.valid)))
	print("Saved to " .. outputPath)
	print("")
	print("=== Improvement summary ===")
	print(string.format("TotalDPS: %.2f -> %.2f (%.1f%%)", seedInfo.baseDPS or 0, improvedDPS,
		(seedInfo.baseDPS and seedInfo.baseDPS > 0) and ((improvedDPS - seedInfo.baseDPS) / seedInfo.baseDPS * 100) or 0))
	print(string.format("Life: %.0f -> %.0f (%.1f%%)", seedInfo.baseLife or 0, out.Life or 0,
		(seedInfo.baseLife and seedInfo.baseLife > 0) and ((out.Life - seedInfo.baseLife) / seedInfo.baseLife * 100) or 0))
	print(string.format("TotalEHP: %.2f -> %.2f (%.1f%%)", seedInfo.baseEHP or 0, out.TotalEHP or 0,
		(seedInfo.baseEHP and seedInfo.baseEHP > 0) and ((out.TotalEHP - seedInfo.baseEHP) / seedInfo.baseEHP * 100) or 0))
	if not bestOverall.valid then
		print("Build is not valid; reasons:")
		for _, r in ipairs(bestOverall.reasons) do print("  - " .. r) end
	end
else
	print("No valid improved build found.")
end
