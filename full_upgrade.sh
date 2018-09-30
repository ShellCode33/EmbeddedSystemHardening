#!/bin/bash

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 [REMOTE IP] [SSH PRIVATE KEY] [IMAGE PATH]"
    exit 1
fi

# We trap CTRL+C in order to prevent the dd from happening if we CTRL+C during the sdcard.img transfer. It will corrupt the pi otherwise.
trap ctrl_c INT

function ctrl_c() {
        exit 1
}

REMOTE_SDCARD_DEVICE="/dev/mmcblk0"
USER="root"
IP="$1"
SSH_KEY="$2"
IMAGE="$3"

check_version() {
    echo -n "The host is currently running the following version : "
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_KEY $USER"@"$IP 'cat /version' 2> /dev/null
}

check_version

echo "Transfering system image to remote system..."
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_KEY $IMAGE $USER"@"$IP:/tmp 2> /dev/null

echo "Writing system image on sdcard..."
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_KEY $USER"@"$IP '
dd if=/tmp/sdcard.img of='$REMOTE_SDCARD_DEVICE'
sync
/sbin/reboot
' 2> /dev/null

echo "Rebooting remote system, waiting for it to be up..."
while true; do ping -c1 $IP > /dev/null && break; done
sleep 5s  # wait for the SSH daemon to start
check_version
