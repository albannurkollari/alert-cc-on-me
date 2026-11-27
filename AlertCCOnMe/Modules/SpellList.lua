local _, ns = ...

local Util = ns.Util
local L = ns.L

local SpellList = {}
ns.SpellList = SpellList

-- db.SpellList stores only the player's changes, keyed by spell ID, so built-ins added
-- in later versions still appear:
--   built-in: { enabled = false } or { removed = true }
--   custom:   { custom = true, enabled = bool, order = n, class = token or nil }
local lookup = {} -- spellID (main or related) -> entry
local QUESTION_MARK_ICON = 134400

local function Overrides()
	return ns.db.SpellList
end

local function SpellName(spellID)
	local ok, name = Util.SafeCall(C_Spell and C_Spell.GetSpellName, spellID)
	if ok and not Util.IsSecret(name) and name ~= nil then
		return name
	end
	return nil
end

local function SpellIcon(spellID)
	local ok, icon = Util.SafeCall(C_Spell and C_Spell.GetSpellTexture, spellID)
	if ok and not Util.IsSecret(icon) and icon ~= nil then
		return icon
	end
	return QUESTION_MARK_ICON
end

local function IsBuiltin(spellID)
	for _, spell in ipairs(ns.CastableCC) do
		if spell.id == spellID then
			return true
		end
	end
	return false
end

-- Built-ins in data order, then custom spells in the order they were added.
-- `includeRemoved` also returns removed built-ins (the settings page keeps their rows).
function SpellList.GetEntries(includeRemoved)
	local entries = {}
	for _, spell in ipairs(ns.CastableCC) do
		local override = Overrides()[spell.id] or {}
		if includeRemoved or not override.removed then
			entries[#entries + 1] = {
				id = spell.id,
				class = spell.class,
				name = SpellName(spell.id) or spell.name,
				expected = spell.name,
				icon = SpellIcon(spell.id),
				enabled = override.enabled ~= false,
				callout = spell.callout,
				related = spell.related or {},
				custom = false,
			}
		end
	end

	local customs = {}
	for spellID, override in pairs(Overrides()) do
		if override.custom and not IsBuiltin(spellID) then
			customs[#customs + 1] = { id = spellID, order = override.order or 0 }
		end
	end
	table.sort(customs, function(a, b)
		return a.order < b.order
	end)
	for _, custom in ipairs(customs) do
		local name = SpellName(custom.id) or ("Spell " .. custom.id)
		entries[#entries + 1] = {
			id = custom.id,
			class = Overrides()[custom.id].class,
			name = name,
			expected = name,
			icon = SpellIcon(custom.id),
			enabled = Overrides()[custom.id].enabled ~= false,
			callout = ns.GenericCallout.CC,
			related = {},
			custom = true,
		}
	end
	return entries
end

-- Listed entries grouped by caster class in ns.ClassOrder, then uncategorized added
-- spells (class = nil). Empty groups are left out.
function SpellList.GetGroups()
	local byClass = {}
	local custom = {}
	for _, entry in ipairs(SpellList.GetEntries()) do
		if entry.class then
			byClass[entry.class] = byClass[entry.class] or {}
			table.insert(byClass[entry.class], entry)
		else
			custom[#custom + 1] = entry
		end
	end
	local groups = {}
	for _, classToken in ipairs(ns.ClassOrder) do
		if byClass[classToken] then
			groups[#groups + 1] = { class = classToken, entries = byClass[classToken] }
		end
	end
	if #custom > 0 then
		groups[#groups + 1] = { entries = custom }
	end
	return groups
end

function SpellList.ClassName(classToken)
	return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken]) or classToken
end

-- "<class icon> <name in class color>", for settings headers and chat.
function SpellList.ClassLabel(classToken)
	local name = SpellList.ClassName(classToken)
	local color = C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classToken)
	if color then
		name = color:WrapTextInColorCode(name)
	end
	local atlas = GetClassAtlas and GetClassAtlas(classToken:lower()) or ("classicon-" .. classToken:lower())
	return ("|A:%s:20:20|a  %s"):format(atlas, name)
end

function SpellList.HasListed(classToken)
	for _, entry in pairs(lookup) do
		if entry.class == classToken then
			return true
		end
	end
	return false
end

function SpellList.Rebuild()
	for key in pairs(lookup) do
		lookup[key] = nil
	end
	for _, entry in ipairs(SpellList.GetEntries()) do
		lookup[entry.id] = entry
		for _, relatedID in ipairs(entry.related) do
			if lookup[relatedID] == nil then
				lookup[relatedID] = entry
			end
		end
	end
end

-- A secret spell ID is never used as a table key: the list can only act on casts the
-- client lets the addon read.
local function Find(spellID)
	if Util.IsSecret(spellID) or spellID == nil then
		return nil
	end
	return lookup[spellID]
end

-- Main IDs only (not related ones): what the list rows show.
function SpellList.IsListed(spellID)
	local entry = lookup[spellID]
	return entry ~= nil and entry.id == spellID
end

function SpellList.IsEnabled(spellID)
	return SpellList.IsListed(spellID) and lookup[spellID].enabled
end

function SpellList.CalloutFor(spellID)
	local entry = Find(spellID)
	if entry and entry.enabled then
		return entry.callout
	end
	return nil
end

function SpellList.IsSuppressed(spellID)
	local entry = Find(spellID)
	return entry ~= nil and not entry.enabled
end

local function Changed()
	SpellList.Rebuild()
	ns.ApplySettings()
	if ns.SettingsUI then
		ns.SettingsUI.OnSpellListChanged()
	end
end

function SpellList.SetEnabled(spellID, enabled)
	local override = Overrides()[spellID] or {}
	override.enabled = enabled and true or false
	if not override.custom and override.enabled and not override.removed then
		override = nil
	end
	Overrides()[spellID] = override
	Changed()
end

-- Custom spells are forgotten; built-ins are hidden until restored or re-added.
function SpellList.Remove(spellID)
	local override = Overrides()[spellID]
	if override and override.custom then
		Overrides()[spellID] = nil
	elseif IsBuiltin(spellID) then
		Overrides()[spellID] = { removed = true }
	end
	Changed()
end

local CLASS_ALIASES = { DK = "DEATHKNIGHT", DH = "DEMONHUNTER" }

local function Normalize(text)
	return (text:upper():gsub("[%s%-_']", ""))
end

-- "monk", "Death Knight", "deathknight", "DK" -> class token; "" -> nil.
function SpellList.ParseClass(text)
	local key = Normalize(text or "")
	if key == "" then
		return nil, true
	end
	if CLASS_ALIASES[key] then
		return CLASS_ALIASES[key], true
	end
	for _, token in ipairs(ns.ClassOrder) do
		local male = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]
		local female = LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[token]
		if key == token or (male and key == Normalize(male)) or (female and key == Normalize(female)) then
			return token, true
		end
	end
	return nil, false
