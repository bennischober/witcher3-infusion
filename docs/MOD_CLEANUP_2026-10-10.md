# Mod cleanup — Remastered 5.00 (2026-10-10)

The game was upgraded in place from Next-Gen 4.04c to **Remastered 5.01** on 2026-10-10
(exe 5.0.0.1048522). This documents the mod-folder cleanup performed the same day.
**A complete backup of the `mods\` folder plus `mods.settings`/`user.settings` was taken first** to
`backups\mods-folder-2026-10-10\` in this repository (excluded from git — proprietary game assets).

## Why the cleanup was needed

Per the official modding summary ("What does the remaster mean for modding?", linked from
Nexus mod 12945) and the community "List of unneeded mods for Remastered" (Nexus mod 12933):

- 5.00 re-encodes all text files from UTF-16 to **UTF-8 with BOM**; old UTF-16 mods stop working.
- The new script compiler reserves **`map` / `set`** as keywords (old mods using those as
  identifiers fail to compile — see `PATCH_NOTES_2026-10-10_scripts.md`).
- Texture/3D-model-only mods are unaffected.
- **FCR3 (Full Combat Rebalance 3) has been bundled with the game since the 4.0 next-gen update**
  (official changelog, curated subset) — a separate FCR3 install is redundant.
- The game now has an in-game mod browser (mod.io Mod Hub); Nexus mods should be
  "Remastered Compatible"-tagged.

## Removed

| Mod | Reason |
| --- | --- |
| `modFCR3_2_Nitpicker` | FCR3 is built into the game since 4.0. Additionally 52 of its 54 scripts were still UTF-16 and its `temp.ws` used the now-reserved `set` identifier (we patched it earlier the same day as an interim fix, before deciding on removal). |
| `modFCR3_3_Padlock` | FCR3 companion (character-screen padlock SWF fix); obsolete with FCR3 built in. |
| `modLevelingGear` | Pre-Remastered leveling mod; keyword-broken (`map` identifier, patched as interim fix). Its mechanic (equipment auto-scaling with player level) is the opposite design of this project's sacrifice-based infusion and would have eroded the sacrifice pool. Source was studied for the discovery report before removal. |
| `mod0000_MergedFiles` | Vortex script-merger output that existed only to merge Leveling Gear + FCR3 scripts. Merges nothing after the removals above. |
| `modMoreMoneyForTraders` | Single UTF-16 script override; would fail to compile on 5.00. Feature (higher trader money) can be re-added later with a Remastered-compatible mod if desired. |
| `modOver9000ngplus` | Data-only NG+ adjustment bundle; unverified on 5.00 and its feature (NG+ cap raise) was not an actively used feature. Removable without loss; re-add a Remastered-tagged alternative later if needed. |

`mods.settings` (Vortex load-order file) contained stale entries for `modHDReworkedProject*`
(texture mods no longer present as folders; HD Reworked is bundled since 4.0) and was reset to an
empty placeholder.

## Kept

| Mod | Reason |
| --- | --- |
| `modHQFacesV3` | Texture/mesh assets only — unaffected by 5.00 per the official guidance. |
| `modRealWeather` | Weather CSV/bundle assets. Two-part install (`mods\modRealWeather` **and** `DLC\RealWeather` — both required, both kept). CSV files did change format-wise in 5.00 (encoding); verify weather in game and remove if it misbehaves. |
| `modInfusion` | This project (deployed copy; scripts re-encoded to UTF-8 with BOM). |

## Post-cleanup state

```
mods\
  modHQFacesV3      (3 files)
  modInfusion       (4 files, UTF-8 BOM scripts)
  modRealWeather    (3 files)
DLC\
  RealWeather       (RealWeather's DLC half — required by the mod)
```

## Rollback

Restore everything with:

```powershell
robocopy "D:\Projects\Privat\Games\witcher3-infusion\backups\mods-folder-2026-10-10\mods" `
         "E:\SteamLibrary\steamapps\common\The Witcher 3\mods" /MIR
# and restore _config\mods.settings / user.settings from the same backup folder if needed
```

## Follow-ups

- In-game verification: launch once, confirm no script errors, check RealWeather behavior.
- Console enablement (`DBGConsoleOn`) still pending for the infusion prototype test.
- If FCR3-in-bundle altered stat/level semantics vs. old vanilla, re-verify the level formulas in
  `docs/TECHNICAL_DISCOVERY.md` §3 against in-game values during M2 testing (the add-until-equal
  transaction design tolerates different per-level stat steps).
