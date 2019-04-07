# Read the value of a key in a ynh manifest file
#
# usage: ynh_read_manifest manifest key
# | arg: manifest - Path of the manifest to read
# | arg: key - Name of the key to find
ynh_read_manifest () {
	manifest="$1"
	key="$2"
	python3 -c "import sys, json;print(json.load(open('$manifest', encoding='utf-8'))['$key'])"
}

# Read the upstream version from the manifest 
# The version number in the manifest is defined by <upstreamversion>~ynh<packageversion>
# For example : 4.3-2~ynh3
# This include the number before ~ynh
# In the last example it return 4.3-2
#
# usage: ynh_app_upstream_version
ynh_app_upstream_version () {
    manifest_path="../manifest.json"
    if [ ! -e "$manifest_path" ]; then
        manifest_path="../settings/manifest.json"	# Into the restore script, the manifest is not at the same place
    fi
    version_key=$(ynh_read_manifest "$manifest_path" "version")
    echo "${version_key/~ynh*/}"
}

# Read package version from the manifest
# The version number in the manifest is defined by <upstreamversion>~ynh<packageversion>
# For example : 4.3-2~ynh3
# This include the number after ~ynh
# In the last example it return 3
#
# usage: ynh_app_package_version
ynh_app_package_version () {
    manifest_path="../manifest.json"
    if [ ! -e "$manifest_path" ]; then
        manifest_path="../settings/manifest.json"	# Into the restore script, the manifest is not at the same place
    fi
    version_key=$(ynh_read_manifest "$manifest_path" "version")
    echo "${version_key/*~ynh/}"
}

#!/bin/bash

# Start or restart a service and follow its booting
#
# usage: ynh_check_starting "Line to match" [Log file] [Timeout] [Service name]
#
# | arg: Line to match - The line to find in the log to attest the service have finished to boot.
# | arg: Log file - The log file to watch
# | arg: Service name
# /var/log/$app/$app.log will be used if no other log is defined.
# | arg: Timeout - The maximum time to wait before ending the watching. Defaut 300 seconds.
ynh_check_starting () {
	local line_to_match="$1"
	local service_name="${4:-$app}"
	local app_log="${2:-/var/log/$service_name/$service_name.log}"
	local timeout=${3:-300}

	ynh_clean_check_starting () {
		# Stop the execution of tail.
		kill -s 15 $pid_tail 2>&1
		ynh_secure_remove "$templog" 2>&1
	}

	echo "Starting of $service_name" >&2
	systemctl stop $service_name
	local templog="$(mktemp)"
	# Following the starting of the app in its log
	tail -F -n0 "$app_log" > "$templog" &
	# Get the PID of the tail command
	local pid_tail=$!
	systemctl start $service_name

	local i=0
	for i in `seq 1 $timeout`
	do
		# Read the log until the sentence is found, that means the app finished to start. Or run until the timeout
		if grep --quiet "$line_to_match" "$templog"
		then
			echo "The service $service_name has correctly started." >&2
			break
		fi
		echo -n "." >&2
		sleep 1
	done
	if [ $i -eq $timeout ]
	then
		echo "The service $service_name didn't fully started before the timeout." >&2
	fi

	echo ""
	ynh_clean_check_starting
}

