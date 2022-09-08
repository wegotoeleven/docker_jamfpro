#!/bin/zsh
# shellcheck shell=bash

if ! /usr/local/bin/docker network ls | grep -i jamf_net > /dev/null 2>&1; then
    /usr/local/bin/docker network create jamf_net
fi

if [[ ! -e ./my.cnf ]]; then
    echo "Creating my.cnf..."
    cat > ./my.cnf << EOF
[mysqld]
default-authentication-plugin=mysql_native_password
EOF
fi

echo "Running jamf_mysql container..."
/usr/local/bin/docker run \
    --rm \
    --detach \
    --name jamf_mysql \
    --net jamf_net \
    --env MYSQL_ROOT_PASSWORD=jamfsw03 \
    --env MYSQL_DATABASE=jamfsoftware \
    --publish 3306:3306 \
    --mount type=bind,source="${PWD}/share",target="/share" \
    --mount type=bind,source="${PWD}/my.cnf",target="/etc/mysql/conf.d/my.cnf" \
    arm64v8/mysql:oracle

# Sleep to ensure that mysql is running
sleep 10

echo "Settings grants in jamf_mysql..."
/usr/local/bin/docker exec jamf_mysql \
    mysql -u root \
    -pjamfsw03 \
    -e "GRANT ALL ON *.* TO 'root'@'%';"

read -s -k $'?Upload Jamf Pro database and press any key to continue...\n'

if [[ ! -e ./ROOT.war ]]; then
    echo "ROOT.war not available. Please type path to ROOT.war..."
    read -r PATH_TO_ROOT
    cp "${PATH_TO_ROOT}" ./ROOT.war
fi

echo "Running jamf_pro container..."
/usr/local/bin/docker run \
    --name jamf_pro \
    --net jamf_net \
    --env DATABASE_USERNAME=root \
    --env DATABASE_PASSWORD=jamfsw03 \
    --env DATABASE_HOST=jamf_mysql \
    --publish 80:8080 \
    --mount type=bind,source="${PWD}/share",target="/share" \
    --mount type=bind,source="${PWD}/ROOT.war",target="/data/ROOT.war" \
    jamf/jamfpro:latest

# Connect to container: /usr/local/bin/docker exec -ti jamf_mysql /bin/bash
# Dump database, on mysql box: mysqldump -u root -p jamfsoftware --set-gtid-purged=OFF | gzip -9 > /share/database-2022-07-04.sql.gz