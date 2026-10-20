#!/usr/bin/env python3
"""Read-only inspector for the XFL sources (.fla) REDkit ships for the game's
Flash UI (r4data/gameplay/gui_new/fla). Answers layout questions without
Adobe Animate: which symbol holds a text field, how wide it is, which font
size it uses, where an instance sits in its parent.

An .fla here is a zip of XML: DOMDocument.xml (main timeline) and one
LIBRARY/*.xml per library symbol. Several have a malformed central
directory, so this tool walks the local file headers instead of using
zipfile. An unpacked XFL folder works too.

Coordinates are local to the symbol: an element's position is its matrix
(tx, ty); a text field's box starts at (left, top) inside it. Width and
height are the authored values, before the instance's scale (shown as
'scale' when it isn't 1). Nested positions add up along the instance chain;
use 'find' with the symbol name to walk up to the parent.

Commands:
  symbols FLA [-g REGEX]          library symbols, linkage class, text field count
  show FLA [SYMBOL] [--frame N]   layers, keyframes and elements of a symbol
                                  (no SYMBOL: the main timeline)
  texts FLA [-s REGEX] [-n REGEX] every text field: box, font, size, sample text
  find REGEX [--texts]            search all FLAs for instance names, symbol
                                  names, linkage classes and library references

FLA is a path, or a name searched under the REDkit fla folder
(e.g. panel_blacksmith). REDkit is auto-detected; --redkit or W3_REDKIT
override it, --root searches another folder.

Examples:
  python tools/fla-inspect.py find tfWarningMessage
  python tools/fla-inspect.py texts panel_blacksmith -s Disassemble
  python tools/fla-inspect.py show panel_blacksmith Panels/ItemDisassembleInfo
  python tools/fla-inspect.py symbols MenuInventory -g tooltip --json
"""

import argparse
import html
import json
import os
import re
import struct
import sys
import xml.etree.ElementTree as ET
import zlib

NS = "{http://ns.adobe.com/xfl/2008/}"
TEXT_TAGS = ("DOMDynamicText", "DOMStaticText", "DOMInputText")
DOC_SYMBOL = "(document)"
# Raw-byte patterns that skip entries before parsing them (parsing is the slow part).
ROOT_TAG = re.compile(rb'<DOM\w+\s[^>]*>')
ATTR = re.compile(rb'(\w+)="([^"]*)"')
TEXT_ELEMENT = re.compile(rb'<DOM(?:Dynamic|Static|Input)Text\b')
# Attributes 'find' matches.
SEARCHED_ATTRS =re.compile(rb' (?:name|libraryItemName|linkageClassName|linkageBaseClass)="([^"]*)"')


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


def fla_root(args):
    if args.root:
        return args.root
    redkit = args.redkit or find_redkit()
    if not redkit:
        sys.exit("REDkit not found: pass --redkit, --root or set W3_REDKIT")
    return os.path.join(redkit, "r4data", "gameplay", "gui_new", "fla")


def all_flas(root):
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        out += [os.path.join(dirpath, f) for f in sorted(filenames) if f.lower().endswith(".fla")]
    return out


def resolve_fla(arg, args):
    """A path, else a (partial) file name under the fla root."""
    if os.path.exists(arg):
        return arg
    flas = all_flas(fla_root(args))
    want = arg.lower()
    if not want.endswith(".fla"):
        want += ".fla"
    exact = [p for p in flas if os.path.basename(p).lower() == want]
    if len(exact) == 1:
        return exact[0]
    part = [p for p in flas if arg.lower() in os.path.basename(p).lower()]
    if len(part) == 1:
        return part[0]
    if not part:
        sys.exit(f"no .fla matches '{arg}'")
    sys.exit(f"'{arg}' is ambiguous:\n  " + "\n  ".join(rel(p, fla_root(args)) for p in part))


def rel(path, root):
    return os.path.relpath(path, root).replace("\\", "/")


# ---- XFL container ----------------------------------------------------------

