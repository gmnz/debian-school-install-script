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


cat >> /etc/grub.d/00_header <<EOL

cat << EOF
set superusers="root"
password_pbkdf2 root grub.pbkdf2.sha512.10000.CAEE0B6E03B95C1CA57F923BEAEA056EB9737A947D2C7FC13FB86E396F6F9CFA444EA31E8DE6AA00321CC0EC998F7E9D39D5B193804D0F047822B0D99F7FAE5D.635FF8AFF5EF6BF4804053AD361843DD526559346271EB109B8E76F5FB5DA40A3C00347027110F0D840D74EE0BE366D8C0902E795F6858E6B3A95FB1EC813DAF
export superusers
EOF
EOL

sed -i "s/--class gnu --class os/--class gnu --class os --unrestricted/g" /etc/grub.d/10_linux
update-grub

apt-get -yq install task-lxde-desktop vim openssh-server x11vnc git codeblocks codeblocks-contrib g++ unattended-upgrades geany geany-plugins gedit gedit-plugins bluefish bluefish-plugins

./scratch2-install.sh

sed -i -- 's/\/\/Unattended-Upgrade::Mail "root"/Unattended-Upgrade::Mail "root"/g' /etc/apt/apt.conf.d/50unattended-upgrades

chmod +x /etc/rc.local
chmod +x /etc/guest-session/skel/.bin/*

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

echo "set -o vi" >> /root/.bashrc

echo "LANGUAGE=sk_SK.UTF-8
LANG=sk_SK.UTF-8
LC_ALL=sk_SK.UTF-8" >> /etc/default/locale

echo "virtualc"

wget "https://sites.google.com/site/virtualcide/virtualc_1.8.0_i386.deb?attredirects=0" -O virtualc.deb
dpkg --add-architecture i386
apt-get -yq install gdebi
gdebi --n virtualc.deb
rm virtualc.deb

echo "end of chroot"
