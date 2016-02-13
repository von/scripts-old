#!/bin/sh
######################################################################
#
# backup-home
#
# Backup my home directory
#
######################################################################

set -o errexit  # Exit on any error

######################################################################

usage() {
  echo "Usage: $0 <target directory>"
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

target=$1; shift

######################################################################
#
# Build list of files to exclude
#

exclude_list="/tmp/backup-home-exclude-$$"

rm -f $exclude_list

echo "Box Sync" >> $exclude_list
echo "Dropbox" >> $exclude_list
echo "Google Drive" >> $exclude_list
echo "old-laptop-jan2014" >> $exclude_list

# Any emacs backup files
echo "*~" >> $exclude_list

######################################################################
#
# Make backup
#

echo "Backing up to ${target}"

mkdir -p -m 0700 "${target}" || exit 1

(cd "$HOME" && tar -c -f - -X ${exclude_list} . ) | (cd "${target}" && tar -x -v -f - )

######################################################################
#
# Clean up
#

rm -f $exclude_list

######################################################################
#
# Done
#

echo "Success."

exit 0
