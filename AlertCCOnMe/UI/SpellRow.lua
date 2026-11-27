local _, ns = ...

-- Spell list row: Blizzard's checkbox-with-button row (behaviour unchanged), laid out
-- as a table: the spell label takes all free width, then two narrow action columns,
-- on/off and remove. Used through UI/SpellRow.xml's AlertCCOnMeSpellRowTemplate, so
-- Blizzard's own rows of that type keep their layout.
local ACTION_SIZE = 26 -- matches the checkbox
local COLUMN_GAP = 8
local RIGHT_PAD = 16

AlertCCOnMeSpellRowMixin = {}

-- Filled in at ADDON_LOADED, once Blizzard's settings mixins are certainly loaded;
-- the template's frames are only created when the panel is first opened.
function ns.InitSpellRowMixin()
	Mixin(AlertCCOnMeSpellRowMixin, SettingsCheckboxWithButtonControlMixin)

	function AlertCCOnMeSpellRowMixin:OnLoad()
		SettingsCheckboxWithButtonControlMixin.OnLoad(self)
		self.Button:SetSize(ACTION_SIZE, ACTION_SIZE)
		self.Button:ClearAllPoints()
		self.Button:SetPoint("RIGHT", self, "RIGHT", -RIGHT_PAD, 0)
		self.Checkbox:ClearAllPoints()
		self.Checkbox:SetPoint("RIGHT", self.Button, "LEFT", -COLUMN_GAP, 0)
		-- The label's hover/tooltip area stops where the action columns start.
		self.Tooltip:ClearAllPoints()
		self.Tooltip:SetPoint("TOPLEFT")
		self.Tooltip:SetPoint("BOTTOMRIGHT", self.Checkbox, "BOTTOMLEFT", -COLUMN_GAP, 0)
	end

	function AlertCCOnMeSpellRowMixin:Init(initializer)
		SettingsCheckboxWithButtonControlMixin.Init(self, initializer)
		-- The base Init pins the label's right edge to the row's center on every reuse.
		self.Text:SetPoint("RIGHT", self.Checkbox, "LEFT", -COLUMN_GAP, 0)
	end
end
