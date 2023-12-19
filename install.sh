#!/bin/bash

HELP="
Invoked by start.sh as entry point of the shebanq container.
Or manually invoked within a running container.
Installs and configures software.
No arguments needed.
Working directory: any.
"

if [[ $1 == "--help" || $1 == "-h" ]]; then
    printf "$HELP"
    exit
fi

appdir=/app
srcdir=$appdir/src
rundir=$appdir/run
cfgdir=$rundir/cfg
logdir=$rundir/log

web2pydir=$rundir/web2py
mysqloptfile=$cfgdir/mysql.opt

shebanqdir=$rundir/shebanq
shebanqappdir=$web2pydir/applications/shebanq
adminappdir=$web2pydir/applications/admin

#----------------------------------------------------------------------------------
# Config files (always, env var may have changed)
#----------------------------------------------------------------------------------

if [[ ! -d $cfgdir ]]; then
    mkdir -p $cfgdir
fi

echo "
[mysql]
password = '$mysqlrootpwd'
user = $mysqlroot
host = $mysqlhost
    " > $mysqloptfile

echo "$mysqluser" > $cfgdir/muser.cfg
echo "$mysqluserpwd" > $cfgdir/mql.cfg
echo $mysqlhost > $cfgdir/host.cfg
echo $web2pyadminpwd > $cfgdir/web2py.cfg
# echo -e "server = mail0.diginfra.net\nsender = dirk.roorda@di.huc.knaw.nl" > $cfgdir/mail.cfg
echo -e "server = mail0.diginfra.net\nsender = shebanq@ancient-data.org" > $cfgdir/mail.cfg

echo "config files created" 

#----------------------------------------------------------------------------------
# Log dir (always make sure the log dir exists and is writable by Apache)
#----------------------------------------------------------------------------------

if [[ ! -e $logdir ]]; then
    mkdir $logdir
fi

chown www-data:www-data $logdir

#----------------------------------------------------------------------------------
# Web2Py
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

    # Various pathces of web2py
    #
    # See https://groups.google.com/g/web2py/c/633ZkgcK2AM
    # and
    # https://github.com/web2py/web2py/issues/2173

    # patch web2py to allow admin over http

    pfile=$web2pydir/gluon/main.py
    sed -i "s/is_local=(env.remote_addr in local_hosts and client == env.remote_addr)/is_local=True/" $pfile

    pfile=$adminappdir/models/access.py
    sed -i "s/elif not request.is_local and not DEMO_MODE:/elif False:/" $pfile

    # patch web2py to inhibit a syntax warning
     
    pfile=$adminappdir/views/default/change_password.html
    sed -i "s/if fieldname is not/if fieldname !=/" $pfile

    # patch web2py to prevent T() within HTTP()
    # We just remove the T() from around a string argument.

    pfile=$adminappdir/controllers/appadmin.py
    sed -i "s/HTTP(200, T('appadmin is disabled because insecure channel'))/HTTP(200, 'appadmin is disabled because insecure channel')/" $pfile

    pfile=$adminappdir/controllers/default.py
    sed -i 's/HTTP(500, T("Invalid request"))/HTTP(500, "Invalid request")/g' $pfile

    pfile=$adminappdir/models/access.py
    sed -i "s/HTTP(200, T('Admin is disabled because insecure channel'))/HTTP(200, 'Admin is disabled because insecure channel')/" $pfile
    sed -i "s/HTTP(200, T('admin disabled because no admin password'))/HTTP(200, 'admin disabled because no admin password')/" $pfile

    pfile=$web2pydir/applications/welcome/controllers/appadmin.py
    sed -i "s/HTTP(200, T('appadmin is disabled because insecure channel'))/HTTP(200, 'appadmin is disabled because insecure channel')/" $pfile

    # put custom files in place

    cp $srcdir/routes.py $web2pydir
    cp $srcdir/wsgihandler.py $web2pydir
 
    # hook up shebanq in web2py/applications

    if [[ -e $shebanqdir ]]; then
        if [[ ! -e $shebanqappdir ]]; then
            ln -sf ../../shebanq $shebanqappdir
        fi
    fi

    # remove the examples application
    # (if we remove the welcome application, web2py will complain)

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
        # chown www-data:www-data $generatedDir
    fi
    cmd1="import gluon.compileapp;"
    cmd2="gluon.compileapp.compile_application('applications/admin')"

    # python-compile modules of admin app

    cd $web2pydir
    python3 -c "$cmd1 $cmd2" > /dev/null
    cd $adminappdir
    python3 -m compileall modules > /dev/null
    generatedDir=$adminappdir/modules/__pycache__
    # chown -R www-data:www-data $generatedDir
    cd $appdir

    echo "web2py installed"
fi

# set the admin password (always, env var may have changed)

cd $web2pydir
python3 -c "from gluon.main import save_password; save_password('''$web2pyadminpwd''', $hostport)"
python3 -c "from gluon.main import save_password; save_password('''$web2pyadminpwd''', 443)"
cd $appdir

#----------------------------------------------------------------------------------
# Install SHEBANQ
#----------------------------------------------------------------------------------

compileneeded=v
changed=x

if [[ ! -d $shebanqdir ]]; then
    mkdir -p $shebanqdir
    compileneeded=v
fi

shebanqsrcdir=$srcdir/shebanq

# copy over the missing subdirectories

for subdir in $shebanqsrcdir/*
do
    subname=`basename $subdir`
    rsync -av --delete --exclude '__pycache__' $subdir $shebanqdir/
    compileneeded=v
done

# make certain dirs in the shebanq app writable

for wd in log cache errors sessions private uploads databases
do
    for basedir in $shebanqdir $adminappdir
    do
        subdest=$basedir/$wd
        if [[ ! -d $subdest ]]; then
            mkdir $subdest
            chown www-data:www-data $subdest
            changed=v
        fi
    done
done

# Configure Web2Py and SHEBANQ

if [[ ! -e $shebanqappdir ]]; then
    ln -sf ../../shebanq $shebanqappdir
    changed=v
fi

# compile shebanq app

if [[ $compileneeded == v ]]; then
    echo "compiling app ..."
    generatedDir=$shebanqdir/compiled
    if [[ ! -e $generatedDir ]]; then
        mkdir $generatedDir
        chown -R www-data:www-data $generatedDir
    fi
    cmd1="import gluon.compileapp;"
    cmd2="gluon.compileapp.compile_application('applications/shebanq')"
    cmd3="gluon.compileapp.compile_application('applications/admin')"

    cd $web2pydir
    python3 -c "$cmd1 $cmd2" > /dev/null
    python3 -c "$cmd1 $cmd3" > /dev/null

    cd $shebanqappdir
    python3 -m compileall modules > /dev/null
    generatedDir=$shebanqdir/modules/__pycache__
    python3 -m compileall models > /dev/null
    generatedDir=$shebanqdir/models/__pycache__
    chown -R www-data:www-data $generatedDir

    cd $adminappdir
    python3 -m compileall modules > /dev/null
    generatedDir=$adminappdir/modules/__pycache__
    python3 -m compileall models > /dev/null
    generatedDir=$adminappdir/models/__pycache__
    chown -R www-data:www-data $generatedDir
    changed=v
fi

if [[ $changed == v ]]; then
    echo "shebanq installed"
fi
