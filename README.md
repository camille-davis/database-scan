# Scan a SQL file for a list of patterns

Outputs a summary of patterns found with their table name, column name, and number of occurrences

## Usage

1. Create a file with a list of patterns you'd like to scan for (one pattern per line), for example common patterns found in malware.
2. Get a SQL file to scan
3. Run ./scan_db.sh sql_file patterns_file

## Requirements
Docker
