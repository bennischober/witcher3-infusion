"""Shapes the Arabic strings source for the game.

The game's ar.w3strings holds Arabic in logical order, but already shaped into
presentation forms - the UI does not join letters itself. This mirrors the
conventions found in the game's own table (docs/TECHNICAL_DISCOVERY.md):

- a letter that joins neither side stays the base letter (U+06xx),
- yeh initial/medial use the Farsi yeh forms (U+FBFE/FBFF),
- heh uses heh doachashmee (U+06BE initial, U+FBAD medial, U+FBAB final),
- tah/zah initial stay the base letter (the font has no initial forms),
- lam + alef become the lam-alef ligatures.

Usage: python shape-arabic.py <source.csv> <output.csv>
"""
import sys

# letter: (final, initial, medial); None = the letter joins only to the right.
DUAL = {
    "ب": ("ﺐ", "ﺑ", "ﺒ"),  # beh
    "ت": ("ﺖ", "ﺗ", "ﺘ"),  # teh
    "ث": ("ﺚ", "ﺛ", "ﺜ"),  # theh
    "ج": ("ﺞ", "ﺟ", "ﺠ"),  # jeem
    "ح": ("ﺢ", "ﺣ", "ﺤ"),  # hah
    "خ": ("ﺦ", "ﺧ", "ﺨ"),  # khah
    "س": ("ﺲ", "ﺳ", "ﺴ"),  # seen
    "ش": ("ﺶ", "ﺷ", "ﺸ"),  # sheen
    "ص": ("ﺺ", "ﺻ", "ﺼ"),  # sad
    "ض": ("ﺾ", "ﺿ", "ﻀ"),  # dad
    "ط": ("ﻂ", "ط", "ﻄ"),  # tah
    "ظ": ("ﻆ", "ظ", "ﻈ"),  # zah
    "ع": ("ﻊ", "ﻋ", "ﻌ"),  # ain
    "غ": ("ﻎ", "ﻏ", "ﻐ"),  # ghain
    "ف": ("ﻒ", "ﻓ", "ﻔ"),  # feh
    "ق": ("ﻖ", "ﻗ", "ﻘ"),  # qaf
    "ك": ("ﻚ", "ﻛ", "ﻜ"),  # kaf
    "ل": ("ﻞ", "ﻟ", "ﻠ"),  # lam
    "م": ("ﻢ", "ﻣ", "ﻤ"),  # meem
    "ن": ("ﻦ", "ﻧ", "ﻨ"),  # noon
    "ه": ("ﮫ", "ھ", "ﮭ"),  # heh
    "ي": ("ﻲ", "ﯾ", "ﯿ"),  # yeh
    "ئ": ("ﺊ", "ﺋ", "ﺌ"),  # yeh with hamza
}
RIGHT = {
    "ا": "ﺎ",  # alef
    "أ": "ﺄ",  # alef with hamza above
    "إ": "ﺈ",  # alef with hamza below
    "آ": "ﺂ",  # alef with madda
    "د": "ﺪ",  # dal
    "ذ": "ﺬ",  # thal
    "ر": "ﺮ",  # reh
    "ز": "ﺰ",  # zain
    "و": "ﻮ",  # waw
    "ؤ": "ﺆ",  # waw with hamza
    "ة": "ﺔ",  # teh marbuta
    "ى": "ﻰ",  # alef maksura (only final in the game's table)
}
# alef after lam: (isolated ligature, final ligature)
LAM_ALEF = {
    "ا": ("ﻻ", "ﻼ"),
    "أ": ("ﻷ", "ﻸ"),
    "إ": ("ﻹ", "ﻺ"),
    "آ": ("ﻵ", "ﻶ"),
}
LAM = "ل"


def shape(text):
    out = []
    n = len(text)
    i = 0
    while i < n:
        ch = text[i]
        prev_joins = i > 0 and text[i - 1] in DUAL
        if ch == LAM and i + 1 < n and text[i + 1] in LAM_ALEF:
            out.append(LAM_ALEF[text[i + 1]][1 if prev_joins else 0])
            i += 2
            continue
        next_joinable = i + 1 < n and (text[i + 1] in DUAL or text[i + 1] in RIGHT)
        if ch in DUAL:
            final, initial, medial = DUAL[ch]
            if prev_joins and next_joinable:
                out.append(medial)
            elif prev_joins:
                out.append(final)
            elif next_joinable:
                out.append(initial)
            else:
                out.append(ch)
        elif ch in RIGHT:
            out.append(RIGHT[ch] if prev_joins else ch)
        else:
            if "ً" <= ch <= "ْ":
                raise ValueError(f"diacritics are not supported: {text!r}")
            out.append(ch)
        i += 1
    return "".join(out)


def main(src, dst):
    with open(src, encoding="utf-8") as f:
        lines = [l.rstrip("\r\n") for l in f]
    shaped = []
    for line in lines:
        if line.startswith(";"):
            shaped.append(line)
        else:
            head, text = line.rsplit("|", 1)
            shaped.append(head + "|" + shape(text))
    with open(dst, "w", encoding="utf-8", newline="") as f:
        f.write("\r\n".join(shaped) + "\r\n")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
