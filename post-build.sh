#!/bin/sh

set -u
set -e

# Add a console on tty1
if [ -e ${TARGET_DIR}/etc/inittab ]; then
    grep -qE '^tty1::' ${TARGET_DIR}/etc/inittab || \
	sed -i '/GENERIC_SERIAL/a\
tty1::respawn:/sbin/getty -L  tty1 0 vt100 # HDMI console' ${TARGET_DIR}/etc/inittab
fi

if [ -e ${TARGET_DIR}/version ]; then
    CURRENT_VERSION="$(cat ${TARGET_DIR}/etc/build-version)"
    NEW_VERSION=$((CURRENT_VERSION+1))
    echo ${NEW_VERSION} > "${TARGET_DIR}/version"
else
    echo 1 > "${TARGET_DIR}/version"
fi
