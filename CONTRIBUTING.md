# Contributing

Thanks for helping out! Bug reports, spell-list corrections, voice packs and code are all welcome. By taking part you agree to the [Code of Conduct](CODE_OF_CONDUCT.md), which also lists what Blizzard allows in an add-on. Please read that section before you open a PR.

## Prerequisites

- [Git](https://git-scm.com/) and a Bash shell (on Windows, the Git Bash that comes with Git)
- World of Warcraft Retail, to try changes in game
- **Either** [Docker](https://www.docker.com/products/docker-desktop/) **or** Lua 5.1 with [LuaRocks](https://luarocks.org/), to run the tests. Docker needs no other setup. For a native setup, run `luarocks --lua-version=5.1 install busted` and `luarocks --lua-version=5.1 install luacheck`

## Get the code

Fork the repository on GitHub, then clone your fork and branch off `beta`, which is the default branch that every PR targets:

```sh
git clone https://github.com/<you>/alert-cc-on-me.git
cd alert-cc-on-me
git switch beta
git switch -c fix/short-description
```

## Run it in game

`install.sh` runs the tests, then copies `AlertCCOnMe/` into your AddOns folder. Point `WOW_ADDONS` at your own install:

```sh
WOW_ADDONS="/c/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns" ./install.sh
```

In game, type `/reload`, then:

| Command | Use |
|---|---|
| `/accm test` | Preview the alert and voice |
| `/accm debug` | Print one line per enemy cast, showing which values the game kept secret |
| `/accm probe [spellID]` | Show what the game lets the addon read where you are now |
| `/accm perf` | CPU, memory and active alert frames |

For a quicker loop, link the folder instead of copying it, then `/reload` after each change. On Windows: `mklink /J "<AddOns>\AlertCCOnMe" "<repo>\AlertCCOnMe"`.

## Run the tests

```sh
tests/run.sh                 # luacheck, then every busted test
tests/run.sh --filter zone   # only tests whose name matches
tests/run.sh bench           # micro-benchmark
```

The script uses `busted` and `luacheck` if they're on your PATH, and otherwise builds and runs the Lua 5.1 container in `tests/Dockerfile` (start Docker first). CI runs the same container on every PR.

The tests load the addon in `.toc` order against `tests/wow_mock.lua`. In that mock, secret values raise an error the moment addon code compares them, truth-tests them, or does arithmetic on them, just like the live client. A new behaviour test goes in `tests/test_addon.lua`:

```lua
T["what the player should see"] = function()
	boot()
	-- set up M.units / M.instanceType, fire events with M.fireUnit, then assert
end
```

## Guidelines

- **Never branch on a secret.** Hand secrets straight to widget APIs that accept them, such as `SetAlphaFromBoolean` or `SetFormattedText`. A static scan in the test suite flags the common mistakes.
- **Keep it light.** The addon only reacts to events and has no per-frame (OnUpdate) handlers. `tests/run.sh bench` shows the cost of a change.
- **Spells:** a new CC spell goes in `AlertCCOnMe/Data/CastableCC.lua` under its class, with a `callout`. Each callout needs `<Key>.ogg` and `<Key>OnYou.ogg` in every built-in voice pack. `tools/generate_voices.ps1` renders them on Windows, and the tests fail if one is missing.
- **Text** goes in `AlertCCOnMe/locales/enUS.lua`, never inline.
- **Commits** follow [Conventional Commits](https://www.conventionalcommits.org/), for example `feat(spells): add Sleep Walk` or `fix(display): keep position after reload`.

## Pull requests

1. Open the PR against `beta`.
2. Make sure `tests/run.sh` passes. CI must be green before a merge: commit format, luacheck, busted and a package build.
3. Describe what changed and how you checked it in game, if you could. Each CI run attaches the packaged addon (`AlertCCOnMe-<version>.zip`, kept 14 days) to the run's summary page, so you can unzip it into `Interface/AddOns/` and try it.

Every merged change to the addon ships as an alpha build for testers on CurseForge and Wago. Merged changes also collect in an automatic `beta` → `main` promotion PR. When the maintainer merges it, your commit types decide the stable version (`feat` → minor, `fix` → patch), so pick them carefully; `docs`, `chore` and `test` alone publish nothing (see the README).
