#!/bin/bash

HELP="

Installs the SHEBANQ app and its prerequisite Web2Py.
It will add directories cfg, mysql, shebanq, web2py under the run directory.

The operation is idempotent: it detects what is already present, and fills in the blanks.

USAGE

Run it in the top-level directory

./install.sh
"

#----------------------------------------------------------------------------------
# Settings
#----------------------------------------------------------------------------------

# directories in the repo (persistently mounted into the shebanq image)

appdir=/app
srcdir=$appdir/src
rundir=$appdir/run

cfgdir=$rundir/cfg
mysqloptfile=$cfgdir/mysql.opt

web2pydir=$rundir/web2py

shebanqdir=$rundir/shebanq
shebanqappdir=$web2pydir/applications/shebanq

#----------------------------------------------------------------------------------
# Config files
#----------------------------------------------------------------------------------

if [[ ! -d $cfgdir ]]; then
    mysqlhost=shebanqdb

    mkdir -p $cfgdir

    echo "
[mysql]
password = '$mysqlrootpwd'
user = root
host = $mysqlhost
    " > $mysqloptfile

    echo "$mysqluserpwd" > $cfgdir/mql.cfg
    echo $mysqlhost > $cfgdir/host.cfg
    echo -e "server = localhost\nsender = shebanq@ancient-data.org" > $cfgdir/mail.cfg

    echo "config files created" 
fi

#----------------------------------------------------------------------------------
# Install Web2Py
#----------------------------------------------------------------------------------

if [[ ! -e $web2pydir ]]; then
    web2pyfile=web2py_src-2.24.1-stable.zip
    web2pyappdir=$web2pydir/applications
    adminappdir=$web2pyappdir/admin

    cp $srcdir/$web2pyfile $rundir/web2py.zip
    cd $rundir
    unzip web2py.zip > /dev/null
    rm web2py.zip
    if [[ ! -d $web2pydir ]]; then
        mv web2py* web2py
    fi

    # patch web2py
    # so that the admin app can run over http
    # see https://github.com/smithmicro/web2py/blob/17a3afce0c368b5ab83ea941b81934851eddaafb/entrypoint.sh#L38
    #
    pfile=$adminappdir/models/access.py
    sed -i "s/elif not request.is_local and not DEMO_MODE:/elif False:/" $pfile

    pfile=$web2pydir/gluon/main.py
    sed -i "s/is_local=(env.remote_addr in local_hosts and client == env.remote_addr)/is_local=True/" $pfile

    # to inhibit a syntax warning
    #
    pfile=$adminappdir/views/default/change_password.html
    sed -i "s/if fieldname is not/if fieldname !=/" $pfile

    cd $web2pydir
    python3 -c "from gluon.main import save_password; save_password('''$web2pyadminpwd''', $hostport)"
    cd $appdir

    cp $srcdir/routes.py $web2pydir
    cp $srcdir/wsgihandler.py $web2pydir
 
    if [[ -e $shebanqdir ]]; then
        # hookup shebanq in web2py/applications

        if [[ ! -e $shebanqappdir ]]; then
            ln -sf ../../shebanq $shebanqappdir
        fi
    fi

    # remove examples and welcome applications

    for app in examples
    do
        if [[ -e $web2pyappdir/$app ]]; then
            rm -rf $web2pyappdir/$app
        fi
    done
    for fl in NEWINSTALL
    do
        if [[ -e $web2pydir/$fl ]]; then
            rm -rf $web2pydir/$fl
        fi
    done

    # make certain dirs of admin app writable
    for wd in log cache errors sessions private uploads
    do
        wdpath=$adminappdir/$wd
        if [[ ! -e $wdpath ]]; then
            mkdir $wdpath
            chown www-data:www-data $wdpath
        fi
    done

    # compile admin app

    generatedDir=$adminappdir/compiled
    if [[ ! -e $generatedDir ]]; then
        mkdir $generatedDir
        chown www-data:www-data $generatedDir
    fi
    cmd1="import gluon.compileapp;"
    cmd2="gluon.compileapp.compile_application('applications/admin')"

    cd $web2pydir
    python3 -c "$cmd1 $cmd2" > /dev/null
    cd $adminappdir
    python3 -m compileall modules > /dev/null
    generatedDir=$adminappdir/modules/__pycache__
    chown -R www-data:www-data $generatedDir
    cd $appdir

    echo "web2py installed"
fi

#----------------------------------------------------------------------------------
# Install SHEBANQ
#----------------------------------------------------------------------------------

compileneeded=x
changed=x

if [[ ! -d $shebanqdir ]]; then
    mkdir -p $shebanqdir
    compileneeded=v
fi

shebanqsrcdir=$srcdir/shebanq

for subdir in $shebanqsrcdir/*
do
    subname=`basename $subdir`
    subdest=$shebanqdir/$subname
    if [[ ! -d $subdest ]]; then
        cp -R $subdir $subdest
        compileneeded=v
    fi
done

# make certain dirs in the shebanq app writable

for wd in log cache errors sessions private uploads
do
    subdest=$shebanqdir/$wd
    if [[ ! -d $subdest ]]; then
        mkdir $subdest
        chown www-data:www-data $subdest
        changed=v
    fi
done

# Configure Web2Py and SHEBANQ

if [[ ! -e $shebanqappdir ]]; then
    ln -sf ../../shebanq $shebanqappdir
    changed=v
fi

# compile shebanq app

if [[ $compileneeded == v ]]; then
    generatedDir=$shebanqdir/compiled
    if [[ ! -e $generatedDir ]]; then
        mkdir $generatedDir
        chown -R www-data:www-data $generatedDir
    fi
    cmd1="import gluon.compileapp;"
    cmd2="gluon.compileapp.compile_application('applications/shebanq')"

    cd $web2pydir
    python3 -c "$cmd1 $cmd2" > /dev/null
    cd $shebanqappdir
    python3 -m compileall modules > /dev/null
    generatedDir=$shebanqdir/modules/__pycache__
    chown -R www-data:www-data $generatedDir
    changed=v
fi

if [[ $changed == v ]]; then
    echo "shebanq installed"
fi
