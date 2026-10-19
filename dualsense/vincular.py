# Vincula un DualSense por USB: escribe en el mando la dirección del adaptador
# Bluetooth y una clave nueva, y guarda la misma clave en BlueZ.
import fcntl, os, sys
def HIDIOCGFEATURE(n): return (3 << 30) | (n << 16) | (ord('H') << 8) | 0x07
def HIDIOCSFEATURE(n): return (3 << 30) | (n << 16) | (ord('H') << 8) | 0x06

hidraw, host = sys.argv[1], sys.argv[2]
host_bytes = bytes(reversed(bytes.fromhex(host.replace(':', ''))))
key = os.urandom(16)

with open(hidraw, 'rb+', buffering=0) as f:
    rep = bytearray(27); rep[0] = 0x0A
    rep[1:7] = host_bytes
    rep[7:23] = key
    fcntl.ioctl(f, HIDIOCSFEATURE(len(rep)), rep)
    info = bytearray(20); info[0] = 0x09
    fcntl.ioctl(f, HIDIOCGFEATURE(len(info)), info)

mando = ':'.join(f'{b:02X}' for b in reversed(info[1:7]))
d = f'/var/lib/bluetooth/{host}/{mando}'
os.makedirs(d, exist_ok=True)
with open(f'{d}/info', 'w') as out:
    out.write(f"""[General]
Name=DualSense Wireless Controller
Class=0x002508
SupportedTechnologies=BR/EDR;
Trusted=true
Blocked=false
Services=00001124-0000-1000-8000-00805f9b34fb;00001200-0000-1000-8000-00805f9b34fb;

[LinkKey]
Key={key.hex().upper()}
Type=4
PINLength=0

[DeviceID]
Source=2
Vendor=1356
Product=3302
Version=256
""")
os.chmod(f'{d}/info', 0o600)
print('mando', mando, 'vinculado a', host)
