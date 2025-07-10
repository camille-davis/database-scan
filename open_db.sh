#!/bin/bash
# Starts a mysql container and populates it with a given file.
set -e
# Usage: ./open_db.sh sql_file

if [ -z "$1" ] ; then
  echo "Usage: $0 sql_file"
  exit 1
fi
SQL_FILE="$1"
CONTAINER_NAME="mysql-temp-$$" # unique name per run

echo "Starting MySQL container..."
docker run -d --rm \
  --name $CONTAINER_NAME \
  -e MYSQL_ROOT_PASSWORD=rootpassword \
  -e MYSQL_DATABASE=testdb \
  -v $(pwd)/$SQL_FILE:/docker-entrypoint-initdb.d/init.sql \
  -p 3307:3306 \
  mysql:latest > /dev/null

until docker exec $CONTAINER_NAME mysqladmin ping -h 127.0.0.1 -u root -prootpassword --silent > /dev/null 2>&1; do
  sleep 1
done

until docker exec $CONTAINER_NAME mysql -h 127.0.0.1 -u root -prootpassword -e "USE testdb;" 2>/dev/null; do
  sleep 1
done
docker exec -it $CONTAINER_NAME mysql -u root -prootpassword testdb
