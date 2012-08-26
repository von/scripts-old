#!/usr/bin/env python
"""Stash 'old' files away in a directory."""

from __future__ import print_function  # So we can get at print()

import argparse
import os.path
import glob
import os
import os.path
import re
import sys
import unittest

# Output functions
output = print
debug = print

#
# Match: file-1 or file-1.ext
# group 1 = "file-", group 2 = "1", group 3 = ".ext"
FILENAME_VERSION_RE = re.compile("(.*?-)(\d+)(\.\w+)?$")

######################################################################

def get_version(filename):
    """Given a filename, return its version number.

    Right now it assume a form such as: filename-11.docx

    Return integer of version or None if version cannot be determined."""
    fn_root,fn_ext = os.path.splitext(filename)
    version_match = FILENAME_VERSION_RE.search(fn_root)
    if not version_match:
        return None
    return int(version_match.group(2))

######################################################################

def process_files(files, old_path):
    """Process all the files in list, moving old ones to old_path"""
    files.sort(key=get_version, reverse=True)
    max_version = get_version(files[0])
    old_files = filter(lambda f: get_version(f) < max_version, files)
    for file in old_files:
        output("Archiving {}".format(file))
        os.rename(file, os.path.join(old_path, file))

######################################################################

def group_files(files):
    """Given a list of filenames, group by prefix without version

    Returns a dictionary with prefix as keys."""
    d = {}
    for f in files:
        m = FILENAME_VERSION_RE.search(f)
        if not m:
            # No version number, skip
            continue
        prefix = m.group(1)
        d.setdefault(prefix, []).append(f)
    return d

######################################################################

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
    parser.add_argument("-o", "--old-dir", default="OLD/",
                        help="destination for old files")
    parser.add_argument("--version", action="version", version="%(prog)s 1.0")
    parser.add_argument('files', metavar='files', type=str, nargs='*',
                        help="files to process")
    args = parser.parse_args()

    global output
    output = print if not args.quiet else lambda s: None
    global debug
    debug = print if args.debug else lambda s: None

    files = glob.glob("*") if not len(args.files) else args.files

    output("Archiving files to {}".format(args.old_dir))
    if not os.path.exists(args.old_dir):
        output("Creating {}".format(args.old_dir))
        os.mkdir(args.old_dir)

    grouped_files = group_files(files)

    for group in grouped_files.keys():
        process_files(grouped_files[group], args.old_dir)

    return(0)

if __name__ == "__main__":
    sys.exit(main())

######################################################################
#
# Tests for this script.
#
# Run with 'nosetests stash-old.py'

class MyTests(unittest.TestCase):
    """Tests for this script."""

    def get_version_test(self):
        """Test for get_version()"""
        self.assertEqual(get_version("filename-7.ext"), 7)
        self.assertIsNone(get_version("filename.ext"))
        self.assertEqual(get_version("filename-4"), 4)

    def FILENAME_VERSION_RE_test(self):
        """Test the FILENAME_VERSION_RE regex"""
        m = FILENAME_VERSION_RE.search("file-1.txt")
        self.assertIsNotNone(m)
        self.assertEqual(m.group(1), "file-")
        self.assertEqual(m.group(2), "1")
        self.assertEqual(m.group(3), ".txt")

    def group_files_test(self):
        """Test for group_files()"""
        files = [ "file-1.txt", "file-3", "test-9", "something",
                  "test-1", "test", "test-3.ext" ]
        d = group_files(files)
        self.assertTrue(d.has_key("file-"))
        self.assertEqual(len(d["file-"]), 2, ":".join(d["file-"]))
        self.assertFalse(d.has_key("something"))
        self.assertTrue(d.has_key("test-"))
        self.assertEqual(len(d["test-"]), 3, ":".join(d["test-"]))
