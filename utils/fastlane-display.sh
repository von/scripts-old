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

DOWNLOAD_DIR="${HOME}/Downloads/"

# Allow globs to expand to empty strings if they don't match anything
shopt -s nullglob

# Find all fastlane files in our download directory
files=`echo \
${DOWNLOAD_DIR}/gov.nsf.fastlane.*.DisplayPDFServlet \
${DOWNLOAD_DIR}/FastLane*.Print \
${DOWNLOAD_DIR}/FastLane.*Display \
`

# XXX This test isn't working
if test "X" = "${files}" ; then
    echo "No Fastlane download found in ${DOWNLOAD_DIR}"
    exit 0
fi

# Find the latest
file=`ls -1t ${files} | head -1`

echo $0

echo "Opening ${file} as PDF"

tmp_file="/tmp/fastlane-display-${RANDOM}-$$.pdf"

cp ${file} ${tmp_file}
open ${tmp_file}

exit 0



