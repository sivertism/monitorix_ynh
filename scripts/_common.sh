#=================================================
# SET ALL CONSTANTS
#=================================================

app=$YNH_APP_INSTANCE_NAME

#=================================================
# DEFINE ALL COMMON FONCTIONS
#=================================================

install_dependances() {
	ynh_install_app_dependencies rrdtool perl libwww-perl libmailtools-perl libmime-lite-perl librrds-perl libdbi-perl libxml-simple-perl libhttp-server-simple-perl libconfig-general-perl pflogsumm
}

get_install_source() {
	ynh_setup_source /tmp

	ynh_package_update
	dpkg --force-confdef --force-confold -i /tmp/app.deb
	ynh_secure_remove /etc/monitorix/conf.d/00-debian.conf
	ynh_package_install -f
}

config_nginx() {
    ynh_add_nginx_config

    # Add special hostname for monitorix status
	nginx_status_conf="/etc/nginx/conf.d/monitorix_status.conf"
	cp ../conf/nginx_status.conf $nginx_status_conf
	ynh_replace_string __PORT__ $nginx_status_port $nginx_status_conf

    systemctl reload nginx
}

config_monitorix() {
	monitorix_conf=/etc/monitorix/monitorix.conf
	cp ../conf/monitorix.conf $monitorix_conf 
	ynh_replace_string __SERVICE_PORT__ $port $monitorix_conf
	ynh_replace_string __YNH_DOMAIN__ $domain $monitorix_conf
	ynh_replace_string __NGINX_STATUS_PORT__ $nginx_status_port $monitorix_conf
	ynh_replace_string "__YNH_WWW_PATH__/" "${path_url%/}/" $monitorix_conf
	ynh_replace_string __YNH_WWW_PATH__ $path_url $monitorix_conf
	ynh_replace_string __MYSQL_USER__ $dbuser $monitorix_conf
	ynh_replace_string __MYSQL_PASSWORD__ $dbpass $monitorix_conf
}

set_permission() {
    chown www-data:root -R /etc/monitorix
    chmod u=rX,g=rwX,o= -R /etc/monitorix
    chown www-data:root -R /var/lib/monitorix
    chmod u=rwX,g=rwX,o= -R /var/lib/monitorix
}
