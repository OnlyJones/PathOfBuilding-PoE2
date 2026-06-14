-- Path of Building: PoE2 — Support Gem Pool Generator
--
-- Provides archetype-aware support-gem selection for a given active skill.
-- Loads gem data from src/Data/Gems.lua and filters supports by compatibility.

local M = {}

local t_insert = table.insert

-- Tags that make a support exclusive to a specific active-skill type.
-- If the active skill lacks one of these, we skip the support.
M.exclusiveTags = {
	melee = true,
	spell = true,
	minion = true,
	totem = true,
	warcry = true,
	trigger = true,
	aura = true,
	curse = true,
	mine = true,
	trap = true,
	channelled = true,
	blink = true,
	banner = true,
	mark = true,
	ammunition = true,
}

-- Generic tags that do not restrict compatibility by themselves.
M.genericTags = {
	support = true,
	attack = true,
	projectile = true,
	area = true,
	lightning = true,
	cold = true,
	fire = true,
	physical = true,
	chaos = true,
	elemental = true,
	duration = true,
	crit = true,
	life = true,
	mana = true,
	conditional = true,
	payoff = true,
}

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

function M.getActiveSkillTags(name)
	local gem = M.getGemByName(name)
	if gem and gem.tags then
		return gem.tags
	end
	return {}
end

-- Strip tier suffix " I", " II", " III", " IV" from a support name.
function M.getSupportFamily(name)
	return name:gsub("%s+[IV]+$", ""):gsub("%s+I$", ""):gsub("%s+II$", ""):gsub("%s+III$", ""):gsub("%s+IV$", "")
end

-- Collect all support gems, keeping only the highest tier per family.
function M.getUniqueSupports()
	local gems = M.loadGems()
	local families = {}
	for _, gem in pairs(gems) do
		if gem.gemType == "Support" and gem.name then
			local family = M.getSupportFamily(gem.name)
			local existing = families[family]
			local keep = false
			if not existing then
				keep = true
			else
				-- Prefer higher naturalMaxLevel, then higher Tier string.
				local existingTier = existing.name:match("%s+([IV]+)$") or ""
				local newTier = gem.name:match("%s+([IV]+)$") or ""
				local function tierValue(s)
					if s == "IV" then return 4
					elseif s == "III" then return 3
					elseif s == "II" then return 2
					elseif s == "I" then return 1
					else return 0 end
				end
				if (gem.naturalMaxLevel or 0) > (existing.naturalMaxLevel or 0) then
					keep = true
				elseif (gem.naturalMaxLevel or 0) == (existing.naturalMaxLevel or 0) and tierValue(newTier) > tierValue(existingTier) then
					keep = true
				end
			end
			if keep then
				families[family] = gem
			end
		end
	end
	local list = {}
	for _, gem in pairs(families) do
		t_insert(list, gem)
	end
	return list
end

function M.isCompatible(supportTags, activeTags)
	for tag, _ in pairs(supportTags) do
		if M.exclusiveTags[tag] and not activeTags[tag] then
			return false
		end
	end
	-- If the support only has generic/exclusive tags, include it if no exclusive mismatch.
	return true
end

function M.scoreSupportEstimate(gem, activeTags)
	local score = 0
	local name = gem.name:lower()
	local tags = gem.tags or {}

	-- Damage keywords
	if name:find("damage") or name:find("penetration") or name:find("exposure") or name:find("more") then
		score = score + 3
	end
	if tags.projectile and activeTags.projectile then score = score + 2 end
	if tags.lightning and activeTags.lightning then score = score + 3 end
	if tags.cold and activeTags.cold then score = score + 2 end
	if tags.fire and activeTags.fire then score = score + 2 end
	if tags.elemental and activeTags.elemental then score = score + 2 end
	if tags.spell and activeTags.spell then score = score + 2 end
	if tags.attack and activeTags.attack then score = score + 1 end
	if name:find("attack speed") or name:find("rapid") then score = score + 3 end
	if name:find("cast speed") or name:find("rapid casting") then score = score + 3 end
	if name:find("critical") or name:find("crit") then score = score + 2 end
	if name:find("chain") or name:find("pierce") or name:find("fork") then score = score + 2 end
	if name:find("additional projectile") or name:find("multishot") then score = score + 2 end
	if name:find("spell level") or name:find("level of all spell") then score = score + 4 end
	if name:find("lightning mastery") then score = score + 4 end
	if name:find("culling") then score = score + 1 end
	if name:find("life leech") or name:find("mana leech") then score = score + 1 end

	return score
end

function M.getCandidates(activeSkillName, opts)
	opts = opts or {}
	local activeTags = M.getActiveSkillTags(activeSkillName)
	local supports = M.getUniqueSupports()
	local candidates = {}
	for _, gem in ipairs(supports) do
		if M.isCompatible(gem.tags or {}, activeTags) then
			t_insert(candidates, {
				name = gem.name,
				tags = gem.tags,
				reqInt = gem.reqInt or 0,
				reqDex = gem.reqDex or 0,
				reqStr = gem.reqStr or 0,
				naturalMaxLevel = gem.naturalMaxLevel or 1,
				score = M.scoreSupportEstimate(gem, activeTags),
			})
		end
	end
	table.sort(candidates, function(a, b) return a.score > b.score end)
	if opts.max then
		local trimmed = {}
		for i = 1, math.min(opts.max, #candidates) do
			trimmed[i] = candidates[i]
		end
		candidates = trimmed
	end
	return candidates, activeTags
end

-- Reconstruct a socket group paste string.
function M.buildGroupString(mainGem, supports)
	local lines = {}
	t_insert(lines, string.format("%s %d/%d  %d", mainGem.name, mainGem.level, mainGem.quality, mainGem.count or 1))
	for _, sup in ipairs(supports) do
		t_insert(lines, string.format("%s %d/%d  %d", sup.name, sup.level, sup.quality, sup.count or 1))
	end
	return table.concat(lines, "\n")
end

return M
