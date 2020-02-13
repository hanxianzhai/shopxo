#!/bin/sh
set -eu

# version_greater A B returns whether A > B
version_greater() {
    [ "$(printf '%s\n' "$@" | sort -t '.' -n -k1,1 -k2,2 -k3,3 | head -n 1)" != "$1" ]
}
# return true if specified directory is empty
directory_empty() {
    [ -z "$(ls -A "$1/")" ]
}


if expr "$1" : "apache" 1>/dev/null || [ "$1" = "supervisord" ] || [ "$1" = "php-fpm" ] || [ "${UPDATE:-0}" -eq 1 ]; then 
    installed_version="0.0.0.0"
    if [ -f /var/www/html/application/index/view/default/config.json ]; then
        # shellcheck disable=SC2016
        installed_version="$(php -r '$array = json_decode(file_get_contents("/var/www/html/application/index/view/default/config.json"),true); echo $array["ver"];')"
    fi
    # shellcheck disable=SC2016
    image_version="$(php -r '$array = json_decode(file_get_contents("/usr/src/shopxo/application/index/view/default/config.json"),true); echo $array["ver"];')"

    if version_greater "$installed_version" "$image_version"; then
        echo "Can't start shopxo because the version of the data ($installed_version) is higher than the docker image version ($image_version) and downgrading is not supported. Are you sure you have pulled the newest image version?"
        exit 1
    fi

    if version_greater "$image_version" "$installed_version"; then
        echo "Initializing shopxo $image_version ..."
        if [ "$installed_version" != "0.0.0.0" ]; then
            echo "Upgrading shopxo from $installed_version ..."
            
        fi
        if [ "$(id -u)" = 0 ]; then
            rsync_options="-rlDog --chown www-data:root"
        else
            rsync_options="-rlD"
        fi
        rsync $rsync_options --delete --exclude-from=/upgrade.exclude /usr/src/shopxo/ /var/www/html/

        for dir in config ; do
            if [ ! -d "/var/www/html/$dir" ] || directory_empty "/var/www/html/$dir"; then
                rsync $rsync_options --include "/$dir/" --exclude '/*' /usr/src/shopxo/ /var/www/html/
            fi
        done
        rsync $rsync_options --include '/version.php' --exclude '/*' /usr/src/shopxo/ /var/www/html/
        echo "Initializing finished"

        #install
        if [ "$installed_version" = "0.0.0.0" ]; then
            rsync $rsync_options /usr/src/shopxo/ /var/www/html/
        fi
    fi    
fi

exec "$@"