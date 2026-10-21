# The Witcher 3 — Infusion System

Technical Implementation Specification and Development Roadmap

- **Document type:** Mod design and implementation specification
- **Target game:** The Witcher 3: Wild Hunt — Next-Gen edition
- **Primary audience:** OpenAI Codex / coding agent
- **Project status:** Design specification; technical feasibility must be verified before implementation
- **Working title:** Witcher Gear Infusion
- **Core design principle:** Preserve equipment identity while allowing players to sacrifice higher-level equipment, materials, and crowns to upgrade their preferred gear through existing craftsmen.
- **Technical findings:** See `docs/TECHNICAL_DISCOVERY.md` — verified game APIs, required deviations from early examples (craftsman tiers, UI constraints), and the recommended implementation architecture.

## 1. Project Overview

### 1.1 Goal

Develop a gameplay mod for The Witcher 3: Wild Hunt that introduces an item infusion system inspired by Destiny 2.

The system allows the player to sacrifice an equipment item to increase the level of another item. The sacrificed item is permanently consumed, its recoverable crafting materials contribute to the infusion, and the player pays a craftsman's service fee plus any remaining material costs.

The target item retains its identity, appearance, set bonuses, sockets, installed upgrades, and other relevant properties. Its stats must be recalculated appropriately for the new level.

Infusion is performed by existing blacksmiths and armorers, using the game's existing crafting/repair infrastructure wherever technically feasible. No new NPCs, quests, or mandatory dialogue trees should be introduced.

The system is primarily intended to improve equipment progression in New Game+, where players may want to continue using Witcher gear acquired during an earlier playthrough.

### 1.2 Design philosophy

The mod must preserve the value of loot progression.

The player should not be able to upgrade every item for free or automatically. Every infusion should involve meaningful choices:

- Is the sacrifice item worth consuming?
- Should the player infuse now or wait for a higher-level item?
- Does the sacrifice item recover valuable crafting materials?
- Is the desired upgrade worth the labor fee?
- Which craftsman is qualified to perform the infusion?
- Is a more expensive master craftsman worth visiting?
- Should the player spend resources now or save them for crafting?

The goal is not to make Geralt overpowered. It is to make equipment progression more flexible while retaining the game's economic and exploration loops.

### 1.3 Explicit non-goals

The initial release must **not**:

- Automatically scale all equipment to Geralt's level.
- Replace the game's normal loot progression.
- Merge the sacrifice item's armor rating, damage, resistances, or bonuses into the target.
- Introduce a new infusion NPC.
- Require new quests or a new crafting profession.
- Add random infusion failure or a chance to destroy the target.
- Require the player to abandon the existing blacksmith/armorer interface if it can be extended safely.
- Impose a fixed global equipment-level cap solely to restrict New Game+ progression.
- Require a new resource type when existing crafting materials can fulfill the same role.

Automatic scaling may coexist with the mod if another mod provides it, but it is not the defining mechanic of this project.

## 2. Mandatory Technical Discovery Phase

Before implementing gameplay logic, inspect the actual game/modding environment.

Do not assume that an API, function, UI hook, or item property exists simply because it would be convenient.

### 2.1 Establish the target environment

Determine and document:

- The exact game edition and supported patch versions.
- Whether the installation uses the Next-Gen game executable and current REDkit-compatible resources.
- The available scripting environment and supported scripting APIs.
- The installed REDkit version and relevant documentation.
- The available UI modding framework, including the community's fully featured UI-building tools if installed.
- How the project's scripts, resources, configuration, and UI assets are packaged.
- The correct installation directory and expected mod folder structure.
- Any dependencies required by the selected UI framework.
- The game's existing script compilation and conflict-resolution workflow.

If the repository already contains a mod project, inspect it before creating a new structure.

If no project exists, establish a minimal valid mod skeleton using verified examples from the installed toolchain.

### 2.2 Inspect existing equipment-leveling mods

Investigate these projects for technical reference:

- Leveling Gear (Remastered and Next-Gen Edition): <https://www.nexusmods.com/witcher3/mods/13046>
- Gear Level Scaling for Next Gen: <https://www.nexusmods.com/witcher3/mods/7447>
- Balanced Item Level Scaling: <https://www.nexusmods.com/witcher3/mods/7466>

Verify the current pages and their compatibility information before relying on them.

Determine whether their published files, scripts, documentation, or other permitted resources reveal useful techniques for:

- Modifying equipment levels.
- Recalculating equipment stats.
- Preserving sockets, enchantments, durability, and item-specific attributes.
- Interacting with the existing repair interface.
- Charging crowns and crafting materials.
- Accessing the player's inventory.
- Identifying individual inventory item instances.
- Integrating additional actions into existing blacksmith/armorer services.

