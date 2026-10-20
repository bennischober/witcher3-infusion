#!/usr/bin/env python3
"""Offline infusion cost calculator (no game launch needed).

Reads the item definitions shipped with REDkit (uncooked XML under
r4data) and applies the same balancing formulas as the mod
(src/modInfusion/.../InfusionService.ws + InfusionConfig.ws):

  recipe    = target's recycling_parts (crafting/alchemy ingredients only) x gapFactor (ceil, >= 1 each)
  gapFactor = min(gap / LEVELS_PER_FULL_SET, MAX_SETS)
  covered   = min(sacrifice salvage, recipe) per recipe material
  remaining = recipe - covered
  raw       = max(targetValue, sacrificeValue) x FEE_FRACTION x gapFactor x craftsman x tier
  fee       = max(MIN_FEE, round(raw if raw <= FEE_SOFT_CAP else sqrt(raw x FEE_SOFT_CAP)))

The mod anchors the fee to the craftsman's full-repair price of the target
or the sacrifice, whichever is higher, instead
(GetItemPriceRepair per point x max durability: regional, whole crowns per
point rounded up). In Velen that is about targetValue x 0.25, which this
tool uses; Novigrad is ~17 % and Skellige ~8 % higher, and cheap items pay
vanilla's rounding (1 crown per point minimum).

KEEP THE CONSTANTS BELOW IN SYNC WITH InfusionConfig.ws.

Recipes are exact (game data). The fee needs the in-game values
(GetItemPriceModified is native and scales with level/NG+): pass them with
--value and --sacrifice-value (the crown values in the item tooltips).
Without them the base prices from the XML are used - a rough lower bound,
labelled as such.

Examples:
  python tools/infusion-cost-table.py --target "Bear Armor 4" --sacrifice "Light armor 06" --gap 9 --craftsman grandmaster
  python tools/infusion-cost-table.py --target "Light armor 01" --sacrifice "Light armor 06" --gap 9 --value 288 --have "Thread=112,Leather squares=5"
  python tools/infusion-cost-table.py --table armor --gap 10
  python tools/infusion-cost-table.py --find "Bear Armor"
"""

import argparse
import glob
import math
import os
import re
import sys

# ---- balancing constants (mirror InfusionConfig.ws) ----------------------
FEE_FRACTION = 0.25
MIN_FEE = 10
FEE_SOFT_CAP = 2000  # 0 = off
LEVELS_PER_FULL_SET = 10.0
MAX_SETS = 3.0
SALVAGE_YIELD_MULT = 1.0
CRAFTSMAN_MULT = {"journeyman": 1.0, "master": 1.5, "grandmaster": 2.0, "archmaster": 2.5}
TIER_MULT = {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.5, 5: 2.0}

# Fallback recipes for targets without dismantle data (InfusionService.ws
# GetRecipeForCategory).
FALLBACK_RECIPES = {
    "steelsword": [("Leather straps", 2), ("Steel ingot", 2)],
    "silversword": [("Leather straps", 2), ("Meteorite ingot", 2)],
    "armor": [("Leather squares", 2), ("Thread", 4)],
    "pants": [("Leather scraps", 2), ("Thread", 2)],
    "boots": [("Leather scraps", 2), ("Thread", 2)],
    "gloves": [("Leather scraps", 1), ("Thread", 2)],
}
SUPPORTED = set(FALLBACK_RECIPES)

def find_redkit():
    """W3_REDKIT, else 'The Witcher 3 REDkit' in the Steam libraries
    (registry HKCU Software/Valve/Steam SteamPath -> steamapps/libraryfolders.vdf)."""
    if os.environ.get("W3_REDKIT"):
        return os.environ["W3_REDKIT"]
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam") as key:
            steam = winreg.QueryValueEx(key, "SteamPath")[0]
    except (ImportError, OSError):
        return None
    libs = [steam]
    vdf = os.path.join(steam, "steamapps", "libraryfolders.vdf")
    if os.path.exists(vdf):
        text = open(vdf, encoding="utf-8", errors="replace").read()
        libs += [m.replace("\\\\", "\\") for m in re.findall(r'"path"\s+"([^"]+)"', text)]
    for lib in libs:
        path = os.path.join(lib, "steamapps", "common", "The Witcher 3 REDkit")
        if os.path.isdir(path):
            return path
    return None

ITEM_RE = re.compile(r"<item\s(?P<attrs>[^>]*?)>(?P<body>.*?)</item>", re.S)
ATTR_RE = re.compile(r'(\w+)\s*=\s*"([^"]*)"')
PART_RE = re.compile(r'<parts\s+count\s*=\s*"(\d+)"\s*>\s*([^<]+?)\s*</parts>')
TAGS_RE = re.compile(r"<tags>\s*([^<]*?)\s*</tags>")
# The mod never infuses these (InfusionService.IsExcludedItem).
EXCLUDED_TAGS = {"NoShow", "NoShowInPlayersInventory", "Body", "Quest", "Aerondight", "AutogenUseLevelRange"}


