#!/bin/bash

HELP="

Installs the SHEBANQ app and all its prerequisites.

The operation is idempotent: it detects what is already present, and fills in the blanks.

However, you can force individual steps with flags.


USAGE

Run it in the top-level directory

./install.sh [flag,...]

FLAGS

force-cfg
    Force creation of config files in the image

force-apache
    Force configuring apache in the image

force-static
    Import static databases even if they already exist

force-version version
    Import static databases for version even if they already exist

force-dynamic
    Import dynamic databases even if they already exist

force-data
    Import all databases even if they already exist

force-web2py
    Install web2py even if it already exists

force-shebanq
    Install shebanq even if it already exists

force-data
    Import all data, even if it is already imported

force-code
    Install web2py, shebanq even if already installed

force
    Install things even if they are already installed

test-shebanq
    Just run the shebanq test controller

run-web2py
    Run the web2py devserver in the foreground

run-apache
    Run apache in the foreground
"

forcecfg=x
forceapache=x
forcestatic=x
forceversion=""
forcedynamic=x
forceweb2py=x
forceshebanq=x

testshebanq=x
runweb2py=x
runapache=x

docfg=v
dogrants=v
doapache=v
dostatic=v
dodynamic=v
doweb2py=v
doshebanq=v

while [ ! -z $1 ]; do
    if [[ $1 == force-cfg ]]; then
        forcecfg=v
        shift
    elif [[ $1 == force-apache ]]; then
        forceapache=v
        shift
    elif [[ $1 == force-static ]]; then
        forcestatic=v
        shift
    elif [[ $1 == force-version ]]; then
        shift
        forceversion=$1
        shift
    elif [[ $1 == force-dynamic ]]; then
        forcedynamic=v
        shift
    elif [[ $1 == force-web2py ]]; then
        forceweb2py=v
        shift
    elif [[ $1 == force-shebanq ]]; then
        forceshebanq=v
        shift
    elif [[ $1 == force-data ]]; then
        forcecfg=v
        forcestatic=v
        forcedynamic=v
        shift
    elif [[ $1 == force-code ]]; then
        forceapache=v
        forceweb2py=v
        forceshebanq=v
        shift
    elif [[ $1 == force ]]; then
        forcecfg=v
        forceapache=v
        forcestatic=v
        forcedynamic=v
        forceweb2py=v
        forceshebanq=v
        shift
    elif [[ $1 == test-shebanq ]]; then
        docfg=v
        doapache=x
        dogrants=x
        dostatic=x
        dodynamic=x
        doweb2py=x
        doshebanq=x
        testshebanq=v
        shift
    elif [[ $1 == run-web2py ]]; then
        docfg=v
        doapache=x
        dogrants=x
        dostatic=x
        dodynamic=x
        doweb2py=x
        doshebanq=x
        runweb2py=v
        shift
    elif [[ $1 == run-apache ]]; then
        docfg=v
        doapache=v
        dogrants=x
        dostatic=x
        dodynamic=x
        doweb2py=x
        doshebanq=x
        runapache=v
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

#----------------------------------------------------------------------------------
# Settings
#----------------------------------------------------------------------------------

# locations on the image (non-persistent)

apachedstdir=/etc/apache2
mqlcmd=/opt/emdros/bin/mql

# directories in the repo (persistently mounted into the shebanq image)

appdir=/app
srcdir=$appdir/src
secretdir=$appdir/secret
rundir=$appdir/run
tmpdir=$appdir/_temp

cfgdir=$rundir/cfg
mysqloptfile=$cfgdir/mysql.opt
mysqlasroot=--defaults-extra-file=$mysqloptfile
mysqlasuser="-h $mysqlhost -u root -p $mysqlrootpwd"

apachesrcdir=$srcdir/apache

dbdir=$srcdir/databases

web2pydir=$rundir/web2py
web2pyfile=web2py_src-2.24.1-stable.zip
web2pyappdir=$web2pydir/applications
adminappdir=$web2pyappdir/admin

paramFile=parameters_$shebanqport.py
paramGiven=$secretdir/$paramFile
paramUsed=$web2pydir/$paramFile

shebanqsrcdir=$srcdir/shebanq
shebanqdir=$rundir/shebanq
shebanqappdir=$web2pydir/applications/shebanq

#----------------------------------------------------------------------------------
# Configuration of the image
#----------------------------------------------------------------------------------

if [[ $docfg == v ]]; then
    echo o-o-o CONFIG FILES o-o-o
    mysqlhost=shebanqdb

    if [[ ! -e $mysqloptfile || $forcecfg == v ]]; then
        if [[ ! -d $cfgdir ]]; then
            mkdir -p $cfgdir
        fi

        echo "
