-- Path of Building: PoE2 — Adaptive Item Pool Generator
--
-- Generates raw PoB item strings based on a seed build's identity:
-- - main skill tags (attack, spell, elemental, physical, etc.)
-- - equipped item bases and rarities
-- - budget tier
--
-- The pool is designed to be archetype-agnostic: it detects weapon type,
-- armour preference, and uniques from the seed build and tailors generation.

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

-- === Cross-archetype base pools ===
-- These are defaults. configure() reorders them based on the seed build.
M.basePools = {
	weapon = {
		-- Bows
		"Gemini Bow", "Dualstring Bow", "Recurve Bow", "Shortbow",
		-- Wands
		"Crackling Wand", "Sage Wand", "Omen Wand",
		-- Staves
		"Gnarled Branch", "Highborn Staff", "Primordial Staff",
		-- Claws
		"Sharktooth Claw", "Twin Claw", "Blinder",
		-- Daggers
		"Boot Knife", "Platinum Kris", "Royal Skewer",
		-- One-handed melee
		"Longsword", "Battle Axe", "Mace",
		-- Two-handed melee
		"Greatsword", "Greataxe", "Great Mallet",
	},
	quiver = { "Primed Quiver", "Broadhead Quiver" },
	helmet = {
		-- Dex
		"Avian Mask", "Face Mask",
		-- Str
		"Iron Hat", "Cone Helmet",
		-- Int
		"Felt Cap", "Lunaris Circlet",
	},
	body = {
		-- Dex/Armour-Evasion
		"Slipstrike Vest", "Bone Raiment",
		-- Str
		"Plate Vest", "Chainmail Doublet",
		-- Int
		"Hexer's Robe", "Feathered Robe",
	},
	gloves = {
		-- Dex
		"Torn Gloves", "Layered Gauntlets",
		-- Str
		"Ringmail Gauntlets", "Plate Gauntlets",
		-- Int
		"Riveted Mitts", "Silk Gloves",
	},
	boots = {
		-- Dex
		"Charmed Shoes", "Laced Boots",
		-- Str
		"Mail Sabatons", "Plate Greaves",
		-- Int
		"Secured Leggings", "Silk Slippers",
	},
	belt = { "Utility Belt", "Wide Belt", "Long Belt" },
	ring = { "Gold Ring", "Ruby Ring", "Topaz Ring", "Sapphire Ring", "Amethyst Ring", "Iron Ring", "Golden Hoop" },
	amulet = { "Bloodstone Amulet", "Jade Amulet", "Lapis Amulet", "Lunar Amulet", "Amber Amulet" },
}

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

-- === Weapon / armour type detection ===
M.weaponPatterns = {
	bow = { "bow" },
	wand = { "wand" },
	staff = { "staff", "branch" },
	claw = { "claw" },
	dagger = { "dagger", "kris", "skewer", "knife" },
	one_handed_melee = { "sword", "axe", "mace", " sceptre" },
	two_handed_melee = { "greatsword", "greataxe", "mallet", "maul" },
}

M.armourPatterns = {
	dex = { "vest", "mask", "gloves", "shoes", "boots", "leggings", "slippers" },
	str = { "plate", "mail", "hat", "helmet", "gauntlets", "greaves", "sabatons" },
	int = { "robe", "cap", "mitts", "circlet", "slippers" },
}

function M.detectWeaponType(seedItems)
	local slotReverse = {}
	for canon, pobSlot in pairs(M.slotMap) do
		slotReverse[pobSlot] = canon
	end
	for slotName, item in pairs(seedItems or {}) do
		local canon = slotReverse[slotName] or slotName
		if canon == "weapon" and item.baseName then
			local base = item.baseName:lower()
			for wtype, patterns in pairs(M.weaponPatterns) do
				for _, pat in ipairs(patterns) do
					if base:find(pat, 1, true) then
						return wtype
					end
				end
			end
		end
	end
	return nil
end

