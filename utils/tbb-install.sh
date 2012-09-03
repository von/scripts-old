#!/bin/sh
#
# Install/update Tor Browser Bundle
#
# Requires you have Erinn Clark's GPG key (0x63FEE659) installed to
# verify signature:
#
# https://www.torproject.org/docs/verifying-signatures.html.en
#
# gpg --keyserver x-hkp://pgp.mit.edu --recv-keys 0x63FEE659
#
######################################################################

set -o errexit  # Fail on any error
set -o nounset  # Unset variables are an error

######################################################################
#
# Some basic values

tor_url="https://www.torproject.org/"

wget_args="--no-check-certificate"  # We check gpg signature instead

######################################################################
#
# Support functions

DEBUG=0
debug()
# <message>
# Prints message if DEBUG is non-zero
{
    if [ ${DEBUG} -eq 1 ] ; then
        message "${1}"
    fi
}

QUIET=0
message()
# <message>
# Print message to stdout if QUIET is 0
{
    if [ ${QUIET} -eq 0 ] ; then
        echo ${1}
    fi
}

warn()
# <message>
# Write a message to stderr
{
    echo ${1} >&2
}

error()
# <message> [<exit status>]
# Write a message to stderr and exit
{
    warn "${1}"
    exit ${2:-1}
}

usage()
# Print usage
{
    message "Usage: $0 [-d|-q]"
}

######################################################################
#
# Utilitiy functions

check_gpg_keys()
{
    message "Checking for needed GPG keys"
    gpg --list-keys ${gpg_key}
    if [ $? -ne 0 ]; then
        error "Needed GPG key not installed: ${gpg_key}"
    fi
}

get_latest_version()
{
    local _url=${tor_url}"projects/torbrowser.html.en"
    local _bundle_regex=${bundle_prefix}"(.*)"${bundle_suffix}
    local _download_line="$(wget -q --no-check-certificate ${_url} -O - | grep -E ${_bundle_regex} | head -1)"
    if test -z "${_download_line}" ; then
        return
    fi
    # Must escape parens for expr and match whole line
    _bundle_regex=".*"${bundle_prefix}"\(.*\)"${bundle_suffix}".*"
    local _latest_version=$(expr "${_download_line}" : "${_bundle_regex}")
    if test -z "${_latest_version}" ; then
        return
    fi
    echo ${_latest_version}
}

get_installed_version()
{
    if test ! -d ${install_path} ; then
        return
    fi
    if test ! -e ${version_file} ; then
        return
    fi
    cat ${version_file}
}

######################################################################
#
# Main code

FORCE=0

args=$(getopt dfq $*)
set -- ${args}
for arg ; do
    case "${arg}" in
        -d)  # Debug mode
            DEBUG=1
            shift
            ;;
        -f)  # Force install/update
            FORCE=1
            ;;
        -q)  # Quiet mode
            QUIET=1
            shift
            ;;
        --)
            shift
            break
            ;;
    esac
done

if test ${DEBUG} -eq 1 -a ${QUIET} -eq 1 ; then
    error "Debug (-d) and quiet (-q) modes are incompatible."
fi

if [ ${QUIET} -eq 1 ]; then
    wget_args=${wget_args}" -q"
fi

# The following sets some key variables depending on our local system type.
#    bundle_prefix: The string preceding the version in the bundle name.
#    bundle_suffix: The string following the version in the bundle name.
#    bundle_path: The path to the bundle on the Tor website.
#    install_root: Where the bundle should be installed locally.
#    unpacked_bundle: directory containing install bundle under install_path
#    install_path: Full path of install
#    version_file: Path to file indicated version of installed bundle
#    gpg_key: Key used to verify bundle signature

sys=$(uname)
debug "System type is ${sys}"
case "${sys}" in
    Darwin)
        bundle_prefix="TorBrowser-"
        bundle_suffix="-osx-i386-en-US.zip"
        bundle_path="/dist/torbrowser/osx/"
        install_root="/Applications/"
        unpacked_bundle="TorBrowser_en-US.app/"
        install_path=${install_root}${unpacked_bundle}
        version_file=${install_path}"/VERSION"
        gpg_key="0x63FEE659"
        ;;

    Linux)
        bundle_prefix="tor-browser-gnu-linux-x86_64-"
        bundle_suffix="-dev-en-US.tar.gz"
        bundle_path="/dist/torbrowser/linux/"
        install_root="/usr/local/"
        unpacked_bundle="tor-browser_en-US/"
        install_path=${install_root}${unpacked_bundle}
        version_file=${install_path}"/VERSION"
        gpg_key="0x63FEE659"
        ;;

    *)
        echo "Unknown system ${sys}"
        exit 1
        ;;
esac

latest_version=$(get_latest_version)
if test -z "${latest_version}" ; then
    error "Could not determine latest version of Tor Borwser Bundle"
fi
debug "Latest version is ${latest_version}"

installed_version=$(get_installed_version)

if test -n "${installed_version}" ; then
    debug "Installed version is ${installed_version}"
    if test "${installed_version}" = "${latest_version}" ; then
        if [ ${FORCE} -eq 1 ]; then
            message "Forcing update."
        else
            message "Nothing to do."
            exit 0
        fi
    fi
fi

# Try to fail early...
check_gpg_keys

message "Installing new version ${latest_version}"
bundle=${bundle_prefix}${latest_version}${bundle_suffix}
tmp_dir=$(mktemp -d /tmp/tbb-install.XXXXXX)
debug "Temporary working directory is ${tmp_dir}"
cd ${tmp_dir}
bundle_url=${tor_url}${bundle_path}${bundle}
message "Downloading bundle from ${bundle_url}"
wget ${wget_args} -O ${bundle} ${bundle_url}
if test ! -e ${bundle} ; then
    error "Failed to download browser bundle."
fi

message "Checking GPG signature"
signature_file=${bundle}.asc
signature_url=${tor_url}${bundle_path}${signature_file}
wget ${wget_args} -O ${signature_file} ${signature_url}
if test ! -e ${signature_file} ; then
    error "Failed to download bundle signature."
fi
gpg --verify ${signature_file} ${bundle}
# We shouldn't need following because errexit is set, but to be safe...
if [ $? -ne 0 ] ; then
    error "GPG signature check failed."
fi

message "Unpacking ${bundle}"
case ${bundle} in
    *.zip)
        unzip -q ${bundle}
        ;;
    *.tar.gz)
        tar xfz ${bundle}
        ;;
    *)
        error "Do not know how to unpack ${bundle}"
        ;;
esac
if test ! -e ${unpacked_bundle} ; then
    error "Cannot find unpacked bundle ${unpacked_bundle}"
fi

# Move aside an existing install
old_install_path=${install_path%/}".OLD"
if test -d ${install_path} ; then
    sudo mv ${install_path} ${old_install_path}
fi

message "Installing new version to ${install_path}"
sudo mv ${tmp_dir}/${unpacked_bundle} ${install_root}

sudo echo ${latest_version} > ${version_file}

if test -d ${old_install_path} ; then
    debug "Cleaning up old version"
    sudo rm -rf ${old_install_path}
fi

message "Success."
exit 0