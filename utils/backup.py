#!/usr/bin/env python
"""Do a backup using rsync

%prog [<some options>] <some arguments>

Example ~/.backup.conf:

[Options]
ExcludesFile=~/.backup.excludes

[Target]
# One or more possible target volumes. Will be check in order.
# Names do not matter.
path1=/Volumes/Backup

[Sources]
# One or more possible source volumes. Names do not matter.
path1=/Users/username
path2=/Users/username2
"""
import ConfigParser
from optparse import OptionParser
import os
import os.path
import shutil
import subprocess
import sys

def message_normal(msg):
    """Display a message."""
    print msg

def message_quiet(msg):
    """Ignore a message for quiet mode."""
    pass

def error_message(msg):
    """Display an error message."""
    # Todo: should go to STDERR
    print msg

def main(argv=None):
    if argv is None:
        argv = sys.argv
    parser = OptionParser(
        usage=__doc__, # printed with -h/--help
        version="%prog 1.0" # automatically generates --version
        )
    parser.add_option("-c", "--config", dest="config",
                      default="~/.backup.conf",
                      help="use configuration from FILE", metavar="FILE")
    parser.add_option("-q", "--quiet", action="store_true", dest="quiet",
                      help="run quietly", default=False)
    (options, args) = parser.parse_args()
    if options.quiet:
        message = message_quiet
    else:
        message = message_normal
    message("Reading configuration...")
    config = ConfigParser.ConfigParser()
    config.read(os.path.expanduser(options.config))

    # Do we have an excludes file?
    excludes_file = None
    try:
        excludes_file = \
            os.path.expanduser(config.get("Options", "ExcludesFile"))
        if os.path.exists(excludes_file):
            message("Using excludes file %s" % excludes_file)
        else:
            error_message("Excludes file \"%s\" does not exist.")
            return 1
    except:
        pass

    # Find target backup volume. Look in [Target] section. We ignore
    # names and just look at values.
    for name, target_volume in config.items("Target"):
        if os.path.exists(target_volume):
            break
    else:
        error_message("Could not find target volume for backup.")
        return 1
    message("Target path is %s" % target_volume)

    # Get list of directories to be backed up.
    source_paths = [items[1] for items in config.items("Sources")]
    if len(source_paths) == 0:
        message("No source paths defined.")
        return 0

    log_file = os.path.join(target_volume, "backup.log")
    if os.path.exists(log_file):
        shutil.move(log_file, log_file + ".bak")
                    
    # Do it
    count = 0
    for source_path in source_paths:
        source_path = os.path.expanduser(source_path)
        if not os.path.exists(source_path):
            message("Source path \"%s\" does not exist." % source_path)
            continue
        count += 1
        target_path = os.path.join(target_volume,
                                   os.path.dirname(source_path).lstrip(os.sep))
        if not os.path.exists(target_path):
            os.makedirs(target_path)
        message("Backing up %s to %s" % (source_path, target_path))
        arguments = ["rsync"]
        # -a: archive mode
        # -u: Update, don't copy older files
        # -c: Use checksums instead of modification time and size -
        # this seems to work better.
        arguments.append("-auc")
        if not options.quiet:
            arguments.append("-v")  # Verbose mode
        arguments.append("--delete")
        arguments.append("--delete-excluded")
        if excludes_file is not None:
            arguments.append("--exclude-from")
            arguments.append(excludes_file)
        arguments.append("--log-file=%s" % log_file)
        arguments.append(source_path)
        arguments.append(target_path)
        return_code = subprocess.check_call(arguments)
        if return_code != 0:
            error_message("Error backing up %s" % source_path)

    message("Success. %d directories backed up." % count)
    return 0

if __name__ == "__main__":
    sys.exit(main())
