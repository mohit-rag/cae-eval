#!/bin/bash
# run_tests.sh - Runs tests inside the Docker container and outputs JSON results
# NOTE: This script does NOT modify any git repository files

set -o pipefail

OUTPUT_PATH="${1:-/tmp/test_results.json}"

cd /code

# -------------------------------------------------------------------
# 1. Start PostgreSQL
# -------------------------------------------------------------------
PG_PORT=15432
PG_USER="test"
PG_DB="test"
PG_PASS="test"
PG_VERSION=$(ls /etc/postgresql/ 2>/dev/null | sort -n | tail -1)
PG_DATA="/var/lib/postgresql/${PG_VERSION}/main"
PG_CONF="/etc/postgresql/${PG_VERSION}/main/postgresql.conf"
PG_HBA="/etc/postgresql/${PG_VERSION}/main/pg_hba.conf"
PG_BIN="/usr/lib/postgresql/${PG_VERSION}/bin"

# Loosen pg_hba.conf from scram-sha-256 to md5 so the test user can
# authenticate via TCP with a simple password.
if [ -f "$PG_HBA" ] && grep -q "scram-sha-256" "$PG_HBA" 2>/dev/null; then
    sed -i 's/scram-sha-256/md5/g' "$PG_HBA" 2>/dev/null || true
fi

if ! pg_isready -h localhost -p "$PG_PORT" -q 2>/dev/null; then
    # Container environments often leak thousands of inherited file descriptors
    # into child processes.  PostgreSQL counts open FDs at startup and refuses
    # to run when (soft-ulimit - open-FDs) is negative.  We work around this
    # by raising the soft limit and closing every inherited FD > 2 before
    # exec-ing pg_ctl.
    su - postgres -c "
        ulimit -n 65536 2>/dev/null
        for fd in /proc/self/fd/*; do
            n=\$(basename \"\$fd\")
            [ \"\$n\" -gt 2 ] 2>/dev/null && eval \"exec \$n>&-\" 2>/dev/null || true
        done
        \"$PG_BIN/pg_ctl\" start \
            -D \"$PG_DATA\" \
            -l /tmp/pg_start.log \
            -o \"-c config_file=$PG_CONF\" \
            -w -t 60
    " 2>/dev/null || true
fi

# Wait for PostgreSQL to be ready
PG_READY=false
for i in {1..30}; do
    if pg_isready -h localhost -p "$PG_PORT" -q 2>/dev/null; then
        PG_READY=true
        break
    fi
    sleep 1
done

if [ "$PG_READY" = false ]; then
    echo "ERROR: PostgreSQL did not start on port $PG_PORT after 30s" >&2
    echo "  Check /tmp/pg_start.log for details" >&2
fi

# -------------------------------------------------------------------
# 2. Ensure test user and database exist
# -------------------------------------------------------------------
if [ "$PG_READY" = true ]; then
    su - postgres -c "psql -p $PG_PORT -tc \"SELECT 1 FROM pg_roles WHERE rolname='$PG_USER'\"" 2>/dev/null | grep -q 1 \
        || su - postgres -c "psql -p $PG_PORT -c \"CREATE USER $PG_USER WITH PASSWORD '$PG_PASS' SUPERUSER\"" 2>/dev/null \
        || true

    su - postgres -c "psql -p $PG_PORT -c \"ALTER USER $PG_USER WITH PASSWORD '$PG_PASS'\"" 2>/dev/null || true

    su - postgres -c "psql -p $PG_PORT -tc \"SELECT 1 FROM pg_database WHERE datname='$PG_DB'\"" 2>/dev/null | grep -q 1 \
        || su - postgres -c "psql -p $PG_PORT -c \"CREATE DATABASE $PG_DB OWNER $PG_USER\"" 2>/dev/null \
        || true
fi

# -------------------------------------------------------------------
# 3. Start Redis
# -------------------------------------------------------------------
if ! redis-cli ping 2>/dev/null | grep -q PONG; then
    redis-server --daemonize yes 2>/dev/null || true
fi

for i in {1..15}; do
    if redis-cli ping 2>/dev/null | grep -q PONG; then
        break
    fi
    sleep 1
done

# -------------------------------------------------------------------
# 4. Run database migrations
# -------------------------------------------------------------------
export CONFIG=tests/test.env
if [ "$PG_READY" = true ]; then
    alembic upgrade head 2>&1 || echo "Alembic migration warning (may be OK if already migrated)"
else
    echo "Skipping alembic migrations (PostgreSQL not available)"
fi

# Run pytest with verbose output
python -m pytest tests/ --tb=short -v 2>&1 | tee /tmp/pytest_output.txt
PYTEST_EXIT_CODE=${PIPESTATUS[0]}

# Read the pytest output
PYTEST_OUTPUT=$(cat /tmp/pytest_output.txt)

# Parse test results from pytest output
# Extract counts from summary line like "123 passed, 4 failed, 5 skipped"
SUMMARY_LINE=$(echo "$PYTEST_OUTPUT" | grep -E "^=.*=" | grep -E "passed|failed|skipped|error" | tail -1)

PASSED=0
FAILED=0
SKIPPED=0

if [ -n "$SUMMARY_LINE" ]; then
    PASSED_MATCH=$(echo "$SUMMARY_LINE" | grep -oE "[0-9]+ passed" | grep -oE "[0-9]+")
    FAILED_MATCH=$(echo "$SUMMARY_LINE" | grep -oE "[0-9]+ failed" | grep -oE "[0-9]+")
    SKIPPED_MATCH=$(echo "$SUMMARY_LINE" | grep -oE "[0-9]+ skipped" | grep -oE "[0-9]+")
    ERROR_MATCH=$(echo "$SUMMARY_LINE" | grep -oE "[0-9]+ error" | grep -oE "[0-9]+")

    [ -n "$PASSED_MATCH" ] && PASSED="$PASSED_MATCH"
    [ -n "$FAILED_MATCH" ] && FAILED="$FAILED_MATCH"
    [ -n "$SKIPPED_MATCH" ] && SKIPPED="$SKIPPED_MATCH"
    [ -n "$ERROR_MATCH" ] && FAILED=$((FAILED + ERROR_MATCH))
fi

# Extract passed test names - look for lines with "PASSED"
PASSED_TESTS="["
first=true
while IFS= read -r line; do
    if [ -n "$line" ]; then
        # Extract test identifier (file::function or file::class::method)
        test_name=$(echo "$line" | sed -E 's/[[:space:]]+(PASSED|FAILED|SKIPPED).*$//' | sed 's/^[[:space:]]*//')
        if [ -n "$test_name" ]; then
            # Escape special characters for JSON using Python
            escaped_name=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$test_name" 2>/dev/null)
            if [ -n "$escaped_name" ]; then
                if [ "$first" = true ]; then
                    PASSED_TESTS="${PASSED_TESTS}{\"name\": $escaped_name}"
                    first=false
                else
                    PASSED_TESTS="${PASSED_TESTS}, {\"name\": $escaped_name}"
                fi
            fi
        fi
    fi
