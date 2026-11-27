local _, ns = ...

local Util = ns.Util
local L = ns.L

local Sound = {}
ns.Sound = Sound

local lastPreCastAt

function Sound.ResolveFile(file)
	for _, option in ipairs(ns.SoundFiles) do
		if option.Value == file then
			return ns.MEDIA .. file
		end
	end
	return ns.MEDIA .. ns.Defaults.Sound.File
end

function Sound.Play(file, channel)
	PlaySoundFile(Sound.ResolveFile(file), channel or "Master")
end

local function FindPack(name)
	for _, option in ipairs(ns.VoicePacks) do
		if option.Value == name then
			return option
		end
	end
	return nil
end

-- An unknown pack (e.g. its add-on was disabled) falls back to the built-in default.
function Sound.VoicePath(clip)
	local pack = FindPack(ns.db.Sound.VoicePack) or FindPack(ns.Defaults.Sound.VoicePack)
	return pack.Path .. clip .. ".ogg"
end

-- Public API for voice pack add-ons. Call it from the pack's own Lua file, with
-- `## Dependencies: AlertCCOnMe` in its .toc so this addon loads first:
--   AlertCCOnMe_RegisterVoicePack("Grampa", "Interface\\AddOns\\AlertCCOnMe_Voice_Grampa\\")
-- The folder needs <Callout>OnYou.ogg and <Callout>.ogg for every callout key (see
-- templates/AlertCCOnMe_Voice_Example). Returns true when the pack was added.
function AlertCCOnMe_RegisterVoicePack(name, path)
	if type(name) ~= "string" or name == "" or type(path) ~= "string" or path == "" then
		return false
	end
	if FindPack(name) then
		return false
	end
	if path:sub(-1) ~= "\\" then
		path = path .. "\\"
	end
	ns.VoicePacks[#ns.VoicePacks + 1] = { Value = name, Text = name, Path = path }
	return true
end

-- Only readable values pick a clip: which spell it is can't be spoken from a secret,
-- so a hidden spell falls back to the plain alarm.
function Sound.PickCallout(cast, eval)
	local key = ns.SpellList.CalloutFor(cast.spellID)
	if not key and eval.isCCReadable == true then
		key = ns.GenericCallout.CC
	elseif not key and eval.isCCReadable == false and not ns.db.RequireCC then
		key = ns.GenericCallout.Cast
	end
	if not key then
		return nil
	end
	if eval.onMeReadable == true then
		return key .. "OnYou"
	end
	return key
end

-- Global, not per caster: one enemy is often visible through several tokens at once
-- (arena1 + its nameplate + target), and their GUIDs are secret in arena.
function Sound.PlayPreCast(cast, eval)
	local db = ns.db.Sound
	local now = GetTime()
	if lastPreCastAt and now - lastPreCastAt < (db.Throttle or 0) then
		return false
	end
	lastPreCastAt = now
	local clip = db.Voice and cast and eval and Sound.PickCallout(cast, eval)
	if clip then
		PlaySoundFile(Sound.VoicePath(clip), db.Channel or "Master")
	else
		Sound.Play(db.File, db.Channel)
	end
	return true
end
