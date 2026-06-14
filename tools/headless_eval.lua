-- Path of Building: PoE2 — Headless Build Evaluator
-- Usage: luajit tools/headless_eval.lua <path/to/build.xml>
--
-- Loads a PoB2 build XML headlessly and prints offence/defence metrics.

local buildPath = arg[1]
if not buildPath then
	print("Usage: luajit tools/headless_eval.lua <path/to/build.xml>")
	os.exit(1)
end

local pob = dofile("tools/lib/pob_env.lua")
pob.bootstrap()

local function readFile(path)
	local f, err = io.open(path, "r")
	if not f then
		error("Cannot open build file: " .. tostring(path) .. " (" .. tostring(err) .. ")")
	end
	local content = f:read("*a")
	f:close()
	return content
end

local function fmtNumber(n)
	if type(n) ~= "number" then
		return tostring(n)
	end
	if n == math.huge then
		return "inf"
	elseif n == -math.huge then
		return "-inf"
	end
	if math.abs(n) >= 1000000 then
		return string.format("%.2fM", n / 1000000)
	elseif math.abs(n) >= 1000 then
		return string.format("%.2fk", n / 1000)
	elseif math.abs(n) >= 1 then
		return string.format("%.2f", n)
	else
		return string.format("%.4f", n)
	end
end

local xmlText = readFile(buildPath)
local api = dofile("tools/lib/build_api.lua")
api.loadBuildXML(xmlText, buildPath)

local out = build.calcsTab.mainOutput
local stats = {
	{"TotalDPS", out.TotalDPS},
	{"FullDPS", out.FullDPS},
	{"AverageDamage", out.AverageDamage},
	{"Speed", out.Speed},
	{"CritChance", out.CritChance},
	{"TotalEHP", out.TotalEHP},
	{"Life", out.Life},
	{"LifeUnreserved", out.LifeUnreserved},
	{"ManaUnreserved", out.ManaUnreserved},
	{"EnergyShield", out.EnergyShield},
	{"FireResist", out.FireResist},
	{"ColdResist", out.ColdResist},
	{"LightningResist", out.LightningResist},
	{"ChaosResist", out.ChaosResist},
	{"Armour", out.Armour},
	{"Evasion", out.Evasion},
}

print("=== PoB2 Headless Evaluation ===")
print("Build: " .. buildPath)
print("Class: " .. (build.spec.curClassName or "?") .. " / " .. (build.spec.curAscendClassName or "?"))
print("")
for _, pair in ipairs(stats) do
	print(string.format("%-18s %s", pair[1] .. ":", fmtNumber(pair[2])))
end
print("=== End ===")
