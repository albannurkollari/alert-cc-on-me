local _, ns = ...

local Util = ns.Util
local IsSecret = Util.IsSecret
local Print = Util.Print
local L = ns.L

local Probe = {}
ns.Probe = Probe

local SECRECY_NAMES = { [0] = "NeverSecret", [1] = "AlwaysSecret", [2] = "ContextuallySecret" }

local function Describe(ok, value)
	if not ok then
		return "|cffff4444error|r"
	end
	if IsSecret(value) then
		return "|cffff8800secret|r"
	end
	return "|cff88ff88" .. tostring(value) .. "|r"
end

local function SecrecyOf(spellID)
	if not (C_Secrets and C_Secrets.GetSpellCastSecrecy) then
		return "n/a"
	end
	local ok, level = Util.SafeCall(C_Secrets.GetSpellCastSecrecy, spellID)
	if not ok or IsSecret(level) then
		return "?"
	end
	return SECRECY_NAMES[level] or tostring(level)
end

local function ProbeSpell(spellID, label)
	local okCC, isCC = Util.SafeCall(C_Spell and C_Spell.IsSpellCrowdControl, spellID)
	Print(("  %s (%d): cast secrecy=%s, IsSpellCrowdControl=%s"):format(
		label or "?", spellID, SecrecyOf(spellID), Describe(okCC, isCC)))
end

local function ProbeUnit(unit)
	if not UnitExists(unit) then
		Print(("  %s: none"):format(unit))
		return
	end
	local cast = ns.CastEval.ReadCast(unit)
	if not cast then
		Print(("  %s: exists, not casting. Re-run while it casts."):format(unit))
	else
		local eval = ns.CastEval.Evaluate(unit, cast)
		Print(("  %s %s: spellID=%s name=%s cc=%s onMe=%s onMeReadable=%s"):format(
			unit, cast.kind, Describe(true, cast.spellID), Describe(true, cast.name),
			Describe(true, eval.isCC), Describe(true, eval.onMe), tostring(eval.onMeReadable)))
	end
	local okSame, same = Util.SafeCall(UnitIsUnit, unit .. "target", "player")
	Print(("  %s target is me (UnitIsUnit): %s"):format(unit, Describe(okSame, same)))
end

function Probe.Run(spellArg)
	local _, build = GetBuildInfo()
	local _, instanceType = IsInInstance()
	Print(("probe: build %s, instance=%s, combat=%s"):format(
		tostring(build), tostring(instanceType), tostring(InCombatLockdown())))

	if C_RestrictedActions and C_RestrictedActions.GetAddOnRestrictionState then
		local ok, state = Util.SafeCall(C_RestrictedActions.GetAddOnRestrictionState)
		Print("  addon restriction state: " .. Describe(ok, state))
	end
	Print(("  APIs: PlayerIsSpellTarget=%s IsSpellCrowdControl=%s GetSpellCastSecrecy=%s"):format(
		tostring(PlayerIsSpellTarget ~= nil),
		tostring(C_Spell ~= nil and C_Spell.IsSpellCrowdControl ~= nil),
		tostring(C_Secrets ~= nil and C_Secrets.GetSpellCastSecrecy ~= nil)))

	ProbeUnit("target")

	local spellID = tonumber(spellArg)
	if spellID then
		ProbeSpell(spellID, "custom")
		return
	end

	Print("  castable CC secrecy (NeverSecret = pre-cast sound can work everywhere):")
	local counts = {}
	for _, entry in ipairs(ns.CastableCC) do
		local level = SecrecyOf(entry.id)
		counts[level] = (counts[level] or 0) + 1
		ProbeSpell(entry.id, entry.name)
	end
	local parts = {}
	for level, count in pairs(counts) do
		parts[#parts + 1] = level .. "=" .. count
	end
	table.sort(parts)
	Print("  summary: " .. table.concat(parts, ", "))
end

local function GameSpellName(spellID)
	local ok, name = Util.SafeCall(C_Spell and C_Spell.GetSpellName, spellID)
	if ok and not Util.IsSecret(name) and name ~= nil then
		return name
	end
	return "?"
end

-- Variant names like "Polymorph (Pig)" are "Polymorph" in game, so match the base name.
local function ListEntry(entry)
	local actual = GameSpellName(entry.id)
	local base = entry.expected:gsub("%s*%(.*%)$", "")
	local line = ("  %d  %s -> %s -> \"%s\""):format(entry.id, entry.expected, actual, entry.callout)
	if #entry.related > 0 then
		line = line .. L.ListRelated:format(#entry.related)
	end
	if not entry.enabled then
		line = line .. L.ListOffTag
	end
	if actual ~= base and actual ~= entry.expected then
		line = line .. L.ListMismatch
	end
	Print(line)
end

function Probe.List()
	Print(L.ListHeader)
	for _, group in ipairs(ns.SpellList.GetGroups()) do
		Print(group.class and ns.SpellList.ClassLabel(group.class) or L.ListUncategorized)
		for _, entry in ipairs(group.entries) do
			ListEntry(entry)
		end
	end
end

-- Real in-game cost from the client's own per-addon profiler (all times in ms).
function Probe.Perf()
	local name = ns.ADDON_NAME
	Print(L.PerfHeader)
	local profiler = C_AddOnProfiler
	local metrics = Enum and Enum.AddOnProfilerMetric
	local okOn, enabled = Util.SafeCall(profiler and profiler.IsEnabled)
	if not (metrics and okOn and enabled == true) then
		Print(L.PerfNoProfiler)
	else
		local function metric(id, overall)
			local ok, value
			if overall then
				ok, value = Util.SafeCall(profiler.GetOverallMetric, id)
			else
				ok, value = Util.SafeCall(profiler.GetAddOnMetric, name, id)
			end
			if ok and type(value) == "number" then
				return value
			end
			return 0
		end
		Print(L.PerfTimes:format(metric(metrics.RecentAverageTime), metric(metrics.SessionAverageTime),
			metric(metrics.PeakTime), metric(metrics.RecentAverageTime, true)))
		Print(L.PerfSpikes:format(metric(metrics.CountTimeOver1Ms), metric(metrics.CountTimeOver5Ms)))
	end
	if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
		UpdateAddOnMemoryUsage()
		Print(L.PerfMemory:format(GetAddOnMemoryUsage(name) or 0))
	end
	Print(L.PerfFrames:format(ns.Display.CountShown()))
end
