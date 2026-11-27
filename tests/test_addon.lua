-- Each T[...] runs in a fresh Lua state with the addon loaded (see addon_spec.lua).
T = {}
local M = TEST
local S = M.secret

local function boot()
	M.fire("ADDON_LOADED", "AlertCCOnMe")
	M.fire("PLAYER_LOGIN")
end

local function eq(actual, expected, msg)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(msg or "eq", tostring(expected), tostring(actual)), 2)
	end
end

local function visible(key)
	local slot = ns.Display.GetSlot(key)
	if not slot then
		return false
	end
	return M.effectiveAlpha(slot.text) > 0
end

local function polyCast(opts)
	opts = opts or {}
	local wrap = opts.secret and S or function(v) return v end
	return {
		kind = opts.kind or "cast",
		name = wrap("Polymorph"),
		texture = wrap(136071),
		startMs = wrap(M.time * 1000),
		endMs = wrap(M.time * 1000 + 1700),
		spellID = (opts.secret and not opts.readableSpell) and S(opts.spellID or 118) or (opts.spellID or 118),
		onMe = opts.onMeSecret and S(opts.onMe ~= false) or (opts.onMe ~= false),
	}
end

T["loads and registers settings without errors"] = function()
	boot()
	assert(ns.db and ns.db.Enabled, "db initialised")
	assert(SlashCmdList.ALERTCCONME, "slash registered")
	local count = 0
	for _ in pairs(M.settings) do count = count + 1 end
	assert(count >= 20, "settings registered: " .. count)
end

