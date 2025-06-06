# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: ssl-cert.eclass
# @MAINTAINER:
# maintainer-needed@gentoo.org
# @AUTHOR:
# Max Kalika <max@gentoo.org>
# @SUPPORTED_EAPIS: 7 8
# @BLURB: Eclass for SSL certificates
# @DESCRIPTION:
# This eclass implements a standard installation procedure for installing
# self-signed SSL certificates.
# @EXAMPLE:
# "install_cert /foo/bar" installs ${ROOT}/foo/bar.{key,csr,crt,pem}

case ${EAPI} in
	7|8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_SSL_CERT_ECLASS} ]]; then
_SSL_CERT_ECLASS=1

inherit edo

# @ECLASS_VARIABLE: SSL_CERT_MANDATORY
# @PRE_INHERIT
# @DESCRIPTION:
# Set to non zero if ssl-cert is mandatory for ebuild.
: "${SSL_CERT_MANDATORY:=0}"

# @ECLASS_VARIABLE: SSL_CERT_USE
# @PRE_INHERIT
# @DESCRIPTION:
# Use flag to append dependency to.
: "${SSL_CERT_USE:=ssl}"

# @ECLASS_VARIABLE: SSL_DEPS_SKIP
# @PRE_INHERIT
# @DESCRIPTION:
# Set to non zero to skip adding to DEPEND and IUSE.
: "${SSL_DEPS_SKIP:=0}"

if [[ "${SSL_DEPS_SKIP}" == "0" ]]; then
	if [[ "${SSL_CERT_MANDATORY}" == "0" ]]; then
		RDEPEND="${SSL_CERT_USE}? ( dev-libs/openssl )"
		if [[ ${EAPI} != 7 ]]; then
			IDEPEND="${SSL_CERT_USE}? ( dev-libs/openssl )"
		fi
		IUSE="${SSL_CERT_USE}"
	else
		RDEPEND="dev-libs/openssl"
		if [[ ${EAPI} != 7 ]]; then
			IDEPEND="dev-libs/openssl"
		fi
	fi
fi

# @FUNCTION: gen_cnf
# @INTERNAL
# @USAGE:
# @DESCRIPTION:
# Initializes variables and generates the needed
# OpenSSL configuration file and a CA serial file
#
gen_cnf() {
	# Location of the config file
	SSL_CONF="${T}/${$}ssl.cnf"
	# Location of the CA serial file
	SSL_SERIAL="${T}/${$}ca.ser"

	# These can be overridden in the ebuild
	SSL_DAYS="${SSL_DAYS:-730}"
	SSL_BITS="${SSL_BITS:-4096}"
	SSL_MD="${SSL_MD:-sha256}"
	SSL_COUNTRY="${SSL_COUNTRY:-US}"
	SSL_STATE="${SSL_STATE:-California}"
	SSL_LOCALITY="${SSL_LOCALITY:-Santa Barbara}"
	SSL_ORGANIZATION="${SSL_ORGANIZATION:-SSL Server}"
	SSL_UNIT="${SSL_UNIT:-For Testing Purposes Only}"
	SSL_COMMONNAME="${SSL_COMMONNAME:-localhost}"
	SSL_EMAIL="${SSL_EMAIL:-root@localhost}"

	# Create the CA serial file
	echo "01" > "${SSL_SERIAL}"

	# Create the config file
	ebegin "Generating OpenSSL configuration${1:+ for CA}"
	cat <<-EOF > "${SSL_CONF}"
		[ req ]
		prompt             = no
		default_bits       = ${SSL_BITS}
		distinguished_name = req_dn
		[ req_dn ]
		C                  = ${SSL_COUNTRY}
		ST                 = ${SSL_STATE}
		L                  = ${SSL_LOCALITY}
		O                  = ${SSL_ORGANIZATION}
		OU                 = ${SSL_UNIT}
		CN                 = ${SSL_COMMONNAME}${1:+ CA}
		emailAddress       = ${SSL_EMAIL}
	EOF
	eend $?

	return $?
}

# @FUNCTION: get_base
# @INTERNAL
# @USAGE: [if_ca]
# @RETURN: <base path>
# @DESCRIPTION:
# Simple function to determine whether we're creating
# a CA (which should only be done once) or final part
#
get_base() {
	if [ "${1}" ] ; then
		echo "${T}/${$}ca"
	else
		echo "${T}/${$}server"
	fi
}

