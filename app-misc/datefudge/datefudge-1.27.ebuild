# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit toolchain-funcs

DESCRIPTION="A program (and preload library) to fake system date"
HOMEPAGE="https://packages.qa.debian.org/d/datefudge.html"
SRC_URI="mirror://debian/pool/main/d/${PN}/${PN}_${PV}.tar.xz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~alpha amd64 arm arm64 ~hppa ~loong ~m68k ~mips ppc ppc64 ~riscv ~s390 sparc x86 ~amd64-linux ~x86-linux ~ppc-macos ~x64-macos"

src_prepare() {
	default

	sed -i \
		-e '/dpkg-parsechangelog/d' \
		Makefile || die
}

src_compile() {
	emake CC="$(tc-getCC)" libdir="/usr/$(get_libdir)" VERSION="${PV}"
}

src_install() {
	emake DESTDIR="${D}" CC="$(tc-getCC)" libdir="/usr/$(get_libdir)" install
	einstalldocs
}