class Xfl:
    """Entries of an .fla zip (via local headers) or an unpacked XFL folder."""

    def __init__(self, path):
        self.path = path
        self.entries = {}  # name -> (offset, method, compressed size) or file path
        if os.path.isdir(path):
            for dirpath, _, filenames in os.walk(path):
                for f in filenames:
                    full = os.path.join(dirpath, f)
                    self.entries[os.path.relpath(full, path).replace("\\", "/")] = full
            return
        # Headers only: the image entries make up most of the file.
        with open(path, "rb") as fh:
            pos = 0
            while True:
                fh.seek(pos)
                header = fh.read(30)
                if len(header) < 30 or header[:4] != b"PK\x03\x04":
                    break
                flags, method = struct.unpack_from("<HH", header, 6)
                csize, = struct.unpack_from("<I", header, 18)
                nlen, elen = struct.unpack_from("<HH", header, 26)
                if flags & 8:
                    sys.exit(f"{path}: entry with a data descriptor - not supported")
                name = fh.read(nlen).decode("utf-8", "replace").replace("\\", "/")
                start = pos + 30 + nlen + elen
                self.entries[name] = (start, method, csize)
                pos = start + csize

    def read(self, name):
        entry = self.entries[name]
        if isinstance(entry, str):
            with open(entry, "rb") as fh:
                return fh.read()
        start, method, csize = entry
        with open(self.path, "rb") as fh:
            fh.seek(start)
            raw = fh.read(csize)
        if method == 0:
            return raw
        if method == 8:
            return zlib.decompress(raw, -15)
        raise ValueError(f"{name}: compression method {method} not supported")

    def xml(self, name, raw=None):
        root = ET.fromstring(self.read(name) if raw is None else raw)
        for el in root.iter():
            if el.tag.startswith(NS):
                el.tag = el.tag[len(NS):]
        return root

    def symbol_entries(self):
        names = ["DOMDocument.xml"] if "DOMDocument.xml" in self.entries else []
        return names + sorted(n for n in self.entries if n.startswith("LIBRARY/") and n.endswith(".xml"))

    def headers(self):
        """(symbol name, root tag attributes, entry, raw bytes) for the main
        timeline and every library symbol, without parsing the whole file.
        The name comes from the root tag: the entry path escapes some characters."""
        for entry in self.symbol_entries():
            raw = self.read(entry)
            if entry == "DOMDocument.xml":
                yield DOC_SYMBOL, {}, entry, raw
                continue
            m = ROOT_TAG.search(raw, 0, 8192)
            if m:
                attrs = {k.decode(): html.unescape(v.decode("utf-8", "replace")) for k, v in ATTR.findall(m.group(0))}
            else:
                attrs = dict(self.xml(entry, raw).attrib)
            yield attrs.get("name", entry[len("LIBRARY/"):-4]), attrs, entry, raw

    def symbols(self, keep=None):
        """(symbol name, root element) for the main timeline and every library symbol.
        keep(name, raw bytes) -> bool skips entries before parsing them."""
        for name, _, entry, raw in self.headers():
            if keep and not keep(name, raw):
                continue
            yield name, self.xml(entry, raw)

    def symbol_index(self):
        """Symbol name -> entry."""
        return {name: entry for name, _, entry, _ in self.headers()}


# ---- element walking --------------------------------------------------------

