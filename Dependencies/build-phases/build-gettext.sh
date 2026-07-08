#!/bin/bash -eu
# build-gettext.sh — Build gettext (libintl only) as universal framework
# Shell function, sourced by build-universal-deps.sh

BUILD_GETTEXT_VERSION="1.0"
BUILD_GETTEXT_FILE="gettext-${BUILD_GETTEXT_VERSION}.tar.xz"
BUILD_GETTEXT_SHA256="71132a3fb71e68245b8f2ac4e9e97137d3e5c02f415636eb508ae607bc01add7"

build_gettext() {
    local src_dir
    src_dir="$(vendored_extract "$BUILD_GETTEXT_FILE" "$BUILD_GETTEXT_SHA256" "gettext-$BUILD_GETTEXT_VERSION")"

    cd "$src_dir"

    # Only build gettext-runtime (libintl), not tools or other bindings
    ./configure --prefix="$SANDBOX" \
        --disable-java --disable-csharp --disable-perl --disable-php --disable-ruby \
        --disable-libasprintf --disable-openmp --disable-curses \
        --disable-native-java --disable-native-csharp \
        --disable-dependency-tracking \
        --without-emacs --without-cvs --without-x \
        --disable-docs --disable-relocatable \
        --enable-shared --disable-static \
        --host="$HOST_TRIPLE"

    make -j"$NUM_JOBS"
    make install

    cd "$ROOTDIR"
}

build_gettext_phase() {
    echo "=== Phase: gettext $BUILD_GETTEXT_VERSION ==="
    build_for_archs build_gettext "libintl.8.dylib"
    build_framework "libintl" "libintl" "$BUILD_DIR/lib/libintl.8.dylib" "$BUILD_DIR/include"

    # Copy libintl headers to build dir so glib/json-glib can include <libintl.h>
    if [ -d "$SANDBOX_X86_64/include" ]; then
        mkdir -p "$BUILD_DIR/include"
        cp "$SANDBOX_X86_64/include/"libintl*.h "$BUILD_DIR/include/" 2>/dev/null || true
    fi
}