# Delete a file checksum from the app settings
#
# $app should be defined when calling this helper
#
# usage: ynh_remove_file_checksum file
# | arg: file - The file for which the checksum will be deleted
ynh_delete_file_checksum () {
	local checksum_setting_name=checksum_${1//[\/ ]/_}	# Replace all '/' and ' ' by '_'
	ynh_app_setting_delete $app $checksum_setting_name
}

# Download, check integrity, uncompress and patch the source from app.src
#
# The file conf/app.src need to contains:
#
# SOURCE_URL=Address to download the app archive
# SOURCE_SUM=Control sum
# # (Optional) Program to check the integrity (sha256sum, md5sum...)
# # default: sha256
# SOURCE_SUM_PRG=sha256
# # (Optional) Archive format
# # default: tar.gz
# SOURCE_FORMAT=tar.gz
# # (Optional) Put false if sources are directly in the archive root
# # default: true
# SOURCE_IN_SUBDIR=false
# # (Optionnal) Name of the local archive (offline setup support)
# # default: ${src_id}.${src_format}
# SOURCE_FILENAME=example.tar.gz 
# # (Optional) If it set as false don't extract the source.
# # (Useful to get a debian package or a python wheel.)
# # default: true
# SOURCE_EXTRACT=(true|false)
#
# Details:
# This helper downloads sources from SOURCE_URL if there is no local source
# archive in /opt/yunohost-apps-src/APP_ID/SOURCE_FILENAME
#
# Next, it checks the integrity with "SOURCE_SUM_PRG -c --status" command.
#
# If it's ok, the source archive will be uncompressed in $dest_dir. If the
# SOURCE_IN_SUBDIR is true, the first level directory of the archive will be
# removed.
#
# Finally, patches named sources/patches/${src_id}-*.patch and extra files in
# sources/extra_files/$src_id will be applied to dest_dir
#
#
# usage: ynh_setup_source dest_dir [source_id]
# | arg: dest_dir  - Directory where to setup sources
# | arg: source_id - Name of the app, if the package contains more than one app
ynh_setup_source () {
    local dest_dir=$1
    local src_id=${2:-app} # If the argument is not given, source_id equals "app"

    local src_file_path="$YNH_CWD/../conf/${src_id}.src"
    # In case of restore script the src file is in an other path.
    # So try to use the restore path if the general path point to no file.
    if [[ ! -e "$src_file_path" ]]; then
        src_file_path="$YNH_CWD/../settings/conf/${src_id}.src"
    fi

    # Load value from configuration file (see above for a small doc about this file
    # format)
    local src_url=$(grep 'SOURCE_URL=' "$src_file_path" | cut -d= -f2-)
    local src_sum=$(grep 'SOURCE_SUM=' "$src_file_path" | cut -d= -f2-)
    local src_sumprg=$(grep 'SOURCE_SUM_PRG=' "$src_file_path" | cut -d= -f2-)
    local src_format=$(grep 'SOURCE_FORMAT=' "$src_file_path" | cut -d= -f2-)
    local src_extract=$(grep 'SOURCE_EXTRACT=' "$src_file_path" | cut -d= -f2-)
    local src_in_subdir=$(grep 'SOURCE_IN_SUBDIR=' "$src_file_path" | cut -d= -f2-)
    local src_filename=$(grep 'SOURCE_FILENAME=' "$src_file_path" | cut -d= -f2-)

    # Default value
    src_sumprg=${src_sumprg:-sha256sum}
    src_in_subdir=${src_in_subdir:-true}
    src_format=${src_format:-tar.gz}
    src_format=$(echo "$src_format" | tr '[:upper:]' '[:lower:]')
    src_extract=${src_extract:-true}
    if [ "$src_filename" = "" ] ; then
        src_filename="${src_id}.${src_format}"
    fi
    local local_src="/opt/yunohost-apps-src/${YNH_APP_ID}/${src_filename}"

    if test -e "$local_src"
    then    # Use the local source file if it is present
        cp $local_src $src_filename
    else    # If not, download the source
        local out=`wget -nv -O $src_filename $src_url 2>&1` || ynh_print_err $out
    fi

    # Check the control sum
    echo "${src_sum} ${src_filename}" | ${src_sumprg} -c --status \
        || ynh_die "Corrupt source"

    # Extract source into the app dir
    mkdir -p "$dest_dir"
    
    if ! "$src_extract"
    then
        mv $src_filename $dest_dir
    elif [ "$src_format" = "zip" ]
    then 
        # Zip format
        # Using of a temp directory, because unzip doesn't manage --strip-components
        if $src_in_subdir ; then
            local tmp_dir=$(mktemp -d)
            unzip -quo $src_filename -d "$tmp_dir"
            cp -a $tmp_dir/*/. "$dest_dir"
            ynh_secure_remove "$tmp_dir"
        else
            unzip -quo $src_filename -d "$dest_dir"
        fi
    else
        local strip=""
        if $src_in_subdir ; then
            strip="--strip-components 1"
        fi
        if [[ "$src_format" =~ ^tar.gz|tar.bz2|tar.xz$ ]] ; then
            tar -xf $src_filename -C "$dest_dir" $strip
        else
            ynh_die "Archive format unrecognized."
        fi
    fi

    # Apply patches
    if (( $(find $YNH_CWD/../sources/patches/ -type f -name "${src_id}-*.patch" 2> /dev/null | wc -l) > "0" )); then
        local old_dir=$(pwd)
        (cd "$dest_dir" \
            && for p in $YNH_CWD/../sources/patches/${src_id}-*.patch; do \
                patch -p1 < $p; done) \
            || ynh_die "Unable to apply patches"
        cd $old_dir
    fi

    # Add supplementary files
    if test -e "$YNH_CWD/../sources/extra_files/${src_id}"; then
        cp -a $YNH_CWD/../sources/extra_files/$src_id/. "$dest_dir"
    fi
}
