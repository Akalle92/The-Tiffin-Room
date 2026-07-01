"""Remove a baked gray/checkerboard background by global two-tone color key.

Unlike a flood fill, this does NOT rely on connectivity, so a white sari or
other light-but-enclosed detail is preserved. We learn the background gray
value(s) from the image border (which is pure background), then clear every
desaturated pixel whose brightness matches a border gray (within TOL).
Saturated pixels (skin, cloth dyes) and dark outlines are always kept.
"""
import sys
from PIL import Image, ImageFilter

SAT_MAX = 24   # only desaturated pixels can be background
TOL = 20       # brightness distance from a known border gray


def checkerkey(path: str) -> None:
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = list(im.get_flattened_data() if hasattr(im, "get_flattened_data") else im.getdata())

    def gray(p):
        return (p[0] + p[1] + p[2]) // 3

    def sat(p):
        return max(p[0], p[1], p[2]) - min(p[0], p[1], p[2])

    # learn background grays from the border
    border_grays = set()
    for x in range(w):
        for p in (px[x], px[(h - 1) * w + x]):
            if sat(p) <= SAT_MAX:
                border_grays.add(gray(p))
    for y in range(h):
        for p in (px[y * w], px[y * w + w - 1]):
            if sat(p) <= SAT_MAX:
                border_grays.add(gray(p))

    remove = [False] * 256
    for v in range(256):
        for bg in border_grays:
            if abs(v - bg) <= TOL:
                remove[v] = True
                break

    out = []
    cleared = 0
    for p in px:
        r, g, b, a = p
        if a > 0 and sat(p) <= SAT_MAX and remove[gray(p)]:
            out.append((r, g, b, 0))
            cleared += 1
        else:
            out.append(p)
    im.putdata(out)

    r, g, b, a = im.split()
    a = a.filter(ImageFilter.MinFilter(3))
    im = Image.merge("RGBA", (r, g, b, a))
    im.save(path)
    print(f"  {path.split(chr(92))[-1]:28s} cleared={round(100 * cleared / (w * h))}%")


if __name__ == "__main__":
    for f in sys.argv[1:]:
        checkerkey(f)