[mysql]
password = '$mysqlrootpwd'
user = root
host = $mysqlhost
        " > $mysqloptfile

        echo "$mysqluserpwd" > $cfgdir/mql.cfg
        echo $mysqlhost > $cfgdir/host.cfg
        echo -e "server = localhost\nsender = shebanq@ancient-data.org" > $cfgdir/mail.cfg
        echo "created mysql db connection config files" 
    fi

    # set the permissions for the shebanq database user

    mysql $mysqlasroot < $srcdir/grants.sql > /dev/null
    if [[ $? -ne 0 ]]; then
        echo Cannot connect to database
        exit
    fi

    echo Database grants have been set

fi

#----------------------------------------------------------------------------------
# Configure apache
#----------------------------------------------------------------------------------

if [[ $doapache == v ]]; then
    echo o-o-o Apache config o-o-o
    sitefile=shebanq.conf
    sitesrcpath=$apachesrcdir/sites-available/$sitefile
    sitedestdir=$apachedstdir/sites-available/
    sitedestpath=$sitedestdir/$sitefile
    sitedestlink=$apachedstdir/sites-enabled/$sitefile
    modfile=wsgi.conf
    modsrcpath=$apachesrcdir/mods-available/$modfile
    moddestdir=$apachedstdir/mods-available/
    moddestpath=$moddestdir/$modfile
    moddestlinkdir=$apachedstdir/mods-enabled/

    if [[ ! -f $sitedestpath || ! -f $moddestpath || $forceapache == v ]]; then
        for mod in expires headers
        do
            ln -sf $moddestdir/$mod.load $moddestlinkdir
        done

        if [[ -f $moddestpath ]]; then
            moddestpathdis=$moddestpath.disabled
            if [[ ! -f $moddestpathdis ]]; then
                cp $moddestpath $moddestpathdis
            fi
        fi
        cp $modsrcpath $moddestdir
        echo wsgi config $modfile has been put in place
        cp $sitesrcpath $sitedestdir
        echo website config $sitefile has been put in place
        ln -sf $sitedestpath $sitedestlink
    fi
fi

#----------------------------------------------------------------------------------
# Load databases
#----------------------------------------------------------------------------------

# test which of the needed databases are already in mysql
# after this we have for each existing database a variable with name dbexists_databasename

if [[ $dostatic == v || $dodynamic == v ]]; then
    echo o-o-o Existing databases o-o-o

    for db in `echo "show databases;" | mysql $mysqlasroot`
    do
        if [[ $db =~ ^shebanq_ ]]; then
            declare dbexists_$db=v
            echo $db
        fi
    done

    # import the missing databases

    echo o-o-o Importing missing databases o-o-o

    # here come the readonly databases. For each version of the Hebrew Bible
    # there are two databases:
    #  shebanq_passageVERSION: ordinary sql data,
    #   contains the text of the verses,
    #   optimized for displaying the bible text
    #  shebanq_etcbcVERSION: mql data,
    #   contains the text plus linguistic annotations by the ETCBC,
    #   optimized for executing MQL queries

    if [[ $dostatic == v ]]; then
        for version in 4 4b c 2017 2021
        do
            db=shebanq_passage$version
            dbvar=dbexists_$db
            if [[ ${!dbvar} != v || $forcestatic == v || $forceversion == $version ]]; then
                echo o-o-o - VERSION $version shebanq_passage
                datafile=$db.sql
                datafilez=$datafile.gz

                if [[ ! -e $tmpdir/$datafile ]]; then
                    echo o-o-o - unzipping $db "(takes approx.  5 seconds)"
                    cp $dbdir/$datafilez $tmpdir
                    gunzip -f $tmpdir/$datafilez
                fi
                echo o-o-o - loading $db "(takes approx. 15 seconds)"
                mysql $mysqlasroot < $tmpdir/$datafile
            fi

            db=shebanq_etcbc$version
            dbvar=dbexists_$db
            if [[ ${!dbvar} != v || $forcestatic == v || $forceversion == $version ]]; then
                echo o-o-o - VERSION $version shebanq_etcbc
                datafile=$db.mql
                datafilez=$datafile.bz2

                if [[ ! -e $tmpdir/$datafile ]]; then
                    echo o-o-o - unzipping $db "(takes approx. 75 seconds)"
                    cp $dbdir/$datafilez $tmpdir
                    bunzip2 -f $tmpdir/$datafilez
                fi
                mysql $mysqlasroot -e "drop database if exists $db;"
                echo o-o-o - loading emdros $db "(takes approx. 50 seconds)"
                $mqlcmd -e UTF8 -n -b m $mysqlasuser < $tmpdir/$datafile
            fi
        done
    fi

    # here come the dynamic databases. They contain the user-contributed content
    # there are two databases:
    #  shebanq_web: user details, saved queries
    #  shebanq_note: saved notes
    #
    # the shebanq_note has foreign-key dependencies on shebanq_web.
    #  When deleting these databases: first delete shebanq_note, then shebanq_web.
    #  When importing these databases: first import shebanq_web, then shebanq_note.
    #
    # When you want to import pre-existing data, they should have been exported as
    # SQL exports.
    # Put them in the secret/data_in folder, you may gzip them, but this is not necessary.
    # The secret folder is not synched with GitHub.
    # Also, remove existing databases with this name from _temp.
    #
    # If you do not have pre-existing data, empty databases will be supplied, but with the
    # right model inside. These empty exports are also in this repo, and they are synched
    # with GitHub.

    if [[ $dodynamic == v ]]; then
        # Cleanup stage (only if the import of dynamic data is forced)
        # The order note - web is important.

        good=v

        for kind in note web
        do
            db=shebanq_$kind
            dbvar=dbexists_$db

            if [[ ${!dbvar} != v || $forcedynamic == v ]]; then
                echo o-o-o - DYNAMIC DATA clearing shebanq_$kind
                datafile=$db.sql
                datafilez=$datafile.gz

                if [[ -e $tmpdir/$datafile ]]; then
                    echo Using sql file provided in temp directory
                else
                    if [[ -e $secretdir/$datafilez ]]; then
                        echo Using previous db content provided in secret directory
                        cp $secretdir/$datafilez $tmpdir/$datafilez
                        echo o-o-o - unzipping $db
                        gunzip -f $tmpdir/$datafilez
                    elif [[ -e $srcdir/$datafilez ]]; then
                        echo Using empty database
                        cp $srcdir/$datafilez $tmpdir/$datafilez
                        gunzip -f $datafilezl
                    else
                        echo No data found
                        good=x
                    fi
                fi
                if [[ $good == x ]]; then
                    exit
                fi

                mysql $mysqlasroot -e "drop database if exists $db;"
                mysql $mysqlasroot -e "create database $db;"
            fi
        done

        # Import stage.
        # The order web - note is important.

        for kind in web note
        do
            db=shebanq_$kind
            dbvar=dbexists_$db
            if [[ ${!dbvar} != v || $forcedynamic == v ]]; then
                echo o-o-o - DYNAMIC DATA loading shebanq_$kind
                datafile=$db.sql

                if [[ -e $tmpdir/$datafile ]]; then
                    echo "use $db" | cat - $tmpdir/$datafile | mysql $mysqlasroot
                fi
            fi
        done
    fi

    echo o-o-o All databases present o-o-o
