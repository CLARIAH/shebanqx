#!/bin/bash

HELP="
Run SHEBANQ webapp.

Usage

Run it from the /src directory in the repo.

./start.sh
"


# python web2py.py --no_gui -s localhost -p 8000 -a shebanq -c local.crt -k local.key

if [[ "${maintenance}" == "v" ]]; then
    echo "MAINTENANCE MODE"
    tail -f /dev/null &
    pid=$!
else
    echo "SERVING MODE"
    cd /web2py
    python web2py.py --no_gui -s localhost -p 8000 -a shebanq &
    pid=$!
fi

trap "kill $pid" SIGTERM
wait "$pid"
