#!/bin/sh
######################################################################
#
# backup-home
#
# Backup my home directory
#
######################################################################
#
# Build list of files to exclude
#

dir_contents () {
  find $HOME/$1 -printf ./$1/%P\\n
}

exclude_list="/tmp/backup-home-exclude-$$"

rm -f $exclude_list

# My old home
dir_contents vwelch-old >> $exclude_list

# The netscape cache
dir_contents .netscape/cache >> $exclude_list

# Any emacs backup files
find $HOME -name \*~ -printf ./%P\\n >> $exclude_list

######################################################################
#
# Now tar everything up
#

date=`date +%Y-%m-%d`

output="/tmp/home-${date}.tar.gz"

cd $HOME

tar cvfz $output -X $exclude_list .

######################################################################
#
# Clean up
#

rm -f $exclude_list

######################################################################
#
# Done
#

ls -l $output

exit 0
