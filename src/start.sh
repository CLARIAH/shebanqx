#!/bin/bash

HELP="
Run SHEBANQ webapp.

Usage

Run it from the /src directory in the repo.

./start.sh
"

cd ~/github/web2py/web2py
python web2py.py --no_gui -s localhost -p 0.0.0.0 -a shebanq -c local.crt -k local.key
pid=$!
trap "kill $pid" SIGTERM
wait "$pid"
