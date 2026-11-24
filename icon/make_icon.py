# GeoLosung icon: a small blue book with white lettering hinted on the cover
# and white page edges on the right and at the bottom (own design).
# Palette indices of the 16 GEOS colours; T = transparent.
T = -1
BLACK, DBLUE, LBLUE, GREY, DGREY, WHITE = 0, 1, 9, 7, 8, 15

def book(w, h, x0, y0, bw, bh, color, spine, lines, page):
    img = [[T] * w for _ in range(h)]
    x1, y1 = x0 + bw - 1, y0 + bh - 1
    cover = DBLUE if color else BLACK
    # pages (white block shifted right/down behind the cover)
    for y in range(y0 + page, y1 + page + 1):
        for x in range(x0 + page, x1 + page + 1):
            img[y][x] = WHITE
    for y in range(y0 + page, y1 + page + 1):          # page outline
        img[y][x1 + page] = BLACK
    for x in range(x0 + page, x1 + page + 1):
        img[y1 + page][x] = BLACK
    if color and page > 1:                              # page lines
        for x in range(x0 + page, x1 + page):
            img[y1 + 1][x] = GREY
        for y in range(y0 + page, y1 + page):
            img[y][x1 + 1] = GREY
    # cover
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            img[y][x] = cover
    for y in range(y0, y1 + 1):
        img[y][x0] = BLACK
        img[y][x1] = BLACK
    for x in range(x0, x1 + 1):
        img[y0][x] = BLACK
        img[y1][x] = BLACK
    # spine
    for y in range(y0 + 1, y1):
        for x in range(x0 + 1, x0 + 1 + spine):
            img[y][x] = LBLUE if color else WHITE
    # lettering: white lines (y offset, x start, x end relative to the cover)
    for dy, a, b in lines:
        for x in range(x0 + a, x0 + b + 1):
            img[y0 + dy][x] = WHITE
    return img

icons = {
    # name: w, h, colour?, cover position and size, spine, lettering, page offset
    'c64x40': (64, 40, True,  dict(x0=20, y0=2, bw=24, bh=34, spine=3,
               lines=[(7, 7, 20), (8, 7, 20), (12, 9, 18), (16, 8, 19), (25, 10, 17)], page=2)),
    'm64x40': (64, 40, False, dict(x0=20, y0=2, bw=24, bh=34, spine=2,
               lines=[(7, 6, 20), (8, 6, 20), (12, 8, 18), (16, 7, 19), (25, 9, 17)], page=2)),
    'c48x30': (48, 30, True,  dict(x0=15, y0=1, bw=18, bh=26, spine=2,
               lines=[(5, 5, 15), (6, 5, 15), (9, 7, 13), (12, 6, 14), (19, 7, 12)], page=2)),
    'm48x30': (48, 30, False, dict(x0=15, y0=1, bw=18, bh=26, spine=2,
               lines=[(5, 5, 15), (6, 5, 15), (9, 7, 13), (12, 6, 14), (19, 7, 12)], page=2)),
    'm64x18': (64, 18, False, dict(x0=25, y0=0, bw=13, bh=16, spine=1,
               lines=[(3, 4, 10), (6, 5, 9), (9, 4, 10)], page=1)),
    'm48x14': (48, 14, False, dict(x0=18, y0=0, bw=11, bh=12, spine=1,
               lines=[(3, 3, 8), (5, 4, 7), (8, 3, 8)], page=1)),
}
out = {}
for name, (w, h, color, p) in icons.items():
    out[name] = (w, h, color, book(w, h, color=color, **p))

if __name__ == '__main__':
    from PIL import Image
    PAL = [(0,0,0),(0,0,170),(0,170,0),(0,170,170),(170,0,0),(170,0,170),(170,85,0),(170,170,170),
           (85,85,85),(85,85,255),(85,255,85),(85,255,255),(255,85,85),(255,85,255),(255,255,85),(255,255,255)]
    tiles = []
    for name, (w, h, color, img) in out.items():
        im = Image.new('RGB', (w, h), (200, 200, 200))
        for y in range(h):
            for x in range(w):
                if img[y][x] != T:
                    im.putpixel((x, y), PAL[img[y][x]])
        tiles.append(im.resize((w * 6, h * 6), Image.NEAREST))
    W = sum(t.width for t in tiles) + 20 * len(tiles)
    H = max(t.height for t in tiles)
    sheet = Image.new('RGB', (W, H), (255, 255, 255))
    x = 0
    for t in tiles:
        sheet.paste(t, (x, 0))
        x += t.width + 20
    sheet.save('preview.png')
