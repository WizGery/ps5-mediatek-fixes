import fcntl, sys
def HIDIOCGFEATURE(n): return (3 << 30) | (n << 16) | (ord('H') << 8) | 0x07
with open(sys.argv[1], 'rb+', buffering=0) as f:
    buf = bytearray(20); buf[0] = 0x09
    fcntl.ioctl(f, HIDIOCGFEATURE(len(buf)), buf)
    mac = ':'.join(f'{b:02X}' for b in reversed(buf[1:7]))
    host = ':'.join(f'{b:02X}' for b in reversed(buf[10:16]))
    print('raw    ', buf.hex())
    print('mando  ', mac)
    print('vinculado a', host)
