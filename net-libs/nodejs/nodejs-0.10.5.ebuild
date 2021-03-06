# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/net-libs/nodejs/nodejs-0.10.30.ebuild,v 1.4 2015/04/08 18:04:57 mgorny Exp $

EAPI=5

# has known failures. sigh.
RESTRICT="test mirror"

PYTHON_COMPAT=( python2_7 )

inherit python-any-r1 pax-utils toolchain-funcs

DESCRIPTION="Evented IO for V8 Javascript"
HOMEPAGE="http://nodejs.org/"
SRC_URI="http://nodejs.org/dist/v${PV}/node-v${PV}.tar.gz"

LICENSE="Apache-1.1 Apache-2.0 BSD BSD-2 MIT"
SLOT="0"
KEYWORDS="~arm ~ppc"
IUSE="+npm -snapshot"

RDEPEND="dev-libs/openssl"
DEPEND="${PYTHON_DEPS}
	${RDEPEND}"

S=${WORKDIR}/node-v${PV}

CFLAGS="-pipe"


src_prepare() {
	# fix compilation on Darwin
	# http://code.google.com/p/gyp/issues/detail?id=260
	sed -i -e "/append('-arch/d" tools/gyp/pylib/gyp/xcode_emulation.py || die

	# make sure we use python2.* while using gyp
	sed -i -e  "s/python/python2/" deps/npm/node_modules/node-gyp/gyp/gyp || die

	# less verbose install output (stating the same as portage, basically)
	sed -i -e "/print/d" tools/install.py || die

	tc-export CC CXX
}

src_configure() {
	local myconf=""
	! use npm && myconf="--without-npm ${myconf}"
	! use snapshot && myconf="--without-snapshot ${myconf}"

	"${PYTHON}" configure --prefix="${EPREFIX}"/usr --without-dtrace ${myconf} || die
}

src_compile() {
	local V=1
	export V
#	emake out/Makefile
#	emake -C out mksnapshot
#	pax-mark m out/Release/mksnapshot
	emake CFLAGS="${CFLAGS}" CXXFLAGS="${CFLAGS}"
}

src_install() {
	"${PYTHON}" tools/install.py install "${D}"

	use npm && dohtml -r "${ED}"/usr/lib/node_modules/npm/html/*
	rm -rf "${ED}"/usr/lib/node_modules/npm/doc "${ED}"/usr/lib/node_modules/npm/html
	rm -rf "${ED}"/usr/lib/dtrace

#	pax-mark -m "${ED}"/usr/bin/node
}

src_test() {
	"${PYTHON}" tools/test.py --mode=release simple message || die
}
