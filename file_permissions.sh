USER=$(logname)
GROUP=$(ps axo user,group,comm | egrep '(apache|httpd)' | grep -v ^root | uniq | cut -d\  -f 2)
chown -R $USER:$GROUP .
find . -type d -exec chmod u=rwxs,g=rxs,o= '{}' \;
find . -type f -exec chmod u=rw,g=r,o= '{}' \;
cd sites
find . -type d -name files -exec chmod ug=rwxs,o= '{}' \;
  for d in ./*/files
    do
      find $d -type d -exec chmod ug=rwxs,o= '{}' \;
      find $d -type f -exec chmod ug=rw,o= '{}' \;
    done
