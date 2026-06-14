-- Path of Building: PoE2 — Aura / Buff / Mark Pool Generator
--
-- Provides archetype-aware buff selection for a given build.
-- Loads gem data from src/Data/Gems.lua and filters aura/herald/banner/mark gems.

local M = {}

local t_insert = table.insert

local gemsCache = nil

function M.loadGems()
	if gemsCache then return gemsCache end
	gemsCache = dofile("src/Data/Gems.lua") or dofile("../src/Data/Gems.lua")
	return gemsCache
end

function M.getGemByName(name)
	local gems = M.loadGems()
	for _, gem in pairs(gems) do
		if gem.name == name then
			return gem
		end
	end
	return nil
end

-- Categories of persistent buffs the optimizer can add as separate groups.
M.buffPatterns = {
	{ kind = "herald", match = function(gem) return gem.tags and gem.tags.herald end },
	{ kind = "banner", match = function(gem) return gem.tags and gem.tags.banner end },
	{ kind = "purity", match = function(gem)
		return gem.name and gem.name:find("Purity") and gem.tags and gem.tags.aura
	end },
	{ kind = "discipline", match = function(gem) return gem.name == "Discipline" end },
	{ kind = "mark", match = function(gem) return gem.gemType == "Mark" end },
}

function M.getCandidates(activeTags, opts)
	opts = opts or {}
	local gems = M.loadGems()
	local candidates = {}
	local seen = {}
	for _, gem in pairs(gems) do
		if gem.name and gem.gemType ~= "Support" then
			for _, pattern in ipairs(M.buffPatterns) do
				if pattern.match(gem) and not seen[gem.name] then
					seen[gem.name] = true
					-- Skip heralds that don't match the active-skill element.
					if pattern.kind == "herald" then
						local heraldElement = nil
						if gem.tags.lightning then heraldElement = "lightning"
						elseif gem.tags.cold then heraldElement = "cold"
						elseif gem.tags.fire then heraldElement = "fire"
						elseif gem.tags.chaos then heraldElement = "chaos"
						elseif gem.tags.physical then heraldElement = "physical" end
						if heraldElement and not activeTags[heraldElement] then
							break
						end
					end
					t_insert(candidates, {
						name = gem.name,
						kind = pattern.kind,
						reqInt = gem.reqInt or 0,
						reqDex = gem.reqDex or 0,
						reqStr = gem.reqStr or 0,
						naturalMaxLevel = gem.naturalMaxLevel or 20,
						tags = gem.tags or {},
					})
					break
				end
			end
		end
	end
	table.sort(candidates, function(a, b) return a.name < b.name end)
	return candidates
end

function M.scoreEstimate(buff, activeTags, focus)
	local score = 0
	if buff.kind == "herald" then score = score + 3 end
	if buff.kind == "mark" then score = score + 2 end
	if buff.kind == "banner" then score = score + 1 end
	if buff.kind == "discipline" then score = score + (focus == "defence" and 3 or 1) end
	if buff.kind == "purity" then score = score + 2 end
	if buff.tags.lightning and activeTags.lightning then score = score + 2 end
	if buff.tags.cold and activeTags.cold then score = score + 1 end
	if buff.tags.fire and activeTags.fire then score = score + 1 end
	return score
end

return M
