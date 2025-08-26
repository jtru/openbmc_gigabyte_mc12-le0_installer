#!/bin/sh
#
# Convenience script to install OpenBMC firmware images on the Gigabyte
# MC12-LE0 AM4 BMC firmware ROM via SSH; no special flashing hardware required.
#
# Copyright (C) 2025  Johannes Truschnigg <johannes@truschnigg.info>
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>.

if [ -z $1 ] || [ $1 = -h ] || [ $1 = --help ]
then
    printf 'Usage: %s MEGARAC_IPADDR\n' "${0##*/}"
    exit 0
fi

missing_progs=''
for prog in ssh-keyscan ssh python3 mktemp openssl sed date wc grep
do
  type -p "${prog}" >/dev/null || missing_progs="${missing_progs} ${prog}"
done

if [ -n "${missing_progs}" ]
then
    printf 'FATAL: program not found in $PATH:%s\n' "${missing_progs}" >&2
    exit 1
fi

if ! ssh-keyscan -T 1 -- "${1}" | grep -qF 'SSH-2.0-OpenSSH_7.9p1' &>/dev/null
then
    echo "FATAL: SSH banner check for host ${1:-NO HOST PROVIDED} failed" >&2
    exit 1
fi

if ! [ "$(wc -c < ./image-bmc)" -eq 67108864 ]
then
    echo "FATAL: ./image-bmc is of inadequate size" >&2
    exit 1
fi

if ! grep -Faq 'mc12-le0-OpenBMC' image-bmc 2>/dev/null
then
    echo "FATAL: ./image-bmc is not a valid Gigabyte MC12-LE0 OpenBMC ROM image" >&2
    exit 1
else
    imgmd5="$(openssl md5 ./image-bmc)"
    imgmd5="${imgmd5##* }"
fi

tmpwebsrv="$(mktemp tmp-$(date +%F)-WebServer.XXXXXXX)"
cat <<EOPYTHON > "${tmpwebsrv}"
import time
import os
import http.server

class PUTRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_PUT(self):
        t = 'tmp-' + time.strftime('%F_%s') + '_' + os.path.basename(self.translate_path(self.path))
        l = max(int(self.headers['Content-Length']), 1)
        with open(t, 'wb') as f:
            f.write(self.rfile.read(l))
        self.send_response(204)
        self.end_headers()

if __name__ == '__main__':
    http.server.test(HandlerClass=PUTRequestHandler, port=8123)
EOPYTHON

httplogfile="$(mktemp tmp-$(date +%F)-WebServer-Log.XXXXXXX)"
echo "Starting temporary local webserver on TCP port 8123 (logfile @ ${httplogfile} ) ..." >&2
python3 "${tmpwebsrv}" &> "${httplogfile}" &
httppid="${!}"
trap 'echo Terminating webserver... >&2; kill ${httppid}; rm -f "${tmpwebsrv}" "${tmpscript}"' EXIT
sleep 1

if ! kill -0 "${httppid}"
then
    echo "FATAL: temporary webserver terminated prematurely" >&2
    exit 1
fi

tmpscript="$(mktemp tmp-$(date +%F)-OpenBMC-flash.XXXXXXX)"
sed -n '1,/^#===ENDOFLOCALSCRIPT/{d};p' "${0}" > "${tmpscript}"

echo "Transferring generated shellscript to MegaRAC BMC host..." >&2
if ! ssh -oPreferredAuthentications=password -oPasswordAuthentication=yes \
  -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null \
  "sysadmin@${1}" -- 'curl --fail -o "/run/'"${tmpscript}"'" http://"${SSH_CONNECTION%% *}:8123/"'"${tmpscript}"
then
    echo "FATAL: failed to transfer generated shellscript to MegaRAC host" >&2
    exit 1
fi

echo "Executing remote shellscript..." >&2
ssh -t -oServerAliveInterval=1 -oServerAliveCountMax=1200 \
  -oPreferredAuthentications=password -oPasswordAuthentication=yes \
  -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null \
  "sysadmin@${1}" -- sh /run/"${tmpscript}" "${imgmd5}"

exit 0


#===ENDOFLOCALSCRIPT
#!/bin/sh
# THE BELOW PORTION OF THIS SCRIPT WILL EXECUTE ON THE MC12-LE0 MegaRAC BMC
MD5_EXPECTED="${1}"
SRV="${SSH_CONNECTION%% *}"

rm -f /run/image-bmc

echo "Fetching OpenBMC ROM image and running pre-flight checks ..." >&2
cd /run
if ! curl --fail -O "http://${SRV}:8123/image-bmc"
then
    echo "FATAL: image-bmc could not be downloaded from ${SRV}" >&2
    exit 1
fi

if ! printf '%s  /run/image-bmc\n' "${MD5_EXPECTED}" | md5sum -c
then
    echo "FATAL: expected md5sum does not match /run/image-bmc" >&2
    exit 1
fi

echo "Pre-flight checks passed; preparing host ..." >&2

echo "Adjusting console loglevel ..." >&2
echo "OpenBMC flashing in progress... see you on the other side" > /dev/kmsg
sysctl -w "kernel.printk=1 4 1 3"

echo "Stopping/killing userspace services (errors expected) ..." >&2
/etc/init.d/cron stop
killall processmanager
killall IPMIMain; sleep 3; killall -9 IPMIMain
killall compmanager
killall hdserver
killall cdserver
ps -ef | awk '/[s]yncconf/{print $2}' | xargs kill
find /proc/[0-9]*/fd/ -type l | xargs ls -ld 2>/dev/null | awk '{if($NF ~ /\/conf/){split($(NF-2),a,/\//); print a[3]}}' | xargs kill

echo "Unmounting all NOR-backed filesystems ..." >&2
sync; umount /dev/mtdblock* 2>/dev/null

echo "Dumping stock FW ROM backup into /run/stock_backup_dump ..."
sync; mtd_debug read /dev/mtd0 0 67108864 /run/stock_backup_dump
md5sum /run/stock_backup_dump > /run/stock_backup_dump.md5sum
echo "Uploading /run/stock_backup_dump to ${SRV}:8123 ..."
if ! curl "http://${SRV}:8123/megarac_stock_image.rom.bak" --fail --upload-file '/run/stock_backup_dump'
then
    echo "FATAL: could not upload /run/stock_backup_dump to ${SRV} - bailing out; please reboot BMC and retry" >&2
    exit 1
else
    curl "http://${SRV}:8123/megarac_stock_image.rom.bak.md5sum" --fail --upload-file '/run/stock_backup_dump.md5sum'
    rm /run/stock_backup_dump
fi


echo "Will flash OpenBMC in 10 seconds - LAST CHANCE TO ABORT via ^C ..." >&2
sleep 10

clear
echo ""
echo "" >&2
echo 'Flashing OpenBMC, please STAND BY and REMAIN CALM for a few minutes... ;)' >&2

sleep 1

set -x

trap ':' SIGINT SIGHUP

mtd_debug erase /dev/mtd0 0 67108864 \
&& mtd_debug write /dev/mtd0 0 67108864 /run/image-bmc \
&& set +x \
&& i=0 && while true
          do
          let 'i=++i % 16'
	  printf "%${i}s== FLASH OK - PLEASE CUT *BMC* POWER NOW ==\n" '' >&2
	  echo "OpenBMC install complete - CUT BMC POWER" > /dev/console
	  sleep 1
	  done \
|| echo 'FATAL: FLASH FAILED - EXTERNAL NOR FLASH RECOVERY NEEDED' >&2
