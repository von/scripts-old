#!/bin/sh
#
# Convert .dmg file to .iso
#
# Kudos: http://www.macosxhints.com/article.php?story=20040121135301830
#
# $Id$

# Exit on any error
set -e

usage() {
  echo "Usage: $0 <source> <dest.iso>"
  echo " <source> can be a .dmg image or a directory."
}

if test $# -ne 2 ; then
    usage
    exit 1
fi

src=$1; shift
dest=$1; shift

echo "Creating $dest..."
hdiutil makehybrid -o $dest -iso $src
echo "Success."
exit 0

