#!/bin/bash

# Run tests script for SimpleLogin
# Usage: run_tests.sh <output_json_path>

OUTPUT_PATH="${1:-/tmp/test_results.json}"

cd /code

# Start PostgreSQL (configured to listen on port 15432)
service postgresql start
sleep 2

# Ensure PostgreSQL is running and database exists
su - postgres -c "psql -p 15432 -c \"ALTER USER test WITH PASSWORD 'test';\"" 2>/dev/null || true
su - postgres -c "createdb -p 15432 -O test test" 2>/dev/null || true

# Start Redis server in the background (required for tests)
redis-server --daemonize yes 2>/dev/null || true

# Set environment variable for test config
export CONFIG=/code/tests/test.env

# Run database migrations
alembic upgrade head 2>/dev/null || true

# Run pytest with JSON output
PYTEST_OUTPUT=$(mktemp)
PYTEST_EXIT_CODE=0

python -m pytest tests/ \
    --tb=short \
    -v \
    --no-header \
    2>&1 | tee "$PYTEST_OUTPUT" || PYTEST_EXIT_CODE=$?

# Parse the pytest output to extract test results
PASSED_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0

# Extract summary line (e.g., "480 passed, 70 warnings in 173.45s")
SUMMARY_LINE=$(grep -E "^=+ .*(passed|failed|skipped|error).*=+$" "$PYTEST_OUTPUT" | tail -1 || true)

if [ -n "$SUMMARY_LINE" ]; then
    PASSED_COUNT=$(echo "$SUMMARY_LINE" | grep -oP '\d+(?= passed)' || echo "0")
    FAILED_COUNT=$(echo "$SUMMARY_LINE" | grep -oP '\d+(?= failed)' || echo "0")
    SKIPPED_COUNT=$(echo "$SUMMARY_LINE" | grep -oP '\d+(?= skipped)' || echo "0")
    ERROR_COUNT=$(echo "$SUMMARY_LINE" | grep -oP '\d+(?= error)' || echo "0")

    # Add errors to failed count
    FAILED_COUNT=$((${FAILED_COUNT:-0} + ${ERROR_COUNT:-0}))
fi

# Set defaults if empty
PASSED_COUNT=${PASSED_COUNT:-0}
FAILED_COUNT=${FAILED_COUNT:-0}
SKIPPED_COUNT=${SKIPPED_COUNT:-0}

# Extract test names from verbose output
# Lines look like: "tests/test_foo.py::test_bar PASSED"
PASSED_TESTS_RAW=$(grep -E " PASSED" "$PYTEST_OUTPUT" | sed 's/ PASSED.*//' | sed 's/^[[:space:]]*//' || true)
FAILED_TESTS_RAW=$(grep -E " FAILED" "$PYTEST_OUTPUT" | sed 's/ FAILED.*//' | sed 's/^[[:space:]]*//' || true)

# Convert to JSON arrays using Python for proper escaping
PASSED_TESTS=$(python3 -c "
import json
import sys
tests_raw = sys.stdin.read()
tests = [t.strip() for t in tests_raw.strip().split('\n') if t.strip()]
result = [{'name': t} for t in tests]
print(json.dumps(result))
" <<< "$PASSED_TESTS_RAW" 2>/dev/null || echo "[]")

FAILED_TESTS=$(python3 -c "
import json
import sys
tests_raw = sys.stdin.read()
tests = [t.strip() for t in tests_raw.strip().split('\n') if t.strip()]
result = [{'name': t} for t in tests]
print(json.dumps(result))
" <<< "$FAILED_TESTS_RAW" 2>/dev/null || echo "[]")

# Create the JSON output
cat > "$OUTPUT_PATH" << EOF
{
  "passed_test_count": $PASSED_COUNT,
  "failed_test_count": $FAILED_COUNT,
  "skipped_test_count": $SKIPPED_COUNT,
  "passed_tests": $PASSED_TESTS,
  "failed_tests": $FAILED_TESTS,
  "exit_code": $PYTEST_EXIT_CODE
}
EOF

# Cleanup
rm -f "$PYTEST_OUTPUT"

exit 0
