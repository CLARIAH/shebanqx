#!/bin/bash

HELP="

Installs the SHEBANQ app.

---------------------------------------------------------------------------------
Initialize databases
---------------------------------------------------------------------------------

1. all static databases, corresponding to versions of the Hebrew Bible
2. all dynamic databases, containing user contributed content

Previous dynamic content is looked up from the _local directory,
which is not pushed to GitHub.
Blank dynamic content will be provided if there is no previous dynamic content.

The operation is incremental: it detects what is already present, and fills in the blanks.

However, you can force new imports with flags.


USAGE

Run it in the maintenance directory

./install.sh [flag,...]

FLAGS

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

force-apache
    Install apache even if it already exists

force-code
    Install web2py, shebanq, apache even if already installed

force
    Install things even if they are already installed

test-shebanq
    Just run the shebanq test controller

run-web2py
    Run the web2py devserver in the foreground

run-apache
    Run apache in the foreground

web2py-ask-pwd
    Be asked to provide a new admin password.
    Assumes web2py is installed.
"

forcestatic="x"
forceversion=""
forcedynamic="x"
forceweb2py="x"
forceshebanq="x"
forceapache="x"

web2pyaskpwd="x"
testshebanq="x"
runweb2py="x"
runapache="x"

dogrants="v"
dostatic="v"
dodynamic="v"
doweb2py="v"
doshebanq="v"
doapache="v"

while [ ! -z "$1" ]; do
    if [[ "$1" == "force-static" ]]; then
        forcestatic="v"
        shift
    elif [[ "$1" == "force-version" ]]; then
        shift
        forceversion="$1"
        shift
    elif [[ "$1" == "force-dynamic" ]]; then
        forcedynamic="v"
        shift
    elif [[ "$1" == "force-web2py" ]]; then
        forceweb2py="v"
        shift
    elif [[ "$1" == "force-shebanq" ]]; then
        forceshebanq="v"
        shift
    elif [[ "$1" == "force-apache" ]]; then
        forceapache="v"
        shift
    elif [[ "$1" == "force-data" ]]; then
        forcestatic="v"
        forcedynamic="v"
        shift
    elif [[ "$1" == "force-code" ]]; then
        forceweb2py="v"
        forceshebanq="v"
        forceapache="v"
        shift
    elif [[ "$1" == "force" ]]; then
        forcestatic="v"
        forcedynamic="v"
        forceweb2py="v"
        forceshebanq="v"
        forceapache="v"
        shift
    elif [[ "$1" == "test-shebanq" ]]; then
        dogrants="x"
        dostatic="x"
        dodynamic="x"
        doweb2py="x"
        doshebanq="x"
        doapache="x"
        testshebanq="v"
        shift
    elif [[ "$1" == "run-web2py" ]]; then
        dogrants="x"
        dostatic="x"
        dodynamic="x"
        doweb2py="x"
        doshebanq="x"
        doapache="x"
        runweb2py="v"
        shift
    elif [[ "$1" == "run-apache" ]]; then
        dogrants="x"
        dostatic="x"
        dodynamic="x"
        doweb2py="x"
        doshebanq="x"
        doapache="x"
        runapache="v"
        shift
    elif [[ "$1" == "web2pyaskpwd" ]]; then
        dogrants="x"
        dostatic="x"
        dodynamic="x"
        doweb2py="x"
        doshebanq="x"
        doapache="x"
        web2pyaskpwd="v"
        shift
    else
        echo "unrecognized argument '$1'"
        good="x"
        shift
    fi
done

if [[ "$good" == "x" ]]; then
    exit
fi

#----------------------------------------------------------------------------------
# Settings
#----------------------------------------------------------------------------------

adir=/app

mdir=$adir/maintenance
mddir=$mdir/dbs

sdir=$adir/src
ssdir=$sdir/shebanq

shdir=$adir/shebanq

wdir=$adir/web2py
wadir=$wdir/applications
shwdir=$wadir/shebanq
wfile="web2py_src-2.21.1-stable.zip"

