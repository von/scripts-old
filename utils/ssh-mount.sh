#!/bin/sh
######################################################################
#
# Use mount_sshfs to mount a filesystem.
#
# Only argument is the target directory to mount to. This directory
# can have the following files:
#
# target : File containing the string to provide mount_sshfs for
#          the remote system. E.g. "vwelch@buildbot.ncsa.uiuc.edu:/"
#
######################################################################

# Binary
mount_sshfs="mount_sshfs"

if test $# -ne 1 ; then
    echo "Usage: $0 <mount path>"
    exit 1
fi

mountPath=$1
shift

targetFile=${mountPath}/target
if test -f $targetFile ; then
    target=`cat ${targetFile}`
else
    echo "Missing ${targetFile}"
    exit 1
fi

${mount_sshfs} ${target} ${mountPath}
