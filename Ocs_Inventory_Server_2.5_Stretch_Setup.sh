#
#!/bin/bash
#
# Développé sur Debian 9.5.0
# By : ZOUZAC F. 2018
# Mail : florent.zouzac@gmail.com
#
patsh=$PWD
ficsh=$0
if readlink /proc/$$/exe | grep -q "dash"; then
	echo "Ce script doit être éxécuter avec 'bin/bash' et non avec 'sh' "
	exit
fi
if [[ -e /etc/debian_version ]]; then
	OS=debian
else
	echo "Ce script doit être éxécuter sur 'Debian' !"
	exit
fi
if [[ "$EUID" -ne 0 ]]; then
	echo "Vous devez éxécuter avec 'root' !"
	exit
fi
if [[ ! -e /etc/apache2 ]]; then
	instlamp='apache2'
fi

if [[ ! -e /etc/mysql ]]; then
	instlamp=$instlamp" "'mariadb-server'
fi

if [[ ! -e /etc/php ]]; then
	instlamp=$instlamp" "'php'
fi
clear
if [[ ! -z "$instlamp" ]]; then
	echo "##########################################################"
	echo "# Bienvenue dans l'installation du serveur Ocs Inventory #"
	echo "##########################################################"
	echo ""
	echo "Attention ! le script va télécharger les paquets suivants : $instlamp ."
	echo ""
	echo "Appuyer sur ENTREE pour continuer CTRL+C pour quitter"
	read break
	apt update
	apt upgrade -y
	apt install $instlamp -y
fi
echo $instlamp | grep "mariadb-server" >/dev/null
if [[ "$?" == "0" ]]; then
	mysql_secure_installation
fi
clear
echo "LAMP : OK ;-)"
echo "###############################################"
echo "# Paramétrage de MySQL pour OCS Inventory ... #"
echo "###############################################"
echo ""
read -p "Créer un nouvel utilisateur et une nouvelle base de donnée ?(y/[n])" option4
if [[ "$option4" == "y" ]]; then
	read -p "Nouveau Nom d'utilisatreur MySQL : " name
	read -p "Nouveau Mot de passe : " pass
	read -p "Nouveau Nom de la base de donnée MySQL : " namesql
	if [[ -z "$name" ]]; then
		clear
		echo "Nom d'utilisateur vide !"
		exit
	fi
	if [[ -z "$pass" ]]; then
		clear
		echo "Mot de passe vide !"
		exit
	fi
	if [[ -z "$namesql" ]]; then
		clear
		echo "Nom de base de donnée vide !"
		exit
	fi
	mysql -uroot -e "CREATE DATABASE ${namesql} CHARACTER SET utf8";
	mysql -uroot -e "CREATE USER ${name}@'%' IDENTIFIED BY '${pass}'";
	mysql -uroot -e "GRANT ALL PRIVILEGES ON ${namesql} . * TO ${name}@'%'";
	mysql -uroot -e "FLUSH PRIVILEGES";
		if [[ "$?" -ne "0" ]]; then
			echo "ERREUR LIGNES 79-82 :-("
		exit
		fi
else
	read -p "Nom d'utilisatreur MySQL déjà éxistant et dédié à Ocs Inventory : " name
	read -p "Mot de passe : " pass
	read -p "Nom de la base de donnée MySQL déjà éxistante et dédié à Ocs Inventory : " namesql
	if [[ -z "$name" ]]; then
		clear
		echo "Nom d'utilisateur vide !"
		exit
	fi
	if [[ -z "$pass" ]]; then
		clear
		echo "Mot de passe vide !"
		exit
	fi
	if [[ -z "$namesql" ]]; then
		clear
		echo "Nom de base de donnée vide !"
		exit
	fi
fi
clear
echo "LAMP : OK ;-)"
echo "MySQL OK ;-)"
echo "##################################################################"
echo "# Téléchargement de OCS Inventory ...                            #"
echo "##################################################################"
echo ""
echo "Appuyer sur ENTREE pour continuer ..."
read break
apt install make perl libxml-simple-perl libperl5.24 libdbi-perl libdbd-mysql-perl libapache-dbi-perl libnet-ip-perl libsoap-lite-perl -y
if [[ "$?" -ne "0" ]]; then
		echo "ERREUR LIGNE 116 :-("
		exit
