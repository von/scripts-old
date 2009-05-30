#!/usr/bin/env python
"""Basic python program.

Updated version of Guido's to use optparse:
http://www.artima.com/weblogs/viewpost.jsp?thread=4829
"""
import optparse
import sys

def main(argv=None):
    if argv is None:
        argv = sys.argv
    usage = "usage: %prog [options] arg1 arg2"
    version= "%prog 1.0"
    parser = optparse.OptionParser(usage=usage, version=version)
    (options, args) = parser.parse_args()


if __name__ == "__main__":
    sys.exit(main())
