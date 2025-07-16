#!/bin/bash

# Check for input file
if [ $# -ne 1 ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

input_file="$1"

# Process the file using awk
awk -v table_name="" -v in_table=0 -v separator_count=0 '
BEGIN {
    # Field separator for splitting lines
    FS = "|"
}

# Extract table name from SQL select statement (handles both plain and mysql> prompt)
/^(mysql> )?select \* from / {
    match($0, /(mysql> )?select \* from ([^ ]+)/, arr)
    if (arr[2] != "") {
        table_name = arr[2]
        in_table = 1
        separator_count = 0
    }
    next
}

# Count separators to track header/data sections
in_table && /^\+/ {
    separator_count++
    # Reset after third separator (end of table)
    if (separator_count == 3) {
        in_table = 0
        separator_count = 0
    }
    next
}

# Process header row
in_table && separator_count == 1 {
    # Extract and clean column names
    for (i = 2; i < NF; i++) {
        gsub(/^[ \t]+|[ \t]+$/, "", $i)
        columns[i-1] = $i
    }
    col_count = NF - 2
    next
}

# Process data rows
in_table && separator_count == 2 && /^\|/ {
    # Process each field
    printf "INSERT INTO `%s` (", table_name
    for (i = 1; i <= col_count; i++) {
        printf "`%s`", columns[i]
        if (i < col_count) printf ", "
    }
    printf ") VALUES ("

    # Process values
    for (i = 2; i <= NF-1; i++) {
        # Trim whitespace
        gsub(/^[ \t]+|[ \t]+$/, "", $i)

        # Handle NULL values and escape quotes
        if ($i == "NULL") {
            printf "NULL"
        } else {
            # Escape single quotes
            gsub(/\047/, "\047\047", $i)
            printf "\047%s\047", $i
        }

        if (i < NF-1) printf ", "
    }
    print ");"
}
' "$input_file"
