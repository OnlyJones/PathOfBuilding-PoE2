-- Path of Building: PoE2 — Build Objective / Scoring Library
--
-- Provides a configurable objective function and hard requirement gates
-- for build optimization.

local M = {}
local t_insert = table.insert

-- Default objective tuned for Lightning Arrow mid-budget.
-- Adjust weights based on archetype and preference.
M.defaultConfig = {
	weights = {
		TotalDPS = 1.0,
		FullDPS = 0.5,
		AverageDamage = 0.3,
		Speed = 0.0,
		CritChance = 0.0,
		TotalEHP = 0.003,
		Life = 1.0,
		Evasion = 0.002,
		Armour = 0.0002,
		EnergyShield = 0.0003,
	},
	gates = {
		minLife = 1500,
		minEHP = nil,
		minUncappedResist = 0,
		minStr = 0,
		minDex = 0,
		minInt = 0,
		maxManaReservedPercent = 100,
	},
	penalties = {
		resistBelowCap = 10000,
		lifeBelowMin = 100,
		attributeShortfall = 1000,
	},
}

function M.evaluate(config)
	config = config or M.defaultConfig
	local out = build.calcsTab.mainOutput
	if not out then
		return { valid = false, score = -math.huge, reasons = { "no calc output" } }
	end

	local reasons = { }
	local penalty = 0

	-- Attribute requirement gates
	local function attrGate(name, reqName, minName)
		local have = out[name] or 0
		local need = out[reqName] or 0
		local minVal = config.gates[minName] or 0
		local required = math.max(need, minVal)
		if have < required then
			local short = required - have
			t_insert(reasons, string.format("%s shortfall: %d/%d", name, have, required))
			penalty = penalty + short * config.penalties.attributeShortfall
		end
	end
	attrGate("Str", "ReqStr", "minStr")
	attrGate("Dex", "ReqDex", "minDex")
	attrGate("Int", "ReqInt", "minInt")

	-- Resistance gates (uncapped values)
	local resistNames = { "FireResist", "ColdResist", "LightningResist", "ChaosResist" }
	for _, r in ipairs(resistNames) do
		local val = out[r] or -60
		if val < config.gates.minUncappedResist then
			local short = config.gates.minUncappedResist - val
			t_insert(reasons, string.format("%s below cap: %.0f", r, val))
			penalty = penalty + short * config.penalties.resistBelowCap
		end
	end

	-- Life gate
	local life = out.Life or 0
	if life < config.gates.minLife then
		local short = config.gates.minLife - life
		t_insert(reasons, string.format("Life below gate: %.0f/%.0f", life, config.gates.minLife))
		penalty = penalty + short * config.penalties.lifeBelowMin
	end

	-- EHP floor gate
	if config.gates.minEHP then
		local ehp = out.TotalEHP or 0
		if ehp < config.gates.minEHP then
			local short = config.gates.minEHP - ehp
			t_insert(reasons, string.format("EHP below gate: %.0f/%.0f", ehp, config.gates.minEHP))
			penalty = penalty + short * 100
		end
	end

	local lifeUnres = out.LifeUnreserved
	if lifeUnres and lifeUnres < 0 then
		t_insert(reasons, "Negative life reservation")
		penalty = penalty + 100000
	end
	local manaUnres = out.ManaUnreserved
	if manaUnres and manaUnres < 0 then
		t_insert(reasons, "Negative mana reservation")
		penalty = penalty + 100000
	end

	-- Weighted score
	local score = 0
	for metric, weight in pairs(config.weights) do
		local val = out[metric]
		if type(val) == "number" then
			score = score + val * weight
		end
	end

	-- Fallback primary-damage metric for archetypes where TotalDPS is not populated.
	local primaryDPS = out.TotalDPS or 0
	if primaryDPS <= 0 then
		local fallback = out.FullDPS or 0
		if fallback <= 0 then
			fallback = (out.AverageDamage or 0) * (out.Speed or 0)
		end
		if fallback <= 0 and out.Minion then
			fallback = out.Minion.TotalDPS or 0
			if fallback <= 0 then
				fallback = (out.Minion.AverageDamage or 0) * (out.Minion.Speed or 0)
			end
		end
		if fallback > 0 then
			score = score + fallback * (config.weights.TotalDPS or 1.0)
		end
	end

	score = score - penalty

	return {
		valid = #reasons == 0,
		score = score,
		penalty = penalty,
		reasons = reasons,
		raw = out,
	}
end

return M
