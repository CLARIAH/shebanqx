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
elif [[ "${runmode}" == "prod" ]]; then
    echo "PRODUCTION MODE"
    apachectl -D FOREGROUND &
    pid=$!
elif [[ "${runmode}" == "dev" ]]; then
    echo "DEVELOP MODE"
    cd /app/web2py
    python web2py.py --no_gui -i 0.0.0.0 -p 8000 -a shebanq
    pid=$!
fi

trap "kill $pid" SIGTERM
wait "$pid"
