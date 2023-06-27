#!/bin/bash

optFile=mysql.opt
mysqlOpt="--defaults-extra-file=$optFile"
mysqlOptE="-h shebanqdb -u root -p $mysqlrootpwd"
echo "
[mysql]
password = '${mysqlrootpwd}'
user = root
host = shebanqdb
" > $optFile

mysql --defaults-extra-file=$optFile < grants.sql

# for version in 4 4b c 2017 2021
for version in 4
do
    echo "o-o-o - VERSION $version shebanq_passage"
    db="shebanq_passage$version"
    datafilez="dbs/${db}.sql.gz"
    datafile="../_local/${db}.sql"
    datafilezl="${datafile}.gz"
    if [[ ! -e "${datafile}" ]]; then
        echo "o-o-o - unzipping $db (takes approx.  5 seconds)"
        cp ${datafilez} ${datafilezl}
        time gunzip -f "${datafilezl}"
    fi
    echo "o-o-o - loading $db (takes approx. 15 seconds)"
    time mysql ${mysqlOpt} < ${datafile}

    echo "o-o-o - VERSION $version shebanq_etcbc"
    db="shebanq_etcbc$version"
    datafilez="dbs/${db}.mql.bz2"
    datafile="../_local/${db}.mql"
    datafilezl="${datafile}.bz2"
    if [[ ! -e "${datafile}" ]]; then
        echo "o-o-o - unzipping $db (takes approx. 75 seconds)"
        cp ${datafilez} ${datafilezl}
        time bunzip2 -f ${datafilezl}
    fi
    mysql ${mysqlOpt} -e "drop database if exists ${db};"
    echo "o-o-o - loading emdros $db (takes approx. 50 seconds)"
    time /opt/emdros/bin/mql -e UTF8 -n -b m $mysqlOptE < ${datafile}
done
