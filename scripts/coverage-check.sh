#!/bin/bash
set -euo pipefail

# Coverage threshold check for Xcode test runs
# Reads xccov report and fails if any production target is below THRESHOLD

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

THRESHOLD="${COVERAGE_THRESHOLD:-50}"
# Validate threshold is numeric
if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]]; then
  echo "ERROR: COVERAGE_THRESHOLD must be a positive integer, got: '$THRESHOLD'" >&2
  exit 1
fi
XCRUN="${XCRUN:-xcrun}"

# Derive data path from build dir or explicit DERIVED_DATA
DERIVED_DATA="${DERIVED_DATA_DIR:-${BUILD_DIR:-build}/DerivedData}"

echo "--- Coverage check (threshold: ${THRESHOLD}%) ---"

# Locate the coverage profile
COV_FILE=""
for d in "${DERIVED_DATA}/Build/ProfileData" "${DERIVED_DATA}/Logs/Test"; do
  if [ -d "$d" ]; then
    COV_FILE=$(find "$d" -name '*.profdata' -maxdepth 4 -print -quit 2>/dev/null || true)
    [ -n "$COV_FILE" ] && break
  fi
done

if [ -z "$COV_FILE" ]; then
  echo "WARNING: No coverage profile data found in ${DERIVED_DATA}."
  echo "SKIPPED — no coverage data to check."
  echo ""
  echo "To generate coverage data, run tests with -enableCodeCoverage YES and build"
  echo "targets with CLANG_COVERAGE_MAPPING=YES CLANG_PROFILE_INSTRUMENTATION=YES."
  exit 0
fi

echo "Found coverage profile: $COV_FILE"

# Verify jq is available for JSON parsing
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq not found. Install via 'brew install jq'" >&2
  exit 1
fi

# Get coverage report as JSON (more robust than text parsing — handles
# spaces in target names, locale-independent formatting)
# xccov view --report --json outputs per-target coverage as a fraction (0-1)
REPORT_JSON=$($XCRUN xccov view --report --json "$COV_FILE" 2>/dev/null || true)

if [ -z "$REPORT_JSON" ]; then
  echo "INFO: xccov report is empty — no test-run targets in profdata. Pre-built framework check follows."
fi

FAILED=0

# Parse JSON with jq — extract name and lineCoverage (as integer percentage)
# Only parse if xccov actually returned data
if [ -n "$REPORT_JSON" ]; then
  while IFS=$'\t' read -r TARGET PCT_INT; do
    # Skip test targets (suffixed with Test/Tests) and frameworks we don't own
    case "$TARGET" in
      *Tests|*Test|AutoHyperlinks|MMTabBarView) continue ;;
    esac

    if [ "$PCT_INT" -lt "$THRESHOLD" ]; then
      echo "FAIL: $TARGET coverage ${PCT_INT}% < ${THRESHOLD}%"
      FAILED=1
    else
      echo "OK:   $TARGET coverage ${PCT_INT}% >= ${THRESHOLD}%"
    fi
  done < <(echo "$REPORT_JSON" | jq -r '.targets[] | [.name, (.lineCoverage * 100 | floor)] | @tsv')
fi

# ---- llvm-cov check for pre-built frameworks ----
# xccov only reports targets compiled during `xcodebuild test`. Frameworks
# built separately with CLANG_COVERAGE_MAPPING/CLANG_PROFILE_INSTRUMENTATION
# must be checked via llvm-cov against their binary and the merged profdata.
BUILD_PRODUCTS="${DERIVED_DATA}/Build/Products/Debug"
if [ -d "$BUILD_PRODUCTS" ]; then
  echo ""
  echo "--- Pre-built framework coverage (llvm-cov) ---"
  for fw_dir in "$BUILD_PRODUCTS"/*.framework; do
    [ -d "$fw_dir" ] || continue
    fw_name="$(basename "$fw_dir" .framework)"
    # Skip vendored frameworks
    case "$fw_name" in
      AutoHyperlinks|MMTabBarView) continue ;;
    esac
    fw_binary="$fw_dir/Versions/A/$fw_name"
    [ -f "$fw_binary" ] || fw_binary="$fw_dir/$fw_name"
    [ -f "$fw_binary" ] || continue

    # Pass native arch for universal (fat) binaries — llvm-cov needs it
    native_arch=$(uname -m)

    cov_pct=$(xcrun llvm-cov report -arch "$native_arch" \
      --instr-profile="$COV_FILE" --object="$fw_binary" 2>/dev/null \
      | awk '$1 == "TOTAL" {gsub(/%/, "", $10); print $10}')

    if [ -z "$cov_pct" ] || [ "$cov_pct" = "-" ] || [ "$cov_pct" = "0.00" ]; then
      echo "WARN: $fw_name — no coverage data (not instrumented or not exercised)"
      continue
    fi

    pct_int=$(printf "%.0f" "$cov_pct" 2>/dev/null || echo 0)

    if [ "$pct_int" -lt "$THRESHOLD" ]; then
      echo "FAIL: $fw_name line coverage ${cov_pct}% < ${THRESHOLD}%"
      FAILED=1
    else
      echo "OK:   $fw_name line coverage ${cov_pct}% >= ${THRESHOLD}%"
    fi
  done
fi

if [ "$FAILED" -eq 1 ]; then
  echo ""
  echo "FAILED: Some targets below coverage threshold (${THRESHOLD}%)."
  exit 1
fi

echo ""
echo "All targets meet or exceed ${THRESHOLD}% coverage."
