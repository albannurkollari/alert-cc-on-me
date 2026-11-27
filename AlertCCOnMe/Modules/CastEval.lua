local _, ns = ...

local Util = ns.Util
local IsSecret = Util.IsSecret
local SafeCall = Util.SafeCall

local CastEval = {}
ns.CastEval = CastEval

-- Presence test that never compares a secret: a secret name means a cast exists.
local function IsPresent(value)
	if IsSecret(value) then
		return true
	end
	return value ~= nil
end

-- Returns the current cast/channel of `unit`, or nil. Fields may be secrets.
function CastEval.ReadCast(unit)
	local ok, name, _, texture, startMs, endMs, isTradeskill, _, _, spellID = SafeCall(UnitCastingInfo, unit)
	if ok and IsPresent(name) then
		if isTradeskill == true then
			return nil
		end
		return {
			kind = "cast",
			name = name,
			texture = texture,
			startMs = startMs,
			endMs = endMs,
			spellID = spellID,
		}
	end

	local okChannel, cName, _, cTexture, cStart, cEnd, cTradeskill, _, cSpellID = SafeCall(UnitChannelInfo, unit)
	if okChannel and IsPresent(cName) then
		if cTradeskill == true then
			return nil
		end
		return {
			kind = "channel",
			name = cName,
			texture = cTexture,
			startMs = cStart,
			endMs = cEnd,
			spellID = cSpellID,
		}
	end

	return nil
end

-- A secret answer counts as "maybe", so the unit stays watched.
function CastEval.IsHostile(unit)
	local ok, canAttack = SafeCall(UnitCanAttack, "player", unit)
	if not ok or IsSecret(canAttack) then
		return true
	end
	return canAttack == true
end

-- Returns true / false when readable, nil when unknown.
function CastEval.IsPlayerUnit(unit)
	if type(unit) == "string" and unit:find("^arena%d") then
		return true
	end
	local ok, isPlayer = SafeCall(UnitIsPlayer, unit)
	if not ok or IsSecret(isPlayer) then
		return nil
	end
	return isPlayer == true
end

-- `isCC` and `onMe` may be secrets; they drive the display gates as-is.
-- `onMeReadable` is a plain boolean (or nil) usable for sound decisions: the exact
-- PlayerIsSpellTarget answer when readable, else the caster's unit target when that
-- comparison is readable (open world), else nil.
function CastEval.Evaluate(unit, cast)
	local result = {}

	-- Assigned via `if ok` rather than `ok and x or nil`: truth-testing a secret raises.
	local okCC, isCC = SafeCall(C_Spell and C_Spell.IsSpellCrowdControl, cast.spellID)
	if okCC then
		result.isCC = isCC
	end

	local okMe, onMe = SafeCall(PlayerIsSpellTarget, unit)
	if okMe then
		result.onMe = onMe
	end

	if okMe and not IsSecret(onMe) and onMe ~= nil then
		result.onMeReadable = onMe == true
	else
		local okUnit, same = SafeCall(UnitIsUnit, unit .. "target", "player")
		if okUnit and not IsSecret(same) and same ~= nil then
			result.onMeReadable = same == true
		end
	end

	if okCC and not IsSecret(isCC) and isCC ~= nil then
		result.isCCReadable = isCC == true
	end

	return result
end

-- Pure decision: should the pre-cast sound play? Only readable facts are used.
function CastEval.ShouldPlaySound(mode, requireCC, eval, isPlayerUnit)
	local ccKnown = eval.isCCReadable ~= nil
	local ccTrue = eval.isCCReadable == true
	if not requireCC then
		ccKnown, ccTrue = true, true
	end
	local meKnown = eval.onMeReadable ~= nil
	local meTrue = eval.onMeReadable == true

	if mode == ns.SoundModes.CONFIRMED then
		return ccTrue and meTrue
	elseif mode == ns.SoundModes.CC_ANY_TARGET then
		return ccTrue and (meTrue or not meKnown)
	elseif mode == ns.SoundModes.ANY_PLAYER_CAST then
		if isPlayerUnit ~= true then
			return false
		end
		if ccKnown and not ccTrue then
			return false
		end
		if meKnown and not meTrue then
			return false
		end
		return true
	end
	return false
end
