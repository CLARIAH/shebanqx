#!/bin/bash

HELP="

Runs shebanq in various parts and modes.

You can trigger individual steps with tasks.


USAGE

Run it in the top-level directory

./command.sh task

TASKS

test-shebanq
    Just run the shebanq test controller

develop
    Run the web2py devserver in the foreground

production
    Run apache in the foreground.
    This is the default.
"

test=x
production=v
develop=x

while [ ! -z $1 ]; do
    if [[ $1 == test ]]; then
        test=v
        shift
    elif [[ $1 == production ]]; then
        production=v
        shift
    elif [[ $1 == develop ]]; then
        develop=v
        shift
    else
        echo "unrecognized argument '$1'"
        good=x
        shift
    fi
done

if [[ $good == x ]]; then
    exit
fi

# directories in the repo (persistently mounted into the shebanq image)

appdir=/app
rundir=$appdir/run

web2pydir=$rundir/web2py


if [[ $test == v ]]; then
    cd $web2pydir
    python3 web2py.py -S shebanq/hebrew/text -M > /dev/null
    exit
fi

if [[ $production == v ]]; then
    echo "PRODUCTION MODE (Apache)"
    apachectl -D FOREGROUND
fi

if [[ $develop == v ]]; then
    echo "DEVELOP MODE (web2py dev server)"
    cd $web2pydir
    python3 web2py.py --no_gui -i 0.0.0.0 -p $hostport -a $web2pyadminpwd
fi
