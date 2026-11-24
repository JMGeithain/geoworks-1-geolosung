#!/usr/bin/env python3
"""Run GeoLosung's handlers in a 16-bit emulator with stub kernel calls.
Only for testing the program logic on the PC (no GeoWorks needed)."""
import struct, sys, os
from unicorn import *
from unicorn.x86_const import *

FLAT = sys.argv[1] if len(sys.argv) > 1 else '/home/claude/sdk/build/geolos/geolos.resource.bin'
DATA = os.environ.get('DATADIR', '/home/claude/ref/out')

raw = open(FLAT, 'rb').read()
foot = raw.rindex(b'G1META01')
code_len, meth_len, rel_len, _ = struct.unpack_from('<HHHH', raw, foot + 8)
code = raw[:code_len]
methods = {}
for i in range(0, meth_len, 4):
    m, off = struct.unpack_from('<HH', raw, code_len + i)
    methods[m] = off
libcalls = set()
for i in range(0, rel_len, 4):
    info, extra, opoff = struct.unpack_from('<BBH', raw, code_len + meth_len + i)
    if info == 0x14: libcalls.add(opoff - 1 + 5)      # return address

CS, DG, SSEG, SENT = 0x1000, 0x2000, 0x2800, 0x0F00
mu = Uc(UC_ARCH_X86, UC_MODE_16)
mu.mem_map(0, 0x100000)
mu.mem_write(CS * 16, code)
mu.mem_write(SENT * 16, b'\xf4')

heap = [0x4000]
files = {}
next_handle = [100]
log = []          # drawn text: (x, y, size, style, colour, text)
state = dict(size=0, style=0, tcol=None, win=(0, 0, 559, 419))

def r(reg): return mu.reg_read(reg)
def w(reg, v): mu.reg_write(reg, v & 0xffff)
def setcf(c):
    f = r(UC_X86_REG_EFLAGS)
    mu.reg_write(UC_X86_REG_EFLAGS, (f | 1) if c else (f & ~1))
def lin(seg, off): return seg * 16 + off

vm = {}          # vm block -> bytes
clip = {}
def kernel(n, lib=False):
    ax, bx, cx, dx = r(UC_X86_REG_AX), r(UC_X86_REG_BX), r(UC_X86_REG_CX), r(UC_X86_REG_DX)
    ds, si = r(UC_X86_REG_DS), r(UC_X86_REG_SI)
    setcf(False)
    if lib:
        if n == 135: w(UC_X86_REG_BX, 0x4444)
        elif n == 127:
            assert bx == 0x4444 and r(UC_X86_REG_BP) == 0, (hex(bx), r(UC_X86_REG_BP))
            clip['item'] = ax
        else: raise Exception('UI %d not stubbed' % n)
        return
    if n == 0:                                   # MemAlloc
        seg = heap[0]; heap[0] += (ax + 15) // 16 + 1
        mu.mem_write(seg * 16, b'\0' * ax)
        w(UC_X86_REG_BX, seg); w(UC_X86_REG_AX, seg)
    elif n == 2: pass
    elif n == 399:                               # file <-> VM handle (as seen in UI.GEO)
        w(UC_X86_REG_BX, {0x4444: 0x5555, 0x5555: 0x4444}.get(ax, 0xdead))
    elif n in (4, 6, 149, 398):
        if n == 149: w(UC_X86_REG_BX, 0x1230)
    elif n == 24:                                # LMem init: header DX
        base = ds * 16
        mu.mem_write(base + 2, struct.pack('<H', dx))
        mu.mem_write(base + dx, struct.pack('<HH', 0xffff, 0))
    elif n == 25:
        w(UC_X86_REG_AX, 0x24)
    elif n == 28:                                # ReAlloc AX = chunk, CX = size
        base = ds * 16
        mu.mem_write(base + 0x40, struct.pack('<H', cx + 2))
        mu.mem_write(base + ax, struct.pack('<H', 0x42))
    elif n == 411:                               # VMAttach CX = mem handle
        blk = 0x100 + 0x10 * len(vm)
        vm[blk] = bytes(mu.mem_read(cx * 16, 0x600))
        assert bx == 0x5555, hex(bx)
        w(UC_X86_REG_AX, blk)
    elif n == 52:                                # FileOpen DS:DX
        name = bytes(mu.mem_read(lin(ds, dx), 80)).split(b'\0')[0].decode('latin-1')
        p = os.path.join(DATA, name.split('\\')[-1])
        ok = name.startswith('DOCUMENT\\LOSUNGEN\\') and os.path.exists(p)
        log.append(('open', name, ok))
        if ok:
            h = next_handle[0]; next_handle[0] += 1
            files[h] = [open(p, 'rb').read(), 0]
            w(UC_X86_REG_AX, h)
        else:
            w(UC_X86_REG_AX, 2); setcf(True)
    elif n == 54: files.pop(bx, None)
    elif n == 58:                                # FileRead BX, CX, DS:DX
        f = files[bx]; chunk = f[0][f[1]:f[1] + cx]; f[1] += len(chunk)
        mu.mem_write(lin(ds, dx), chunk)
        if len(chunk) < cx:
            setcf(True); w(UC_X86_REG_CX, len(chunk))
    elif n == 60:                                # FilePos BX, CX:DX
        files[bx][1] = (cx << 16) | dx
    elif n in (73, 74, 76, 211, 212, 310, 316, 336, 346, 355, 446, 447, 489): pass
    elif n == 95:
        assert (ax >> 8) == 0x2a
        y, m, d = state['today']
        w(UC_X86_REG_CX, y); w(UC_X86_REG_DX, (m << 8) | d)
    elif n == 330:                               # GrDrawText
        if cx == 0:
            t = bytes(mu.mem_read(lin(ds, si), 200)).split(b'\0')[0]
        else:
            t = bytes(mu.mem_read(lin(ds, si), cx))
        log.append(('text', ax if ax < 0x8000 else ax - 0x10000, bx if bx < 0x8000 else bx - 0x10000,
                    state['size'], state['style'], state['tcol'], t.decode('mac_roman')))
        w(UC_X86_REG_ES, 0x7777)                 # pretend the kernel trashes ES
    elif n == 359:
        state['tcol'] = (ax & 0xff, bx & 0xff, bx >> 8) if (ax >> 8) == 0x80 else ax & 0xff
    elif n == 362: state['style'] = ax & 0xff
    elif n == 366:
        state['size'] = dx; w(UC_X86_REG_ES, 0x7777)
    elif n == 440:
        x0, y0, x1, y1 = state['win']
        w(UC_X86_REG_AX, x0); w(UC_X86_REG_BX, y0); w(UC_X86_REG_CX, x1); w(UC_X86_REG_DX, y1)
    else:
        raise Exception('kernel %d not stubbed' % n)