def num(value, default=0.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def fmt(value, digits=2):
    return f"{value:.{digits}f}".rstrip("0").rstrip(".") if isinstance(value, float) else str(value)


def transform(info, m):
    """Adds 'scale' / 'skew' to an element info when the matrix has them."""
    if abs(m["a"] - 1) > 1e-4 or abs(m["d"] - 1) > 1e-4:
        info["scale"] = [m["a"], m["d"]]
    if abs(m["b"]) > 1e-4 or abs(m["c"]) > 1e-4:
        info["skew"] = [m["b"], m["c"]]
    return info


def matrix(el):
    m = el.find("matrix/Matrix")
    get = (lambda k, d: num(m.get(k), d)) if m is not None else (lambda k, d: d)
    return {k: get(k, d) for k, d in (("a", 1.0), ("b", 0.0), ("c", 0.0), ("d", 1.0), ("tx", 0.0), ("ty", 0.0))}


def text_info(el):
    """Geometry and first-run formatting of a text field element."""
    m = matrix(el)
    left, top = num(el.get("left")), num(el.get("top"))
    runs = el.findall("textRuns/DOMTextRun")
    chars = "".join((r.findtext("characters") or "") for r in runs)
    attrs = runs[0].find("textAttrs/DOMTextAttrs") if runs else None
    a = attrs.attrib if attrs is not None else {}
    info = {
        "kind": el.tag[3:-4].lower(),  # dynamic / static / input
        "name": el.get("name", ""),
        "x": m["tx"] + left * m["a"],
        "y": m["ty"] + top * m["d"],
        "width": num(el.get("width")),
        "height": num(el.get("height")),
        "lineType": el.get("lineType", "single line"),
        "html": el.get("renderAsHTML") == "true",
        "autoExpand": el.get("autoExpand") == "true",
        "face": a.get("face", ""),
        "size": num(a.get("size"), 12.0),
        "lineHeight": num(a.get("lineHeight")) if "lineHeight" in a else None,
        "lineSpacing": num(a.get("lineSpacing")) if "lineSpacing" in a else None,
        "letterSpacing": num(a.get("letterSpacing")) if "letterSpacing" in a else None,
        "alignment": a.get("alignment", "left"),
        "color": a.get("fillColor", "#000000"),
        "runs": len(runs),
        "text": chars,
    }
    return transform(info, m)


def instance_info(el):
    m = matrix(el)
    info = {
        "kind": el.tag[3:].replace("Instance", "").lower() or el.tag,
        "name": el.get("name", ""),
        "library": el.get("libraryItemName", ""),
        "x": m["tx"],
        "y": m["ty"],
    }
    if el.get("isVisible") == "false":
        info["hidden"] = True
    return transform(info, m)


def walk_elements(elements, shapes=False):
    """Element infos in a frame's <elements>, descending into groups."""
    for el in list(elements) if elements is not None else []:
        if el.tag in TEXT_TAGS:
            yield text_info(el)
        elif el.tag == "DOMGroup":
            yield from walk_elements(el.find("members"), shapes)
        elif el.tag.endswith("Instance"):
            yield instance_info(el)
        elif shapes:
            yield {"kind": el.tag[3:].lower(), "name": "", "library": ""}


def timelines(root):
    if root.tag == "DOMDocument":
        return root.findall("timelines/DOMTimeline")
    return root.findall("timeline/DOMTimeline")


def keyframes(root):
    """(timeline, layer, frame index, label, duration, elements element) for every keyframe."""
    for tl in timelines(root):
        for layer in tl.findall("layers/DOMLayer"):
            for fr in layer.findall("frames/DOMFrame"):
                yield (tl.get("name", ""), layer, int(num(fr.get("index"))), fr.get("name", ""),
                       int(num(fr.get("duration"), 1)), fr.find("elements"))


def text_fields(root):
    """(layer name, frame index, frame label, text info) for every text field of a symbol."""
    for _, layer, index, label, _, elements in keyframes(root):
        for info in walk_elements(elements):
            if info["kind"] in ("dynamic", "static", "input"):
                yield layer.get("name", ""), index, label, info


# ---- output -----------------------------------------------------------------

def short(text, limit=40):
    text = text.replace("\r", "\\n").replace("\n", "\\n")
    return text if len(text) <= limit else text[:limit - 3] + "..."


def describe_text(t):
    parts = [f"{t['kind']} '{t['name']}'" if t["name"] else t["kind"],
             f"at ({fmt(t['x'])}, {fmt(t['y'])})",
             f"{fmt(t['width'])} x {fmt(t['height'])}"]
    if "scale" in t:
        parts.append("scale " + " x ".join(fmt(s, 3) for s in t["scale"]))
    if "skew" in t:
        parts.append("skewed")
    font = f"{t['face']} {fmt(t['size'])}"
    if t["lineHeight"] is not None:
        font += f"/{fmt(t['lineHeight'])}"
    parts.append(font)
    if t["letterSpacing"]:
        parts.append(f"spacing {fmt(t['letterSpacing'])}")
    parts.append(t["alignment"])
    parts.append(t["lineType"])
    if t["html"]:
        parts.append("html")
    if t["autoExpand"]:
        parts.append("autoExpand")
    parts.append(t["color"])
    if t["runs"] > 1:
        parts.append(f"{t['runs']} runs")
    if t["text"].strip():
        parts.append(f"\"{short(t['text'])}\"")
    return "  ".join(parts)


def describe_instance(i):
    parts = [f"{i['kind']} '{i['name']}'" if i["name"] else i["kind"]]
    if i.get("library"):
        parts.append(f"<{i['library']}>")
    if "x" in i:
        parts.append(f"at ({fmt(i['x'])}, {fmt(i['y'])})")
    if "scale" in i:
        parts.append("scale " + " x ".join(fmt(s, 3) for s in i["scale"]))
    if "skew" in i:
        parts.append("skewed")
    if i.get("hidden"):
        parts.append("hidden")
    return "  ".join(parts)


def describe(info):
    return describe_text(info) if "face" in info else describe_instance(info)


def emit_json(obj):
    json.dump(obj, sys.stdout, indent=2, ensure_ascii=False)
    print()


def find_symbol(xfl, wanted):
    """Exact symbol name, else a unique last path segment, else a unique
    substring (both case-insensitive)."""
    symbols = xfl.symbol_index()
    if wanted is None:
        wanted = DOC_SYMBOL
    if wanted in symbols:
        return wanted, xfl.xml(symbols[wanted])
    leaf = [s for s in symbols if s.rsplit("/", 1)[-1].lower() == wanted.lower()]
    if len(leaf) == 1:
        return leaf[0], xfl.xml(symbols[leaf[0]])
    part = [s for s in symbols if wanted.lower() in s.lower()]
    if len(part) == 1:
        return part[0], xfl.xml(symbols[part[0]])
    if not part:
        sys.exit(f"no symbol matches '{wanted}' (see 'symbols')")
    sys.exit(f"'{wanted}' is ambiguous:\n  " + "\n  ".join(sorted(part)))


# ---- commands ---------------------------------------------------------------

def cmd_symbols(args):
    xfl = Xfl(resolve_fla(args.fla, args))
    pattern = re.compile(args.grep, re.I) if args.grep else None
    rows = []
    for name, attrs, _, raw in xfl.headers():
        linkage = attrs.get("linkageClassName", "")
        base = attrs.get("linkageBaseClass", "")
        if pattern and not (pattern.search(name) or pattern.search(linkage) or pattern.search(base)):
            continue
        rows.append({"symbol": name, "linkage": linkage, "baseClass": base,
                     "textFields": len(TEXT_ELEMENT.findall(raw))})
    if args.json:
        return emit_json(rows)
    for r in rows:
        cls = r["linkage"] + (f" : {r['baseClass']}" if r["baseClass"] else "")
        texts = f"  [{r['textFields']} text]" if r["textFields"] else ""
        print(f"{r['symbol']}{'  -> ' + cls if cls else ''}{texts}")
    sys.stdout.flush()
    print(f"-- {len(rows)} symbols", file=sys.stderr)


def cmd_show(args):
    xfl = Xfl(resolve_fla(args.fla, args))
    name, root = find_symbol(xfl, args.symbol)
    out = []
    for tl, layer, index, label, duration, elements in keyframes(root):
        if args.frame is not None and not index <= args.frame < index + duration:
            continue
        items = list(walk_elements(elements, args.shapes))
        if not items:
            continue
        out.append({"timeline": tl, "layer": layer.get("name", ""),
                    "layerType": layer.get("layerType", ""), "frame": index,
                    "duration": duration, "label": label, "elements": items})
    if args.json:
        return emit_json({"symbol": name, "linkage": root.get("linkageClassName", ""), "keyframes": out})
    linkage = root.get("linkageClassName")
    print(name + (f"  -> {linkage}" if linkage else ""))
    layer_seen = None
    for kf in out:
        if (kf["timeline"], kf["layer"]) != layer_seen:
            layer_seen = (kf["timeline"], kf["layer"])
            kind = f" ({kf['layerType']})" if kf["layerType"] else ""
            print(f"  layer '{kf['layer']}'{kind}")
        span = f"{kf['frame']}" if kf["duration"] == 1 else f"{kf['frame']}-{kf['frame'] + kf['duration'] - 1}"
        print(f"    frame {span}" + (f" '{kf['label']}'" if kf["label"] else ""))
        for el in kf["elements"]:
            print("      " + describe(el))


def cmd_texts(args):
    xfl = Xfl(resolve_fla(args.fla, args))
    sym_re = re.compile(args.symbol, re.I) if args.symbol else None
    name_re = re.compile(args.name, re.I) if args.name else None

    def keep(sym, raw):
        return (not sym_re or sym_re.search(sym)) and TEXT_ELEMENT.search(raw)

    rows = []
    for sym, root in xfl.symbols(keep):
        for layer, index, label, info in text_fields(root):
            if name_re and not name_re.search(info["name"]):
                continue
            rows.append(dict(symbol=sym, layer=layer, frame=index, label=label, **info))
    if args.json:
        return emit_json(rows)
    current = None
    for r in rows:
        if r["symbol"] != current:
            current = r["symbol"]
            print(current)
        where = f"[{r['layer']} @{r['frame']}" + (f" '{r['label']}'" if r["label"] else "") + "]"
        print(f"  {where}  {describe_text(r)}")
    sys.stdout.flush()
    print(f"-- {len(rows)} text fields", file=sys.stderr)


def cmd_find(args):
    pattern = re.compile(args.pattern, re.I)
    root_dir = fla_root(args)

    def keep(_, raw):
        return any(pattern.search(html.unescape(v.decode("utf-8", "replace")))
                   for v in SEARCHED_ATTRS.findall(raw))

    rows = []
    for path in all_flas(root_dir):
        fla = rel(path, root_dir)
        for sym, root in Xfl(path).symbols(keep):
            hits = [("symbol", sym)] if pattern.search(sym) else []
            for key in ("linkageClassName", "linkageBaseClass"):
                if pattern.search(root.get(key) or ""):
                    hits.append(("class", root.get(key)))
            for kv in hits:
                rows.append({"fla": fla, "symbol": sym, "match": kv[0], "value": kv[1]})
            for tl, layer, index, label, _, elements in keyframes(root):
                for info in walk_elements(elements):
                    is_text = "face" in info
                    if args.texts and not is_text:
                        continue
                    if pattern.search(info["name"]) or (not is_text and pattern.search(info["library"])):
                        rows.append({"fla": fla, "symbol": sym, "match": "element",
                                     "layer": layer.get("name", ""), "frame": index, "element": info})
    if args.json:
        return emit_json(rows)
    for r in rows:
        if r["match"] == "element":
            print(f"{r['fla']}  {r['symbol']}  [{r['layer']} @{r['frame']}]  {describe(r['element'])}")
        else:
            print(f"{r['fla']}  {r['symbol']}  ({r['match']}: {r['value']})")
    sys.stdout.flush()
    print(f"-- {len(rows)} matches", file=sys.stderr)


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--redkit", default=None, help="REDkit install folder (default: W3_REDKIT or auto-detected from Steam)")
    common.add_argument("--root", default=None, help="folder searched for .fla files (default: REDkit's gui_new/fla)")
    common.add_argument("--json", action="store_true", help="machine-readable output")

    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="command", required=True)

    p = sub.add_parser("symbols", parents=[common], help="list library symbols")
    p.add_argument("fla")
    p.add_argument("-g", "--grep", help="regex on symbol name or linkage class")
    p.set_defaults(func=cmd_symbols)

    p = sub.add_parser("show", parents=[common], help="layers, keyframes and elements of a symbol")
    p.add_argument("fla")
    p.add_argument("symbol", nargs="?", help="symbol name or unique part of it (default: main timeline)")
    p.add_argument("--frame", type=int, help="only keyframes covering this frame (0-based)")
    p.add_argument("--shapes", action="store_true", help="also list unnamed shapes and bitmaps")
    p.set_defaults(func=cmd_show)

    p = sub.add_parser("texts", parents=[common], help="every text field with geometry and font")
    p.add_argument("fla")
    p.add_argument("-s", "--symbol", help="regex on the symbol name")
    p.add_argument("-n", "--name", help="regex on the text field's instance name")
    p.set_defaults(func=cmd_texts)

    p = sub.add_parser("find", parents=[common], help="search all FLAs")
    p.add_argument("pattern", help="regex on instance names, symbol names, linkage classes, library references")
    p.add_argument("--texts", action="store_true", help="only text fields")
    p.set_defaults(func=cmd_find)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
