#!/bin/bash -eu
# build-glib.sh — Build glib (with gmodule, gobject, gthread, gio) as universal framework
# Shell function, sourced by build-universal-deps.sh

BUILD_GLIB_VERSION="2.88.2"
BUILD_GLIB_FILE="glib-${BUILD_GLIB_VERSION}.tar.xz"
BUILD_GLIB_SHA256="cf3f215a640c8a4257f14317586b8f1fdd25a10a93cb4bdda147c0f9ad88e74f"

build_glib() {
    local src_dir
    src_dir="$(vendored_extract "$BUILD_GLIB_FILE" "$BUILD_GLIB_SHA256" "glib-$BUILD_GLIB_VERSION")"

    cd "$src_dir"

    # glib uses meson — need to find the cross file
    local cross_arg=""
    if [ "$HOST_TRIPLE" = "$HOST_ARM64" ]; then
        cross_arg="--cross-file $ROOTDIR/meson-cross-arm64.ini"
    else
        cross_arg="--cross-file $ROOTDIR/meson-cross-x86_64.ini"
    fi

    # Need pkg-config in PATH; look at vendored sandbox deps first (libffi, pcre2)
    export PATH="$BUILD_DIR/bin:$PATH"
    export PKG_CONFIG_PATH="$SANDBOX/lib/pkgconfig:$BUILD_DIR/lib/pkgconfig"

    meson setup _build \
        $cross_arg \
        --prefix="$SANDBOX" --libdir=lib \
        -Dman-pages=disabled -Ddocumentation=false \
        -Dinstalled_tests=false -Dtests=false \
        -Dintrospection=false \
        -Dselinux=disabled -Dxattr=false \
        -Dlibelf=disabled -Ddtrace=false \
        -Dsystemtap=false \
        -Dnls=disabled \
        -Dforce_posix_threads=true \
        --wrap-mode=nofallback

    ninja -C _build -j"$NUM_JOBS"
    ninja -C _build install

    cd "$ROOTDIR"
}

build_glib_phase() {
    echo "=== Phase: glib $BUILD_GLIB_VERSION ==="

    local dylibs="libglib-2.0.0.dylib libgmodule-2.0.0.dylib libgobject-2.0.0.dylib libgthread-2.0.0.dylib libgio-2.0.0.dylib"

    build_for_archs build_glib "$dylibs"

    # Copy .pc files and headers from x86_64 sandbox so downstream builds can find glib
    mkdir -p "$BUILD_DIR/lib/pkgconfig"
    if [ -d "$SANDBOX_X86_64/lib/pkgconfig" ]; then
        cp "$SANDBOX_X86_64/lib/pkgconfig/"*.pc "$BUILD_DIR/lib/pkgconfig/" 2>/dev/null || true
        # Fix .pc file prefix paths to point to BUILD_DIR instead of ephemeral sandbox
        for pc in "$BUILD_DIR/lib/pkgconfig/"*.pc; do
            sed -i '' "s|$SANDBOX_X86_64|$BUILD_DIR|g" "$pc" 2>/dev/null || true
        done
    fi
    if [ -d "$SANDBOX_X86_64/include/glib-2.0" ]; then
        mkdir -p "$BUILD_DIR/include"
        cp -R "$SANDBOX_X86_64/include/glib-2.0" "$BUILD_DIR/include/" 2>/dev/null || true
    fi
    if [ -d "$SANDBOX_X86_64/lib/glib-2.0/include" ]; then
        mkdir -p "$BUILD_DIR/lib/glib-2.0"
        cp -R "$SANDBOX_X86_64/lib/glib-2.0/include" "$BUILD_DIR/lib/glib-2.0/" 2>/dev/null || true
    fi

    # Create frameworks for each dylib
    # glib headers are in two places: include/glib-2.0/ and the glibconfig.h
    # which is generated at build time in lib/glib-2.0/include/
    local glib_headers="$BUILD_DIR/include/glib-2.0"
    local glibconfig_src="$BUILD_DIR/lib/glib-2.0/include/glibconfig.h"

    # Build the glib framework first with all headers
    build_framework "glib" "glib" "$BUILD_DIR/lib/libglib-2.0.0.dylib" "$glib_headers"

    # Copy glibconfig.h into the glib framework headers
    if [ -f "$glibconfig_src" ]; then
        mkdir -p "$SRCROOT/Frameworks/glib.framework/Versions/A/Headers"
        cp "$glibconfig_src" "$SRCROOT/Frameworks/glib.framework/Versions/A/Headers/"
    fi

    # Copy glib headers into the sub-framework Headers/ dirs
    for sub in libgthread libgmodule libgobject libgio; do
        build_framework "$sub" "$sub" "$BUILD_DIR/lib/$sub-2.0.0.dylib" ""
        mkdir -p "$SRCROOT/Frameworks/$sub.framework/Versions/A/Headers"
        if [ -d "$SRCROOT/Frameworks/glib.framework/Versions/A/Headers" ]; then
            cp -R "$SRCROOT/Frameworks/glib.framework/Versions/A/Headers/" \
                "$SRCROOT/Frameworks/$sub.framework/Versions/A/Headers/" 2>/dev/null || true
        fi
    done
}