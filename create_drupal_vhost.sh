#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 
  exit 1
fi

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
echo -n "Enter BaseURL: "
read BASEURL


#Build stage path
STAGEPATH=$WORKINGPATH"/"$SERVERNAME"/"$CLIENT"/"$PROJECT"/"$STAGE

#Build install path
INSTALLPATH=$WORKINGPATH"/"$SERVERNAME"/"$CLIENT"/"$PROJECT"/"$STAGE"/"$PROJECTID"/drupal-8.x"

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
  cd $STAGE
  mkdir $PROJECTID
  cd $PROJECTID
  mkdir 
fi

echo "Installing...."

#Create apache vhost file
cd $SCRIPTPATH/vhosts
echo "<VirtualHost *:80>
  ServerAdmin webmaster@localhost
  ServerName "$PROJECT"."$BASEURL"
  DocumentRoot $INSTALLATIONDIRECTORY/drupal/
  <Directory $INSTALLATIONDIRECTORY/drupal/>
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
</VirtualHost>" >$SITENAME.conf

#Download Drupal
cd $INSTALLATIONDIRECTORY
mkdir $SITENAME
cd $SITENAME
mkdir htpasswd
cd htpasswd
htpasswd -cb .htpasswd preview pass4$SITENAME
cd ..
mkdir htdocs
cd htdocs
  drush dl drupal
DRUPALDIRECTORYWITHVERSION=$(ls)
  if [ -d "$DRUPALDIRECTORYWITHVERSION" ]; then

  mv $DRUPALDIRECTORYWITHVERSION drupal-8.x
#Configure apache vhost
  if [ -f $SCRIPTPATH/vhosts/$SITENAME.conf ]; then

  echo "Preparing $SITENAME.conf... Enter sudo password:"
  sudo cp $SCRIPTPATH/vhosts/$SITENAME.conf /etc/apache2/sites-available/
  echo "Enabling" $SITENAME".conf... "
  sudo a2ensite $SITENAME.conf
  echo "Reloading apache... "
  sudo service apache2 reload
  rm $SCRIPTPATH/vhosts/$SITENAME.conf
#Create Database and Passwords

  if [ -d "$INSTALLATIONDIRECTORY/$SITENAME/htdocs/drupal-8.x" ]; then
  cd $INSTALLATIONDIRECTORY/$SITENAME/htdocs/drupal-8.x
  DBDRUPALPASS=$(date +%s | sha256sum | base64 | head -c 32)
DRUPALPASS=$(date +%s | sha256sum | base64 | head -c 32)
  echo -n "Enter the root mysql password: "
  read -s DBROOTPASS

#Setup drupal
drush sql-create --db-su=root --db-su-pw=$DBROOTPASS --db-url="mysql://"$PROJECTID":"$DBDRUPALPASS"@localhost/"$PROJECTID
drush si --account-name=wm_$PROJECT --account-pass=$DRUPALPASS --account-mail=$EMAIL --site-name=$PROJECT --db-url="mysql://"$SITENAME"_d8:"$DBDRUPALPASS"@localhost/$SERVERNAME_sub_"$SITENAME"_d8"

#Set permissions, owner and group
echo "Setting Permissions..."
cd $INSTALLATIONDIRECTORY/$SITENAME/htdocs/drupal-8.x
$SCRIPTPATH/file_permissions.sh

#Return information
echo "Site installation complete"
echo "Site URL: $SITENAME."$BASEURL""
echo "Drupal user: wm_$SITENAME"
echo "Drupal password: $DRUPALPASS"
echo "Htaccess User: preview, Password:pass4$SITENAME"
