# Scan a SQL file for a list of patterns

Outputs a summary of patterns found with their table name, column name, and number of occurrences

## Usage

Create a file with a list of patterns you'd like to scan for (one pattern per line), for example common patterns found in malware.

Get a SQL file to scan and run:
```
./scan_db.sh sql_file patterns_file
```

Or if you just want to start a container to inspect the SQL file:
```
./open_db.sh sql_file
```

## Requirements
Docker
