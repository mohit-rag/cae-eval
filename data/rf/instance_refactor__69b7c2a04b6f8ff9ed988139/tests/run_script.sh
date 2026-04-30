#!/bin/bash
set -e

OUTPUT_PATH="${1:-/tmp/test_results.json}"

cd /app/src/go

# Run Go tests with verbose JSON output
TEST_OUTPUT=$(mktemp)
set +e
go test -json -count=1 -timeout 600s ./... > "$TEST_OUTPUT" 2>&1
EXIT_CODE=$?
set -e

# Parse the JSON output from go test
PASSED_TESTS=$(mktemp)
FAILED_TESTS=$(mktemp)
SKIPPED_TESTS=$(mktemp)

# Extract test results (only lines with Test field and terminal actions)
grep '"Action":"pass"' "$TEST_OUTPUT" | grep '"Test"' | jq -r '.Test' | sort -u > "$PASSED_TESTS" 2>/dev/null || true
grep '"Action":"fail"' "$TEST_OUTPUT" | grep '"Test"' | jq -r '.Test' | sort -u > "$FAILED_TESTS" 2>/dev/null || true
grep '"Action":"skip"' "$TEST_OUTPUT" | grep '"Test"' | jq -r '.Test' | sort -u > "$SKIPPED_TESTS" 2>/dev/null || true

# Remove failed tests from passed (a test can have pass for subtests but fail overall)
if [ -s "$FAILED_TESTS" ]; then
    TEMP_PASSED=$(mktemp)
    grep -v -F -x -f "$FAILED_TESTS" "$PASSED_TESTS" > "$TEMP_PASSED" 2>/dev/null || true
    mv "$TEMP_PASSED" "$PASSED_TESTS"
fi

# Remove skipped from passed and failed
if [ -s "$SKIPPED_TESTS" ]; then
    TEMP=$(mktemp)
    grep -v -F -x -f "$SKIPPED_TESTS" "$PASSED_TESTS" > "$TEMP" 2>/dev/null || true
    mv "$TEMP" "$PASSED_TESTS"
    TEMP=$(mktemp)
    grep -v -F -x -f "$SKIPPED_TESTS" "$FAILED_TESTS" > "$TEMP" 2>/dev/null || true
    mv "$TEMP" "$FAILED_TESTS"
fi

PASSED_COUNT=$(wc -l < "$PASSED_TESTS" | tr -d ' ')
FAILED_COUNT=$(wc -l < "$FAILED_TESTS" | tr -d ' ')
SKIPPED_COUNT=$(wc -l < "$SKIPPED_TESTS" | tr -d ' ')

# Build JSON arrays with proper escaping using jq, piping from files to avoid arg limits
PASSED_JSON_FILE=$(mktemp)
FAILED_JSON_FILE=$(mktemp)

jq -R -s '[split("\n")[] | select(length > 0) | {name: .}]' < "$PASSED_TESTS" > "$PASSED_JSON_FILE"
jq -R -s '[split("\n")[] | select(length > 0) | {name: .}]' < "$FAILED_TESTS" > "$FAILED_JSON_FILE"

# Write the final JSON output using file-based slurp to avoid arg limits
jq -n \
    --argjson passed_count "$PASSED_COUNT" \
    --argjson failed_count "$FAILED_COUNT" \
    --argjson skipped_count "$SKIPPED_COUNT" \
    --slurpfile passed_tests "$PASSED_JSON_FILE" \
    --slurpfile failed_tests "$FAILED_JSON_FILE" \
    --argjson exit_code "$EXIT_CODE" \
    '{
        passed_test_count: $passed_count,
        failed_test_count: $failed_count,
        skipped_test_count: $skipped_count,
        passed_tests: $passed_tests[0],
        failed_tests: $failed_tests[0],
        exit_code: $exit_code
    }' > "$OUTPUT_PATH"

echo "Test results written to $OUTPUT_PATH"
echo "Passed: $PASSED_COUNT, Failed: $FAILED_COUNT, Skipped: $SKIPPED_COUNT"

# Cleanup
rm -f "$TEST_OUTPUT" "$PASSED_TESTS" "$FAILED_TESTS" "$SKIPPED_TESTS" "$PASSED_JSON_FILE" "$FAILED_JSON_FILE"

exit 0
