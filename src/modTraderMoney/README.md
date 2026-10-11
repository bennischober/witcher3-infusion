# modTraderMoney — trader money refill (restored mod)

Restores the user's preferred "More Money for Traders" behavior. The original mod
(Nexus, single script) sets every merchant's purse to 5,000 crowns when their shop
opens — one line of behavior inside a full vanilla `inventoryMenu.ws` override.

## Why it lives as a separate mini-mod

- Keeps the infusion mod's override surface minimal (infusion touches
  `commonMenu.ws` + `blacksmithMenu.ws`; this touches `inventoryMenu.ws`).
- The original file was UTF-16 LE BOM (pre-5.01); this copy is converted to
  **UTF-8 BOM** so it compiles on the Remastered.

## Compatibility

- Overrides vanilla `game/gui/menus/inventoryMenu.ws` — conflicts only with
  other mods overriding the same file (none currently installed).
- Vanilla refill mechanic note: merchants also regenerate money daily; this mod
  guarantees 5,000 on every shop open.
