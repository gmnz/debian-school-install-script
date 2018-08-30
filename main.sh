#!/bin/bash

set -e

echo
echo -n "HOSTNAME: "
read HOSTNAME
echo -n "root passwd: "
read -s PASSWD
echo

umount /dev/sda? || echo "sda unmounted"
echo

#(fdisk -l /dev/sda)=$(fdisk -l /dev/sda)
LINPART=$(echo "$(fdisk -l /dev/sda)" | grep -e Linux | grep -v "Linux swap" | awk '{ print $1 }')
DSIZE=$(parted /dev/sda -s -- p | grep Disk | head -n 1 | awk '{ print $3 }' | awk -F'G' '{ print $1 }'| awk -F'.' '{ print $1 }')

if [ -z $LINPART ]; then
  	PEND=$(parted /dev/sda -s -- p | tail -n 2 | head -n 1 | awk '{ print $3 }' | awk -F. '{ print $1 }' | awk -F'G' ' { print $1 }')
	while (echo $PEND | grep -v MB); do
	  if [ $((DSIZE - PEND)) -lt 25 ]; then
	    PARTN=$(echo "$(fdisk -l /dev/sda)" | grep sda | grep -v Disk | wc -l)
	    echo "Deleting partition $PARTN..."
	    parted /dev/sda -s -- rm $PARTN
	    PEND=$(parted /dev/sda -s -- p | tail -n 2 | head -n 1 | awk '{ print $3 }' | awk -F. '{ print $1 }' | awk -F'G' ' { print $1 }')
	  fi
	done
        #elif echo "$(fdisk -l /dev/sda)" | grep -q -e FAT -e NTFS; then
        #  PEND=$(parted /dev/sda -s -- p | tail -n 2 | head -n 1 | awk '{ print $3 }' | awk -F. '{ print $1 }' | awk -F'G' ' { print $1 }')
        #  if [ $PEND -eq $DSIZE ]; then
        #    LINPART=$(echo "$(fdisk -l /dev/sda)" | tail -n 1 | awk '{ print $1 }')
        #    echo $LINPART $PEND
        #    #yes | parted -s /dev/sda resizepart ${LINPART: -1} "$((PEND-14))GB" 
        #    echo ", -20G" | sfdisk -N ${LINPART: -1} /dev/sda
        #    PEND=$(parted /dev/sda -s -- p | tail -n 2 | head -n 1 | awk '{ print $3 }' | awk -F. '{ print $1 }' | awk -F'G' ' { print $1 }')
        #  fi
        #  UNIT="GB"
        #  PSIZE=$((PEND+10))
        #else
        #  PEND="1"
        #  UNIT="MB"
        #  PSIZE=$((DSIZE-4))
        #  parted /dev/sda -s -- mklabel msdos
	#fi
	PEND=$(parted /dev/sda -s -- p | tail -n 2 | head -n 1 | awk '{ print $3 }')
	echo $PEND
	PSIZE=$((DSIZE-5))
        parted /dev/sda -s -- mkpart extended $PEND$UNIT 100%
        parted /dev/sda -s -- mkpart logical ext4 $PEND$UNIT $PSIZE"GB"
        parted /dev/sda -s -- mkpart logical linux-swap $PSIZE"GB" 100%
fi

SWAPP=$(echo "$(fdisk -l /dev/sda)" | grep "Linux swap" | awk '{ print $1 }')
LINPART=$(echo "$(fdisk -l /dev/sda)" | grep -e Linux | grep -v "Linux swap" | awk '{ print $1 }')

yes | mkfs.ext4 $LINPART
#starts even if it makes no sense
#mkfs.ext4 -F $LINPART

if [ -n "$(swapon -s)" ]; then swapoff $SWAPP; fi
yes | mkswap $SWAPP
swapon $SWAPP

mount $LINPART /mnt

apt-get update
apt-get -yq install debootstrap
debootstrap stretch /mnt http://ftp.sk.debian.org/debian

mount --bind /dev /mnt/dev
mount -t proc none /mnt/proc
mount -t sysfs sys /mnt/sys

chmod +x chroot.sh	
cp chroot.sh /mnt/chroot.sh 
cp scratch2-install.sh /mnt/scratch2-install.sh 
chroot /mnt ./chroot.sh $LINPART $SWAPP $HOSTNAME $PASSWD

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
