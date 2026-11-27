local _, ns = ...

-- Built-in defaults for the spell list (Modules/SpellList.lua), which the player can
-- toggle, remove and extend. Detection does NOT depend on it
-- (C_Spell.IsSpellCrowdControl classifies live casts); it drives the per-spell on/off
-- for readable casts.
-- `class` is the player class that casts it (NPCs can cast some too); the spell list
-- groups by it so players learn where each CC comes from.
-- Main IDs verified 2026-11-27 against Blizzard's retail game data: spec talent trees,
-- PvP talents and baseline spells. Seduction is a pet ability, which that data does not cover.
-- `related`: the other IDs sharing the spell's name in current game data, from
-- MiniAuras' generated SpellNameIndex. Look variants (Polymorph: Pig, Hex: Spider...)
-- are separate cast IDs, listed so the on/off covers them too.
ns.CastableCC = {
	{ id = 118, class = "MAGE", name = "Polymorph", related = {
		28271, 28272, 61025, 61305, 61721, 61780, 126819, 161353, 161354, 161355, 161372,
		277787, 277792, 321395, 391622, 460392, 29124, 71319, 218434, 219393, 219394, 219398,
		219399, 219400, 219401, 219402, 219403, 219404, 219405, 219406, 219407, 240134, 277788,
		277793, 302583, 391631, 460396, 461489,
	} },
	{ id = 383121, class = "MAGE", name = "Mass Polymorph" },
	{ id = 33786, class = "DRUID", name = "Cyclone", related = { 88010, 373248 } },
	{ id = 2637, class = "DRUID", name = "Hibernate" },
	{ id = 339, class = "DRUID", name = "Entangling Roots", related = {
		22800, 40363, 66070, 170855, 201192, 201589, 235963, 247564, 330873, 373249, 460614,
	} },
	{ id = 360806, class = "EVOKER", name = "Sleep Walk" },
	{ id = 198898, class = "MONK", name = "Song of Chi-Ji", related = { 198909 } },
	-- 5782 is the cast; it applies the 118699 debuff.
	{ id = 5782, class = "WARLOCK", name = "Fear", related = { 118699, 130616, 251419 } },
	{ id = 6358, class = "WARLOCK", name = "Seduction", related = { 261589 } },
	{ id = 710, class = "WARLOCK", name = "Banish" },
	{ id = 605, class = "PRIEST", name = "Mind Control" },
	{ id = 205364, class = "PRIEST", name = "Dominate Mind" },
	-- Shackle Undead was renamed Shackle Horror; same ID.
	{ id = 9484, class = "PRIEST", name = "Shackle Horror" },
	{ id = 51514, class = "SHAMAN", name = "Hex", related = {
		210873, 211004, 211010, 211015, 269352, 277778, 277784, 309328, 196942, 219215, 219216,
		219217, 219218, 219219, 254412, 269355, 277780, 277785, 309329,
	} },
	{ id = 305483, class = "SHAMAN", name = "Lightning Lasso", related = { 204437, 305484, 305485, 371792 } },
	{ id = 10326, class = "PALADIN", name = "Turn Evil", related = { 145067 } },
	{ id = 1513, class = "HUNTER", name = "Scare Beast" },
}

-- Group order in the spell list (alphabetical). Every class is listed because added
-- spells can go under any of them; empty groups stay hidden. Uncategorized comes last.
ns.ClassOrder = {
	"DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER", "MAGE", "MONK",
	"PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
}
