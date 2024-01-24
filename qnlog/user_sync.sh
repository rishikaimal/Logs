#!/bin/bash

PWD=$(pwd)

directory="$PWD/../rootfs/common/etc/sv/qnlog"

if [ -d "$directory" ]; then
    echo "Service "qnlog" already Installed."
else
    mkdir ../rootfs/common/etc/sv/qnlog
    cp -r qnlog/* ../rootfs/common/etc/sv/qnlog
    cd ../rootfs/common/etc/runit/runsvdir/default/
    ln -s /etc/sv/qnlog qnlog
    echo "Service Logs installed successfully"
fi
