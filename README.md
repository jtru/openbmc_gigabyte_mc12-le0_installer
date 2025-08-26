Gigabyte MC12-LE0 OpenBMC Installer
===================================

This projects is intended to help you convert your
[Gigabyte MC12-LE0](https://www.gigabyte.com/Enterprise/Server-Motherboard/MC12-LE0-rev-1x)
motherboard's baseboard management controller (BMC) firmware from proprietary
[AMI MegaRAC](https://www.ami.com/megarac/) to a Free Software/Open Source,
community-originated [OpenBMC](https://www.openbmc.org/) build.


Prerequisites
-------------

To convert your BMC firmware from MegaRAC to OpenBMC, you need to make sure you
have SSH access to the MegaRAC firmware running by default on your board's BMC.

Starting with Gigabyte's 12.61.39 release of their MegaRAC-based BMC firmware,
the SSH service has been removed from official firmware images. Some releases
before that version make the BMC admin jump through a number of hoops in the
web admin panel to enable SSH login for the pre-defined `sysadmin` account.

The recommended way to achieve SSH access to the MegaRAC BMC firmware for
flashing OpenBMC is to revert/downgrade it to release **12.61.17** (or any
earlier release), where the hardcoded SSH credentials of `sysadmin`:`superuser`
provide privileged access without any other required preparation.

Also, you need to make sure that **TCP port 8123 on your local machine** that
you are flashing OpenBMC from is **accessible for the MegaRAC BMC** to
establish incoming connections to. Since the MegaRAC userland is very stripped
down, all command invocation and transfer of artifacts between it your machine
has to happen via `ssh` and `curl`, which is why a local helper http server is
employed to push some data around during flashing.

Finally, to flash OpenBMC onto your board's BMC ROM, you will need to get a
compatible **image-bmc** file spun from an OpenBMC source tree that was
purpose-built for the Gigabyte MC12-LE0 and is published and maintained
separately from this installer.  At the time of writing, a source tree with the
required changes to support the motherboard can be found at the proper branch at
[github.com/jtru/openbmc](https://github.com/jtru/openbmc/tree/gigabyte-mc12-le0)


Usage / Installation
--------------------

Once you have acquired or built a compatible **image-bmc**, place it right next
to the `autoinstall_mc12le0_OpenBMC_via_ssh.sh` script in this repository's
root directory, find out one of the IP addresses (we're going to assume
**192.0.2.42** here for demonstration purposes) your MegaRAC BMC can be
reached via SSH, and invoke the aforementioned script like so:

    ./autoinstall_mc12le0_OpenBMC_via_ssh.sh 192.0.2.42

While executing, you will be prompted for the `sysadmin` account's password
twice. After the second prompt, you are invited to lean back and hope for the
following to happen successfully, as the script will attempt to:

1. Perform a number of sanity checks to make sure this has a chance of working
2. Spawn a temporary webserver on your local system, listening on TCP port 8123
3. Log in to the BMC system and place a script to perform the OpenBMC
   installation with it
4. Stop all services/processes on the BMC that are known to mess with the
   conversion
5. Take a backup of the currently running MegaRAC firmware as stored in the
   MC12-LE0's BMC ROM
6. Transfer that backup to the machine you have invoked the installer from
7. Upload the OpenBMC **image-bmc** ROM image to the BMC and check the file's
   integrity
8. Finally, erase the BMC's ROM and overwrite it with the **image-bmc**
   contents

Once done, the script will tell you to cut the BMC's power supply - at this
point, there's no way to shut off the BMC by any software means.

When powering up the next time, your board's BMC will boot into OpenBMC.


Reverting to stock BMC firmware from OpenBMC
--------------------------------------------

OpenBMC makes it very easy to flash a provided ROM image onto the BMC's flash
storage - all you need to ensure is that the proper file is placed at a
specific location in the OpenBMC file system, and after a reboot (which will
take a while, since flash erasure and writing takes some time), the BMC will
boot with the provided image content.

The example below illustrates the process, assuming **192.0.2.42** for the
OpenBMC-running BMC's IP address, and
**tmp-YYYY-MM-DD_ts_megarac_stock_image.rom.bak** as the filename produced
during the backup of the original BMC ROM content during OpenBMC installation:

    scp tmp-YYYY-MM-DD_ts_megarac_stock_image.rom.bak root@192.0.2.42:/run/initramfs/image-bmc
    ssh root@192.0.2.42 reboot

After a few minutes, your board's BMC should have rebooted into its MegaRAC
firmware again.


Recovery from bad flash attempts
--------------------------------

**WARNING**: If something bad happens during flashing (like a power outage or
loss of network connectivity), chances are you will soft-brick your BMC.

In that case, **recovery is very likely possible**, but might involve using
advanced software tools and/or some fiddling with the ICs on the board. If you
need help figuring out how to revive a dead BMC after a mishap during flashing,
you are welcome to **open an issue in this repo to ask for help**. That said,
the following disclaimer applies:


Disclaimer and Copyright
------------------------

Copyright (C) 2025  Johannes Truschnigg <johannes@truschnigg.info>

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option)
any later version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see <https://www.gnu.org/licenses/>.
