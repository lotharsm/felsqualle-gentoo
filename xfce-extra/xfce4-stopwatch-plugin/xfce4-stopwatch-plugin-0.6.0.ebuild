# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit meson xdg-utils

DESCRIPTION="A simple stopwatch plugin for Xfce panel"
HOMEPAGE="
	https://docs.xfce.org/panel-plugins/xfce4-stopwatch-plugin
	https://gitlab.xfce.org/panel-plugins/xfce4-stopwatch-plugin/
"
SRC_URI="
	https://archive.xfce.org/src/panel-plugins/${PN}/${PV%.*}/${P}.tar.xz
"

LICENSE="BSD-2"
SLOT="0"
KEYWORDS="~amd64"

DEPEND="
	>=dev-libs/glib-2.50.0
	>=x11-libs/gtk+-3.22.0:3
	>=xfce-base/libxfce4util-4.16.0:=
	>=xfce-base/xfce4-panel-4.16.0:=
"
RDEPEND="
	${DEPEND}
	kernel_linux? ( sys-apps/net-tools )
"
BDEPEND="
	>=sys-devel/gettext-0.19.8
	virtual/pkgconfig
"

pkg_postinst() {
	xdg_icon_cache_update
}

pkg_postrm() {
	xdg_icon_cache_update
}
