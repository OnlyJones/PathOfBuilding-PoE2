-- Path of Building: PoE2 — Constrained Lightning Arrow Optimizer
-- Usage: luajit tools/optimize_archetype.lua [options]
--   --output <file.xml>      output path (default optimized_build.xml)
--   --points <n>             passive points budget (default 90)
--   --level <n>              character level (default 90)
--   --gear-sets <n>          number of gear sets to enumerate (default 8)
--   --beam-width <n>         tree beam width (default 1 = greedy)
--   --seed <n>               random seed
--
-- Builds a Lightning Arrow Ranger/Deadeye and searches over generated gear
-- plus passive tree to maximize a configurable objective.

local args = { }
for i = 1, #arg do
	if arg[i] == "--output" then args.output = arg[i + 1] end
	if arg[i] == "--points" then args.points = tonumber(arg[i + 1]) end
	if arg[i] == "--level" then args.level = tonumber(arg[i + 1]) end
	if arg[i] == "--gear-sets" then args.gearSets = tonumber(arg[i + 1]) end
	if arg[i] == "--beam-width" then args.beamWidth = tonumber(arg[i + 1]) end
	if arg[i] == "--seed" then args.seed = tonumber(arg[i + 1]) end
end

local outputPath = args.output or "optimized_build.xml"
local maxPoints = args.points or 90
local charLevel = args.level or 90
local gearSetCount = args.gearSets or 8
local beamWidth = args.beamWidth or 1
local seed = args.seed or os.time()
math.randomseed(seed)

local t_insert = table.insert

local pob = dofile("tools/lib/pob_env.lua")
pob.bootstrap()

-- Re-seed after POB bootstrap, which may reset the RNG
math.randomseed(seed)

local api = dofile("tools/lib/build_api.lua")
local itemPool = dofile("tools/lib/adaptive_item_pool.lua")

-- Configure adaptive pool for Lightning Arrow
itemPool.configure({ mainSkill = "Lightning Arrow", level = charLevel, budget = "mid" })
local objective = dofile("tools/lib/objective.lua")

-- === Objective config tuned for Lightning Arrow ===
local objConfig = {
	weights = {
		TotalDPS = 1.0,
		FullDPS = 0.5,
		TotalEHP = 0.001,
		Life = 0.5,
	},
	gates = {
		minLife = 1200,
		minUncappedResist = 0,
		minDex = 0,
	},
	penalties = {
		resistBelowCap = 5000,
		lifeBelowMin = 100,
		attributeShortfall = 1000,
	},
}

-- === Candidate notable selection ===
-- === Curated Lightning Arrow notables (from community build analysis) ===
local curatedNotables = {
	["Clean Shot"] = true,
	["Crystal Elixir"] = true,
	["Forces of Nature"] = true,
	["Pierce the Heart"] = true,
	["Harness the Elements"] = true,
	["Honed Instincts"] = true,
	["Emboldened Avatar"] = true,
	["Master Fletching"] = true,
	["Flash Storm"] = true,
	["Gathering Winds"] = true,
	["Endless Munitions"] = true,
	["Escape Velocity"] = true,
	["Falcon Technique"] = true,
	["Primal Sundering"] = true,
	["Acceleration"] = true,
	["Wrapped Quiver"] = true,
	["Inspiring Ally"] = true,
	["Catalysis"] = true,
	["Maiming Strike"] = true,
	["Projectile Proximity Specialisation"] = true,
	["Proficiency"] = true,
	["Lightning Rod"] = true,
	["The Spring Hare"] = true,
	["Death from Afar"] = true,
}
local keywords = { "lightning", "bow", "projectile", "critical", "life", "evasion", "resist", "attack speed", "damage", "accuracy", "speed", "dexterity", "intelligence", "strength", "attribute" }
local function getCandidateNodes()
	local nodes = { }
	for id, node in pairs(build.spec.nodes) do
		if node.type == "Notable" and not build.spec.allocNodes[id] then
			-- Prefer curated notables; fall back to keyword matching
			local name = node.name or ""
			if curatedNotables[name] then
				t_insert(nodes, node)
			else
				local nameL = name:lower()
				local desc = (node.dn or ""):lower()
				local txt = nameL .. " " .. desc
				for _, kw in ipairs(keywords) do
					if txt:find(kw, 1, true) then
						t_insert(nodes, node)
						break
					end
				end
			end
		end
	end
	return nodes