fi

#----------------------------------------------------------------------------------
# Install Web2Py
#----------------------------------------------------------------------------------

if [[ $doweb2py == v ]]; then
    echo o-o-o Web2Py o-o-o

    if [[ ! -e $web2pydir || $forceweb2py == v ]]; then
        if [[ -e $web2pydir ]]; then
            echo Removing existing web2py directory
            rm -rf $web2pydir
        fi
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

            if [[ -e $shebanqappdir ]]; then
                rm -rf $shebanqappdir
            fi
            ln -s $shebanqdir $shebanqappdir
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
    fi
fi

#----------------------------------------------------------------------------------
# Install SHEBANQ
#----------------------------------------------------------------------------------

if [[ $doshebanq == v ]]; then
    echo o-o-o SHEBANQ o-o-o

    if [[ ! -e $shebanqdir || $forceshebanq == v ]]; then
        if [[ ! -e $shebanqdir ]]; then
            mkdir -p $shebanqdir
        fi

        cp -R $shebanqsrcdir/* $shebanqdir

        # make certain dirs in the shebanq app writable
        for wd in log cache errors sessions private uploads
        do
            wdpath=$shebanqdir/$wd
            if [[ ! -e $wdpath ]]; then
                mkdir $wdpath
                chown www-data:www-data $wdpath
            fi
        done

        # Configure Web2Py and SHEBANQ

        if [[ -e $shebanqappdir ]]; then
            rm -rf $shebanqappdir
        fi
        ln -s $shebanqdir $shebanqappdir

        # compile shebanq app

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
        echo "installation of shebanq complete"
        cd $appdir
    fi
fi

#----------------------------------------------------------------------------------
# Test the main controller of SHEBANQ
#----------------------------------------------------------------------------------

if [[ $testshebanq == v ]]; then
    cd $web2pydir
    python3 web2py.py -S shebanq/hebrew/text -M > /dev/null
    cd $appdir
fi

#----------------------------------------------------------------------------------
# Run Web2Py
#----------------------------------------------------------------------------------

if [[ $runweb2py == v ]]; then
    echo o-o-o WEB2PY run in foreground o-o-o
    cd $web2pydir
    python3 web2py.py --no_gui -i 0.0.0.0 -p $hostport -a $web2pyadminpwd
fi
#
#----------------------------------------------------------------------------------
# Run Apache
#----------------------------------------------------------------------------------

if [[ $runapache == v ]]; then
    echo o-o-o APACHE run in foreground o-o-o
    apachectl -D FOREGROUND
fi
