#!/usr/bin/env python
"""
Backup delicious or pinboard.in bookmarks.

$Id$

Looks for a configuration file in ~/.delicious-backup.conf with the
follow format:

[Backup]
path=/path/to/backup

[Account]
username=delicious-username
password=delicious-password

[API]
URL=URL-to-use
"""

from ConfigParser import ConfigParser
from optparse import OptionParser
import os.path
import subprocess
import sys

def errorExit(fmt, *vals):
    print fmt % vals
    sys.exit(1)

defaultConfFilename = "~/.delicious-backup.config"

def main(argv=None):
    if argv is None:
        argv = sys.argv

    # We are using OptionParser for future expansion and easy usage output
    usage ="usage: %prog [options] delicious-username"
    parser = OptionParser(usage=usage,
                          version="$Id$")
    parser.add_option("-c", "--configFile", dest="confFilename",
                      default=defaultConfFilename,
                      help="read configuration from FILENAME (default is '%s')" % defaultConfFilename)
    parser.add_option("-v", "--verbose",
                      dest="verbose", default=False, action="store_true",
                      help="turn on verbose mode")
        
    (options, args) = parser.parse_args(argv[1:])

    if options.verbose:
        def verbose(fmt, *vals):
            print fmt % vals
    else:
        def verbose(fmt, *vals):
            pass

    if len(args) > 0:
        verbose("Ignoring extra arguments: " + ' '.join(args))

    config = ConfigParser()
    verbose("Reading configuration from %s" % options.confFilename)
    config.read(os.path.expanduser(options.confFilename))

    # Make sure needed sections exist
    if not config.has_section("Account"):
        errorExit("Configuration file \"%s\" is missing section \"Account\"", options.confFilename)
    if not config.has_section("Backup"):
        errorExit("Configuration file \"%s\" is missing section \"Backup\"", options.confFilename)

    # XXX Could use better error handling here
    username = config.get("Account", "username")
    password = config.get("Account", "password")
    backupfile = config.get("Backup", "path")
    URL = config.get("API", "URL")

    # Make sure we have all the values we need.
    if username is None:
        errorExit("Must specify username in configuration file or on commandline.")
    if password is None:
        errorExit("Must specify password in configuration file or on commandline.")
    if backupfile is None:
        # Should never actually get here since there is a default for this
        errorExit("Must specify backup filename in configuration file or on commandline.")

    cmdArgs = ["wget",
               "--no-check-certificate",
               "--user=%s" % username,
               "--password=%s" % password,
               "-O%s" % os.path.expanduser(backupfile),
               URL]

    if not options.verbose:
        cmdArgs.append("-q")

    subprocess.call(cmdArgs)

    return 0

if __name__ == "__main__":
    sys.exit(main())

