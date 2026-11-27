-- Minimal WoW API mock for offline tests. Secrets are proxies whose metamethods
-- raise, and every widget method / API outside the secret allow-list rejects them.
local M = {}
_G.TEST = M

M.calls = {}
M.sounds = {}
M.frames = {}
M.time = 1000
M.inCombat = false
M.instanceType = "none"
M.units = {}
M.nameplates = {}
M.auraSounds = {}

local secretMeta = {}
local function boom(op)
	return function()
		error("secret value misuse: " .. op, 2)
	end
end
for _, op in ipairs({ "__index", "__newindex", "__concat", "__add", "__sub", "__mul", "__div",
	"__mod", "__unm", "__pow", "__lt", "__le", "__call", "__len", "__tostring" }) do
	secretMeta[op] = boom(op)
end

local secrets = setmetatable({}, { __mode = "k" })
function M.secret(value)
	local proxy = setmetatable({}, secretMeta)
	secrets[proxy] = { value = value }
	return proxy
end
function M.reveal(value)
	local s = secrets[value]
	if s then
		return s.value
	end
	return value
end
function issecretvalue(value)
	return type(value) == "table" and secrets[value] ~= nil
end

local function assertNoSecrets(where, ...)
	for i = 1, select("#", ...) do
		if issecretvalue((select(i, ...))) then
			error("secret passed to " .. where .. " (arg " .. i .. ")", 3)
		end
	end
end

-- Widget methods that accept secrets from tainted code (per 12.1.5 API docs).
local SECRET_OK = {
	SetAlphaFromBoolean = true,
	SetTexture = true,
	SetFormattedText = true,
	SetText = true,
	SetMinMaxValues = true,
	SetValue = true,
}