function M.detectArmourType(seedItems)
	local slotReverse = {}
	for canon, pobSlot in pairs(M.slotMap) do
		slotReverse[pobSlot] = canon
	end
	local scores = { dex = 0, str = 0, int = 0 }
	for slotName, item in pairs(seedItems or {}) do
		local canon = slotReverse[slotName] or slotName
		if canon ~= "weapon" and canon ~= "quiver" and canon ~= "belt" and canon ~= "ring" and canon ~= "amulet" and item.baseName then
			local base = item.baseName:lower()
			for atype, patterns in pairs(M.armourPatterns) do
				for _, pat in ipairs(patterns) do
					if base:find(pat, 1, true) then
						scores[atype] = scores[atype] + 1
					end
				end
			end
		end
	end
	local best, bestScore = nil, 0
	for atype, score in pairs(scores) do
		if score > bestScore then
			best, bestScore = atype, score
		end
	end
	return best
end

-- === Unique items (cross-archetype) ===
-- These are added to by seed uniques automatically.
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
	belt = {
		[[Rarity: UNIQUE
Ingenuity
Utility Belt
Charm Slots: 3
Implicits: 2
Has 3 Charm Slots
20% of Flask Recovery applied Instantly
11% reduced Charm Charges gained
2% reduced Charm Charges used
30% increased bonuses gained from left Equipped Ring
21% increased bonuses gained from right Equipped Ring]],
	},
	amulet = {},
	ring = {},
	helmet = {},
	boots = {},
	quiver = {},
}

-- Add a unique raw string to the pool for a canonical slot.
function M.addUnique(canonSlot, raw)
	M.uniques[canonSlot] = M.uniques[canonSlot] or {}
	t_insert(M.uniques[canonSlot], raw)
end

-- Extract unique items from seed build and register them in the pool.
function M.addSeedUniques(seedInfo)
	if not seedInfo or not seedInfo.items then
		return
	end
	local slotReverse = {}
	for canon, pobSlot in pairs(M.slotMap) do
		slotReverse[pobSlot] = canon
	end
	for slotName, item in pairs(seedInfo.items) do
		if item.rarity == "UNIQUE" and item.raw then
			local canon = slotReverse[slotName] or slotName
			M.addUnique(canon, item.raw)
		end
	end
end

-- === Adaptive affix pools ===
M.affixes = {}