end

-- === Evaluate current build state ===
local function evalBuild()
	build.buildFlag = true
	runCallback("OnFrame")
	return objective.evaluate(objConfig)
end

-- === Greedy / beam tree optimization ===
local function optimizeTree(candidateNodes, pointsBudget)
	local base = evalBuild()
	local baseNodes = {}
	for id, _ in pairs(build.spec.allocNodes) do
		baseNodes[id] = true
	end

	-- Use POB's fast incremental node calculator
	local calcs = LoadModule("Modules/Calcs")
	local calcFunc = calcs.getNodeCalculator(build)

	local function incrementalEval(nodeList)
		-- nodeList is array of nodes to add to the *base* build
		local out = calcFunc(nodeList)
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
							-- Collect all nodes in this state + new path
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

	-- Apply best state's tree via real allocation
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

-- === Build a single gear set and optimize its tree ===
local function buildAndOptimize(gearSet)
	newBuild()
	-- Headless newBuild reuses the build object; clear old items so gear sets don't leak
	build.itemsTab.items = { }
	build.itemsTab.itemOrderList = { }
	for _, slot in pairs(build.itemsTab.slots) do
		slot.selItemId = 0
		if slot.active then slot.active = false end
	end

	build.spec:SelectClass(2) -- Ranger
	build.spec:SelectAscendClass(1) -- Deadeye
	build.className = build.spec.curClassName
	build.ascendClassName = build.spec.curAscendClassName
	build.characterLevel = charLevel
	build.characterLevelAutoMode = false

	for _, entry in ipairs(gearSet) do
		build.itemsTab:CreateDisplayItemFromRaw(entry.raw)
		if build.itemsTab.displayItem then
			build.itemsTab:AddDisplayItem()
		end
	end

	build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0  1\nAdded Lightning Damage 20/0  1\nElemental Damage with Attacks 20/0  1\nRapid Attacks 20/0  1\nChain 20/0  1\nStoicism 20/0  1\nElemental Armament 20/0  1")
	build.skillsTab:PasteSocketGroup("Herald of Thunder 20/0  1")
	build.mainSocketGroup = 1

	build.configTab.input.conditionBoss = true
	build.configTab.input.conditionCombat = true
	build.configTab.input.conditionEffective = true
	build.configTab:BuildModList()

	build.buildFlag = true
	runCallback("OnFrame")

	api.saveBuildXML("__opt_template__.xml")
	local f = io.open("__opt_template__.xml", "r")
	local templateXML = f:read("*a")
	f:close()
	api.loadBuildXML(templateXML, "__opt_template__.xml")

	local candidateNodes = getCandidateNodes()
	local result = optimizeTree(candidateNodes, maxPoints)
	return result
end

-- === Main gear-set search ===
local bestOverall = { score = -math.huge }
local allResults = { }

-- Pre-generate all gear sets before POB resets the RNG
local gearSets = { }
for i = 1, gearSetCount do
	gearSets[i] = itemPool.generateSet({ quality = 20, affixCount = 4 })
end

for i = 1, gearSetCount do
	local gearSet = gearSets[i]
	print(string.format("=== Gear set %d/%d ===", i, gearSetCount))
	local ok, result = pcall(function() return buildAndOptimize(gearSet) end)
	if ok and result then
		local out = result.raw
		print(string.format("  DPS %.2f | Life %.0f | EHP %.2f | Score %.2f | Valid %s",
			out.TotalDPS or 0, out.Life or 0, out.TotalEHP or 0, result.score, tostring(result.valid)))
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

-- Save best build
if bestOverall.score > -math.huge then
	local out = bestOverall.raw
	print("")
	print(string.format("Best build: DPS %.2f | Life %.0f | EHP %.2f | Score %.2f | Valid %s",
		out.TotalDPS or 0, out.Life or 0, out.TotalEHP or 0, bestOverall.score, tostring(bestOverall.valid)))
	print("Saved to " .. outputPath)
else
	print("No valid build found.")
end

os.remove("__opt_template__.xml")
