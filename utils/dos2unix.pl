#!/usr/local/bin/perl
######################################################################
#
# dos2unix
#
# Convert a dos ascii file into a unix ascii file
#
# $Id$
#
######################################################################

while(<>) {
 
  # Convert CR-LF to LF
  s/\x0d\x0a/\x0a/g;

  print;
}
