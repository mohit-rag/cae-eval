#!/bin/bash
# Run Suricata unit tests (C + Rust) and output results as JSON
# Usage: run_tests.sh <output_path>

set -o pipefail

OUTPUT_PATH="${1:-/tmp/test_results.json}"

# =============================================================================
# Build Configuration & Compilation
# =============================================================================

BUILD_LOG_DIR="/tmp_artifact_storage"
CONFIGURE_FLAGS="${CONFIGURE_FLAGS:---enable-unittests --enable-tests --enable-unit-tests --disable-dependency-tracking}"

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

ensure_pcre_for_suricata_build() {
    local need_pcre1=false need_pcre2=false

    if ! { command -v pkg-config &>/dev/null && pkg-config --exists libpcre2-8 2>/dev/null; } &&
       ! [[ -f /usr/include/pcre2.h ]] && ! [[ -f /usr/local/include/pcre2.h ]]; then
        need_pcre2=true
    fi

    if ! { command -v pkg-config &>/dev/null && pkg-config --exists libpcre 2>/dev/null; } &&
       ! [[ -f /usr/include/pcre.h ]] && ! [[ -f /usr/local/include/pcre.h ]]; then
        need_pcre1=true
    fi

    [[ "$need_pcre1" == false && "$need_pcre2" == false ]] && return 0

    local apt_pkgs=() dnf_pkgs=() yum_pkgs=() apk_pkgs=() pacman_pkgs=()
    if [[ "$need_pcre2" == true ]]; then
        apt_pkgs+=(libpcre2-dev); dnf_pkgs+=(pcre2-devel); yum_pkgs+=(pcre2-devel)
        apk_pkgs+=(pcre2-dev); pacman_pkgs+=(pcre2)
    fi
    if [[ "$need_pcre1" == true ]]; then
        apt_pkgs+=(libpcre3-dev); dnf_pkgs+=(pcre-devel); yum_pkgs+=(pcre-devel)
        apk_pkgs+=(pcre-dev); pacman_pkgs+=(pcre)
    fi

    log "WARNING: PCRE development files missing (pcre1=${need_pcre1}, pcre2=${need_pcre2}); installing..."

    if command -v apt-get &>/dev/null; then
        if apt-get install -y "${apt_pkgs[@]}" >/dev/null 2>&1; then
            log "SUCCESS: Installed ${apt_pkgs[*]} via apt-get (cached)"
            return 0
        fi
        local attempt
        for attempt in 1 2 3; do
            if apt-get update >/dev/null 2>&1; then
                if apt-get install -y "${apt_pkgs[@]}" >/dev/null 2>&1; then
                    log "SUCCESS: Installed ${apt_pkgs[*]} via apt-get (attempt ${attempt})"
                    return 0
                fi
            fi
            log "WARNING: apt-get attempt ${attempt} failed, retrying..."
            sleep 1
        done
    fi

    if command -v dnf &>/dev/null; then
        if dnf install -y -q "${dnf_pkgs[@]}" 2>/dev/null; then
            log "SUCCESS: Installed ${dnf_pkgs[*]} via dnf"
            return 0
        fi
    fi

    if command -v yum &>/dev/null; then
        if yum install -y -q "${yum_pkgs[@]}" 2>/dev/null; then
            log "SUCCESS: Installed ${yum_pkgs[*]} via yum"
            return 0
        fi
    fi

    if command -v apk &>/dev/null; then
        if apk add --quiet "${apk_pkgs[@]}" 2>/dev/null; then
            log "SUCCESS: Installed ${apk_pkgs[*]} via apk"
            return 0
        fi
    fi

    if command -v pacman &>/dev/null; then
        if pacman -Sy --noconfirm "${pacman_pkgs[@]}" 2>/dev/null; then
            log "SUCCESS: Installed ${pacman_pkgs[*]} via pacman"
            return 0
        fi
    fi

    log "ERROR: Could not install PCRE development files. Install them in the image and retry."
    exit 1
}