function M.buildAffixes(archetype)
	archetype = archetype or {}
	local isAttack = archetype.attack
	local isSpell = archetype.spell
	local isBow = archetype.bow
	local isWand = archetype.wand
	local isStaff = archetype.staff
	local isMelee = archetype.melee
	local armourType = archetype.armourType or "dex"
	local elemental = archetype.elemental or {}
	local dmgTypes = {}
	for _, dt in ipairs({"Lightning", "Cold", "Fire"}) do
		if elemental[dt:lower()] then t_insert(dmgTypes, dt) end
	end
	if #dmgTypes == 0 then
		dmgTypes = { archetype.physical and "Physical" or "Lightning" }
	end

	local primaryAttr = isSpell and "Intelligence" or "Dexterity"
	local secondaryAttr = (isSpell and not isAttack) and "Dexterity" or "Intelligence"

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
	local attackLevels = { weight = isAttack and 10 or 0, text = function() return "+" .. randomRoll(3, 5) .. " to Level of all Attack Skills" end }
	local spellLevels = { weight = isSpell and 10 or 0, text = function() return "+" .. randomRoll(1, 3) .. " to Level of all Spell Skills" end }
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
	if isBow then
		for _, dt in ipairs(dmgTypes) do
			t_insert(M.affixes.weapon, 1, { weight = 22, text = function() return "Adds " .. fmtRoll(30, 75) .. " to " .. fmtRoll(140, 280) .. " " .. dt .. " Damage" end })
		end
		t_insert(M.affixes.weapon, { weight = 16, text = function() return (randomRoll(60, 140)) .. "% increased Elemental Damage with Attacks" end })
	end
	if isWand or isStaff then
		for _, dt in ipairs(dmgTypes) do
			t_insert(M.affixes.weapon, 1, { weight = 20, text = function() return "Adds " .. fmtRoll(20, 55) .. " to " .. fmtRoll(100, 220) .. " " .. dt .. " Damage to Spells" end })
		end
		t_insert(M.affixes.weapon, { weight = 15, text = function() return (randomRoll(60, 140)) .. "% increased Spell Damage" end })
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
	if armourType == "dex" then
		t_insert(M.affixes.gloves, { weight = 8, text = function() return (randomRoll(20, 50)) .. "% increased Evasion Rating" end })
	end

	M.affixes.helmet = {
		{ weight = 13, text = function() return "+" .. randomRoll(70, 150) .. " to maximum Life" end },
		{ weight = 9, text = function() return "+" .. randomRoll(25, 55) .. "% to " .. (dmgTypes[1] or "Lightning") .. " Resistance" end },
		{ weight = 7, text = function() return "+" .. randomRoll(25, 55) .. "% to Fire Resistance" end },
		{ weight = 7, text = function() return "+" .. randomRoll(25, 55) .. "% to Cold Resistance" end },
		{ weight = 7, text = function() return (randomRoll(15, 35)) .. "% increased Critical Hit Chance" end },
		{ weight = 5, text = function() return "+" .. randomRoll(25, 55) .. " to " .. primaryAttr end },
	}
	if armourType == "dex" then
		t_insert(M.affixes.helmet, { weight = 9, text = function() return (randomRoll(25, 55)) .. "% increased Evasion Rating" end })
	elseif armourType == "str" then
		t_insert(M.affixes.helmet, { weight = 9, text = function() return (randomRoll(25, 55)) .. "% increased Armour" end })
	elseif armourType == "int" then
		t_insert(M.affixes.helmet, { weight = 8, text = function() return (randomRoll(20, 45)) .. "% increased Energy Shield" end })
	end

	M.affixes.body = {
		{ weight = 16, text = function() return "+" .. randomRoll(90, 200) .. " to maximum Life" end },
		{ weight = 10, text = function() return "+" .. randomRoll(30, 60) .. "% to " .. (dmgTypes[1] or "Lightning") .. " Resistance" end },
		{ weight = 9, text = function() return "+" .. randomRoll(30, 60) .. "% to Fire Resistance" end },
		{ weight = 9, text = function() return "+" .. randomRoll(30, 60) .. "% to Cold Resistance" end },
		{ weight = 7, text = function() return (randomRoll(6, 18)) .. "% increased maximum Life" end },
		{ weight = 5, text = function() return "+" .. randomRoll(25, 55) .. " to " .. primaryAttr end },
	}
	if armourType == "dex" then
		t_insert(M.affixes.body, { weight = 10, text = function() return (randomRoll(30, 60)) .. "% increased Evasion Rating" end })
	elseif armourType == "str" then
		t_insert(M.affixes.body, { weight = 10, text = function() return (randomRoll(30, 60)) .. "% increased Armour" end })
	elseif armourType == "int" then
		t_insert(M.affixes.body, { weight = 9, text = function() return (randomRoll(25, 50)) .. "% increased Energy Shield" end })
	end

	M.affixes.boots = {
		{ weight = 13, text = function() return "+" .. randomRoll(60, 130) .. " to maximum Life" end },
		{ weight = 9, text = function() return "+" .. randomRoll(25, 55) .. "% to Cold Resistance" end },
		{ weight = 9, text = function() return "+" .. randomRoll(25, 55) .. "% to Lightning Resistance" end },
		{ weight = 9, text = function() return "+" .. randomRoll(25, 55) .. "% to Fire Resistance" end },
		{ weight = 6, text = function() return (randomRoll(20, 35)) .. "% increased Movement Speed" end },
		{ weight = 5, text = function() return "+" .. randomRoll(20, 45) .. " to " .. primaryAttr end },
	}
	if armourType == "dex" then
		t_insert(M.affixes.boots, { weight = 8, text = function() return (randomRoll(20, 50)) .. "% increased Evasion Rating" end })
	elseif armourType == "str" then
		t_insert(M.affixes.boots, { weight = 8, text = function() return (randomRoll(20, 50)) .. "% increased Armour" end })
	elseif armourType == "int" then
		t_insert(M.affixes.boots, { weight = 7, text = function() return (randomRoll(15, 40)) .. "% increased Energy Shield" end })
	end

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
		{ weight = 6, text = function() return "+" .. randomRoll(25, 55) .. " to " .. primaryAttr end },
	}
	if isSpell then
		t_insert(M.affixes.ring, { weight = 9, text = function() return (randomRoll(20, 50)) .. "% increased Spell Damage" end })
	end

	M.affixes.amulet = {
		{ weight = 12, text = function() return "+" .. randomRoll(50, 110) .. " to maximum Life" end },
		{ weight = 9, text = function() return "+" .. randomRoll(20, 45) .. " to Strength" end },
		{ weight = 10, text = function() return "+" .. randomRoll(25, 55) .. " to " .. primaryAttr end },
		{ weight = 8, text = function() return "+" .. randomRoll(20, 45) .. " to " .. secondaryAttr end },
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

local function baseDefences(slot, tier, armourType)
	tier = math.min(math.max(tier or 3, 1), 5)
	armourType = armourType or "dex"
	if slot == "body" then
		if armourType == "dex" then
			local minArm = 40 + tier * 40
			local maxArm = minArm + tier * 30
			local minEva = 120 + tier * 110
			local maxEva = minEva + tier * 100
			return "Armour: " .. randomRoll(minArm, maxArm) .. "\nEvasion: " .. randomRoll(minEva, maxEva)
		elseif armourType == "str" then
			local minArm = 150 + tier * 120
			local maxArm = minArm + tier * 100
			return "Armour: " .. randomRoll(minArm, maxArm)
		elseif armourType == "int" then
			local minES = 80 + tier * 70
			local maxES = minES + tier * 60
			return "Energy Shield: " .. randomRoll(minES, maxES)
		end
	elseif slot == "helmet" then
		if armourType == "dex" then
			return "Evasion: " .. randomRoll(100 + tier * 80, 150 + tier * 110)
		elseif armourType == "str" then
			return "Armour: " .. randomRoll(120 + tier * 90, 180 + tier * 130)
		elseif armourType == "int" then
			return "Energy Shield: " .. randomRoll(60 + tier * 50, 100 + tier * 80)
		end
	elseif slot == "gloves" then
		if armourType == "dex" then
			return "Evasion: " .. randomRoll(40 + tier * 40, 70 + tier * 60)
		elseif armourType == "str" then
			return "Armour: " .. randomRoll(50 + tier * 50, 90 + tier * 80)
		elseif armourType == "int" then
			return "Energy Shield: " .. randomRoll(25 + tier * 25, 45 + tier * 45)
		end
	elseif slot == "boots" then
		if armourType == "dex" then
			return "Evasion: " .. randomRoll(70 + tier * 60, 120 + tier * 90)
		elseif armourType == "str" then
			return "Armour: " .. randomRoll(90 + tier * 70, 140 + tier * 100)
		elseif armourType == "int" then
			return "Energy Shield: " .. randomRoll(40 + tier * 35, 70 + tier * 60)
		end
	end
	return ""
end

function M.generateRare(slot, base, affixCount, quality)
	base = base or (M.basePools[slot] and M.basePools[slot][math.random(1, #M.basePools[slot])])
	affixCount = affixCount or 5
	quality = quality or 20
	local tier = math.floor((M.archetype and M.archetype.level or 90) / 20) + 1
	local armourType = M.archetype and M.archetype.armourType or "dex"

	local lines = {
		"New Item",
		base or "Unknown Base",
		"Quality: " .. quality,
	}

	-- Add armour/evasion/ES base defences for armour slots
	local defences = baseDefences(slot, tier, armourType)
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

	-- Guarantee life + two resistances on armour and jewellery
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

	-- Detect weapon / spell archetype from main skill
	if seedInfo and seedInfo.mainSkill then
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
			M.archetype.wand = gem.tags.wand
			M.archetype.staff = gem.tags.staff
			M.archetype.elemental = {
				lightning = gem.tags.lightning,
				cold = gem.tags.cold,
				fire = gem.tags.fire,
			}
			M.archetype.physical = gem.tags.physical
		end
	end

	-- Detect weapon type and armour type from seed gear (overrides gem hints if present)
	local weaponType = M.detectWeaponType(seedInfo and seedInfo.items)
	if weaponType then
		M.archetype.bow = weaponType == "bow"
		M.archetype.wand = weaponType == "wand"
		M.archetype.staff = weaponType == "staff"
		M.archetype.melee = weaponType == "one_handed_melee" or weaponType == "two_handed_melee" or weaponType == "claw" or weaponType == "dagger"
		M.archetype.attack = M.archetype.bow or M.archetype.melee
	end
	M.archetype.armourType = M.detectArmourType(seedInfo and seedInfo.items) or "dex"

	-- Filter base pools so generated gear matches the seed's weapon/armour type.
	local function filterByType(pool, predicate)
		local filtered = {}
		for _, base in ipairs(pool) do
			if predicate(base:lower()) then
				t_insert(filtered, base)
			end
		end
		return #filtered > 0 and filtered or pool
	end

	local weaponPred
	if M.archetype.bow then
		weaponPred = function(b) return b:find("bow", 1, true) end
	elseif M.archetype.wand then
		weaponPred = function(b) return b:find("wand", 1, true) end
	elseif M.archetype.staff then
		weaponPred = function(b) return b:find("staff", 1, true) or b:find("branch", 1, true) end
	elseif M.archetype.melee then
		weaponPred = function(b)
			return b:find("sword", 1, true) or b:find("axe", 1, true) or b:find("mace", 1, true)
				or b:find("mallet", 1, true) or b:find("claw", 1, true) or b:find("dagger", 1, true)
				or b:find("kris", 1, true) or b:find("skewer", 1, true) or b:find("knife", 1, true)
				or b:find("maul", 1, true)
		end
	end
	if weaponPred then
		M.basePools.weapon = filterByType(M.basePools.weapon, weaponPred)
		if M.archetype.bow then
			M.basePools.quiver = { "Primed Quiver", "Broadhead Quiver" }
		else
			M.basePools.quiver = {}
		end
	end

	local armourPred
	if M.archetype.armourType == "dex" then
		armourPred = function(b) return b:find("vest") or b:find("mask") or b:find("gloves") or b:find("shoes") or b:find("leggings") or b:find("slippers") or b:find("boots") end
	elseif M.archetype.armourType == "str" then
		armourPred = function(b) return b:find("plate") or b:find("mail") or b:find("hat") or b:find("helmet") or b:find("gauntlets") or b:find("greaves") or b:find("sabatons") end
	elseif M.archetype.armourType == "int" then
		armourPred = function(b) return b:find("robe") or b:find("cap") or b:find("mitts") or b:find("circlet") or b:find("slippers") end
	end
	if armourPred then
		for _, slot in ipairs({"helmet", "body", "gloves", "boots"}) do
			M.basePools[slot] = filterByType(M.basePools[slot], armourPred)
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

	-- Register any uniques from the seed so the optimizer can reuse them.
	M.addSeedUniques(seedInfo)

	M.buildAffixes(M.archetype)
end

function M.generateSet(opts)
	opts = opts or {}
	local set = {}
	local slots = { "weapon", "quiver", "helmet", "body", "gloves", "boots", "belt", "ring", "ring", "amulet" }
	for _, slot in ipairs(slots) do
		local isUnique = opts.uniqueChance and math.random() < opts.uniqueChance
		local raw
		if isUnique and M.uniques[slot] and #M.uniques[slot] > 0 then
			raw = M.generateUnique(slot)
		else
			raw = M.generateRare(slot, nil, opts.affixCount, opts.quality)
		end
		t_insert(set, { slot = M.slotMap[slot], raw = raw })
	end
	return set
end

return M