T["open world: readable polymorph on me shows alert and plays sound"] = function()
	boot()
	M.units.target = { hostile = true, isPlayer = true, unitTargetIsMe = true, cast = polyCast() }
	M.fireUnit("UNIT_SPELLCAST_START", "target")
	assert(visible("target"), "alert visible")
	eq(#M.sounds, 1, "one pre-cast sound")
	eq(M.sounds[1], [[Interface\AddOns\AlertCCOnMe\Media\Voice\David\SheepOnYou.ogg]], "voice callout")
	local slot = ns.Display.GetSlot("target")
	eq(slot.text.formatArgs[1], "Polymorph", "spell name passed to text")
end

T["open world: readable polymorph on someone else stays hidden and silent"] = function()
	boot()
	M.units.target = { hostile = true, isPlayer = true, unitTargetIsMe = false, cast = polyCast({ onMe = false }) }
	M.fireUnit("UNIT_SPELLCAST_START", "target")
	assert(not visible("target"), "alert hidden")
	eq(#M.sounds, 0, "no sound")
end

T["non-CC cast on me is hidden when RequireCC"] = function()
	boot()
	M.units.target = { hostile = true, isPlayer = true, unitTargetIsMe = true, cast = polyCast({ spellID = 116 }) }
	M.fireUnit("UNIT_SPELLCAST_START", "target")
	assert(not visible("target"), "frostbolt hidden")
	eq(#M.sounds, 0, "no sound")
	ns.db.RequireCC = false
	M.fireUnit("UNIT_SPELLCAST_START", "target")
	assert(visible("target"), "frostbolt shown when RequireCC off")
end

T["arena fully secret: visual works via secret gates, CONFIRMED stays silent"] = function()
	boot()
	M.instanceType = "arena"
	M.units.arena1 = { hostile = true, isPlayer = true, unitTargetIsMe = S(true),
		cast = polyCast({ secret = true, onMeSecret = true }) }
	M.fireUnit("UNIT_SPELLCAST_START", "arena1")
	assert(visible("arena1"), "secret-gated alert renders")
	local slot = ns.Display.GetSlot("arena1")
	assert(issecretvalue(slot.meGate.alphaFromBool), "onMe gate fed a secret")
	assert(issecretvalue(slot.ccGate.alphaFromBool), "cc gate fed a secret")
	eq(#M.sounds, 0, "no confirmed sound possible")
end

T["arena fully secret: polymorph on teammate renders nothing"] = function()
	boot()
	M.instanceType = "arena"
	M.units.arena1 = { hostile = true, isPlayer = true, unitTargetIsMe = S(false),
		cast = polyCast({ secret = true, onMeSecret = true, onMe = false }) }
	M.fireUnit("UNIT_SPELLCAST_START", "arena1")
	assert(not visible("arena1"), "hidden by secret gate")
end

T["arena ANY_PLAYER_CAST mode plays on secret casts"] = function()
	boot()
	M.instanceType = "arena"
	ns.db.Sound.Mode = "ANY_PLAYER_CAST"
	M.units.arena1 = { hostile = true, isPlayer = true, unitTargetIsMe = S(true),
		cast = polyCast({ secret = true, onMeSecret = true }) }
	M.fireUnit("UNIT_SPELLCAST_START", "arena1")
	eq(#M.sounds, 1, "heuristic sound")
end

T["NeverSecret CC with secret target: CC_ANY_TARGET plays, CONFIRMED does not"] = function()
	boot()
	M.instanceType = "arena"
	M.units.arena1 = { hostile = true, isPlayer = true, unitTargetIsMe = S(true),
		cast = polyCast({ secret = true, readableSpell = true, onMeSecret = true }) }
	M.fireUnit("UNIT_SPELLCAST_START", "arena1")
	eq(#M.sounds, 0, "confirmed silent")
	ns.db.Sound.Mode = "CC_ANY_TARGET"
	M.tick(2)
	M.fireUnit("UNIT_SPELLCAST_START", "arena1")
	eq(#M.sounds, 1, "dbm-style sound")
end

T["stop event hides the alert"] = function()
	boot()
	M.units.target = { hostile = true, isPlayer = true, unitTargetIsMe = true, cast = polyCast() }
	M.fireUnit("UNIT_SPELLCAST_START", "target")
	assert(visible("target"))
	M.units.target.cast = nil
	M.fireUnit("UNIT_SPELLCAST_STOP", "target")
	assert(not visible("target"), "hidden after stop")
end

T["channel is detected"] = function()
	boot()
	M.units.focus = { hostile = true, isPlayer = true, unitTargetIsMe = true, cast = polyCast({ kind = "channel", spellID = 5782 }) }
	M.fireUnit("UNIT_SPELLCAST_CHANNEL_START", "focus")
	assert(visible("focus"), "channel shown")
end

T["friendly caster is ignored"] = function()
	boot()
	M.units.target = { hostile = false, isPlayer = true, unitTargetIsMe = true, cast = polyCast() }
	M.fireUnit("UNIT_SPELLCAST_START", "target")
	assert(not visible("target"))
	eq(#M.sounds, 0)
end

T["arena dedupe: player nameplate skipped, arena token used"] = function()
	boot()
	M.instanceType = "arena"
	local cast = polyCast()
	M.units.arena1 = { hostile = true, isPlayer = true, unitTargetIsMe = true, cast = cast }
	M.units.nameplate3 = { hostile = true, isPlayer = true, unitTargetIsMe = true, cast = cast }
	M.fireUnit("UNIT_SPELLCAST_START", "nameplate3")
	M.fireUnit("UNIT_SPELLCAST_START", "arena1")
	assert(not visible("nameplate3"), "nameplate duplicate hidden")
	assert(visible("arena1"), "arena shown")
	eq(#M.sounds, 1, "single sound")
end

T["target with nameplate defers to nameplate"] = function()
	boot()
	local cast = polyCast()
	M.units.target = { hostile = true, isPlayer = true, unitTargetIsMe = true, cast = cast }
	M.units.nameplate1 = M.units.target
	M.nameplates.target = {}
	M.fireUnit("UNIT_SPELLCAST_START", "target")
	M.fireUnit("UNIT_SPELLCAST_START", "nameplate1")
	assert(not visible("target"), "target duplicate hidden")
	assert(visible("nameplate1"), "nameplate shown")
end

T["sound throttle suppresses rapid repeats"] = function()
	boot()
	M.units.target = { hostile = true, isPlayer = true, unitTargetIsMe = true, cast = polyCast() }
	M.fireUnit("UNIT_SPELLCAST_START", "target")
	M.fireUnit("UNIT_SPELLCAST_START", "target")
	eq(#M.sounds, 1, "throttled")
	M.tick(1.5)
	M.fireUnit("UNIT_SPELLCAST_START", "target")
	eq(#M.sounds, 2, "plays again after throttle")
end

T["safety timeout hides a cast whose stop event was missed"] = function()
	boot()
	M.units.target = { hostile = true, isPlayer = true, unitTargetIsMe = true, cast = polyCast() }
	M.fireUnit("UNIT_SPELLCAST_START", "target")
	M.tick(ns.CAST_SAFETY_TIMEOUT + 1)
	assert(not visible("target"), "timed out")
end

T["test command and probe run without errors"] = function()
	boot()
	SlashCmdList.ALERTCCONME("test")
	assert(visible("test"), "test alert visible")
	eq(#M.sounds, 1, "test sound")
	M.units.target = { hostile = true, isPlayer = true, unitTargetIsMe = S(true), cast = polyCast({ secret = true, onMeSecret = true }) }
	SlashCmdList.ALERTCCONME("probe")
	SlashCmdList.ALERTCCONME("probe 118")
	SlashCmdList.ALERTCCONME("status")
	SlashCmdList.ALERTCCONME("debug")
	M.fireUnit("UNIT_SPELLCAST_START", "target")
	SlashCmdList.ALERTCCONME("unlock")
	SlashCmdList.ALERTCCONME("lock")
	SlashCmdList.ALERTCCONME("reset")
	SlashCmdList.ALERTCCONME("")
	assert(M.openedSettings, "settings opened")
end

T["unsafe text format is rejected"] = function()
	assert(ns.Util.IsSafeFormat("%s on YOU!"))
	assert(ns.Util.IsSafeFormat("100%% %s"))
	assert(not ns.Util.IsSafeFormat("%d %s"))
	assert(not ns.Util.IsSafeFormat("no placeholder"))
	assert(not ns.Util.IsSafeFormat("%s %s"))
end

T["ShouldPlaySound truth table"] = function()
	local f = ns.CastEval.ShouldPlaySound
	local C, A, P = "CONFIRMED", "CC_ANY_TARGET", "ANY_PLAYER_CAST"
	eq(f(C, true, { isCCReadable = true, onMeReadable = true }, true), true, "C cc+me")
	eq(f(C, true, { isCCReadable = true }, true), false, "C me unknown")
	eq(f(A, true, { isCCReadable = true }, true), true, "A me unknown")
	eq(f(A, true, { isCCReadable = true, onMeReadable = false }, true), false, "A not me")
	eq(f(A, true, {}, true), false, "A cc unknown")
	eq(f(P, true, {}, true), true, "P unknown all")
	eq(f(P, true, {}, nil), false, "P not a player")
	eq(f(P, true, { isCCReadable = false }, true), false, "P known non-cc")
	eq(f(P, false, { isCCReadable = false }, true), true, "P requireCC off")
	eq(f(C, false, { onMeReadable = true }, true), true, "C requireCC off")
end

T["edit box: shift-drag moves, shift-wheel scales, right-click locks"] = function()
	boot()
	local a = _G.AlertCCOnMeAnchor
	local moves = 0
	a.StartMoving = function() moves = moves + 1 end

	M.shift = true
	a.scripts.OnDragStart(a)
	eq(moves, 0, "locked frame does not move")

	SlashCmdList.ALERTCCONME("move")
	assert(ns.db.Locked == false, "move unlocks")
	assert(visible("test"), "preview shown in edit mode")

	M.shift = false
	a.scripts.OnDragStart(a)
	eq(moves, 0, "plain drag ignored")
	a.scripts.OnMouseWheel(a, 1)
	eq(ns.db.Scale, 1, "plain wheel ignored")

	M.shift = true
	a.scripts.OnDragStart(a)
	a.scripts.OnDragStop(a)
	eq(moves, 1, "shift-drag moves")
	a.scripts.OnMouseWheel(a, 1)
	eq(ns.db.Scale, 1.05, "shift-wheel up")
	for _ = 1, 50 do a.scripts.OnMouseWheel(a, -1) end
	eq(ns.db.Scale, 0.5, "scale clamped")

	a.scripts.OnMouseUp(a, "RightButton")
	assert(ns.db.Locked == true, "right-click locks")
	assert(not visible("test"), "preview hidden after lock")
end

T["voice: hidden spell falls back to alarm, off uses alarm, unknown CC is generic"] = function()
	boot()
	ns.db.Sound.Mode = ns.SoundModes.ANY_PLAYER_CAST
	M.units.arena1 = { hostile = true, isPlayer = true, cast = polyCast({ secret = true, onMeSecret = true }) }
	M.fireUnit("UNIT_SPELLCAST_START", "arena1")
	eq(#M.sounds, 1, "any-cast sound in arena")
	assert(M.sounds[1]:find("Alarm.ogg", 1, true), "secret spell -> alarm, got " .. M.sounds[1])

	local clip = ns.Sound.PickCallout({ spellID = 999999 }, { isCCReadable = true, onMeReadable = true })
	eq(clip, "CCOnYou", "readable CC not in list")
	eq(ns.Sound.PickCallout({ spellID = 118 }, { isCCReadable = true }), "Sheep", "target unknown -> no 'on you'")
	eq(ns.Sound.PickCallout({ spellID = S(118) }, { isCCReadable = true, onMeReadable = true }), "CCOnYou", "secret ID never indexed")
	eq(ns.Sound.PickCallout({ spellID = 116 }, { isCCReadable = false, onMeReadable = true }), nil, "non-CC with RequireCC")
	ns.db.RequireCC = false
	eq(ns.Sound.PickCallout({ spellID = 116 }, { isCCReadable = false, onMeReadable = true }), "CastOnYou", "non-CC without RequireCC")

	ns.db.Sound.VoicePack = "Zira"
	assert(ns.Sound.VoicePath("FearOnYou"):find([[Voice\Zira\FearOnYou.ogg]], 1, true), "pack selection")
	ns.db.Sound.VoicePack = "Bogus"
	assert(ns.Sound.VoicePath("FearOnYou"):find([[Voice\David\FearOnYou.ogg]], 1, true), "unknown pack falls back")
end

T["list prints every listed CC with state and flags name mismatches"] = function()
	boot()
	M.spellNames[710] = "Not Banish"
	ns.SpellList.SetEnabled(5782, false)
	SlashCmdList.ALERTCCONME("list")
	local text = table.concat(M.chat, "\n")
	assert(text:find("118  Polymorph -> Polymorph -> \"Sheep\"  (+38 related IDs)", 1, true), "poly line")
	assert(text:find("5782  Fear -> Fear -> \"Fear\"  (+3 related IDs)  |cffff9900OFF", 1, true), "off tag")
	assert(text:find("710  Banish -> Not Banish -> \"Banish\"  |cffff5555MISMATCH", 1, true), "mismatch flagged")
end

local function spellRow(spellID)
	for _, init in ipairs(M.spellLayout.inits) do
		if init.setting and init.setting.var == "AlertCCOnMe_Spell_" .. spellID then
			return init
		end
	end
end

local function shownRows()
	local count = 0
	for _, init in ipairs(M.spellLayout.inits) do
		if init.setting and init:ShouldShow() then
			count = count + 1
		end
	end
	return count
end

T["spell list: native rows toggle, remove, add and restore"] = function()
	boot()
	eq(shownRows(), #ns.CastableCC, "one row per built-in")
	local poly = spellRow(118)
	assert(poly.setting.name:find("^|T%d+:") and poly.setting.name:find("Polymorph", 1, true)
		and poly.setting.name:find("118", 1, true), "row label has icon, name, ID: " .. poly.setting.name)
	eq(poly.buttonText, "X", "remove button")

	-- Off: a readable Polymorph on me is ignored.
	poly.setting:SetValue(false)
	eq(ns.db.SpellList[118].enabled, false, "saved off")
	M.units.target = { hostile = true, isPlayer = true, unitTargetIsMe = true, cast = polyCast() }
	M.fireUnit("UNIT_SPELLCAST_START", "target")
	assert(not visible("target"), "disabled spell hidden")
	eq(#M.sounds, 0, "disabled spell silent")
	poly.setting:SetValue(true)
	eq(ns.db.SpellList[118], nil, "back on stores nothing")
	assert(poly.setting:GetValue() == true, "proxy reads list")

	-- X hides the row; /accm add brings it back.
	local repairs = M.repairs or 0
	poly.onClick()
	assert(not poly:ShouldShow(), "removed row hidden")
	assert((M.repairs or 0) > repairs, "panel repaired")
	eq(ns.db.SpellList[118].removed, true, "removal saved")
	SlashCmdList.ALERTCCONME("add 118")
	assert(poly:ShouldShow(), "re-added row shown")

	-- Custom spell through the native popup.
	for _, init in ipairs(M.spellLayout.inits) do
		if init.name == ns.L.BtnAddSpell then init.onClick() end
	end
	eq(M.popup, "ALERTCCONME_ADD_SPELL", "add popup opened")
	M.spellNames[5555] = "Test Stun"
	local popup = StaticPopupDialogs.ALERTCCONME_ADD_SPELL
	popup.OnAccept({ EditBox = { GetText = function() return "5555" end } })
	local custom = spellRow(5555)
	assert(custom and custom:ShouldShow(), "custom row added")
	assert(custom.setting.name:find("(added)", 1, true), "custom tag")
	eq(ns.Sound.PickCallout({ spellID = 5555 }, { isCCReadable = true, onMeReadable = true }), "CCOnYou", "custom spell gets generic callout")

	M.chat = {}
	SlashCmdList.ALERTCCONME("add 4242")
	assert(M.chat[1]:find("no spell with ID 4242", 1, true), "unknown ID rejected")
	SlashCmdList.ALERTCCONME("add 5555")
	assert(M.chat[2]:find("already in the list", 1, true), "duplicate rejected")
	SlashCmdList.ALERTCCONME("add |cff71d5ff|Hspell:33786:0|h[Cyclone]|h|r")
	assert(M.chat[3]:find("already in the list", 1, true), "spell link parsed")

	SlashCmdList.ALERTCCONME("remove 5555")
	eq(ns.db.SpellList[5555], nil, "custom forgotten")
	assert(not custom:ShouldShow(), "custom row hidden")

	spellRow(710).onClick()
	spellRow(605).setting:SetValue(false)
	ns.SpellList.RestoreBuiltins()
	assert(spellRow(710):ShouldShow() and spellRow(605).setting:GetValue(), "built-ins restored")
	eq(next(ns.db.SpellList), nil, "nothing left saved")
end

T["spell list: grouped under class headers with icon, hidden when empty"] = function()
	boot()
	-- Layout order: each class header, then that class's spells.
	local current, seen = nil, {}
	for _, init in ipairs(M.spellLayout.inits) do
		if init.header then
			current = init
		elseif init.setting then
			local spellID = tonumber(init.setting.var:match("_Spell_(%d+)$"))
			seen[spellID] = current.header
		end
	end
	for _, spell in ipairs(ns.CastableCC) do
		local header = seen[spell.id]
		assert(header and header:find("classicon-" .. spell.class:lower(), 1, true),
			("%d under its class header, got %s"):format(spell.id, tostring(header)))
		assert(header:find(LOCALIZED_CLASS_NAMES_MALE[spell.class], 1, true), "class name in header")
	end

	local function headerFor(text)
		for _, init in ipairs(M.spellLayout.inits) do
			if init.header and init.header:find(text, 1, true) then return init end
		end
	end
	local mage = headerFor("classicon-mage")
	assert(mage:ShouldShow(), "mage header shown")
	eq(mage.tooltip, nil, "class headers have no tooltip")
	SlashCmdList.ALERTCCONME("remove 118")
	assert(mage:ShouldShow(), "still one mage spell")
	SlashCmdList.ALERTCCONME("remove 383121")
	assert(not mage:ShouldShow(), "empty mage header hidden")
	SlashCmdList.ALERTCCONME("add 118")
	assert(mage:ShouldShow(), "mage header back")

	local uncategorized = headerFor(ns.L.ListUncategorized)
	assert(not uncategorized:ShouldShow(), "no added spells yet")
	M.spellNames[5555] = "Test Stun"
	SlashCmdList.ALERTCCONME("add 5555")
	assert(uncategorized:ShouldShow(), "uncategorized header shown")
	local last = M.spellLayout.inits[#M.spellLayout.inits]
	eq(last.setting.var, "AlertCCOnMe_Spell_5555", "classless spell goes under Uncategorized")

	M.chat = {}
	SlashCmdList.ALERTCCONME("list")
	local text = table.concat(M.chat, "\n")
	local mageAt = text:find("classicon-mage", 1, true)
	local polyAt = text:find("118  Polymorph", 1, true)
	assert(mageAt and polyAt and mageAt < polyAt, "list groups under class header")
end

T["voice packs: add-ons register extra packs, unknown packs fall back to built-in"] = function()
	boot()
	eq(#ns.VoicePacks, 3, "three built-in packs")
	assert(AlertCCOnMe_RegisterVoicePack("Grampa", [[Interface\AddOns\AlertCCOnMe_Voice_Grampa\Voice]]), "registered")
	assert(not AlertCCOnMe_RegisterVoicePack("Grampa", [[Interface\AddOns\Other\]]), "duplicate name refused")
	assert(not AlertCCOnMe_RegisterVoicePack("David", [[Interface\AddOns\Other\]]), "built-in name refused")
	assert(not AlertCCOnMe_RegisterVoicePack("", "x") and not AlertCCOnMe_RegisterVoicePack("x", nil), "bad args refused")

	ns.db.Sound.VoicePack = "Grampa"
	eq(ns.Sound.VoicePath("HexOnYou"), [[Interface\AddOns\AlertCCOnMe_Voice_Grampa\Voice\HexOnYou.ogg]], "pack path, trailing slash added")
	M.units.target = { hostile = true, isPlayer = true, unitTargetIsMe = true, cast = polyCast() }
	M.fireUnit("UNIT_SPELLCAST_START", "target")
	eq(M.sounds[1], [[Interface\AddOns\AlertCCOnMe_Voice_Grampa\Voice\SheepOnYou.ogg]], "pre-cast uses the registered pack")

	ns.db.Sound.VoicePack = "Uninstalled"
	eq(ns.Sound.VoicePath("HexOnYou"), [[Interface\AddOns\AlertCCOnMe\Media\Voice\David\HexOnYou.ogg]], "missing pack falls back to David")
end

T["spell row template: label fills the width, on/off and X are narrow action columns"] = function()
	boot()
	eq(spellRow(118).template, "AlertCCOnMeSpellRowTemplate", "rows use the table-layout template")
	eq(spellRow(118).data.buttonText, "X", "remove action")

	local row = setmetatable({}, { __index = function(t, k)
		local own = rawget(AlertCCOnMeSpellRowMixin, k)
		if own ~= nil then return own end
		return CreateFrame("Frame")[k]
	end })
	row.log, row.points, row.scripts = {}, {}, {}
	row:OnLoad()
	row:Init({})

	local function call(widget, method)
		for _, entry in ipairs(widget.log) do
			if entry[1] == method then return entry end
		end
	end
	local size = call(row.Button, "SetSize")
	eq(size[2], 26, "X is checkbox-sized (width)")
	eq(size[3], 26, "X is checkbox-sized (height)")
	local buttonPoint = row.Button.points[#row.Button.points]
	eq(buttonPoint[1], "RIGHT", "X on the right edge")
	eq(buttonPoint[2], row, "X anchored to the row")
	local checkPoint = row.Checkbox.points[#row.Checkbox.points]
	assert(checkPoint[1] == "RIGHT" and checkPoint[2] == row.Button and checkPoint[3] == "LEFT", "checkbox just left of X")
	local textPoint = row.Text.points[#row.Text.points]
	assert(textPoint[1] == "RIGHT" and textPoint[2] == row.Checkbox and textPoint[3] == "LEFT",
		"label runs up to the checkbox, not the row center")
end

-- The header a row sits under, by walking back through the layout.
local function sectionOf(spellID)
	local current
	for _, init in ipairs(M.spellLayout.inits) do
		if init.header then
			current = init.header
		elseif init.setting and init.setting.var == "AlertCCOnMe_Spell_" .. spellID then
			return current
		end
	end
end

T["spell list: added spells go under the class given, or Uncategorized"] = function()
	boot()
	M.spellNames[5555], M.spellNames[6666], M.spellNames[7777] = "Test Stun", "Test Fear", "Test Root"

	SlashCmdList.ALERTCCONME("add 5555 monk")
	assert(sectionOf(5555):find("classicon-monk", 1, true), "under Monk: " .. tostring(sectionOf(5555)))
	-- After Song of Chi-Ji, before the next class header.
	local songAt, customAt
	for i, init in ipairs(M.spellLayout.inits) do
		if init.setting and init.setting.var == "AlertCCOnMe_Spell_198898" then songAt = i end
		if init.setting and init.setting.var == "AlertCCOnMe_Spell_5555" then customAt = i end
	end
	eq(customAt, songAt + 1, "appended at the end of the Monk section")
	eq(ns.db.SpellList[5555].class, "MONK", "class saved")

	SlashCmdList.ALERTCCONME("add 6666 Death Knight")
	assert(sectionOf(6666):find("classicon-deathknight", 1, true), "new Death Knight section shown")
	SlashCmdList.ALERTCCONME("add 7777 dh")
	eq(ns.db.SpellList[7777].class, "DEMONHUNTER", "dh alias")

	M.chat = {}
	SlashCmdList.ALERTCCONME("add 5555 rogue")
	assert(M.chat[1]:find("moved to Rogue", 1, true), "move message: " .. M.chat[1])
	assert(sectionOf(5555):find("classicon-rogue", 1, true), "row moved to Rogue")
	local count = 0
	for _, init in ipairs(M.spellLayout.inits) do
		if init.setting and init.setting.var == "AlertCCOnMe_Spell_5555" then count = count + 1 end
	end
	eq(count, 1, "row moved, not duplicated")

	SlashCmdList.ALERTCCONME("add 8888 bogus")
	assert(M.chat[2]:find("unknown class", 1, true), "unknown class rejected")
	eq(ns.db.SpellList[8888], nil, "nothing saved")
	SlashCmdList.ALERTCCONME("add |cff71d5ff|Hspell:9999:0|h[Test]|h|r shaman")
	M.spellNames[9999] = "Test Link"
	SlashCmdList.ALERTCCONME("add |cff71d5ff|Hspell:9999:0|h[Test]|h|r shaman")
	eq(ns.db.SpellList[9999].class, "SHAMAN", "link plus class")

	local groups = ns.SpellList.GetGroups()
	eq(groups[#groups].class, "WARLOCK", "no Uncategorized group when every added spell has a class")
end

T["performance: a readable no opens no frame; expiry is a timer, not OnUpdate"] = function()
	boot()
	-- Readable non-CC at me, and readable CC at someone else: nothing to gate, no frame.
	M.units.target = { hostile = true, isPlayer = true, unitTargetIsMe = true, cast = polyCast({ spellID = 116 }) }
	M.fireUnit("UNIT_SPELLCAST_START", "target")
	M.units.focus = { hostile = true, isPlayer = true, unitTargetIsMe = false, cast = polyCast({ onMe = false }) }
	M.fireUnit("UNIT_SPELLCAST_START", "focus")
	eq(ns.Display.CountShown(), 0, "no frames for readable no's")

	-- Hidden values still need the gated frame.
	M.units.arena1 = { hostile = true, isPlayer = true, cast = polyCast({ secret = true, onMeSecret = true, onMe = false }) }
	M.fireUnit("UNIT_SPELLCAST_START", "arena1")
	eq(ns.Display.CountShown(), 1, "secret cast keeps its gated frame")
	assert(ns.Display.GetSlot("arena1").scripts.OnUpdate == nil, "no per-frame handler")
	M.tick(ns.CAST_SAFETY_TIMEOUT + 1)
	eq(ns.Display.CountShown(), 0, "safety timer hides it")
end

T["perf command reports profiler, memory and frames"] = function()
	boot()
	SlashCmdList.ALERTCCONME("perf")
	assert(table.concat(M.chat, "\n"):find("profiler is off", 1, true), "graceful without profiler")
	Enum.AddOnProfilerMetric = { RecentAverageTime = 1, SessionAverageTime = 0, PeakTime = 4, CountTimeOver1Ms = 5, CountTimeOver5Ms = 6 }
	C_AddOnProfiler = {
		IsEnabled = function() return true end,
		GetAddOnMetric = function(name, metric) assert(name == "AlertCCOnMe"); return metric == 4 and 0.5 or 0.01 end,
		GetOverallMetric = function() return 2.5 end,
	}
	GetAddOnMemoryUsage = function() return 123.4 end
	UpdateAddOnMemoryUsage = function() end
	M.chat = {}
	SlashCmdList.ALERTCCONME("perf")
	local text = table.concat(M.chat, "\n")
	assert(text:find("recent 0.010 ms", 1, true) and text:find("peak 0.50 ms", 1, true), "cpu line: " .. text)
	assert(text:find("all addons recent: 2.500 ms", 1, true), "overall comparison")
	assert(text:find("memory: 123 KB", 1, true), "memory line")
	assert(text:find("alert frames shown now: 0", 1, true), "frames line")
end

T["fuzz: free-text inputs never raise (add/remove/slash/text format)"] = function()
	boot()
	math.randomseed(1234)
	local pieces = { "118", "monk", " ", "|", "|H", "spell:", "|h[", "]|h|r", "%", "%s", "%d", "%%", "%n",
		"\0", "\n", "-1", "0", "99999999999999999999", "death knight", "dk", "'", '"', "\\", "::", "Ω", "🙂",
		"|cffff0000", "|T", ":0|t", "nil", "1e309", "0x10" }
	local function randomText()
		local parts = {}
		for i = 1, math.random(0, 8) do
			parts[i] = pieces[math.random(#pieces)]
		end
		return table.concat(parts)
	end
	for _ = 1, 3000 do
		local text = randomText()
		local ok, err = pcall(ns.SpellList.Add, text)
		assert(ok, ("Add(%q) raised: %s"):format(text, tostring(err)))
		ok, err = pcall(SlashCmdList.ALERTCCONME, "remove " .. text)
		assert(ok, ("remove %q raised: %s"):format(text, tostring(err)))
		ok, err = pcall(ns.SpellList.ParseClass, text)
		assert(ok, ("ParseClass(%q) raised: %s"):format(text, tostring(err)))
		-- Any format the validator accepts must be safe to render with one string.
		if ns.Util.IsSafeFormat(text) then
			ok, err = pcall(string.format, text, "Polymorph")
			assert(ok, ("accepted unsafe format %q: %s"):format(text, tostring(err)))
		end
	end
	local ok, err = pcall(StaticPopupDialogs.ALERTCCONME_ADD_SPELL.OnAccept, { EditBox = { GetText = function() return nil end } })
	assert(ok, "empty popup accepted: " .. tostring(err))
end