ensure_config_inputs_for_suricata() {
    [[ -f config.status ]] || [[ -f configure ]] || return 0

    local config_files=""
    if [[ -f config.status ]]; then
        config_files=$(grep '^config_files=' config.status 2>/dev/null | sed 's/^config_files="//' | sed 's/"$//')
    fi
    if [[ -z "$config_files" ]] && [[ -f configure ]]; then
        config_files=$(grep 'ac_config_files=.*Makefile' configure 2>/dev/null | tail -1 | sed 's/.*ac_config_files="\$ac_config_files //' | sed 's/"$//')
    fi
    [[ -n "$config_files" ]] || return 0

    local entry infile
    for entry in $config_files; do
        infile="${entry}.in"
        [[ -f "$infile" ]] && continue
        mkdir -p "$(dirname "$infile")"
        if [[ -f "$entry" ]]; then
            log "Suricata: ${infile} missing; creating from ${entry}"
            cp "$entry" "$infile"
        else
            log "Suricata: ${infile} missing; creating empty placeholder"
            touch "$infile"
        fi
    done
}

ensure_suricata_siocgstamp_workaround() {
    local f="src/source-af-packet.c"
    [[ -f "$f" ]] || return 0
    if grep -qF 'ioctl(ptv->socket, SIOCGSTAMP,' "$f" 2>/dev/null; then
        log "Suricata: applying SIOCGSTAMP -> SIOCGSTAMP_OLD workaround (glibc 2.31+)"
        sed -i 's/ioctl(ptv->socket, SIOCGSTAMP,/ioctl(ptv->socket, SIOCGSTAMP_OLD,/' "$f"
    fi
}

