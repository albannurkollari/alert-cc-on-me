# Voice pack template for Alert CC On Me

Alert CC On Me ships three voice packs (David, Zira, Mark). A voice pack add-on adds
another one to the **Voice** dropdown in Settings > Alert CC On Me > Sound.

## Make a pack

1. Copy this folder and rename it, e.g. `AlertCCOnMe_Voice_Grampa`. Rename the `.toc`
   to match the folder name.
2. In `Register.lua`, change `"Example"` to the name shown in the dropdown.
3. Put 34 `.ogg` clips in a `Voice` folder inside it, two per callout:

   | Callout | Spells | Files |
   |---|---|---|
   | Sheep | Polymorph, Mass Polymorph | `SheepOnYou.ogg`, `Sheep.ogg` |
   | Cyclone | Cyclone | `CycloneOnYou.ogg`, `Cyclone.ogg` |
   | Hibernate | Hibernate | `HibernateOnYou.ogg`, `Hibernate.ogg` |
   | Roots | Entangling Roots | `RootsOnYou.ogg`, `Roots.ogg` |
   | Sleep | Sleep Walk | `SleepOnYou.ogg`, `Sleep.ogg` |
   | Fear | Fear | `FearOnYou.ogg`, `Fear.ogg` |
   | Seduction | Seduction | `SeductionOnYou.ogg`, `Seduction.ogg` |
   | Banish | Banish | `BanishOnYou.ogg`, `Banish.ogg` |
   | MindControl | Mind Control, Dominate Mind | `MindControlOnYou.ogg`, `MindControl.ogg` |
   | Shackle | Shackle Horror | `ShackleOnYou.ogg`, `Shackle.ogg` |
   | Hex | Hex | `HexOnYou.ogg`, `Hex.ogg` |
   | Lasso | Lightning Lasso | `LassoOnYou.ogg`, `Lasso.ogg` |
   | TurnEvil | Turn Evil | `TurnEvilOnYou.ogg`, `TurnEvil.ogg` |
   | ScareBeast | Scare Beast | `ScareBeastOnYou.ogg`, `ScareBeast.ogg` |
   | SongOfChiJi | Song of Chi-Ji | `SongOfChiJiOnYou.ogg`, `SongOfChiJi.ogg` |
   | CC | any other crowd control | `CCOnYou.ogg`, `CC.ogg` |
   | Cast | non-CC cast (when "Only crowd-control spells" is off) | `CastOnYou.ogg`, `Cast.ogg` |

   `...OnYou` plays when the cast is confirmed to target you ("Sheep on you!"). The
   short one plays when the target is unknown ("Sheep!"). Keep clips short; under a
   second works best.

   To render them with a Windows voice installed on your PC:

   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/generate_voices.ps1 `
     -Name Grampa -Voice "Microsoft David Desktop" -OutDir "<your add-on>\Voice"
   ```

   Or record your own and save them as `.ogg` with the names above.
4. Copy the folder into `World of Warcraft\_retail_\Interface\AddOns\` and restart the
   game. WoW only sees new sound files after a full restart, not after `/reload`.
5. Pick the pack under Settings > Alert CC On Me > Sound > Voice, then `/accm test`.

If the pack's add-on is disabled later, Alert CC On Me falls back to David.
