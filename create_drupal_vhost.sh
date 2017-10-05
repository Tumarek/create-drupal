#!/bin/bash

# ====== Check requirements ======
echo "Installing Drupal"

echo "Checking dependencies"

#Load default config
source ./default.cnfg

#Find out which User exectue the script
USER=$(logname)
echo "Drupal will be installed for: "$USER"!"

#Check if we have root.
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 
  exit 1
fi

#
command -v composer >/dev/null 2>&1 || { echo >&2 "Composer is required but not installed.  Aborting.";

#Define path the script is in.
SCRIPT=$(readlink -f "$0")

# Absolute path this script is in.
SCRIPTPATH=$(dirname "$SCRIPT")

#Define web working path
WORKINGPATH=/var/www

#Define server name
echo -n "Enter Servername: "
read SERVERNAME

#Define client name.
echo -n "Enter clientname: "
read CLIENT

#Define project name.
echo -n "Enter the project name: " 
read PROJECT

#Define stage directory
echo  "Stage is development."
STAGE=dev

#Define client shortcut
echo -n "Enter short client name: "
read CLIENTSHORT

#Define project id 
PROJECTID=$CLIENTSHORT"_"$PROJECT"_d8"
if [ ${#PROJECTID} -gt 12 ]
then
  echo Project ID Too long - 12 characters max
  exit 1
else
fi

#Define base URL
if [ -z "BASEURL" ]
then
  echo -n "Enter base URL for the site: "
  read BASEURL
else
  echo -n "Base URL is set to " $BASEURL
fi

#Build stage path
STAGEPATH=$WORKINGPATH"/"$SERVERNAME"/"$CLIENT"/"$PROJECT"/"$STAGE

#Build install path
INSTALLPATH=$WORKINGPATH"/"$SERVERNAME"/"$CLIENT"/"$PROJECT"/"$STAGE"/"$PROJECTID"/web"

echo "Project Id will be: "$PROJECTID
echo "Drupal will be installed in: "$INSTALLPATH
echo "Your site will be called: "$PROJECT", the domain will be: "$PROJECT"."$BASEURL

#Check if client already exists and create if neccesary
cd $WORKINGPATH"/"$SERVERNAME"/" 
if [ -d "$CLIENT" ];
then
  echo $CLIENT" already exists and Project will be added..."
else
  mkdir $CLIENT
fi

#Check if project already exists.
cd $WORKINGPATH"/"$SERVERNAME"/"$CLIENT 
if [ -d "$PROJECT" ];
then
  echo $PROJECT "is already taken...  Aborting"
  exit 1
else
  mkdir $PROJECT
  cd $PROJECT
  mkdir $STAGE
fi

echo "Installing...."

# ====== Download Drupal ====== 
#Create htaccess
mkdir htpasswd
cd htpasswd
htpasswd -cb .htpasswd preview pass4$PROJECTID

#Change permissions to development user
cd $WORKINGPATH"/"$SERVERNAME"/"$CLIENT                                                                                              
chown -R $USER:$USER * .[^.]*

#Install drupal
cd $STAGEPATH 
su - $USER -c composer create-project drupal-composer/drupal-project:8.x-dev $PROJECTID --stability dev --no-interaction  

# ====== Prepare Apache vhost ======
#Create apache vhost file
cat > /ect/apache2/sites-available/$PROJECTID.conf << EOF
<VirtualHost *:80>
  ServerAdmin webmaster@localhost
  ServerName "$PROJECTID"."$BASEURL"
  DocumentRoot $INSTALLPATH
  <Directory $INSTALLPATH>
    Options FollowSymlinks
    #Require all granted

    AuthType Basic
    AuthName 'Authentication Required'
    AuthUserFile $STAGEPATH/"htpasswd/.htpasswd"
    Require user preview

    AllowOverride All
  </Directory>

  ErrorLog \${APACHE_LOG_DIR}/"$PROJECTID"_error.log
  LogLevel warn
  CustomLog \${APACHE_LOG_DIR}/"$PROJECTID"_access.log combined
</VirtualHost>" >
EOF

echo "Enabling" $PROJECTID".conf... "
a2ensite $PROJECTID.conf
echo "Reloading apache... "
service apache2 reload

#Create Database and Passwords
  if [ -d "$INSTALLPATH" ]; then
  cd $INSTALLPATH
  DBDRUPALPASS=$(date +%s | sha256sum | base64 | head -c 32)
  DRUPALPASS=$(date +%s | sha256sum | base64 | head -c 32)
  echo -n "Enter the root mysql password: "
  read -s DBROOTPASS

#Setup drupal
drush sql-create --db-su=root --db-su-pw=$DBROOTPASS --db-url="mysql://"$PROJECTID":"$DBDRUPALPASS"@localhost/"$PROJECTID
drush si --account-name=wm_$PROJECT --account-pass=$DRUPALPASS --account-mail=$EMAIL --site-name=$PROJECT --db-url="mysql://"$PROJECTID"_d8:"$DBDRUPALPASS"@localhost/$SERVERNAME_sub_"$PROJECTID"_d8"

#Set permissions, owner and group
echo "Setting Permissions..."
cd $INSTALLPATH
$SCRIPTPATH/file_permissions.sh

#Create git repository and edit .gitignore
cd $STAGEPATH
git init
cd $INSTALLPATH/..


#Return information
echo "Site installation complete"
echo "Site URL: $PROJECTID."$BASEURL""
echo "Drupal user: wm_$PROJECTID"
echo "Drupal password: $DRUPALPASS"
echo "Htaccess User: preview, Password:pass4$PROJECTID"
