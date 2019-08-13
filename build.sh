#/bin/bash

# GENQUEBEC_USER         = genquebec
# PORTFOLIO_DB_NAME_DEV  = user_dev
# PORTFOLIO_DB_NAME_PROD = alain_portf
# PORTFOLIO_HOME_DEV     = /home/user/domains/dev.portfolio.alainlauzon.com/public_html
# PORTFOLIO_HOME_PROD    = /home/user/domains/portfolio.alainlauzon.com/public_html
# PORTFOLIO_URL_DEV     = dev.portfolio.alainlauzon.com
# PORTFOLIO_URL_PROD     = portfolio.alainlauzon.com
# PORTFOLIO_USER         = user

DB_NAME_DEV=user_dev
DB_NAME_PROD=alain_portf
HOME_DEV=/home/user/domains/dev.portfolio.alainlauzon.com/public_html
HOME_PROD=/home/user/domains/portfolio.alainlauzon.com/public_html
URL_DEV=dev.portfolio.alainlauzon.com
URL_PROD=portfolio.alainlauzon.com
USER=user
DB_NAME_PROD=alain_portf
DB_USERNAME_PROD=alain_portf
DB_USERNAME_DEV=user_dev
DB_PASSWORD_PROD="xyz"
DB_PASSWORD_DEV=abc

rndstr=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo ''`

# Prepare temporary transfer directory
mkdir /tmp/$rndstr

# Cd to prod
cd $HOME_PROD

# Dump prod database
/usr/local/bin/drush --yes sql-dump > /tmp/${rndstr}/sql-dump-prod.sql

# Cd to dev
cd $HOME_DEV

# Drop all tables in the existing DEV database
echo "SELECT concat('DROP TABLE IF EXISTS ', table_name, ';')  FROM information_schema.tables  WHERE table_schema = 'user_dev';" | /usr/local/bin/drush --root=. --db-url=mysql://$DB_USERNAME_DEV:$DB_PASSWORD_DEV@localhost/$DB_NAME_DEV sql-cli | tail -n +2 | /usr/local/bin/drush --root=. --db-url=mysql://$DB_USERNAME_DEV:$DB_PASSWORD_DEV@localhost/$DB_NAME_DEV sql-cli

# Create settings.php file
rm -f $HOME_DEV/sites/default/settings.php
/usr/local/bin/drush --db-url=mysql://$DB_USERNAME_DEV:$DB_PASSWORD_DEV@localhost/$DB_NAME_DEV site-install -y
chown user:user $HOME_DEV/sites/default/settings.php

# Copy prod DB to dev DB
/usr/local/bin/drush --root=. --db-url=mysql://$DB_USERNAME_DEV:$DB_PASSWORD_DEV@localhost/$DB_NAME_DEV sql-cli < /tmp/${rndstr}/sql-dump-prod.sql

# Cleanup the temporary transfer directory
rm -Rf /tmp/${rndstr}

# Remove files in dev
rm -rf $HOME_DEV/sites/default/files

# Copy files and private directories from prod to dev
cp -rp $HOME_PROD/sites/default/files $HOME_DEV/sites/default/



# Clear cache dev
/usr/local/bin/drush cc all

