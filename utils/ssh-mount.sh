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
umount="umount"

# -L Follow symlinks
mount_sshfs_opts="-L"

if test $# -ne 1 ; then
    echo "Usage: $0 <mount path>"
    exit 1
fi

mountPath=$1
shift

if test ! -d ${mountPath} ; then
    echo "Mount path (${mountPath}) does not exist."
    exit 1
fi

# Expand to full path
mountPath=`(cd ${mountPath}; pwd)`

# Is mount path already mounted?
df ${mountPath} | grep ${mountPath} > /dev/null
status=$?

if test ${status} -eq 0 ; then
    # It's probably a stale mount, so go ahead and umount it
    # If we had a way to test for a stale mount, we could do that and
    # figure out if we're already done.
    echo "Already mounted. Forcing umount."
    ${umount} -f ${mountPath}
fi

targetFile=${mountPath}/ssh-mount-target

if test -f $targetFile ; then
    target=`cat ${targetFile}`
else
    echo "Missing mount configuration file (${targetFile})."
    exit 1
fi

echo "Mounting ${mountPath}"
${mount_sshfs} ${mount_sshfs_opts} ${target} ${mountPath}
status=$?

if test $status -eq 0 ; then
    echo "Success."
else
    echo "Failed."
    exit $status
fi

exit 0

