#!/bin/bash

HELP="

Loads the SHEBANQ databases.

It will load static data containing the texts and linguistic annotaitons.
And it will load the dynamic data contributed by users: queries and notes and admin details.

The operation is idempotent: it detects what is already present, and fills in the blanks.

USAGE

Run it in the top-level directory

./load.sh

"

#----------------------------------------------------------------------------------
# Settings
#----------------------------------------------------------------------------------

# locations on the image (persistent)

mqlcmd=/opt/emdros/bin/mql

# directories in the repo (persistently mounted into the shebanq image)

appdir=/app
srcdir=$appdir/src
secretdir=$appdir/secret
rundir=$appdir/run
tmpdir=$appdir/_temp

cfgdir=$rundir/cfg
mysqloptfile=$cfgdir/mysql.opt
mysqlasroot=--defaults-extra-file=$mysqloptfile
mysqlasroote="-h $mysqlhost -u root -p $mysqlrootpwd"


dbdir=$srcdir/databases

# set the permissions for the shebanq database user

mysql $mysqlasroot < $srcdir/grants.sql > /dev/null
if [[ $? -ne 0 ]]; then
    echo Cannot connect to database
    exit
fi

echo Database grants have been set


#----------------------------------------------------------------------------------
# Load databases
#----------------------------------------------------------------------------------

# test which of the needed databases are already in mysql
# after this we have for each existing database a variable with name dbexists_databasename

for db in `echo "show databases;" | mysql $mysqlasroot`
do
    if [[ $db =~ ^shebanq_ ]]; then
        declare dbexists_$db=v
    fi
done

# import the missing databases

# here come the readonly databases. For each version of the Hebrew Bible
# there are two databases:
#  shebanq_passageVERSION: ordinary sql data,
#   contains the text of the verses,
#   optimized for displaying the bible text
#  shebanq_etcbcVERSION: mql data,
#   contains the text plus linguistic annotations by the ETCBC,
#   optimized for executing MQL queries

for version in 4 4b c 2017 2021
do
    db=shebanq_passage$version
    dbvar=dbexists_$db

    if [[ ${!dbvar} != v ]]; then
        echo Importing $db
        datafile=$db.sql
        datafilez=$datafile.gz

        if [[ ! -e $tmpdir/$datafile ]]; then
            echo -e "\tunzipping $db (takes approx.  5 seconds)"
            cp $dbdir/$datafilez $tmpdir
            gunzip -f $tmpdir/$datafilez
        fi
        echo -e "\tloading $db (takes approx. 15 seconds)"
        mysql $mysqlasroot < $tmpdir/$datafile
        echo -e "\tdone"
    fi

    db=shebanq_etcbc$version
    dbvar=dbexists_$db

    if [[ ${!dbvar} != v ]]; then
        echo Importing $db
        datafile=$db.mql
        datafilez=$datafile.bz2

        if [[ ! -e $tmpdir/$datafile ]]; then
            echo -e "\tunzipping $db (takes approx. 75 seconds)"
            cp $dbdir/$datafilez $tmpdir
            bunzip2 -f $tmpdir/$datafilez
        fi
        mysql $mysqlasroot -e "drop database if exists $db;"
        echo -e "\tloading emdros $db (takes approx. 50 seconds)"
        $mqlcmd -e UTF8 -n -b m $mysqlasroote < $tmpdir/$datafile
        echo -e "\tdone"
    fi
done

# here come the dynamic databases. They contain the user-contributed content
# there are two databases:
#  shebanq_web: user details, saved queries
#  shebanq_note: saved notes
#
# the shebanq_note has foreign-key dependencies on shebanq_web.
#  When deleting these databases: first delete shebanq_note, then shebanq_web.
#  When importing these databases: first import shebanq_web, then shebanq_note.
#
# When you want to import pre-existing data, they should have been exported as
# SQL exports.
# Put them in the secret/data_in folder, you may gzip them, but this is not necessary.
# The secret folder is not synched with GitHub.
# Also, remove existing databases with this name from _temp.
#
# If you do not have pre-existing data, empty databases will be supplied, but with the
# right model inside. These empty exports are also in this repo, and they are synched
# with GitHub.

    # Cleanup stage (only if the import of dynamic data is forced)
    # The order note - web is important.

good=v

for kind in note web
do
    db=shebanq_$kind
    dbvar=dbexists_$db

    if [[ ${!dbvar} != v ]]; then
        echo Checking $db
        datafile=$db.sql
        datafilez=$datafile.gz

        if [[ -e $tmpdir/$datafile ]]; then
            echo previous db content from temp directory
        else
            if [[ -e $secretdir/$datafilez ]]; then
                echo previous db content from secret directory
                cp $secretdir/$datafilez $tmpdir/$datafilez
                echo o-o-o - unzipping $db
                gunzip -f $tmpdir/$datafilez
            elif [[ -e $srcdir/$datafilez ]]; then
                echo no previous content
                cp $srcdir/$datafilez $tmpdir/$datafilez
                gunzip -f $datafilezl
            else
                echo no data
                good=x
            fi
        fi
        if [[ $good == x ]]; then
            exit
        fi

        mysql $mysqlasroot -e "drop database if exists $db;"
        mysql $mysqlasroot -e "create database $db;"
    fi
done

# Import stage.
# The order web - note is important.

for kind in web note
do
    db=shebanq_$kind
    dbvar=dbexists_$db
    if [[ ${!dbvar} != v ]]; then
        datafile=$db.sql

        if [[ -e $tmpdir/$datafile ]]; then
            echo "use $db" | cat - $tmpdir/$datafile | mysql $mysqlasroot
        fi
        echo Imported $db
    fi
done
