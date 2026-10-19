# ps5-mediatek-fixes

WiFi and Bluetooth (DualSense) fixes for PS5 units that ship the **MediaTek MT7921**
combo chip instead of the Marvell IW620, running the
[ps5-linux](https://github.com/ps5-linux) kernel (tested on 7.1.7, Ubuntu 26.04).

| Device | ID | Problem | Fix |
|---|---|---|---|
| WiFi (PCIe) | `14c3:7961` | Kernel built with `CONFIG_MT7921E` unset | Build `mt7921e.ko` out of tree |
| Bluetooth (USB) | `0e8d:3603` | btusb binds a phantom second controller (`hci1`, interfaces 3/4) | udev rule deauthorizing interfaces 3 and 4 |
| Bluetooth | `0e8d:3603` | USB autosuspend | udev rule + `btusb enable_autosuspend=0` |
| Bluetooth | `0e8d:3603` | ACL TX never completes: the chip accepts one URB on bulk OUT `0x01` and NAKs forever | `0003`: send ACL on the second bulk OUT, `0x02` |
| Bluetooth | `0e8d:3603` | L2CAP HID connection (PSM 17) arrives before the Encryption Change event and is refused with "security block" | `0004`: answer "pending" while encryption is on its way |

## Patches

- `0001-ps5-linux-btusb.patch`, `0002-ps5-linux-hci_sync.patch`: unmodified hunks from
  [ps5-linux-patches](https://github.com/ps5-linux/ps5-linux-patches) so the rebuilt
  modules match the running kernel.
- `0003-btusb-ps5-mediatek-bulk-out-0x02.patch`: interface 0 of the chip exposes two bulk OUT
  endpoints (`0x01`, `0x02`) and btusb picks the first one. Only `0x02` (paired with bulk
  IN `0x82`) is drained by the firmware. The endpoint can be changed with the
  `btusb.ps5_tx_ep` module parameter (`0` restores the default behaviour).
- `0004-l2cap-defer-security-when-encryption-pending.patch`: the chip delivers ACL data
  (bulk IN) ahead of HCI events (interrupt IN). When a link key has already been replied
  and encryption is not yet up, the connection request is answered as pending instead of
  blocked; `l2cap_security_cfm()` then accepts or blocks it once the link is encrypted, so
  no channel opens unencrypted.

## Build and install

```sh
sudo apt install build-essential curl gcc-14   # the gcc major the kernel was built with
./build.sh                  # build for the running kernel
sudo ./build.sh --install   # build and install to /lib/modules/<version>/updates
sudo reboot
```

Run it again after every kernel update. If a patch no longer applies, the script stops.

## DualSense over Bluetooth

BlueZ cannot cable-pair a DualSense. With the controller plugged in over USB:

```sh
sudo python3 -I dualsense/leer.py /dev/hidrawN                       # current pairing
sudo python3 -I dualsense/vincular.py /dev/hidrawN <adapter address>  # pair
sudo systemctl restart bluetooth
```

`vincular.py` writes the adapter address and a new link key to the controller (feature
report `0x0A`) and stores the same key in `/var/lib/bluetooth`. Unplug it and press PS.
