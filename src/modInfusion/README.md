# Witcher Gear Infusion — mod sources

Source of truth for the mod. The game's `mods\` folder receives **copies only**
(via `tools\deploy-mod.ps1`) — never edit deployed files directly.

## Layout

```
src/modInfusion/
  content/
    scripts/
      game/
        infusion/
          InfusionTypes.ws     - enums, structs, error strings
          InfusionService.ws   - level computation, validation, transaction
          InfusionDebug.ws     - debug console commands (M2 prototype)
```

## Compatibility rules (binding, see docs/TECHNICAL_DISCOVERY.md §2)

- **No overrides of base game script files.** Only new files in new folders.
  In particular, never override `gameParams.ws`, `inventoryComponent.ws`, or
  `playerWitcher.ws` — those are owned by the user's script-merged mods, and
  overriding them would force script-merging on every user of this mod.
- All game APIs are called through existing public entry points
  (`thePlayer`, `theGame`, inventory component methods).

## Milestone 2 scope (current)

- Steel swords only (`IFE_DisabledCategory` gates the rest).
- Debug-console-driven: `infuseStats`, `infusePreview`, `infuseRun`, `infuseSelfTest`.
- Flat debug labor fee (service constant), durability restoration included.
- Salvage/materials and craftsman eligibility are Milestones 3–4 (not implemented).

## Testing checklist (in game, console enabled)

1. `infuseSelfTest` — runs rejection checks (same instance, equal level, equipped
   sacrifice, category mismatch) then one real infusion; log channel `Infusion`.
2. Verify in inventory: sacrifice consumed, target level raised, durability 100%.
3. Save, reload, `infuseStats` — level must persist (crafted abilities are
   instance data, same persistence mechanism as vanilla NG+ item leveling).
4. `infuseRun` with no valid pair must change nothing.
