#!/bin/sh
######################################################################
#
# Back up ~/Documents to a USB drive. Designed to be used with
# "Do Something When" - http://www.azarhi.com/Projects/DSW/
#
# $Id$
#
######################################################################

# Exit on any error
set -e

rsync="rsync"
# -c: Use checksums instead of modification time and size - this seems
# to work better.
rsyncOpts="-auvc --delete --delete-excluded"

sourceDir="${HOME}/Documents"
echo "Source path is ${sourcePath}"

# We assume this script is run from the USB drive
usbPath=`dirname "${0}"`
echo "USB path is ${usbPath}"

set -x
${rsync} ${rsyncOpts} "${sourceDir}" "${usbPath}"
set +x

echo "Success."
exit 0
