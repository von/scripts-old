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


def rtf2pdf(rtf_filename, pdf_filename):
    """Convert given rtf file to a pdf file with given name

    Uses cupsfilter - kudos http://stackoverflow.com/a/22119831/197789"""
    # Prior to Mavericks, I used the following directly
    # /System/Library/Printers/Libraries/convert
    p = subprocess.Popen(["cupsfilter", rtf_filename],
                         stdout=subprocess.PIPE)
    with open(pdf_filename, "w") as pdf_file:
        while True:
            data = p.stdout.read()
            if len(data) == 0:
                break
            pdf_file.write(data)


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

        rtf2pdf(tmp_rtf_filename, dest_filename)
        os.unlink(tmp_rtf_filename)

        print "{}: Converted to {}".format(src, dest_filename)

    return(0 if not error else 1)

if __name__ == "__main__":
    sys.exit(main())
