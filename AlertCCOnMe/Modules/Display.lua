local _, ns = ...

local Util = ns.Util
local L = ns.L
local IsSecret = Util.IsSecret

local Display = {}
ns.Display = Display

local anchor
local slots = {}
local TEST_KEY = "test"
local FLASH_TEXTURE = "Interface\\FullScreenTextures\\LowHealth"
local FALLBACK_ICON = 136071 -- Polymorph

local function HasValue(value)
	return IsSecret(value) or value ~= nil
end

-- SetAlphaFromBoolean is the only secret-safe visibility switch for tainted code;
-- SetShown rejects secrets. A missing value hides the gate.
local function ApplyGate(frame, value)
	if HasValue(value) then
		frame:SetAlphaFromBoolean(value, 1, 0)
	else
		frame:SetAlpha(0)
	end
end

local function SavePosition()
	local point, _, relativePoint, x, y = anchor:GetPoint(1)
	local db = ns.db
	db.Point, db.RelativePoint = point or "CENTER", relativePoint or "CENTER"
	db.X, db.Y = math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5)
end

local function CreateAnchor()
	anchor = CreateFrame("Frame", "AlertCCOnMeAnchor", UIParent)
	anchor:SetFrameStrata("HIGH")
	anchor:SetClampedToScreen(true)
	anchor:SetMovable(true)
	anchor:RegisterForDrag("LeftButton")
	-- Shift is required so a stray click while the edit box is up never moves it.
	anchor:SetScript("OnDragStart", function(self)
		if not ns.db.Locked and IsShiftKeyDown() then
			self.moving = true
			self:StartMoving()
		end
	end)
	anchor:SetScript("OnDragStop", function(self)
		if self.moving then
			self.moving = false
			self:StopMovingOrSizing()
			SavePosition()
		end
	end)
	anchor:SetScript("OnMouseWheel", function(_, delta)
		if ns.db.Locked or not IsShiftKeyDown() then
			return
		end
		local scale = Util.Clamp(ns.db.Scale, 0.5, 2.5, 1) + (delta > 0 and 0.05 or -0.05)
		ns.db.Scale = Util.Clamp(math.floor(scale * 100 + 0.5) / 100, 0.5, 2.5, 1)
		Display.ApplySettings()
	end)
	anchor:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" and not ns.db.Locked then
			ns.SetLocked(true)
		end
	end)

	anchor.handle = anchor:CreateTexture(nil, "BACKGROUND")
	anchor.handle:SetAllPoints()
	anchor.handle:SetColorTexture(0.1, 0.6, 1, 0.2)
	anchor.edges = {}
	local EDGES = {
		{ "TOPLEFT", "TOPRIGHT" },
		{ "BOTTOMLEFT", "BOTTOMRIGHT" },
		{ "TOPLEFT", "BOTTOMLEFT", vertical = true },
		{ "TOPRIGHT", "BOTTOMRIGHT", vertical = true },
	}
	for _, edge in ipairs(EDGES) do
		local line = anchor:CreateTexture(nil, "BORDER")
		line:SetColorTexture(0.2, 0.7, 1, 0.9)
		line:SetPoint(edge[1])
		line:SetPoint(edge[2])
		if edge.vertical then
			line:SetWidth(1)
		else
			line:SetHeight(1)
		end
		anchor.edges[#anchor.edges + 1] = line
	end
	anchor.handleText = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	anchor.handleText:SetPoint("BOTTOM", anchor, "TOP", 0, 3)
	anchor.handleText:SetText(L.EditHint)
end

-- Fit the edit box to what the alert actually draws.
local function SizeAnchor()
	local v = ns.db.Visual
	local height = Util.Clamp(v.FontSize, 10, 72, 26) + 16
	if v.ShowIcon then
		height = height + Util.Clamp(v.IconSize, 16, 160, 56) + 6
	end
	anchor:SetSize(math.max(240, Util.Clamp(v.FontSize, 10, 72, 26) * 11), height)
end

local function CreateSlot(key)
	local slot = CreateFrame("Frame", nil, anchor)
	slot:SetAllPoints(anchor)
	slot:Hide()

	slot.ccGate = CreateFrame("Frame", nil, slot)
	slot.ccGate:SetAllPoints(slot)

	slot.meGate = CreateFrame("Frame", nil, slot.ccGate)
	slot.meGate:SetAllPoints(slot.ccGate)

	local content = slot.meGate

	slot.iconBorder = content:CreateTexture(nil, "BORDER")
	slot.iconBorder:SetColorTexture(0, 0, 0, 0.9)

	slot.icon = content:CreateTexture(nil, "ARTWORK")
	slot.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	slot.iconBorder:SetPoint("TOPLEFT", slot.icon, -2, 2)
	slot.iconBorder:SetPoint("BOTTOMRIGHT", slot.icon, 2, -2)

	slot.text = content:CreateFontString(nil, "OVERLAY")
	slot.text:SetFont(STANDARD_TEXT_FONT, 26, "OUTLINE")
	slot.text:SetShadowOffset(1, -1)

	-- Parented to the gates so it inherits their alpha, but stretched over the screen.
	slot.flash = CreateFrame("Frame", nil, content)
	slot.flash:SetAllPoints(UIParent)
	slot.flash:SetFrameStrata("BACKGROUND")
	slot.flash.tex = slot.flash:CreateTexture(nil, "BACKGROUND")
	slot.flash.tex:SetAllPoints()
	slot.flash.tex:SetTexture(FLASH_TEXTURE)
	slot.flash.tex:SetVertexColor(1, 0, 0)
	slot.flash.tex:SetBlendMode("ADD")
	local flashAnim = slot.flash.tex:CreateAnimationGroup()
	flashAnim:SetLooping("BOUNCE")
	local fade = flashAnim:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0.25)
	fade:SetDuration(0.35)
	slot.flashAnim = flashAnim

	-- Scale, not alpha: an alpha animation would fight the secret-driven gates.
	local pulse = slot.icon:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	local grow = pulse:CreateAnimation("Scale")
	grow:SetScaleFrom(1, 1)
	grow:SetScaleTo(1.15, 1.15)
	grow:SetDuration(0.3)
	slot.pulse = pulse

	slot.key = key
	return slot
