#!/bin/bash -eu

LIBPURPLE_VERSION="2.14.14"
LIBPURPLE_URL="https://downloads.sourceforge.net/project/pidgin/Pidgin/${LIBPURPLE_VERSION}/pidgin-${LIBPURPLE_VERSION}.tar.bz2"
# ponytail: SHA256 verified against pidgin.im release page
LIBPURPLE_SHA256="0ffc9994def10260f98a55cd132deefa8dc4a9835451cc0e982747bd458e2356"

##
# libpurple
#
build_libpurple() {
	prereq "libpurple" "${LIBPURPLE_URL}"

	# Verify tarball integrity
	status "Verifying libpurple tarball checksum..."
	echo "${LIBPURPLE_SHA256}  ${ROOTDIR}/source/libpurple.tar.bz2" | shasum -a 256 -c - || {
		error "libpurple tarball checksum mismatch — expected ${LIBPURPLE_SHA256}"
		exit 1
	}

	if [ ! -d "$ROOTDIR/source/libpurple" ]; then
		error "libpurple checkout not found"
		exit 1
	fi

	prereq "cyrus-sasl" \
		"https://github.com/cyrusimap/cyrus-sasl/releases/download/cyrus-sasl-2.1.27/cyrus-sasl-2.1.27.tar.gz"

	# Copy the headers from Cyrus-SASL
	status "Copying headers from Cyrus-SASL"
	quiet mkdir -p "$ROOTDIR/build/include/sasl"
	log cp -f "$ROOTDIR/source/cyrus-sasl/include/"*.h "$ROOTDIR/build/include/sasl"

	quiet pushd "$ROOTDIR/source/libpurple"

	# Protocols available in 2.14.14 — msn, oscar, and yahoo were removed upstream
	PROTOCOLS="bonjour,gg,irc,jabber,novell,sametime,simple,zephyr"

	if needsconfigure $@; then
	(
		status "Configuring libpurple"
		export ACLOCAL_FLAGS="-I $ROOTDIR/build/share/aclocal"
		export LIBXML_CFLAGS="-I/usr/include/libxml2"
		export LIBXML_LIBS="-lxml2"
		export MEANWHILE_CFLAGS="-I$ROOTDIR/build/include/meanwhile \
			-I$ROOTDIR/build/include/glib-2.0 \
			-I$ROOTDIR/build/lib/glib-2.0/include"
		export MEANWHILE_LIBS="-lmeanwhile -lglib-2.0 -liconv"
		export MSGFMT="$ROOTDIR/build/bin/msgfmt"
		CONFIG_CMD="./configure \
			--disable-dependency-tracking \
			--disable-gtkui \
			--disable-consoleui \
			--disable-perl \
			--enable-debug \
			--disable-static \
			--enable-shared \
			--enable-cyrus-sasl \
			--prefix=$ROOTDIR/build \
			--with-static-prpls=$PROTOCOLS \
			--disable-plugins \
			--disable-avahi \
			--disable-dbus \
			--enable-gnutls=no \
			--enable-nss=no \
			--enable-vv=no \
			--disable-gstreamer \
			--disable-idn"
		xconfigure "$BASE_CFLAGS -I/usr/include/kerberosIV -DHAVE_SSL \
				-DHAVE_OPENSSL -fno-common -DHAVE_ZLIB" \
			"$BASE_LDFLAGS -lsasl2 -ljson-glib-1.0 -lz" \
			"${CONFIG_CMD}" \
			"${ROOTDIR}/source/libpurple/libpurple/purple.h" \
			"${ROOTDIR}/source/libpurple/config.h"
	)
	fi

	status "Building and installing libpurple"
	log make -j $NUMBER_OF_CORES
	log make install

	status "Copying internal libpurple headers"
	log cp -f "$ROOTDIR/source/libpurple/libpurple/cmds.h" \
		  "$ROOTDIR/source/libpurple/libpurple/internal.h" \
		  "$ROOTDIR/source/libpurple/libpurple/protocols/gg/buddylist.h" \
		  "$ROOTDIR/source/libpurple/libpurple/protocols/gg/gg.h" \
		  "$ROOTDIR/source/libpurple/libpurple/protocols/gg/search.h" \
		  "$ROOTDIR/source/libpurple/libpurple/protocols/jabber/auth.h" \
		  "$ROOTDIR/source/libpurple/libpurple/protocols/jabber/bosh.h" \
		  "$ROOTDIR/source/libpurple/libpurple/protocols/jabber/buddy.h" \
		  "$ROOTDIR/source/libpurple/libpurple/protocols/jabber/caps.h" \
		  "$ROOTDIR/source/libpurple/libpurple/protocols/jabber/jutil.h" \
		  "$ROOTDIR/source/libpurple/libpurple/protocols/jabber/presence.h" \
		  "$ROOTDIR/source/libpurple/libpurple/protocols/jabber/si.h" \
		  "$ROOTDIR/source/libpurple/libpurple/protocols/jabber/jabber.h" \
		  "$ROOTDIR/source/libpurple/libpurple/protocols/jabber/iq.h" \
		  "$ROOTDIR/source/libpurple/libpurple/protocols/jabber/namespaces.h" \
		  "$ROOTDIR/source/libpurple/libpurple/protocols/irc/irc.h" \
		  "$ROOTDIR/source/libpurple/libpurple/protocols/gg/lib/libgadu.h" \
		  "$ROOTDIR/build/include/libpurple"

	status "Successfully installed libpurple"
	quiet popd
}