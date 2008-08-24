#!/bin/sh
######################################################################
#
# copy-vm
#
# Make a copy of a VMWare VM.
#
# $Id$
#
######################################################################

# Exit on any error
set -e

if test $# -lt 2 ; then
	echo "Usage: $0 <source vm> <destination vm>"
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

echo "Copying virtual machine (${src} -> ${dst})..."
cp -ax "${src}" "${dst}"

cd "${dst}"

echo "Renaming disk ${dst}.vmdk..."
vmware-vdiskmanager -n "${src}.vmdk" "${dst}.vmdk"

echo "Fixing configuration...."
mv "${src}.vmx" "${dst}.vmx"
sed -i "s/${src}/${dst}/" "${dst}.vmx"

echo "Success."
exit 0

