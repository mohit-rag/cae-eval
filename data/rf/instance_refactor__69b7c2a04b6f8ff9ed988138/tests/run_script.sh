#!/bin/bash
set -o pipefail

OUTPUT_PATH="${1:-/tmp/test_results.json}"

# Arrays to collect all test results
ALL_PASSED_TESTS=()
ALL_FAILED_TESTS=()
OVERALL_EXIT_CODE=0
NETDATA_BUILD_OK=0

# =============================================================================
# Build Configuration & Compilation
# =============================================================================

BUILD_LOG_DIR="/tmp_artifact_storage"
CMAKE_FLAGS="${CMAKE_FLAGS:--DWITH_UNIT_TESTS=ON -DENABLE_UNIT_TESTS=ON -DBUILD_TESTING=ON -DCMAKE_BUILD_TYPE=Debug}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

get_build_jobs() {
    if [[ -n "${NPROC:-}" ]]; then
        echo "$NPROC"
        return
    fi
    local total_cpus
    total_cpus=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "")
    if [[ -z "$total_cpus" ]]; then
        echo 4
    else
        local jobs=$(( total_cpus / 2 ))
        [[ $jobs -lt 1 ]] && jobs=1
        echo "$jobs"
    fi
}

ensure_cmocka_for_netdata_tests() {
    if command -v pkg-config &>/dev/null && pkg-config --exists cmocka 2>/dev/null; then
        return 0
    fi
    if [[ -f /usr/include/cmocka.h ]] || [[ -f /usr/local/include/cmocka.h ]]; then
        return 0
    fi

    log "WARNING: CMocka development files not found; installing for Netdata unit tests..."

    if command -v apt-get &>/dev/null; then
        if apt-get install -y -qq libcmocka-dev >/dev/null 2>&1; then
            log "SUCCESS: Installed libcmocka-dev via apt-get (cached)"
            return 0
        fi
        local attempt
        for attempt in 1 2 3; do
            if apt-get update >/dev/null 2>&1; then
                if apt-get install -y -qq libcmocka-dev >/dev/null 2>&1; then
                    log "SUCCESS: Installed libcmocka-dev via apt-get (attempt ${attempt})"
                    return 0
                fi
            fi
            log "WARNING: apt-get attempt ${attempt} failed, retrying..."
            sleep 1
        done
    fi

    if command -v dnf &>/dev/null; then
        if dnf install -y -q libcmocka-devel 2>/dev/null; then
            log "SUCCESS: Installed libcmocka-devel via dnf"
            return 0
        fi
    fi

    if command -v yum &>/dev/null; then
        if yum install -y -q libcmocka-devel 2>/dev/null; then
            log "SUCCESS: Installed libcmocka-devel via yum"
            return 0
        fi
    fi

    if command -v apk &>/dev/null; then
        if apk add --quiet cmocka-dev 2>/dev/null; then
            log "SUCCESS: Installed cmocka-dev via apk"
            return 0
        fi
    fi

    if command -v pacman &>/dev/null; then
        if pacman -Sy --noconfirm cmocka 2>/dev/null; then
            log "SUCCESS: Installed cmocka via pacman"
            return 0
        fi
    fi

    log "WARNING: Could not install CMocka development files. Some tests may fail."
    return 1
}

build_netdata() {
    # Determine repo root from script location or known paths
    local repo_root=""
    if [[ -f "/app/CMakeLists.txt" ]]; then
        repo_root="/app"
    elif [[ -f "/opt/netdata.git/CMakeLists.txt" ]]; then
        repo_root="/opt/netdata.git"
    else
        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [[ -f "${script_dir}/CMakeLists.txt" ]]; then
            repo_root="$script_dir"
        fi
    fi

    if [[ -z "$repo_root" ]]; then
        log "WARNING: Could not find Netdata CMakeLists.txt; skipping build"
        return 0
    fi

    local nproc_val build_dir
    nproc_val=$(get_build_jobs)
    build_dir="${repo_root}/build"

    mkdir -p "$BUILD_LOG_DIR"
    log "=== Building Netdata (repo: ${repo_root}) ==="

    if ! command -v cmake &>/dev/null; then
        log "WARNING: cmake is not installed; skipping Netdata build"
        return 1
    fi

    ensure_cmocka_for_netdata_tests || true

    if [[ ! -d "$build_dir" ]]; then
        log "Running cmake -B ${build_dir} ${CMAKE_FLAGS}..."
        cmake -B "$build_dir" -S "$repo_root" ${CMAKE_FLAGS} > "${BUILD_LOG_DIR}/cmake.log" 2>&1 || {
            log "WARNING: cmake configure failed (see ${BUILD_LOG_DIR}/cmake.log)"
            return 1
        }
    fi

    log "Running cmake --build -j${nproc_val}..."
    cmake --build "$build_dir" -j "${nproc_val}" > "${BUILD_LOG_DIR}/cmake_build.log" 2>&1 || {
        log "WARNING: cmake build failed (see ${BUILD_LOG_DIR}/cmake_build.log)"
        return 1
    }

    log "=== Netdata build complete ==="
    return 0
}

