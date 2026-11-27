local _, ns = ...

local Util = ns.Util
local CastEval = ns.CastEval
local IsSecret = Util.IsSecret

local CastWatcher = {}
ns.CastWatcher = CastWatcher

local START_EVENTS = {
	UNIT_SPELLCAST_START = true,
	UNIT_SPELLCAST_CHANNEL_START = true,
	UNIT_SPELLCAST_EMPOWER_START = true,
}
local STOP_EVENTS = {
	UNIT_SPELLCAST_STOP = true,
	UNIT_SPELLCAST_FAILED = true,
	UNIT_SPELLCAST_INTERRUPTED = true,
	UNIT_SPELLCAST_CHANNEL_STOP = true,
	UNIT_SPELLCAST_EMPOWER_STOP = true,
}
local UPDATE_EVENTS = {
	UNIT_SPELLCAST_DELAYED = true,
	UNIT_SPELLCAST_CHANNEL_UPDATE = true,
	UNIT_SPELLCAST_EMPOWER_UPDATE = true,
}

local watchers = {}
local debugEnabled = false

local function SourceOf(unit)
	if unit:find("^arena") then
		return "Arena"
	elseif unit:find("^nameplate") then
		return "Nameplates"
	elseif unit == "target" then
		return "Target"
	elseif unit == "focus" then
		return "Focus"
	end
end

local function InArena()
	if C_PvP and C_PvP.IsArena then
		local ok, isArena = Util.SafeCall(C_PvP.IsArena)
		if ok and not IsSecret(isArena) then
			return isArena == true
		end
	end
	local _, instanceType = IsInInstance()
	return instanceType == "arena"
end

local function HasNameplate(unit)
	local ok, plate = Util.SafeCall(C_NamePlate.GetNamePlateForUnit, unit)
	if not ok or IsSecret(plate) then
		return false
	end
	return plate ~= nil
end

-- One enemy can be arena1, a nameplate and the target at the same time. The arena
-- token wins in arena; outside arena the nameplate wins over target/focus.
function CastWatcher.IsDuplicate(unit)
	local source = SourceOf(unit)
	if source ~= "Arena" and InArena() and CastEval.IsPlayerUnit(unit) == true then
		return true
	end
	if (source == "Target" or source == "Focus") and HasNameplate(unit) then
		return true
	end
	return false
end

local function DebugReport(unit, cast, eval, played)
	if not debugEnabled then
		return
	end
	local function state(value)
		if IsSecret(value) then
			return "|cffff8800secret|r"
		end
		return tostring(value)
	end
	Util.Print(("[%s] %s spell=%s cc=%s onMe=%s onMeReadable=%s sound=%s"):format(
		unit, cast.kind, state(cast.spellID), state(eval.isCC), state(eval.onMe),
		tostring(eval.onMeReadable), tostring(played)))
end

function CastWatcher.Evaluate(unit, allowSound)
	local db = ns.db
	if not db.Enabled then
		ns.Display.Hide(unit)
		return
	end
	local exists = UnitExists(unit)
	if (not IsSecret(exists) and not exists) or not CastEval.IsHostile(unit) or CastWatcher.IsDuplicate(unit) then
		ns.Display.Hide(unit)
		return
	end
	local isPlayer = CastEval.IsPlayerUnit(unit)
	if db.PlayersOnly and isPlayer == false then
		ns.Display.Hide(unit)
		return
	end

	local cast = CastEval.ReadCast(unit)
	if not cast then
		ns.Display.Hide(unit)
		return
	end

	-- Switched off in the spell list. Only works when the client lets us read the ID.
	if ns.SpellList.IsSuppressed(cast.spellID) then
		ns.Display.Hide(unit)
		return
	end

	local eval = CastEval.Evaluate(unit, cast)
	-- A readable "no" needs no frame; only hidden values need the alpha-gated one.
	if eval.onMeReadable == false or (db.RequireCC and eval.isCCReadable == false) then
		ns.Display.Hide(unit)
		DebugReport(unit, cast, eval, false)
		return
	end
	ns.Display.Show(unit, cast, eval)

	local played = false
	if allowSound and db.Sound.PreCast
		and CastEval.ShouldPlaySound(db.Sound.Mode, db.RequireCC, eval, isPlayer) then
		played = ns.Sound.PlayPreCast(cast, eval)
	end
	DebugReport(unit, cast, eval, played)
end

local function OnUnitEvent(self, event)
	local unit = self.unit
	if START_EVENTS[event] then
		CastWatcher.Evaluate(unit, true)
	elseif STOP_EVENTS[event] then
		-- A channel can follow a cast immediately; re-read instead of blindly hiding.
		CastWatcher.Evaluate(unit, false)
	elseif UPDATE_EVENTS[event] then
		CastWatcher.Evaluate(unit, false)
	end
end

local function CreateWatcher(unit)
	local frame = CreateFrame("Frame")
	frame.unit = unit
	for event in pairs(START_EVENTS) do
		frame:RegisterUnitEvent(event, unit)
	end
	for event in pairs(STOP_EVENTS) do
		frame:RegisterUnitEvent(event, unit)
	end
	for event in pairs(UPDATE_EVENTS) do
		frame:RegisterUnitEvent(event, unit)
	end
	frame:SetScript("OnEvent", OnUnitEvent)
	watchers[unit] = frame
end

-- Re-evaluate a token whose identity changed (new target, plate shown, arena update)
-- so a cast already in progress is picked up.
function CastWatcher.Rescan(unit, allowSound)
	if watchers[unit] then
		CastWatcher.Evaluate(unit, allowSound)
	end
end

function CastWatcher.RescanAll()
	for unit in pairs(watchers) do
		CastWatcher.Evaluate(unit, false)
	end
end

function CastWatcher.SetDebug(enabled)
	debugEnabled = enabled
end

function CastWatcher.IsDebug()
	return debugEnabled
end

local globalFrame = CreateFrame("Frame")
globalFrame:SetScript("OnEvent", function(_, event, unit)
	if event == "NAME_PLATE_UNIT_ADDED" then
		if type(unit) == "string" and not IsSecret(unit) then
			CastWatcher.Rescan(unit, true)
		end
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		if type(unit) == "string" and not IsSecret(unit) then
			ns.Display.Hide(unit)
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		CastWatcher.Rescan("target", true)
	elseif event == "PLAYER_FOCUS_CHANGED" then
		CastWatcher.Rescan("focus", true)
	elseif event == "ARENA_OPPONENT_UPDATE" then
		if type(unit) == "string" and not IsSecret(unit) then
			CastWatcher.Rescan(unit, false)
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		ns.Display.HideAll()
		CastWatcher.RescanAll()
	end
end)

function CastWatcher.Initialize()
	CreateWatcher("target")
	CreateWatcher("focus")
	for i = 1, ns.MAX_ARENA do
		CreateWatcher("arena" .. i)
	end
	for i = 1, ns.MAX_NAMEPLATES do
		CreateWatcher("nameplate" .. i)
	end
	globalFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	globalFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
	globalFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	globalFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
	globalFrame:RegisterEvent("ARENA_OPPONENT_UPDATE")
	globalFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
end
