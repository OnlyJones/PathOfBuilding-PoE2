-- Path of Building: PoE2 — Item Pool Generator
--
-- Generates raw PoB item strings for Lightning Arrow mid-budget optimization.
-- Items are generated as strings so they can be loaded via save/reload, which
-- is required for POB to apply item mods correctly in headless mode.

local M = {}

local t_insert = table.insert

-- Helpers
local function fmtRange(min, max)
	if min == max then
		return tostring(min)
	end
	return string.format("(%d-%d)", min, max)
end

local function randomRoll(min, max)
	return math.random(min, max)
end

local function fmtRoll(min, max)
	local a = randomRoll(min, max)
	local b = randomRoll(min, max)
	return fmtRange(math.min(a, b), math.max(a, b))
end

-- === Bases by slot ===
M.bases = {
	weapon = { "Gemini Bow", "Dualstring Bow", "Recurve Bow" },
	quiver = { "Primed Quiver", "Broadhead Quiver" },
	helmet = { "Avian Mask", "Face Mask" },
	body = { "Slipstrike Vest", "Hexer's Robe", "Bone Raiment" },
	gloves = { "Torn Gloves", "Ringmail Gauntlets", "Layered Gauntlets" },
	boots = { "Charmed Shoes", "Mail Sabatons", "Secured Leggings" },
	belt = { "Utility Belt", "Wide Belt", "Long Belt" },
	ring = { "Gold Ring", "Ruby Ring", "Topaz Ring", "Sapphire Ring", "Amethyst Ring" },
	amulet = { "Bloodstone Amulet", "Jade Amulet", "Lapis Amulet" },
}

-- === Unique items relevant to Lightning Arrow ===
M.uniques = {
	weapon = {
		[[Rarity: UNIQUE
Death's Harp
Dualstring Bow
Quality: 20
Implicits: 1
+50% Surpassing chance to fire an additional Arrow
+(20-25)% to Critical Damage Bonus
Bow Attacks fire 3 additional Arrows
Gain (20-30) Life per enemy killed
Gain (12-18) Mana per enemy killed]],
		[[Rarity: UNIQUE
Quill Rain
Shortbow
Quality: 20
100% increased Attack Speed
+(10-20) to Dexterity
(50-100)% increased Arrow Speed
40% less Attack Damage]],
		[[Rarity: UNIQUE
Splinterheart
Recurve Bow
Quality: 20
(120-160)% increased Physical Damage
+(50-70) to Accuracy Rating
(20-30)% increased Projectile Speed
Projectiles Split towards +2 targets]],
	},
	body = {
		[[Rarity: UNIQUE
Tabula Rasa
Simple Robe
Quality: 20
Sockets: W-W-W-W-W-W
Has 6 Linked Sockets]],
	},
	gloves = {
		[[Rarity: UNIQUE
Painter's Servant
Torn Gloves
Quality: 0
Implicits: 1
{enchant}20% increased Attack Speed
(30-40)% increased Damage with Hits against Chilled Enemies
+(30-40) to maximum Life
+(20-30)% to Cold Resistance]],
	},
}

