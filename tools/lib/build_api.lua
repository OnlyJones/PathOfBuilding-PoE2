-- Path of Building: PoE2 — Headless Build API Helpers
--
-- Workarounds for headless mode quirks (e.g. savers cleared after init).

local M = {}
local t_insert = table.insert

local xml = dofile("runtime/lua/xml.lua")

local function reconstructSavers(build)
	if not build.savers then
		build.savers = {
			["Config"] = build.configTab,
			["Notes"] = build.notesTab,
			["Party"] = build.partyTab,
			["Tree"] = build.treeTab,
			["TreeView"] = build.treeTab.viewer,
			["Items"] = build.itemsTab,
			["Skills"] = build.skillsTab,
			["Calcs"] = build.calcsTab,
			["Import"] = build.importTab,
		}
	end
	return build.savers
end

-- Robustly load a PoB2 XML in headless mode.
-- This mirrors BuildMode:Init's loading sequence but avoids UI dependencies.
function M.loadBuildXML(xmlText, fileName)
	local dbXML, errMsg = xml.ParseXML(xmlText)
	if errMsg then
		error("XML parse error: " .. errMsg)
	end
	if not dbXML[1] or dbXML[1].elem ~= "PathOfBuilding2" then
		error("Invalid build XML: missing PathOfBuilding2 root")
	end

	-- Reset build state to a clean slate
	newBuild()

	local savers = reconstructSavers(build)
	build.xmlSectionList = { }

	-- Load Build metadata first
	for _, node in ipairs(dbXML[1]) do
		if type(node) == "table" and node.elem == "Build" then
			build:Load(node, fileName)
			break
		end
	end

	-- Collect other sections
	for _, node in ipairs(dbXML[1]) do
		if type(node) == "table" then
			t_insert(build.xmlSectionList, node)
		end
	end

	-- Defer passive trees until after items/skills so jewels resolve correctly
	local deferredPassiveTrees = { }
	for _, node in ipairs(build.xmlSectionList) do
		local saver = savers[node.elem] or build.legacyLoaders and build.legacyLoaders[node.elem]
		if saver then
			if saver == build.treeTab then
				t_insert(deferredPassiveTrees, node)
			else
				saver:Load(node, fileName)
			end
		end
	end
	for _, node in ipairs(deferredPassiveTrees) do
		build.treeTab:Load(node, fileName)
	end
	for _, saver in pairs(savers) do
		if saver.PostLoad then
			saver:PostLoad()
		end
	end

	build.buildFlag = true
	runCallback("OnFrame")

	return build
end

function M.saveBuildXML(fileName)
	local savers = reconstructSavers(build)
	if not build.extraSaveStats then
		build.displayStats, build.minionDisplayStats, build.extraSaveStats = LoadModule("Modules/BuildDisplayStats")
	end
	local xmlText = build:SaveDB(fileName)
	if not xmlText then
		error("Failed to generate build XML")
	end
	local f, err = io.open(fileName, "w")
	if not f then
		error("Cannot write " .. fileName .. ": " .. tostring(err))
	end
	f:write(xmlText)
	f:close()
end

function M.getBuildMetrics()
	local out = build.calcsTab.mainOutput
	return {
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
	}
end

return M
