-- Path of Building: PoE2 — Build Comparer
-- Usage: luajit tools/compare_builds.lua <build1.xml|url> <build2.xml|url> [options]
--
-- Compares two PoB2 builds side-by-side and reports offence/defence deltas.

local args = {}
for i = 1, #arg do
	if arg[i] == "--config" then args.config = arg[i + 1] end
end

local inputA = arg[1]
local inputB = arg[2]
if not inputA or not inputB then
	print("Usage: luajit tools/compare_builds.lua <build1.xml|url> <build2.xml|url> [--config boss|mapping]")
	os.exit(1)
end

local pob = dofile("tools/lib/pob_env.lua")
pob.bootstrap()

local api = dofile("tools/lib/build_api.lua")
local share = dofile("tools/lib/share_code.lua")

local function loadInput(input)
	local xmlText
	if input:match("^https?://") or input:match("^%s*[a-zA-Z0-9]+%.[a-zA-Z]") then
		local code = input:gsub("^%s+", ""):gsub("%s+$", "")
		if code:match("^https?://") then
			xmlText = share.decodeURL(code)
		else
			xmlText = share.decodeInput(code)
		end
	else
		local f, err = io.open(input, "r")
		if not f then
			error("Cannot open " .. input .. ": " .. tostring(err))
		end
		xmlText = f:read("*a")
		f:close()
	end
	api.loadBuildXML(xmlText, input)

	if args.config == "boss" then
		build.configTab.input.conditionBoss = true
		build.configTab.input.conditionCombat = true
		build.configTab.input.conditionEffective = true
		build.configTab:BuildModList()
	end

	build.buildFlag = true
	runCallback("OnFrame")
	return build.calcsTab.mainOutput
end

local metrics = {
	"TotalDPS", "FullDPS", "AverageDamage", "Speed", "CritChance", "CritMultiplier",
	"Life", "LifeUnreserved", "TotalEHP", "Evasion", "Armour", "EnergyShield",
	"FireResist", "ColdResist", "LightningResist", "ChaosResist",
	"Str", "Dex", "Int", "ReqStr", "ReqDex", "ReqInt",
}

local function fmt(name, val)
	if type(val) ~= "number" then
		return tostring(val)
	end
	if name:match("Resist") or name:match("Percent") then
		return string.format("%.0f", val)
	end
	return string.format("%.2f", val)
end

local outA = loadInput(inputA)
local outB = loadInput(inputB)

print(string.format("%-20s  %20s  %20s  %12s", "Metric", inputA, inputB, "Delta"))
print(string.rep("=", 80))
for _, m in ipairs(metrics) do
	local a = outA[m] or 0
	local b = outB[m] or 0
	local delta = b - a
	local deltaPct = (a ~= 0) and (delta / a * 100) or 0
	print(string.format("%-20s  %20s  %20s  %+10.1f%%", m, fmt(m, a), fmt(m, b), deltaPct))
end
