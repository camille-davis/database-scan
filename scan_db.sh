#!/bin/bash
set -e # exit on error

# Get args.
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 sql_file patterns_file"
  echo "patterns_file should include one pattern per line."
  exit 1
fi
SQL_FILE="$1"
PATTERNS_FILE="$2"
CONTAINER_NAME="mysql-temp-$$" # unique name per run
SQL_TMPFILE=$(mktemp)

# If the script is interrupted, stop the container.
cleanup() {
  docker stop $CONTAINER_NAME > /dev/null 2>&1 || true
}
trap cleanup INT TERM EXIT

echo "Starting MySQL container..."
docker run -d --rm \
  --name $CONTAINER_NAME \
  -e MYSQL_ROOT_PASSWORD=rootpassword \
  -e MYSQL_DATABASE=testdb \
  -v $(pwd)/$SQL_FILE:/docker-entrypoint-initdb.d/init.sql \
  -p 3307:3306 \
  mysql:latest > /dev/null

echo "Waiting for database to be ready..."
until docker exec $CONTAINER_NAME mysqladmin ping -h 127.0.0.1 -u root -prootpassword --silent > /dev/null 2>&1; do
  sleep 1
done
until docker exec $CONTAINER_NAME mysql -h 127.0.0.1 -u root -prootpassword -e "USE testdb;" 2>/dev/null; do
  sleep 1
done

# Create a temporary SQL file. Add a temporary table to store scan results.
cat <<EOF > "$SQL_TMPFILE"
USE testdb;
CREATE TABLE scan_search_results (
    table_name VARCHAR(100),
    column_name VARCHAR(100),
    pattern_found VARCHAR(200),
    row_id VARCHAR(50),
    sample_data TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF

echo "Searching for patterns..."

# Get each column in "table column" format.
columns=$(docker exec $CONTAINER_NAME mysql -h 127.0.0.1 -u root -prootpassword -N -e \
  "SELECT TABLE_NAME, COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='testdb' AND DATA_TYPE IN ('char','varchar','text','tinytext','mediumtext','longtext');" 2>/dev/null)

# Go through the patterns file line by line.
while IFS= read -r pattern; do

    # Skip empty lines.
    [[ -z "$pattern" ]] && continue

    # For each column, add a statement to the SQL file that inserts pattern matches into scan_search_results.
    while IFS=$'\t' read -r table column; do
        echo "INSERT INTO scan_search_results (table_name, column_name, pattern_found, sample_data)" >> "$SQL_TMPFILE"
        echo "SELECT '$table', '$column', '$pattern', LEFT($column, 200) FROM $table WHERE LOWER($column) LIKE LOWER('%$pattern%');" >> "$SQL_TMPFILE"
    done <<< "$columns"
done < "$PATTERNS_FILE"

# Add a select statement to display a summary.
cat <<EOF >> "$SQL_TMPFILE"
SELECT
    table_name,
    column_name,
    pattern_found,
    COUNT(*) as occurrences
FROM scan_search_results
GROUP BY table_name, column_name, pattern_found
ORDER BY table_name, column_name, pattern_found;

DROP TEMPORARY TABLE IF EXISTS scan_search_results;
EOF

# Run all the SQL.
docker exec -i $CONTAINER_NAME mysql -h 127.0.0.1 -u root -prootpassword testdb < "$SQL_TMPFILE"

rm -f "$SQL_TMPFILE"

docker stop $CONTAINER_NAME > /dev/null 2>&1
