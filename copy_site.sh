#!/bin/sh
#================================================================
# HEADER
#================================================================
#% SYNOPSIS
#+    ${SCRIPT_NAME} [-h] BRANCH SITE SOURCE_ENV TARGET_ENV
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
echo ${SCRIPT_NAME} $@
printenv

set -e

#== usage functions ==#
SCRIPT_NAME=`basename $0`
usagefull() { scriptinfo full ; }
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

if [ "$#" -ne 4 ]; then
  usagefull
  exit 1
fi

set -x

DRUPAL_REPO_URL="git@bitbucket.org:alainlauzoncom/portfolio.git"
BRANCH=${1}
SITE=${2}
SOURCE_ENV=${3}
TARGET_ENV=${4}

USERNAME_VARNAME="${SITE}_USERNAME"
USERNAME=${!USERNAME_VARNAME}

SOURCE_HOME_VARNAME="${SITE}_${SOURCE_ENV}_HOME"
SOURCE_HOME=$${!SOURCE_HOME_VARNAME}

SOURCE_DB_NAME_VARNAME=${SITE}_${SOURCE_ENV}_DB_NAME
SOURCE_DB_NAME=${!SOURCE_DB_NAME_VARNAME}

SOURCE_DB_HOST_VARNAME=${SITE}_${SOURCE_ENV}_DB_HOST
SOURCE_DB_HOST=${!SOURCE_DB_HOST_VARNAME}

SOURCE_DB_PORT_VARNAME=${SITE}_${SOURCE_ENV}_DB_PORT
SOURCE_DB_PORT=${!SOURCE_DB_PORT_VARNAME}

SOURCE_DB_USERNAME_VARNAME=${SITE}_${SOURCE_ENV}_DB_USERNAME
SOURCE_DB_USERNAME=${!SOURCE_DB_USERNAME_VARNAME}

SOURCE_DB_PASSWORD_VARNAME=${SITE}_${SOURCE_ENV}_DB_PASSWORD
SOURCE_DB_PASSWORD=${!SOURCE_DB_PASSWORD_VARNAME}

TARGET_HOME_VARNAME=${SITE}_${TARGET_ENV}_HOME
TARGET_HOME=${!TARGET_HOME_VARNAME}

TARGET_DB_NAME_VARNAME=${SITE}_${TARGET_ENV}_DB_NAME
TARGET_DB_NAME=${!TARGET_DB_NAME_VARNAME}

TARGET_DB_HOST_VARNAME=${SITE}_${TARGET_ENV}_DB_HOST
TARGET_DB_HOST=${!TARGET_DB_HOST_VARNAME}

TARGET_DB_PORT_VARNAME=${SITE}_${TARGET_ENV}_DB_PORT
TARGET_DB_PORT=${!TARGET_DB_PORT_VARNAME}

TARGET_DB_USERNAME_VARNAME=${SITE}_${TARGET_ENV}_DB_USERNAME
TARGET_DB_USERNAME=${!TARGET_DB_USERNAME_VARNAME}

TARGET_DB_PASSWORD_VARNAME=${SITE}_${TARGET_ENV}_DB_PASSWORD
TARGET_DB_PASSWORD=${!TARGET_DB_PASSWORD_VARNAME}


rndstr=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo ''`

# Prepare temporary transfer directory
mkdir /tmp/$rndstr

# Cd to prod
cd $SOURCE_HOME/public_html

# Dump prod database
/usr/local/bin/drush --yes sql-dump > /tmp/${rndstr}/sql-dump-prod.sql

# Cd to dev
cd $TARGET_HOME
rm -Rf * .g* .h* .l*

# Get code from git repo
git clone --single-branch --branch $BRANCH $DRUPAL_REPO_URL .
chown -R $USERNAME:$USERNAME .

# CD to public_html
cd public_html

# Drop all tables in the existing DEV database
# The dev DB must already exists
# @todo Is there a better way to do that?
echo "SELECT concat('DROP TABLE IF EXISTS ', table_name, ';')  FROM information_schema.tables  WHERE table_schema = 'user_dev';"\
  | /usr/local/bin/drush --root=. --db-url=mysql://$TARGET_DB_USERNAME:$TARGET_DB_PASSWORD@localhost/$TARGET_DB_NAME sql-cli\
  | tail -n +2\
  | /usr/local/bin/drush --root=. --db-url=mysql://$TARGET_DB_USERNAME:$TARGET_DB_PASSWORD@localhost/$TARGET_DB_NAME sql-cli

# Create settings.php file
rm -f sites/default/settings.php
/usr/local/bin/drush site-install --force --db-url=mysql://$TARGET_DB_USERNAME:$TARGET_DB_PASSWORD@localhost/$TARGET_DB_NAME -y
chown $USERNAME:$USERNAME sites/default/settings.php

# Copy prod DB to dev DB
/usr/local/bin/drush --root=. --db-url=mysql://$TARGET_DB_USERNAME:$TARGET_DB_PASSWORD@localhost/$TARGET_DB_NAME sql-cli < /tmp/${rndstr}/sql-dump-prod.sql

# Cleanup the temporary transfer directory
rm -Rf /tmp/${rndstr}

# Remove files in dev
chmod +w sites/default sites/default/files
rm -rf sites/default/files

# Copy files and private directories from prod to dev
cp -rp $SOURCE_HOME/public_html/sites/default/files sites/default/
chmod -w sites/default

# Clear cache dev
/usr/local/bin/drush cc all
