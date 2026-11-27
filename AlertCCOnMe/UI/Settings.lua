local addonName, ns = ...

local L = ns.L

local SettingsUI = {}
ns.SettingsUI = SettingsUI

local category
local spellCategory, spellLayout
local spellRows = {} -- spellID -> row initializer
local UNCATEGORIZED = "UNCATEGORIZED"
local sectionHeaders = {} -- class token or UNCATEGORIZED -> header initializer
local rowSection = {} -- spellID -> section its row sits in
local isRow = {} -- row initializer -> true

local function OnChanged()
	ns.ApplySettings()
end

-- `section` is nil for root keys, else "Zones" / "Visual" / "Sound".
local function Register(section, key, label, varType)
	local tbl = section and ns.db[section] or ns.db
	local defaults = section and ns.Defaults[section] or ns.Defaults
	local variable = addonName .. "_" .. (section or "Root") .. "_" .. key
	local setting = Settings.RegisterAddOnSetting(category, variable, key, tbl, varType, label, defaults[key])
	setting:SetValueChangedCallback(OnChanged)
	return setting
end

local function Checkbox(section, key, label, tooltip)
	local setting = Register(section, key, label, Settings.VarType.Boolean)
	Settings.CreateCheckbox(category, setting, tooltip)
end

local function Slider(section, key, label, minValue, maxValue, step, tooltip, formatter)
	local setting = Register(section, key, label, Settings.VarType.Number)
	local options = Settings.CreateSliderOptions(minValue, maxValue, step)
	options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter or function(value)
		return ("%d"):format(value)
	end)
	Settings.CreateSlider(category, setting, options, tooltip)
end

local function Dropdown(section, key, label, entries, tooltip)
	local setting = Register(section, key, label, Settings.VarType.String)
	local function GetOptions()
		local container = Settings.CreateControlTextContainer()
		for _, entry in ipairs(entries) do
			container:Add(entry.Value, entry.Text, entry.Tooltip)
		end
		return container:GetData()
	end
	Settings.CreateDropdown(category, setting, GetOptions, tooltip)
end

local function Header(layout, text)
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
end

local function Button(layout, label, text, onClick)
	layout:AddInitializer(CreateSettingsButtonInitializer(label, text, onClick, nil, false))
end

-- Spell list: Blizzard's own checkbox-with-button row per spell,
-- "<icon> Name  ID | on/off | X". Proxy settings read and write ns.SpellList directly.
local function SpellLabel(entry)
	local custom = entry.custom and ("  |cff808080" .. L.ListCustom .. "|r") or ""
	return ("|T%s:18:18:0:0:64:64:5:59:5:59|t  %s  |cff808080%d|r%s"):format(tostring(entry.icon), entry.name, entry.id, custom)
end

local function CreateSpellRow(entry)
	local spellID = entry.id
	local setting = Settings.RegisterProxySetting(spellCategory, addonName .. "_Spell_" .. spellID,
		Settings.VarType.Boolean, SpellLabel(entry), true,
		function()
			return ns.SpellList.IsEnabled(spellID)
		end,
		function(value)
			ns.SpellList.SetEnabled(spellID, value)
		end)
	-- Same data as CreateSettingsCheckboxWithButtonInitializer, on our table-layout template.
	local data = Settings.CreateSettingInitializerData(setting, nil, L.ListRowTip)
	data.buttonText = L.ListRemove
	data.OnButtonClick = function()
		ns.SpellList.Remove(spellID)
	end
	data.clickRequiresSet = false
	local row = Settings.CreateSettingInitializer("AlertCCOnMeSpellRowTemplate", data)
	-- Removed rows stay registered but hidden, so re-adding a spell just shows it again.
	row:AddShownPredicate(function()
		return ns.SpellList.IsListed(spellID)
	end)
	spellRows[spellID] = row
	isRow[row] = true
end

-- A section is its header plus the rows right after it, so a row is placed by moving it
-- to the end of its section. RepairDisplay orders the panel by layout position.
local function PlaceRow(spellID, section)
	local inits = spellLayout:GetInitializers()
	local row = spellRows[spellID]
	for i = #inits, 1, -1 do
		if inits[i] == row then
			table.remove(inits, i)
		end
	end
	local position = #inits + 1
	for i, init in ipairs(inits) do
		if init == sectionHeaders[section] then
			position = i + 1
			while inits[position] and isRow[inits[position]] do
				position = position + 1
			end
			break
		end
	end
	table.insert(inits, position, row)
	rowSection[spellID] = section
end

-- Creates the row on first sight and moves it when an added spell changes class.
local function SyncSpellRow(entry)
	local section = entry.class or UNCATEGORIZED
	if not spellRows[entry.id] then
		CreateSpellRow(entry)
	end
	if rowSection[entry.id] ~= section then
		PlaceRow(entry.id, section)
	end
end

local function AddSectionHeader(section, label, hasSpells)
	local header = CreateSettingsListSectionHeaderInitializer(label)
	header:AddShownPredicate(hasSpells)
	spellLayout:AddInitializer(header)
	sectionHeaders[section] = header
end

local function DialogEditBox(dialog)
	return (dialog.GetEditBox and dialog:GetEditBox()) or dialog.EditBox or dialog.editBox
end

local function AddFromDialog(dialog)
	local editBox = DialogEditBox(dialog)
	if editBox then
		local _, message = ns.SpellList.Add(editBox:GetText())
		ns.Util.Print(message)
	end
end

