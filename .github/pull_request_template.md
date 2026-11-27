## Summary

<!--
One bullet per change: a bold sentence naming the change, then one or two lines on why
it matters or what it affects. Link the issue it solves, e.g. "Closes #123".

- **Adds a toggle for raids.** Raid encounters cast CC at players too, so the alert
  could help there; it stays off by default.
-->

-

## Testing

- [ ] `tests/run.sh` passes (luacheck + busted)
- [ ] New or changed behaviour has a test in `tests/test_addon.lua`
- [ ] Tried in game: <!-- where: open world / arena / battleground / dungeon -->

## Checklist

- [ ] Commit subjects follow [Conventional Commits](https://www.conventionalcommits.org/); they decide the next stable version
- [ ] No branching on, comparing or doing arithmetic on secret values
- [ ] User-facing text is in `AlertCCOnMe/locales/enUS.lua`
- [ ] Fits the [Code of Conduct](../blob/beta/CODE_OF_CONDUCT.md), including Blizzard's add-on rules
