-- Offline micro-benchmark: the addon under Lua 5.1 (WoW's language version) and
-- tests/wow_mock.lua. Numbers include mock overhead, so read them relatively: before vs
-- after a change, or one scenario against another. Real in-game cost: /accm perf.
--
-- Usage (repo root): tests/run.sh bench
package.path = "./?.lua;" .. package.path
local helper = require("tests.helper")

local env = helper.newClient()

local function Bench()
	local M, S = TEST, TEST.secret
	M.quiet = true
	M.fire("ADDON_LOADED", "AlertCCOnMe")
	M.fire("PLAYER_LOGIN")

	local function cast(secret, spellID, onMe)
		local w = secret and S or function(v) return v end
		return {
			kind = "cast", name = w("Frostbolt"), texture = w(135846),
			startMs = w(M.time * 1000), endMs = w(M.time * 1000 + 1700),
			spellID = secret and S(spellID) or spellID,
			onMe = secret and S(onMe) or onMe,
		}
	end

	-- 40 hostile players with nameplates, all casting.
	local function populate(secret, spellID, onMe)
		for i = 1, 40 do
			local unit = "nameplate" .. i
			M.nameplates[unit] = {}
			-- In restricted content "nameplateNtarget" is secret too.
			local targetIsMe = secret and S(onMe) or onMe
			M.units[unit] = { hostile = true, isPlayer = true, unitTargetIsMe = targetIsMe, cast = cast(secret, spellID, onMe) }
		end
	end

	local function shownSlots()
		local n = 0
		for i = 1, 40 do
			local slot = ns.Display.GetSlot("nameplate" .. i)
			if slot and slot:IsShown() then n = n + 1 end
		end
		return n
	end

	local function measure(label, iterations, fn)
		collectgarbage("collect")
		collectgarbage("stop")
		local kb0, t0 = collectgarbage("count"), os.clock()
		for i = 1, iterations do fn(i) end
		local seconds, kb = os.clock() - t0, collectgarbage("count") - kb0
		collectgarbage("restart")
		return { label = label, us = seconds * 1e6 / iterations, bytes = kb * 1024 / iterations }
	end

	local results = {}
	local function castStorm(label, secret, spellID, onMe)
		populate(secret, spellID, onMe)
		results[#results + 1] = measure(label, 20000, function(i)
			M.fireUnit("UNIT_SPELLCAST_START", "nameplate" .. (i % 40 + 1))
		end)
		results[#results].shown = shownSlots()
		ns.Display.HideAll()
	end

	castStorm("cast event: readable non-CC, not at me (open world)", false, 116, false)
	castStorm("cast event: readable CC at me (open world)", false, 118, true)
	castStorm("cast event: all secret, not at me (arena/BG)", true, 116, false)

	-- Per-frame cost while every enemy is mid-cast (secret, so every slot stays shown).
	populate(true, 116, false)
	for i = 1, 40 do M.fireUnit("UNIT_SPELLCAST_START", "nameplate" .. i) end
	-- Only this addon's per-frame handlers, not the mock's own frame loop.
	local handlers = {}
	for _, f in ipairs(M.frames) do
		if rawget(f, "shown") and f.scripts.OnUpdate then handlers[#handlers + 1] = f end
	end
	results[#results + 1] = measure("per frame: OnUpdate handlers, 40 secret casts", 5000, function()
		for _, f in ipairs(handlers) do f.scripts.OnUpdate(f, 0) end
	end)
	results[#results].shown = #handlers .. "h/" .. shownSlots()

	results[#results + 1] = measure("full rescan (PLAYER_ENTERING_WORLD)", 2000, function()
		M.fire("PLAYER_ENTERING_WORLD")
	end)
	return results
end

local results = setfenv(Bench, env)()
print(("%-56s%9s%10s%7s"):format("scenario", "us/op", "bytes/op", "shown"))
for _, r in ipairs(results) do
	print(("%-56s%9.1f%10.0f%7s"):format(r.label, r.us, r.bytes, tostring(r.shown or "")))
end
