#!/bin/sh
######################################################################
#
# Install GT
#
# $Id$
#
######################################################################

# Exit on any error
set -e

######################################################################
#
# Defaults

# Version to install
GT_VERSION="4.0.6"

# Temporary directory
tmp_dir=/tmp

# configure options
conf_opts=""

# Don't install rls right now because it doesn't build on my intel mac
conf_opts="${conf_opts} --disable-rls"

######################################################################
#
# Subroutines
#

# log_cmd command arg1 arg2...
# Run command with arguments, logging output and exiting on error
log_cmd()
{
    log "Executing: $*"
    $* >> $log_file 2>&1
}

# log message arg1 arg2...
# Log message
log()
{
    echo $* >> $log_file
}

# flagged_cmd flag_file description command arg1 arg2...
# If flag_file does not exist, print description and run command.
# On success, touch flag_file
# On error, exist
flagged_cmd()
{
    flag_file=$1; shift
    description=$1; shift
    if test -f ${flag_file} ; then
	:
    else
	log $description
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
  -b           Binary install instead of source.
  -g path      Path to GLOBUS_LOCATION
  -v version   Version to install (default ${GT_VERSION})
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
	    GT_VERSION=$1; shift
	    echo "Installing version ${GT_VERSION}"
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

version_mod=`echo $GT_VERSION | sed -e "s/\./_/g"`
major_version=`echo $GT_VERSION | cut -d . -f 1`
minor_version=`echo $GT_VERSION | cut -d . -f 2`
point_version=`echo $GT_VERSION | cut -d . -f 3`

log_file=${GLOBUS_LOCATION}/gt-install-log


if test $binary_install -eq 1 ; then
    echo "Binary install not supported yet."
    exit 1
else
    source_dir=gt${GT_VERSION}-all-source-installer

fi
tarball=${source_dir}.tar.gz
if test $major_version -eq "4" -a $minor_version -eq "0" ; then
    # 4.0.x are of the form "/pub/gt4/4.0/4.0.4/installers/etc/..."
    source_url=ftp://ftp.globus.org/pub/gt${major_version}/${major_version}.${minor_version}/${GT_VERSION}/installers/src/${tarball}
elif test $major_version -eq "4" -a $minor_version -eq "1" ; then
    # 4.1.x are of the form "/pub/gt4/4.1.1/installers/etc/..."
    source_url=ftp://ftp.globus.org/pub/gt${major_version}/${GT_VERSION}/installers/src/${tarball}
else
    # Punt and assume gt 4.0.x format
   source_url=ftp://ftp.globus.org/pub/gt${major_version}/${major_version}.${minor_version}/${GT_VERSION}/installers/src/${tarball}
fi

# Flags
gt_installed_flag=${GLOBUS_LOCATION}/gt-installed
gt_unpacked_flag=${tmp_dir}/${source_dir}/gt-unpacked
gt_configured_flag=${tmp_dir}/${source_dir}/gt-configured
gt_made_flag=${tmp_dir}/${source_dir}/gt-made

######################################################################

if test -f $gt_installed_flag ; then
    echo "Already installed - $gt_installed_flag exists."
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
echo "Starting log file: $log_file"
tail -n 0 --pid=$$ -f $log_file &
# Sleep a couple seconds here to let tail start up
sleep 2

log "Install started"
log_cmd date
log "GLOBUS_LOCATION: $GLOBUS_LOCATION"
log "GT_VERSION: $GT_VERSION (major: ${major_version} minor: ${minor_version} point: ${point_version})"
log "JAVA_HOME: $JAVA_HOME"
log "ANT_HOME: $ANT_HOME"

######################################################################
#
# Get source tarball
cd $GLOBUS_LOCATION

flagged_cmd ${tarball} "Getting Globus source tarball" wget --progress=dot:mega $source_url

# if test ! -f ${tarball} ; then
#     log "Getting tarball from $source_url"
#     # -nv here prevents screens full of progress dots
#     log_cmd wget -nv $source_url
# fi

if test ! -f ${tarball} ; then
    log "Failed to get tarball."
    exit 1
fi

######################################################################
#
# Unpack source tarball

cd ${tmp_dir}

flagged_cmd ${gt_unpacked_flag} "Unpacking source tarball..." tar xfz ${GLOBUS_LOCATION}/${tarball}

cd ${source_dir}

######################################################################
#
# Configure GT

conf_opts="${conf_opts} --prefix=${GLOBUS_LOCATION}"

flagged_cmd ${gt_configured_flag} "Running configure..." ./configure ${conf_opts}

######################################################################
#
# Build GT

flagged_cmd ${gt_made_flag} "Building..." make

######################################################################
#
# And install

flagged_cmd ${gt_installed_flag} "Installing..." make install

######################################################################
#
# Success.

log "Success"
exit 0

    