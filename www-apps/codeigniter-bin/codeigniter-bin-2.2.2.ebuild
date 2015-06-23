# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header$

EAPI="4"

inherit eutils user systemd

KEYWORDS="~amd"


DESCRIPTION="CodeIgniter PHP framework for full-featured web applications"
SRC_URI="https://github.com/bcit-ci/CodeIgniter/archive/${PV}.zip"
RESTRICT="bindist mirror"
SLOT="0"
IUSE=""


MY_PN="CodeIgniter"
S="${WORKDIR}/${MY_PN}-${PV}"
LICENSE="${MY_PN}"


# Installation dependencies.
DEPEND=""

# Runtime dependencies.
RDEPEND=">=dev-lang/php-5.1.6"

src_install() {
	find -name index.html -exec rm {} \;
	dodir /opt/codeigniter
	find ${S} -maxdepth 2 -type d -name system -exec cp -a {} ${D}/opt/codeigniter/ \;
	dodoc license.txt
	
}
