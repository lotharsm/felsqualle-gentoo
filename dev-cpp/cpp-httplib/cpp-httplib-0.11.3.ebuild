# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{8..11} )
inherit cmake-multilib python-any-r1

DESCRIPTION="C++ HTTP/HTTPS server and client library"
HOMEPAGE="https://github.com/yhirose/cpp-httplib"
SRC_URI="https://github.com/yhirose/cpp-httplib/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0/0.11" # soversion
KEYWORDS="~amd64 ~x86"

IUSE="brotli ssl zlib"

RDEPEND="
	brotli? ( app-arch/brotli:=[${MULTILIB_USEDEP}] )
	ssl? ( dev-libs/openssl:=[${MULTILIB_USEDEP}] )
	zlib? ( sys-libs/zlib[${MULTILIB_USEDEP}] )
"
DEPEND="${RDEPEND}"
BDEPEND="${PYTHON_DEPS}"

src_configure() {
	local mycmakeargs=(
		-DHTTPLIB_COMPILE=yes
		-DBUILD_SHARED_LIBS=yes
		-DHTTPLIB_USE_BROTLI_IF_AVAILABLE=no
		-DHTTPLIB_USE_OPENSSL_IF_AVAILABLE=no
		-DHTTPLIB_USE_ZLIB_IF_AVAILABLE=no
		-DHTTPLIB_REQUIRE_BROTLI=$(usex brotli)
		-DHTTPLIB_REQUIRE_OPENSSL=$(usex ssl)
		-DHTTPLIB_REQUIRE_ZLIB=$(usex zlib)
		-DPython3_EXECUTABLE="${PYTHON}"
	)
	cmake-multilib_src_configure
}
