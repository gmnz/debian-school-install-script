#!/bin/bash

cat >/etc/fstab <<EOL
#<device>			<dir>		<type>		<options>		<dump>	<fsck>
$1				/		ext4		defaults		0	1
$2				none		swap		defaults		0	0
EOL

echo $3 > /etc/hostname
ln -sf /usr/share/zoneinfo/Europe/Bratislava /etc/localtime
echo "root:$4"|chpasswd

apt-get -yq install locales
sed -i -- 's/# sk_SK.UTF-8 UTF-8/sk_SK.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen
echo LANG=sk_SK.UTF-8 > /etc/locale.conf
export LANG=sk_SK.UTF-8 

export DEBIAN_FRONTEND=noninteractive
apt-get -yq install linux-image-amd64 grub-pc
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

apt-get -yq install task-lxde-desktop vim openssh-server git codeblocks codeblocks-contrib g++ unattended-upgrades

sed -i -- 's/\/\/Unattended-Upgrade::Mail "root"/Unattended-Upgrade::Mail "root"/g' /etc/apt/apt.conf.d/50unattended-upgrades

cd /etc/lightdm/
git clone https://gist.github.com/pixline/6981710 
cd 6981710
mv guest-account.sh ../
cd ..
rm -rf 6981710
chmod +x /etc/lightdm/guest-account.sh
sed -i -- 's/#guest-account-script=guest-account/guest-account-script=\/etc\/lightdm\/guest-account.sh/g' /etc/lightdm/lightdm.conf
sed -i -- 's/#greeter-hide-users=false/greeter-hide-users=true/g' /etc/lightdm/lightdm.conf
sed -i -- 's/#greeter-allow-guest=true/greeter-allow-guest=true/g' /etc/lightdm/lightdm.conf
sed -i -- 's/#allow-guest=true/allow-guest=true/g' /etc/lightdm/lightdm.conf
sed -i -- 's/#autologin-guest=false/autologin-guest=true/g' /etc/lightdm/lightdm.conf

sed -i -- 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i -- 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
