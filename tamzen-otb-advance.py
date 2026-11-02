# Fixes the advance widths in Tamzen's OTB files. Run by the tamzen override
# in terminal.nix, on the files of the built package.
#
# The OTBs are fonttosfnt conversions of the bitmaps, and fonttosfnt writes
# an hmtx advance that only approximates the cell: Tamzen8x15r.otb says
# 1161/2048 em, which at its 15 ppem strike is 8.503 px, not 8. Renderers that
# take metrics from the bitmap strike (FreeType for foot, fuzzel, Alacritty)
# never notice. Pango does: it scales the hmtx advance and rounds it, so every
# glyph in waybar and mako advanced 9 px and text drew with a 1 px gap. The
# fix sets every advance to exactly the cell width the file name states.

import re
import sys

from fontTools.ttLib import TTFont

for path in sys.argv[1:]:
    m = re.search(r"(\d+)x(\d+)[rb]\.otb$", path)
    if not m:
        sys.exit(f"{path}: no WxH cell size in the file name")
    width = int(m.group(1))

    # Keep the stored timestamps, so the output is the same on every build.
    font = TTFont(path, recalcTimestamp=False)
    strikes = font["EBLC"].strikes
    if len(strikes) != 1:
        sys.exit(f"{path}: expected one bitmap strike, found {len(strikes)}")
    ppem = strikes[0].bitmapSizeTable.ppemY
    upem = font["head"].unitsPerEm

    advance = round(width * upem / ppem)
    if round(advance * ppem / upem) != width:
        sys.exit(f"{path}: no integer advance rounds to {width} px at {ppem} ppem")

    hmtx = font["hmtx"].metrics
    for glyph, (_, lsb) in hmtx.items():
        hmtx[glyph] = (advance, lsb)
    font["hhea"].advanceWidthMax = advance
    font["OS/2"].xAvgCharWidth = advance

    font.save(path)
    print(f"{path}: {width} px at {ppem} ppem -> advance {advance}/{upem}")
