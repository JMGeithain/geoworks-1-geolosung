#!/usr/bin/env python3
"""Referenz-Implementierung (nur zum Testen) des GeoLosung-Umwandlers.
Erzeugt dieselben Bytes wie GeoLosung-Umwandeln.ps1."""
import sys, re, datetime as dt, xml.etree.ElementTree as ET, hashlib

# GEOS-Zeichensatz 0x80..0xFF (aus FreeGEOS Include/char.def)
GEOS_HI = [0xC4,0xC5,0xC7,0xC9,0xD1,0xD6,0xDC,0xE1,0xE0,0xE2,0xE4,0xE3,0xE5,0xE7,0xE9,0xE8,
           0xEA,0xEB,0xED,0xEC,0xEE,0xEF,0xF1,0xF3,0xF2,0xF4,0xF6,0xF5,0xFA,0xF9,0xFB,0xFC,
           0x2020,0xB0,0xA2,0xA3,0xA7,0x2022,0xB6,0xDF,0xAE,0xA9,0x2122,0xB4,0xA8,0x2260,0xC6,0xD8,
           0x221E,0xB1,0x2264,0x2265,0xA5,0xB5,0x2202,0x2211,0x220F,0x3C0,0x222B,0xAA,0xBA,0x3A9,0xE6,0xF8,
           0xBF,0xA1,0xAC,0x221A,0x192,0x2248,0x2206,0xAB,0xBB,0x2026,0xA0,0xC0,0xC3,0xD5,0x152,0x153,
           0x2013,0x2014,0x201C,0x201D,0x2018,0x2019,0xF7,0x25CA,0xFF,0x178,0x2044,0xA4,0x2039,0x203A,0xDD,0xFD,
           0x2021,0xB7,0x201A,0x201E,0x2030,0xC2,0xCA,0xC1,0xCB,0xC8,0xCD,0xCE,0xCF,0xCC,0xD3,0xD4,
           0,0xD2,0xDA,0xDB,0xD9,0x131,0x2C6,0x2DC,0xAF,0x2D8,0x2D9,0x2DA,0xB8,0x2DD,0x2DB,0x2C7]
U2G = {u: 0x80 + i for i, u in enumerate(GEOS_HI) if u}
FALLBACK = {0x20AC: 'EUR', 0x2012: '-', 0x2015: '-', 0x2212: '-', 0x2032: "'", 0x2033: '"'}

def to_geos(s, ascii_quotes=False):
    out = bytearray()
    for ch in s:
        c = ord(ch)
        if ascii_quotes and c in (0x2018, 0x2019, 0x201A): ch, c = "'", 0x27
        if ascii_quotes and c in (0x201C, 0x201D, 0x201E, 0xAB, 0xBB): ch, c = '"', 0x22
        if 0x20 <= c < 0x7F: out.append(c)
        elif c in U2G: out.append(U2G[c])
        elif c in FALLBACK: out += FALLBACK[c].encode()
        elif c == 9: out.append(0x20)
        else: out.append(ord('?'))
    return bytes(out)

def easter(y):
    a=y%19; b=y//100; c=y%100; d=b//4; e=b%4; f=(b+8)//25; g=(b-f+1)//3
    h=(19*a+b-d-g+15)%30; i=c//4; k=c%4; l=(32+2*e+2*i-h-k)%7; m=(a+11*h+22*l)//451
    mo=(h+l-7*m+114)//31; da=(h+l-7*m+114)%31+1
    return dt.date(y,mo,da)

PASSION = {
 -49: 'Sonntag vor der Passionszeit - Estomihi (Sei mir ein starker Fels! Psalm 31,3)',
 -42: '1. Sonntag der Passionszeit - Invokavit (Er ruft mich an, darum will ich ihn erh\u00f6ren. Psalm 91,15)',
 -35: '2. Sonntag der Passionszeit - Reminiszere (Gedenke, HERR, an deine Barmherzigkeit! Psalm 25,6)',
 -28: '3. Sonntag der Passionszeit - Okuli (Meine Augen sehen stets auf den HERRN. Psalm 25,15)',
 -21: '4. Sonntag der Passionszeit - L\u00e4tare (Freuet euch mit Jerusalem! Jesaja 66,10)',
 -14: '5. Sonntag der Passionszeit - Judika (Schaffe mir Recht, Gott! Psalm 43,1)',
 -7: '6. Sonntag der Passionszeit - Palmsonntag',
 -3: 'Gr\u00fcndonnerstag', -2: 'Karfreitag', 0: 'Osterfest', 1: 'Ostermontag',
 7: '1. Sonntag nach Ostern - Quasimodogeniti (Wie die neugeborenen Kindlein. 1. Petrus 2,2)',
 14: '2. Sonntag nach Ostern - Miserikordias Domini (Die Erde ist voll der G\u00fcte des HERRN. Psalm 33,5)',
 21: '3. Sonntag nach Ostern - Jubilate (Jauchzet Gott, alle Lande! Psalm 66,1)',
 28: '4. Sonntag nach Ostern - Kantate (Singet dem HERRN ein neues Lied! Psalm 98,1)',
 35: '5. Sonntag nach Ostern - Rogate (Betet!)',
 39: 'Christi Himmelfahrt',
 42: '6. Sonntag nach Ostern - Exaudi (HERR, h\u00f6re meine Stimme! Psalm 27,7)',
 49: 'Pfingstfest', 50: 'Pfingstmontag', 56: 'Trinitatis (Dreieinigkeit)'}
