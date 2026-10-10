# modInfusion — release mod

This folder is the **release content**: exactly these files ship to players.

- `content/scripts/game/infusion/InfusionTypes.ws` — error codes, preview data, category table
- `content/scripts/game/infusion/InfusionService.ws` — level computation, validation, transaction

Debug/test tooling lives in `tests/modInfusion/` and is deployed on top of this folder by
`tools/deploy-mod.ps1 -Dev` during development — never in a release.

Project overview, development workflow, and compatibility notes: see the repository
[README](../../README.md). Design specification: [INFUSION_SPEC](../../INFUSION_SPEC.md).
Verified game internals: [docs/TECHNICAL_DISCOVERY.md](../../docs/TECHNICAL_DISCOVERY.md).
