# Witcher Gear Infusion — install guide

Keep the gear you love. Feed it the gear you don't: sacrifice an equipment item at a blacksmith
or armorer to raise another item to its level. The upgraded item keeps its appearance, sockets,
runes, glyphs, enchantment and set bonuses; the sacrifice is consumed, its materials reduce the
cost, and the craftsman charges for the work.

## Requirements

- **The Witcher 3: Wild Hunt — Remastered**, game version **5.01** (tested on Steam).
- Nothing else: no script merger, no other mods. The mod adds only new script files and never
  overrides the game's own scripts.

Texts: all 18 game languages. Only English and German have been reviewed by native speakers so
far — corrections for the other languages are welcome.

## Install

1. Close the game.
2. Extract the archive into your game folder, so that this folder exists:

   ```
   The Witcher 3\mods\modInfusion\content\scripts\...
   ```

   (Steam default: `C:\Program Files (x86)\Steam\steamapps\common\The Witcher 3`. If there is no
   `mods` folder yet, the archive creates it.)
3. Start the game. The first start after installing takes a little longer: the game compiles
   the scripts. If it shows a script compilation error instead, see
   [Troubleshooting](#troubleshooting).

Mod managers that install into `mods\` (e.g. Vortex) work the same way.

## Use

1. Talk to any **blacksmith** (swords) or **armorer** (armor) and open their service menu.
2. Open the **Infusion** tab, right next to *Repair*.
3. **Pick the target** — the item you want to keep. Items this craftsman can't infuse right now
   are greyed out; their tooltip says why (no higher-level item, rank too low, …).
4. **Pick the sacrifice** — a same-type item with a higher level. The panel shows the fee and
   the materials you still need. Select the target again to go back.
5. Press **E** (or the gamepad's accept button) and confirm. The target takes the sacrifice's
   level and is fully repaired; the sacrifice is gone.

Rules in short:

- Same item type only: chest armor ↔ chest armor, boots ↔ boots, steel ↔ steel, silver ↔ silver.
- The sacrifice must have a **higher** level and must not be equipped.
- Blacksmiths infuse swords, armorers infuse armor. Relics need a **master**, Witcher gear a
  **grandmaster** or better.
- The fee depends on the craftsman's rank and region, the size of the jump and the item:
  relics and Witcher gear cost more. Above 2,000 crowns fees rise more slowly.

## Update

1. Delete the old `The Witcher 3\mods\modInfusion` folder.
2. Install the new version as above.

Deleting first makes sure no file from the old version stays behind. If you changed settings
(see [CONFIGURATION.md](CONFIGURATION.md)), note them before deleting — the new version brings
the defaults.

## Uninstall

Delete `The Witcher 3\mods\modInfusion`. This is safe mid-playthrough: infused items keep their
levels (they use the game's own level mechanism), and the mod stores nothing else in your save.

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| No Infusion tab | The folder is in the wrong place. The path must be `mods\modInfusion\content\scripts\…` — not `mods\modInfusion\modInfusion\…` or `mods\content\…`. |
| Script compilation error mentioning `HaxGetPanelStateName` ("duplicate found") | Another mod also replaces this game function (it lists the blacksmith menu's tabs). Only one of the two can be installed. |
| Script compilation error in another mod's file | Usually unrelated to this mod; remove the other mod to check. |
| Infusion tab empty | Nothing in your inventory can be infused at this craftsman (wrong specialization, or no higher-level item of the same type). |
| Texts missing | The `content\strings` folder is missing — reinstall. |

Known limitations: [KNOWN_ISSUES.md](KNOWN_ISSUES.md). Settings: [CONFIGURATION.md](CONFIGURATION.md).
