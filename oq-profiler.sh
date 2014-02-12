#!/bin/bash

DATE=$(date +%Y%m%d%H%M%S)
OQDIR='oq-report-'$DATE
OQDIRPATH='/tmp/'$OQDIR

system_profiler () {
    local system=$OQDIRPATH/system_profile
    local commands=('id' 'lscpu' 'lsblk' 'mount' 'lsb_release -a' 'cat /proc/cpuinfo' 'ps aux')

    for i in "${commands[@]}"
    do
        echo -e "\n#### Start $i ####\n" >> $system
        $i >> $system
        echo -e "\n##### End $i #####\n" >> $system
    done
}

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
    local imports=('openquake' 'openquake.hazardlib' 'openquake.risklib' 'openquake.nrmllib' 'celery')

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


if [ ! -x /usr/bin/openquake ]; then
    echo "OpenQuake is not installed. Exiting."
    exit 1
fi

mkdir $OQDIRPATH || exit 1

{
system_profiler
check_pkg
check_permissions
copy_settings
check_python
} 2>> $OQDIRPATH/errors.log

## Zip file creation
zip_results
