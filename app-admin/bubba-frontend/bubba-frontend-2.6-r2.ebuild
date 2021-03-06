# Copyright 2015-2016 gordonb3 <gordon@bosvangennip.nl>
# Distributed under the terms of the GNU General Public License v2
# $Header$
#
# Note: place jquery javascripts directly in this build
#       there's no sense in making this shared code, because
#	newer versions of jquery are not compatible
#

EAPI="5"

inherit eutils perl-module systemd

MY_PV=${PV/_*/}
JQ_PV="1.4.2"
JQUI_PV="1.8.12"
DESCRIPTION="Excito B3 administrative scripts"
HOMEPAGE="http://www.excito.com/"
SRC_URI="http://b3.update.excito.org/pool/main/b/${PN}/${PN}_${MY_PV}.tar.gz
	http://code.jquery.com/jquery-${JQ_PV}.js
	http://code.jquery.com/ui/${JQUI_PV}/jquery-ui.js -> jquery-ui-${JQUI_PV}.js"

RESTRICT="mirror"
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~arm ~ppc"
IUSE="+apache2 nginx systemd debug"

REQUIRED_USE="^^ ( apache2 nginx )"

DEPEND="
	=net-libs/nodejs-0.10.5[-snapshot]
	dev-ruby/coffee-script
	dev-perl/Locale-PO
	dev-perl/Getopt-Long-Descriptive
	app-admin/bubba-backend
"

RDEPEND="${DEPEND}
	app-admin/hddtemp
	dev-lang/php[cgi,fpm,sockets,json,xml,gd,pdo,crypt,imap]
	apache2? ( dev-lang/php[apache2] )
	apache2? ( >=www-servers/apache-2.4.9[apache2_modules_proxy,apache2_modules_proxy_fcgi,apache2_modules_proxy_http,apache2_modules_rewrite] )
	nginx? ( www-servers/nginx[nginx_modules_http_proxy,nginx_modules_http_rewrite,nginx_modules_http_fastcgi,nginx_modules_http_access,nginx_modules_http_auth_basic,nginx_modules_http_referer] )
	www-apps/codeigniter-bin
	dev-php/libbubba-info-php
	dev-php/PEAR-HTTP_Request2
	systemd? ( sys-apps/systemd )
"

S=${WORKDIR}/${PN}

pkg_setup() {
	ebegin "checking for coffee"
	# verify that the coffee command is available during install
	if which coffee 1>/dev/null  2>/dev/null ; then
		eend 0
	else
		eend 1 ""
		elog "attempting to install coffee"
		npm install -g coffee-script
	fi
	which coffee 1>/dev/null  2>/dev/null || die "failed to install coffee - please verify npm command"
}

src_unpack() {
	unpack ${PN}_${MY_PV}.tar.gz
}

src_prepare() {
	# Fix patch errors due to DOS line endings in some files
	sed -i "s/\r$//" ${S}/admin/controllers/ajax_settings.php
	sed -i "s/\r$//" ${S}/admin/libraries/Session.php

	# Patch source files
	epatch ${FILESDIR}/${PN}-${MY_PV}-gentoo.patch
	if use systemd; then
		epatch ${FILESDIR}/${PN}-${MY_PV}-systemd.patch
		epatch ${FILESDIR}/${PN}-${MY_PV}-samba4.patch
	fi
	epatch ${FILESDIR}/${PN}-${MY_PV}-minidlna.patch
	epatch ${FILESDIR}/${PN}-${MY_PV}-php7.patch

	# debug USE flag enables extra logging in web UI
	if use debug; then
		sed  -i "s/^\(define('ENVIRONMENT', '\).*\(');\)$/\1development\2/"  ${S}/admin/index.php
	fi

	# inconsistent service names
	if use systemd; then
		sed -i "s/cupsd/cups/" admin/controllers/services.php
	else
		sed -i "s/forked-daapd/daapd/" admin/controllers/services.php
		sed -i "s/forked-daapd/daapd/" admin/models/networkmanager.php
	fi
}


src_compile() {
	# There is an issue with the msgfmt check format routine always
	# comparing the translations to msgid_plural
	find po -type f -exec sed -i "s/\([^\%]\)\%d /\1@NUMBER@ /" {} \;
	emake DESTDIR=${ED}

	find po -type f -exec sed -i "s/@NUMBER@/\%d/" {} \;

}