ldir=$adir/_local
lgdir=$ldir/generated
lcdir=$ldir/config_in
lddir=$ldir/data_in
optFile=$lgdir/mysql.opt

paramFile="parameters_443.py"
paramGiven="$lcdir/$paramFile"
paramSaved="$wdir/$paramFile"

ocdir=/opt/cfg

mysqlhost=shebanqdb
mysqlOpt="--defaults-extra-file=$optFile"
mysqlOptE="-h ${mysqlhost} -u root -p $mysqlrootpwd"

apdir=/etc/apache2
aldir=/var/log/apache2

#----------------------------------------------------------------------------------
# Initialize databases
#----------------------------------------------------------------------------------

# test which of the needed databases are already in mysql
# after this we have for each existing database a variable with name dbexists_databasename

if [[ "$dostatic" == "v" || "$dodynamic" == "v" ]]; then
    # create config file in order to operate to the database

    echo "
    [mysql]
    password = '${mysqlrootpwd}'
    user = root
    host = ${mysqlhost}
    " > $optFile

    echo "o-o-o Existing databases o-o-o"

    for db in `echo "show databases;" | mysql ${mysqlOpt}`
    do
        if [[ "$db" =~ ^shebanq_ ]]; then
            declare dbexists_$db="v"
            echo -e "\t$db"
        fi
    done

    # import the missing databases

    echo "o-o-o Importing missing databases o-o-o"

    good="v"

    # here come the readonly databases. For each version of the Hebrew Bible
    # there are two databases:
    #  shebanq_passageVERSION: ordinary sql data,
    #   contains the text of the verses,
    #   optimized for displaying the bible text
    #  shebanq_etcbcVERSION: mql data,
    #   contains the text plus linguistic annotations by the ETCBC,
    #   optimized for executing MQL queries

    if [[ "$dostatic" == "v" ]]; then
        for version in 4 4b c 2017 2021
        do
            db="shebanq_passage$version"
            dbvar=dbexists_$db
            if [[ "${!dbvar}" != "v" || "$forcestatic" == "v" || "$forceversion" == "$version" ]]; then
                echo -e "\to-o-o - VERSION $version shebanq_passage"
                datafilez="$mddir/${db}.sql.gz"
                datafile="$lgdir/${db}.sql"
                datafilezl="${datafile}.gz"
                if [[ ! -e "${datafile}" ]]; then
                    echo -e "\t\to-o-o - unzipping $db (takes approx.  5 seconds)"
                    cp ${datafilez} ${datafilezl}
                    gunzip -f "${datafilezl}"
                fi
                echo -e "\t\to-o-o - loading $db (takes approx. 15 seconds)"
                mysql ${mysqlOpt} < ${datafile}
            fi

            db="shebanq_etcbc$version"
            dbvar=dbexists_$db
            if [[ "${!dbvar}" != "v" || "$forcestatic" == "v" || "$forceversion" == "$version" ]]; then
                echo -e "\t\to-o-o - VERSION $version shebanq_etcbc"
                datafilez="$mddir/${db}.mql.bz2"
                datafile="$lgdir/${db}.mql"
                datafilezl="${datafile}.bz2"
                if [[ ! -e "${datafile}" ]]; then
                    echo -e "\t\to-o-o - unzipping $db (takes approx. 75 seconds)"
                    cp ${datafilez} ${datafilezl}
                    bunzip2 -f ${datafilezl}
                fi
                mysql ${mysqlOpt} -e "drop database if exists ${db};"
                echo -e "\t\to-o-o - loading emdros $db (takes approx. 50 seconds)"
                /opt/emdros/bin/mql -e UTF8 -n -b m $mysqlOptE < ${datafile}
            fi
        done
    fi

    # here come the dynamic databases. They contain the user-contributed content
    # there are two databases:
    #  shebanq_web: user details, saved queries
    #  shebanq_note: saved notes
    #
    # the shebanq_note has FK dependencies on shebanq_web.
    #  When deleting these databases: first delete shebanq_note, then shebanq_web.
    #  When importing these databases: first import shebanq_web, then shebanq_note.
    #
    # When you want to import pre-existing data, they should have been exported as
    # SQL exports.
    # Put them in the _local/data_in folder, you may gzip them, but this is not necessary.
    # The _local folder is not synched with GitHub.
    # If you do not have pre-existing data, empty databases will be supplied, but with the
    # right model inside. These empty exports are also in this repo, and they are synched
    # with GitHub.

    # Cleanup stage (only if the import of dynamic data is forced)
    # The order note - web is important.

    if [[ "$dodynamic" == "v" ]]; then
        for kind in note web
        do
            db="shebanq_$kind"
            dbvar=dbexists_$db
            if [[ "${!dbvar}" != "v" || "$forcedynamic" == "v" ]]; then
                echo -e "\to-o-o - DYNAMIC DATA clearing shebanq_$kind"
                datafilez="$mddir/${db}.sql.gz"
                datafile="$lddir/${db}.sql"
                datafilezl="${datafile}.gz"
                if [[ -e "${datafile}" ]]; then
                    echo -e "\t\tUsing sql file provided in local directory"
                else
                    if [[ -e "${datafilezl}" ]]; then
                        echo -e "\t\tUsing zipped sql file provided in local directory"
                        echo -e "\t\to-o-o - unzipping $db"
                        gunzip -f "${datafilezl}"
                    elif [[ -e "${datafilez}" ]]; then
                        echo -e "\t\tUsing initial database"
                        cp ${datafilez} ${datafilezl}
                        gunzip -f "${datafilezl}"
                    else
                        echo -e "\t\tNo data found"
                        good="x"
                    fi
                fi
                mysql ${mysqlOpt} -e "drop database if exists $db;"
                mysql ${mysqlOpt} -e "create database $db;"
            fi
        done
    fi

    # Import stage.
    # The order web - note is important.

    for kind in web note
    do
        db="shebanq_$kind"
        dbvar=dbexists_$db
        if [[ "${!dbvar}" != "v" || "$forcedynamic" == "v" ]]; then
            echo -e "\to-o-o - DYNAMIC DATA loading shebanq_$kind"
            datafile="$lddir/${db}.sql"
            if [[ -e "${datafile}" ]]; then
                echo "use $db" | cat - ${datafile} | mysql ${mysqlOpt}
            fi
        fi
    done

    if [[ "$good" == "v" ]]; then
        echo "o-o-o All databases present o-o-o"
    else
        echo "o-o-o Not all databases could be imported o-o-o"
    fi
