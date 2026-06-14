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

M.baseFileMap = {
	weapon = { "wand", "staff", "sceptre", "bow", "sword", "axe", "mace", "claw", "dagger" },
	quiver = { "quiver" },
	helmet = { "helmet" },
	body = { "body" },
	gloves = { "gloves" },
	boots = { "boots" },
	belt = { "belt" },
	ring = { "ring" },
	amulet = { "amulet" },
}

function M.loadValidBaseNames(slot)
	local names = {}
	local seen = {}
	local files = M.baseFileMap[slot]
	if not files then return names end
	for _, file in ipairs(files) do
		local path = "src/Data/Bases/" .. file .. ".lua"
		local f, err = loadfile(path)
		if f then
			local itemBases = {}
			local ok, res = pcall(f, itemBases)
			if not ok and type(res) == "function" then
				-- Some base files return a function; call it.
				ok, res = pcall(res, itemBases)
			end
			for name, _ in pairs(itemBases) do
				if not seen[name] then
					seen[name] = true
					t_insert(names, name)
				end
			end
		end
	end
	return names
end

function M.filterValidBases(slot, candidates)
	local valid = M.loadValidBaseNames(slot)
	local validSet = {}
	for _, name in ipairs(valid) do
		validSet[name:lower()] = true
	end
	local filtered = {}
	for _, base in ipairs(candidates) do
		if validSet[base:lower()] then
			t_insert(filtered, base)
		end
	end
	return #filtered > 0 and filtered or candidates
end

