# Alert CC On Me

A World of Warcraft Retail addon (Midnight, 12.1) that warns you **while** an enemy is casting crowd control at you (Polymorph, Cyclone, Fear, Hex, Mind Control, Sleep Walk and more), so you still have time to interrupt, stun, or break line of sight before it lands.

## Features

- **On-screen alert:** "Polymorph on YOU!" appears only when the cast is crowd control *and* aimed at you, in arena too.
- **Voice callouts:** "Sheep on you!", "Cyclone on you!" in three built-in voices. Other add-ons can register more voice packs.
- **Spell list by class:** each CC spell sits under its caster's class with the class icon and color. Turn spells on or off, remove them, or add your own (`/accm add 12345 monk`).
- **Movable and scalable:** `/accm move`, then Shift+drag to move, Shift+mouse wheel to scale, right-click to lock.
- **Lightweight:** it only reacts to enemy cast events, runs no per-frame handlers, and never touches the network.

## How it works

Since Midnight, the game hands addons enemy cast data as *secret values*. An addon may pass them to some UI functions but cannot read or compare them. The alert is built from nested frames whose transparency comes straight from two secret answers ("is it crowd control?" and "is it aimed at me?"), so it shows only when both are true. The addon itself never learns either answer.

Sound can't be decided from a secret value, so the voice callout plays only when the game leaves the spell readable:

| | Open world | Arena / restricted content |
|---|---|---|
| On-screen alert | yes | yes |
| Voice callout naming the spell | yes | only for spells the game keeps readable |
| Alarm on any enemy cast (opt-in sound mode) | yes | yes |

`/accm probe` (run it in a Skirmish) lists which CC spells stay readable in arena.

## Install

Copy the `AlertCCOnMe` folder into `World of Warcraft\_retail_\Interface\AddOns\`, then `/reload`. Keep enemy nameplates turned on: they're how the addon sees nearby enemies.

## Commands

| Command | Action |
|---|---|
| `/accm` | Open settings |
| `/accm test` | Preview the alert and voice |
| `/accm move` / `lock` | Move and scale the alert / lock it |
| `/accm spells` | Open the spell list |
| `/accm add <id> [class]` / `remove <id>` | Add (e.g. `add 198898 monk`) or remove a spell |
| `/accm list` | Print the spell list, flagging IDs whose game name doesn't match |
| `/accm probe [id]` | Show what the game lets the addon read |
| `/accm debug` | Print one line per enemy cast |
| `/accm perf` | CPU (client profiler), memory, active alert frames |
| `/accm on` / `off` / `status` | Enable, disable, show state |

## Voice packs

David, Zira and Mark ship with the addon. A voice pack is a small add-on that calls
`AlertCCOnMe_RegisterVoicePack(name, path)` and holds one `.ogg` per callout. See [`templates/AlertCCOnMe_Voice_Example`](templates/AlertCCOnMe_Voice_Example).

## Development

| Path | Purpose |
|---|---|
| `tests/run_tests.py` | Offline test suite: loads the addon under LuaJIT with a WoW API mock that raises on any misuse of secret values (Python 3.14 + `pip install lupa`) |
| `tests/bench.py` | Micro-benchmark under Lua 5.1 |
| `tools/generate_voices.ps1` | Renders voice clips with Windows speech voices and ffmpeg |
| `install.sh` | Runs the tests, then copies the addon into your AddOns folder (`WOW_ADDONS` overrides the path) |

## License

[Apache-2.0](LICENSE). See [`AlertCCOnMe/NOTICE`](AlertCCOnMe/NOTICE) for attributions.

---

*Disclaimer: this addon was developed with the aid of agentic coding.*