local function RegisterAddSpellPopup()
	StaticPopupDialogs.ALERTCCONME_ADD_SPELL = {
		text = L.AddPrompt,
		button1 = L.AddButton,
		button2 = CANCEL,
		hasEditBox = true,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		OnAccept = AddFromDialog,
		EditBoxOnEnterPressed = function(editBox)
			local dialog = editBox:GetParent()
			AddFromDialog(dialog)
			dialog:Hide()
		end,
		EditBoxOnEscapePressed = function(editBox)
			editBox:GetParent():Hide()
		end,
	}
end

local function RegisterSpellList()
	if not (Settings.RegisterVerticalLayoutSubcategory and Settings.RegisterProxySetting
		and Settings.CreateSettingInitializer and SettingsCheckboxWithButtonControlMixin) then
		return
	end
	ns.InitSpellRowMixin()
	spellCategory, spellLayout = Settings.RegisterVerticalLayoutSubcategory(category, L.ListTitle)
	RegisterAddSpellPopup()

	Header(spellLayout, L.ListTitle)
	Button(spellLayout, L.BtnAddSpell, L.BtnAddSpell, function()
		StaticPopup_Show("ALERTCCONME_ADD_SPELL")
	end)
	Button(spellLayout, L.BtnRestoreSpells, L.BtnRestoreSpells, function()
		ns.SpellList.RestoreBuiltins()
	end)
	-- A header per class, then Uncategorized; each hides while it has no spells.
	for _, classToken in ipairs(ns.ClassOrder) do
		AddSectionHeader(classToken, ns.SpellList.ClassLabel(classToken), function()
			return ns.SpellList.HasListed(classToken)
		end)
	end
	AddSectionHeader(UNCATEGORIZED, L.ListUncategorized, function()
		return ns.SpellList.HasListed(nil)
	end)
	-- Removed built-ins get rows too, so restoring one shows it back under its class.
	for _, entry in ipairs(ns.SpellList.GetEntries(true)) do
		SyncSpellRow(entry)
	end
end

function SettingsUI.Register()
	if not (Settings and Settings.RegisterVerticalLayoutCategory) then
		return
	end
	local layout
	category, layout = Settings.RegisterVerticalLayoutCategory(L.CategoryName)

	Header(layout, L.SectionGeneral)
	Checkbox(nil, "Enabled", L.OptEnabled)
	Checkbox(nil, "Locked", L.OptLocked, L.OptLockedTip)
	Slider(nil, "Scale", L.OptScale, 0.5, 2.5, 0.05, nil, function(value)
		return ("%.2f"):format(value)
	end)
	Checkbox(nil, "RequireCC", L.OptRequireCC, L.OptRequireCCTip)
	Checkbox(nil, "PlayersOnly", L.OptPlayersOnly, L.OptPlayersOnlyTip)
	Button(layout, L.BtnTest, L.BtnTest, function()
		ns.RunTest()
	end)
	Button(layout, L.BtnProbe, L.BtnProbe, function()
		ns.Probe.Run()
	end)
	Button(layout, L.BtnSpellList, L.BtnSpellList, function()
		SettingsUI.OpenSpellList()
	end)

	Header(layout, L.SectionZones)
	Checkbox("Zones", "World", L.OptZoneWorld)
	Checkbox("Zones", "Arena", L.OptZoneArena, L.OptZoneArenaTip)
	Checkbox("Zones", "Battleground", L.OptZoneBattleground, L.OptZoneBattlegroundTip)
	Checkbox("Zones", "Dungeon", L.OptZoneDungeon, L.OptZoneDungeonTip)

	Header(layout, L.SectionVisual)
	Checkbox("Visual", "ShowIcon", L.OptShowIcon)
	Slider("Visual", "IconSize", L.OptIconSize, 16, 160, 2)
	Checkbox("Visual", "ShowText", L.OptShowText)
	Slider("Visual", "FontSize", L.OptFontSize, 10, 72, 1)
	Checkbox("Visual", "ShowScreenFlash", L.OptScreenFlash)
	Checkbox("Visual", "Pulse", L.OptPulse)

	Header(layout, L.SectionSound)
	Checkbox("Sound", "PreCast", L.OptPreCast, L.OptPreCastTip)
	Checkbox("Sound", "Voice", L.OptVoice, L.OptVoiceTip)
	Dropdown("Sound", "VoicePack", L.OptVoicePack, ns.VoicePacks)
	Dropdown("Sound", "Mode", L.OptSoundMode, {
		{ Value = ns.SoundModes.CONFIRMED, Text = L.ModeConfirmed, Tooltip = L.ModeConfirmedTip },
		{ Value = ns.SoundModes.CC_ANY_TARGET, Text = L.ModeAnyTarget, Tooltip = L.ModeAnyTargetTip },
		{ Value = ns.SoundModes.ANY_PLAYER_CAST, Text = L.ModeAnyPlayer, Tooltip = L.ModeAnyPlayerTip },
	})
	Dropdown("Sound", "File", L.OptSoundFile, ns.SoundFiles)

	RegisterSpellList()
	Settings.RegisterAddOnCategory(category)
end

-- New custom spells get a row; RepairDisplay re-applies the shown predicates.
function SettingsUI.OnSpellListChanged()
	if not spellLayout then
		return
	end
	for _, entry in ipairs(ns.SpellList.GetEntries()) do
		SyncSpellRow(entry)
	end
	if SettingsInbound and SettingsInbound.RepairDisplay then
		SettingsInbound.RepairDisplay()
	end
end

function SettingsUI.OpenSpellList()
	if spellCategory then
		Settings.OpenToCategory(spellCategory:GetID())
	end
end

function SettingsUI.Open()
	if category then
		Settings.OpenToCategory(category:GetID())
	end
end
