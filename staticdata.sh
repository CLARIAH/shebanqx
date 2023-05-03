#!/bin/sh

mysql -hhost.docker.internal -uroot < /opt/cfg/user.sql
mysql -hhost.docker.internal -uroot < /opt/cfg/grants.sql

mysqlOpt="--defaults-extra-file=/opt/cfg/mysqldumpopt"

for version in 4 4b c 2017 2021
do
    echo "o-o-o - VERSION $version shebanq_passage"
    db="shebanq_passage$version"
    datafile="${db}.sql"
    echo "o-o-o - unzipping $db"
    gunzip -f "${db}.gz"
    echo "o-o-o - loading $db (may take half a minute)"
    mysql ${mysqlOpt} < ${datafile}
    rm ${datafile}

    echo "o-o-o - VERSION $version shebanq_etcbc"
    db="shebanq_etcbc$version"
    datafile="${db}.mql"
    echo "o-o-o - unzipping $db"
    bunzip2 -f ${datafile}.bz2
    mysql ${mysqlOpt} -hhost.docker.internal -e "drop database if exists ${db};"
    /opt/emdros/bin/mql -e UTF8 -n -b m -h host.docker.internal -u shebanq_admin -p uvw456 < ${datafile}
    rm ${datafile}
done
