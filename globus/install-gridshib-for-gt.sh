#!/bin/sh
######################################################################
#
# Install GridShib for GT (from source)
#
# $Id$
#
######################################################################

# Exit on any error
set -e

######################################################################
#
# Parse commandline options
#

binary_install=0

usage=<<EOF
Usage: $0 <options>

Options:
  -b    Binary install instead of source.
EOF
args=`getopt b $*`
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

######################################################################

version="0.5.1"
version_mod=`echo $version | sed -e "s/\./_/g"`

log_file=${GLOBUS_LOCATION}/gridsib-gt-intall-log
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

echo "Install started" >> $log_file
date >> $log_file

######################################################################
#
# Get source tarball
cd $tmp_dir

if test ! -f ${tarball} ; then
    echo "Getting tarball from $source_url" >> $log_file
    wget $source_url || exit 1
fi

######################################################################
#
# Unpack source tarball

if test ! -f ${gridshib_unpacked_flag} ; then
    tar xvfz ${tarball} || exit 1
    touch $gridshib_unpacked_flag
fi

######################################################################
#
# Check for urn:oasis:names:tc:SAML:1.0:protocol in ns.excludes
# See: http://bugzilla.globus.org/globus/show_bug.cgi?id=5117

if test $binary_install -eq 0 ; then
    echo "Checking for problem build-stubs.xml..."
    if grep "urn:oasis:names:tc:SAML:1.0:protocol" ${GLOBUS_LOCATION}/share/globus_wsrf_tools/build-stubs.xml > /dev/null ; then
	echo "Found. Patching ${GLOBUS_LOCATION}/share/globus_wsrf_tools/build-stubs.xml" | tee -a $log_file
	cd ${GLOBUS_LOCATION}
	cp share/globus_wsrf_tools/build-stubs.xml share/globus_wsrf_tools/build-stubs.xml.orig
	patch -p0 <<"EOF" | tee -a $log_file
--- share/globus_wsrf_tools/build-stubs.xml     2007-03-22 21:06:36.000000000 -0500
+++ share/globus_wsrf_tools/build-stubs.xml.patched     2007-03-22 21:19:49.000000000 -0500
@@ -120,7 +120,7 @@
     <property name="source.binding.dir" location="."/>
     <property name="binding.protocol" value="http"/>
     <property name="stubs.timeout" value="180"/>
-    <property name="ns.excludes" value="-x http://docs.oasis-open.org/wsrf/2004/06/wsrf-WS-BaseFaults-1.2-draft-01.xsd -x http://docs.oasis-open.org/wsrf/2004/06/wsrf-WS-BaseFaults-1.2-draft-01.wsdl -x http://docs.oasis-open.org/wsrf/2004/06/wsrf-WS-ResourceLifetime-1.2-draft-01.xsd -x http://docs.oasis-open.org/wsrf/2004/06/wsrf-WS-ResourceLifetime-1.2-draft-01.wsdl -x http://docs.oasis-open.org/wsrf/2004/06/wsrf-WS-ResourceProperties-1.2-draft-01.xsd -x http://docs.oasis-open.org/wsrf/2004/06/wsrf-WS-ResourceProperties-1.2-draft-01.wsdl -x http://docs.oasis-open.org/wsrf/2004/06/wsrf-WS-ServiceGroup-1.2-draft-01.xsd -x http://docs.oasis-open.org/wsrf/2004/06/wsrf-WS-ServiceGroup-1.2-draft-01.wsdl -x http://docs.oasis-open.org/wsn/2004/06/wsn-WS-BaseNotification-1.2-draft-01.xsd -x http://docs.oasis-open.org/wsn/2004/06/wsn-WS-BaseNotification-1.2-draft-01.wsdl -x http://schemas.xmlsoap.org/ws/2004/04/trust -x http://schemas.xmlsoap.org/ws/2002/12/policy -x http://schemas.xmlsoap.org/ws/2002/07/utility -x http://schemas.xmlsoap.org/ws/2004/04/sc -x http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd -x http://www.w3.org/2000/09/xmldsig# -x http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd -x urn:oasis:names:tc:SAML:1.0:protocol"/>
+    <property name="ns.excludes" value="-x http://docs.oasis-open.org/wsrf/2004/06/wsrf-WS-BaseFaults-1.2-draft-01.xsd -x http://docs.oasis-open.org/wsrf/2004/06/wsrf-WS-BaseFaults-1.2-draft-01.wsdl -x http://docs.oasis-open.org/wsrf/2004/06/wsrf-WS-ResourceLifetime-1.2-draft-01.xsd -x http://docs.oasis-open.org/wsrf/2004/06/wsrf-WS-ResourceLifetime-1.2-draft-01.wsdl -x http://docs.oasis-open.org/wsrf/2004/06/wsrf-WS-ResourceProperties-1.2-draft-01.xsd -x http://docs.oasis-open.org/wsrf/2004/06/wsrf-WS-ResourceProperties-1.2-draft-01.wsdl -x http://docs.oasis-open.org/wsrf/2004/06/wsrf-WS-ServiceGroup-1.2-draft-01.xsd -x http://docs.oasis-open.org/wsrf/2004/06/wsrf-WS-ServiceGroup-1.2-draft-01.wsdl -x http://docs.oasis-open.org/wsn/2004/06/wsn-WS-BaseNotification-1.2-draft-01.xsd -x http://docs.oasis-open.org/wsn/2004/06/wsn-WS-BaseNotification-1.2-draft-01.wsdl -x http://schemas.xmlsoap.org/ws/2004/04/trust -x http://schemas.xmlsoap.org/ws/2002/12/policy -x http://schemas.xmlsoap.org/ws/2002/07/utility -x http://schemas.xmlsoap.org/ws/2004/04/sc -x http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd -x http://www.w3.org/2000/09/xmldsig# -x http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"/>
 
     <path id="fullclasspath">
         <pathelement location="."/>
EOF
	cd $tmp_dir
    fi
fi

######################################################################
#
# And deploy

cd ${source_dir}
if test $binary_install -eq 0 ; then
    # Source install
    ant deploy | tee -a $log_file
    echo "Deplying EchoService" | tee -a $log_file
    ant deploy-echoservice | tee -a $log_file
    echo "Deplying tests" | tee -a $log_file
    ant deploy-tests | tee -a $log_file
else
    # Binary install
    echo "Deploying schemas gar" | tee -a $log_file
    ${DEPLOY_GAR} gridshib-gt-schemas-${version_mod}.gar | tee -a $log_file
    echo "Deploying stubs gar" | tee -a $log_file
    ${DEPLOY_GAR} gridshib-gt-stubs-${version_mod}.gar | tee -a $log_file
    echo "Deploying main gar" | tee -a $log_file
    ${DEPLOY_GAR} gridshib-gt-${version_mod}.gar | tee -a $log_file
    echo "Deploying GridShib Echo service" | tee -a $log_file
    ${DEPLOY_GAR} gridshib-gt-echo-${version_mod}.gar | tee -a $log_file
fi

touch $gridshib_installed_flag

######################################################################
#
# Success.

echo "Success" | tee -a $log_file
exit 0

    