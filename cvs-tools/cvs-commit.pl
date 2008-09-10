#!/usr/bin/env perl
######################################################################
#
# cvs-commit
#
# Wrapper around 'cvs commit' to do a diff first and let me edit
# the log message while looking at the diff.
#
# TODO:
#  -Be cool to tie this in with ChangeLog
#
# $Id$
#
######################################################################

require 5.001;

######################################################################

%Configuration = (
		  cvs             => "cvs",
		  cvs_diff_args   => "",
		  cvs_commit_args => "",
		 );

$Configuration{editor} = $ENV{"CVSEDITOR"} || $ENV{"EDITOR"} || "vi";

$EDITOR_ARGS = "";

$CVS_ARGS = "";

$CVS_DIFF_ARGS = "";

$CVS_COMMIT_ARGS = "";

######################################################################

$tmp_file = "/tmp/.cvscommit.$$";

######################################################################
#
# Process command line
#

use Getopt::Std;

my %opts;

getopts('cl', \%opts);

# -c means do context diff
$opts{c} && ($Configuration{cvs_diff_args} .= " -c");

# -l means run in local dir only
if ($opts{l}) {
    $Configuration{cvs_diff_args} .= " -l";
    $Configuration{cvs_commit_args} .= " -l";
}

# The rest of the arguments are files to commit    
$files = join(' ', @ARGV);

######################################################################
#
# Main program
#

my $cmd = $Configuration{cvs};
$cmd .= " diff";
$cmd .= " " . $Configuration{cvs_diff_args};
$cmd .= " " . $files;
 
# Run the diff and create the temporary file
open(CVS_DIFF, "$cmd |") ||
  die "Could not run '$cmd': $!";

open(TMP_FILE, ">$tmp_file") ||
  die "Could not open $tmp_file for writing: $!";

while(<CVS_DIFF>) {
  # Ignore unknown files
  /^\? / && next;

  print TMP_FILE "CVS: " . $_;
}

close(CVS_DIFF);
close(TMP_FILE);

# Now allow the user to edit the temporary file
$cmd = $Configuration{editor};
$cmd .= " " . $tmp_file;

system("$cmd");

# Now remove comments from temporary file
open(OLD_TMP_FILE, "<$tmp_file") ||
  die "Could not open $tmp_file for reading: $!";

# now unlink it so that we can recreate it
unlink($tmp_file);

# Now recreate it
open(NEW_TMP_FILE, ">$tmp_file") ||
  die "Could not open $tmp_file for writing: $!";

while(<OLD_TMP_FILE>) {
    if (/^CVS:/) {
	next;
    }

    print NEW_TMP_FILE;
}

close(OLD_TMP_FILE);
close(NEW_TMP_FILE);

# Now do the commit
$cmd = $Configuration{cvs};
$cmd .= " commit";
$cmd .= " -F";
$cmd .= " $tmp_file";
$cmd .= " " . $Configuration{cvs_commit_args};
$cmd .= " " . $files;

system($cmd);

# Clean up
unlink($tmp_file);

exit(0);


