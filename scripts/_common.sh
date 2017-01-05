#!/bin/bash 

## Adapt md5sum while you update app
md5sum="7314ad6fcd014a34c2e4e8a95455bcaa"

init_script() {
    # Exit on command errors and treat unset variables as an error
    set -eu

    # Source YunoHost helpers
    source /usr/share/yunohost/helpers

    # Retrieve arguments
    app=$YNH_APP_INSTANCE_NAME
}

correct_path() {
    if [ "${path:0:1}" != "/" ] && [ ${#path} -gt 0 ]; then
        path="/$path"
    fi
    if [ "${path:${#path}-1}" == "/" ] && [ ${#path} -gt 1 ]; then
        path="${path:0:${#path}-1}"
    fi
}

get_source() {

    wget -q -O '/tmp/monitorix.deb' 'http://www.monitorix.org/monitorix_3.9.0-izzy1_all.deb'

    if [[ ! -e '/tmp/monitorix.deb' ]] || [[ $(md5sum '/tmp/monitorix.deb' | cut -d' ' -f1) != $md5sum ]]
    then
        ynh_die "Error : can't get monitorix debian package"
    fi
}