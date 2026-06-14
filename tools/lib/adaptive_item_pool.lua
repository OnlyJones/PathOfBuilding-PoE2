-- Path of Building: PoE2 — Adaptive Item Pool Generator
--
-- Generates raw PoB item strings based on a seed build's identity:
-- - main skill tags (attack, spell, elemental, physical, etc.)
-- - equipped item bases and rarities
-- - budget tier

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

-- === Generic base pools by slot ===
M.basePools = {
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

-- Map gem tags / archetype hints to preferred bases
M.baseHints = {
	bow = { weapon = { "Gemini Bow", "Dualstring Bow", "Recurve Bow" }, quiver = { "Primed Quiver", "Broadhead Quiver" } },
	claw = { weapon = { "Sharktooth Claw", "Twin Claw", "Blinder" } },
	dagger = { weapon = { "Boot Knife", "Platinum Kris", "Royal Skewer" } },
	wand = { weapon = { "Crackling Wand", "Sage Wand", "Omen Wand" } },
	staff = { weapon = { "Gnarled Branch", "Highborn Staff", "Primordial Staff" } },
	one_handed_melee = { weapon = { "Longsword", "Battle Axe", "Mace" } },
	two_handed_melee = { weapon = { "Greatsword", "Greataxe", "Great Mallet" } },
	str_armour = { body = { "Plate Vest", "Chainmail Doublet" }, helmet = { "Iron Hat", "Cone Helmet" }, gloves = { "Ringmail Gauntlets" }, boots = { "Mail Sabatons" } },
	dex_armour = { body = { "Slipstrike Vest" }, helmet = { "Avian Mask" }, gloves = { "Torn Gloves" }, boots = { "Charmed Shoes" } },
	int_armour = { body = { "Hexer's Robe", "Feathered Robe" }, helmet = { "Felt Cap" }, gloves = { "Riveted Mitts" }, boots = { "Laced Boots" } },
}

-- === Unique items (cross-archetype; expanded over time) ===
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

-- === Adaptive affix pools ===
M.affixes = {}

function M.buildAffixes(archetype)
	archetype = archetype or {}
	local isAttack = archetype.attack
	local isSpell = archetype.spell
	local isBow = archetype.bow
	local elemental = archetype.elemental or {}
	local dmgTypes = {}
	for _, dt in ipairs({"Lightning", "Cold", "Fire"}) do
		if elemental[dt:lower()] then t_insert(dmgTypes, dt) end
	end
	if #dmgTypes == 0 then
		dmgTypes = { archetype.physical and "Physical" or "Lightning" }
	end

	local function dmgPrefix(slot)
		local pool = {}
		for _, dt in ipairs(dmgTypes) do
			if slot == "weapon" then
				t_insert(pool, { weight = 20, text = function() return "Adds " .. fmtRoll(30, 75) .. " to " .. fmtRoll(140, 280) .. " " .. dt .. " Damage" end })
			else
				t_insert(pool, { weight = 14, text = function() return "Adds " .. fmtRoll(5, 18) .. " to " .. fmtRoll(20, 65) .. " " .. dt .. " Damage to Attacks" end })
			end
		end
		return pool
	end

	local globalDmg = { weight = 16, text = function() return (randomRoll(60, 140)) .. "% increased " .. (isSpell and "Spell " or "") .. "Damage" end }
	local attackSpeed = { weight = 14, text = function() return (randomRoll(20, 40)) .. "% increased Attack Speed" end }
	local castSpeed = { weight = 14, text = function() return (randomRoll(12, 30)) .. "% increased Cast Speed" end }
	local critChance = { weight = 10, text = function() return "+" .. randomRoll(1, 3) .. "% to Critical Hit Chance" end }
	local critMulti = { weight = 9, text = function() return "+" .. randomRoll(20, 55) .. "% to Critical Damage Bonus" end }
	local attackLevels = { weight = isBow and 12 or 6, text = function() return "+" .. randomRoll(3, 5) .. " to Level of all Attack Skills" end }
	local spellLevels = { weight = 8, text = function() return "+" .. randomRoll(1, 3) .. " to Level of all Spell Skills" end }
	local additionalArrow = { weight = isBow and 10 or 0, text = function() return "Bow Attacks fire an additional Arrow" end }

	M.affixes.weapon = dmgPrefix("weapon")
	t_insert(M.affixes.weapon, globalDmg)
	if isAttack then
		t_insert(M.affixes.weapon, attackSpeed)
		t_insert(M.affixes.weapon, attackLevels)
	end
	if isSpell then
		t_insert(M.affixes.weapon, castSpeed)
		t_insert(M.affixes.weapon, spellLevels)
	end
	t_insert(M.affixes.weapon, critChance)
	t_insert(M.affixes.weapon, critMulti)
	if isBow then
		t_insert(M.affixes.weapon, additionalArrow)
	end
	if M.archetype and M.archetype.bow then
		-- High-priority flat damage and % increased damage for bows
		for _, dt in ipairs(dmgTypes) do
			t_insert(M.affixes.weapon, 1, { weight = 22, text = function() return "Adds " .. fmtRoll(30, 75) .. " to " .. fmtRoll(140, 280) .. " " .. dt .. " Damage" end })
		end
		t_insert(M.affixes.weapon, { weight = 16, text = function() return (randomRoll(60, 140)) .. "% increased Elemental Damage with Attacks" end })
	end

	M.affixes.quiver = isBow and {
		{ weight = 16, text = function() return "Adds " .. fmtRoll(8, 25) .. " to " .. fmtRoll(30, 90) .. " " .. (dmgTypes[1] or "Lightning") .. " Damage to Attacks" end },
		{ weight = 14, text = function() return (randomRoll(35, 90)) .. "% increased Elemental Damage with Attacks" end },
		{ weight = 12, text = function() return (randomRoll(10, 28)) .. "% increased Attack Speed" end },
		{ weight = 9, text = function() return "+" .. randomRoll(1, 3) .. "% to Critical Hit Chance" end },
		{ weight = 8, text = function() return "+" .. randomRoll(20, 45) .. "% to Critical Damage Bonus" end },
		{ weight = 5, text = function() return "Projectiles Pierce an additional Target" end },
		{ weight = 5, text = function() return "+" .. randomRoll(25, 60) .. " to Dexterity" end },
	} or {}

	M.affixes.gloves = dmgPrefix("gloves")
	t_insert(M.affixes.gloves, { weight = 11, text = function() return "+" .. randomRoll(60, 130) .. " to maximum Life" end })
	t_insert(M.affixes.gloves, { weight = 9, text = function() return "+" .. randomRoll(25, 55) .. "% to " .. (dmgTypes[1] or "Lightning") .. " Resistance" end })
	t_insert(M.affixes.gloves, { weight = 6, text = function() return "+" .. randomRoll(25, 55) .. "% to Fire Resistance" end })
	t_insert(M.affixes.gloves, { weight = 6, text = function() return "+" .. randomRoll(25, 55) .. "% to Cold Resistance" end })
	if isAttack then
		t_insert(M.affixes.gloves, { weight = 11, text = function() return (randomRoll(12, 30)) .. "% increased Attack Speed" end })
	end

	M.affixes.helmet = {
		{ weight = 13, text = function() return "+" .. randomRoll(70, 150) .. " to maximum Life" end },
		{ weight = 9, text = function() return "+" .. randomRoll(25, 55) .. "% to " .. (dmgTypes[1] or "Lightning") .. " Resistance" end },
		{ weight = 7, text = function() return "+" .. randomRoll(25, 55) .. "% to Fire Resistance" end },
		{ weight = 7, text = function() return "+" .. randomRoll(25, 55) .. "% to Cold Resistance" end },
		{ weight = 7, text = function() return (randomRoll(15, 35)) .. "% increased Critical Hit Chance" end },
		{ weight = 5, text = function() return "+" .. randomRoll(25, 55) .. " to " .. (isSpell and "Intelligence" or "Dexterity") end },
	}

	M.affixes.body = {
		{ weight = 16, text = function() return "+" .. randomRoll(90, 200) .. " to maximum Life" end },
		{ weight = 10, text = function() return "+" .. randomRoll(30, 60) .. "% to " .. (dmgTypes[1] or "Lightning") .. " Resistance" end },
		{ weight = 9, text = function() return "+" .. randomRoll(30, 60) .. "% to Fire Resistance" end },
		{ weight = 9, text = function() return "+" .. randomRoll(30, 60) .. "% to Cold Resistance" end },
		{ weight = 7, text = function() return (randomRoll(6, 18)) .. "% increased maximum Life" end },
		{ weight = 5, text = function() return "+" .. randomRoll(25, 55) .. " to " .. (isSpell and "Intelligence" or "Dexterity") end },
	}

	M.affixes.boots = {
		{ weight = 13, text = function() return "+" .. randomRoll(60, 130) .. " to maximum Life" end },
		{ weight = 9, text = function() return "+" .. randomRoll(25, 55) .. "% to Cold Resistance" end },
		{ weight = 9, text = function() return "+" .. randomRoll(25, 55) .. "% to Lightning Resistance" end },
		{ weight = 9, text = function() return "+" .. randomRoll(25, 55) .. "% to Fire Resistance" end },
		{ weight = 6, text = function() return (randomRoll(20, 35)) .. "% increased Movement Speed" end },
		{ weight = 5, text = function() return "+" .. randomRoll(20, 45) .. " to " .. (isSpell and "Intelligence" or "Dexterity") end },
	}

	M.affixes.belt = {
		{ weight = 16, text = function() return "+" .. randomRoll(80, 160) .. " to maximum Life" end },
		{ weight = 10, text = function() return "+" .. randomRoll(30, 60) .. "% to Fire Resistance" end },
		{ weight = 10, text = function() return "+" .. randomRoll(30, 60) .. "% to Cold Resistance" end },
		{ weight = 10, text = function() return "+" .. randomRoll(30, 60) .. "% to Lightning Resistance" end },
		{ weight = 7, text = function() return (randomRoll(6, 18)) .. "% increased maximum Life" end },
		{ weight = 5, text = function() return "+" .. randomRoll(15, 40) .. " to Strength" end },
	}

	M.affixes.ring = {
		{ weight = 12, text = function() return "+" .. randomRoll(40, 100) .. " to maximum Life" end },
		{ weight = 9, text = function() return "+" .. randomRoll(25, 55) .. "% to Fire Resistance" end },
		{ weight = 9, text = function() return "+" .. randomRoll(25, 55) .. "% to Cold Resistance" end },
		{ weight = 9, text = function() return "+" .. randomRoll(25, 55) .. "% to Lightning Resistance" end },
		{ weight = 10, text = function() return "Adds " .. fmtRoll(3, 12) .. " to " .. fmtRoll(15, 55) .. " " .. (dmgTypes[1] or "Lightning") .. " Damage to Attacks" end },
		{ weight = 7, text = function() return (randomRoll(20, 50)) .. "% increased Elemental Damage with Attacks" end },
		{ weight = 6, text = function() return "+" .. randomRoll(25, 55) .. " to " .. (isSpell and "Intelligence" or "Dexterity") end },
	}

	M.affixes.amulet = {
		{ weight = 12, text = function() return "+" .. randomRoll(50, 110) .. " to maximum Life" end },
		{ weight = 9, text = function() return "+" .. randomRoll(20, 45) .. " to Strength" end },
		{ weight = 10, text = function() return "+" .. randomRoll(25, 55) .. " to " .. (isSpell and "Intelligence" or "Dexterity") end },
		{ weight = 8, text = function() return "+" .. randomRoll(20, 45) .. " to " .. ((isSpell and not isAttack) and "Dexterity" or "Intelligence") end },
		{ weight = 9, text = function() return (randomRoll(25, 60)) .. "% increased " .. (isSpell and "Spell " or "Elemental ") .. "Damage" end },
		{ weight = 7, text = function() return "+" .. randomRoll(1, 3) .. "% to Critical Hit Chance" end },
		{ weight = 6, text = function() return "+" .. randomRoll(20, 50) .. "% to Critical Damage Bonus" end },
		{ weight = 6, text = function() return "+" .. randomRoll(25, 55) .. "% to " .. (dmgTypes[1] or "Lightning") .. " Resistance" end },
	}
end

local function weightedPick(pool)
	if not pool or #pool == 0 then
		return nil
	end
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

local function baseDefences(slot, tier)
	tier = math.min(math.max(tier or 3, 1), 5)
	local isDex = M.archetype and (M.archetype.bow or M.archetype.attack)
	if not isDex then
		return ""
	end
	if slot == "body" then
		local minArm = 40 + tier * 40
		local maxArm = minArm + tier * 30
		local minEva = 80 + tier * 90
		local maxEva = minEva + tier * 80
		return "Armour: " .. randomRoll(minArm, maxArm) .. "\nEvasion: " .. randomRoll(minEva, maxEva)
	elseif slot == "helmet" then
		local minEva = 70 + tier * 60
		local maxEva = minEva + tier * 50
		return "Evasion: " .. randomRoll(minEva, maxEva)
	elseif slot == "gloves" then
		local minEva = 20 + tier * 30
		local maxEva = minEva + tier * 25
		return "Evasion: " .. randomRoll(minEva, maxEva)
	elseif slot == "boots" then
		local minEva = 40 + tier * 45
		local maxEva = minEva + tier * 40
		return "Evasion: " .. randomRoll(minEva, maxEva)
	end
	return ""
end

function M.generateRare(slot, base, affixCount, quality)
	base = base or (M.basePools[slot] and M.basePools[slot][math.random(1, #M.basePools[slot])])
	affixCount = affixCount or 5
	quality = quality or 20
	local tier = math.floor((M.archetype and M.archetype.level or 90) / 20) + 1

	local lines = {
		"New Item",
		base or "Unknown Base",
		"Quality: " .. quality,
	}

	-- Add armour/evasion base defences for armour slots
	local defences = baseDefences(slot, tier)
	if defences ~= "" then
		for line in defences:gmatch("[^\r\n]+") do
			t_insert(lines, line)
		end
	end

	-- Weapon runes: flat elemental damage, modelled as implicits
	if slot == "weapon" then
		local runeCount = 3
		local dmgType = M.archetype and M.archetype.elemental and next(M.archetype.elemental) or "Lightning"
		dmgType = dmgType:gsub("^%l", string.upper)
		lines[4] = "Implicits: " .. runeCount
		for i = 1, runeCount do
			t_insert(lines, "{rune}Adds " .. randomRoll(2, 5) .. " to " .. randomRoll(140, 190) .. " " .. dmgType .. " Damage")
		end
	else
		lines[4] = "Implicits: 0"
	end

	local pool = M.affixes[slot]
	local chosen = {}

	-- Guarantee two resistances on armour and jewellery
	if slot ~= "weapon" and slot ~= "quiver" then
		t_insert(chosen, "+" .. randomRoll(
			slot == "body" and 90 or (slot == "helmet" and 70 or (slot == "belt" and 80 or 40)),
			slot == "body" and 200 or (slot == "helmet" and 140 or (slot == "belt" and 160 or 100))
		) .. " to maximum Life")
		local resistType1 = ({"Fire", "Cold", "Lightning"})[math.random(1, 3)]
		t_insert(chosen, "+" .. randomRoll(25, 55) .. "% to " .. resistType1 .. " Resistance")
		local resistType2
		repeat
			resistType2 = ({"Fire", "Cold", "Lightning"})[math.random(1, 3)]
		until resistType2 ~= resistType1
		t_insert(chosen, "+" .. randomRoll(25, 55) .. "% to " .. resistType2 .. " Resistance")
	end

	-- Guarantee attributes on jewellery
	local isSpell = M.archetype and M.archetype.spell
	if slot == "amulet" then
		t_insert(chosen, "+" .. randomRoll(50, 80) .. " to " .. (isSpell and "Intelligence" or "Dexterity"))
		t_insert(chosen, "+" .. randomRoll(30, 60) .. " to " .. (isSpell and "Dexterity" or "Intelligence"))
		t_insert(chosen, "+" .. randomRoll(20, 40) .. " to Strength")
	end
	if slot == "ring" then
		t_insert(chosen, "+" .. randomRoll(40, 70) .. " to " .. (isSpell and "Intelligence" or "Dexterity"))
		t_insert(chosen, "+" .. randomRoll(20, 40) .. " to " .. (isSpell and "Dexterity" or "Intelligence"))
		t_insert(chosen, "+" .. randomRoll(15, 30) .. " to Strength")
	end

	for i = #chosen + 1, affixCount do
		t_insert(chosen, weightedPick(pool))
	end

	for _, line in ipairs(chosen) do
		if line then
			t_insert(lines, line)
		end
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

function M.configure(seedInfo)
	M.archetype = { level = seedInfo.level or 90 }
	if seedInfo and seedInfo.mainSkill then
		-- Load gems from project root, but cwd may be src/ after bootstrap; try both
		local gems = dofile("src/Data/Gems.lua") or dofile("../src/Data/Gems.lua")
		local key = nil
		for k, v in pairs(gems) do
			if v.name == seedInfo.mainSkill then
				key = k
				break
			end
		end
		local gem = key and gems[key]
		if gem and gem.tags then
			M.archetype.attack = gem.tags.attack or gem.tags.bow or gem.tags.mace or gem.tags.sword or gem.tags.claw or gem.tags.dagger or gem.tags.wand or gem.tags.staff
			M.archetype.spell = gem.tags.spell
			M.archetype.bow = gem.tags.bow
			M.archetype.elemental = {
				lightning = gem.tags.lightning,
				cold = gem.tags.cold,
				fire = gem.tags.fire,
			}
			M.archetype.physical = gem.tags.physical
		end
	end

	-- Override base pools from seed item bases (map POB slot names back to canonical)
	if seedInfo and seedInfo.items then
		local slotReverse = {}
		for canon, pobSlot in pairs(M.slotMap) do
			slotReverse[pobSlot] = canon
		end
		for slot, item in pairs(seedInfo.items) do
			local canon = slotReverse[slot] or slot
			if item.baseName and M.basePools[canon] then
				-- Put the seed base first in the pool
				local newPool = { item.baseName }
				for _, b in ipairs(M.basePools[canon]) do
					if b ~= item.baseName then
						t_insert(newPool, b)
					end
				end
				M.basePools[canon] = newPool
			end
		end
	end

	M.buildAffixes(M.archetype)
end

M.slotMap = {
	weapon = "Weapon 1",
	quiver = "Weapon 2",
	helmet = "Helmet",
	body = "Body Armour",
	gloves = "Gloves",
	boots = "Boots",
	belt = "Belt",
	ring = "Ring",
	amulet = "Amulet",
}

function M.generateSet(opts)
	opts = opts or {}
	local set = {}
	local slots = { "weapon", "quiver", "helmet", "body", "gloves", "boots", "belt", "ring", "ring", "amulet" }
	for _, slot in ipairs(slots) do
		local isUnique = opts.uniqueChance and math.random() < opts.uniqueChance
		local raw
		if isUnique and M.uniques[slot] then
			raw = M.generateUnique(slot)
		else
			raw = M.generateRare(slot, nil, opts.affixCount, opts.quality)
		end
		t_insert(set, { slot = M.slotMap[slot], raw = raw })
	end
	return set
end

return M
