Alert CC On Me warns you **while** an enemy is casting crowd control at you (Polymorph, Cyclone, Fear, Hex, Mind Control, Sleep Walk and more), so you still have time to interrupt, stun or break line of sight before it lands.

## Features

- **On-screen alert:** "Polymorph on YOU!" appears only when the cast is crowd control *and* aimed at you, in arena too.
- **Alert sound:** pick one of the game's own sounds (raid warning, boss whisper, ready check, alarm clock...). The addon ships no audio, so it stays tiny.
- **Spell list by class:** each crowd-control spell sits under its caster's class. Turn spells on or off, remove them, or add your own (`/accm add 12345 monk`).
- **Choose where it runs:** open world, arena, battleground and dungeon each have their own on/off setting.
- **Movable and scalable:** `/accm move`, then Shift+drag to move, Shift+mouse wheel to scale, right-click to lock.
- **Lightweight:** it only reacts to enemy cast events, runs no per-frame handlers, and never touches the network.

## How it works

Since Midnight, the game hands addons enemy cast data as secret values that an addon can pass to the UI but cannot read. The alert is drawn straight from the game's own answers to "is it crowd control?" and "is it aimed at me?", so it shows only when both are true. The sound needs a readable spell, so in arena and other restricted content it plays only for spells the game keeps readable, unless you pick the any-cast sound mode; the on-screen alert works everywhere.

Keep enemy nameplates turned on: they're how the addon sees nearby enemies.

## Commands

- `/accm`: open the settings
- `/accm test`: preview the alert and sound
- `/accm move` / `/accm lock`: move and scale the alert / lock it
- `/accm spells`: open the spell list
- `/accm on` / `/accm off` / `/accm status`: enable, disable, show state

## Feedback and source

Report bugs and request features on [GitHub Issues](https://github.com/albannurkollari/alert-cc-on-me/issues). The source code is on [GitHub](https://github.com/albannurkollari/alert-cc-on-me) under the MIT license.
