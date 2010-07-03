#!/usr/bin/env python
"""Backup my cryptographic keys to a USB drive"""

import os.path
import shutil
import sys
from optparse import OptionParser


######################################################################
#
# Configuration
#

possibleUSBPaths = [
    "/Volumes/128MB USB",
]

filesToBackUp = [
    "~/Dropbox/Creds/KeePassDB.kdb",
    "~/KeePass.key",
    "~/.gnupg/pubring.gpg",
    "~/.gnupg/secring.gpg",
    "~/.gnupg/personal-revoke.asc",
]

######################################################################

def main(argv=None):
    # Do argv default this way, as doing it in the functional
    # declaration sets it at compile time.
    if argv is None:
        argv = sys.argv
    parser = OptionParser(
        usage="%prog", # printed with -h/--help
        version="%prog 0.1" # automatically generates --version
        )
    parser.add_option("-q", "--quiet", action="store_true", dest="quiet",
                      help="run quietly", default=False)
    (options, args) = parser.parse_args()
    if not options.quiet:
        print 'backup-keys running...'
    for USBpath in possibleUSBPaths:
        if os.path.isdir(USBpath):
            if not options.quiet:
                print "Using USB path: %s" % USBpath
            break
    else:
        print "No USB device found."
        return 1
    for file in filesToBackUp:
        if not options.quiet:
            print "Backing up %s" % file
        shutil.copy(os.path.expanduser(file),
                    os.path.join(USBpath, os.path.basename(file)))
    if not options.quiet:
        print "Done."
    return 0

if __name__ == "__main__":
    sys.exit(main())