end

local expiries = {} -- slot -> pending safety timer

local function CancelExpiry(slot)
	if expiries[slot] then
		expiries[slot]:Cancel()
		expiries[slot] = nil
	end
end

-- Safety net for a missed stop event. A one-shot timer, not OnUpdate: in restricted
-- content every enemy cast keeps a (gated, invisible) slot shown, and per-frame
-- handlers on all of them add up.
local function ScheduleExpiry(slot, key, seconds)
	CancelExpiry(slot)
	if seconds < math.huge then
		expiries[slot] = C_Timer.NewTimer(seconds, function()
			expiries[slot] = nil
			Display.Hide(key)
		end)
	end
end

local function LayoutSlot(slot)
	local v = ns.db.Visual
	local size = Util.Clamp(v.IconSize, 16, 160, 56)

	slot.icon:ClearAllPoints()
	slot.icon:SetPoint("TOP", slot, "TOP", 0, 0)
	slot.icon:SetSize(size, size)
	slot.icon:SetShown(v.ShowIcon)
	slot.iconBorder:SetShown(v.ShowIcon)

	local color = v.TextColor or ns.Defaults.Visual.TextColor
	slot.text:SetFont(STANDARD_TEXT_FONT, Util.Clamp(v.FontSize, 10, 72, 26), "OUTLINE")
	slot.text:SetTextColor(color.r, color.g, color.b)
	slot.text:ClearAllPoints()
	if v.ShowIcon then
		slot.text:SetPoint("TOP", slot.icon, "BOTTOM", 0, -6)
	else
		slot.text:SetPoint("TOP", slot, "TOP", 0, 0)
	end
	slot.text:SetShown(v.ShowText)
end

