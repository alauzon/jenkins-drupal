#!/bin/sh
#================================================================
# HEADER
#================================================================
#% SYNOPSIS
#+    ${SCRIPT_NAME} [-h] USERNAME DB_NAME_PROD DB_USERNAME_PROD DB_PASSWORD_PROD HOME_PROD DB_NAME_DEV DB_USERNAME_DEV DB_PASSWORD_DEV HOME_DEV
#%
#% DESCRIPTION
#%    Copy a site from prod to another one like dev or test.
#%
#% OPTIONS
#%    -h, --help                    Print this help
#%
#% EXAMPLES
#%    ${SCRIPT_NAME} arg1 arg2
#
#================================================================
# END_OF_HEADER
#================================================================

#== usage functions ==#
SCRIPT_NAME=`basename $0`
usagefull() { scriptinfo ful ; }
scriptinfo() {
    headFilter="^#-"
    [[ "$1" = "usg" ]] && headFilter="^#+"
    [[ "$1" = "ful" ]] && headFilter="^#[%+]"
    [[ "$1" = "ver" ]] && headFilter="^#-"
    head -99 ${0} | grep -e "${headFilter}" | sed -e "s/${headFilter}//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g";
}

#============================
#  PARSE OPTIONS WITH GETOPTS
#============================

#== set short options ==#
SCRIPT_OPTS=':h-:'

#== set long options associated with short one ==#
typeset -A ARRAY_OPTS
ARRAY_OPTS=(
    [help]=h
)

#== parse options ==#
while getopts ':o:txhv-:' OPTION
do
    #== translate long options to short ==#
    if [[ "x$OPTION" == "x-" ]]
    then
        LONG_OPTION=$OPTARG
        LONG_OPTARG=$(echo $LONG_OPTION | grep "=" | cut -d'=' -f2)
        LONG_OPTIND=-1
        [[ "x$LONG_OPTARG" = "x" ]] && LONG_OPTIND=$OPTIND || LONG_OPTION=$(echo $OPTARG | cut -d'=' -f1)
        [[ $LONG_OPTIND -ne -1 ]] && eval LONG_OPTARG="\$$LONG_OPTIND"
        OPTION=${ARRAY_OPTS[$LONG_OPTION]}
        [[ "x$OPTION" = "x" ]] &&  OPTION="?" OPTARG="-$LONG_OPTION"

        if [[ $( echo "${SCRIPT_OPTS}" | grep -c "${OPTION}:" ) -eq 1 ]]
        then
            if [[ "x${LONG_OPTARG}" = "x" ]] || [[ "${LONG_OPTARG}" = -* ]]
            then
                OPTION=":" OPTARG="-$LONG_OPTION"
            else
                OPTARG="$LONG_OPTARG"
                if [[ $LONG_OPTIND -ne -1 ]]
                then
                    [[ $OPTIND -le $Optnum ]] && OPTIND=$(( $OPTIND+1 ))
                    shift $OPTIND
                    OPTIND=1
                fi
            fi
        fi
    fi

    #== options follow by another option instead of argument ==#
    if [[ "x${OPTION}" != "x:" ]] && [[ "x${OPTION}" != "x?" ]] && [[ "${OPTARG}" = -* ]]; then
        OPTARG="$OPTION" OPTION=":"
    fi

    #== manage options ==#
    case "$OPTION" in
        h ) usagefull
            exit 0
            ;;

        : ) error "${SCRIPT_NAME}: -$OPTARG: option requires an argument"
            flagOptErr=1
            ;;

        ? ) error "${SCRIPT_NAME}: -$OPTARG: unknown option"
            flagOptErr=1
            ;;
    esac
done
shift $((${OPTIND} - 1)) ## shift options

#============================
#  MAIN SCRIPT
#============================

if [ "$#" -ne 9 ]; then
  usagefull
  exit 1
fi

USERNAME=$1
DB_NAME_PROD=$2
DB_USERNAME_PROD=$3
DB_PASSWORD_PROD=$4
HOME_PROD=$5
DB_NAME_DEV=$6
DB_USERNAME_DEV=$7
DB_PASSWORD_DEV=$8
HOME_DEV=$9

#echo "USER = '$USER'"
#echo "DB_NAME_PROD = '$DB_NAME_PROD'"
#echo "DB_USERNAME_PROD = '$DB_USERNAME_PROD'"
#echo "DB_PASSWORD_PROD = '$DB_PASSWORD_PROD'"
#echo "HOME_PROD = '$HOME_PROD'"
#echo "DB_NAME_DEV = '$DB_NAME_DEV'"
#echo "DB_USERNAME_DEV = '$DB_USERNAME_DEV'"
#echo "DB_PASSWORD_DEV = '$DB_PASSWORD_DEV'"
#echo "HOME_DEV = '$HOME_DEV'"

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
# @todo Is there a better way to do that?
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