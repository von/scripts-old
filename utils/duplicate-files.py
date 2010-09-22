#!/usr/bin/env python
"""Detect duplicate files

%prog [<path>]

Path is current directory if not given.
"""
import hashlib
from optparse import OptionParser
import os.path
import sys

def get_file_hash(filename):
    """Return the hash of a filename as a string."""
    BLOCK_SIZE = 1024  # Arbitrary
    hash = hashlib.sha1()
    with open(filename) as f:
        while True:
                data = f.read(BLOCK_SIZE)
                if not data:
                    break
                hash.update(data)
    return hash.hexdigest()

def progress():
    """Show progress"""
    sys.stdout.write(".")
    sys.stdout.flush()

def progress_complete():
    """Complete output of progress"""
    sys.stdout.write("\n")
    sys.stdout.flush()

def main(argv=None):
    if argv is None:
        argv = sys.argv
    parser = OptionParser(
        usage=__doc__, # printed with -h/--help
        version="%prog 1.0" # automatically generates --version
        )
    (options, args) = parser.parse_args()
    if len(args) > 0:
        path = args.pop()
        if not os.path.exists(path):
            parser.error("Path \"%s\" does not exist" % path)
    else:
        path = "."

    file_hashes = {}
    for directory_name, subdirectory_names, filenames in os.walk(path):
        for filename in [os.path.join(directory_name, filename)\
                             for filename in filenames]:
            file_hash = get_file_hash(filename)
            if file_hash in file_hashes:
                file_hashes[file_hash].append(filename)
            else:
                file_hashes[file_hash] = [filename]
            print ".",
            sys.stdout.flush()
    print

    for file_hash, filenames in file_hashes.items():
        if len(filenames) > 1:
            print "Duplicates:"
            for filename in filenames:
                print "\t" + filename
    return 0

if __name__ == "__main__":
    sys.exit(main())
