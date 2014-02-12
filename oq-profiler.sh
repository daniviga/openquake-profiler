#!/bin/bash

DATE=$(date +%Y%m%d%H%M%S)
OQDIR='oq-report-'$DATE
OQDIRPATH='/tmp/'$OQDIR

check_pkg () {
    local policies=('^python-oq-.*' 'python-celeryd' 'rabbitmq-server' 'postgresql-9.1')

    echo "Gathering information on installed packages"
    dpkg -l > $OQDIRPATH/pkgs_list

    echo "Gathering information on packages policies"
    for i in "${policies[@]}"
    do
        apt-cache policy $i >> $OQDIRPATH/pkgs_policy
    done
}

check_permissions () {
    echo "Checking permissions"
    ls -la /usr/openquake /var/lib/openquake > $OQDIRPATH/permissions
}

check_env () {
    echo "Checking user environment"
    env > $OQDIRPATH/user_env
}

copy_settings () {
    local PG=/etc/postgresql/9.1/main

    echo "Gathering information on software configurations"
    cp -R /etc/openquake /usr/openquake/engine/celeryconfig.py $OQDIRPATH
    mkdir $OQDIRPATH/postgresql
    cp $PG/pg_hba.conf $PG/postgresql.conf $PG/*.orig $OQDIRPATH/postgresql
}

check_python () {
    local imports=('openquake' 'openquake.hazardlib' 'openquake.risklib' 'openquake.nrmllib' 'celery' 'pippo')

    for i in "${imports[@]}"
    do
        echo "import $i" | python &>> $OQDIRPATH/python-import-errors
    done
}

zip_results () {
    cd /tmp
    echo 'Creating report zip file in '$HOME
    zip -9qr $OQDIR $OQDIR
    cp $OQDIR.zip $HOME
}

mkdir $OQDIRPATH
check_pkg
check_permissions
copy_settings
check_python
zip_results
