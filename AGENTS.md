# Project Instructions for Codex

## Project

Witcher 3 Infusion — a sacrifice-based equipment progression mod for The Witcher 3: Wild Hunt Next-Gen.

Game and Redkit paths:

- "E:\SteamLibrary\steamapps\common\The Witcher 3"
- "E:\SteamLibrary\steamapps\common\The Witcher 3 REDkit"

## Before coding

- Read INFUSION_SPEC.md before implementing features.
- Inspect the existing project and installed development tools.
- Verify APIs, file formats, and UI capabilities against actual documentation or working examples.
- Document technical findings in docs/TECHNICAL_DISCOVERY.md.
- Do not invent game APIs or assume that a feature is supported without verification.

## Design requirements

- Infusion uses a target item and a distinct sacrifice item.
- The sacrifice item's level determines the target's new level.
- The sacrifice item is consumed on successful infusion.
- Recoverable materials reduce the required crafting materials.
- Crowns represent the craftsman's labor.
- Existing blacksmiths and armorers provide the service.
- Craftsman eligibility depends on verified experience tier and specialization.
- Successful infusion restores the target's durability.
- Preserve the target's identity, bonuses, sockets, and installed upgrades wherever supported.
- Do not transfer the sacrifice item's bonuses in the core implementation.
- Do not replace infusion with automatic equipment scaling.
- Do not introduce new NPCs or mandatory dialogue trees.

## Development approach

- Work incrementally according to the milestones in INFUSION_SPEC.md.
- Build the smallest testable prototype first.
- Keep UI, transaction, salvage, pricing, eligibility, and stat-scaling logic modular.
- Validate transactions before consuming items or resources.
- Document unresolved technical limitations.
- Test persistence and save/reload behavior wherever possible.
- Do not claim successful in-game testing unless it was actually performed.

## Optional extensions

Bonus merging must remain separate from the core infusion mechanic. It may be developed as an optional module or independently distributed mod, but it must not be required for the base system.

## Git practices

- Make small, focused commits.
- Do not commit proprietary game assets or unauthorized third-party mod files.
- Keep documentation updated when implementation decisions change.
- Do not overwrite unrelated user changes.
- Use the `git-commit-message-rules` to properly format/create a commit message.
