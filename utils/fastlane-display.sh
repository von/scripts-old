#!/bin/sh
######################################################################
#
# fastlane-display.sh
#
# We just downloaded a PDF from fastlane but my system doesn't realize
# it's a PDF. Find the file in /tmp and display it.
#
# $Id$
#
######################################################################

# This finds the newest file from fastlane in /tmp
files="/tmp/gov.nsf.fastlane* /tmp/FastLane*.Print"
file=`ls -t1 ${prefix} | head -1`

# Put a '.pdf' extension on it
tmp_file="/tmp/$$.pdf"
cp $file $tmp_file

# And open it
exec open $tmp_file