-- === Rare item affix pools ===
M.affixes = {
	weapon = {
		{ weight = 18, text = function() return "Adds " .. fmtRoll(30, 70) .. " to " .. fmtRoll(120, 260) .. " Lightning Damage" end },
		{ weight = 10, text = function() return "Adds " .. fmtRoll(20, 50) .. " to " .. fmtRoll(80, 180) .. " Cold Damage" end },
		{ weight = 10, text = function() return "Adds " .. fmtRoll(20, 50) .. " to " .. fmtRoll(80, 180) .. " Fire Damage" end },
		{ weight = 14, text = function() return (randomRoll(80, 160)) .. "% increased Elemental Damage" end },
		{ weight = 12, text = function() return (randomRoll(25, 45)) .. "% increased Attack Speed" end },
		{ weight = 10, text = function() return "+" .. randomRoll(3, 5) .. " to Level of all Attack Skills" end },
		{ weight = 8, text = function() return "+" .. randomRoll(1, 3) .. "% to Critical Hit Chance" end },
		{ weight = 8, text = function() return "+" .. randomRoll(25, 70) .. "% to Critical Damage Bonus" end },
		{ weight = 6, text = function() return "Bow Attacks fire an additional Arrow" end },
		{ weight = 5, text = function() return "+" .. randomRoll(20, 50) .. " to Dexterity" end },
	},
	quiver = {
		{ weight = 12, text = function() return "Adds " .. fmtRoll(5, 20) .. " to " .. fmtRoll(25, 75) .. " Lightning Damage to Attacks" end },
		{ weight = 10, text = function() return (randomRoll(30, 80)) .. "% increased Elemental Damage with Attacks" end },
		{ weight = 8, text = function() return (randomRoll(10, 25)) .. "% increased Attack Speed" end },
		{ weight = 6, text = function() return "+" .. randomRoll(1, 3) .. "% to Critical Hit Chance" end },
		{ weight = 5, text = function() return "+" .. randomRoll(15, 35) .. "% to Critical Damage Bonus" end },
		{ weight = 4, text = function() return "Projectiles Pierce an additional Target" end },
		{ weight = 4, text = function() return "+" .. randomRoll(20, 50) .. " to Dexterity" end },
	},
	gloves = {
		{ weight = 10, text = function() return "Adds " .. fmtRoll(5, 15) .. " to " .. fmtRoll(20, 55) .. " Lightning Damage to Attacks" end },
		{ weight = 9, text = function() return (randomRoll(15, 35)) .. "% increased Attack Speed" end },
		{ weight = 9, text = function() return "+" .. randomRoll(50, 110) .. " to maximum Life" end },
		{ weight = 6, text = function() return "+" .. randomRoll(20, 45) .. "% to Lightning Resistance" end },
		{ weight = 5, text = function() return "+" .. randomRoll(20, 45) .. "% to Fire Resistance" end },
		{ weight = 5, text = function() return "+" .. randomRoll(20, 45) .. "% to Cold Resistance" end },
		{ weight = 4, text = function() return "+" .. randomRoll(15, 35) .. " to Dexterity" end },
		{ weight = 3, text = function() return "+" .. randomRoll(10, 30) .. " to Intelligence" end },
	},
	helmet = {
		{ weight = 10, text = function() return "+" .. randomRoll(60, 130) .. " to maximum Life" end },
		{ weight = 7, text = function() return "+" .. randomRoll(20, 45) .. "% to Lightning Resistance" end },
		{ weight = 7, text = function() return "+" .. randomRoll(20, 45) .. "% to Fire Resistance" end },
		{ weight = 7, text = function() return "+" .. randomRoll(20, 45) .. "% to Cold Resistance" end },
		{ weight = 6, text = function() return (randomRoll(15, 35)) .. "% increased Critical Hit Chance" end },
		{ weight = 5, text = function() return "+" .. randomRoll(20, 45) .. " to Dexterity" end },
	},
	body = {
		{ weight = 12, text = function() return "+" .. randomRoll(80, 180) .. " to maximum Life" end },
		{ weight = 8, text = function() return "+" .. randomRoll(25, 55) .. "% to Lightning Resistance" end },
		{ weight = 8, text = function() return "+" .. randomRoll(25, 55) .. "% to Fire Resistance" end },
		{ weight = 8, text = function() return "+" .. randomRoll(25, 55) .. "% to Cold Resistance" end },
		{ weight = 6, text = function() return (randomRoll(6, 18)) .. "% increased maximum Life" end },
		{ weight = 4, text = function() return "+" .. randomRoll(20, 45) .. " to Dexterity" end },
	},
	boots = {
		{ weight = 10, text = function() return "+" .. randomRoll(50, 110) .. " to maximum Life" end },
		{ weight = 7, text = function() return "+" .. randomRoll(20, 45) .. "% to Cold Resistance" end },
		{ weight = 7, text = function() return "+" .. randomRoll(20, 45) .. "% to Lightning Resistance" end },
		{ weight = 7, text = function() return "+" .. randomRoll(20, 45) .. "% to Fire Resistance" end },
		{ weight = 5, text = function() return (randomRoll(20, 35)) .. "% increased Movement Speed" end },
		{ weight = 4, text = function() return "+" .. randomRoll(15, 35) .. " to Dexterity" end },
	},
	belt = {
		{ weight = 12, text = function() return "+" .. randomRoll(70, 140) .. " to maximum Life" end },
		{ weight = 8, text = function() return "+" .. randomRoll(25, 55) .. "% to Fire Resistance" end },
		{ weight = 8, text = function() return "+" .. randomRoll(25, 55) .. "% to Cold Resistance" end },
		{ weight = 8, text = function() return "+" .. randomRoll(25, 55) .. "% to Lightning Resistance" end },
		{ weight = 6, text = function() return (randomRoll(6, 18)) .. "% increased maximum Life" end },
		{ weight = 4, text = function() return "+" .. randomRoll(15, 40) .. " to Strength" end },
	},
	ring = {
		{ weight = 10, text = function() return "+" .. randomRoll(35, 85) .. " to maximum Life" end },
		{ weight = 8, text = function() return "+" .. randomRoll(20, 45) .. "% to Fire Resistance" end },
		{ weight = 8, text = function() return "+" .. randomRoll(20, 45) .. "% to Cold Resistance" end },
		{ weight = 8, text = function() return "+" .. randomRoll(20, 45) .. "% to Lightning Resistance" end },
		{ weight = 8, text = function() return "Adds " .. fmtRoll(3, 10) .. " to " .. fmtRoll(15, 45) .. " Lightning Damage to Attacks" end },
		{ weight = 7, text = function() return (randomRoll(15, 40)) .. "% increased Elemental Damage with Attacks" end },
		{ weight = 5, text = function() return "+" .. randomRoll(20, 45) .. " to Dexterity" end },
		{ weight = 3, text = function() return "+" .. randomRoll(10, 30) .. " to Intelligence" end },
	},
	amulet = {
		{ weight = 10, text = function() return "+" .. randomRoll(40, 100) .. " to maximum Life" end },
		{ weight = 8, text = function() return "+" .. randomRoll(20, 45) .. " to Strength" end },
		{ weight = 9, text = function() return "+" .. randomRoll(20, 45) .. " to Dexterity" end },
		{ weight = 7, text = function() return "+" .. randomRoll(20, 45) .. " to Intelligence" end },
		{ weight = 7, text = function() return (randomRoll(20, 50)) .. "% increased Elemental Damage with Attacks" end },
		{ weight = 6, text = function() return "+" .. randomRoll(1, 3) .. "% to Critical Hit Chance" end },
		{ weight = 5, text = function() return "+" .. randomRoll(15, 40) .. "% to Critical Damage Bonus" end },
		{ weight = 5, text = function() return "+" .. randomRoll(20, 45) .. "% to Lightning Resistance" end },
	},
}