done < <(echo "$PYTEST_OUTPUT" | grep -E "^tests/.*PASSED")
PASSED_TESTS="${PASSED_TESTS}]"

# Extract failed test names - look for lines with "FAILED"
FAILED_TESTS="["
first=true
while IFS= read -r line; do
    if [ -n "$line" ]; then
        # Extract test identifier
        test_name=$(echo "$line" | sed -E 's/[[:space:]]+(PASSED|FAILED|SKIPPED|ERROR).*$//' | sed 's/^[[:space:]]*//')
        if [ -n "$test_name" ]; then
            escaped_name=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$test_name" 2>/dev/null)
            if [ -n "$escaped_name" ]; then
                if [ "$first" = true ]; then
                    FAILED_TESTS="${FAILED_TESTS}{\"name\": $escaped_name}"
                    first=false
                else
                    FAILED_TESTS="${FAILED_TESTS}, {\"name\": $escaped_name}"
                fi
            fi
        fi
    fi
done < <(echo "$PYTEST_OUTPUT" | grep -E "^tests/.*FAILED")
FAILED_TESTS="${FAILED_TESTS}]"

# Also check for ERROR tests (test collection errors, etc.)
while IFS= read -r line; do
    if [ -n "$line" ]; then
        test_name=$(echo "$line" | sed -E 's/[[:space:]]+(ERROR).*$//' | sed 's/^[[:space:]]*//')
        if [ -n "$test_name" ]; then
            escaped_name=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$test_name" 2>/dev/null)
            if [ -n "$escaped_name" ]; then
                if [ "$FAILED_TESTS" = "[]" ]; then
                    FAILED_TESTS="[{\"name\": $escaped_name}]"
                else
                    FAILED_TESTS="${FAILED_TESTS%]}, {\"name\": $escaped_name}]"
                fi
            fi
        fi
    fi
done < <(echo "$PYTEST_OUTPUT" | grep -E "^tests/.*ERROR")

# Create JSON output
cat > "$OUTPUT_PATH" << EOF
{
  "passed_test_count": $PASSED,
  "failed_test_count": $FAILED,
  "skipped_test_count": $SKIPPED,
  "passed_tests": $PASSED_TESTS,
  "failed_tests": $FAILED_TESTS,
  "exit_code": $PYTEST_EXIT_CODE
}
EOF

echo "Test results written to $OUTPUT_PATH"
echo "Passed: $PASSED, Failed: $FAILED, Skipped: $SKIPPED, Exit code: $PYTEST_EXIT_CODE"

exit 0