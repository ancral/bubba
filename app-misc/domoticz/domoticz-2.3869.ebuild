# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header$

EAPI="5"

inherit cmake-utils eutils systemd

#EGIT_REPO_URI="git://github.com/domoticz/domoticz.git"
COMMIT="3494b9e90270bab7b435681656038ad65be0aaf4"
CTIME=1450856617

SRC_URI="https://github.com/domoticz/domoticz/archive/${COMMIT}.zip -> ${PN}-${PV}.zip"
RESTRICT="mirror"
DESCRIPTION="Home automation system"
HOMEPAGE="http://domoticz.com/"
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~arm ~ppc"
IUSE="-staticboost systemd"

DEPEND="
	dev-util/cmake
"

RDEPEND="${DEPEND}
	net-misc/curl
	dev-libs/libusb
	dev-libs/libusb-compat
	dev-embedded/libftdi
	dev-db/sqlite
	dev-libs/boost
	sys-libs/zlib
"


src_unpack() {
	unpack ${A}
	mv ${WORKDIR}/${PN}-${COMMIT} ${S}
}

src_prepare() {
	# link build directory
	ln -s ${S} ${WORKDIR}/${PF}_build

	ProjectHash=${COMMIT:0:7}
	ProjectRevision=${PV:2}
	ProjectDate=$(date -d @${CTIME} +"%F %T")

	elog "building APPVERSION ${ProjectRevision}, APPHASH \"${ProjectHash}\", APPDATE ${ProjectDate}"

	echo -e "#define APPVERSION ${ProjectRevision}\n#define APPHASH \"${ProjectHash}\"\n#define APPDATE ${CTIME}\n" > appversion.h
	echo 'execute_process(COMMAND ${CMAKE_COMMAND} -E copy_if_different appversion.h appversion.h.txt)' > getgit.cmake

        sed \
                -e "/^Gitversion_GET_REVISION/cset(ProjectRevision ${ProjectRevision})" \
		-e "/^MATH(EXPR ProjectRevision/d" \
               	-i CMakeLists.txt


	# disable static boost:
	sed \
		-e "s:\${USE_STATIC_BOOST}:OFF:" \
		-i CMakeLists.txt
}

src_configure() {
	local mycmakeargs=(
		$(cmake-utils_use staticboost USE_STATIC_BOOST)
	)
#		-DCMAKE_BUILD_TYPE=Release

	cmake-utils_src_configure
}

src_install() {
	cmake-utils_src_install
	if use systemd ; then
		systemd_newunit "${FILESDIR}"/${PN}.service "${PN}.service"
		systemd_install_serviced "${FILESDIR}"/${PN}.service.conf
	else
		newinitd "${FILESDIR}"/${PN}.init.d ${PN}
		newconfd "${FILESDIR}"/${PN}.conf.d ${PN}
	fi
}
