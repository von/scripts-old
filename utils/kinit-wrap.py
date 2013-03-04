#!/usr/bin/env python
"""Obtain a valid Kerberos TGT and then execute given command."""

from __future__ import print_function  # So we can get at print()

import argparse
import os
import os.path
import subprocess
import sys
import tempfile

output = print
debug = print

def main(argv=None):
    # Do argv default this way, as doing it in the functional
    # declaration sets it at compile time.
    if argv is None:
        argv = sys.argv

    # Argument parsing
    parser = argparse.ArgumentParser(
        description=__doc__, # printed with -h/--help
        # Don't mess with format of description
        formatter_class=argparse.RawDescriptionHelpFormatter,
        # To have --help print defaults with trade-off it changes
        # formatting, use: ArgumentDefaultsHelpFormatter
        )
    # Only allow one of debug/quiet mode
    verbosity_group = parser.add_mutually_exclusive_group()
    verbosity_group.add_argument("-d", "--debug",
                                 action='store_true', default=False,
                                 help="Turn on debugging")
    verbosity_group.add_argument("-q", "--quiet",
                                 action="store_true", default=False,
                                 help="run quietly")
    parser.add_argument("--version", action="version", version="%(prog)s 1.0")
    parser.add_argument("-p", "--principal", default=None,
                        help="Required Kerberos principle")
    parser.add_argument("command_args", metavar="args", type=str, nargs="*",
                        help="command and arguments to execute")
    args = parser.parse_args()

    global output
    output = print if not args.quiet else lambda s: None
    global debug
    debug = print if args.debug else lambda s: None

    # Environment to use for spawned processes
    env = os.environ

    if args.principal:
        debug("Setting up environment for principal: {}".format(args.principal))
        cache = os.path.join(tempfile.gettempdir(),
                             "krb5cc_{}_{}".format(
                                 os.getlogin(),
                                 args.principal))
        debug("Cache is {}".format(cache))
        env['KRB5CCNAME'] = cache

    # Loop until we have a valid ticket
    while (True):
        status = subprocess.call(["klist", "-t"], env=env)
        debug("klist returned {}".format(status))
        if status == 0:
            output("Valid ticket found.")
            break
        kinit_cmd = ["kinit"]
        if args.principal:
            # Must specify -c, just setting KRB5CCNAME in env not enough
            kinit_cmd.extend(["-c", cache, args.principal])
        try:
            status = subprocess.call(kinit_cmd, env=env)
        except KeyboardInterrupt:
            print("Caught interrupt.")
            return 1
        except OSError as e:
            print("Error executing 'kinit': {}".format(str(e)))
            return(1)
        debug("kinit returned {}".format(status))

    if args.command_args and len(args.command_args) > 0:
        debug("Executing: {}".format(" ".join(args.command_args)))
        try:
            status = subprocess.call(args.command_args, env=env)
        except OSError as e:
            print("Error executing {}: {}".format(args.command_args[0],
                                                  str(e)))
            return(1)
        debug("Command exit status: {}".format(status))
        return(status)

    return(0)

if __name__ == "__main__":
    sys.exit(main())
