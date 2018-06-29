#!/bin/bash

echo test

set -e

echo
echo -n "HOSTNAME: "
read HOSTNAME
echo -n "root passwd: "
read -s PASSWD

DTAB=$(fdisk -l /dev/sda)
PARTN=$(echo "$DTAB" | grep -e Linux | grep -v "Linux swap" | awk '{ print $1 }')
DSIZE=$(parted /dev/sda -s -- p | grep Disk | head -n 1 | awk '{ print $3 }' | awk -F'G' '{ print $1 }')

if [ -z $PARTN ]; then
        if [ $(($(echo $DTAB | grep sda | wc -l) - 1)) -gt 3 ]; then
          parted /dev/sda -s -- rm 4
          PEND=$(parted /dev/sda -s -- p | tail -n 2 | head -n 1 | awk '{ print $3 }' | awk -F. '{ print $1 }' | awk -F'G' ' { print $1 }')
        elif fdisk -l /dev/sda | grep -q -e FAT -e NTFS; then
          PEND=$(parted /dev/sda -s -- p | tail -n 2 | head -n 1 | awk '{ print $3 }' | awk -F. '{ print $1 }' | awk -F'G' ' { print $1 }')
          if [ $PEND -eq $DSIZE ]; then
            PARTN=$(echo "$DTAB" | tail -n 1 | awk '{ print $1 }')
            echo $PARTN $PEND
            #yes | parted -s /dev/sda resizepart ${PARTN: -1} "$((PEND-14))GB" 
            echo ", -14G" | sfdisk -N ${PARTN: -1} /dev/sda
            PEND=$(parted /dev/sda -s -- p | tail -n 2 | head -n 1 | awk '{ print $3 }' | awk -F. '{ print $1 }' | awk -F'G' ' { print $1 }')
          fi
          UNIT="GB"
          PSIZE=$((PEND+10))
        else
          PEND="1"
          UNIT="MB"
          PSIZE=$((DSIZE-4))
          parted /dev/sda -s -- mklabel msdos
	fi
        parted /dev/sda -s -- mkpart extended $PEND$UNIT 100%
        parted /dev/sda -s -- mkpart logical ext4 $PEND$UNIT $PSIZE"GB"
        parted /dev/sda -s -- mkpart logical linux-swap $PSIZE"GB" 100%
fi

SWAPP=$(echo "$DTAB" | grep "Linux swap" | awk '{ print $1 }')
PARTN=$(echo "$DTAB" | grep -e Linux | grep -v "Linux swap" | awk '{ print $1 }')

yes | mkfs.ext4 $PARTN
#starts even if it makes no sense
#mkfs.ext4 -F $PARTN

if [ -n "$(swapon -s)" ]; then swapoff $SWAPP; fi
yes | mkswap $SWAPP
swapon $SWAPP

mount $PARTN /mnt

apt-get update
apt-get -yq install debootstrap
debootstrap stretch /mnt http://ftp.sk.debian.org/debian

mount --bind /dev /mnt/dev
mount -t proc none /mnt/proc
mount -t sysfs sys /mnt/sys

cp chroot.sh /mnt/chroot.sh 
chroot /mnt ./chroot.sh $PARTN $SWAPP $HOSTNAME $PASSWD

cp -r guest-session /mnt/etc/
mkdir /mnt/root/.ssh
cp authorized_keys /mnt/root/.ssh/authorized_keys
cp rc.local /mnt/etc/

read -p "Press Enter to reboot"

umount /mnt/dev
umount /mnt/proc
umount /mnt/sys
umount /mnt

reboot
