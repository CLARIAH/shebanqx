#!/bin/bash

HELP="
Run SHEBANQ webapp.

Usage

Run it from the /src directory in the repo.

./start.sh
"


if [[ "${runmode}" == "maintenance" ]]; then
    echo "MAINTENANCE MODE"
    tail -f /dev/null &
    pid=$!
elif [[ "${runmode}" == "production" || "${runmode}" == "" ]]; then
    runmode=production
    echo "PRODUCTION MODE"
    echo "waiting for shebanqdb to come online"
    sleep 2
    ./install.sh
    echo RUNNING apache ...
    apachectl -D FOREGROUND &
    pid=$!
elif [[ "${runmode}" == "develop" ]]; then
    echo "DEVELOP MODE"
    echo "waiting for shebanqdb to come online"
    sleep 2
    ./install.sh
    echo RUNNING web2py dev server ...
    cd /app/run/web2py
    python3 web2py.py --no_gui -i 0.0.0.0 -p $hostport -a $web2pyadminpwd &
    pid=$!
fi

trap "kill $pid" SIGTERM
wait "$pid"
