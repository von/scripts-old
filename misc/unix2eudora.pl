#!/usr/local/bin/perl
######################################################################
#
#
# unix2eudora
#
# Convert a list of unix mail boxes to a zip file suitable for
# unzipping in a eudora folder.
#
######################################################################

my @files = @ARGV;

######################################################################
#
# Create a temproary working directory
#

my $Temp_Dir = "/tmp/unix2eudora.$$";

if (!mkdir($Temp_Dir))
{
  die "Could not create temporary working directory $Temp_Dir: $!";
}

######################################################################
#
# Parse files
#

# XXX Need to create dscemap file

file: foreach $file (@files) {
  # Skip emacs backup files
  if ($file =~ /~$/)
  {
    next file;
  }

  my $output_file = $Temp_Dir . "/" . $file . ".mbx";

  unix2dos($file, $output_file);
}
