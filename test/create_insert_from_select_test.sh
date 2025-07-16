#!/usr/bin/env bash
set -euo pipefail

# Run the scan and capture output
output=$(../create_insert_from_select.sh create_insert_from_select_input.txt)

# Get the expected output
expected=$(cat create_insert_from_select_expected_output.txt)

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
