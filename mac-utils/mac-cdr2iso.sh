#!/bin/sh
######################################################################
#
# Convert CD-Rom to iso on Mac
#
# Kudos:
# http://www.slashdotdash.net/2006/08/14/create-iso-cd-dvd-image-with-mac-os-x-tiger-10-4/
#
# $Id$
#
######################################################################

if test $# -lt 1 ; then
    echo "Usage: $0 <destination iso>"
    exit 1
fi

dst=$1; shift

# Disk can be determined with 'drutil status'
# Todo: determine this dynamically, it is not consistent.
s=`drutil status | grep Name`
src=${s:(-10)}
if test -z "$src" ; then
    echo "No CDR detected."
    exit 1
fi

echo "Detected CDR at ${src}"

echo "Unmounting CD-ROM..."
diskutil unmountDisk $src

# Note addition of "s0" which is required
ddsrc=${src}s0

echo "Imaging CD-ROM..."
dd if=${ddsrc} of=${dst} bs=2048 || exit 1

echo "Success."
ls -l $dst

echo "Ejectng CD-ROM..."
drutil eject

exit 0
