#!/usr/bin/env python
"""Convert a MS-Office file into a PDF

Uses 'textutil' to convert to RTF then 'convert' to convert RTF to PDF"""

import argparse
import os
import os.path
import subprocess
import sys
import tempfile

TEXTUTIL = "textutil"

CONVERT = "/System/Library/Printers/Libraries/convert"


def main(argv=None):
    # Do argv default this way, as doing it in the functional
    # declaration sets it at compile time.
    if argv is None:
        argv = sys.argv

    # Argument parsing
    parser = argparse.ArgumentParser(
        description=__doc__,  # printed with -h/--help
        # Don't mess with format of description
        formatter_class=argparse.RawDescriptionHelpFormatter,
        # To have --help print defaults with trade-off it changes
        # formatting, use: ArgumentDefaultsHelpFormatter
    )

    parser.add_argument('srcs', metavar='PATH', type=str, nargs="+",
                        help="Path to source file")

    args = parser.parse_args()

    error = False

    for src in args.srcs:
        if not os.path.exists(src):
            print "{}: does not exist".format(src)
            error = True
            continue
        filename_base = os.path.splitext(src)[0]
        dest_filename = filename_base + ".pdf"
        if os.path.exists(dest_filename):
            print "{}: {} already exists, skipping".format(src, dest_filename)
            continue
        tmp_rtf_filename = tempfile.mkstemp(suffix=".rtf")[1]

        retcode = subprocess.call([TEXTUTIL,
                                   "-convert", "rtf",
                                   "-output", tmp_rtf_filename,
                                   src])
        if retcode != 0:
            print "{}: Failed to convert " \
                "(to intermediate RTF format)".format(src)
            error = True
            continue

        try:
            subprocess.check_call([CONVERT,
                                   "-f", tmp_rtf_filename,
                                   "-o", dest_filename])
        except OSError as ex:
            print "Could not execute {}: {}".format(CONVERT,
                                                    str(ex))
            error = True
            break

        os.unlink(tmp_rtf_filename)
        if retcode != 0:
            print "{}: Failed to convert".format(src)
            error = True
            continue

        print "{}: Converted to {}".format(src, dest_filename)

    return(0 if not error else 1)

if __name__ == "__main__":
    sys.exit(main())
