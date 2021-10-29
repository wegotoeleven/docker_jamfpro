#!/bin/zsh
# shellcheck shell=bash

if /usr/local/bin/docker network ls | grep -i jamf_net > /dev/null 2>&1
then
    /usr/local/bin/docker network create jamf_net
fi

if [ ! -e ./my.cnf ]
then
    echo "Creating my.cnf..."
    cat > ./my.cnf << EOF
[mysqld]
default-authentication-plugin=mysql_native_password
EOF
fi

/usr/local/bin/docker run \
    --rm \
    --detach \
    --name jamf_mysql \
    --net jamf_net \
    --env MYSQL_ROOT_PASSWORD=jamfsw03 \
    --env MYSQL_DATABASE=jamfsoftware \
    --publish 3306:3306 \
    --mount type=bind,source="${PWD}/my.cnf",target="/etc/mysql/conf.d/my.cnf" \
    mysql:8 

/usr/local/bin/docker exec jamf_mysql \
    mysql -u root \
    -pjamfsw03 \
    -e "GRANT ALL ON *.* TO 'root'@'%';"

read -p "Upload Jamf Pro database and press any key to continue..."

if [ ! -e ./ROOT.war ]
then
    echo "ROOT.war not available. Please type path to ROOT.war..."
    read -r PATH_TO_ROOT
    cp "${PATH_TO_ROOT}" ./ROOT.war
fi

/usr/local/bin/docker run \
    --name jamf_pro \
    --net jamf_net \
    --env DATABASE_USERNAME=root \
    --env DATABASE_PASSWORD=jamfsw03 \
    --env DATABASE_HOST=jamf_mysql \
    --publish 80:8080 \
    --mount type=bind,source="${PWD}/ROOT.war",target="/data/ROOT.war" \
    jamf/jamfpro:latest