#!/bin/bash -eu
# build-json-glib.sh — Build json-glib as universal framework
# Shell function, sourced by build-universal-deps.sh

BUILD_JSONGLIB_VERSION="1.10.6"
BUILD_JSONGLIB_URL="https://download.gnome.org/sources/json-glib/1.10/json-glib-${BUILD_JSONGLIB_VERSION}.tar.xz"
BUILD_JSONGLIB_SHA256="77f4bcbf9339528f166b8073458693f0a20b77b7059dbc2db61746a1928b0293"

build_json_glib() {
    local src_dir
    src_dir="$(download_and_extract "$BUILD_JSONGLIB_URL" "$BUILD_JSONGLIB_SHA256" "json-glib-$BUILD_JSONGLIB_VERSION")"

    cd "$src_dir"

    export PATH="$BUILD_DIR/bin:$PATH"
    # Look at our built deps first
    export PKG_CONFIG_PATH="$BUILD_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"
    # Meson cross-compilation ignores env CFLAGS, so pass via -Dc_args
    # Need to include the arch flags from the cross file too
    local EXTRA_C_ARGS="-I$BUILD_DIR/include/glib-2.0 -I$BUILD_DIR/lib/glib-2.0/include -arch $ARCH -mmacosx-version-min=11.0"

    local cross_arg=""
    if [ "$HOST_TRIPLE" = "$HOST_ARM64" ]; then
        cross_arg="--cross-file $ROOTDIR/meson-cross-arm64.ini"
    else
        cross_arg="--cross-file $ROOTDIR/meson-cross-x86_64.ini"
    fi

    meson setup _build \
        $cross_arg \
        --prefix="$SANDBOX" --libdir=lib \
        -Dman=false -Ddocumentation=disabled \
        -Dtests=false -Dinstalled_tests=false \
        -Dintrospection=disabled \
        --wrap-mode=nofallback \
        "-Dc_args=$EXTRA_C_ARGS" \
        "-Dc_link_args=-arch $ARCH -mmacosx-version-min=11.0"

    ninja -C _build -j"$NUM_JOBS"
    ninja -C _build install

    cd "$ROOTDIR"
}

build_json_glib_phase() {
    echo "=== Phase: json-glib $BUILD_JSONGLIB_VERSION ==="
    build_for_archs build_json_glib "libjson-glib-1.0.0.dylib"
    build_framework "libjson-glib" "libjson-glib" \
        "$BUILD_DIR/lib/libjson-glib-1.0.0.dylib" \
        "$BUILD_DIR/include/json-glib-1.0"
}