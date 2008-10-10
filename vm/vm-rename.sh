#!/bin/sh
######################################################################
#
# vm-rename
#
# Rename a VMWare VM.
#
# Kudos: http://blog.kovyrin.net/2007/04/08/how-to-clone-virtual-machine-with-vmware-server/
#
# $Id$
#
######################################################################

# Exit on any error
set -e

if test $# -lt 2 ; then
	echo "Usage: $0 <original vm name> <target vm name>"
	exit 1
fi

src=`basename "$1"`; shift
dst=`basename "$1"`; shift

if test ! -d "${src}" ; then
	echo "Source VM does not exist (${src})"
	exit 1
fi

if test -d "${dst}" ; then
	echo "Destination VM already exists (${dst})"
	exit 1
fi

echo "Renaming virtual machine (${src} -> ${dst})..."
mv "${src}" "${dst}"

cd "${dst}"

echo "Renaming disk ${dst}.vmdk..."
vmware-vdiskmanager -n "${src}.vmdk" "${dst}.vmdk"

echo "Fixing configuration...."
mv "${src}.vmx" "${dst}.vmx"
sed -i "s/${src}/${dst}/" "${dst}.vmx"

echo "Success."
exit 0

