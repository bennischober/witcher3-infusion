# Craftsman map — verified game data (extracted from REDkit entity templates, 2026-10-11)

Source: `W3CraftsmanComponent.craftsmanData` in the uncooked `.w2ent` templates
(REDkit `r4data`). This is the game's own data — identical to what the live
`infuseCraftsmanReport` queries at runtime. Extracted offline for balance planning (M5).

Tier enum: `ECL_Journeyman < ECL_Master < ECL_Grand_Master < ECL_Arch_Master`
(the game has no "Amateur" tier).

## Velen / No Man's Land (early game area)

| NPC / location | Specialization | Tier |
| --- | --- | --- |
| Crow's Perch smith ("Verden Smith") | Smith | Journeyman |
| Midcotts smith | Smith | Journeyman |
| Rudnik smith | Smith | Journeyman |
| Bald Mountain crafter | Smith | Journeyman |
| Baron's Keep armorer | Armorer | Journeyman |
| Mouth armorer | Armorer | Journeyman |

*Fergus Graem (Armorer, Master) and Joana (Armorer, Grandmaster) at Crow's Perch are
quest-phased (sq108) — they exist as separate quest templates, not community merchants.
Live-report verified: `Fergus Graem smith=none armorer=master`, `Joana smith=none armorer=grandmaster`.*

## Novigrad & Oxenfurt

| NPC / location | Specialization | Tier |
| --- | --- | --- |
| Novigrad market smith | Smith | Master |
| Novigrad citizen district regular smith | Smith | Journeyman |
| Novigrad rich district armorer | Armorer | Master |
| White Bridge redanian blacksmith | Smith | Master |
| White Bridge redanian armorer | Armorer | Master |
| Roche's camp quartermaster | Armorer | Journeyman |
| **Hattori** (Novigrad, sq304) | **Smith** | **Grandmaster** |

## Skellige

| NPC / location | Specialization | Tier |
| --- | --- | --- |
| Kaer Trolde castle smith | Smith | Master |
| Kaer Trolde castle armorer | Armorer | Master |
| Lugos Keep smith | Smith | Master |
| Lugos Keep armorer | Armorer | Master |
| All village smiths (Arinbjorn, Brokvar, Dimun, Ferylund, Fyresdal, Larvik, Tuiseach) | Smith | Journeyman |
| Larvik / Tuiseach armorers | Armorer | Journeyman |

## Toussaint (Blood & Wine)

| NPC / location | Specialization | Tier |
| --- | --- | --- |
| Belgard wine blacksmith | Smith | Grandmaster |
| City West blacksmith | Smith | Grandmaster |
| City West armorer | Armorer | Grandmaster |
| **Slavko Atimstein** (quest NPC) | — | **Archmaster** |

## Prologue / Others

| NPC / location | Specialization | Tier |
| --- | --- | --- |
| Nilfgaardian camp quartermaster (prologue) | Smith | Journeyman |
| q505 Redanian blacksmith | Smith | Master |
| q501 Nilfgaard quartermaster (Undvik) | Smith | Master |
| Enchanter (ep1) | Enchanter | Grandmaster |

## Design implications for the infusion mod

1. **Early-game availability (Velen):** only Journeyman smiths and armorers. Ordinary gear
   infusions work; **relic and Witcher gear cannot be infused in early Velen** — by design
   (spec §8.2). This creates a natural progression: players unlock better infusion services
   by reaching Novigrad/Skellige.
2. **Master smiths** (Novigrad market, White Bridge, Kaer Trolde, Lugos) handle relic gear.
3. **Witcher gear** (quality 5) requires Grandmaster: Hattori (swords), Yoana/"master
   blacksmith" (armor), Toussaint craftsmen. Our default threshold
   (`CRAFTSMAN_LEVEL_REQUIRED_FOR_WITCHER_GEAR = ECL_Grand_Master`) matches exactly one
   smith per region for swords — rare and meaningful, as intended.
4. **No Arch-Master smiths** in the base game (the one Archmaster is a Toussaint quest NPC
   without smith/armorer specialization). The Arch-Master tier is effectively reserved —
   our fee table should still include it, but availability is zero in vanilla. Relevant for
   M5 fee balance: the Arch-Master multiplier (2.5x) never actually applies unless another
   mod adds such NPCs.
5. **Verification path:** the live report (`infuseCraftsmanReport`) at Crow's Perch matches
   this offline extraction (Fergus/Joana quest-phased, Verden Smith = Journeyman Smith).
