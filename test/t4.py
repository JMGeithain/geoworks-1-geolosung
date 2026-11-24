import emu
emu.state['today']=(2026,11,22)
emu.call(0x0049, cx=0x500); emu.log.clear()
emu.call(0x0c04); emu.show('Hilfe')
emu.key(0x91,0xff); emu.key(0x91,0xff); emu.show('2x runter')
# Seite runter-Knopf: Mitte unten
emu.log.clear(); emu.call(0x00c3, cx=280, dx=420-22-12+5); emu.show('Seite runter')
emu.log.clear(); emu.call(0x00c3, cx=280, dx=420-22-12+5); emu.show('Seite runter 2')
emu.log.clear(); emu.call(0x00c3, cx=560-116-20+10, dx=420-22-12+5); emu.show('Schliessen')
