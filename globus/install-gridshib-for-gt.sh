#!/bin/sh
######################################################################
#
# Install GridShib for GT
#
# $Id$
#
######################################################################
#
# Defaults

version="0.5.2"

######################################################################

# Exit on any error
set -e

# log_cmd command arg1 arg2...
# Run command with arguments, logging output and exiting on error
log_cmd()
{
    # Explicitly check exit status since 'set -e' won't catch it
    # because of the tee
    $* >> $log_file 2>&1
}

# log message arg1 arg2...
# Log message
log()
{
    echo $* >> $log_file
}

# flagged_cmd flag_file command arg1 arg2...
# If flag_file does not exist, run command.
# On success, touch flag_file
# On error, exist
flagged_cmd()
{
    flag_file=$1; shift
    if test -f ${flag_file} ; then
	:
    else
	log_cmd $*
	touch ${flag_file}
    fi
}

######################################################################
#
# Parse commandline options
#

binary_install=0

usage=<<EOF
Usage: $0 <options>

Options:
  -b    Binary install instead of source.
  -g path      Path to GLOBUS_LOCATION
  -v version   Version to install (default $version)
EOF
args=`getopt bg:v: $*`
if test $? != 0 ; then
    echo $usage
    exit 1
fi
set -- $args
for arg ; do
    case "$arg" in
	-b)
	    echo "Installing from binary."
	    binary_install=1
	    shift;;
	-g)
	    shift
	    export GLOBUS_LOCATION=$1; shift
	    echo "Setting GLOBUS_LOCATION=${GLOBUS_LOCATION}"
	    ;;
	-v)
	    shift
	    version=$1; shift
	    echo "Installing version ${version}"
	    ;;
	--)
	    shift; break;;
    esac
done

######################################################################

if test X${GLOBUS_LOCATION} = X ; then
    echo "GLOBUS_LOCATION not defined."
    exit 1
fi

if test ! -d ${GLOBUS_LOCATION} ; then
    echo "GLOBUS_LOCATION($GLOBUS_LOCATION) does not exist."
    exit 1
fi

if test ! -w ${GLOBUS_LOCATION} ; then
    echo "GLOBUS_LOCATION($GLOBUS_LOCATION) not writable."
    exit 1
fi

if test X${JAVA_HOME} = X ; then
    echo "JAVA_HOME is not set."
    exit 1
fi

if test X${ANT_HOME} = X ; then
    echo "ANT_HOME is not set."
    exit 1
fi

######################################################################

version_mod=`echo $version | sed -e "s/\./_/g"`

log_file=${GLOBUS_LOCATION}/gridshib-gt-install-log

if test $binary_install -eq 1 ; then
    source_dir=gridshib-gt-bin-${version_mod}-GT4.0
else
    source_dir=gridshib-gt-source-${version_mod}
fi
tarball=${source_dir}.tar.gz
source_url=http://gridshib.globus.org/downloads/${tarball}
tmp_dir=/tmp

# Flags
gridshib_installed_flag=${GLOBUS_LOCATION}/gridshib-gt-installed
gridshib_unpacked_flag=${tmp_dir}/${source_dir}/gridshib-gt-unpacked

######################################################################

if test -f $gridshib_installed_flag ; then
    echo "Already installed - $gridshib_installed_flag exists."
    exit 0
fi

######################################################################
#
# Find needed binaries

DEPLOY_GAR=${GLOBUS_LOCATION}/bin/globus-deploy-gar

######################################################################
#
# Start log file

# Output log file as we go along
tail -n 0 -f $log_file &
log_pid=$!

cleanup()
{
    echo Cleaning up.
    kill $log_pid
}
trap cleanup EXIT

log "Install started"
log_cmd date >> $log_file

######################################################################
#
# Get source tarball
cd $tmp_dir

if test ! -f ${tarball} ; then
    log "Getting tarball from $source_url"
    log_cmd wget -nv $source_url
fi

######################################################################
#
# Unpack source tarball

flagged_cmd ${gridshib_unpacked_flag} tar xfz ${tarball}

######################################################################
#
# And deploy

cd ${source_dir}
if test $binary_install -eq 0 ; then
    # Source install
    log_cmd ant deploy
    log "Deplying EchoService"
    log_cmd ant deploy-echoservice
    log "Deplying tests"
    log_cmd ant deploy-tests
else
    # Binary install
    log "Deploying schemas gar"
    log_cmd ${DEPLOY_GAR} gridshib-gt-schemas-${version_mod}.gar
    log "Deploying stubs gar"
    log_cmd ${DEPLOY_GAR} gridshib-gt-stubs-${version_mod}.gar
    log "Deploying main gar"
    log_cmd ${DEPLOY_GAR} gridshib-gt-core-${version_mod}.gar
    log "Deploying GridShib Echo service"
    log_cmd ${DEPLOY_GAR} gridshib-gt-echo-${version_mod}.gar
fi

touch $gridshib_installed_flag

######################################################################
#
# Success.

log "Success"
exit 0

    