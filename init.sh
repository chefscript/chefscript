#!/bin/bash
echo "Start initial setting."

echo "MySQL initial setting..."
mysql -e 'DROP DATABASE IF EXISTS db_chefscript;'
mysql -e 'CREATE DATABASE IF NOT EXISTS db_chefscript;'
mysql -e 'GRANT ALL PRIVILEGES ON db_chefscript.* TO "csuser"@"localhost" IDENTIFIED BY "cspass";'
mysql -e 'FLUSH PRIVILEGES;'

echo "Change mode to 755 client program..."
chmod 755 `dirname $0`/client/bin/cscli

echo "Add PATH env for client program..."
PATH=$PATH:`dirname $0`/client/bin
export PATH

echo "Install required packages"
yum -y install mysql-server ruby bundle gem

echo "Run [bundle install]..."
cd `dirname $0`/src
bundle install

echo "Done!"
