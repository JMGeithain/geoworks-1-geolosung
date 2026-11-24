import emu
emu.state['today']=(2026,11,22)
emu.call(0x0049, cx=0x500); emu.log.clear()
emu.call(0x0c03); emu.show('info')
emu.call(0x0c04); emu.show('hilfe')
