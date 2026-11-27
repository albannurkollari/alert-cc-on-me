std = "lua51"
max_line_length = false
exclude_files = { ".release" }

-- Globals the addon defines for the client.
globals = {
	"AlertCCOnMeDB",
	"AlertCCOnMe_OnCompartmentClick",
	"AlertCCOnMe_RegisterVoicePack",
	"AlertCCOnMeSpellRowMixin",
	"SLASH_ALERTCCONME1",
	"SLASH_ALERTCCONME2",
	"SlashCmdList",
	"StaticPopupDialogs",
}

-- WoW API the addon reads.
read_globals = {
	"C_AddOnProfiler", "C_AddOns", "C_ClassColor", "C_NamePlate", "C_PvP", "C_RestrictedActions",
	"C_Secrets", "C_Spell", "C_Timer", "CANCEL", "CreateFrame", "CreateSettingsButtonInitializer",
	"CreateSettingsListSectionHeaderInitializer", "DEFAULT_CHAT_FRAME", "Enum", "GetAddOnMemoryUsage",
	"GetBuildInfo", "GetClassAtlas", "GetTime", "InCombatLockdown", "IsInInstance", "issecretvalue",
	"IsShiftKeyDown", "LOCALIZED_CLASS_NAMES_FEMALE", "LOCALIZED_CLASS_NAMES_MALE",
	"MinimalSliderWithSteppersMixin", "Mixin", "PlayerIsSpellTarget", "PlaySoundFile", "Settings",
	"SettingsCheckboxWithButtonControlMixin", "SettingsInbound", "STANDARD_TEXT_FONT",
	"StaticPopup_Show", "strtrim", "UIParent", "UnitCanAttack", "UnitCastingInfo", "UnitChannelInfo",
	"UnitExists", "UnitIsPlayer", "UnitIsUnit", "UpdateAddOnMemoryUsage",
}

-- Tests run against their own mock, which defines the WoW API as globals.
files["tests"] = {
	std = "+busted",
	allow_defined_top = true,
	-- The perf test swaps in its own profiler and memory API.
	globals = { "TEST", "T", "ns", "C_AddOnProfiler", "GetAddOnMemoryUsage", "UpdateAddOnMemoryUsage" },
	-- The mock stubs whole API signatures and defines API the addon may not use yet.
	unused_args = false,
	ignore = { "131" },
}
