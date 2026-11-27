# Screenshots

Images for the project pages on CurseForge, Wago and WoWInterface, and for the README. They live in the repo only: `.pkgmeta` keeps `docs/` out of the addon zip.

## Shots to capture

| File | Shows | How | Taken |
|---|---|---|---|
| `alert.png` | The alert firing: "Polymorph on YOU!" over the game world | `/accm test` in a busy spot, or a real cast in a Skirmish | ✅ |
| `edit-mode.png` | The edit box being moved and scaled | `/accm move`, then Shift + drag mid-move | — |
| `settings.png` | The options page, including "Where to alert" | `/accm` | ✅ |
| `spell-list.png` | The spell list grouped by class, with on/off and X | `/accm spells` | ✅ |
| `sound.png` | The pre-cast sound dropdown open | `/accm`, Sound section | — |

## Guidelines

- **PNG, cropped to what the shot shows.** A crop reads better in galleries than a full 1920×1080 frame. Convert WoW's JPGs with `ffmpeg -i shot.jpg -map_metadata -1 shot.png`, which also drops the metadata.
- **Default UI with no other addons visible,** so the alert is the focus.
- **No personal details.** Hide or crop character names, guild names, chat and the realm.
- **Take them in game.** Use your Print Screen key (WoW saves to `_retail_/Screenshots`), then convert from JPG to PNG if needed.
- **Upload by hand, once per site.** No site offers an API for images: use CurseForge's **Images** tab, the Wago developer dashboard, or WoWInterface's upload form, which needs one screenshot.
