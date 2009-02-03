#!/usr/bin/env python
"""
Backup delicious bookmarks.

$Id$
"""

from getpass import getpass
from optparse import OptionParser
import os.path
import subprocess
import sys

# We are using OptionParser for future expansion and easy usage output
usage ="usage: %prog [options] delicious-username"
parser = OptionParser(usage=usage, version="$Id$")
parser.add_option("-o", "--output", dest="filename",
                  default="./delicious-bookmarks.xml",
                  help="write bookmarks to FILENAME (default is 'delicious-bookmarks.xml')")
parser.add_option("-p", "--password", dest="password", default=None,
                  help="use PASSWORD for delicious account")
(options, args) = parser.parse_args()

if len(args) < 1:
    parser.error("Delicious username required.")

username = args.pop(0)

if len(args) > 0:
    print "Ignoring extra arguments: " + ' '.join(args)

if options.password:
    password = options.password
else:
    password = getpass("Please enter delicious password for %s: " % username)

backupfile = options.filename

subprocess.call(["wget",
                 "--no-check-certificate",
                 "--user=%s" % username,
                 "--password=%s" % password,
                 "-O%s" % backupfile,
                 "https://api.del.icio.us/v1/posts/all"])

sys.exit(0)


