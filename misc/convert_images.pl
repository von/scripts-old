#!/usr/local/bin/perl
######################################################################
#
# convert_images.pl
#
# Convert a bunch of images to the same size and standardize filenames.
#
# $Id$
#
######################################################################

foreach $file (@ARGV) {
  if (! -f $file) {
    warn ("No such file: $file");
    next;
  }

  print "Converting $file...\n";

  $new_file = lc($file);

  system("convert -size 640x400 $file $new_file");
}