local function weightedPick(pool)
	local total = 0
	for _, entry in ipairs(pool) do
		total = total + entry.weight
	end
	local roll = math.random(1, total)
	for _, entry in ipairs(pool) do
		roll = roll - entry.weight
		if roll <= 0 then
			return entry.text()
		end
	end
	return pool[1].text()
end

function M.generateRare(slot, base, affixCount, quality)
	base = base or M.bases[slot][math.random(1, #M.bases[slot])]
	affixCount = affixCount or 5
	quality = quality or 20

	local lines = {
		"New Item",
		base,
		"Quality: " .. quality,
		"Implicits: 0",
	}

	-- Weapon runes: flat lightning for Lightning Arrow, modelled as implicits
	if slot == "weapon" then
		local runeCount = 3
		lines[4] = "Implicits: " .. runeCount
		for i = 1, runeCount do
			t_insert(lines, "{rune}Adds " .. randomRoll(2, 5) .. " to " .. randomRoll(160, 190) .. " Lightning Damage")
		end
	end

	local pool = M.affixes[slot]
	local chosen = {}

	-- Guarantee a minimum life roll on armour and jewellery
	if slot ~= "weapon" and slot ~= "quiver" then
		t_insert(chosen, "+" .. randomRoll(
			slot == "body" and 80 or (slot == "helmet" and 60 or (slot == "belt" and 70 or 30)),
			slot == "body" and 180 or (slot == "helmet" and 130 or (slot == "belt" and 140 or 90))
		) .. " to maximum Life")
	end

	-- Guarantee at least one resistance on armour and jewellery
	if slot ~= "weapon" and slot ~= "quiver" then
		local resistType = ({"Fire", "Cold", "Lightning"})[math.random(1, 3)]
		t_insert(chosen, "+" .. randomRoll(20, 45) .. "% to " .. resistType .. " Resistance")
	end

	-- Guarantee attributes on jewellery to help meet gem requirements
	if slot == "amulet" then
		t_insert(chosen, "+" .. randomRoll(45, 70) .. " to Dexterity")
		t_insert(chosen, "+" .. randomRoll(25, 50) .. " to Intelligence")
		t_insert(chosen, "+" .. randomRoll(10, 25) .. " to Strength")
	end
	if slot == "ring" then
		t_insert(chosen, "+" .. randomRoll(35, 60) .. " to Dexterity")
		t_insert(chosen, "+" .. randomRoll(15, 35) .. " to Intelligence")
		t_insert(chosen, "+" .. randomRoll(10, 25) .. " to Strength")
	end

	-- Fill remaining affix slots from weighted pool
	for i = #chosen + 1, affixCount do
		if pool then
			t_insert(chosen, weightedPick(pool))
		end
	end

	for _, line in ipairs(chosen) do
		t_insert(lines, line)
	end
	return table.concat(lines, "\n")
end

function M.generateUnique(slot, index)
	local pool = M.uniques[slot]
	if not pool or #pool == 0 then
		return nil
	end
	index = index or math.random(1, #pool)
	return pool[index]
end

-- Generate a full gear set for Lightning Arrow.
-- Returns a table keyed by slot name with raw item strings.
function M.generateSet(opts)
	opts = opts or { }
	local set = { }
	local slots = { "weapon", "quiver", "helmet", "body", "gloves", "boots", "belt", "ring", "ring", "amulet" }
	for _, slot in ipairs(slots) do
		local isUnique = opts.uniqueChance and math.random() < opts.uniqueChance
		if isUnique and M.uniques[slot] then
			t_insert(set, { slot = slot, raw = M.generateUnique(slot) })
		else
			t_insert(set, { slot = slot, raw = M.generateRare(slot, nil, 5, opts.quality) })
		end
	end
	return set
end

return M
