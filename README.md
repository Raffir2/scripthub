# Raffir Scripts

One loadstring for every game:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Raffir2/scripthub/main/loader.lua"))()
```

- **Known game** → its script loads right away, no menu. `RightControl` opens the menu to pick another script for that game; that choice is remembered for next time.
- **Unknown game** → the menu opens with every game and script.
- Detection uses `game.GameId` (works for all sub-places, like AOT:R missions), then `game.PlaceId`.
- Each downloaded file is cached in `RaffirScripts/cache/`, so it still loads when GitHub can't be reached.
- "Re-run after teleport" (menu footer) queues the launcher again on teleport, if the executor's `queue_on_teleport` works.

## Games

| Game | Scripts | Source |
|---|---|---|
| Spellbound | Spellbound GUI · Book Farm | Raffir2/spellbound · mirror |
| Wizard West | Wizard West | Raffir2/wizard-west |
| Thunder Scientific Corporation | TSC Menu · Auto Vent (standalone) | filipmijo2/tsc-hub · mirror |
| Untitled Tag Game | Tag Assist · Autopilot · Infinite Slide | filipmijo2/utg-tag-assist · mirror · mirror |
| Attack on Titan Revolution | AOT:R Menu | filipmijo2/aot-hub |
| Elemental Magic Arena | EMA Helper | mirror |
| QUANTIFY | Shape Tool · Autoplay · Auto Craft & Sell | mirror |
| Anime Expeditions | Auto Fishing | mirror |
| Drain the Lake | DTL Auto Farm | mirror |
| Mine a Mountain | Crystal Farm | mirror |
| Clean all the Leaves | Leaf Farm | mirror |
| Vesteria | Vesteria Hub | mirror |
| Absolvement | Absolvement | gist |

Scripts with their own repo are loaded from that repo's raw URL, so they are always the newest version. "Mirror" files live in `games/` here.

## Maintaining

- Add a game or script: add an entry to `registry.lua`. The loader itself does not change.
- Refresh mirrored files from the local dev copies: `bash tools/sync.sh`, then commit.
- Local test without pushing: copy the repo into the executor workspace folder `raffir_dev/` and run
  `getgenv().RAFFIR_DEV = "raffir_dev"; loadstring(readfile("raffir_dev/loader.lua"))()`.
- Scripted control: `getgenv().__RAFFIR_LAUNCHER` has `show`, `hide`, `kill`, `select(gameId)`, `load(gameId, scriptId)`.

Rules the loader keeps: no instance name contains "hub" (Elemental Magic Arena kicks on that), and in games flagged `quiet` (TSC, Adonis log scanner) it writes nothing to the console.
