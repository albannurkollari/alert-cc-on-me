local _, ns = ...

ns.SoundModes = {
	CONFIRMED = "CONFIRMED", -- only when CC and "targeting me" are both readable and true
	CC_ANY_TARGET = "CC_ANY_TARGET", -- DBM-style: readable CC cast, target unknown or me
	ANY_PLAYER_CAST = "ANY_PLAYER_CAST", -- any enemy player cast start (works in arena, noisy)
}

ns.SoundFiles = {
	{ Value = "Alarm.ogg", Text = "Alarm (two-tone)" },
	{ Value = "Rise.ogg", Text = "Rise (sweep)" },
	{ Value = "Ping.ogg", Text = "Ping (high)" },
	{ Value = "Thud.ogg", Text = "Thud (low double)" },
}

ns.Defaults = {
	Enabled = true,
	Locked = true,
	Point = "CENTER",
	RelativePoint = "CENTER",
	X = 0,
	Y = 180,
	Scale = 1.0,

	-- false widens the alert to any hostile cast aimed at you (e.g. Chaos Bolt).
	RequireCC = true,
	PlayersOnly = false,

	-- Where alerts run. Raids and scenarios (delves) have no toggle and stay off.
	Zones = {
		World = true,
		Arena = true,
		Battleground = true,
		Dungeon = true,
	},

	Visual = {
		ShowIcon = false,
		IconSize = 56,
		ShowText = true,
		TextFormat = "%s on YOU!",
		FontSize = 26,
		TextColor = { r = 1, g = 0.2, b = 0.2 },
		ShowScreenFlash = false,
		FlashAlpha = 0.55,
		Pulse = true,
	},

	Sound = {
		PreCast = true,
		-- Speak the CC ("Sheep on you!") whenever the spell is readable; alarm otherwise.
		Voice = true,
		VoicePack = "Bryce",
		Mode = "CONFIRMED",
		File = "Alarm.ogg",
		Channel = "Master",
		-- Seconds; the same caster re-triggering inside this window stays silent.
		Throttle = 1.0,
	},

	-- Player edits to the CC spell list; see Modules/SpellList.lua.
	SpellList = {},
}
