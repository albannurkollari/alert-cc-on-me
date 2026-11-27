local _, ns = ...

local Sound = {}
ns.Sound = Sound

local lastPreCastAt

-- An unknown name (e.g. a sound saved by an older version) plays the default.
function Sound.Find(name)
	local fallback
	for _, option in ipairs(ns.AlertSounds) do
		if option.Value == name then
			return option
		end
		if option.Value == ns.Defaults.Sound.Alert then
			fallback = option
		end
	end
	return fallback
end

function Sound.Play(name, channel)
	local option = Sound.Find(name)
	if option.File then
		PlaySoundFile(option.File, channel or "Master")
	else
		PlaySound(option.Kit, channel or "Master")
	end
end

-- Global, not per caster: one enemy is often visible through several tokens at once
-- (arena1 + its nameplate + target), and their GUIDs are secret in arena.
function Sound.PlayPreCast()
	local db = ns.db.Sound
	local now = GetTime()
	if lastPreCastAt and now - lastPreCastAt < (db.Throttle or 0) then
		return false
	end
	lastPreCastAt = now
	Sound.Play(db.Alert, db.Channel)
	return true
end
