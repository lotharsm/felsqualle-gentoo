# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake flag-o-matic git-r3

DESCRIPTION="Open Source Flight Simulator"
HOMEPAGE="https://www.flightgear.org/"
EGIT_REPO_URI="https://gitlab.com/flightgear/${PN}.git"
EGIT_BRANCH="next"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS=""
IUSE="cpu_flags_x86_sse2 dbus debug examples gdal qt6 +udev +utils"

# Needs --fg-root with path to flightgear-data passed to test runner passed,
# not really worth patching
RESTRICT="test"

# zlib is some strange auto-dep from simgear
# TODO add osgXR
COMMON_DEPEND="
	dev-db/sqlite:3
	>=dev-games/openscenegraph-3.6.0[jpeg,png]
	~dev-games/simgear-${PV}[gdal=]
	media-libs/openal
	>=media-libs/plib-1.8.5
	>=media-libs/speex-1.2.0:0
	media-libs/speexdsp:0
	media-sound/gsm
	sys-libs/zlib
	virtual/glu
	x11-libs/libX11
	dbus? ( >=sys-apps/dbus-1.6.18-r1 )
	gdal? ( >=sci-libs/gdal-2.0.0:= )
	qt6? (
		dev-qt/qtbase:6[gui,network,widgets]
		dev-qt/qtdeclarative:6
	)
	udev? ( virtual/udev )
	utils? (
		media-libs/freeglut
		media-libs/freetype:2
		media-libs/glew:0
		media-libs/libpng:0
		virtual/opengl
		qt6? ( dev-qt/qtwebsockets:6 )
	)
"
# libXi and libXmu are build-only-deps according to FindGLUT.cmake
DEPEND="${COMMON_DEPEND}
	dev-libs/boost
	x11-base/xorg-proto
	utils? (
		x11-libs/libXi
		x11-libs/libXmu
	)
"
RDEPEND="${COMMON_DEPEND}
	~games-simulation/${PN}-data-${PV}
"
BDEPEND="qt6? ( dev-qt/qttools:6 )"

PATCHES=(
	"${FILESDIR}/${PN}-2024.1.1-cmake.patch"
	"${FILESDIR}/${PN}-2024.1.1-fix-fgpanel.patch"
)

DOCS=(AUTHORS ChangeLog NEWS README Thanks)

src_configure() {
	# -Werror=lto-type-mismatch, -Werror=odr
	# https://bugs.gentoo.org/859217
	# https://sourceforge.net/p/flightgear/codetickets/2908/
	filter-lto

	local mycmakeargs=(
		-DBUILD_SHARED_LIBS=OFF
		-DCHECK_FOR_QT5=OFF
		-DCHECK_FOR_QT6=ON
		-DENABLE_AUTOTESTING=OFF
		-DENABLE_FGCOM=$(usex utils)
		-DENABLE_FGELEV=$(usex utils)
		-DENABLE_FGJS=$(usex utils)
		-DENABLE_FGVIEWER=$(usex utils)
		-DENABLE_GDAL=$(usex gdal)
		-DENABLE_GPSSMOOTH=$(usex utils)
		-DENABLE_HID_INPUT=$(usex udev)
		-DENABLE_IAX=$(usex utils)
		-DENABLE_JS_DEMO=$(usex utils)
		-DENABLE_JSBSIM=ON
		-DENABLE_LARCSIM=ON
		-DENABLE_METAR=$(usex utils)
		-DENABLE_PLIB_JOYSTICK=ON # NOTE look for defaults changes in CMake
		-DENABLE_QT=$(usex qt6)
		-DENABLE_RTI=OFF
		-DENABLE_SENTRY=OFF # sentry-native masked
		-DENABLE_HUD=ON
		-DENABLE_PUI=ON
		-DENABLE_SIMD=$(usex cpu_flags_x86_sse2)
		-DENABLE_STGMERGE=ON
		-DENABLE_SWIFT=OFF # swift pilot client not packaged yet
		-DENABLE_TRAFFIC=$(usex utils)
		-DENABLE_UIUC_MODEL=ON
		-DENABLE_VR=OFF
		-DENABLE_YASIM=ON
		-DEVENT_INPUT=$(usex udev)
		-DFG_BUILD_TYPE=Nightly
		-DFG_DATA_DIR=/usr/share/${PN}
		-DJSBSIM_TERRAIN=ON
		-DOSG_FSTREAM_EXPORT_FIXED=OFF # TODO also see simgear
		-DSP_FDMS=ON
		-DSYSTEM_CPPUNIT=OFF # NOTE we do not build tests anyway
		-DSYSTEM_FLITE=OFF
		-DSYSTEM_HTS_ENGINE=OFF
		-DSYSTEM_SPEEX=ON
		-DSYSTEM_GSM=ON
		-DSYSTEM_SQLITE=ON
		-DSYSTEM_OSGXR=ON
		-DUSE_AEONWAVE=OFF
		-DUSE_DBUS=$(usex dbus)
		-DWITH_FGPANEL=$(usex utils)
	)
	if use gdal && use utils; then
		mycmakeargs+=(-DENABLE_DEMCONVERT=ON)
	else
		mycmakeargs+=(-DENABLE_DEMCONVERT=OFF)
	fi
	if use qt6 && use utils; then
		mycmakeargs+=(-DENABLE_FGQCANVAS=ON)
	else
		mycmakeargs+=(-DENABLE_FGQCANVAS=OFF)
	fi

	cmake_src_configure
}

src_install() {
	cmake_src_install

	# Install bash completion (TODO zsh)
	# Uncomment below when scripts stops writing files...
#	sed -e "s|/usr/local/share/FlightGear|${GAMES_DATADIR}/${PN}|" \
#		-i scripts/completion/fg-completion.bash || die 'unable to replace FG_ROOT'
#	newbashcomp scripts/completion/fg-completion.bash ${PN}

	# Install examples and other misc files
	if use examples; then
		docompress -x /usr/share/doc/"${PF}"/{examples,tools}
		docinto examples
		dodoc -r scripts/java scripts/perl scripts/python
		docinto examples/c++
		dodoc -r scripts/example/*
		docinto tools
		dodoc -r scripts/atis scripts/tools/*
	fi

	# Install nasal script syntax
	insinto /usr/share/vim/vimfiles/syntax
	doins scripts/syntax/{ac3d,nasal}.vim
	insinto /usr/share/vim/vimfiles/ftdetect/
	doins "${FILESDIR}"/{ac3d,nasal}.vim
}

pkg_postinst() {
	if use qt6; then
		einfo "To use launcher, run fgfs with '--launcher' parameter"
	fi
}
