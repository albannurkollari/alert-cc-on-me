"""Offline test runner: loads the addon under LuaJIT (lupa) with tests/wow_mock.lua.

Usage: python tests/run_tests.py   (needs `pip install lupa`)
"""
import pathlib
import re
import sys

from lupa import luajit21 as lupa_rt

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "AlertCCOnMe"
TESTS = ROOT / "tests"


def toc_files():
    files = []
    for line in (ADDON / "AlertCCOnMe.toc").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and line.lower().endswith(".lua"):
            files.append(ADDON / line.replace("\\", "/"))
    return files


def new_runtime():
    lua = lupa_rt.LuaRuntime(unpack_returned_tuples=True)
    lua.execute((TESTS / "wow_mock.lua").read_text(encoding="utf-8"))
    ns = lua.eval("{}")
    for path in toc_files():
        chunk = lua.eval("function(src, name) return assert(loadstring(src, '@' .. name)) end")(
            path.read_text(encoding="utf-8"), str(path.relative_to(ROOT)))
        chunk("AlertCCOnMe", ns)
    return lua, ns


def run_lua_tests():
    lua_src = (TESTS / "test_addon.lua").read_text(encoding="utf-8")
    names = re.findall(r"^T\[\"([^\"]+)\"\]", lua_src, flags=re.M)
    failures = 0
    for name in names:
        lua, ns = new_runtime()
        lua.globals().ns = ns
        lua.execute(lua_src)
        runner = lua.eval("function(name) local ok, err = xpcall(T[name], debug.traceback); return ok, err end")
        ok, err = runner(name)
        if ok:
            print(f"PASS  {name}")
        else:
            failures += 1
            print(f"FAIL  {name}\n      {err}")
    return failures, len(names)


# Truth-testing or comparing a secret cannot be trapped by a Lua mock, so flag the
# risky shapes statically: `x and y or z` / `if x then` on names known to carry secrets.
SECRET_NAMES = r"(isCC|onMe|cast\.name|cast\.texture|cast\.spellID|cast\.startMs|cast\.endMs|spellID|texture|name|startMs|endMs|plate|canAttack|isPlayer|same|exists|level|handle)"
RISKY = [
    re.compile(r"\b" + SECRET_NAMES + r"\s+and\s+[^\n]*\bor\b"),
    # Comparing before the secrecy check: the comparison itself raises on a secret.
    re.compile(r"\b(\w+)\s*[~=]=\s*nil\s+and\s+not\s+(?:Util\.)?IsSecret\(\1\)"),
]


def static_scan():
    issues = []
    for path in ADDON.rglob("*.lua"):
        for no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            code = line.split("--", 1)[0]
            for pattern in RISKY:
                if pattern.search(code):
                    issues.append(f"{path.relative_to(ROOT)}:{no}: {line.strip()}")
    return issues


def voice_clip_check():
    src = (ADDON / "Data" / "CastableCC.lua").read_text(encoding="utf-8")
    keys = set(re.findall(r'callout = "(\w+)"', src))
    generic = src.split("ns.GenericCallout", 1)[1].splitlines()[0]
    keys |= set(re.findall(r'= "(\w+)"', generic))
    packs = re.findall(r'\{ Value = "(\w+)"', src.split("ns.VoicePacks", 1)[1])
    missing = []
    for pack in packs:
        for key in sorted(keys):
            for clip in (key, key + "OnYou"):
                if not (ADDON / "Media" / "Voice" / pack / f"{clip}.ogg").is_file():
                    missing.append(f"Voice/{pack}/{clip}.ogg")
    return missing, len(keys), len(packs)


def main():
    failures, total = run_lua_tests()
    missing, nkeys, npacks = voice_clip_check()
    for clip in missing:
        print("MISSING voice clip:", clip)
    print(f"voice clips: {nkeys} callouts x {npacks} packs checked, {len(missing)} missing")
    failures += len(missing)
    issues = static_scan()
    for issue in issues:
        print("SCAN  possible secret truth-test:", issue)
    print(f"\n{total - failures}/{total} tests passed, {len(issues)} scan warnings")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
