#!/bin/bash

HELP="
Run SHEBANQ webapp.

Usage

Run it from within the container.

./start.sh
"



if [[ $runmode == maintenance ]]; then
    echo "MAINTENANCE MODE"

    # No installation, just a running container ready for inspection
    # In an interactive shell you can run the scripts to
    # install, load and run

    tail -f /dev/null &
    pid=$!

else

    # In serving mode, either production (apache) or develop (web2py devserver) 
    #
    # First we run install.sh, to install missing bits on /app/run
    # Secondly we run load.sh, to load missing databases in the shebanqdb container
    # Then we run run.sh, to start the serving process in the background
    #
    # We catch the pid of that process and wait for it to be interrupted by Ctrl+C
    # This will prevent docker compose to wait 10 seconds before killing the process

    ./install.sh

    echo waiting for shebanqdb to come online
    sleep 2
    ./load.sh

    ./run.sh $runmode &
    pid=$!
fi

trap "kill $pid" SIGTERM
wait "$pid"
