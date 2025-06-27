#!/bin/bash
set -e
# Usage: ./scan_db.sh sql_file patterns_file

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 sql_file patterns_file"
  echo "patterns_file should include one pattern per line."
  exit 1
fi
SQL_FILE="$1"
PATTERNS_FILE="$2"
CONTAINER_NAME="mysql-temp-$$" # unique name per run
SQL_TMPFILE=$(mktemp)

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

columns=$(docker exec $CONTAINER_NAME mysql -h 127.0.0.1 -u root -prootpassword -N -e \
  "SELECT TABLE_NAME, COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='testdb' AND DATA_TYPE IN ('char','varchar','text','tinytext','mediumtext','longtext');" 2>/dev/null)

cat <<EOF > "$SQL_TMPFILE"
-- Auto-generated SQL script to search for patterns
USE testdb;
SET SESSION net_read_timeout=600;
SET SESSION net_write_timeout=600;
SET SESSION wait_timeout=600;
SET SESSION max_execution_time=600000;

CREATE TEMPORARY TABLE IF NOT EXISTS scan_search_results (
    table_name VARCHAR(100),
    column_name VARCHAR(100),
    pattern_found VARCHAR(200),
    row_id VARCHAR(50),
    sample_data TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF

echo "Searching for patterns... this may take a while."

total_patterns=$(grep -v '^[[:space:]]*$' "$PATTERNS_FILE" | wc -l | tr -d ' ')
current_pattern=0

while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue
    ((current_pattern++))
    echo -ne "Searching for pattern: ($current_pattern / $total_patterns)       \r"

    if [[ "$pattern" =~ \\\($ ]]; then
        mysql_pattern="${pattern//\(/\\\\(}"
        display_pattern="$pattern"
    else
        mysql_pattern="$pattern"
        display_pattern="$pattern"
    fi
    esc_pattern=$(echo "$mysql_pattern" | sed "s/'/''/g")
    esc_display=$(echo "$display_pattern" | sed "s/'/''/g")
    while IFS=$'\t' read -r table column; do
        pk=$(docker exec $CONTAINER_NAME mysql -h 127.0.0.1 -u root -prootpassword -N -e \
          "SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='testdb' AND TABLE_NAME='$table' AND COLUMN_KEY IN ('PRI','UNI') LIMIT 1;" 2>/dev/null)
        if [ -z "$pk" ]; then
          pk="NULL"
        fi
        echo "INSERT INTO scan_search_results (table_name, column_name, pattern_found, row_id, sample_data)" >> "$SQL_TMPFILE"
        if [ "$pk" != "NULL" ]; then
          echo "SELECT '$table', '$column', '$esc_display', $pk, LEFT($column, 200) FROM $table WHERE $column REGEXP '$esc_pattern';" >> "$SQL_TMPFILE"
        else
          echo "SELECT '$table', '$column', '$esc_display', NULL, LEFT($column, 200) FROM $table WHERE $column REGEXP '$esc_pattern';" >> "$SQL_TMPFILE"
        fi
    done <<< "$columns"
done < "$PATTERNS_FILE"

cat <<EOF >> "$SQL_TMPFILE"
-- Display results summary
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

echo ""
echo "Writing summary..."
docker exec -i $CONTAINER_NAME mysql -h 127.0.0.1 -u root -prootpassword testdb < "$SQL_TMPFILE"

rm -f "$SQL_TMPFILE"

docker stop $CONTAINER_NAME > /dev/null 2>&1
