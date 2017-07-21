#!/bin/bash 

app=$YNH_APP_INSTANCE_NAME

## Adapt md5sum while you update app
md5sum="7314ad6fcd014a34c2e4e8a95455bcaa"
monitorix_version="3.9.0"

install_dependances() {
	ynh_install_app_dependencies rrdtool perl libwww-perl libmailtools-perl libmime-lite-perl librrds-perl libdbi-perl libxml-simple-perl libhttp-server-simple-perl libconfig-general-perl pflogsumm
	ynh_package_update
	dpkg -i /tmp/monitorix.deb
	ynh_secure_remove /etc/monitorix/conf.d/00-debian.conf
	ynh_package_install -f
}

get_source() {
    wget -q -O '/tmp/monitorix.deb' "http://www.monitorix.org/monitorix_${monitorix_version}-izzy1_all.deb"

    if [[ ! -e '/tmp/monitorix.deb' ]] || [[ $(md5sum '/tmp/monitorix.deb' | cut -d' ' -f1) != $md5sum ]]
    then
        ynh_die "Error : can't get monitorix debian package"
    fi
}

config_nginx() {
	nginx_conf=../conf/nginx.conf
	ynh_replace_string __YNH_WWW_PATH__ $path $nginx_conf
	ynh_replace_string __SERVICE_PORT__ $http_port $nginx_conf
	cp $nginx_conf /etc/nginx/conf.d/$domain.d/$app.conf
	
	# Add special hostname for monitorix status
	nginx_status_conf=../conf/nginx_status.conf
	ynh_replace_string PORT $nginx_status_port $nginx_status_conf
	cp $nginx_status_conf /etc/nginx/conf.d/monitorix_status.conf
	
	systemctl reload nginx.service
}

config_monitorix() {
	monitorix_conf=../conf/monitorix.conf
	ynh_replace_string __SERVICE_PORT__ $http_port $monitorix_conf
	ynh_replace_string __YNH_DOMAIN__ $domain $monitorix_conf
	ynh_replace_string __NGINX_STATUS_PORT__ $nginx_status_port $monitorix_conf
	ynh_replace_string __YNH_WWW_PATH__ $path $monitorix_conf
	ynh_replace_string __MYSQL_USER__ $dbuser $monitorix_conf
	ynh_replace_string MYSQL_PASSWORD $dbpass $monitorix_conf
	cp $monitorix_conf /etc/monitorix/monitorix.conf
}