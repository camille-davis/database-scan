# Database tools

## Requirements
Docker

## scan_db.sh

Searches through a SQL file for a list of patterns using MySQL LIKE.

Outputs a summary of patterns found with their table name, column name, and number of occurrences.

### Usage

Create a file with a list of patterns you'd like to scan for (one pattern per line), for example common patterns found in malware. Case insensitive. No need to include wildcard at beginning or end. You can use MySQL LIKE wildcards in the middle. A sample file is provide at `sample_malware_patterns.txt` but it's not exhaustive.

Get a SQL file to scan and run:
```
./scan_db.sh <sql_file> <patterns_file>
```

## open_db.sh

Starts a mysql container and populates it with a SQL file.
```
./open_db.sh <sql_file>
```

## create_insert_from_select.sh

Turns given select statements and their output into insert statements.

### Usage

In MySQL, run one or more select statements. Copy and paste the console output to a file so it looks like this:
```
mysql> <select statement 1>
<output 1>
mysql> <select statement 2>
<output 2>
```

Then run:
```
./create_insert_from_select.sh <file>
```
