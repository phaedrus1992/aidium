#!/bin/bash -eu
# vendor-fetch.sh — download a source tarball into Dependencies/vendor/ and
# verify/print its SHA256. Developer tool only; the build itself never downloads.
# Usage: vendor-fetch.sh <url> <expected-sha256>

url="$1"
expected="$2"
vendor_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/vendor"
mkdir -p "$vendor_dir"
file="$vendor_dir/$(basename "$url")"

curl -fSL --proto '=https' --retry 3 -o "$file" "$url"
actual="$(shasum -a 256 "$file" | awk '{print $1}')"
if [ "$actual" != "$expected" ]; then
    echo "ERROR: SHA256 mismatch for $(basename "$file")" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    rm -f "$file"
    exit 1
fi
echo "OK: $actual  $(basename "$file")"
