#!/bin/sh
######################################################################
#
# backup-email
#
# Backup my email to mss
#
# Assumes I have a kerberos ticket
#
######################################################################

mailbox="/var/mail/${USER}"

# Destination directory on mss
dest_dir="archive/mail"

# ftp command
ftp="ftp"

# gzip command
gzip="gzip"

# cat command
cat="cat"

# mss hostname
mss="mss.ncsa.uiuc.edu"

# scratch directory
scratch_dir="${HOME}/scratch"

######################################################################
# Exit on any error
set -e

# Figure out string for today's date
date=`date +%y%m%d`

# Name of backup mailbox
mbox_backup="mail.${date}.gz"

######################################################################

echo "Changing directory to $scratch_dir"
cd $scratch_dir

echo "Copying and compressing $mailbox"
$cat $mailbox | $gzip -c > $mbox_backup
ls -l $mbox_backup

echo "Transferring $mbox_backup to $mss"
$ftp $mss <<EOF
cd ${dest_dir}
put $mbox_backup
ls -l $mbox_backup
quit
EOF

echo "Removing $mbox_backup"
rm $mbox_backup

echo "Done"
exit 0

