#!/bin/bash

PWD=$(pwd)

directory="$PWD/../rootfs/common/etc/sv/logs"

if [ -d "$directory" ]; then
    echo "Service "Logs" already Installed."
else
    mkdir ../rootfs/common/etc/sv/logs
    cp -r logs/* ../rootfs/common/etc/sv/logs
    cd ../rootfs/common/etc/runit/runsvdir/default/
    ln -s /etc/sv/logs logs
    echo "Service Logs installed successfully"
fi
