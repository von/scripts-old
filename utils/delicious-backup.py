#!/usr/bin/env python
"""
Backup delicious bookmarks.

$Id$

Looks for a configuration file in ~/.delicious-backup.conf with the
follow format:

[Backup]
path=/path/to/backup

[Account]
username=delicious-username
password=delicious-password
"""

from ConfigParser import ConfigParser
from optparse import OptionParser
import os.path
import subprocess
import sys
import urllib2

def errorExit(fmt, *vals):
    print fmt % vals
    sys.exit(1)

defaultConfFilename = "~/.delicious-backup.config"

deliciousURL = "https://api.del.icio.us/v1/posts/all"

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

    # Make sure we have all the values we need.
    if username is None:
        errorExit("Must specify username in configuration file or on commandline.")
    if password is None:
        errorExit("Must specify password in configuration file or on commandline.")
    if backupfile is None:
        # Should never actually get here since there is a default for this
        errorExit("Must specify backup filename in configuration file or on commandline.")

    # Fetch with basic auth
    # Kudos: http://www.voidspace.org.uk/python/articles/urllib2.shtml

    # create a password manager
    password_mgr = urllib2.HTTPPasswordMgrWithDefaultRealm()

    # Add the username and password.
    # XXX I'm not quite sure what the realm is here, None is a catch all
    password_mgr.add_password(None, deliciousURL, username, password)

    handler = urllib2.HTTPBasicAuthHandler(password_mgr)

    opener = urllib2.build_opener(handler)
    urllib2.install_opener(opener)


    bookmarks = urllib2.urlopen(deliciousURL).read()

    with open(backupfile, "w") as backup:
        backup.write(bookmarks)

    return 0

if __name__ == "__main__":
    sys.exit(main())