fi
apt install build-essential libmojolicious-perl php-pclzip build-essential libdbd-mysql-perl libnet-ip-perl libxml-simple-perl -y
if [[ "$?" -ne "0" ]]; then
		echo "ERREUR LIGNE 121 :-("
		exit
fi
apt install libarchive-zip-perl php-gd php-mbstring php-soap php-mysql php-curl php-xml php-zip -y
if [[ "$?" -ne "0" ]]; then
		echo "ERREUR LIGNE 126 :-("
		exit
fi
cpan install XML::Entities Plack::Handler::Apache2
if [[ "$?" -ne "0" ]]; then
		echo "ERREUR LIGNE 131 :-("
		exit
fi
cd ~
wget https://github.com/OCSInventory-NG/OCSInventory-ocsreports/releases/download/2.5/OCSNG_UNIX_SERVER_2.5.tar.gz
tar -xvf OCSNG_UNIX_SERVER_2.5.tar.gz
cd OCSNG_UNIX_SERVER_2.5
sed -i '1893c cd '"$patsh"'' /root/OCSNG_UNIX_SERVER_2.5/setup.sh
sed -i '1894a bash '"$ficsh"'' /root/OCSNG_UNIX_SERVER_2.5/setup.sh
clear
sh setup.sh
sed -i '1893c exit 1' /root/OCSNG_UNIX_SERVER_2.5/setup.sh
sed -i '1894d' /root/OCSNG_UNIX_SERVER_2.5/setup.sh
chown www-data:www-data /var/lib/ocsinventory-reports/
if [[ -e /etc/apache2/conf-available/z-ocsinventory-server.conf ]]; then
	sed -i '26c\ \ PerlSetEnv OCS_DB_NAME '"$namesql"'' /etc/apache2/conf-available/z-ocsinventory-server.conf
	sed -i '27c\ \ PerlSetEnv OCS_DB_LOCAL '"$namesql"'' /etc/apache2/conf-available/z-ocsinventory-server.conf
	sed -i '29c\ \ PerlSetEnv OCS_DB_USER '"$name"'' /etc/apache2/conf-available/z-ocsinventory-server.conf
	sed -i '31c\ \ PerlSetVar OCS_DB_PWD '"$pass"'' /etc/apache2/conf-available/z-ocsinventory-server.conf
else
	echo "/etc/apache2/conf-available/z-ocsinventory-server.conf" est introuvable ! 
	exit
fi
if [[ -e /etc/apache2/conf-available/z-ocsinventory-server.conf ]]; then
	a2enconf z-ocsinventory-server.conf
else
	echo "/etc/apache2/conf-available/z-ocsinventory-server.conf" est introuvable ! 
	exit
fi
if [[ -e /etc/apache2/conf-available/ocsinventory-reports.conf ]]; then
	a2enconf ocsinventory-reports.conf
else
	echo "/etc/apache2/conf-available/ocsinventory-reports.conf" est introuvable ! 
	exit
fi
systemctl reload apache2
if [[ "$?" -eq "0" ]]; then
	echo "reload apache2 : OK ! ;-)"
else
	clear
	echo "!!Aie !! apache2 n'a pas redémarré correctement :-("
	exit
fi
if [[ -e /etc/apache2/conf-enabled/ocsinventory-reports.conf ]]; then
	echo "+ --------------------------------------------------------------------------------- + "
	echo "| Une fois la configuration terminée, il est vivement recommandé de faire             "
	echo "| un "rm /usr/share/ocsinventory-reports/ocsreports/install.php".                     "
	echo "| Les identifiants SQL pour la base $namesql sont stockés dans                        "
	echo "| "/etc/apache2/conf-available/z-ocsinventory-server.conf"                            "
	echo "+ --------------------------------------------------------------------------------- + "
	echo ""
