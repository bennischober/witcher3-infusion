# Witcher Gear Infusion — known issues and limitations

## Interface

- **The button always says "Infuse".** The game's menu doesn't tell mods which item is
  selected, so the label can't change between "pick target" and "cancel". In step 2 the section
  header says how to cancel: select the target again (or switch tabs).
- **The Infusion tab borrows the Dismantle page's layout**: the pliers icon in the middle
  column, and no item picture or condition bar in the right panel. Item details are in the
  tooltip.
- **The material panel shows at most 5 materials** — the ones you still have to pay. The
  confirmation popup lists everything, including what the sacrifice covers.
- **No projected stat for blunt weapons.** The popup shows the stat after infusion
  ("Armor: 129 -> 164") only where the level step raises the item's main stat; for maces and
  other blunt weapons in the steel sword slot the line is left out.
- **Translations other than English and German are unreviewed.** They follow the game's own
  terms (craftsman ranks, equipment, repair) but no native speaker has checked them, and they
  have not been seen in game — longer texts may not fit their labels. Arabic display is untested.

## Rules

- **Axes count as steel swords** — the game files them in the same category, so they infuse
  with (and as) steel swords.
- **Excluded items**: quest items, Aerondight (it has its own upgrade mechanic) and the
  game's merchant-only leveled stock. They appear greyed out with "Can't be infused safely".
- **Equipped items can't be sacrifices** — unequip first. The target may be equipped.
- **Equal levels can't be infused** — the sacrifice must be strictly higher; an equal-level
  infusion would consume an item for nothing.
- **Only the level transfers.** The sacrifice's bonuses, runes or set effects are never moved
  (an optional bonus-merging module is a possible future extension).

## Prices

- **Fees follow the craftsman's region** (Novigrad about +17 %, Skellige about +8 % over
  Velen), because they're based on his own repair price. On cheap items the difference
  disappears: the game prices repairs in whole crowns per durability point, rounded up, so cheap
  gear costs at least 1 crown per point everywhere.
- **Long New Game+ runs aren't playtested yet.** Fees and materials stay valid at any level
  (tested above the level cap), but whether they feel right after many NG+ cycles is open.

## Compatibility

- **No other mod has been tested alongside this one.** The mod overrides no game script (it
  hooks in via REDkit script annotations), so it doesn't need a script merger and usually
  coexists with other mods.
- **One hard conflict:** the mod replaces the game function `HaxGetPanelStateName` (it lists
  the blacksmith menu's tabs). Another mod replacing the same function causes a "duplicate
  found" compilation error — only one of them can be installed.
- **Mods that change item levels or stats** (scaling mods, damage overhauls) may change how a
  level maps to stats. Infusion verifies the resulting level before charging anything and
  aborts safely — nothing consumed — if it doesn't match.
- **Mods that change the blacksmith menu** (UI overhauls) may hide or break the Infusion tab.
- **No in-game settings menu** — the Remastered settings menu doesn't support it; settings are
  in a script file ([CONFIGURATION.md](CONFIGURATION.md)) and an update resets them.

## Save games

- Removing the mod is safe; infused items keep their levels.
- Nothing else is stored in the save.
