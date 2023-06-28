#!/bin/bash

forcestatic="x"
forcedynamic="x"
forceversion=""

HELP="

Installs the SHEBANQ app.

---------------------------------------------------------------------------------
Initialize databases
---------------------------------------------------------------------------------

1. all static databases, corresponding to versions of the Hebrew Bible
2. all dynamic databases, containing user contributed content

Previous dynamic content is looked up from the _local directory,
which is not pushed to GitHub.
Blank dynamic content will be provided if there is no previous dynamic content.

The operation is incremental: it detects what is already present, and fills in the blanks.

However, you can force new imports with flags.


USAGE

Run it in the maintenance directory

./install.sh [flag,...]

FLAGS

force-static
    Import static databases even if they already exist

force-version version
    Import static databases for version even if they already exist

force-dynamic
    Import  dynamic databases even if they already exist
"

while [ ! -z "$1" ]; do
    if [[ "$1" == "force-static" ]]; then
        forcestatic="v"
        shift
    elif [[ "$1" == "force-dynamic" ]]; then
        forcedynamic="v"
        shift
    elif [[ "$1" == "force-version" ]]; then
        shift
        forceversion="$1"
        shift
    else
        echo "unrecognized argument '$1'"
        good="x"
        shift
    fi
done

#----------------------------------------------------------------------------------
# Initialize databases
#----------------------------------------------------------------------------------

ocdir=/opt/cfg

sdir=dbs
gdir=../_local/generated
cdir=../_local/config_in
ddir=../_local/data_in

optFile=$gdir/mysql.opt

mysqlOpt="--defaults-extra-file=$optFile"
mysqlOptE="-h shebanqdb -u root -p $mysqlrootpwd"

echo "
[mysql]
password = '${mysqlrootpwd}'
user = root
host = shebanqdb
" > $optFile

echo "o-o-o Existing databases: o-o-o"

for db in `echo "show databases;" | mysql ${mysqlOpt}`
do
    if [[ "$db" =~ ^shebanq_ ]]; then
        declare dbexists_$db="v"
        echo $db
    fi
done

echo "o-o-o Importing missing databases: o-o-o"

good="v"

for version in 4 4b c 2017 2021
do
    db="shebanq_passage$version"
    dbvar=dbexists_$db
    if [[ "${!dbvar}" != "v" || "$forcestatic" == "v" || "$forceversion" == "$version" ]]; then
        echo "o-o-o - VERSION $version shebanq_passage"
        datafilez="$sdir/${db}.sql.gz"
        datafile="$gdir/${db}.sql"
        datafilezl="${datafile}.gz"
        if [[ ! -e "${datafile}" ]]; then
            echo "o-o-o - unzipping $db (takes approx.  5 seconds)"
            cp ${datafilez} ${datafilezl}
            gunzip -f "${datafilezl}"
        fi
        echo "o-o-o - loading $db (takes approx. 15 seconds)"
        mysql ${mysqlOpt} < ${datafile}
    fi

    db="shebanq_etcbc$version"
    dbvar=dbexists_$db
    if [[ "${!dbvar}" != "v" || "$forcestatic" == "v" || "$forceversion" == "$version" ]]; then
        echo "o-o-o - VERSION $version shebanq_etcbc"
        datafilez="$sdir/${db}.mql.bz2"
        datafile="$gdir/${db}.mql"
        datafilezl="${datafile}.bz2"
        if [[ ! -e "${datafile}" ]]; then
            echo "o-o-o - unzipping $db (takes approx. 75 seconds)"
            cp ${datafilez} ${datafilezl}
            bunzip2 -f ${datafilezl}
        fi
        mysql ${mysqlOpt} -e "drop database if exists ${db};"
        echo "o-o-o - loading emdros $db (takes approx. 50 seconds)"
        /opt/emdros/bin/mql -e UTF8 -n -b m $mysqlOptE < ${datafile}
    fi
done

for kind in note web
do
    db="shebanq_$kind"
    dbvar=dbexists_$db
    if [[ "${!dbvar}" != "v" || "$forcedynamic" == "v" ]]; then
        echo "o-o-o - DYNAMIC DATA clearing shebanq_$kind"
        datafilez="$sdir/${db}.sql.gz"
        datafile="$ddir/${db}.sql"
        datafilezl="${datafile}.gz"
        if [[ -e "${datafile}" ]]; then
            echo "Using sql file provided in local directory"
        else
            if [[ -e "${datafilezl}" ]]; then
                echo "Using zipped sql file provided in local directory"
                echo "o-o-o - unzipping $db"
                gunzip -f "${datafilezl}"
            elif [[ -e "${datafilez}" ]]; then
                echo "Using initial database"
                cp ${datafilez} ${datafilezl}
                gunzip -f "${datafilezl}"
            else
                echo "No data found"
                good="x"
            fi
        fi
        mysql ${mysqlOpt} -e "drop database if exists $db;"
        mysql ${mysqlOpt} -e "create database $db;"
    fi
done

for kind in web note
do
    db="shebanq_$kind"
    dbvar=dbexists_$db
    if [[ "${!dbvar}" != "v" || "$forcedynamic" == "v" ]]; then
        echo "o-o-o - DYNAMIC DATA loading shebanq_$kind"
        datafile="$ddir/${db}.sql"
        if [[ -e "${datafile}" ]]; then
            echo "use $db" | cat - ${datafile} | mysql ${mysqlOpt}
        fi
    fi
done

if [[ "$good" == "v" ]]; then
    echo "o-o-o All databases present o-o-o"
else
    echo "o-o-o Not all databases could be imported o-o-o"
fi


echo "o-o-o (RE)SETTING GRANTS o-o-o"

mysql ${mysqlOpt} < $sdir/grants.sql

#----------------------------------------------------------------------------------
# Install SHEBANQ
#----------------------------------------------------------------------------------

mkdir -p $ocdir

echo "$mysqluserpwd" > $ocdir/mql.cfg
echo "host = shebanqdb" > $ocdir/host.cfg
echo "server = localhost\nsender = shebanq@ancient-data.org" > $ocdir/mail.cfg