local function GetSlot(key)
	local slot = slots[key]
	if not slot then
		slot = CreateSlot(key)
		slots[key] = slot
		LayoutSlot(slot)
	end
	return slot
end

local function StartEffects(slot)
	local v = ns.db.Visual
	if v.ShowScreenFlash then
		slot.flash:SetAlpha(Util.Clamp(v.FlashAlpha, 0.05, 1, 0.55))
		slot.flash:Show()
		slot.flashAnim:Play()
	else
		slot.flashAnim:Stop()
		slot.flash:Hide()
	end
	if v.Pulse and v.ShowIcon then
		slot.pulse:Play()
	else
		slot.pulse:Stop()
	end
end

local function StopEffects(slot)
	slot.flashAnim:Stop()
	slot.pulse:Stop()
end

-- `cast` and `eval` fields may be secrets; they are only handed to widget APIs.
function Display.Show(key, cast, eval)
	local slot = GetSlot(key)
	local v = ns.db.Visual

	if ns.db.RequireCC then
		ApplyGate(slot.ccGate, eval.isCC)
	else
		slot.ccGate:SetAlpha(1)
	end
	ApplyGate(slot.meGate, eval.onMe)

	if HasValue(cast.texture) then
		slot.icon:SetTexture(cast.texture)
	else
		slot.icon:SetTexture(FALLBACK_ICON)
	end

	local pattern = Util.IsSafeFormat(v.TextFormat) and v.TextFormat or ns.Defaults.Visual.TextFormat
	slot.text:SetFormattedText(pattern, cast.name)

	ScheduleExpiry(slot, key, cast.timeout or ns.CAST_SAFETY_TIMEOUT)
	slot:Show()
	StartEffects(slot)
end

function Display.Hide(key)
	local slot = slots[key]
	if not slot then
		return
	end
	if key == TEST_KEY and not ns.db.Locked then
		return
	end
	CancelExpiry(slot)
	StopEffects(slot)
	slot:Hide()
end

function Display.HideAll()
	for key in pairs(slots) do
		Display.Hide(key)
	end
end

function Display.ShowTest(duration)
	local texture = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(118) or FALLBACK_ICON
	Display.Show(TEST_KEY, {
		name = L.TestText,
		texture = texture,
		timeout = duration or 3,
	}, { isCC = true, onMe = true })
end

function Display.ApplySettings()
	local db = ns.db
	anchor:ClearAllPoints()
	anchor:SetPoint(db.Point or "CENTER", UIParent, db.RelativePoint or "CENTER", db.X or 0, db.Y or 0)
	anchor:SetScale(Util.Clamp(db.Scale, 0.5, 2.5, 1))
	SizeAnchor()
	-- Locked: no mouse at all, so the alert never eats clicks mid-fight.
	anchor:EnableMouse(not db.Locked)
	anchor:EnableMouseWheel(not db.Locked)
	anchor.handle:SetShown(not db.Locked)
	anchor.handleText:SetShown(not db.Locked)
	for _, line in ipairs(anchor.edges) do
		line:SetShown(not db.Locked)
	end
	anchor:Show()

	for _, slot in pairs(slots) do
		LayoutSlot(slot)
	end

	if not db.Locked then
		Display.ShowTest(math.huge)
	else
		Display.Hide(TEST_KEY)
	end
end

function Display.ResetPosition()
	local d = ns.Defaults
	ns.db.Point, ns.db.RelativePoint, ns.db.X, ns.db.Y = d.Point, d.RelativePoint, d.X, d.Y
	Display.ApplySettings()
end

-- Alert frames currently shown, visible or gated to alpha 0 (for /accm perf).
function Display.CountShown()
	local count = 0
	for _, slot in pairs(slots) do
		if slot:IsShown() then
			count = count + 1
		end
	end
	return count
end

-- Used by the offline tests and /accm debug tooling.
function Display.GetSlot(key)
	return slots[key]
end

function Display.Initialize()
	CreateAnchor()
	Display.ApplySettings()
end