fi

#----------------------------------------------------------------------------------
# Install Web2Py
#----------------------------------------------------------------------------------

# The file parameters_443.py contains the hash of the admin password.
# You can supply it in the _local/config_in folder, which is not synched to GitHub
# If you did not supply an admin password, the install script will continue without
# setting up an admin password.
# You can run the install script again with web2by-ask-pwd and then it will
# ask for an admin password and set it up.

if [[ "$doweb2py" == "v" || "$web2pyaskpwd" == "v" ]]; then
    echo "o-o-o Web2Py o-o-o"

    if [[ ! -e $wdir || "$forceweb2py" == "v" ]]; then
        if [[ -e $wdir ]]; then
            echo -e "\tRemoving existing web2py directory"
            rm -rf $wdir
        fi
        cp $sdir/$wfile $adir/web2py.zip
        cd $adir
        unzip web2py.zip > /dev/null
        rm web2py.zip
        cd $mdir

        if [[ "$web2pyaskpwd" == "x" ]]; then
            if [[ -f "$paramGiven" ]]; then
                echo -e "\tFound existing $paramFile with hash of admin password"
                cp $paramGiven $wdir
            else
                echo -e "\tNo $paramGiven with hash of admin password found"
                echo -e "\tYou can create one afterwards by running"
                echo -e "\t./install.sh web2pyaskpwd"
            fi
        fi
        cp routes.py $wdir
        cp wsgihandler.py $wdir
     
        if [[ -e $shdir ]]; then
            # hookup shebanq in web2py/applications

            if [[ -e $shwdir ]]; then
                rm -rf $shwdir
            fi
            ln -s $shdir $shwdir
        fi
        chown -R www-data:www-data $wdir

        # remove examples and welcome applications

        for app in examples welcome
        do
            if [[ -e "$wadir/$app" ]]; then
                rm -rf "$wadir/$app"
            fi
        done
    fi
