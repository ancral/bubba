# Copyright 2015-2016 gordonb3 <gordon@bosvangennip.nl>
# Distributed under the terms of the GNU General Public License v2
# $Header$

EAPI="5"

inherit eutils

DESCRIPTION="Bubba platform information library"
HOMEPAGE="http://www.excito.com/"
SRC_URI="http://b3.update.excito.org/pool/main/libb/${PN}/${PN}_${PV}.tar.gz"

RESTRICT="mirror"
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~arm ~ppc"
IUSE=""

DEPEND=""

RDEPEND="${DEPEND}"



src_prepare() {
	sed -i "s/libtool --mode/libtool --tag=CC --mode/" Makefile
}

src_compile() {
	LDFLAGS="-Wl,-O1" make all
}


src_install() {
	make DESTDIR=${ED} install
	dodoc debian/changelog debian/copyright
}
