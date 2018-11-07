#!/bin/bash
#set -x

# NOTE : When using scp/ssh we do not check the identity of the server because it will change everytime we reflash the raspberry pi. It's not an issue because this script is only to be used in a dev environment. It would be a huge security hole to create a permanent identity key on the host, so it's better this way.

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 [REMOTE IP] [SSH PRIVATE KEY] [IMAGE PATH]"
    exit 1
fi

REMOTE_SDCARD_DEVICE="/dev/mmcblk0"
PART_NUM="p1"
USER="root"
IP="$1"
SSH_KEY="$2"
IMAGE="$3"
FILE_TYPE="$(file "$IMAGE" | cut -d' ' -f2-)"

# If the file is a zImage
if echo "$FILE_TYPE" | grep zImage &> /dev/null
then
    echo "Upgrading zImage only..."
    upgrade_command="mkdir /tmp/mnt; mount ${REMOTE_SDCARD_DEVICE}${PART_NUM} /tmp/mnt; mv /tmp/zImage /tmp/mnt/"

# If the file is a system image
elif echo "$FILE_TYPE" | grep boot &> /dev/null
then
    echo "Upgrading the whole image..."
    upgrade_command="dd if=/tmp/sdcard.img of='${REMOTE_SDCARD_DEVICE}'"

else
    echo "Unknown file type. Please provide a system image or a zImage."
    exit 42
fi

function ctrl_c() {
    echo -e "\nUpgrade cancelled."
    exit 1
}

# We trap CTRL+C in order to prevent the dd from happening if we CTRL+C during the sdcard.img transfer. It will corrupt the pi otherwise.
trap ctrl_c INT

check_version() {
    echo -n "The host is currently running the following version : "
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_KEY $USER"@"$IP 'cat /etc/build-id' 2> /dev/null
}

check_version

echo "Transfering system image to remote system..."
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_KEY $IMAGE $USER"@"$IP:/tmp 2> /dev/null

echo "Writing to sdcard..."
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_KEY $USER"@"$IP "${upgrade_command}; sync; /sbin/reboot;" 2> /dev/null

echo "Rebooting remote system, waiting for it to be up..."

# wait for the host to init reboot
sleep 5s

# wait for the host to be up
while true; do ping -c1 $IP > /dev/null && break; done

check_version