def load_items(redkit):
    """name -> dict(category, price, parts, source). First definition wins;
    base game files are read before DLC files, items/ before items_plus/."""
    root = os.path.join(redkit, "r4data")
    patterns = [
        os.path.join(root, "gameplay", "items", "*.xml"),
        os.path.join(root, "dlc", "*", "data", "gameplay", "items", "*.xml"),
        os.path.join(root, "gameplay", "items_plus", "*.xml"),
        os.path.join(root, "dlc", "*", "data", "gameplay", "items_plus", "*.xml"),
    ]
    items = {}
    for pattern in patterns:
        for path in sorted(glob.glob(pattern)):
            try:
                text = open(path, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            for m in ITEM_RE.finditer(text):
                attrs = dict(ATTR_RE.findall(m.group("attrs")))
                name = attrs.get("name")
                if not name or name in items:
                    continue
                parts = [(p[1], int(p[0])) for p in PART_RE.findall(m.group("body"))]
                tags_m = TAGS_RE.search(m.group("body"))
                tags = {t.strip() for t in tags_m.group(1).split(",")} if tags_m else set()
                try:
                    price = float(attrs.get("price", "0") or 0)
                except ValueError:
                    price = 0.0
                items[name] = {
                    "category": attrs.get("category", ""),
                    "price": price,
                    "parts": parts,
                    "source": os.path.relpath(path, root),
                    "excluded": bool(tags & EXCLUDED_TAGS),
                }
    return items


def gap_factor(gap):
    if gap <= 0:
        return 0.0
    return min(gap / LEVELS_PER_FULL_SET, MAX_SETS)


# Only these count as recipe materials (InfusionService.IsRecipeMaterial):
# dismantle data also lists junk (insignia, hafts), whole items and food.
RECIPE_CATEGORIES = {"crafting_ingredient", "alchemy_ingredient"}
ITEMS = {}  # filled by main(); used for the material category filter


def recipe_for(item, gap):
    """(recipe, from_dismantle_data)"""
    sets = gap_factor(gap)
    recipe = [(n, max(1, math.ceil(q * sets))) for n, q in item["parts"]
              if q > 0 and ITEMS.get(n, {}).get("category") in RECIPE_CATEGORIES]
    if recipe:
        return recipe, True
    return list(FALLBACK_RECIPES.get(item["category"], [])), False


def salvage_of(item):
    return [(n, math.floor(q * SALVAGE_YIELD_MULT)) for n, q in item["parts"]]


def apply_salvage(recipe, salvage):
    salv = {}
    for n, q in salvage:
        salv.setdefault(n, q)  # first entry counts, like ComputeRemainingMaterials
    covered, remaining = [], []
    for n, q in recipe:
        s = salv.get(n, 0)
        if s > 0:
            covered.append((n, min(s, q)))
        if q - s > 0:
            remaining.append((n, q - s))
    return covered, remaining


def raw_fee(value, gap, craftsman, quality):
    return value * FEE_FRACTION * gap_factor(gap) * CRAFTSMAN_MULT[craftsman] * TIER_MULT.get(quality, 1.0)


def soften(fee):
    # Soft ceiling (InfusionService.SoftenFee): square-root growth above FEE_SOFT_CAP.
    if FEE_SOFT_CAP > 0 and fee > FEE_SOFT_CAP:
        return math.sqrt(fee * FEE_SOFT_CAP)
    return fee


def fee_for(value, gap, craftsman, quality):
    fee = soften(raw_fee(value, gap, craftsman, quality))
    return max(MIN_FEE, int(math.floor(fee + 0.5)))


def fmt(parts):
    return ", ".join(f"{n} x{q}" for n, q in parts) if parts else "-"


def parse_have(text):
    have = {}
    for chunk in (text or "").split(","):
        if "=" in chunk:
            n, q = chunk.rsplit("=", 1)
            have[n.strip()] = int(q)
    return have


def cmd_pair(items, args):
    for key in ("target", "sacrifice"):
        if getattr(args, key) not in items:
            sys.exit(f"unknown item '{getattr(args, key)}' - try --find")
    target, sacrifice = items[args.target], items[args.sacrifice]
    for key, it in (("target", target), ("sacrifice", sacrifice)):
        if it["excluded"]:
            print(f"WARNING: {key} carries an excluded tag (hidden/body/quest item) - the mod rejects it")
    if target["category"] != sacrifice["category"]:
        print(f"WARNING: categories differ ({target['category']} vs {sacrifice['category']}) - the mod rejects this pair")
    recipe, from_data = recipe_for(target, args.gap)
    covered, remaining = apply_salvage(recipe, salvage_of(sacrifice))
    target_value = args.value if args.value is not None else target["price"]
    sacrifice_value = args.sacrifice_value if args.sacrifice_value is not None else sacrifice["price"]
    value = max(target_value, sacrifice_value)
    fee = fee_for(value, args.gap, args.craftsman, args.quality)

    print(f"Target    : {args.target} [{target['category']}] ({target['source']})")
    print(f"Sacrifice : {args.sacrifice} ({sacrifice['source']})")
    print(f"Gap       : {args.gap} levels -> factor {gap_factor(args.gap):.2f} sets")
    print(f"Recipe    : {fmt(recipe)}" + ("" if from_data else "   (fallback table: target has no dismantle data)"))
    print(f"Salvage   : {fmt(salvage_of(sacrifice))}")
    print(f"Covered   : {fmt(covered)}")
    print(f"You pay   : {fmt(remaining)}")
    if args.have:
        have = parse_have(args.have)
        short = [(n, q - have.get(n, 0)) for n, q in remaining if have.get(n, 0) < q]
        print(f"Missing   : {fmt(short)}" if short else "Missing   : - (all materials available)")
    in_game = args.value is not None and args.sacrifice_value is not None
    basis = "higher in-game value" if in_game else "higher value, BASE price from XML where not passed (rough lower bound)"
    print(f"Fee       : {fee} crowns  ({basis} {value:g} x {FEE_FRACTION} x {gap_factor(args.gap):.2f}"
          f" x {CRAFTSMAN_MULT[args.craftsman]} {args.craftsman} x {TIER_MULT.get(args.quality, 1.0)} tier)")
    raw = raw_fee(value, args.gap, args.craftsman, args.quality)
    if FEE_SOFT_CAP > 0 and raw > FEE_SOFT_CAP:
        print(f"            softened above {FEE_SOFT_CAP}: sqrt({raw:.0f} x {FEE_SOFT_CAP})")


def cmd_table(items, args):
    rows = [(n, it) for n, it in items.items() if it["category"] == args.table and not it["excluded"]]
    rows.sort(key=lambda r: (r[1]["price"], r[0]))
    print(f"# category {args.table}, gap {args.gap} (factor {gap_factor(args.gap):.2f}), "
          f"craftsman {args.craftsman}; fee from BASE price (in-game values are higher)")
    print("| Item | Base price | Fee | Recipe (before salvage) |")
    print("| --- | ---: | ---: | --- |")
    for name, it in rows:
        recipe, from_data = recipe_for(it, args.gap)
        fee = fee_for(it["price"], args.gap, args.craftsman, args.quality)
        print(f"| {name} | {it['price']:g} | {fee} | {fmt(recipe)}{'' if from_data else ' (fallback)'} |")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--redkit", default=None, help="REDkit install folder (default: W3_REDKIT or auto-detected from Steam)")
    ap.add_argument("--target")
    ap.add_argument("--sacrifice")
    ap.add_argument("--gap", type=int, default=10, help="level gap (sacrifice level - target level)")
    ap.add_argument("--value", type=float, help="target's in-game crown value (tooltip); default: XML base price")
    ap.add_argument("--sacrifice-value", type=float, help="sacrifice's in-game crown value (tooltip); default: XML base price")
    ap.add_argument("--craftsman", choices=sorted(CRAFTSMAN_MULT), default="journeyman")
    ap.add_argument("--quality", type=int, default=1, help="target quality 1-5 (tier multiplier: 4 relic x1.5, 5 Witcher gear x2.0)")
    ap.add_argument("--have", help='inventory counts, e.g. "Thread=112,Leather squares=5"')
    ap.add_argument("--table", metavar="CATEGORY", help="cost table for a category (armor, boots, pants, gloves, steelsword, silversword)")
    ap.add_argument("--find", metavar="TEXT", help="list item names containing TEXT")
    args = ap.parse_args()

    if not args.redkit:
        args.redkit = find_redkit()
    if not args.redkit:
        sys.exit("REDkit not found in the Steam libraries - pass --redkit or set W3_REDKIT")
    items = load_items(args.redkit)
    ITEMS.update(items)
    if not items:
        sys.exit(f"no item definitions found under {args.redkit}\\r4data - set --redkit or W3_REDKIT")

    if args.find:
        for n in sorted(n for n in items if args.find.lower() in n.lower()):
            it = items[n]
            print(f"{n}  [{it['category']}]  price {it['price']:g}  parts: {fmt(it['parts'])}")
    elif args.table:
        cmd_table(items, args)
    elif args.target and args.sacrifice:
        cmd_pair(items, args)
    else:
        ap.print_help()


if __name__ == "__main__":
    main()