# --- Build Netdata ---
if build_netdata; then
    NETDATA_BUILD_OK=1
else
    OVERALL_EXIT_CODE=1
fi

# ============================================================
# PART 1: Run C/Native Unit Tests
# ============================================================

# Find the netdata binary
NETDATA_BIN=""
if [[ "$NETDATA_BUILD_OK" -eq 1 ]]; then
    if [ -x /app/build/src/netdata ]; then
        NETDATA_BIN="/app/build/src/netdata"
    elif [ -x /opt/netdata.git/build/src/netdata ]; then
        NETDATA_BIN="/opt/netdata.git/build/src/netdata"
    elif [ -x /usr/sbin/netdata ]; then
        NETDATA_BIN="/usr/sbin/netdata"
    elif [ -x /usr/local/bin/netdata-test ]; then
        NETDATA_BIN="/usr/local/bin/netdata-test"
    fi
fi

if [[ "$NETDATA_BUILD_OK" -ne 1 ]]; then
    echo "WARNING: Netdata build was unavailable, skipping C unit tests"
elif [ -z "$NETDATA_BIN" ] || [ ! -x "$NETDATA_BIN" ]; then
    echo "WARNING: netdata binary not found after build, skipping C unit tests"
else
    echo "Using netdata binary: $NETDATA_BIN"

    # Clean up any leftover state from previous runs to ensure idempotent execution
    rm -rf /var/cache/netdata/unittest-dbengine 2>/dev/null
    rm -rf /var/cache/netdata/dbengine 2>/dev/null
    rm -rf /var/lib/netdata/registry 2>/dev/null
    mkdir -p /var/lib/netdata/registry /var/cache/netdata /var/log/netdata

    # Define the test names matching the order in main.c unittest block
    C_TEST_NAMES=(
        "pluginsd_parser_unittest"
        "unit_test_static_threads"
        "unit_test_buffer"
        "unit_test_str2ld"
        "buffer_unittest"
        "unittest_prepare_rrd"
        "run_all_mockup_tests"
        "unit_test_storage"
        "test_dbengine"
        "test_sqlite"
        "string_unittest"
        "dictionary_unittest"
        "aral_unittest"
        "rrdlabels_unittest"
        "ctx_unittest"
        "uuid_unittest"
        "dyncfg_unittest"
        "unittest_waiting_queue"
        "uuidmap_unittest"
    )

    # Run the C unit tests
    TMPLOG=$(mktemp)
    echo "Running: $NETDATA_BIN -W unittest"
    $NETDATA_BIN -W unittest > "$TMPLOG" 2>&1
    C_EXIT_CODE=$?
    echo "C unit tests exit code: $C_EXIT_CODE"

    if [ $C_EXIT_CODE -ne 0 ]; then
        OVERALL_EXIT_CODE=1
    fi

    # Determine pass/fail for C tests
    if [ $C_EXIT_CODE -eq 0 ]; then
        for t in "${C_TEST_NAMES[@]}"; do
            ALL_PASSED_TESTS+=("$t")
        done
    else
        LOG_CONTENT=$(cat "$TMPLOG")
        LAST_FAILED=""
        for t in "${C_TEST_NAMES[@]}"; do
            if echo "$LOG_CONTENT" | grep -qi "$t\|$(echo $t | tr '_' ' ')"; then
                LAST_FAILED="$t"
            else
                break
            fi
            ALL_PASSED_TESTS+=("$t")
        done

        if [ -n "$LAST_FAILED" ]; then
            unset 'ALL_PASSED_TESTS[${#ALL_PASSED_TESTS[@]}-1]'
            ALL_FAILED_TESTS+=("$LAST_FAILED")
        else
            ALL_FAILED_TESTS+=("unknown_c_test")
        fi
    fi

    rm -f "$TMPLOG"
fi

# ============================================================
# PART 2: Run Go Tests
# ============================================================

# Find the Go source directory
GO_SRC_DIR=""
if [ -d "/app/src/go" ]; then
    GO_SRC_DIR="/app/src/go"
