#!/bin/bash

# Copyright (c) 2014, Daniele Viganò (daniele.vigano@globalquakemodel.org), GEM Foundation.
#
# OpenQuake is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# OpenQuake is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with OpenQuake.  If not, see <http://www.gnu.org/licenses/>.

DATE=$(date +%Y%m%d%H%M%S)
OQDIR='oq-report-'$DATE
OQDIRPATH='/tmp/'$OQDIR

system_profiler () {
    local system=$OQDIRPATH/system_profile
    local commands=('uname -a' 'lsb_release -a' 'lscpu' 'cat /proc/cpuinfo' 'lsblk' 'mount' 'free -m' 'ps aux')

    for i in "${commands[@]}"
    do
        echo -e "\n#### Start $i ####\n" >> $system
        $i >> $system
        echo -e "\n##### End $i #####\n" >> $system
    done
}

postgres_profiler () {
    local postgres=$OQDIRPATH/postgres_profile

    echo "Gathering information on PostgreSQL"
    echo -e "### Size on disk ###\n" >> $postgres
    du -hs /var/lib/postgresql >> $postgres
    echo -e "\n### Databases size ###\n" >> $postgres
    su - postgres -c 'psql -c "SELECT pg_database.datname, pg_database_size(pg_database.datname), pg_size_pretty(pg_database_size(pg_database.datname)) FROM pg_database ORDER BY pg_database_size DESC;"' >> $postgres
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
    ls -la /usr/openquake /var/lib/openquake /etc/openquake > $OQDIRPATH/permissions
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
    chown -R $SUDO_USER.$SUDO_GROUP $OQDIR*
    cp -a $OQDIR.zip $HOME
}


## Main ##

if [ $(id -u) -gt 0 ]; then
    echo "This script requires sudo. Aborting." >&2
    exit 1
fi

if ! command -v openquake &> /dev/null; then
    if ! command -v oq-engine &> /dev/null; then
        echo "OpenQuake is not installed. Aborting." >&2
        exit 1
    fi
fi

command -v zip &> /dev/null || {
    echo "I require zip but it's not installed. Aborting." >&2
    exit 1
}

mkdir $OQDIRPATH || {
    echo 'I cannot write to '$OQDIRPATH'. Aborting' >&2
    exit 1
}

{
system_profiler
check_pkg
copy_settings
check_python
postgres_profiler
check_permissions
} 2>> $OQDIRPATH/errors.log

## Zip file creation
zip_results
