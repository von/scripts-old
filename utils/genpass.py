#!/usr/bin/env python
"""Generate passwords or pass phrases"""
from __future__ import print_function  # So we can get at print()

import argparse
import random
import string
import sys

import envoy  # pip install envoy

# Output functions
output = print
debug = print


def null_output(*args, **kwargs):
    pass

######################################################################
#
# Functions to generate different types of passwords/passs phrases
#


def pass_word(args):
    """Generate a password."""
    min = args.min if args.min else 12
    max = args.max if args.max else 24
    if args.charset:
        alphabet = alphabets[args.charset]
    else:
        alphabet = string.letters + string.digits
    if not args.lookalikes:
        alphabet = alphabet.translate(
            string.maketrans('', ''),  # For pre-2.6 compatability
            '0O1l')  # Characters to delete
    length = random.randint(min, max)
    debug("Length is {}".format(length))
    s = "".join([random.choice(alphabet) for i in xrange(length)])
    return s


def pass_phrase(args):
    """Generate a pass phrase."""
    debug("Reading dictionary {}".format(args.dict))
    with open(args.dict) as f:
        words = f.readlines()
    min = args.min if args.min else 4
    max = args.max if args.max else 6
    length = random.randint(min, max)
    debug("Length is {}".format(length))
    s = " ".join([random.choice(words).strip() for i in xrange(length)])
    return s


def pass_pin(args):
    """Generate a pin."""
    min = args.min if args.min else 4
    max = args.max if args.max else 4
    alphabet = string.digits
    length = random.randint(min, max)
    debug("Length is {}".format(length))
    s = "".join([random.choice(alphabet) for i in xrange(length)])
    return s

######################################################################
#
# Password output functions
#


def output_stdout(s, args):
    """Output to stdout"""
    print(s)
    return(0)


def output_clipboard(s, args):
    """Output to paste buffer"""
    output("Putting passphrase/word into paste buffer...")
    if sys.platform == "darwin":
        prog = "pbcopy"
    else:
        prog = "xclip -in -verbose -selection clipboard"
    debug("Invoking {}".format(prog))
    result = envoy.run(prog, data=s, timeout=1)
    if result.status_code > 0:
        output("Error: " + result.std_err)
        return(1)
    return(0)

######################################################################

# Alphabets used by pass_word
alphabets = {
    "alphanum": string.letters + string.digits,
    "alphanumpunct": string.letters + string.digits + string.punctuation,
    }

algorithms = {
    "word": pass_word,
    "phrase": pass_phrase,
    "pin": pass_pin,
    }

######################################################################


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

    # Generate password by default
    parser.set_defaults(
        function=pass_word,
        out_function=output_clipboard)

    # Only allow one of debug/quiet mode
    verbosity_group = parser.add_mutually_exclusive_group()
    verbosity_group.add_argument(
        "-d", "--debug",
        action='store_true', default=False,
        help="Turn on debugging")
    verbosity_group.add_argument(
        "-q", "--quiet",
        action="store_true", default=False,
        help="run quietly")

    parser.add_argument("--version", action="version", version="%(prog)s 1.0")
    parser.add_argument(
        "-a", "--algorithm",
        default="word",
        help="Specify algorithm to use",
        choices=algorithms.keys())
    parser.add_argument(
        "-c", "--charset",
        default="alphanum",
        help="Specify character set for passwords",
        choices=alphabets.keys())
    parser.add_argument(
        "-D", "--dict",
        default="/usr/share/dict/words",
        help="Specify dictionary file to use for pass phrases",
        metavar="PATH")
    parser.add_argument(
        "-l", "--lookalikes",
        action="store_true", default=False,
        help="Allow look-alike characters (0, O, 1, l, etc.)")
    parser.add_argument(
        "-m", "--min",
        type=int, default=0,
        help="Specify minimum length/words", metavar="NUM")
    parser.add_argument(
        "-M", "--max",
        type=int, default=0,
        help="Specify maximum length/words", metavar="NUM")
    parser.add_argument(
        "-S", "--stdout",
        action='store_const', const=output_stdout,
        dest='out_function',
        help="Write password to STDOUT")

    args = parser.parse_args()

    global output
    output = print if not args.quiet else null_output
    global debug
    debug = print if args.debug else null_output

    debug("Calling random.seed()")
    random.seed()

    try:
        pass_function = algorithms[args.algorithm]
        debug("Invoking {}".format(str(args.function)))
        pass_str = pass_function(args)
        debug("Returned from {}".format(str(args.function)))
    except Exception as e:
        print("Failed:" + str(e))
        return(1)

    try:
        debug("Invoking {}".format(str(args.out_function)))
        args.out_function(pass_str, args)
        debug("Returned from {}".format(str(args.out_function)))
    except Exception as e:
        print("Failed:" + str(e))
        return(1)

    return(0)

if __name__ == "__main__":
    sys.exit(main())