def hook(uc, address, size, user):
    if address < 0x1000:                         # far call to 0:ordinal
        sp = r(UC_X86_REG_SP); ss = r(UC_X86_REG_SS)
        ip, cs = struct.unpack('<HH', bytes(mu.mem_read(lin(ss, sp), 4)))
        kernel(address, ip in libcalls)
        w(UC_X86_REG_SP, sp + 4)
        mu.reg_write(UC_X86_REG_CS, cs); mu.reg_write(UC_X86_REG_IP, ip)
mu.hook_add(UC_HOOK_CODE, hook, begin=0, end=0xfff)

def call(msg, **regs):
    off = methods[msg]
    w(UC_X86_REG_SS, SSEG); w(UC_X86_REG_SP, 0xfff0)
    sp = 0xfff0 - 4
    mu.mem_write(lin(SSEG, sp), struct.pack('<HH', 0, SENT))
    w(UC_X86_REG_SP, sp)
    w(UC_X86_REG_DS, DG); w(UC_X86_REG_ES, DG); w(UC_X86_REG_CS, CS)
    for k, v in regs.items(): w(getattr(__import__("unicorn.x86_const", fromlist=["x"]), 'UC_X86_REG_' + k.upper()), v)
    mu.emu_start(lin(CS, off), lin(SENT, 0), count=20_000_000)
    return r(UC_X86_REG_AX)

def dg(off): return struct.unpack('<H', bytes(mu.mem_read(DG * 16 + off, 2)))[0]

def show(title):
    print('=====', title, '| date %d.%d.%d mode %d state %d scr %d' % (dg(0xB8), dg(0xB6), dg(0xB4), dg(0xC0), dg(0xC4), dg(0xC2)))
    for e in log:
        if e[0] == 'text':
            _, x, y, size, style, col, t = e
            print('  %4d %4d %2d %s %-15s %s' % (x, y, size, 'B' if style & 0x20 else ' ', col, t))
        else:
            print('  ', e)
    log.clear()

def key(cl, ch=0, dl=0):
    log.clear()
    call(0x007b, cx=(ch << 8) | cl, dx=dl)

if __name__ == '__main__':
    state['today'] = (2026, 11, 22)
    call(0x0049, cx=0x500)                       # first expose
    show('Start (heute 22.11.2026)')
    key(0x92, 0xff); show('Pfeil rechts')
    key(0x93, 0xff); key(0x93, 0xff); show('2x Pfeil links')
    key(ord('d'));
    for c in '24.12.2027': key(ord(c))
    show('Datum-Eingabe')
    key(0x0d, 0xff); show('Eingabe -> 24.12.2027')
    key(0x92, 0xff); key(0x92, 0xff); key(0x92, 0xff); key(0x92, 0xff); key(0x92, 0xff); key(0x92, 0xff); key(0x92, 0xff)
    show('7x rechts -> 31.12.2027 / 1.1.2028?')
    key(0x92, 0xff); show('rechts -> 2028 fehlt')
    call(0x00c3, cx=80, dx=10); show('Klick Heute')
    key(ord('d'));
    for c in '30.2.2027': key(ord(c))
    key(0x0d, 0xff); show('ungueltig 30.2.2027')
    key(0x1b, 0xff)
    call(0x0c04); show('Hilfe-Menue')
    key(ord('x'));
    state['win'] = (0, 0, 299, 199)
    call(0x0049, cx=0x500); show('kleines Fenster 300x200')
    key(0x91, 0xff); key(0x91, 0xff); show('2x runter')
    key(0x91, 0xff); key(0x91, 0xff); key(0x91, 0xff); key(0x91, 0xff); show('4x runter (Ende)')
