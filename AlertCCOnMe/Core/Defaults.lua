local _, ns = ...

ns.SoundModes = {
	CONFIRMED = "CONFIRMED", -- only when CC and "targeting me" are both readable and true
	CC_ANY_TARGET = "CC_ANY_TARGET", -- DBM-style: readable CC cast, target unknown or me
	ANY_PLAYER_CAST = "ANY_PLAYER_CAST", -- any enemy player cast start (works in arena, noisy)
}

-- The game's own sounds, so the addon ships no audio. Value is what the setting saves.
-- Kit: a SOUNDKIT ID from Blizzard's SoundKitConstants.lua (12.1.5), played with PlaySound.
-- File: a sound file ID from the community listfile (github.com/wowdev/wow-listfile),
-- played with PlaySoundFile; the comment is the file's path in the game data.
ns.AlertSounds = {
	{ Value = "RAID_WARNING", Text = "Interface: Raid warning", Kit = 8959 },
	{ Value = "RAID_BOSS_WARNING", Text = "Interface: Raid boss warning", File = 567394 }, -- Sound/INTERFACE/RaidBossWarning.ogg
	{ Value = "UI_RAID_BOSS_WHISPER_WARNING", Text = "Interface: Boss whisper warning", Kit = 37666 },
	{ Value = "PVP_WARNING", Text = "Interface: PvP warning", File = 567488 }, -- Sound/INTERFACE/PVPWARNING.ogg
	{ Value = "AGGRO_WARNING", Text = "Interface: Aggro warning", File = 567401 }, -- Sound/INTERFACE/Aggro_Enter_Warning_State.ogg
	{ Value = "READY_CHECK", Text = "Interface: Ready check", Kit = 8960 },
	{ Value = "ALARM_CLOCK_WARNING_1", Text = "Interface: Alarm clock 1", Kit = 18871 },
	{ Value = "ALARM_CLOCK_WARNING_3", Text = "Interface: Alarm clock 3", Kit = 12889 },
	{ Value = "HORN_IRON_HORDE_1", Text = "Horn: Iron Horde war horn 1", File = 1030922 }, -- SOUND/DOODAD/FX_IH_WARHORN01.ogg
	{ Value = "HORN_IRON_HORDE_2", Text = "Horn: Iron Horde war horn 2", File = 1030923 }, -- SOUND/DOODAD/FX_IH_WARHORN02.ogg
	{ Value = "HORN_IRON_HORDE_3", Text = "Horn: Iron Horde war horn 3", File = 1030924 }, -- SOUND/DOODAD/FX_IH_WARHORN03.ogg
	{ Value = "HORN_WARSONG", Text = "Horn: Warsong war horn", File = 1036067 }, -- SOUND/SPELLS/FX_Warsong_WarHorn_6.0.ogg
	{ Value = "HORN_DWARF", Text = "Horn: Dwarf horn", File = 566064 }, -- Sound/DOODAD/DwarfHorn.ogg
	{ Value = "HORN_SCOURGE", Text = "Horn: Scourge horn", File = 567386 }, -- Sound/EVENTS/scourge_horn.ogg
	{ Value = "HORN_OBSIDIAN", Text = "Horn: Obsidian battle horn", File = 5097434 }, -- Sound/Spell/ObsidianBattleHorn_cast_oneshot_5097434.ogg
	{ Value = "HORN_SOUNDING", Text = "Horn: Sounding horn", File = 3885353 }, -- Sound/Spell/SoundingHorn_cast_oneshot_3885353.ogg
	{ Value = "HORN_ZEPPELIN", Text = "Horn: Zeppelin horn", File = 566719 }, -- Sound/DOODAD/ZeppelinHorn.ogg
	{ Value = "HORN_FOG", Text = "Horn: Lighthouse fog horn", File = 567094 }, -- Sound/DOODAD/LightHouseFogHorn.ogg
	{ Value = "HORN_TRAIN", Text = "Horn: Grimrail train horn", File = 1023633 }, -- SOUND/DOODAD/FX_GRIMRAIL_TRAINHORN.ogg
	{ Value = "DRUM_OGRE", Text = "Drum: Ogre war drum", File = 567275 }, -- Sound/Event Sounds/Event_wardrum_ogre.ogg
	{ Value = "DRUM_ALARM_1", Text = "Drum: Alarm drum hit 1", File = 1487136 }, -- SOUND/DOODAD/FX_Alarm_Drum_Hit_01.ogg
	{ Value = "DRUM_ALARM_3", Text = "Drum: Alarm drum hit 3", File = 1487138 }, -- SOUND/DOODAD/FX_Alarm_Drum_Hit_03.ogg
	{ Value = "DRUM_TROLL", Text = "Drum: Troll battle drum", File = 840238 }, -- Sound/DOODAD/FX_TrollBattle_DrumLoop1_Single.OGG
	{ Value = "GONG_TROLL", Text = "Gong: Troll gong", File = 565564 }, -- Sound/DOODAD/G_GongTroll01.ogg
	{ Value = "GONG_BLACKROCK", Text = "Gong: Blackrock shield gong", File = 565687 }, -- Sound/DOODAD/GO_BlackrockV2_ShieldGongCustom0_03.ogg
	{ Value = "BELL_HORDE", Text = "Bell: Horde bell toll", File = 565853 }, -- Sound/DOODAD/BellTollHorde.ogg
	{ Value = "BELL_ALLIANCE", Text = "Bell: Alliance bell toll", File = 566564 }, -- Sound/DOODAD/BellTollAlliance.ogg
	{ Value = "BELL_KARAZHAN", Text = "Bell: Karazhan bell toll", File = 566254 }, -- Sound/DOODAD/KharazahnBellToll.ogg
	{ Value = "BELL_DIVINE", Text = "Bell: Divine bell", File = 669386 }, -- Sound/DOODAD/GO_PA_DivineBell_Ring_Pure.OGG
	{ Value = "ALARM_LARGE", Text = "Alarm: Large", File = 2974001 }, -- sound/spells/fx_alarm_large01.ogg
	{ Value = "ALARM_MEDIUM", Text = "Alarm: Medium", File = 2974005 }, -- sound/spells/fx_alarm_medium01.ogg
	{ Value = "ALARM_SMALL", Text = "Alarm: Small", File = 2974003 }, -- sound/spells/fx_alarm_small01.ogg
	{ Value = "ALARM_KLAXON", Text = "Alarm: Goblin klaxon", File = 597938 }, -- Sound/event/EVENT_THIntro_GoblinKlaxon_Loop.ogg
	{ Value = "IMPACT_ROCK", Text = "Impact: Heavy rock", File = 1345549 }, -- SOUND/DOODAD/FX_RockImpact_Heavy_Short_01.ogg
	{ Value = "IMPACT_LIGHTNING", Text = "Impact: Lightning strike", File = 635065 }, -- Sound/DOODAD/FX_Lightning_Impact_Heavy01.OGG
	{ Value = "IMPACT_GIANT_THUD", Text = "Impact: Giant falling thud", File = 950632 }, -- Sound/DOODAD/FX_DeathThud_DirtGrass_Giant_01.OGG
	{ Value = "IMPACT_FIREWORK", Text = "Impact: Firework boom", File = 565731 }, -- Sound/DOODAD/G_FireworkBoomGeneral4.ogg
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
		Mode = "CONFIRMED",
		-- An ns.AlertSounds value.
		Alert = "RAID_WARNING",
		Channel = "Master",
		-- Seconds; the same caster re-triggering inside this window stays silent.
		Throttle = 1.0,
	},

	-- Player edits to the CC spell list; see Modules/SpellList.lua.
	SpellList = {},
}
