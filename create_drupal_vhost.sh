#!/bin/bash


#Define path the script is in.
SCRIPT=$(readlink -f "$0")

# Absolute path this script is in.
SCRIPTPATH=$(dirname "$SCRIPT")

#Define web working path
WORKINGPATH=/var/www
echo $WORKINGPATH

#Define server name
SERVERNAME=batou

#Define base URL
read BASEURL

#Define stage directory
STAGEPATH=dev

#Define client name.
echo -n "Enter the name of the client: "

ok=0
while [ $ok = 0 ]
do
  echo "Enter the id: " 
  read CLIENT
  if [ ${#CLIENT} -gt 12 ]
  then
    echo Too long - 12 characters max
  else
    ok=1
fi
done

#Define project name.
echo -n "Enter the name of the project: "

ok=0
while [ $ok = 0 ]
do
  echo "Enter the id: " 
  read PROJECT
  if [ ${#PROJECT} -gt 12 ]
  then
    echo Too long - 12 characters max
  else
    ok=1
fi
done

#Build install path
INSTALLPATH=$WORKINGPATH"/"$SERVERNAME"/"$CLIENT"/"$PROJECT"/"

<<'COMMENT'
echo "Your site will be called: "$SITENAME", the domain will be: "$SITENAME"."$BASEURL" and be installed in" $INSTALLATIONDIRECTORY"/"$SITENAME

#Check if project already exists.
cd $INSTALLATIONDIRECTORY
 if [ -d "$SITENAME" ]; then
   echo $SITENAME "is already taken...  Aborting"
 else
  
  echo "Installing...."
  
  #Create apache vhost file
  cd $SCRIPTPATH/vhosts
  echo "<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    ServerName "$SITENAME"."$BASEURL"
    DocumentRoot $INSTALLATIONDIRECTORY/"$SITENAME"/htdocs/drupal-8.x/
    <Directory $INSTALLATIONDIRECTORY/"$SITENAME"/htdocs/drupal-8.x/>
      Options FollowSymlinks
      
      #Require all granted
      
      AuthType Basic
      AuthName 'Authentication Required'
      AuthUserFile "$INSTALLATIONDIRECTORY"/"$SITENAME"/htpasswd/.htpasswd
      Require user preview

      AllowOverride All
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/"$BASEURL"_sub_"$SITENAME"_error.log
    LogLevel warn
    CustomLog \${APACHE_LOG_DIR}/"$BASEURL"_sub_"$SITENAME"_access.log combined
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
        drush sql-create --db-su=root --db-su-pw=$DBROOTPASS --db-url="mysql://"$SITENAME"_d8:"$DBDRUPALPASS"@localhost/$SERVERNAME_sub_"$SITENAME"_d8"
        drush si --account-name=wm_$SITENAME --account-pass=$DRUPALPASS --account-mail=$EMAIL --site-name=$SITENAME --db-url="mysql://"$SITENAME"_d8:"$DBDRUPALPASS"@localhost/$SERVERNAME_sub_"$SITENAME"_d8"

        #Set permissions, owner and group
        echo "Setting Permissions..."
        cd $INSTALLATIONDIRECTORY/$SITENAME/htdocs/drupal-8.x
        chown -R dev:www-data $INSTALLATIONDIRECTORY/$SITENAME
        find . -type d -exec chmod u=rwxs,g=rxs,o= '{}' \;
        find . -type f -exec chmod u=rw,g=r,o= '{}' \;
        cd sites
        find . -type d -name files -exec chmod ug=rwxs,o= '{}' \;
        for d in ./*/files
        do
          find $d -type d -exec chmod ug=rwxs,o= '{}' \;
          find $d -type f -exec chmod ug=rw,o= '{}' \;
        done
        
        echo "Site installation complete"
        echo "Site URL: $SITENAME."$BASEURL""
        echo "Drupal user: wm_$SITENAME"
        echo "Drupal password: $DRUPALPASS"
        echo "Htaccess User: preview, Password:pass4$SITENAME"
      else
        echo "Somthing with the Installdirectories went wrong... Aborting"
      fi

    else
      echo "Vhost could not be created... Aborting"
    fi

  else
    echo "Drupal could not be downloaded... Aborting"
  fi
fi
COMMENT