elif [ -d "/opt/netdata.git/src/go" ]; then
    GO_SRC_DIR="/opt/netdata.git/src/go"
fi

if [ -n "$GO_SRC_DIR" ] && [ -f "$GO_SRC_DIR/go.mod" ]; then
    echo "Running Go tests in: $GO_SRC_DIR"
    echo "Go module root (pwd): $(cd "$GO_SRC_DIR" && pwd)"
    echo "Resolved repo root from daemon_refactor_validation: $(cd "$GO_SRC_DIR/daemon_refactor_validation" 2>/dev/null && cd ../../.. 2>/dev/null && pwd || echo 'NOT FOUND')"
    echo "Checking C source files at resolved root:"
    RESOLVED_ROOT="$(cd "$GO_SRC_DIR/daemon_refactor_validation" 2>/dev/null && cd ../../.. 2>/dev/null && pwd || echo '')"
    if [ -n "$RESOLVED_ROOT" ]; then
        for f in src/daemon/main.c src/libnetdata/exit/exit_initiated.h src/libnetdata/log/nd_log.h; do
            [ -f "$RESOLVED_ROOT/$f" ] && echo "  [OK] $RESOLVED_ROOT/$f" || echo "  [MISSING] $RESOLVED_ROOT/$f"
        done
    fi
    
    GO_TMPLOG=$(mktemp)
    GO_PASSED=$(mktemp)
    GO_FAILED=$(mktemp)
    
    # Run go test with JSON output for all packages
    cd "$GO_SRC_DIR"
    go test -json ./... > "$GO_TMPLOG" 2>&1
    GO_EXIT_CODE=$?
    echo "Go tests exit code: $GO_EXIT_CODE"

    # Surface package-level failures (panics, build errors)
    jq -r 'select(.Action == "fail" and .Test == null) | "PACKAGE FAIL: \(.Package)"' "$GO_TMPLOG" 2>/dev/null
    jq -r 'select(.Action == "output" and .Test == null and (.Output | test("panic|cannot|error";"i"))) | "\(.Package): \(.Output)"' "$GO_TMPLOG" 2>/dev/null | head -20

    if [ $GO_EXIT_CODE -ne 0 ]; then
        OVERALL_EXIT_CODE=1
    fi

    # Parse go test JSON output efficiently with single jq calls
    # Extract passed tests (Action=pass with a Test field)
    jq -r 'select(.Action == "pass" and .Test != null) | "\(.Package)/\(.Test)"' "$GO_TMPLOG" 2>/dev/null > "$GO_PASSED"
    
    # Extract failed tests (Action=fail with a Test field)
    jq -r 'select(.Action == "fail" and .Test != null) | "\(.Package)/\(.Test)"' "$GO_TMPLOG" 2>/dev/null > "$GO_FAILED"

    # Read results into arrays
    while IFS= read -r test_name; do
        [ -n "$test_name" ] && ALL_PASSED_TESTS+=("$test_name")
    done < "$GO_PASSED"

    while IFS= read -r test_name; do
        [ -n "$test_name" ] && ALL_FAILED_TESTS+=("$test_name")
    done < "$GO_FAILED"

    rm -f "$GO_TMPLOG" "$GO_PASSED" "$GO_FAILED"
else
    echo "WARNING: Go source directory not found or no go.mod, skipping Go tests"
fi

# ============================================================
# PART 3: Build JSON Output
# ============================================================

PASSED_COUNT=${#ALL_PASSED_TESTS[@]}
FAILED_COUNT=${#ALL_FAILED_TESTS[@]}

{
    echo "{"
    echo "  \"passed_test_count\": $PASSED_COUNT,"
    echo "  \"failed_test_count\": $FAILED_COUNT,"
    echo "  \"skipped_test_count\": 0,"

    # Passed tests array
    echo "  \"passed_tests\": ["
    first=true
    for t in "${ALL_PASSED_TESTS[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        escaped=$(echo "$t" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\n/\\n/g')
        printf '    {"name": "%s"}' "$escaped"
    done
    echo ""
    echo "  ],"

    # Failed tests array
    echo "  \"failed_tests\": ["
    first=true
    for t in "${ALL_FAILED_TESTS[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        escaped=$(echo "$t" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\n/\\n/g')
        printf '    {"name": "%s"}' "$escaped"
    done
    echo ""
    echo "  ],"

    echo "  \"exit_code\": $OVERALL_EXIT_CODE"
    echo "}"
} > "$OUTPUT_PATH"

echo "Test results written to $OUTPUT_PATH"
cat "$OUTPUT_PATH"

exit 0
