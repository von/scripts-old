#!/usr/bin/env python
"""Copy an iTunes playlist to a target directory (presumably a USB drive)

First argument must be an exported iTunes playlist.

Second argument must be the target directory.
"""
import argparse
import collections
import os.path
import shutil
import string
import sys

# Fields in the exported playlist
PLAYLIST_FIELDS = [
    "title", "artist", "unknown1", "album", "unknown2",
    "genre", "unknown3", "unkown4", "unknown5", "unknown6",
    "unknown7", "unknown8", "unknown9", "date1", "date2",
    "unknown10", "unknown11", "unknown12", "type", "unknown13",
    "track", "unknown14", "date3", "unknown15", "unknown16",
    "unknown17", "colon_path"
    ]

# Class for representing song from playlist
SongLine = collections.namedtuple( "SongLine", PLAYLIST_FIELDS)

def message_normal(m):
    """Handle message in normal mode by printing it"""
    print m

def message_quiet(m):
    """Handle message in quiet mode by dropping it on the floor"""
    pass

def main(argv=None):
    # Do argv default this way, as doing it in the functional
    # declaration sets it at compile time.
    if argv is None:
        argv = sys.argv
    parser = argparse.ArgumentParser(
        description=__doc__, # printed with -h/--help
        # Don't mess woth formation of description
        formatter_class=argparse.RawDescriptionHelpFormatter,
        )
    parser.add_argument("-d", "--delete", action="store_true",
                        help="delete files not in playlist", default=False)
    parser.add_argument("-q", "--quiet", action="store_true", dest="quiet",
                        help="run quietly", default=False)
    parser.add_argument("--version", action="version", version="%(prog)s 1.0")
    parser.add_argument('playlist', metavar='playlist',
                        type=argparse.FileType("U"),
                        help='playlist to copy')
    parser.add_argument('target', metavar='path', type=str,
                        help='target path')
    args = parser.parse_args()
    message = message_normal if not args.quiet else message_quiet
    if not os.path.exists(args.target):
        parser.error("Target ({}) does not exist".format(args.target))
    if not os.path.isdir(args.target):
        parser.error("Target ({}) is not a directory".format(args.target))
    message("Copying playlist to {}".format(args.target))
    copied_files = []
    # First line is comment with field names, read and discard
    args.playlist.readline() 
    for line in args.playlist:
        # Remove NULL characters from line
        line = line.translate(string.maketrans("", ""), "\x00")
        fields = line.strip().split("\t")
        # Ignore blank lines
        if len(fields) != len(PLAYLIST_FIELDS):
            continue
        song = SongLine._make(fields)
        path_components = song.colon_path.split(":")
        # First component is username, prepend "~" and expand to homedir
        path_components[0] = os.path.expanduser("~" + path_components[0])
        source_path = os.path.join(*path_components)
        basename = os.path.basename(source_path)
        copied_files.append(basename)
        target_path = os.path.join(args.target, basename)
        if os.path.exists(target_path):
            message("Skipping {}".format(source_path))
            continue
        message("Copying {}".format(source_path))
        if not os.path.exists(source_path):
            message("Skipping {}: file does not exist".format(source_path))
            continue
        shutil.copy(source_path, args.target)
    if args.delete:
        message("Deleting files not in playlist...")
        for file in os.listdir(args.target):
            if file not in copied_files:
                message("Deleting {}".format(file))
                try:
                    os.remove(os.path.join(args.target, file))
                except Exception, e:
                    message("Failed to delete {}: {}".format(file, e))
    return(0)

if __name__ == "__main__":
    sys.exit(main())
