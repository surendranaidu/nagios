#!/bin/bash
apt-get update
apt-get install wget build-essential apache2 apache2-utils php5-gd libgd2-xpm-dev libapache2-mod-php5 postfix curl expect -y
useradd --system --home /usr/local/nagios -M nagios
groupadd --system nagcmd
usermod -a -G nagcmd nagios
usermod -a -G nagcmd www-data
cd /tmp
wget http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-4.0.8.tar.gz
wget http://nagios-plugins.org/download/nagios-plugins-2.0.3.tar.gz
tar xvzf nagios-4.0.8.tar.gz
tar xvzf nagios-plugins-2.0.3.tar.gz
cd nagios-4.0.8
mkdir -p /etc/apache2/conf-available
./configure --with-nagios-group=nagios --with-command-group=nagcmd --with-mail=/usr/sbin/sendmail --with-httpd_conf=/etc/apache2/conf-available
make all
make install
make install-init
make install-config
make install-commandmode
make install-webconf
cp -R contrib/eventhandlers/ /usr/local/nagios/libexec/
chown -R nagios:nagios /usr/local/nagios/libexec/eventhandlers
/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
ln -s /etc/init.d/nagios /etc/rcS.d/S99nagios
cd ..
cd nagios-plugins-2.0.3
./configure --with-nagios-user=nagios --with-nagios-group=nagios --enable-perl-modules --enable-extra-opts
make
make install
a2enmod cgi
cd
cat > nagios_passwd.sh << EOM
#!/usr/bin/expect -f
spawn htpasswd -c /usr/local/nagios/etc/htpasswd.users nagiosadmin
expect "New password: "
send "nagiosadmin\r"
expect "Re-type new password: "
send "nagiosadmin\r"
expect eof
EOM
chmod +x nagios_passwd.sh
./nagios_passwd.sh
if [ -e /etc/apache2/sites-enabled/000-default.conf ]
then
    sed -i '29s/^/Include\ conf-available\/nagios.conf\n/' /etc/apache2/sites-enabled/000-default.conf
    echo -ne "Include nagios conf file in apache cfg\n"
elif [ -e /etc/apache2/sites-enabled/000-default ]
then
    sed -i '29s/^/Include\ conf-available\/nagios.conf\n/' /etc/apache2/sites-enabled/000-default
    echo -ne "Include nagios conf file in apache cfg\n"
else
    echo "Neither of the config file exists.."
fi
service apache2 restart
service nagios restart
curl -u nagiosadmin:nagiosadmin http://localhost/nagios
cd $HOME
rm -rfv nagios_passwd.sh
