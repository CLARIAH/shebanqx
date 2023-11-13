#!/bin/bash

HELP="
Entrypoint command of the shebanq container.
Installs software, loads data, and runs a service.
No arguments needed.
Working directory: any.
"

if [[ $1 == "--help" || $1 == "-h" ]]; then
    printf "$HELP"
    exit
fi

appdir=/app

if [[ $runmode == maintenance ]]; then
    echo "MAINTENANCE MODE"

    tail -f /dev/null &
    pid=$!

else

    echo verifying whether installation is complete
    $appdir/install.sh
    echo installation is complete

    echo waiting for shebanqdb to come online
    sleep 2
    $appdir/load.sh
    echo all data present in shebanqdb

    echo starting shebanq web app
    $appdir/run.sh $runmode &
    pid=$!
fi

trap "kill $pid" SIGTERM
wait "$pid"
