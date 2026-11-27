"""Offline micro-benchmark: the addon under plain Lua 5.1 (WoW's language version) and
tests/wow_mock.lua. Numbers include mock overhead, so read them relatively: before vs
after a change, or one scenario against another. Real in-game cost: /accm perf.

Usage: python tests/bench.py
"""
import pathlib
import sys

from lupa import lua51

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tests"))
from run_tests import TESTS, toc_files  # noqa: E402

BENCH = r"""
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
"""


def main():
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    lua.execute((TESTS / "wow_mock.lua").read_text(encoding="utf-8"))
    ns = lua.eval("{}")
    loader = lua.eval("function(src, name) return assert(loadstring(src, '@' .. name)) end")
    for path in toc_files():
        loader(path.read_text(encoding="utf-8"), path.name)("AlertCCOnMe", ns)
    lua.globals().ns = ns
    results = lua.execute(BENCH)
    print(f"{'scenario':<56}{'us/op':>9}{'bytes/op':>10}{'shown':>7}")
    for i in range(1, len(results) + 1):
        r = results[i]
        shown = r["shown"] if r["shown"] is not None else ""
        print(f"{r['label']:<56}{r['us']:>9.1f}{r['bytes']:>10.0f}{shown!s:>7}")


if __name__ == "__main__":
    main()
