# Fixes the advance widths in the OTB files of a bitmap font. Run by the
# tamzen and cozette overrides in terminal.nix, on the files of the built
# package.
#
# An OTB stores each glyph's width twice: in the bitmap strike (EBLC/EBDT),
# in whole pixels, and in hmtx, in font units. The OTBs of both fonts are
# conversions whose hmtx only approximates the pixels:
#
#   - Tamzen8x15r.otb says 1161/2048 em, which at its 15 ppem strike is
#     8.503 px, not 8;
#   - cozette.otb says 1024/2048 em for its 6 px glyphs, 6.5 px at 13 ppem
#     (and 1890 for its 12 px wide ones, 11.997 px).
#
# Renderers that take metrics from the bitmap strike (FreeType for foot,
# fuzzel, Alacritty) never notice. Pango does: it positions glyphs by the hmtx
# advance, so in waybar and mako Tamzen drew with a 1 px gap per glyph and
# Cozette with an extra half pixel, rounded unevenly to 6 or 7. The fix sets
# every hmtx advance to the bitmap's own advance, glyph by glyph, which is
# what the pixels say.

import sys

from fontTools.ttLib import TTFont


def advance_of(metrics):
    # BigGlyphMetrics (horizontal and vertical) or SmallGlyphMetrics (one
    # direction only, which here is horizontal).
    return metrics.horiAdvance if hasattr(metrics, "horiAdvance") else metrics.Advance


def bitmap_advances(font):
    """Advance in pixels of every glyph in the font's only bitmap strike."""
    strikes = font["EBLC"].strikes
    if len(strikes) != 1:
        sys.exit(f"expected one bitmap strike, found {len(strikes)}")
    advances = {}
    # Index formats 2 and 5 store one metrics record for a whole run of
    # glyphs in EBLC; the others store metrics with each glyph in EBDT.
    for sub in strikes[0].indexSubTables:
        metrics = getattr(sub, "metrics", None)
        if metrics is not None:
            for name in sub.names:
                advances[name] = advance_of(metrics)
    for name, glyph in font["EBDT"].strikeData[0].items():
        if name not in advances:
            advances[name] = advance_of(glyph.metrics)
    return strikes[0].bitmapSizeTable.ppemY, advances


for path in sys.argv[1:]:
    # Keep the stored timestamps, so the output is the same on every build.
    font = TTFont(path, recalcTimestamp=False)
    ppem, advances = bitmap_advances(font)
    upem = font["head"].unitsPerEm

    hmtx = font["hmtx"].metrics
    changed = 0
    for glyph, (old, lsb) in hmtx.items():
        px = advances.get(glyph)
        if px is None:  # no bitmap for this glyph: leave it as it is
            continue
        new = round(px * upem / ppem)
        if round(new * ppem / upem) != px:
            sys.exit(f"{path}: no integer advance rounds to {px} px at {ppem} ppem")
        if new != old:
            hmtx[glyph] = (new, lsb)
            changed += 1

    widths = [adv for adv, _ in hmtx.values()]
    font["hhea"].advanceWidthMax = max(widths)
    # OS/2 defines xAvgCharWidth as the average over all non-zero widths.
    nonzero = [w for w in widths if w]
    font["OS/2"].xAvgCharWidth = round(sum(nonzero) / len(nonzero))

    font.save(path)
    pixels = sorted(set(advances.values()))
    print(f"{path}: {ppem} ppem, bitmap advances {pixels} px, {changed} hmtx entries fixed")
