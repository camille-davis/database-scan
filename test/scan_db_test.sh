#!/usr/bin/env bash
set -euo pipefail

# Run the scan and capture output
output=$(../scan_db.sh test_db.sql scan_db_input.txt)

# Get the expected output
expected=$(cat scan_db_expected_output.txt)

# Extract the last N lines of output, where N is the number of lines in expected_output_scan_db.txt
expected_lines=$(echo "$expected" | wc -l)
output_tail=$(echo "$output" | tail -n "$expected_lines")

# Compare, ignoring whitespace.
if [ "$(echo "$output_tail" | tr -d '[:space:]')" = "$(echo "$expected" | tr -d '[:space:]')" ]; then
  echo "PASS"
  exit 0
else
  echo "FAIL"
  exit 1
fi
