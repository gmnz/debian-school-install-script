#!/bin/bash

set -e

echo
echo -n "hostname: "
read hostname
echo -n "root passwd: "
read -s passwd
echo

dsize=$(fdisk -l | grep "Disk /dev/sd" | awk -F":" '{ print $2 }' | awk -F"GiB" '{ print $1 }' | awk -F"." '{ print $1 }' | sort -n | tail -n 1 | tr -d ' ')
tdisk=$(fdisk -l | grep "Disk /dev/sd" | grep $dsize | awk -F "Disk" '{ print $2 }' | awk -F":" '{ print $1 }' | tr -d ' ')
dsize=$(parted $tdisk -- p | head -n 2 | tail -n 1 | awk '{ print $3 }' | awk -F'GB' '{ print $1 }')

umount ${tdisk}? || echo "$tdisk unmounted"
echo

#(fdisk -l /dev/sda)=$(fdisk -l /dev/sda)
linpart=$(echo "$(fdisk -l $tdisk)" | grep -e Linux | grep -v "Linux swap" | awk '{ print $1 }')
#dsize=$(parted /dev/sda -s -- p | grep Disk | head -n 1 | awk '{ print $3 }' | awk -F'G' '{ print $1 }'| awk -F'.' '{ print $1 }')

#if there are more Linux partitions delete it all
#NOT TESTED YET
#if [ $(echo $linpart | wc -l) -gt 1 ]; then
#	parted /dev/sda -s -- mklabel msdos
#fi

#echo "!.. $linpart ..!"
#cat fsdjaflsdj

if [ -z "$linpart" ]; then
  	pend=$(parted $tdisk -s -- p | tail -n 2 | head -n 1 | awk '{ print $3 }' | awk -F. '{ print $1 }' | awk -F'G' ' { print $1 }')
	partype=$(parted $tdisk -- p | tail -n 2 | head -n 1 | awk '{ print $6 }')

	if [ $pend -eq $dsize]; then
		if [ $partype == "ntfs" ]; then
			winpart=$(fdisk -l $tdisk | tail -n 1 | awk '{ print $1 }')
			mount $winpart /mnt
			avail=$(df -h /mnt/ | tail -n 1 | awk '{ print $4 }' | awk -F"G" '{ print $1 }')
			umount $winpart
			if [ $avail -gt 54 ]; then
				yes | parted ---pretend-input-tty $tdisk resizepart ${winpart: -1} "$((pend-54))GB"
			fi
		fi

	fi

	#while ((echo $pend | grep -qv MB) && [ $pend != "End" ]); do
	#  if [ $((dsize - pend)) -lt 25 ]; then
	#    PARTN=$(echo "$(fdisk -l /dev/sda)" | grep sda | grep -v Disk | wc -l)
	#    echo "Deleting partition $PARTN..."
	#    parted /dev/sda -s -- rm $PARTN
	#    pend=$(parted /dev/sda -s -- p | tail -n 2 | head -n 1 | awk '{ print $3 }' | awk -F. '{ print $1 }' | awk -F'G' ' { print $1 }')
	#  fi
	#done
        #elif echo "$(fdisk -l /dev/sda)" | grep -q -e FAT -e NTFS; then
        #  pend=$(parted /dev/sda -s -- p | tail -n 2 | head -n 1 | awk '{ print $3 }' | awk -F. '{ print $1 }' | awk -F'G' ' { print $1 }')
        #  if [ $pend -eq $dsize ]; then
        #    linpart=$(echo "$(fdisk -l /dev/sda)" | tail -n 1 | awk '{ print $1 }')
        #    echo $linpart $pend
        #    #yes | parted -s /dev/sda resizepart ${linpart: -1} "$((pend-14))GB" 
        #    echo ", -20G" | sfdisk -N ${linpart: -1} /dev/sda
        #    pend=$(parted /dev/sda -s -- p | tail -n 2 | head -n 1 | awk '{ print $3 }' | awk -F. '{ print $1 }' | awk -F'G' ' { print $1 }')
        #  fi
        #  unit="GB"
        #  psize=$((pend+10))
        #else
        #  pend="1"
        #  unit="MB"
        #  psize=$((dsize-4))
        #  parted /dev/sda -s -- mklabel msdos
	#fi
	pend=$(parted /dev/sda -s -- p | tail -n 2 | head -n 1 | awk '{ print $3 }')
	#echo $pend
	if [ $pend == "End" ]; then
		pend=1
		unit=MiB
	fi

	psize=$((dsize-5))
        parted /dev/sda -s -- mkpart extended $pend$unit 100%
	if [ $pend == "1" ]; then
		pend=2
	fi
        parted /dev/sda -s -- mkpart logical ext4 $pend$unit $psize"GB"
        parted /dev/sda -s -- mkpart logical linux-swap $psize"GB" 100%
fi

swapp=$(echo "$(fdisk -l /dev/sda)" | grep "Linux swap" | awk '{ print $1 }')
linpart=$(echo "$(fdisk -l /dev/sda)" | grep -e Linux | grep -v "Linux swap" | awk '{ print $1 }')

yes | mkfs.ext4 $linpart
#starts even if it makes no sense
#mkfs.ext4 -F $linpart

if [ -n "$(swapon -s)" ]; then swapoff $swapp; fi
if [ -z "$swapp" ]; then
	yes | mkswap $swapp
	swapon $swapp
fi

mount $linpart /mnt

apt-get update
apt-get -yq install debootstrap
debootstrap stretch /mnt http://ftp.sk.debian.org/debian

mount --bind /dev /mnt/dev
mount -t proc none /mnt/proc
mount -t sysfs sys /mnt/sys

cp -r guest-session /mnt/etc/
mkdir /mnt/root/.ssh
cp authorized_keys /mnt/root/.ssh/authorized_keys
cp rc.local /mnt/etc/

chmod +x chroot.sh	
cp chroot.sh /mnt/chroot.sh 
cp scratch2-install.sh /mnt/scratch2-install.sh 
chroot /mnt ./chroot.sh $linpart $swapp $hostname $passwd

read -p "Press Enter to reboot"

umount /mnt/dev
umount /mnt/proc
umount /mnt/sys
umount /mnt

reboot
