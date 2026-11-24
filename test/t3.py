import emu, struct
emu.state['today']=(2026,11,22)
emu.call(0x0049, cx=0x500); emu.log.clear()
emu.key(ord('k'))
print('item', emu.clip)
for b,d in emu.vm.items():
    print(hex(b), d[:0x50].hex())
hdr = emu.vm[emu.clip['item']]
print('owner', struct.unpack_from('<HH',hdr,0), 'flags', hex(struct.unpack_from('<H',hdr,4)[0]), 'name', hdr[6:0x27].split(b'\0')[0])
print('count', struct.unpack_from('<H',hdr,0x27), 'fmt', struct.unpack_from('<H',hdr,0x29), 'info', struct.unpack_from('<HHH',hdr,0x3d))
tb = emu.vm[struct.unpack_from('<H',hdr,0x41)[0]]
ch = struct.unpack_from('<H',tb,0x10)[0]; p=struct.unpack_from('<H',tb,ch)[0]; n=struct.unpack_from('<H',tb,p-2)[0]-2
print('runs', tb[0x12:0x1a].hex(), '[0]', tb[0:2].hex())
print(tb[p:p+n].decode('mac_roman').replace('\r','\n'))
emu.show('nach Kopieren')