local Widget = {}
Widget.__index = function(self, key)
	local method = rawget(Widget, key)
	if method then
		return method
	end
	return function(obj, ...)
		if not SECRET_OK[key] then
			assertNoSecrets(key, ...)
		end
		if not M.quiet then
			obj.log[#obj.log + 1] = { key, ... }
		end
		return nil
	end
end

local function NewWidget(kind, parent)
	local w = setmetatable({ kind = kind, parent = parent, log = {}, shown = true, alpha = 1, scripts = {}, points = {} }, Widget)
	M.frames[#M.frames + 1] = w
	return w
end

function Widget:Show() self.shown = true end
function Widget:Hide() self.shown = false end
function Widget:IsShown() return self.shown end
function Widget:SetShown(v) assertNoSecrets("SetShown", v); self.shown = v and true or false end
function Widget:SetAlpha(a) assertNoSecrets("SetAlpha", a); self.alpha = a end
function Widget:SetAlphaFromBoolean(value, a, b)
	if value == nil then
		error("SetAlphaFromBoolean: nil value", 2)
	end
	rawset(self, "alphaFromBool", value)
	self.alpha = M.reveal(value) and (a or 1) or (b or 0)
end
function Widget:SetScript(name, fn) self.scripts[name] = fn end
function Widget:GetScript(name) return self.scripts[name] end
function Widget:SetPoint(...) assertNoSecrets("SetPoint", ...); self.points[#self.points + 1] = { ... } end
function Widget:GetPoint() return "CENTER", nil, "CENTER", 0, 180 end
function Widget:SetTexture(t) self.texture = t end
function Widget:SetText(t) self.text = t end
function Widget:GetText() return self.text end
function Widget:SetFormattedText(fmt, ...)
	assertNoSecrets("SetFormattedText(format)", fmt)
	self.format, self.formatArgs = fmt, { ... }
end
function Widget:SetMinMaxValues(a, b) self.min, self.max = a, b end
function Widget:SetValue(v) assertNoSecrets("SetValue(plain expected)", v); self.value = v end
function Widget:RegisterEvent(e) rawset(self, "events", rawget(self, "events") or {}); self.events[e] = true end
function Widget:UnregisterEvent(e) local ev = rawget(self, "events"); if ev then ev[e] = nil end end
function Widget:RegisterUnitEvent(e, unit)
	rawset(self, "unitEvents", rawget(self, "unitEvents") or {})
	self.unitEvents[e] = unit
end
function Widget:CreateTexture() return NewWidget("Texture", self) end
function Widget:CreateFontString() return NewWidget("FontString", self) end
function Widget:CreateAnimationGroup() return NewWidget("AnimationGroup", self) end
function Widget:CreateAnimation() return NewWidget("Animation", self) end
function Widget:Play() self.playing = true end
function Widget:Stop() self.playing = false end

function CreateFrame(kind, name, parent)
	local w = NewWidget(kind, parent)
	if name then
		_G[name] = w
	end
	return w
end

-- Effective visibility, as the client would render it: shown chain * alpha chain.
function M.effectiveAlpha(w)
	local alpha = 1
	while w do
		if not rawget(w, "shown") then
			return 0
		end
		alpha = alpha * (rawget(w, "alpha") or 1)
		w = rawget(w, "parent")
	end
	return alpha
end

UIParent = NewWidget("Frame")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) M.chat[#M.chat + 1] = msg end }
M.chat = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
SlashCmdList = {}

function GetTime() return M.time end
function InCombatLockdown() return M.inCombat end
function IsShiftKeyDown() return M.shift == true end
function IsInInstance() return M.instanceType ~= "none", M.instanceType end
function GetBuildInfo() return "12.1.5", "70961" end
function PlaySoundFile(path, channel)
	assertNoSecrets("PlaySoundFile", path, channel)
	M.sounds[#M.sounds + 1] = path
end

local function U(unit)
	return M.units[unit]
end
function UnitExists(unit) return U(unit) ~= nil end
function UnitCanAttack(_, unit) local u = U(unit); return u and u.hostile or false end
function UnitIsPlayer(unit) local u = U(unit); return u and u.isPlayer or false end
function UnitIsUnit(a, b)
	local base = a:match("^(.-)target$")
	if base and b == "player" then
		local u = U(base)
		if not u then return false end
		return u.unitTargetIsMe
	end
	return a == b
end
function UnitCastingInfo(unit)
	local u = U(unit)
	local c = u and u.cast
	if not c or c.kind ~= "cast" then return nil end
	return c.name, c.name, c.texture, c.startMs, c.endMs, false, "castguid", false, c.spellID
end
function UnitChannelInfo(unit)
	local u = U(unit)
	local c = u and u.cast
	if not c or c.kind ~= "channel" then return nil end
	return c.name, c.name, c.texture, c.startMs, c.endMs, false, false, c.spellID
end
function PlayerIsSpellTarget(unit)
	local u = U(unit)
	if not u or not u.cast then return false end
	return u.cast.onMe
end

M.spellNames = { [118] = "Polymorph", [28272] = "Polymorph", [5782] = "Fear", [118699] = "Fear", [33786] = "Cyclone" }
C_Spell = {
	GetSpellName = function(spellID) return M.spellNames[spellID] end,
	IsSpellCrowdControl = function(spellID)
		if issecretvalue(spellID) then
			return M.secret(M.ccSpells[M.reveal(spellID)] == true)
		end
		return M.ccSpells[spellID] == true
	end,
	GetSpellTexture = function() return 136071 end,
}
M.ccSpells = { [118] = true, [33786] = true, [5782] = true }

C_Secrets = { GetSpellCastSecrecy = function(id) return M.castSecrecy[id] or 2 end }
M.castSecrecy = {}
C_PvP = { IsArena = function() return M.instanceType == "arena" end }
C_NamePlate = { GetNamePlateForUnit = function(unit) return M.nameplates[unit] end }
C_AddOns = { GetAddOnMetadata = function() return "0.1.0" end }
C_RestrictedActions = { GetAddOnRestrictionState = function() return 0 end }

Enum = { UnitAuraSoundTrigger = { Added = 0 } }
local nextHandle = 0
C_UnitAuras = {
	AddAuraSound = function(trigger, info)
		if M.inCombat then error("AddAuraSound restricted in combat") end
		assertNoSecrets("AddAuraSound", trigger, info.unitToken, info.spellID, info.soundFileName)
		nextHandle = nextHandle + 1
		M.auraSounds[nextHandle] = info
		return nextHandle
	end,
	RemoveAuraSound = function(handle) M.auraSounds[handle] = nil end,
}

-- Blizzard Settings API stubs.
local function settingObj(var, key, tbl)
	return { var = var, key = key, tbl = tbl, SetValueChangedCallback = function(self, cb) self.cb = cb end }
end
M.settings = {}
Settings = {
	VarType = { Boolean = "boolean", Number = "number", String = "string" },
	RegisterVerticalLayoutCategory = function(name)
		local layout = { AddInitializer = function() end }
		return { name = name, GetID = function() return 1 end }, layout
	end,
	RegisterVerticalLayoutSubcategory = function(parent, name)
		assert(parent, "subcategory needs a parent")
		M.spellLayout = { inits = {}, AddInitializer = function(self, init) self.inits[#self.inits + 1] = init; return init end,
			GetInitializers = function(self) return self.inits end }
		return { name = name, GetID = function() return 2 end }, M.spellLayout
	end,
	RegisterProxySetting = function(_, var, varType, name, default, getValue, setValue)
		assert(type(default) == varType, "proxy default type for " .. var)
		assert(not M.settings[var], "duplicate setting variable " .. var)
		local s = { var = var, name = name, GetValue = function() return getValue() end, SetValue = function(_, v) setValue(v) end }
		M.settings[var] = s
		return s
	end,
	RegisterAddOnSetting = function(_, var, key, tbl, varType, name, default)
		assert(type(tbl) == "table", "variableTbl must be a table for " .. var)
		assert(default ~= nil, "default missing for " .. var)
		assert(type(default) == varType, ("default type %s ~= %s for %s"):format(type(default), varType, var))
		assert(not M.settings[var], "duplicate setting variable " .. var)
		local s = settingObj(var, key, tbl)
		M.settings[var] = s
		return s
	end,
	CreateCheckbox = function() end,
	CreateSlider = function() end,
	CreateSliderOptions = function() return { SetLabelFormatter = function() end } end,
	CreateDropdown = function(_, _, getOptions) assert(type(getOptions()) == "table") end,
	CreateControlTextContainer = function()
		local data = {}
		return { Add = function(_, v, t) data[#data + 1] = { value = v, text = t } end, GetData = function() return data end }
	end,
	RegisterAddOnCategory = function() end,
	OpenToCategory = function() M.openedSettings = true end,
}
local function withPredicates(init)
	init.preds = {}
	init.AddShownPredicate = function(self, f) self.preds[#self.preds + 1] = f end
	init.ShouldShow = function(self) for _, f in ipairs(self.preds) do if not f() then return false end end return true end
	return init
end
function CreateSettingsListSectionHeaderInitializer(name, tooltip) return withPredicates({ header = name, tooltip = tooltip }) end
LOCALIZED_CLASS_NAMES_MALE = { DEATHKNIGHT = "Death Knight", DEMONHUNTER = "Demon Hunter", ROGUE = "Rogue", WARRIOR = "Warrior", DRUID = "Druid", EVOKER = "Evoker", HUNTER = "Hunter", MAGE = "Mage", MONK = "Monk", PALADIN = "Paladin", PRIEST = "Priest", SHAMAN = "Shaman", WARLOCK = "Warlock" }
function CreateSettingsButtonInitializer(name, text, onClick) return { name = name, onClick = onClick } end
function CreateSettingsCheckboxWithButtonInitializer(setting, buttonText, onClick)
	return {
		setting = setting, buttonText = buttonText, onClick = onClick, preds = {},
		AddShownPredicate = function(self, f) self.preds[#self.preds + 1] = f end,
		ShouldShow = function(self) for _, f in ipairs(self.preds) do if not f() then return false end end return true end,
	}
end
Settings.CreateSettingInitializerData = function(setting, options, tooltip)
	return { setting = setting, options = options, tooltip = tooltip }
end
Settings.CreateSettingInitializer = function(template, data)
	local init = withPredicates({ template = template, data = data, setting = data.setting })
	-- Mirror the fields the tests read on checkbox-with-button rows.
	init.buttonText, init.onClick = data.buttonText, data.OnButtonClick
	return init
end
SettingsCheckboxWithButtonControlMixin = {
	OnLoad = function(self)
		self.Checkbox = CreateFrame("CheckButton", nil, self)
		self.Button = CreateFrame("Button", nil, self)
		self.Tooltip = CreateFrame("Frame", nil, self)
		self.Text = self:CreateFontString()
	end,
	Init = function(self) self.Text:SetPoint("RIGHT", self, "CENTER", -85, 0) end,
}
function Mixin(target, ...)
	for _, source in ipairs({ ... }) do
		for k, v in pairs(source) do target[k] = v end
	end
	return target
end
SettingsInbound = { RepairDisplay = function() M.repairs = (M.repairs or 0) + 1 end }
StaticPopupDialogs = {}
function StaticPopup_Show(name) M.popup = name end
CANCEL = "Cancel"

-- Event plumbing.
function M.fire(event, ...)
	for _, f in ipairs(M.frames) do
		local ev = rawget(f, "events"); if ev and ev[event] and f.scripts.OnEvent then
			f.scripts.OnEvent(f, event, ...)
		end
	end
end
function M.fireUnit(event, unit, ...)
	for _, f in ipairs(M.frames) do
		local ue = rawget(f, "unitEvents"); if ue and ue[event] == unit and f.scripts.OnEvent then
			f.scripts.OnEvent(f, event, unit, ...)
		end
	end
end
M.timers = {}
C_Timer = {
	NewTimer = function(seconds, callback)
		local timer = { at = M.time + seconds, callback = callback }
		timer.Cancel = function(self) self.cancelled = true end
		M.timers[#M.timers + 1] = timer
		return timer
	end,
}

function M.tick(seconds)
	M.time = M.time + (seconds or 0)
	for i = #M.timers, 1, -1 do
		local timer = M.timers[i]
		if timer.cancelled then
			table.remove(M.timers, i)
		elseif M.time >= timer.at then
			table.remove(M.timers, i)
			timer.callback()
		end
	end
	for _, f in ipairs(M.frames) do
		if rawget(f, "shown") and f.scripts.OnUpdate then
			f.scripts.OnUpdate(f, seconds or 0)
		end
	end
end

return M
