#!/bin/sh
######################################################################
#
# doc_viewer
#
# Given a document and a program on the command line, make a copy
# of the document and spawn the viewer in the background on the
# document.
#
# Meant to be used with mutt and .mailcap. Example .mailcap would
# be:
#
# application/msword; doc_viewer soffice %s
#
######################################################################
#
# Parse coomand line which is program and document
#

program=$1
shift

document=$1
shift

######################################################################

# Need to copy the document because as soon as we exit the calling
# application (e.g. mutt) may remove it
newdoc=`mktemp /tmp/doc_view.XXXXXX`
cp "${document}" ${newdoc}

${program} ${newdoc} &

# XXX This leaves the document lying around. Not sure how to go about
#     cleaning it up