Do not assume any of these mods provides sacrifice-based infusion. Their role is technical research, not a substitute for implementing the project's distinct gameplay loop.

Respect third-party licenses. Do not copy code or redistribute assets without appropriate permission. Prefer original implementations based on documented APIs and independently verified behavior.

### 2.3 Investigate existing craftsmen

Identify how the game represents:

- Blacksmiths versus armorers.
- Amateur, journeyman, and master craftsmanship (the game's actual tiers are journeyman, master, grand master, and arch master — see §6.2).
- Crafting specializations.
- Existing crafting and repair service interfaces.
- NPC-specific service capabilities.

Verify the exact mechanics in the target game version.

The design must distinguish between a craftsman's general experience tier and their equipment specialization. A master swordsmith should not automatically be treated as a master armorer unless the game's data or an explicitly configured rule supports that conclusion.

Potential reference characters include Hattori and Yoana, but eligibility must be determined by the actual game data, not by assumptions about an NPC's name.

### 2.4 Technical discovery deliverables

Before implementing the complete feature, produce a short technical report containing:

- The verified project structure.
- The verified method for accessing and identifying inventory items.
- The verified method for obtaining and changing item levels.
- The verified method for recalculating item stats.
- The verified method for accessing or extending the repair interface.
- The verified method for charging crowns and consuming materials.
- The verified method for determining craftsman eligibility.
- Known API limitations and mod conflicts.
- A recommended implementation architecture.
- A list of unresolved technical risks.

If a desired operation is not supported directly, document the alternatives and recommend the safest one. Do not silently substitute automatic item scaling for infusion.

## 3. Core Gameplay Rules

### 3.1 The two-item model

An infusion consists of two distinct equipment items.

**Target item**

The item the player wants to keep and upgrade.

Examples:

- Witcher armor.
- Witcher swords.
- Ordinary armor.
- Ordinary swords.

The target item is not consumed.

**Sacrifice item**

The item used to perform the infusion.

The sacrifice item:

- Must satisfy the compatibility rules.
- Must provide a valid level for the requested upgrade.
- Is permanently consumed after a successful transaction.
- Contributes recoverable crafting materials.
- Does not transfer its identity, appearance, bonuses, or other equipment-specific properties to the target.

The sacrifice item's level and recovered materials are its primary contributions.

### 3.2 Level transfer

The default rule is:

> The target's new level equals the sacrifice item's level.

For example:

- Target: Ursine armor, level 40.
- Sacrifice: compatible armor, level 60.
- Result: Ursine armor, level 60.

Do not calculate the new level from Geralt's level.

Do not automatically set the target to the maximum level available in the player's inventory.

Do not permit an infusion that reduces the target's level.

If the sacrifice item is the same level as the target, the default behavior should be to reject the operation because it provides no level progression. This can be a configurable rule if testing identifies a legitimate use case.

If the sacrifice item is below the target's level, reject the operation.

The system must never consume an item for an invalid or zero-benefit infusion.

### 3.3 Compatibility

Initial compatibility rules:

- Armor may be infused using compatible armor.
- Swords may be infused using compatible swords.
- Armor cannot consume a sword as its sacrifice item.
- Swords cannot consume armor as their sacrifice item.

Determine whether the game has additional useful distinctions, such as weapon categories or item classes. Add more specific restrictions only when they have a clear technical or gameplay purpose.

Witcher gear can be infused using compatible equipment of the same broad category. The sacrifice does not need to belong to the same Witcher school.

A future configuration option may permit broader compatibility, but the default should be conservative and predictable.

### 3.4 Full durability restoration

A successful infusion restores the target item to 100% durability.

The sacrifice item does not need to be fully repaired before it can be used, unless testing demonstrates a specific reason to require it.

The target's durability is restored as part of the paid service, not as an additional free action.

The interface must clearly communicate that full durability restoration is included in the infusion.

If the game represents durability through a property that differs from the expected percentage-based model, adapt the implementation to the actual data model.

## 4. Preserve the Target Item's Identity

This is a critical requirement.

Infusion upgrades the target; it does not merge two items.

### 4.1 Properties to preserve

Where supported by the game's item model, preserve:

- The target's underlying item identity and definition.
- Appearance and equipment model.
- Witcher school identity.
- Set bonuses and equipment-specific effects.
- Sockets and installed glyphs, runestones, or other upgrades.
- Enchantments.
- Item-specific abilities or properties.
- Relevant quest or unique-item associations.
- Other attributes that are not explicitly intended to change during infusion.

Do not reconstruct the target as a new generic item merely to assign it a different level if this would lose item-specific properties.

### 4.2 Properties to update

The infusion system should update:

- The target's equipment level.
- Its level-dependent primary stats.
- Its derived stats, where appropriate.
- Its durability, restoring it to full.

The new stats must be calculated from the target's own item definition and the new level.

For example, an Ursine armor piece must remain Ursine armor after infusion. Its armor rating and other level-dependent values should be recalculated for its new level without copying the sacrificed armor's resistances or set bonuses.

### 4.3 Recalculation investigation

Determine how the game generates stats for equipment at a particular level.

Possible approaches include:

- Updating the target's level through a supported API and allowing the game to recalculate its stats.
- Reconstructing a valid item instance using the target's definition and new level, then restoring its individual properties.
- Using a documented or independently verified stat-scaling mechanism from the modding environment.

These are alternatives to investigate, not assumptions about available APIs.

Prefer a method that allows the game to calculate the target's own stats naturally.

Avoid manually applying arbitrary multipliers to the existing stats unless no reliable alternative exists. Repeatedly multiplying current stats can cause cumulative errors and incorrect scaling.

### 4.4 Validation requirements

Test with:

- Ordinary armor.
- Witcher armor.
- Ordinary swords.
- Witcher swords.
- Items with sockets.
- Items with installed upgrades.
- Enchanted equipment.
- Damaged equipment.
- Unique equipment.
- Equipment with special progression mechanics.

Verify that the target survives save/reload with the correct identity, stats, durability, and installed upgrades.

If certain unique items cannot be upgraded safely, exclude them through a clear compatibility rule rather than risking corrupted items.

## 5. Salvage and Material Recovery

The sacrificed item is not merely destroyed. It is dismantled conceptually, and its recoverable materials contribute to the infusion.

This is a central feature of the mod.

### 5.1 Design principles

- The sacrifice item is always consumed after a successful infusion.
- The player receives no separate pile of salvage items in their inventory by default.
- Recoverable materials are applied directly to the infusion recipe.
- The required amount of each material is reduced by the amount recovered from the sacrifice.
- Rarer or more valuable items should generally provide more useful material recovery.
- Material recovery should be based on item properties where possible.
- Materials that cannot be recovered from the sacrifice should not be invented merely to provide a discount.

Direct application avoids unnecessary inventory transfers and reduces the possibility of players interrupting the process between dismantling and upgrading.

### 5.2 Salvage data

Investigate whether the game exposes dismantling recipes or equivalent data for each item.

If reliable dismantling data exists, reuse it where permitted and technically practical.

Otherwise, define a configurable salvage mapping based on item categories and crafting components.

For each sacrifice item, the system should calculate a salvage yield:

```
SalvageYield(sacrificeItem) -> material quantities
```

Example:

- Sacrifice: a rare heavy armor item.
- Salvage yield: leather scraps and metal components.
- Infusion recipe: leather scraps, metal components, and a specialized ingredient.
- The recovered leather and metal are deducted from the required recipe quantities.
- The player only supplies the remaining quantities.

These are conceptual examples; exact material types and yields must be grounded in the game's data.

### 5.3 Rarity and salvage value

Rarity should influence material recovery, but it should not be the only factor.

A higher-tier item may yield more useful or processed components. However, salvage must remain consistent with the actual item being dismantled.

For example, a metal sword should primarily recover materials appropriate to metalworking. Its rarity must not cause it to produce arbitrary quantities of leather.

Use a configurable salvage multiplier or category-specific yield table when the game does not expose reliable dismantling data.

Do not assume every item has an explicit rarity field. Some Witcher equipment, relics, and unique items may need category-based classification.

### 5.4 Material requirements

Each infusion has a material recipe.

The recipe may depend on:

- Target item category.
- Target rarity or equipment tier.
- Target level.
- Level difference.
- Whether the target is Witcher gear.
- Other explicit configuration rules.

The recipe represents the resources needed to perform the work, excluding any materials recovered from the sacrifice.

For each material:

```
AdditionalRequired = max(0, RecipeRequired - SalvagedQuantity)
```

The player's inventory must contain the remaining required quantity.

If salvage provides more of a material than the recipe needs, excess material is discarded by default. It should not be added to the player's inventory unless an optional salvage feature is explicitly implemented.

### 5.5 Avoiding exploits

Ensure that:

- A sacrifice item cannot be used more than once.
- The same item instance cannot simultaneously serve as target and sacrifice.
- A single inventory instance cannot be selected twice through UI duplication.
- Previewing an infusion does not consume materials.
- Canceling an infusion does not consume materials.
- A failed validation does not grant free salvage.
- Material quantities are revalidated immediately before committing the transaction.

The player should never receive salvage materials independently and then also receive their full value as an infusion discount.

## 6. Crowns and Service Fees

Crowns represent the craftsman's labor, expertise, and time.

They are distinct from material costs.

### 6.1 Cost structure

The final cost is:

```
Total Cost = Labor Fee + Remaining Material Requirements
```

The labor fee depends on:

- Craftsman's experience tier.
- Target item's category and tier.
- Level difference between the target and sacrifice.
- Configurable base prices and multipliers.

The material requirements are calculated separately, with salvage applied before the final inventory check.

Do not apply a craftsman's labor multiplier to the material quantities. A master craftsman should charge more for labor, not magically require more metal to produce the same result.

### 6.2 Craftsman fee multipliers

Proposed initial balance values (mapped to the game's verified `ECraftsmanLevel` enum — the game has no "Amateur" tier):

| Craftsman tier | Labor multiplier |
| -------------- | ---------------- |
| Journeyman     | 1.0x             |
| Master         | 1.5x             |
| Grand Master   | 2.0x             |
| Arch Master    | 2.5x             |

These are starting values for testing, not final balance decisions.

The values must be configurable.

If the game exposes an existing crafting or repair pricing model that can be extended safely, investigate it first. Otherwise, implement an independent infusion pricing calculation.

### 6.3 Base labor fee

Use a configurable formula.

A suitable starting model is:

```
LaborFee = BaseFee × CraftsmanMultiplier × TargetTierMultiplier × LevelGapMultiplier
```

Where:

- `BaseFee` is a configurable baseline in crowns.
- `CraftsmanMultiplier` depends on the existing NPC's verified craftsmanship tier.
- `TargetTierMultiplier` represents the complexity of the target equipment.
- `LevelGapMultiplier` increases the fee for larger upgrades.

The exact formula may be refined during testing. Avoid unnecessarily complex formulas that are difficult to understand or balance.

Ensure that the calculation uses appropriate integer rounding and cannot produce negative prices or invalid numeric values.

### 6.4 Pricing goals

- Small upgrades should be affordable enough to encourage occasional use.
- Large upgrades should require more investment.
- Master craftsmen should generally be more expensive than lower-tier craftsmen.
- Salvage should reduce material requirements, not automatically eliminate the labor fee.
- The player should be encouraged to consider when to infuse rather than infusing every item immediately.
- Costs must remain meaningful without becoming prohibitively expensive in extended New Game+ runs.

## 7. Infusion Efficiency

Infusion efficiency represents how much work is required to upgrade the target.

The level difference is the primary balancing variable.

### 7.1 Level-gap calculation

Define:

```
LevelGap = SacrificeLevel - TargetLevel
```

Reject the infusion if `LevelGap <= 0`.

For valid infusions, calculate a configurable multiplier from the level gap.

A small gap should be comparatively efficient. A larger gap should generally increase labor cost.

Do not increase the material requirements twice for the same level gap without a clear balancing reason.

### 7.2 Craftsman efficiency

Craftsman expertise may also influence efficiency.

For example, a master craftsman could have a lower level-gap penalty than a journeyman. This would provide an additional reason to visit a specialist, beyond eligibility alone.

However, craftsman rank already affects labor fees and item eligibility. Avoid stacking so many penalties that master-level services become mandatory for every reasonable upgrade.

Start with one level-gap pricing curve and the craftsman fee multipliers. Add separate efficiency discounts only if playtesting shows that they improve the experience.

### 7.3 No random failure

Infusions should never randomly fail.

Once the player confirms a valid operation and all requirements are met, the operation should either complete successfully or abort safely without consuming resources.

The cost of the sacrifice item and the paid service already creates meaningful opportunity cost.

## 8. Craftsman Eligibility and New Game+ Scaling

The existing craftsmen are the progression gates.

No new NPCs or crafting stations are required.

### 8.1 Existing NPCs only

Integrate the feature into existing blacksmiths and armorers.

Reuse the existing service interface and dialogue flow wherever possible.

Do not add new NPCs, new quests, or new dialogue trees solely to expose the infusion mechanic.

If the existing interface cannot safely support the workflow, document the limitation and propose the smallest possible UI extension that remains attached to the existing service.

### 8.2 Eligibility model

Craftsman eligibility should be determined by:

- Verified craftsmanship tier.
- Equipment specialization.
- Target equipment category.
- Configurable eligibility rules.

Proposed defaults:

- Journeyman craftsmen can infuse basic equipment.
- Masters can handle more advanced equipment.
- Grand masters and arch masters can handle advanced Witcher gear and other high-tier equipment.
- Armorers handle armor.
- Swordsmiths handle swords.

These rules must be validated against the game's actual craftsmanship system. Do not assume that every NPC's profession or tier can be identified using a particular API before verifying it.

Witcher gear should normally require an appropriately qualified master craftsman.

### 8.3 Infinite New Game+ scaling

Do not impose a fixed global maximum infusion level.

A hard-coded level-50 or level-100 restriction is not an appropriate default for a system intended to support extended NG+ progression.

Instead:

- Eligibility depends on the craftsman's capabilities and equipment specialization.
- The sacrifice item's level determines the new target level.
- Cost and efficiency calculations scale with the level difference.
- Material recipes remain valid at higher levels.
- All numeric calculations are checked for overflow and invalid values.

A craftsman may have a configurable eligibility restriction if it serves a clear gameplay purpose, but avoid absolute level caps as the primary progression gate.

If the game itself has technical limitations at extreme levels, document those limits and handle them safely.

## 9. UI and Interaction Design

### 9.1 Preferred interface

Use the existing blacksmith/armorer repair or service interface if it can be extended reliably.

The player should not need to learn a completely new menu system.

The UI should support selecting:

- A target item.
- A compatible sacrifice item.

It must display the resulting level, labor fee, required materials, salvage contributions, and final resource requirements before confirmation.

### 9.2 Required preview

For a selected target and sacrifice, display:

- Target item name and icon.
- Current target level.
- Sacrifice item name and icon.
- Sacrifice level.
- Projected target level.
- Projected primary stats, if reliably calculable.
- Craftsman eligibility.
- Labor fee.
- Required materials.
- Materials recovered from the sacrifice.
- Remaining material requirements.
- Confirmation or rejection reason.

The UI must clearly state that the sacrifice item will be permanently consumed.

The UI must also clearly state that the target will be restored to full durability.

Do not show projected stats as authoritative if the underlying game calculation cannot be reproduced accurately. In that case, display the known level change and explain the limitation.

### 9.3 Validation messages

Provide clear explanations for invalid operations.

Examples:

- "The sacrifice item must be a higher level than the target."
- "This craftsman cannot infuse this equipment."
- "A qualified master armorer is required."
- "The selected items are incompatible."
- "You do not have enough crowns."
- "You are missing required crafting materials."
- "This item cannot be infused safely."
- "The selected sacrifice item is no longer available."

Use the game's established localization and message conventions where practical.

### 9.4 UI framework discovery

Inspect the available UI-building framework before choosing the implementation approach.

Determine whether it supports:

- Reading individual inventory entries.
- Selecting two distinct item instances.
- Displaying item icons and stats.
- Updating a preview when selections change.
- Communicating with the underlying script logic.
- Extending or replacing parts of the repair interface.
- Safe cancellation and confirmation.

Use the existing framework's documented patterns rather than inventing an interaction model unsupported by the environment.

### 9.5 Transaction confirmation

Confirmation should summarize the complete transaction.

For example:

```text
Target: Ursine armor, level 40 → 60.
Sacrifice: compatible armor, level 60.
Labor: 1,200 crowns.
Materials recovered: specified quantities.
Additional materials required: specified quantities.
Durability after infusion: 100%.
Sacrifice item: permanently consumed.
```

These values are illustrative.

The confirmation must use freshly validated inventory and price data, not stale values from a previous preview.

## 10. Configuration

The mod should expose the important balance choices through its supported configuration system.

If a configuration menu is technically practical, provide one. Otherwise, use a documented configuration file with sensible defaults.

Suggested settings:

| Setting                       | Purpose                                                    |
| ----------------------------- | ---------------------------------------------------------- |
| `EnableInfusion`              | Enables or disables the entire feature                     |
| `EnableArmorInfusion`         | Enables armor infusion                                     |
| `EnableSwordInfusion`         | Enables sword infusion                                     |
| `RequireMasterForWitcherGear` | Controls the master-craftsman requirement                  |
| `JourneymanLaborMultiplier`   | Controls journeyman service fees                           |
| `MasterLaborMultiplier`       | Controls master service fees                               |
| `GrandMasterLaborMultiplier`  | Controls grand-master service fees                         |
| `ArchMasterLaborMultiplier`   | Controls arch-master service fees                          |
| `BaseLaborFee`                | Sets the baseline crown cost                               |
| `LevelGapCostMultiplier`      | Controls the effect of the level difference                |
| `TargetTierMultipliers`       | Configures cost by target equipment tier                   |
| `EnableSalvage`               | Enables material recovery from sacrifice items             |
| `SalvageYieldMultiplier`      | Adjusts recovered material quantities                      |
| `RequireCraftingMaterials`    | Enables or disables material requirements                  |
| `RestoreTargetDurability`     | Controls full durability restoration                       |
| `AllowEqualLevelInfusion`     | Normally false                                             |
| `AllowSpecialItems`           | Controls explicitly tested special-item categories         |

Configuration changes must be validated. Invalid values must not cause negative costs, unlimited resource generation, or script errors.

## 11. What Transfers from the Sacrifice

Infusion only transfers progression:

- Sacrifice level determines the target's new level.
- Salvage materials reduce crafting costs.
- The sacrifice item is consumed.
- The target retains its own bonuses and identity.
- The target's stats are recalculated for its new level.

The sacrifice item's bonuses are never transferred. Its socketed runes and glyphs return to the player's inventory, as when dismantling; an enchanted sacrifice loses its enchantment and those upgrades.

## 12. Architecture and Separation of Responsibilities

Use a modular implementation. Exact filenames and APIs should follow the verified project conventions.

Suggested logical components:

### 12.1 Inventory selection

Responsibilities:

- Read the player's inventory.
- Identify distinct item instances.
- Filter compatible targets and sacrifices.
- Prevent the same item from filling both roles.
- Detect items that are no longer available.

### 12.2 Eligibility service

Responsibilities:

- Identify the existing craftsman's tier.
- Determine whether the craftsman handles the target's equipment category.
- Apply configured restrictions.
- Return a clear eligibility result and reason.

### 12.3 Salvage calculator

Responsibilities:

- Determine the sacrifice item's recoverable materials.
- Apply configured yield rules.
- Return a material-quantity breakdown.
- Avoid modifying the inventory during preview.

### 12.4 Cost calculator

Responsibilities:

- Calculate labor fees.
- Apply craftsman and target-tier multipliers.
- Apply level-gap pricing.
- Calculate the remaining material requirements.
- Validate numeric ranges.

### 12.5 Stat-scaling service

Responsibilities:

- Determine the target's new level.
- Recalculate level-dependent target stats.
- Preserve target-specific properties.
- Reject unsupported or unsafe item types.

### 12.6 Transaction manager

Responsibilities:

- Validate the final transaction.
- Verify the target and sacrifice still exist.
- Verify the player's crowns and materials.
- Perform the upgrade.
- Consume the sacrifice.
- Deduct the required resources.
- Restore durability.
- Abort safely on failure.

### 12.7 UI controller

Responsibilities:

- Present the target/sacrifice selection.
- Request previews from the calculation services.
- Display costs and projected results.
- Show eligibility errors.
- Request final confirmation.
- Submit the validated operation.

### 12.8 Configuration service

Responsibilities:

- Load defaults.
- Read user configuration.
- Validate settings.
- Supply balance parameters to other components.

Keep calculation logic independent of UI logic. The same calculation services should be usable in automated tests and alternative interfaces.

## 13. Transaction Safety and Inventory Integrity

This is one of the highest-priority technical requirements.

The infusion transaction must be treated as a single logical operation.

### 13.1 Required preconditions

Immediately before committing:

- Verify that the target item still exists.
- Verify that the sacrifice item still exists.
- Verify that the two items are distinct.
- Verify compatibility.
- Verify the sacrifice level exceeds the target level.
- Verify craftsman eligibility.
- Recalculate salvage and labor costs.
- Verify the player's crowns.
- Verify all remaining materials.
- Verify that the target can be upgraded safely.
- Verify that the resulting level and stats are valid.

The UI preview is not sufficient proof that these conditions remain true.

### 13.2 Commit behavior

Use the safest transaction pattern supported by the game's APIs.

Prefer to validate and prepare all changes before modifying the inventory.

Only consume the sacrifice and charge the player when the target upgrade can be completed.

If the API supports atomic inventory operations or rollback, use them where appropriate.

If a true atomic transaction is unavailable, design a recovery strategy that avoids resource loss or item duplication.

Document the remaining limitations honestly.

### 13.3 Failure handling

If an infusion fails:

- Do not consume the sacrifice item.
- Do not charge the player.
- Do not remove crafting materials.
- Do not leave the target in a partially upgraded state.
- Provide a useful error message.
- Record diagnostic information if appropriate.

Do not report success until the underlying game state confirms the operation.

### 13.4 Save/load integrity

After a successful infusion, verify that:

- The target retains its new level.
- Its recalculated stats remain correct.
- Its durability remains full.
- Its identity and installed upgrades remain intact.
- The sacrifice item remains consumed.
- Crowns and materials remain correctly deducted.

Also test saving and reloading immediately before and after the operation.

## 14. Compatibility and Mod Conflicts

Investigate potential conflicts with:

- Leveling Gear and other equipment-scaling mods.
- Mods that change item levels or stats.
- Mods that modify blacksmith/armorer interfaces.
- Crafting and dismantling overhauls.
- Mods that change item durability.
- Mods that modify Witcher gear.
- Inventory UI modifications.
- Mods that add or change item rarity classifications.

Do not claim universal compatibility without testing.

### 14.1 Scaling-mod conflicts

The infusion mod must not silently depend on automatic scaling to provide its core functionality.

If another mod automatically changes equipment levels, document the interaction.

Determine whether the target's level is recalculated or overwritten by the other mod after infusion.

If the repair interface is already modified by another mod, test whether the infusion interaction can coexist with it.

### 14.2 Unsupported equipment

Maintain an explicit exclusion list or compatibility mechanism for items that cannot be safely upgraded.

Do not make the exclusion list broader than necessary.

Provide a clear explanation when an item is excluded.

## 15. Testing Plan

Testing must cover functionality, balance, and data integrity.

### 15.1 Core functionality tests

- Infuse an ordinary sword using a higher-level sword.
- Infuse ordinary armor using higher-level armor.
- Infuse Witcher armor using compatible higher-level armor.
- Infuse a Witcher sword using a compatible higher-level sword.
- Confirm that the target reaches the sacrifice item's level.
- Confirm that the sacrifice item is consumed exactly once.
- Confirm that the target's durability is restored to full.
- Confirm that the target's appearance and identity remain unchanged.
- Confirm that installed upgrades and enchantments remain intact.
- Confirm that the target's level-dependent stats are recalculated correctly.

### 15.2 Rejection tests

Attempt to:

- Infuse an item using a lower-level sacrifice.
- Infuse an item using an equal-level sacrifice.
- Use armor to infuse a sword.
- Use a sword to infuse armor.
- Select the same item as both target and sacrifice.
- Infuse at an unqualified craftsman.
- Infuse Witcher gear at an ineligible craftsman.
- Infuse without enough crowns.
- Infuse without enough materials.
- Infuse an excluded unique item.

Every rejected transaction must leave the inventory and resources unchanged.

### 15.3 Salvage tests

Verify that:

- Salvage quantities match the configured rules.
- Recovered materials reduce recipe requirements correctly.
- Excess recovered materials do not generate unintended inventory resources.
- The sacrifice item cannot be salvaged twice.
- Rare items provide appropriately higher material value where intended.
- Material recovery remains consistent with item categories.
- Disabling salvage correctly changes the material calculation.

### 15.4 Pricing tests

Verify that:

- Masters charge more labor than journeymen under default settings.
- Journeymen charge more labor than lower-tier craftsmen under default settings.
- Larger level gaps increase labor costs as configured.
- Higher-tier targets have the intended price multipliers.
- Material salvage does not incorrectly reduce the labor fee.
- Costs never become negative.
- Large New Game+ levels do not cause overflow or invalid values.
- Configuration changes produce the expected price changes.

### 15.5 Persistence tests

For each major equipment category:

- Infuse an item.
- Inspect its properties.
- Save the game.
- Reload the save.
- Inspect the item again.
- Confirm the sacrifice item is absent.
- Confirm the resource deductions persist.
- Confirm the target is not duplicated.

### 15.6 Regression tests

Confirm that:

- Ordinary repairs still work.
- Ordinary crafting still works.
- Dismantling still works.
- Existing blacksmith and armorer interactions still work.
- Infusion does not alter unrelated inventory items.
- The feature can be disabled without leaving invalid state.
- Other supported equipment categories remain unaffected.

## 16. Development Milestones

Implement the project in phases. Do not build the complete UI before validating the underlying item operations.

### Milestone 1 — Technical feasibility

Deliverables:

- Valid mod project structure.
- Verified item access and identification.
- Verified method for modifying item levels.
- Verified stat-recalculation method.
- Verified craftsman eligibility approach.
- Verified method for consuming inventory items and charging resources.
- Documented UI integration plan.

Acceptance criterion: A technically credible implementation path exists for the core transaction.

### Milestone 2 — Minimal infusion prototype

Implement one supported equipment category first.

Recommended initial scope: ordinary swords.

The prototype should:

- Select a target sword.
- Select a higher-level sacrifice sword.
- Validate the operation.
- Change the target's level.
- Recalculate its stats.
- Consume the sacrifice.
- Charge a basic crown fee.
- Restore target durability.

The UI may be a temporary debug interface if necessary.

Acceptance criterion: The transaction works reliably and survives save/reload.

### Milestone 3 — Materials and salvage

Add:

- Configurable recipes.
- Salvage yield calculations.
- Material deductions.
- Inventory validation.
- Failure handling.

Acceptance criterion: Material costs and sacrifice consumption are correct, with no duplication or resource-loss bugs.

### Milestone 4 — Craftsman integration

Add:

- Existing NPC identification.
- Craftsman eligibility.
- Equipment specialization rules.
- Tier-based labor multipliers.
- Witcher gear restrictions.

Acceptance criterion: Different existing craftsmen provide the intended services without new NPCs or mandatory new dialogue.

### Milestone 5 — Infusion efficiency and balancing

Add:

- Level-gap pricing.
- Target-tier multipliers.
- Configurable cost curves.
- High-level scaling validation.

Acceptance criterion: Costs remain valid across the tested level range and create meaningful decisions.

### Milestone 6 — Production UI

Implement the final item-selection and confirmation workflow using the verified UI framework.

Acceptance criterion: Players can complete the entire infusion process without debug tools or manual configuration edits.

### Milestone 7 — Compatibility and release preparation

Complete:

- Regression testing.
- Save/load testing.
- Compatibility documentation.
- Configuration documentation.
- Installation instructions.
- Known-issues documentation.
- Release packaging.

Acceptance criterion: The mod can be installed and used without developer tools, with all known limitations documented.

## 17. Definition of Done

The initial release is complete when all of the following are true:

- Infusion works through existing blacksmith/armorer services.
- No new NPCs or mandatory dialogue trees are required.
- Target and sacrifice are distinct inventory items.
- The sacrifice item's level determines the target's new level.
- The sacrifice item is permanently consumed on success.
- Salvaged materials reduce the remaining material cost.
- Crown fees represent labor and depend on craftsman tier.
- Larger level gaps can increase labor costs.
- Craftsman eligibility follows verified craftsmanship and specialization rules.
- Witcher gear can be restricted to appropriately qualified masters.
- The target retains its identity and supported installed upgrades.
- Target stats are recalculated correctly.
- Target durability is restored to full.
- Invalid operations do not consume items or resources.
- Successful operations persist correctly across save/reload.
- Configuration settings work and are documented.
- No fixed global infusion level cap is imposed without a demonstrated technical requirement.
- Existing crafting, repair, and dismantling continue to work.
- Known compatibility limitations are documented.

## 18. Instructions to Codex

Treat this document as the authoritative design specification.

Work incrementally and verify technical assumptions before building on them.

### First actions

- Inspect the available repository and installed modding tools.
- Identify the exact target game and UI environment.
- Research the existing equipment-leveling mods and relevant documentation.
- Produce the technical discovery report.
- Identify the smallest testable infusion transaction.
- Implement the prototype.
- Test it in the actual game before proceeding to the next milestone.

### Implementation rules

- Prefer verified APIs over guessed function names.
- Prefer existing game infrastructure over custom replacements.
- Keep gameplay logic independent of UI logic.
- Keep the code modular and configuration-driven.
- Do not substitute automatic scaling for sacrifice-based infusion.
- Do not silently omit difficult requirements; document blockers and alternatives.
- Do not claim that a feature works until it has been tested.
- Do not make broad compatibility claims without evidence.
- Do not consume resources before a transaction can safely complete.
- Do not overwrite the player's target item with the sacrifice item's identity.
- Do not introduce a fixed level cap merely because ordinary vanilla equipment tends to occupy a lower range.

When a technical decision is necessary, choose the simplest approach that preserves the intended gameplay behavior and item integrity. Document significant deviations from this specification.

### Expected first response from Codex

Before implementing the full mod, Codex should report:

- What it found in the repository and modding environment.
- Which parts of the design are directly supported by verified APIs.
- Which parts require experimentation.
- Any dependencies or conflicts that need attention.
- The recommended minimal prototype.
- The exact next implementation steps.

Once the feasibility report is complete, begin implementing the smallest working infusion transaction rather than attempting the entire system in one step.

## Final Design Summary

The mod extends The Witcher 3's existing equipment and crafting systems with a deliberate sacrifice-based progression mechanic.

The player keeps the item they love, sacrifices another item to determine its new level, recovers useful crafting materials from the sacrifice, pays the existing craftsman's labor fee, and receives a fully repaired, appropriately upgraded piece of equipment.

Craftsman specialization and experience determine who can perform the work. Material recovery, level-gap efficiency, and service prices create meaningful decisions about when and where to infuse.

The target item remains itself.

The central gameplay rule is simple: sacrifice loot to preserve and improve your chosen gear, but make every infusion a deliberate investment.