FIXED = {(1,1):'Neujahr',(6,1):'Epiphanias',(24,6):'Johannistag',(29,9):'Michaelistag',
         (31,10):'Reformationstag',(24,12):'Heiliger Abend',(25,12):'Weihnachtsfest',
         (26,12):'2. Weihnachtstag',(31,12):'Altjahrsabend'}

def feasts(y):
    E = easter(y); D = dt.timedelta
    r = {}
    def put(d, s):
        if d.year == y: r[d] = s
    # Weihnachts- und Epiphaniaszeit
    for day in range(2, 6):
        d = dt.date(y,1,day)
        if d.weekday() == 6: put(d, '2. Sonntag nach Weihnachten')
    for day in range(27, 32):
        d = dt.date(y,12,day)
        if d.weekday() == 6: put(d, '1. Sonntag nach Weihnachten')
    if E - D(70) > dt.date(y,2,2):
        last = E - D(77)
    else:
        last = dt.date(y,2,2)
        while last.weekday() != 6: last -= D(1)
        while last >= E - D(49): last -= D(7)
    d = dt.date(y,1,7); n = 0
    while d.weekday() != 6: d += D(1)
    while d < last:
        n += 1; put(d, f'{n}. Sonntag nach Epiphanias'); d += D(7)
    put(last, 'Letzter Sonntag nach Epiphanias')
    for off, s in ((-70,'4. Sonntag vor der Passionszeit'),
                   (-63,'3. Sonntag vor der Passionszeit - Septuagesimae'),
                   (-56,'2. Sonntag vor der Passionszeit - Sexagesimae')):
        if E + D(off) > last: put(E + D(off), s)
    for off, s in PASSION.items(): put(E + D(off), s)
    # Ende des Kirchenjahres / Advent
    a1 = dt.date(y,11,27)
    while a1.weekday() != 6: a1 += D(1)
    for k in range(4): put(a1 + D(7*k), f'{k+1}. Sonntag im Advent')
    put(a1 - D(7), 'Letzter Sonntag des Kirchenjahres - Ewigkeitssonntag')
    put(a1 - D(14), 'Vorletzter Sonntag des Kirchenjahres')
    put(a1 - D(21), 'Drittletzter Sonntag des Kirchenjahres')
    put(a1 - D(11), 'Bu\u00df- und Bettag')
    d = E + D(63); k = 1
    while d < a1 - D(21):
        put(d, f'{k}. Sonntag nach Trinitatis' + (' (Israelsonntag)' if k == 10 else ''))
        d += D(7); k += 1
    ed = dt.date(y,10,1)
    while ed.weekday() != 6: ed += D(1)
    put(ed, 'Erntedankfest')
    for (dd, mm), s in FIXED.items():
        d = dt.date(y, mm, dd)
        if d in r and (dd, mm) == (24,12): r[d] = r[d] + ' - ' + s
        else: r[d] = s
    d = dt.date(y,12,6)
    if d.weekday() != 6: r[d] = 'Nikolaustag'
    return r

def clean(s):
    return re.sub(r'\s+', ' ', s or '').strip()

def emph(s):  # #ein# -> e i n (gesperrt)
    return re.sub(r'#([^#]+)#', lambda m: ' '.join(m.group(1)), s)

def part(el):
    intro = clean(el.findtext('IL'))
    text = clean(' '.join(clean(l.text) for l in el.findall('L')))
    m = re.match(r'^/([^/]+)/\s*(.*)$', text)
    if m and not intro: intro, text = clean(m.group(1)), m.group(2)
    return intro, emph(text), clean(el.findtext('SL'))

def convert(xmlpath, ascii_quotes=False):
    root = ET.parse(xmlpath).getroot()
    year = int(root.get('year'))
    fe = feasts(year)
    lines = ['GEOLOSUNG 1', f'JAHR {year}', 'QUELLE ' + xmlpath.replace('\\','/').split('/')[-1]]
    count = 0
    for los in root.findall('LOSUNG'):
        d, m = int(los.get('d')), int(los.get('m'))
        date = dt.date(year, m, d)
        title = clean(los.findtext('TL'))
        title = re.sub(r'^Losung f\u00fcr\s+', '', title)
        lines.append(f'[{m:02d}{d:02d}]')
        lines.append('T=' + title)
        if date in fe: lines.append('F=' + fe[date])
        for key, tag in (('A', 'OT'), ('N', 'NT')):
            el = los.find(tag)
            intro, text, ref = part(el)
            if intro: lines.append(key + 'E=' + intro)
            lines.append(key + 'T=' + text)
            lines.append(key + 'S=' + ref)
        count += 1
    lines.append('[ENDE]')
    data = b''.join(to_geos(l, ascii_quotes) + b'\r\n' for l in lines)
    return year, count, data

if __name__ == '__main__':
    for p in sys.argv[1:]:
        y, n, data = convert(p)
        out = f'GLOS{y}.DAT'
        open(out, 'wb').write(data)
        print(out, n, 'Tage', len(data), 'Bytes', hashlib.sha256(data).hexdigest()[:16])
