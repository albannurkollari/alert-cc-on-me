local addonName, ns = ...

local Util = ns.Util
local L = ns.L

local function NormalizeDb(db)
	local modeValid = false
	for _, mode in pairs(ns.SoundModes) do
		if db.Sound.Mode == mode then
			modeValid = true
		end
	end
	if not modeValid then
		db.Sound.Mode = ns.Defaults.Sound.Mode
	end
	if not Util.IsSafeFormat(db.Visual.TextFormat) then
		db.Visual.TextFormat = ns.Defaults.Visual.TextFormat
	end
end

-- Called after any option change.
function ns.ApplySettings()
	ns.Display.ApplySettings()
	ns.CastWatcher.RescanAll()
end

function ns.RunTest()
	ns.Display.ShowTest(3)
	if ns.db.Sound.Voice then
		PlaySoundFile(ns.Sound.VoicePath("SheepOnYou"), ns.db.Sound.Channel)
	else
		ns.Sound.Play(ns.db.Sound.File, ns.db.Sound.Channel)
	end
end

local function SetLocked(locked)
	ns.db.Locked = locked
	ns.ApplySettings()
	Util.Print(locked and L.LockedMsg or L.Unlocked)
end
ns.SetLocked = SetLocked

local function HandleSlash(message)
	local command, rest = (message or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
	if command == "" or command == "options" or command == "config" then
		ns.SettingsUI.Open()
	elseif command == "test" then
		ns.RunTest()
	elseif command == "unlock" or command == "move" then
		SetLocked(false)
	elseif command == "lock" then
		SetLocked(true)
	elseif command == "reset" then
		ns.Display.ResetPosition()
		Util.Print(L.ResetMsg)
	elseif command == "list" then
		ns.Probe.List()
	elseif command == "perf" then
		ns.Probe.Perf()
	elseif command == "spells" then
		ns.SettingsUI.OpenSpellList()
	elseif command == "add" then
		local _, message = ns.SpellList.Add(rest)
		Util.Print(message)
	elseif command == "remove" then
		local spellID = tonumber(rest)
		if spellID and ns.SpellList.IsListed(spellID) then
			ns.SpellList.Remove(spellID)
			Util.Print(L.RemovedMsg:format(spellID))
		else
			Util.Print(L.NotListedMsg:format(rest))
		end
	elseif command == "probe" then
		ns.Probe.Run(rest)
	elseif command == "debug" then
		ns.CastWatcher.SetDebug(not ns.CastWatcher.IsDebug())
		Util.Print("debug " .. (ns.CastWatcher.IsDebug() and "on" or "off"))
	elseif command == "sound" then
		ns.db.Sound.PreCast = not ns.db.Sound.PreCast
		Util.Print(ns.db.Sound.PreCast and L.SoundOn or L.SoundOff)
	elseif command == "on" or command == "off" then
		ns.db.Enabled = command == "on"
		ns.ApplySettings()
		Util.Print(ns.db.Enabled and L.Enabled or L.Disabled)
	elseif command == "status" then
		Util.Print(("enabled=%s mode=%s preCast=%s voice=%s (%s) requireCC=%s"):format(
			tostring(ns.db.Enabled), ns.db.Sound.Mode, tostring(ns.db.Sound.PreCast),
			tostring(ns.db.Sound.Voice), ns.db.Sound.VoicePack, tostring(ns.db.RequireCC)))
	else
		Util.Print(L.Help)
	end
end

function AlertCCOnMe_OnCompartmentClick()
	ns.SettingsUI.Open()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= addonName then
			return
		end
		AlertCCOnMeDB = AlertCCOnMeDB or {}
		Util.CopyDefaults(ns.Defaults, AlertCCOnMeDB)
		ns.db = AlertCCOnMeDB
		NormalizeDb(ns.db)
		ns.SpellList.Rebuild()

		ns.Display.Initialize()
		ns.CastWatcher.Initialize()
		ns.SettingsUI.Register()

		SLASH_ALERTCCONME1 = "/accm"
		SLASH_ALERTCCONME2 = "/alertcc"
		SlashCmdList.ALERTCCONME = HandleSlash

		self:UnregisterEvent("ADDON_LOADED")
		self:RegisterEvent("PLAYER_LOGIN")
	elseif event == "PLAYER_LOGIN" then
		local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
		Util.Print(L.Loaded:format(version))
	end
end)
