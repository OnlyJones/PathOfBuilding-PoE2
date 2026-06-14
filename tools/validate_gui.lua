-- Path of Building: PoE2 — GUI Validation Helper
-- Usage: luajit tools/validate_gui.lua <build.xml>
--
-- Loads a build headlessly, prints key metrics, and describes the GUI
-- comparison protocol.

local buildPath = arg[1]
if not buildPath then
	print("Usage: luajit tools/validate_gui.lua <build.xml>")
	os.exit(1)
end

local pob = dofile("tools/lib/pob_env.lua")
pob.bootstrap()

local api = dofile("tools/lib/build_api.lua")

local f, err = io.open(buildPath, "r")
if not f then
	error("Cannot open " .. buildPath .. ": " .. tostring(err))
end
local xml = f:read("*a")
f:close()

api.loadBuildXML(xml, buildPath)
local out = build.calcsTab.mainOutput

print("=== Headless metrics for GUI validation ===")
print("Build: " .. buildPath)
print("Class: " .. (build.spec.curClassName or "?") .. " / " .. (build.spec.curAscendClassName or "?"))
print("Level: " .. build.characterLevel)
print("")
print(string.format("%-20s %.4f", "TotalDPS:", out.TotalDPS or 0))
print(string.format("%-20s %.4f", "FullDPS:", out.FullDPS or 0))
print(string.format("%-20s %.4f", "AverageDamage:", out.AverageDamage or 0))
print(string.format("%-20s %.4f", "Speed:", out.Speed or 0))
print(string.format("%-20s %.4f", "CritChance:", out.CritChance or 0))
print(string.format("%-20s %.4f", "TotalEHP:", out.TotalEHP or 0))
print(string.format("%-20s %.4f", "Life:", out.Life or 0))
print(string.format("%-20s %.4f", "LifeUnreserved:", out.LifeUnreserved or 0))
print(string.format("%-20s %.4f", "ManaUnreserved:", out.ManaUnreserved or 0))
print(string.format("%-20s %.4f", "EnergyShield:", out.EnergyShield or 0))
print(string.format("%-20s %.4f", "FireResist:", out.FireResist or 0))
print(string.format("%-20s %.4f", "ColdResist:", out.ColdResist or 0))
print(string.format("%-20s %.4f", "LightningResist:", out.LightningResist or 0))
print(string.format("%-20s %.4f", "ChaosResist:", out.ChaosResist or 0))
print(string.format("%-20s %.4f", "Armour:", out.Armour or 0))
print(string.format("%-20s %.4f", "Evasion:", out.Evasion or 0))
print("")
print("=== GUI validation protocol ===")
print("1. Open runtime/Path of Building-PoE2.exe")
print("2. File -> Open, select: " .. buildPath)
print("3. Switch to the Calcs tab")
print("4. Set the same config flags as the build (boss, combat, effective)")
print("5. Compare the above headless values to the GUI Calcs tab")
print("6. Acceptable tolerance: DPS within 1%, defences within rounding error")
print("7. If values diverge, check that config flags and main skill are identical")