end

-- "<spell ID or link> [class]" -> spellID, rest of the text.
local function ParseInput(input)
	local linkID = input:match("[sS][pP][eE][lL][lL]:(%d+)")
	if linkID then
		local rest = input:gsub("|c%x+|[hH][^|]*|[hH]%[.-%]|[hH]|r", ""):gsub("|[hH][^|]*|[hH]%[.-%]|[hH]", "")
		return tonumber(linkID), rest
	end
	local id, rest = input:match("^%s*(%d+)(.*)$")
	return tonumber(id), rest or ""
end

-- Accepts "<spell ID> [class]" or a pasted spell link, e.g. "198898 monk". Adding an
-- already added spell with another class moves it there. Returns ok, message.
function SpellList.Add(input)
	local spellID, rest = ParseInput(tostring(input or ""))
	if not spellID or spellID <= 0 then
		return false, L.AddInvalid
	end
	local classToken, classOk = SpellList.ParseClass(rest)
	if not classOk then
		return false, L.AddUnknownClass:format(strtrim and strtrim(rest) or rest)
	end
	local name = SpellName(spellID)
	if not name then
		return false, L.AddUnknown:format(spellID)
	end
	local where = classToken and SpellList.ClassName(classToken) or L.ListUncategorized

	local override = Overrides()[spellID]
	if IsBuiltin(spellID) then
		if override and override.removed then
			Overrides()[spellID] = nil
			Changed()
			return true, L.AddRestored:format(name, spellID)
		end
		return false, L.AddDuplicate:format(name, spellID)
	end
	if override and override.custom then
		if classToken and override.class ~= classToken then
			override.class = classToken
			Changed()
			return true, L.AddMoved:format(name, spellID, where)
		end
		return false, L.AddDuplicate:format(name, spellID)
	end

	local order = 0
	for _, other in pairs(Overrides()) do
		if other.custom and (other.order or 0) > order then
			order = other.order
		end
	end
	Overrides()[spellID] = { custom = true, enabled = true, order = order + 1, class = classToken }
	Changed()
	return true, L.AddDone:format(name, spellID, where)
end

-- Brings back removed or disabled built-ins; custom spells stay.
function SpellList.RestoreBuiltins()
	for spellID, override in pairs(Overrides()) do
		if not override.custom then
			Overrides()[spellID] = nil
		end
	end
	Changed()
end