# @FUNCTION: gen_key
# @INTERNAL
# @USAGE: <base path>
# @DESCRIPTION:
# Generates an RSA key
#
gen_key() {
	local base=$(get_base "$1")
	nonfatal edob -m "Generating ${SSL_BITS} bit RSA key${1:+ for CA}" \
		openssl genrsa -out "${base}.key" "${SSL_BITS}"
	return $?
}

# @FUNCTION: gen_csr
# @INTERNAL
# @USAGE: <base path>
# @DESCRIPTION:
# Generates a certificate signing request using
# the key made by gen_key()
#
gen_csr() {
	local base=$(get_base "$1")
	nonfatal edob -m "Generating Certificate Signing Request${1:+ for CA}" \
		openssl req -config "${SSL_CONF}" -new \
			-key "${base}.key" -out "${base}.csr"
	return $?
}

# @FUNCTION: gen_crt
# @INTERNAL
# @USAGE: <base path>
# @DESCRIPTION:
# Generates either a self-signed CA certificate using
# the csr and key made by gen_csr() and gen_key() or
# a signed server certificate using the CA cert previously
# created by gen_crt()
#
gen_crt() {
	local base=$(get_base "$1")
	if [ "${1}" ] ; then
		nonfatal edob -m "Generating self-signed X.509 Certificate for CA" \
			openssl x509 -extfile "${SSL_CONF}" \
				-${SSL_MD} \
				-days ${SSL_DAYS} -req -signkey "${base}.key" \
				-in "${base}.csr" -out "${base}.crt"
	else
		local ca=$(get_base 1)
		nonfatal edob -m "Generating authority-signed X.509 Certificate" \
			openssl x509 -extfile "${SSL_CONF}" \
				-days ${SSL_DAYS} -req -CAserial "${SSL_SERIAL}" \
				-CAkey "${ca}.key" -CA "${ca}.crt" -${SSL_MD} \
				-in "${base}.csr" -out "${base}.crt"
	fi
	return $?
}

# @FUNCTION: gen_pem
# @INTERNAL
# @USAGE: <base path>
# @DESCRIPTION:
# Generates a PEM file by concatinating the key
# and cert file created by gen_key() and gen_cert()
#
gen_pem() {
	local base=$(get_base "$1")
	ebegin "Generating PEM Certificate"
	(cat "${base}.key"; echo; cat "${base}.crt") > "${base}.pem"
	eend $?

	return $?
}

# @FUNCTION: install_cert
# @USAGE: <certificates>
# @DESCRIPTION:
# Uses all the private functions above to generate and install the
# requested certificates.
# <certificates> are full pathnames relative to ROOT, without extension.
#
# Example: "install_cert /foo/bar" installs ${ROOT}/foo/bar.{key,csr,crt,pem}
#
install_cert() {
	if [ $# -lt 1 ] ; then
		eerror "At least one argument needed"
		return 1;
	fi

	case ${EBUILD_PHASE} in
		config|preinst|postinst) ;;
		*) die "install_cert cannot be called in ${EBUILD_PHASE}" ;;
	esac

	# Generate a CA environment #164601
	gen_cnf 1 || return 1
	gen_key 1 || return 1
	gen_csr 1 || return 1
	gen_crt 1 || return 1
	echo

	gen_cnf || return 1
	echo

	local count=0
	for cert in "$@" ; do
		# Check the requested certificate
		if [ -z "${cert##*/}" ] ; then
			ewarn "Invalid certification requested, skipping"
			continue
		fi

		# Check for previous existence of generated files
		for type in key csr crt pem ; do
			if [ -e "${ROOT}${cert}.${type}" ] ; then
				ewarn "${ROOT}${cert}.${type}: exists, skipping"
				continue 2
			fi
		done

		# Generate the requested files
		gen_key || continue
		gen_csr || continue
		gen_crt || continue
		gen_pem || continue
		echo

		# Install the generated files and set sane permissions
		local base=$(get_base)
		install -d "${ROOT}${cert%/*}"
		install -m0400 "${base}.key" "${ROOT}${cert}.key"
		install -m0444 "${base}.csr" "${ROOT}${cert}.csr"
		install -m0444 "${base}.crt" "${ROOT}${cert}.crt"
		install -m0400 "${base}.pem" "${ROOT}${cert}.pem"
		: $(( ++count ))
	done

	# Resulting status
	if [ ${count} = 0 ] ; then
		eerror "No certificates were generated"
		return 1
	elif [ ${count} != ${#} ] ; then
		ewarn "Some requested certificates were not generated"
	fi
}

fi