fi
read -p "Configurer un nom d'hôte sécurisé à l'aide d'un certificat auto-signé ? (y/[n]) : " sethttps
if [[ "$sethttps" == "y" ]] || [[ "$sethttps" == "Y" ]] || [[ "$sethttps" == "yes" ]] || [[ "$sethttps" == "Yes" ]]; then
	read -p 'Entrer le nom de dommaine du site (exemple.fr) : ' ndomaine
	if [[ -e /etc/ssl/openssl.cnf ]] && [[ ! -z "$ndomaine" ]]; then
		if [[ ! -e /etc/ssl/$ndomaine ]]; then
			mkdir /etc/ssl/$ndomaine/
			cd /etc/ssl/$ndomaine/
			openssl genrsa -out $ndomaine.key 2048
			openssl req -new -key $ndomaine.key -out $ndomaine.csr
			openssl x509 -req -days 365 -in $ndomaine.csr -signkey $ndomaine.key -out $ndomaine.crt
		else
			echo "! Création du certificat impossible car dossier $ndomaine déjà existant !"
			read -p 'Supprimer dossier existant ?([y]/n)' removecert
			if [[ "$removecert" != "n" ]] && [[ "$removecert" != "N" ]]; then
				rm -rf /etc/ssl/$ndomaine
				mkdir /etc/ssl/$ndomaine/
				cd /etc/ssl/$ndomaine/
				openssl genrsa -out $ndomaine.key 2048
				openssl req -new -key $ndomaine.key -out $ndomaine.csr
				openssl x509 -req -days 365 -in $ndomaine.csr -signkey $ndomaine.key -out $ndomaine.crt
			else
				echo "! Création du certificat impossible car dossier $ndomaine déjà existant !"
				exit
			fi
		fi
	else
		clear
		echo '/!\ openssl non installé ou nom de domaine vide /!\'
		exit
	fi
	echo "<VirtualHost *:80>
        ServerName $ndomaine
        RewriteEngine on
        RewriteCond %{SERVER_NAME} =$ndomaine
        RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,QSA,R=permanent]
</VirtualHost>
<VirtualHost *:443>
        ServerName $ndomaine
        SSLEngine on
        SSLCertificateFile      /etc/ssl/$ndomaine/$ndomaine.crt
        SSLCertificateKeyFile   /etc/ssl/$ndomaine/$ndomaine.key
        DocumentRoot /usr/share/ocsinventory-reports/ocsreports/
	<Directory /usr/share/ocsinventory-reports/ocsreports/>
                Options +FollowSymlinks
        </Directory>
</VirtualHost>" >/etc/apache2/sites-available/$ndomaine.conf
	sed -i '23c#Alias /ocsreports /usr/share/ocsinventory-reports/ocsreports' /etc/apache2/conf-available/ocsinventory-reports.conf
	a2enmod ssl rewrite
	a2ensite $ndomaine
	systemctl restart apache2
	if [[ "$?" -eq "0" ]]; then
		echo "reload apache2 : OK ! ;-)"
	else
		clear
		echo "!! Aie !! apache2 n'a pas redémarré correctement :-("
		exit
	fi
else
	exit
fi
if [[ -e /etc/apache2/sites-available/$ndomaine.conf ]]; then
	echo "+ --------------------------------------------------------------------------------- + "
	echo "| - Une fois la configuration web terminée, il est vivement recommandé de faire       "
	echo "| un 'rm /usr/share/ocsinventory-reports/ocsreports/install.php'                      "
	echo "| - Les identifiants SQL pour la base $namesql sont stockés dans                      "
	echo "| '/etc/apache2/conf-available/z-ocsinventory-server.conf'                            "
	echo "| - L'hôte virtuel est configuré dans /etc/apache2/sites-available/$ndomaine.conf    "
	echo "| Acheter le nom de domaine $ndomaine ou configurer serveur DNS ou fichiers hosts	    "
	echo "| &&	Rendez-vous sur https://$ndomaine					    "
	echo "+ --------------------------------------------------------------------------------- + "
	echo ""
else
	echo '/!\ Configuration HTTPS FAIL /!\'
fi
exit
#################################################################################################
