Gigabyte MC12-LE0 OEM Firmware Backups
======================================

Some historic, vulnerable Gigabyte MC12-LE0 BMC firmware images as previously
provided by Gigabyte on their [BMC firmware download/support
website](https://www.gigabyte.com/Enterprise/Server-Motherboard/MC12-LE0-rev-1x#Support-Firmware)
will be kept here.

Since AMI fixed a number of security-sensitive bugs in (and even downright
removed the SSH server from) more recent OEM BMC firmware builds, this might be
able to help get your board downgraded to a software revision that still allows
for this OpenBMC installer to work. Keeping that in mind, you **DO NOT WANT
THESE FIRMWARE RELEASES TO BE INSTALLED** ON A MAINBOARD YOU ACTUALLY USE. Due
to the contained vulnerabilities, it's **DANGEROUS** to do that, and your BMC
**IS VERY LIKELY TO GET COMPROMISED** if you disregard this advice.


Release 12.60.35
----------------

The file named `126035.bin` in this directory contains a flashable EEPROM image
of the Gigabyte/AMI MegaRAC BMC firmware release **12.60.35**.

In my testing, `gigaflash_x64` (also contained in this directory) could
reprogram the MC12-LE0 BMC EEPROM via SPI from a live-booted release of [grml
for 64-bit PC (amd64)](https://grml.org/download/) even from the most recent
BMC firmware release.

Gigaflash uses a proprietary method to flash the ROM from the host that other
tools (such as the excellent [culvert](https://github.com/amboar/culvert/))
presently cannot, but will proceed to only flash images cryptographically
signed by the manufacturer.

The following shell session transcript illustrates how a downgrading procedure
involving it usually goes:

```bash
# ./gigaflash_x64 126035.bin -cs 0 -2500
gigaflash v2.0.10
Do you want to preserve configuration? (Y/N)
N
Loading Firmware...

Update Firmware
Find ASPEED Device 1a03:2000 on 4:0.0
MMIO Virtual Address: ba56f000
Relocate IO Base: f000
Found ASPEED Device 1a03:2500 rev. 41
Static Memory Controller Information:
CS0 Flash Type is SPI
CS1 Flash Type is SPI
CS2 Flash Type is SPI
CS3 Flash Type is NOR
CS4 Flash Type is NOR
Boot CS is 0
Option Information:
CS: 0
Flash Type: SPI
[Warning] Don't AC OFF or Reboot System During BMC Firmware Update!!
Find Flash Chip #1: 64MB SPI Flash
Update Flash Chip #1 O.K.
Update Flash Chip O.K.
Wait 90 seconds for BMC Ready...
./gigaflash_x64 126035.bin -cs 0 -2500  557.82s user 0.06s system 84% cpu 11:00.98 total
```

The whole flashing process is expected to take a few minutes. The host will NOT
be reset during the procedure, but the BMC will become unavailable (both via
the network and via its serial console) at the start of flashing, and reboot at
least twice after that succeeded. After the second reboot, it will have its
default configuration restored (if you answered the prompt like I did in the
example above; otherwise, strange things might happen), get a DHCP lease for an
IPv4 address, and be open for SSH access from the OpenBMC installer this
document is a part of as documented.
