local addonName, ns = ...

ns.ADDON_NAME = addonName
ns.PREFIX = "|cff33ff99AlertCCOnMe|r"
ns.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"

ns.MAX_NAMEPLATES = 40
ns.MAX_ARENA = 5
-- Stop events are the primary teardown; this only catches a missed stop.
ns.CAST_SAFETY_TIMEOUT = 30

local Util = {}
ns.Util = Util

function Util.IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

-- Readable means safe to compare or branch on from tainted code.
function Util.IsReadable(value)
	return not Util.IsSecret(value)
end

function Util.Print(message)
	DEFAULT_CHAT_FRAME:AddMessage(ns.PREFIX .. ": " .. tostring(message))
end

function Util.CopyDefaults(source, target)
	for key, value in pairs(source) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			Util.CopyDefaults(value, target[key])
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

function Util.CopyTable(source)
	if type(source) ~= "table" then
		return source
	end
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = Util.CopyTable(value)
	end
	return copy
end

function Util.Clamp(value, minValue, maxValue, fallback)
	local n = tonumber(value)
	if not n then
		return fallback
	end
	return math.max(minValue, math.min(maxValue, n))
end

-- The alert text is fed to FontString:SetFormattedText with a possibly-secret spell
-- name, so the pattern must hold exactly one %s and no other conversions.
function Util.IsSafeFormat(pattern)
	if type(pattern) ~= "string" or pattern == "" then
		return false
	end
	local stripped = pattern:gsub("%%%%", "")
	local _, count = stripped:gsub("%%", "")
	local _, sCount = stripped:gsub("%%s", "")
	return count == 1 and sCount == 1
end

-- pcall wrapper for APIs that may be absent or raise on restricted tokens.
function Util.SafeCall(fn, ...)
	if type(fn) ~= "function" then
		return false
	end
	return pcall(fn, ...)
end
