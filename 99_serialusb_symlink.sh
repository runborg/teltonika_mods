#!/bin/bash
#
# Automatically assign symlinks for usb-serial converters
#
# On the Teltonika RUTX11 (only tested on this) internal usb devices 
# are enumerated after devices on the external usb port.
# This means that USB Serial Adapters will enumerate differently
# if they are present on bootup than if they are plugged into the device
# after the boot process is finished.
# 
# This script creates symlinks for each ttyUSB device on the external
# usb port under /dev/usbSerial#, as there are only one external usb
# port whis will enumerate the same each time as long as as external hubs
# are not used. 


exec 1>>/root/usbenv 2>&1  # for debugging, redirect stdout/stderr to file

# Skipping bus and hub devices
[ "$DEVTYPE" = usb_device -a "${DEVICENAME%%:*}" = "$DEVICENAME" ] || exit 0

# TODO:need a rewrite to support different port addresses on other devices
# We are only interested in devices on the external port
if ! expr "${DEVICENAME}" : "1-1\.3[.:$]" > /dev/null; then
  #echo "Device ${DEVICENAME} not on external usb port, ignoring"
  exit 0
fi

if [ "$ACTION" = bind ]; then
  echo "Adding device: ${DEVICE_NAME} " \
       "action='$ACTION' " \
       "ttyName=$(ls /sys/${DEVPATH} | grep tty) " \
       "devicename='$DEVICENAME' " \
       "devpath='$DEVPATH' " \
       "product='$PRODUCT' " \
       "type='$TYPE' " \
       "interface='$INTERFACE'"

  TTY_NAME=$(ls /sys/${DEVPATH} | grep tty)
  # Ignore devices without any attached tty device
  [ -z "${TTY_NAME}" ] || exit 0
    
  i=1  
  while [ $i -lt 100 ]; do
    newName="/dev/usbSerial${i}"
    if [ ! -c "${newName}" ]; then
      echo "Creating Symlink for ${TTY_NAME} ${newName}"
      ln -s ${TTY_NAME} ${newName}
      break
    fi
    
    i=$((i+1)) # increment i
  done
  
elif [ "$ACTION" = unbind ]; then
  # Remove usb device
  # On device removal the tty name is not present any more, loop trough
  # all serial devices and remove symlinks pointing to non-existing
  # devices
  logger -t hotplug "Device removed ${DEVICE_NAME} ${DEVICENAME} ${DEVPATH}"
  for f in /dev/usbSerial*; do
    if [ ! -c ${f} ]; then  
      sym=$(readlink -f ${f})

      if [ ! -c ${sym} ]; then
        logger -t hotplug  "Symlink ${f} points to a not-existing tty device ${sym}, removing"
        rm -rf ${sym}
      fi
    fi
  done
fi
