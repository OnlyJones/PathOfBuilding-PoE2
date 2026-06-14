-- Path of Building: PoE2 — Test Build Generator
-- Usage: luajit tools/generate_test_build.lua <output.xml>
--
-- Creates a minimal Lightning Arrow test build and saves it as PoB2 XML.

local outputPath = arg[1] or "test_build.xml"

local pob = dofile("tools/lib/pob_env.lua")
pob.bootstrap()

newBuild()

-- Ranger / Deadeye for Lightning Arrow
build.spec:SelectClass(2) -- Ranger
build.spec:SelectAscendClass(1) -- Deadeye
build.className = build.spec.curClassName
build.ascendClassName = build.spec.curAscendClassName

-- Equip a crude bow
build.itemsTab:CreateDisplayItemFromRaw("New Item\nCrude Bow\nQuality: 0")
build.itemsTab:AddDisplayItem()

-- Add Lightning Arrow
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0  1")
build.mainSocketGroup = 1

-- Default combat config for sensible numbers
build.configTab.input.conditionBoss = true
build.configTab.input.conditionCombat = true
build.configTab.input.conditionEffective = true
build.configTab:BuildModList()

build.buildFlag = true
runCallback("OnFrame")

-- Reconstruct savers because headless init clears them
local api = dofile("tools/lib/build_api.lua")
api.saveBuildXML(outputPath)

print("Saved test build to " .. outputPath)
print("TotalDPS:", build.calcsTab.mainOutput.TotalDPS)
print("Life:", build.calcsTab.mainOutput.Life)
print("TotalEHP:", build.calcsTab.mainOutput.TotalEHP)