fi

if [[ "$web2pyaskpwd" == "v" ]]; then

    cd $wdir
    python3 -c "from gluon.main import save_password; save_password(input('admin password: '),443)"
    if [[ -f "$paramSaved" ]]; then
        cp $paramSaved $paramGiven
        chown -R www-data:www-data $paramGiven
        echo -e "\tA new $paramFile file has been created and saved to $lcdir"
    fi
    cd $mdir
fi

#----------------------------------------------------------------------------------
# Install SHEBANQ
#----------------------------------------------------------------------------------

if [[ "$doshebanq" == "v" ]]; then
    echo "o-o-o SHEBANQ o-o-o"

    if [[ ! -e $shdir || "$forceshebanq" == "v" ]]; then
        if [[ ! -e $shdir ]]; then
            mkdir -p $shdir
        fi

        cp -R $ssdir/* $shdir

        for wd in log cache errors sessions private uploads
        do
            wdpath="$shdir/$wd"
            if [[ ! -e "$wdpath" ]]; then
                mkdir "$wdpath"
            fi
        done

        # Configure Web2Py and SHEBANQ

        if [[ -e $shwdir ]]; then
            rm -rf $shwdir
        fi
        ln -s $shdir $shwdir

        # Create config files in /opt/cfg

        mkdir -p $ocdir

        echo "$mysqluserpwd" > $ocdir/mql.cfg
        echo "${mysqlhost}" > $ocdir/host.cfg
        echo "server = localhost\nsender = shebanq@ancient-data.org" > $ocdir/mail.cfg

        # set the permissions for the shebanq database user

        echo -e "\to-o-o (RE)SETTING GRANTS o-o-o"

        mysql ${mysqlOpt} < $mddir/grants.sql
        chown -R www-data:www-data $shdir
    fi
fi

#----------------------------------------------------------------------------------
# Configure Apache
#----------------------------------------------------------------------------------

if [[ "$doapache" == "v" ]]; then
    echo "o-o-o APACHE setup o-o-o"
    conffile=shebanq.conf
    confdir=$apdir/sites-available/
    confpath=$confdir/$conffile
    if [[ ! -f $confpath || "$forceapache" == "v" ]]; then
        for mod in expires headers
        do
            ln -sf $apdir/mods-available/$mod.load $apdir/mods-enabled/
        done

        wsfile=wsgi.conf
        wsadir=$apdir/mods-available
        wsapath=$wsadir/wsfile
        if [[ -f $wsapath ]]; then
            wsapathd=$wsapath.disabled
            if [[ ! -f $wsapathd ]]; then
                cp $wsapath $wsapathd
            fi
        fi
        cp $mdir/$wsfile $wsadir
        cp $mdir/$conffile $confpath
        ln -sf $confpath $apdir/sites-enabled/
        chown -R www-data:www-data $aldir
    fi
fi

#----------------------------------------------------------------------------------
# Test the main controller of SHEBANQ
#----------------------------------------------------------------------------------

if [[ "$testshebanq" == "v" ]]; then
    cd $wdir
    python3 web2py.py -S shebanq/hebrew/text -M > /dev/null
    cd $mdir
fi

#----------------------------------------------------------------------------------
# Run Web2Py
#----------------------------------------------------------------------------------

if [[ "$runweb2py" == "v" ]]; then
    echo "o-o-o WEB2PY run in foreground o-o-o"
    cd /app/web2py
    python web2py.py --no_gui -i 0.0.0.0 -p 8000 -a shebanq
fi
#
#----------------------------------------------------------------------------------
# Run Apache
#----------------------------------------------------------------------------------

if [[ "$runapache" == "v" ]]; then
    echo "o-o-o APACHE run in foreground o-o-o"
    apachectl -D FOREGROUND
fi
