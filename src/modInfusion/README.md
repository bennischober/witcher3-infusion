# modInfusion — release mod

This folder is the **release content**: exactly these files ship to players.

| File (`content/`) | Contents |
| --- | --- |
| `scripts/game/infusion/InfusionTypes.ws` | Error codes, preview data, category data, error messages |
| `scripts/game/infusion/InfusionConfig.ws` | Balance knobs and feature switches (script constants) |
| `scripts/game/infusion/InfusionService.ws` | Levels, salvage and recipe, fee, eligibility, validation, transaction |
| `scripts/game/infusion/InfusionMenuTab.ws` | Annotations: registers the Infusion tab in the common menu |
| `scripts/game/infusion/InfusionBlacksmithMenu.ws` | Annotations: the Infusion tab's behavior in the blacksmith menu |
| `scripts/game/infusion/InfusionConfirmationPopup.ws` | Confirmation popup |
| `scripts/game/gui/_old/components/guiInfusionInventoryComponent.ws` | Item grid of the Infusion tab |
| `strings/{en,de}.w3strings` | UI strings (built from `tools/strings-sources/`) |

No vanilla script is overridden. Debug/test tooling lives in `tests/modInfusion/` and is
deployed on top of this folder by `tools/deploy-mod.ps1 -Dev` — never in a release.

Project overview: [README](../../README.md). Design: [INFUSION_SPEC](../../INFUSION_SPEC.md).
UI: [docs/UI.md](../../docs/UI.md). Engine facts: [docs/TECHNICAL_DISCOVERY.md](../../docs/TECHNICAL_DISCOVERY.md).