src_install() {
	emake install DESTDIR=${ED}
	insinto /opt/bubba/web-admin
	doins -r admin
	insinto /opt/bubba/web-admin/admin/views/default/_js
	newins ${DISTDIR}/jquery-${JQ_PV}.js jquery.js
	newins ${DISTDIR}/jquery-ui-${JQUI_PV}.js jquery-ui.js

	PHP_CLI_INI_PATH=$(php -n --ini | grep -v "(none)" | awk '{print $NF}')
	PHP_APACHE_INI_PATH=$(echo ${PHP_CLI_INI_PATH} | sed "s/cli/apache2/")
	PHP_FPM_INI_PATH=$(echo ${PHP_CLI_INI_PATH} | sed "s/cli/fpm/")

	echo "date.timezone=\"`cat /etc/timezone`\"" >> php5-cgi.conf
	echo "short_open_tag=On" >> php5-cgi.conf
	echo "always_populate_raw_post_data=-1" >> php5-cgi.conf

	insinto ${PHP_FPM_INI_PATH}/ext
	newins php5-cgi.conf bubba-admin.ini
	dosym ${PHP_FPM_INI_PATH}/ext/bubba-admin.ini ${PHP_FPM_INI_PATH}/ext-active/bubba-admin.ini

	if use apache2; then
		echo "date.timezone=\"`cat /etc/timezone`\"" >> php5-apache.conf
		echo "short_open_tag=On" >> php5-apache.conf
		echo "always_populate_raw_post_data=-1" >> php5-apache.conf

		insinto ${PHP_APACHE_INI_PATH}/ext
		newins php5-apache.conf bubba-admin.ini
		dosym ${PHP_APACHE_INI_PATH}/ext/bubba-admin.ini ${PHP_APACHE_INI_PATH}/ext-active/bubba-admin.ini

		insinto /etc/apache2/vhosts.d
		newins ${FILESDIR}/apache.conf bubba.conf
	fi

	if use nginx; then
		insinto /etc/nginx/vhosts.d
		newins ${FILESDIR}/nginx.conf bubba.conf
	fi


	insinto /var/lib/bubba
	doins lite_php_browscap.ini

	dodir /var/log/web-admin 

	if use systemd; then
		systemd_dounit ${FILESDIR}/bubba-adminphp.service
	else
		newinitd ${FILESDIR}/bubba-adminphp.initd bubba-adminphp
	fi

	insinto /etc/bubba
	newins ${FILESDIR}/bubba-adminphp.conf adminphp.conf
	use nginx && sed "s/apache/nginx/" -i ${ED}/etc/bubba/adminphp.conf

	dodoc "${S}/debian/copyright" ${FILESDIR}/Changelog
	newdoc "${S}/debian/changelog" changelog.deb
	insinto /usr/share/doc/${PF}/examples
	docompress -x /usr/share/doc/${PF}/examples
	doins php5-cgi.conf php5-apache.conf php5-xcache.ini ${FILESDIR}/*.conf ${FILESDIR}/*.initd
}


pkg_postinst() {
	if use systemd; then
		systemctl daemon-reload
		systemctl is-enabled bubba-adminphp >/dev/null || {
			elog "enable bubba-adminphp service"
			systemctl enable bubba-adminphp >/dev/null
		}
		systemctl is-active bubba-adminphp >/dev/null && systemctl stop bubba-adminphp >/dev/null
		elog "auto starting bubba-adminphp service"
		systemctl start bubba-adminphp
	else
		rc-status default | grep -q bubba-adminphp || {
			elog "add bubba-adminphp service to default runlevel"
			rc-config add bubba-adminphp default >/dev/null
		}
		rc-service bubba-adminphp status >/dev/null && rc-service bubba-adminphp stop >/dev/null
		elog "auto starting bubba-adminphp service"
		rc-service bubba-adminphp start
	fi
	if use nginx; then
		elog "Although this package was configured for nginx, you may still use it"
		elog "also with apache, provided it was configured with the right use flags."
	else
		elog "Although this package was configured for apache, you may still use it"
		elog "also with nginx, provided it was configured with the right use flags."
	fi
	elog "Sample config files have been placed in /usr/share/doc/${PF}/examples"
	if use nginx; then
		elog ""
		elog "If you are switching to apache, please do not forget to enable the"
		elog "bubba-admin plugin for mod_php as well by copying php5-apache.conf"
		elog "from the examples folder to ${PHP_APACHE_INI_PATH}/ext/bubba-admin.ini"
		elog "and create a symlink to it from ${PHP_APACHE_INI_PATH}/ext-active"
	fi

}
