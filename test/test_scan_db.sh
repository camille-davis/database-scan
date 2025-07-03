#!/usr/bin/env bash
set -euo pipefail

# Run the scan and capture output
output=$(../scan_db.sh test_db.sql test_malware_patterns.txt)

# Get the expected output
expected=$(cat expected_output.txt)

# Extract the last N lines of output, where N is the number of lines in expected_output.txt
expected_lines=$(echo "$expected" | wc -l)
output_tail=$(echo "$output" | tail -n "$expected_lines")

# Compare
if [[ "$output_tail" == "$expected" ]]; then
  echo "PASS"
  exit 0
else
  echo "FAIL"
  exit 1
fi
