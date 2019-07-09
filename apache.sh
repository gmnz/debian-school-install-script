apt update
export DEBIAN_FRONTEND=noninteractive
apt -yq install apache2 php7.0 mariadb-client mariadb-server php-mbstring php-gettext phpmyadmin
a2enmod userdir
adduser --disabled-password --gecos "" server
sed -i 's/php_admin_flag engine Off/php_admin_flag engine On/g' /etc/apache2/mods-available/php7.0.conf 
phpenmod mbstring
grep "Include /etc/phpmyadmin/apache.conf" /etc/apache2/apache2.conf || echo "Include /etc/phpmyadmin/apache.conf" >> /etc/apache2/apache2.conf 
runuser -l server -c 'mkdir ~/public_html'
runuser -l server -c 'chmod o+x ~'
runuser -l server -c 'chmod o+x ~/public_html/'
runuser -l server -c 'chmod -R o+r ~/public_html/'
exit
