#!/usr/bin/env python
"""
Back up a LAMP web server, i.e. apache configuration, mysql database
and web server documents.

$Id$

Uses a configuration file with the following format:

[web]
confDir=/path/to/apache/configuration
dataDir=/path/to/data/dir

[database]
user=username
password=password

[scp]
dest=user@host:/dest/path
"""
from __future__ import with_statement
import atexit
import ConfigParser
import optparse
import os
import os.path
import socket
import subprocess
import sys
import tempfile
import time

######################################################################
#
# Utility functions

def runCmd(cmd):
    """Run command described by array and trturn outout as array of lines.

    If command returns non-zero an Exception is thrown."""
    sys.stdout.flush()
    subprocess.check_call(cmd,
                          # Try to keep stderr and stdout in sync
                          stderr=subprocess.STDOUT)

######################################################################

def main(argv=None):
    if argv is None:
        argv = sys.argv
    # Use parser for usage and future expansion
    usage="usage: %prog [options]"
    parser = optparse.OptionParser(usage=usage)
    parser.add_option("-D", "--skipDatabaseBackup",
                      action="store_false", dest="backupDatabase", default=True,
                      help="Skip backup of database")
    (options, args) = parser.parse_args(argv)
    # Remove script name from arguments
    args.pop(0)
    if len(args) < 1:
        parser.error("No configuration file specified.")
    config = ConfigParser.ConfigParser()
    for fp in [open(file) for file in args]:
        config.readfp(fp)
    # Create temporary working directory with tarball
    workingDir = tempfile.mkdtemp()
    atexit.register(os.rmdir, workingDir)
    tarfile = os.path.join(workingDir,
                           "backup-%s-%s.tar.gz" % (socket.gethostname(),
                                                    time.strftime("%y%m%d")))
    # Paths we will be including in tarball
    pathsToBackup = []
    pathsToBackup.append(config.get("web", "confDir"))
    pathsToBackup.append(config.get("web", "dataDir"))
    if options.backupDatabase:
        print "Dumping database."
        databaseBackup = os.path.join(workingDir, "databaseBackup.sql")
        atexit.register(os.remove, databaseBackup)
        with open(databaseBackup, "w") as backupFD:
            pipe = subprocess.Popen(["/usr/bin/mysqldump",
                                     "--user=%s" % config.get("database",
                                                              "user"),
                                     "--password=%s" % config.get("database",
                                                                  "password"),
                                     "--all-databases"],
                                    stdout=backupFD)
            pipe.wait()
            if pipe.returncode != 0:
                print "Database dump failed."
                return 1
        pathsToBackup.append(databaseBackup)
    print "Running tar...."
    print "Backing up: " + " ".join(pathsToBackup)
    runCmd(["tar", "cfzP", tarfile] + pathsToBackup)
    atexit.register(os.remove, tarfile)
    scpDest = config.get("scp", "dest")
    print "Backing up tarfile via scp to %s..." % scpDest
    runCmd(["scp",
            # Use blowfish for speed
            "-c", "blowfish",
            # Batch mode, no passwords or other prompts
            "-B",
            tarfile,
            scpDest])
    print "Success."
    return 0

if __name__ == "__main__":
    sys.exit(main())