-- === Cross-archetype base pools ===
-- Defaults are populated from src/Data/Bases/*.lua at module load.
M.basePools = {
	weapon = {},
	quiver = {},
	helmet = {},
	body = {},
	gloves = {},
	boots = {},
	belt = {},
	ring = {},
	amulet = {},
}

function M.populateBasePools()
	for slot, files in pairs(M.baseFileMap) do
		M.basePools[slot] = M.loadValidBaseNames(slot)
	end
end

M.populateBasePools()

-- If a slot has no valid bases loaded (e.g., loading failed), fall back to a small safe list.
if #M.basePools.weapon == 0 then
	M.basePools.weapon = { "Volatile Wand", "Permafrost Staff", "Gemini Bow", "Longsword", "Battle Axe", "Mace" }
end
if #M.basePools.quiver == 0 then
	M.basePools.quiver = { "Primed Quiver", "Broadhead Quiver" }
end
if #M.basePools.helmet == 0 then
	M.basePools.helmet = { "Avian Mask", "Iron Hat", "Felt Cap", "Kamasan Tiara" }
end
if #M.basePools.body == 0 then
	M.basePools.body = { "Slipstrike Vest", "Plate Vest", "Hexer's Robe", "Altar Robe" }
end
if #M.basePools.gloves == 0 then
	M.basePools.gloves = { "Torn Gloves", "Ringmail Gauntlets", "Silk Gloves", "Fine Bracers" }
end
if #M.basePools.boots == 0 then
	M.basePools.boots = { "Charmed Shoes", "Braced Sabatons", "Silk Slippers", "Sandsworn Sandals" }
end
if #M.basePools.belt == 0 then
	M.basePools.belt = { "Utility Belt", "Wide Belt", "Long Belt" }
end
if #M.basePools.ring == 0 then
	M.basePools.ring = { "Gold Ring", "Ruby Ring", "Topaz Ring", "Sapphire Ring", "Amethyst Ring", "Iron Ring" }
end
if #M.basePools.amulet == 0 then
	M.basePools.amulet = { "Bloodstone Amulet", "Jade Amulet", "Lapis Amulet", "Lunar Amulet", "Amber Amulet" }
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

-- === Weapon / armour type detection ===
M.weaponPatterns = {
	bow = { "bow" },
	wand = { "wand" },
	staff = { "staff", "branch" },
	sceptre = { "sceptre" },
	claw = { "claw" },
	dagger = { "dagger", "kris", "skewer", "knife" },
	one_handed_melee = { "sword", "axe", "mace" },
	two_handed_melee = { "greatsword", "greataxe", "mallet", "maul" },
}

M.armourPatterns = {
	dex = { "vest", "mask", "gloves", "shoes", "boots", "leggings", "slippers" },
	str = { "plate", "mail", "hat", "helmet", "gauntlets", "greaves", "sabatons" },
	int = { "robe", "cap", "mitts", "circlet", "slippers", "tiara", "cowl", "hood", "vestment", "cassock" },
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
	local isSceptre = archetype.sceptre
	local isCasterWeapon = isWand or isStaff or isSceptre
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
			if slot == "weapon" and not isCasterWeapon then
				t_insert(pool, { weight = 20, text = function() return "Adds " .. fmtRoll(30, 75) .. " to " .. fmtRoll(140, 280) .. " " .. dt .. " Damage" end })
			else
				t_insert(pool, { weight = 14, text = function() return "Adds " .. fmtRoll(5, 18) .. " to " .. fmtRoll(20, 65) .. " " .. dt .. " Damage to Attacks" end })
			end
		end
		return pool
	end

	local globalDmg = { weight = 16, text = function() return (randomRoll(60, 140)) .. "% increased " .. (isSpell and "Spell " or "") .. "Damage" end }
	local elemDmgWithAttacks = { weight = isAttack and 16 or 0, text = function() return (randomRoll(60, 140)) .. "% increased Elemental Damage with Attacks" end }
	local attackSpeed = { weight = isAttack and 14 or 0, text = function() return (randomRoll(20, 40)) .. "% increased Attack Speed" end }
	local castSpeed = { weight = (isSpell or isCasterWeapon) and 16 or 0, text = function() return (randomRoll(15, 35)) .. "% increased Cast Speed" end }
	local critChance = { weight = 10, text = function() return "+" .. randomRoll(1, 3) .. "% to Critical Hit Chance" end }
	local spellCritChance = { weight = isCasterWeapon and 12 or 0, text = function() return (randomRoll(50, 120)) .. "% increased Critical Hit Chance for Spells" end }
	local critMulti = { weight = 9, text = function() return "+" .. randomRoll(20, 55) .. "% to Critical Damage Bonus" end }
	local attackLevels = { weight = isAttack and 10 or 0, text = function() return "+" .. randomRoll(3, 5) .. " to Level of all Attack Skills" end }
	local spellLevels = { weight = (isSpell or isCasterWeapon) and 14 or 0, text = function() return "+" .. randomRoll(2, 5) .. " to Level of all Spell Skills" end }
	local additionalArrow = { weight = isBow and 10 or 0, text = function() return "Bow Attacks fire an additional Arrow" end }

	M.affixes.weapon = {}
	if isCasterWeapon then
		-- Spell weapons: prioritize spell damage, cast speed, +levels, crit for spells.
		for _, dt in ipairs(dmgTypes) do
			t_insert(M.affixes.weapon, { weight = 18, text = function() return "Adds " .. fmtRoll(20, 55) .. " to " .. fmtRoll(100, 220) .. " " .. dt .. " Damage to Spells" end })
		end
		t_insert(M.affixes.weapon, { weight = 22, text = function() return (randomRoll(80, 160)) .. "% increased Spell Damage" end })
		t_insert(M.affixes.weapon, { weight = 18, text = function() return (randomRoll(25, 55)) .. "% increased Cast Speed" end })
		t_insert(M.affixes.weapon, { weight = 16, text = function() return "+" .. randomRoll(2, 5) .. " to Level of all Spell Skills" end })
		t_insert(M.affixes.weapon, { weight = 14, text = function() return (randomRoll(60, 130)) .. "% increased Critical Hit Chance for Spells" end })
		t_insert(M.affixes.weapon, { weight = 14, text = function() return "Gain " .. randomRoll(10, 30) .. "% of Elemental Damage as Extra " .. (dmgTypes[1] or "Lightning") .. " Damage" end })
		t_insert(M.affixes.weapon, critMulti)
		if isSceptre then
			-- Minion sceptres can also roll minion levels/damage.
			t_insert(M.affixes.weapon, { weight = 10, text = function() return "+" .. randomRoll(1, 3) .. " to Level of all Minion Skills" end })
			t_insert(M.affixes.weapon, { weight = 10, text = function() return (randomRoll(60, 120)) .. "% increased Minion Damage" end })
		end
	else
		M.affixes.weapon = dmgPrefix("weapon")
		t_insert(M.affixes.weapon, globalDmg)
		if isAttack then
			t_insert(M.affixes.weapon, attackSpeed)
			t_insert(M.affixes.weapon, attackLevels)
		end
		if isBow then
			for _, dt in ipairs(dmgTypes) do
				t_insert(M.affixes.weapon, 1, { weight = 22, text = function() return "Adds " .. fmtRoll(30, 75) .. " to " .. fmtRoll(140, 280) .. " " .. dt .. " Damage" end })
			end
			t_insert(M.affixes.weapon, elemDmgWithAttacks)
			t_insert(M.affixes.weapon, additionalArrow)
		end
		t_insert(M.affixes.weapon, critChance)
		t_insert(M.affixes.weapon, critMulti)
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
	t_insert(M.affixes.gloves, { weight = 11, text = function() return "+" .. randomRoll(
		slot == "body" and 90 or (slot == "helmet" and 70 or (slot == "belt" and 80 or 60)),
		slot == "body" and 200 or (slot == "helmet" and 140 or (slot == "belt" and 160 or 130))
	) .. " to maximum Life" end })
	t_insert(M.affixes.gloves, { weight = 9, text = function() return "+" .. randomRoll(25, 55) .. "% to " .. (dmgTypes[1] or "Lightning") .. " Resistance" end })
	t_insert(M.affixes.gloves, { weight = 6, text = function() return "+" .. randomRoll(25, 55) .. "% to Fire Resistance" end })
	t_insert(M.affixes.gloves, { weight = 6, text = function() return "+" .. randomRoll(25, 55) .. "% to Cold Resistance" end })
	if isAttack then
		t_insert(M.affixes.gloves, { weight = 11, text = function() return (randomRoll(12, 30)) .. "% increased Attack Speed" end })
	end
	if isSpell then
		t_insert(M.affixes.gloves, { weight = 12, text = function() return (randomRoll(15, 35)) .. "% increased Cast Speed" end })
		t_insert(M.affixes.gloves, { weight = 10, text = function() return (randomRoll(25, 60)) .. "% increased Spell Damage" end })
	end
	if armourType == "dex" then
		t_insert(M.affixes.gloves, { weight = 8, text = function() return (randomRoll(20, 50)) .. "% increased Evasion Rating" end })
	elseif armourType == "int" then
		t_insert(M.affixes.gloves, { weight = 8, text = function() return (randomRoll(20, 50)) .. "% increased Energy Shield" end })
		t_insert(M.affixes.gloves, { weight = 7, text = function() return "+" .. randomRoll(30, 80) .. " to maximum Energy Shield" end })
	end

	M.affixes.helmet = {
		{ weight = 13, text = function() return "+" .. randomRoll(70, 150) .. " to maximum Life" end },
		{ weight = 9, text = function() return "+" .. randomRoll(25, 55) .. "% to " .. (dmgTypes[1] or "Lightning") .. " Resistance" end },
		{ weight = 7, text = function() return "+" .. randomRoll(25, 55) .. "% to Fire Resistance" end },
		{ weight = 7, text = function() return "+" .. randomRoll(25, 55) .. "% to Cold Resistance" end },
	}
	if isSpell then
		t_insert(M.affixes.helmet, { weight = 12, text = function() return (randomRoll(25, 60)) .. "% increased Spell Damage" end })
		t_insert(M.affixes.helmet, { weight = 10, text = function() return (randomRoll(20, 50)) .. "% increased Critical Hit Chance for Spells" end })
		t_insert(M.affixes.helmet, { weight = 8, text = function() return "+" .. randomRoll(20, 50) .. " to Intelligence" end })
	else
		t_insert(M.affixes.helmet, { weight = 7, text = function() return (randomRoll(15, 35)) .. "% increased Critical Hit Chance" end })
	end
	if armourType == "dex" then
		t_insert(M.affixes.helmet, { weight = 9, text = function() return (randomRoll(25, 55)) .. "% increased Evasion Rating" end })
	elseif armourType == "str" then
		t_insert(M.affixes.helmet, { weight = 9, text = function() return (randomRoll(25, 55)) .. "% increased Armour" end })
	elseif armourType == "int" then
		t_insert(M.affixes.helmet, { weight = 9, text = function() return (randomRoll(25, 55)) .. "% increased Energy Shield" end })
		t_insert(M.affixes.helmet, { weight = 7, text = function() return "+" .. randomRoll(40, 90) .. " to maximum Energy Shield" end })
	end

	M.affixes.body = {
		{ weight = 16, text = function() return "+" .. randomRoll(90, 200) .. " to maximum Life" end },
		{ weight = 10, text = function() return "+" .. randomRoll(30, 60) .. "% to " .. (dmgTypes[1] or "Lightning") .. " Resistance" end },
		{ weight = 9, text = function() return "+" .. randomRoll(30, 60) .. "% to Fire Resistance" end },
		{ weight = 9, text = function() return "+" .. randomRoll(30, 60) .. "% to Cold Resistance" end },
		{ weight = 7, text = function() return (randomRoll(6, 18)) .. "% increased maximum Life" end },
	}
	if isSpell then
		t_insert(M.affixes.body, { weight = 12, text = function() return (randomRoll(30, 70)) .. "% increased Spell Damage" end })
		t_insert(M.affixes.body, { weight = 8, text = function() return "+" .. randomRoll(30, 70) .. " to Intelligence" end })
	else
		t_insert(M.affixes.body, { weight = 5, text = function() return "+" .. randomRoll(25, 55) .. " to " .. primaryAttr end })
	end
	if armourType == "dex" then
		t_insert(M.affixes.body, { weight = 10, text = function() return (randomRoll(30, 60)) .. "% increased Evasion Rating" end })
	elseif armourType == "str" then
		t_insert(M.affixes.body, { weight = 10, text = function() return (randomRoll(30, 60)) .. "% increased Armour" end })
	elseif armourType == "int" then
		t_insert(M.affixes.body, { weight = 10, text = function() return (randomRoll(30, 60)) .. "% increased Energy Shield" end })
		t_insert(M.affixes.body, { weight = 8, text = function() return "+" .. randomRoll(60, 140) .. " to maximum Energy Shield" end })
	end

	M.affixes.boots = {
		{ weight = 13, text = function() return "+" .. randomRoll(60, 130) .. " to maximum Life" end },
		{ weight = 9, text = function() return "+" .. randomRoll(25, 55) .. "% to Cold Resistance" end },
		{ weight = 9, text = function() return "+" .. randomRoll(25, 55) .. "% to Lightning Resistance" end },
		{ weight = 9, text = function() return "+" .. randomRoll(25, 55) .. "% to Fire Resistance" end },
		{ weight = 6, text = function() return (randomRoll(20, 35)) .. "% increased Movement Speed" end },
	}
	if isSpell then
		t_insert(M.affixes.boots, { weight = 8, text = function() return (randomRoll(15, 35)) .. "% increased Spell Damage" end })
		t_insert(M.affixes.boots, { weight = 6, text = function() return "+" .. randomRoll(20, 45) .. " to Intelligence" end })
	else
		t_insert(M.affixes.boots, { weight = 5, text = function() return "+" .. randomRoll(20, 45) .. " to " .. primaryAttr end })
	end
	if armourType == "dex" then
		t_insert(M.affixes.boots, { weight = 8, text = function() return (randomRoll(20, 50)) .. "% increased Evasion Rating" end })
	elseif armourType == "str" then
		t_insert(M.affixes.boots, { weight = 8, text = function() return (randomRoll(20, 50)) .. "% increased Armour" end })
	elseif armourType == "int" then
		t_insert(M.affixes.boots, { weight = 8, text = function() return (randomRoll(20, 50)) .. "% increased Energy Shield" end })
		t_insert(M.affixes.boots, { weight = 6, text = function() return "+" .. randomRoll(30, 70) .. " to maximum Energy Shield" end })
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
		{ weight = 6, text = function() return "+" .. randomRoll(25, 55) .. " to " .. primaryAttr end },
	}
	if isSpell then
		t_insert(M.affixes.ring, { weight = 14, text = function() return (randomRoll(30, 70)) .. "% increased Spell Damage" end })
		t_insert(M.affixes.ring, { weight = 10, text = function() return "+" .. randomRoll(20, 50) .. " to Intelligence" end })
		t_insert(M.affixes.ring, { weight = 9, text = function() return (randomRoll(10, 25)) .. "% increased Cast Speed" end })
	else
		t_insert(M.affixes.ring, { weight = 10, text = function() return "Adds " .. fmtRoll(3, 12) .. " to " .. fmtRoll(15, 55) .. " " .. (dmgTypes[1] or "Lightning") .. " Damage to Attacks" end })
		t_insert(M.affixes.ring, { weight = 7, text = function() return (randomRoll(20, 50)) .. "% increased Elemental Damage with Attacks" end })
	end

	M.affixes.amulet = {
		{ weight = 12, text = function() return "+" .. randomRoll(50, 110) .. " to maximum Life" end },
		{ weight = 9, text = function() return "+" .. randomRoll(20, 45) .. " to Strength" end },
		{ weight = 10, text = function() return "+" .. randomRoll(25, 55) .. " to " .. primaryAttr end },
		{ weight = 8, text = function() return "+" .. randomRoll(20, 45) .. " to " .. secondaryAttr end },
		{ weight = 7, text = function() return "+" .. randomRoll(1, 3) .. "% to Critical Hit Chance" end },
		{ weight = 6, text = function() return "+" .. randomRoll(20, 50) .. "% to Critical Damage Bonus" end },
		{ weight = 6, text = function() return "+" .. randomRoll(25, 55) .. "% to " .. (dmgTypes[1] or "Lightning") .. " Resistance" end },
	}
	if isSpell then
		t_insert(M.affixes.amulet, { weight = 14, text = function() return (randomRoll(30, 70)) .. "% increased " .. (isSpell and "Spell " or "Elemental ") .. "Damage" end })
		t_insert(M.affixes.amulet, { weight = 10, text = function() return "+" .. randomRoll(1, 3) .. " to Level of all Spell Skills" end })
		t_insert(M.affixes.amulet, { weight = 8, text = function() return (randomRoll(10, 25)) .. "% increased Cast Speed" end })
	else
		t_insert(M.affixes.amulet, { weight = 9, text = function() return (randomRoll(25, 60)) .. "% increased " .. (isSpell and "Spell " or "Elemental ") .. "Damage" end })
	end
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

local function weightedPickWithoutReplacement(poolRef)
	local pool = poolRef[1]
	if not pool or #pool == 0 then
		return nil
	end
	local total = 0
	for _, entry in ipairs(pool) do
		total = total + entry.weight
	end
	if total <= 0 then
		return nil
	end
	local roll = math.random(1, total)
	for i, entry in ipairs(pool) do
		roll = roll - entry.weight
		if roll <= 0 then
			local text = entry.text()
			table.remove(pool, i)
			return text
		end
	end
	local entry = table.remove(pool, 1)
	return entry and entry.text()
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
	local poolCopy = { [1] = {} }
	for _, entry in ipairs(pool or {}) do
		t_insert(poolCopy[1], entry)
	end
	local chosen = {}

	-- Guarantee life + two resistances on armour and jewellery
	if slot ~= "weapon" and slot ~= "quiver" then
		t_insert(chosen, "+" .. randomRoll(
			slot == "body" and 90 or (slot == "helmet" and 70 or (slot == "belt" and 80 or 60)),
			slot == "body" and 200 or (slot == "helmet" and 140 or (slot == "belt" and 160 or 130))
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
		local pick = weightedPickWithoutReplacement(poolCopy)
		if pick then
			t_insert(chosen, pick)
		end
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
		M.archetype.sceptre = weaponType == "sceptre"
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
	elseif M.archetype.sceptre then
		weaponPred = function(b) return b:find("sceptre", 1, true) end
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
		M.basePools.weapon = M.filterValidBases("weapon", M.basePools.weapon)
		if M.archetype.bow then
			M.basePools.quiver = M.filterValidBases("quiver", { "Primed Quiver", "Broadhead Quiver" })
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
		armourPred = function(b) return b:find("robe") or b:find("cap") or b:find("mitts") or b:find("circlet") or b:find("slippers") or b:find("tiara") or b:find("cowl") or b:find("hood") end
	end
	if armourPred then
		for _, slot in ipairs({"helmet", "body", "gloves", "boots"}) do
			M.basePools[slot] = filterByType(M.basePools[slot], armourPred)
			M.basePools[slot] = M.filterValidBases(slot, M.basePools[slot])
		end
	end

	-- Belt, ring, amulet base pools are not type-filtered but should still be valid.
	for _, slot in ipairs({"belt", "ring", "amulet"}) do
		M.basePools[slot] = M.filterValidBases(slot, M.basePools[slot])
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

	-- Generate flasks and charms.
	local flaskCount = opts.flaskCount or 2
	local charmCount = opts.charmCount or 3
	for i = 1, flaskCount do
		t_insert(set, { slot = "Flask " .. i, raw = M.generateFlask(opts) })
	end
	for i = 1, charmCount do
		t_insert(set, { slot = "Charm " .. i, raw = M.generateCharm(opts) })
	end

	return set
end

function M.generateFlask(opts)
	opts = opts or {}
	local isLife = math.random() < 0.5
	local base
	if isLife then
		base = ({ "Transcendent Life Flask", "Gargantuan Life Flask", "Ultimate Life Flask" })[math.random(1, 3)]
	else
		base = ({ "Transcendent Mana Flask", "Gargantuan Mana Flask", "Ultimate Mana Flask" })[math.random(1, 3)]
	end
	local quality = opts.quality or 20
	local prefix = isLife and ((randomRoll(50, 80)) .. "% increased Amount Recovered") or ((randomRoll(50, 80)) .. "% increased Amount Recovered")
	local suffixPool = {
		"(21-25)% Chance to gain a Charge when you kill an enemy",
		"(41-45)% increased Recovery rate",
		"Gains 0.15 Charges per Second",
		"(23-30)% increased Charges gained",
	}
	if isLife then
		t_insert(suffixPool, "Grants Immunity to Bleeding for (6-8) seconds if used while Bleeding\nGrants Immunity to Corrupted Blood for (6-8) seconds if used while affected by Corrupted Blood")
		t_insert(suffixPool, "Grants Immunity to Ignite for (6-8) seconds if used while Ignited\nRemoves all Burning when used")
		t_insert(suffixPool, "Grants Immunity to Freeze and Chill for (6-8) seconds if used while Frozen")
		t_insert(suffixPool, "Grants Immunity to Shock for (6-8) seconds if used while Shocked")
		t_insert(suffixPool, "Grants Immunity to Poison for (6-8) seconds if used while Poisoned")
	else
		t_insert(suffixPool, "(20-23)% of Recovery applied Instantly")
	end
	local suffix = suffixPool[math.random(1, #suffixPool)]
	return table.concat({
		"New Item",
		base,
		"Quality: " .. quality,
		"Implicits: 0",
		prefix,
		suffix,
	}, "\n")
end

function M.generateCharm(opts)
	opts = opts or {}
	local charmTypes = { "Staunching Charm", "Dousing Charm", "Thawing Charm", "Grounding Charm", "Antidote Charm", "Amethyst Charm" }
	local base = charmTypes[math.random(1, #charmTypes)]
	local suffixPool = {
		"(23-30)% increased Charges gained",
		"(21-25)% Chance to gain a Charge when you kill an enemy",
		"Recover (35-52) Life when Used",
		"Recover (33-50) Mana when Used",
		"Also grants (85-128) Guard",
		"(21-25)% increased Duration",
	}
	local suffix = suffixPool[math.random(1, #suffixPool)]
	return table.concat({
		"New Item",
		base,
		"Implicits: 1",
		"Used when you take damage",
		suffix,
	}, "\n")
end

return M
