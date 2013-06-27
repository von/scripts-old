#!/usr/bin/env python
"""Join multiple PDF files together into a single PDF

This is a wrapper around Apple's join.py script"""

import argparse
import subprocess
import sys

# Must be called with system Python
PYTHON="/usr/bin/python"

# Apple's script
PDF_JOIN = "/System/Library/Automator/Combine PDF Pages.action/Contents/Resources/join.py"

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
    parser.add_argument("-i", "--input", type=file,
                        metavar="PATH",
                        help="File specifying files to join")
    parser.add_argument("-o", "--output", type=str, required=True,
                        metavar="PATH", help="Output file path")
    parser.add_argument('pdfs', metavar='paths', type=str, nargs='?',
                        help="paths to PDFs to join")
    args = parser.parse_args()

    pdfs = args.pdfs if args.pdfs else []
    if args.input:
        pdfs.extend([f.strip() for f in args.input.readlines()])

    if len(pdfs) == 0:
        parser.error("Must supply PDF filename to join")

    retcode = subprocess.call(
        [PYTHON, PDF_JOIN, "-o", args.output] + pdfs,
        # Clear environment as PYTHONPATH will confuse join.py
        env={})

    return(retcode)

if __name__ == "__main__":
    sys.exit(main())
