-- Adds this folder as a voice pack. It then shows up in
-- Settings > Alert CC On Me > Sound > Voice.
local addonName = ...
AlertCCOnMe_RegisterVoicePack("Example", "Interface\\AddOns\\" .. addonName .. "\\Voice\\")