build_suricata() {
    local nproc_val
    nproc_val=$(get_build_jobs)

    mkdir -p "$BUILD_LOG_DIR"
    log "=== Building Suricata ==="

    if [[ ! -f configure ]]; then
        if [[ -f autogen.sh ]]; then
            log "Running autogen.sh..."
            bash autogen.sh > "${BUILD_LOG_DIR}/autogen.log" 2>&1 || {
                log "ERROR: autogen.sh failed (see ${BUILD_LOG_DIR}/autogen.log)"
                exit 1
            }
        elif [[ -f configure.ac ]]; then
            log "Running autoreconf..."
            autoreconf -fi > "${BUILD_LOG_DIR}/autoreconf.log" 2>&1 || {
                log "ERROR: autoreconf failed (see ${BUILD_LOG_DIR}/autoreconf.log)"
                exit 1
            }
        fi
    fi

    # Restore missing autotools helper scripts
    if [[ -f configure ]] && [[ ! -f missing ]]; then
        local makefile_refs_missing=false
        if [[ -f Makefile ]] && grep -qF 'missing aclocal' Makefile 2>/dev/null; then
            makefile_refs_missing=true
        elif [[ -f Makefile.in ]] && grep -qF 'missing aclocal' Makefile.in 2>/dev/null; then
            makefile_refs_missing=true
        fi
        if [[ "$makefile_refs_missing" == true ]]; then
            if [[ -f autogen.sh ]]; then
                log "Running autogen.sh (restoring autotools helpers)..."
                bash autogen.sh > "${BUILD_LOG_DIR}/autogen_helpers.log" 2>&1 || {
                    log "ERROR: autogen.sh failed (see ${BUILD_LOG_DIR}/autogen_helpers.log)"
                    exit 1
                }
            elif [[ -f configure.ac ]]; then
                log "Running autoreconf -fi (restoring autotools helpers)..."
                autoreconf -fi > "${BUILD_LOG_DIR}/autoreconf_helpers.log" 2>&1 || {
                    log "ERROR: autoreconf failed (see ${BUILD_LOG_DIR}/autoreconf_helpers.log)"
                    exit 1
                }
            fi
        fi
    fi

    # Regenerate missing autotools artifacts
    if [[ -f configure.ac ]]; then
        if grep -q 'AC_CONFIG_HEADERS' configure.ac 2>/dev/null && [[ ! -f config.h.in ]]; then
            if command -v autoheader &>/dev/null; then
                log "config.h.in missing; running autoheader..."
                autoheader > "${BUILD_LOG_DIR}/autoheader.log" 2>&1 || {
                    log "WARNING: autoheader failed (see ${BUILD_LOG_DIR}/autoheader.log)"
                }
            fi
        fi
        local _need_automake=false _am
        for _am in Makefile.am */Makefile.am */*/Makefile.am */*/*/Makefile.am; do
            [[ -f "$_am" ]] || continue
            [[ "$_am" == libhtp/* ]] && continue
            if [[ ! -f "${_am%.am}.in" ]]; then
                _need_automake=true
                break
            fi
        done
        if [[ "$_need_automake" == true ]] && command -v automake &>/dev/null; then
            log "Makefile.in file(s) missing; running automake --add-missing..."
            automake --add-missing > "${BUILD_LOG_DIR}/automake.log" 2>&1 || {
                log "WARNING: automake --add-missing failed (see ${BUILD_LOG_DIR}/automake.log)"
            }
        fi
    fi

    # Handle incomplete bundled libhtp
    local extra_flags=""
    if [[ -d libhtp ]] && [[ ! -f libhtp/htp/htp.c ]]; then
        if pkg-config --exists htp 2>/dev/null; then
            log "WARNING: Bundled libhtp missing source files; using system libhtp ($(pkg-config --modversion htp))"
            extra_flags="--enable-non-bundled-htp"
            rm -f Makefile
        else
            log "WARNING: Bundled libhtp is incomplete and no system libhtp found"
        fi
    fi

    ensure_pcre_for_suricata_build
    ensure_config_inputs_for_suricata

    if [[ -f configure ]] && [[ ! -f Makefile ]]; then
        log "Running ./configure ${CONFIGURE_FLAGS} ${extra_flags}..."
        ./configure ${CONFIGURE_FLAGS} ${extra_flags} > "${BUILD_LOG_DIR}/configure.log" 2>&1 || {
            log "ERROR: configure failed (see ${BUILD_LOG_DIR}/configure.log)"
            exit 1
        }
    fi

    # Full clean before every build to avoid stale object segfaults across checkouts/patches
    if [[ -f Makefile ]]; then
        local _rust_bak=""
        if [[ -d rust/target ]] || [[ -d rust/gen ]]; then
            _rust_bak=$(mktemp -d)
            [[ -d rust/target ]] && mv rust/target "$_rust_bak/target"
            [[ -d rust/gen ]]    && mv rust/gen    "$_rust_bak/gen"
        fi

        log "Suricata: running make clean before build..."
        [[ -f config.h.in ]] || { touch config.h.in; log "Suricata: created config.h.in placeholder for clean"; }
        for _sentinel in aclocal.m4 configure config.status config.h.in config.h \
                          Makefile.in Makefile src/Makefile.in src/Makefile; do
            touch "$_sentinel" 2>/dev/null || true
        done
        make clean > "${BUILD_LOG_DIR}/make_clean.log" 2>&1 || {
            log "WARNING: make clean returned non-zero — continuing"
        }

        if [[ -n "$_rust_bak" ]]; then
            [[ -d "$_rust_bak/target" ]] && mv "$_rust_bak/target" rust/target
            [[ -d "$_rust_bak/gen" ]]    && mv "$_rust_bak/gen"    rust/gen
            rm -rf "$_rust_bak"
            log "Suricata: restored rust/target/ + rust/gen/ (Cargo cache preserved)"
        fi

        log "Suricata: re-bootstrapping build system for current source tree..."
        rm -f Makefile src/Makefile config.h config.status config.h.in
        if [[ -f autogen.sh ]]; then
            bash autogen.sh > "${BUILD_LOG_DIR}/autogen.log" 2>&1 || {
                log "ERROR: autogen.sh failed (see ${BUILD_LOG_DIR}/autogen.log)"
                exit 1
            }
        elif [[ -f configure.ac ]]; then
            autoreconf -fi > "${BUILD_LOG_DIR}/autoreconf.log" 2>&1 || {
                log "ERROR: autoreconf failed (see ${BUILD_LOG_DIR}/autoreconf.log)"
                exit 1
            }
        fi
        if [[ -f configure ]]; then
            log "Running ./configure ${CONFIGURE_FLAGS} ${extra_flags}..."
            ./configure ${CONFIGURE_FLAGS} ${extra_flags} > "${BUILD_LOG_DIR}/configure.log" 2>&1 || {
                log "ERROR: configure failed (see ${BUILD_LOG_DIR}/configure.log)"
                exit 1
            }
        fi
    fi

    ensure_suricata_siocgstamp_workaround
    export CARGO_HTTP_MULTIPLEXING=false

    log "Running make -j${nproc_val}..."
    make -j"${nproc_val}" > "${BUILD_LOG_DIR}/make.log" 2>&1 || {
        log "ERROR: make failed (see ${BUILD_LOG_DIR}/make.log)"
        exit 1
    }

    log "=== Suricata build complete ==="
}

# --- Build Suricata ---
cd /src/suricata
build_suricata

RUST_OUTPUT=$(mktemp)
C_OUTPUT=$(mktemp)

# --- Run Rust tests ---
echo "=== Running Rust tests ==="
cd /src/suricata/rust
cargo test 2>&1 | tee "$RUST_OUTPUT" || true
RUST_EXIT=${PIPESTATUS[0]:-$?}

# --- Run C unit tests ---
echo ""
echo "=== Running C unit tests ==="
cd /src/suricata
mkdir -p /tmp/suricata-test-logs /tmp/suricata-test-log
./src/suricata -u -l /tmp/suricata-test-logs 2>&1 | tee "$C_OUTPUT" || true
C_EXIT=${PIPESTATUS[0]:-$?}

# Determine overall exit code
EXIT_CODE=0
if [ "$RUST_EXIT" -ne 0 ] || [ "$C_EXIT" -ne 0 ]; then
    EXIT_CODE=1
fi

# Parse test results using Python for proper JSON escaping
python3 - "$RUST_OUTPUT" "$C_OUTPUT" "$EXIT_CODE" "$OUTPUT_PATH" << 'PYEOF'
import sys
import json
import re

rust_file = sys.argv[1]
c_file = sys.argv[2]
exit_code = int(sys.argv[3])
output_path = sys.argv[4]

passed_tests = []
failed_tests = []
skipped_tests = []

# --- Parse Rust test output ---
with open(rust_file, 'r', errors='replace') as f:
    for line in f:
        line = line.rstrip('\n')
        # Match: test <name> ... ok
        m = re.match(r'^test\s+(.+?)\s+\.\.\.\s+ok$', line)
        if m:
            passed_tests.append("rust:" + m.group(1).strip())
            continue
        # Match: test <name> ... FAILED
        m = re.match(r'^test\s+(.+?)\s+\.\.\.\s+FAILED$', line)
        if m:
            failed_tests.append("rust:" + m.group(1).strip())
            continue
        # Match: test <name> ... ignored
        m = re.match(r'^test\s+(.+?)\s+\.\.\.\s+ignored$', line)
        if m:
            skipped_tests.append("rust:" + m.group(1).strip())
            continue

# --- Parse C unit test output ---
with open(c_file, 'r', errors='replace') as f:
    content = f.read()

lines = content.split('\n')
in_selftest = False
current_test = None

for line in lines:
    # Skip the selftest section
    if '* Running Unittesting subsystem selftests...' in line:
        in_selftest = True
        continue
    if '* Done running Unittesting subsystem selftests...' in line:
        in_selftest = False
        continue
    if in_selftest:
        continue

    # Case 1: Single-line result: "Test <name> : pass" or "Test <name> : FAILED"
    m = re.match(r'^Test\s+(.+?)\s+:\s*(.*\s+)?(pass|FAILED)\s*$', line)
    if m:
        test_name = m.group(1).strip()
        result = m.group(3)
        if result == 'pass':
            passed_tests.append("c:" + test_name)
        else:
            failed_tests.append("c:" + test_name)
        current_test = None
        continue

    # Case 2: Test line starting with "Test <name> :" but no result yet
    m = re.match(r'^Test\s+(.+?)\s+:', line)
    if m:
        current_test = m.group(1).strip()
        continue

    # Case 3: Standalone result line after multi-line output
    stripped = line.strip()
    if current_test and stripped in ('pass', 'FAILED'):
        if stripped == 'pass':
            passed_tests.append("c:" + current_test)
        else:
            failed_tests.append("c:" + current_test)
        current_test = None
        continue

# Build JSON output
result = {
    "passed_test_count": len(passed_tests),
    "failed_test_count": len(failed_tests),
    "skipped_test_count": len(skipped_tests),
    "passed_tests": [{"name": t} for t in passed_tests],
    "failed_tests": [{"name": t} for t in failed_tests],
    "exit_code": exit_code
}

with open(output_path, 'w') as f:
    json.dump(result, f, indent=2)

print(f"\n=== Test Results ===")
print(f"Rust: {sum(1 for t in passed_tests if t.startswith('rust:'))} passed, {sum(1 for t in failed_tests if t.startswith('rust:'))} failed")
print(f"C: {sum(1 for t in passed_tests if t.startswith('c:'))} passed, {sum(1 for t in failed_tests if t.startswith('c:'))} failed")
print(f"Total: {len(passed_tests)} passed, {len(failed_tests)} failed, {len(skipped_tests)} skipped")
print(f"Results written to: {output_path}")
PYEOF

# Cleanup
rm -f "$RUST_OUTPUT" "$C_OUTPUT"

exit 0
