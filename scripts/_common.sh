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

get_source() {

    wget -q -O '/tmp/monitorix.deb' 'http://www.monitorix.org/monitorix_3.9.0-izzy1_all.deb'

    if [[ ! -e '/tmp/monitorix.deb' ]] || [[ $(md5sum '/tmp/monitorix.deb' | cut -d' ' -f1) != $md5sum ]]
    then
        ynh_die "Error : can't get monitorix debian package"
    fi
}


CHECK_VAR () {	# Vérifie que la variable n'est pas vide.
# $1 = Variable à vérifier
# $2 = Texte à afficher en cas d'erreur
	test -n "$1" || (echo "$2" >&2 && false)
}

EXIT_PROPERLY () {	# Provoque l'arrêt du script en cas d'erreur. Et nettoye les résidus.
	exit_code=$?
	if [ "$exit_code" -eq 0 ]; then
			exit 0	# Quitte sans erreur si le script se termine correctement.
	fi
	trap '' EXIT
	set +eu
	echo -e "\e[91m \e[1m"	# Shell in light red bold
	echo -e "!!\n  $app install's script has encountered an error. Installation was cancelled.\n!!" >&2

	if type -t CLEAN_SETUP > /dev/null; then	# Vérifie l'existance de la fonction avant de l'exécuter.
		CLEAN_SETUP	# Appel la fonction de nettoyage spécifique du script install.
	fi

	# Compense le bug de ssowat qui ne supprime pas l'entrée de l'app en cas d'erreur d'installation.
	sudo sed -i "\@\"$domain$path/\":@d" /etc/ssowat/conf.json

	ynh_die
}

TRAP_ON () {	# Activate signal capture
	set -eu	# Exit if a command fail, and if a variable is used unset.
	trap EXIT_PROPERLY EXIT	# Capturing exit signals on shell script
}

# Ignore the yunohost-cli log to prevent errors with conditionals commands
# usage: NO_LOG COMMAND
# Simply duplicate the log, execute the yunohost command and replace the log without the result of this command
# It's a very badly hack...
# Petite copie perso à mon usage ;)
NO_LOG() {
  ynh_cli_log=/var/log/yunohost/yunohost-cli.log
  sudo cp -a ${ynh_cli_log} ${ynh_cli_log}-move
  eval $@
  exit_code=$?
  sudo mv ${ynh_cli_log}-move ${ynh_cli_log}
  return $?
}

CHECK_USER () {	# Vérifie la validité de l'user admin
# $1 = Variable de l'user admin.
	ynh_user_exists "$1" || (echo "Wrong admin" >&2 && false)
}

CHECK_PATH () {	# Vérifie la présence du / en début de path. Et son absence à la fin.
	if [ "${path:0:1}" != "/" ]; then    # Si le premier caractère n'est pas un /
		path="/$path"    # Ajoute un / en début de path
	fi
	if [ "${path:${#path}-1}" == "/" ] && [ ${#path} -gt 1 ]; then    # Si le dernier caractère est un / et que ce n'est pas le seul caractère.
		path="${path:0:${#path}-1}"	# Supprime le dernier caractère
	fi
}

CHECK_DOMAINPATH () {	# Vérifie la disponibilité du path et du domaine.
	sudo yunohost app checkurl $domain$path -a $app
}

CHECK_FINALPATH () {	# Vérifie que le dossier de destination n'est pas déjà utilisé.
	final_path=/var/www/$app
	if [ -e "$final_path" ]
	then
		echo "This path already contains a folder" >&2
		false
	fi
}

SETUP_SOURCE () {	# Télécharge la source, décompresse et copie dans $final_path
# $1 = Nom de l'archive téléchargée.
	wget -nv -i ../sources/source_url -O $1
	# Vérifie la somme de contrôle de la source téléchargée.
	md5sum -c ../sources/source_md5 --status || (echo "Corrupt source" >&2 && false)
	# Décompresse la source
	if [ "$(echo ${1##*.})" == "gz" ]; then
		tar -x -f $1
	elif [ "$(echo ${1##*.})" == "zip" ]; then
		unzip -q $1
	else
		false	# Format d'archive non pris en charge.
	fi
	# Copie les fichiers sources
	sudo cp -a $(cat ../sources/source_dir)/. "$final_path"
	# Copie les fichiers additionnels ou modifiés.
	if test -e "../sources/ajouts"; then
		sudo cp -a ../sources/ajouts/. "$final_path"
	fi
}

STORE_MD5_CONFIG () {	# Enregistre la somme de contrôle du fichier de config
# $1 = Nom du fichier de conf pour le stockage dans settings.yml
# $2 = Nom complet et chemin du fichier de conf.
	ynh_app_setting_set $app $1_file_md5 $(sudo md5sum "$2" | cut -d' ' -f1)
}

CHECK_MD5_CONFIG () {	# Créé un backup du fichier de config si il a été modifié.
# $1 = Nom du fichier de conf pour le stockage dans settings.yml
# $2 = Nom complet et chemin du fichier de conf.
	if [ "$(ynh_app_setting_get $app $1_file_md5)" != $(sudo md5sum "$2" | cut -d' ' -f1) ]; then
		sudo cp -a "$2" "$2.backup.$(date '+%d.%m.%y_%Hh%M,%Ss')"	# Si le fichier de config a été modifié, créer un backup.
	fi
}

FIND_PORT () {	# Cherche un port libre.
# $1 = Numéro de port pour débuter la recherche.
	port=$1
	while ! sudo yunohost app checkport $port ; do
		port=$((port+1))
	done
	CHECK_VAR "$port" "port empty"
}


### REMOVE SCRIPT

REMOVE_NGINX_CONF () {	# Suppression de la configuration nginx
	if [ -e "/etc/nginx/conf.d/$domain.d/$app.conf" ]; then	# Delete nginx config
		echo "Delete nginx config"
		sudo rm "/etc/nginx/conf.d/$domain.d/$app.conf"
		sudo service nginx reload
	fi
}

SECURE_REMOVE () {      # Suppression de dossier avec vérification des variables
	chaine="$1"	# L'argument doit être donné entre quotes simple '', pour éviter d'interpréter les variables.
	no_var=0
	while (echo "$chaine" | grep -q '\$')	# Boucle tant qu'il y a des $ dans la chaine
	do
		no_var=1
		global_var=$(echo "$chaine" | cut -d '$' -f 2)	# Isole la première variable trouvée.
		only_var=\$$(expr "$global_var" : '\([A-Za-z0-9_]*\)')	# Isole complètement la variable en ajoutant le $ au début et en gardant uniquement le nom de la variable. Se débarrasse surtout du / et d'un éventuel chemin derrière.
		real_var=$(eval "echo ${only_var}")		# `eval "echo ${var}` permet d'interpréter une variable contenue dans une variable.
		if test -z "$real_var" || [ "$real_var" = "/" ]; then
			echo "Variable $only_var is empty, suppression of $chaine cancelled." >&2
			return 1
		fi
		chaine=$(echo "$chaine" | sed "s@$only_var@$real_var@")	# remplace la variable par sa valeur dans la chaine.
	done
	if [ "$no_var" -eq 1 ]
	then
		if [ -e "$chaine" ]; then
			echo "Delete directory $chaine"
			sudo rm -r "$chaine"
		fi
		return 0
	else
		echo "No detected variable." >&2
		return 1
	fi
}
