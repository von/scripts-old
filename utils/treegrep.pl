#!/usr/local/bin/perl
######################################################################
#
# treegrep
#
# Run grep recursively on a whole directory tree.
#
# $Id$
#
######################################################################
#
# Defaults
#

$FILES_REGEX="*";

$FUNCTION = 0;

$REGEX_OPTS = "";

######################################################################
#
# Parse command line arguments
#

use Getopt::Std;

getopts("f:Fi");

$FILES_REGEX = $opt_f
    if $opt_f;

$FUNCTION = 1
    if $opt_F;

$REGEX_OPTS .= "i"
    if $opt_i;
  
$FILES_REGEX = &PARSE_REGEX($FILES_REGEX);

$REGEX = &PARSE_REGEX(shift);

if (!$REGEX) {
    print STDERR "Usage: $0 <regex>\n";
    exit 1;
}

if ($FUNCTION) {
    # Try to function the function described by regex
    # Basically look for <regex>\s*(.*)\s*{?\s*$
    #
    # XXX This doesn't work too well because of
    # multiline declarations...
    #
    $REGEX = "^\\s*" . $REGEX . "\\s*\\([^\)]*\\)\\s*\\{?\\s*\$";
}

&DO_DIR(".");

exit 0;



######################################################################
#
# DO_DIR
#

sub DO_DIR {
    my $DIR = shift;

    #print "Doing directory $DIR\n";

    my $FILE;

    my @FILES = &DIRECTORY($DIR);

    # DO all files
    foreach $FILE (@FILES) {
	&DO_FILE($DIR . "/" . $FILE)
	    if PASSES_FILTER($DIR, $FILE);
    }

    # Do all subdirs
    foreach $FILE (@FILES) {
	next
	    if (($FILE eq ".") | ($FILE eq ".."));

	my $NEW_DIR = $DIR . "/" . $FILE;

	&DO_DIR($NEW_DIR)
	    if ( -d $NEW_DIR);
    }
}

######################################################################
#
# DO_FILE
#

sub DO_FILE {
    my $FILENAME = shift;

    if (!open(FILE, $FILENAME)) {
	print STDERR "Couldn't open file $FILENAME: $!\n";
	return;
    }

    my $REGEX_CODE = "/$REGEX/$REGEX_OPTS";

    while(<FILE>) {
	if (eval $REGEX_CODE) {
	    print "$FILENAME:$_";
	}
    }

    close(FILE);
}
	    

	       

######################################################################
#
# DIRECTORY
#
# Read all filenames in a directory and return an array containing
# them. Ignores "." and "..".
#
# Arguments: None
# Returns: Array
#

sub DIRECTORY {
    my $DIRECTORY = shift;

    $DIRECTORY = "."
	if !$DIRECTORY;

    local($DH);

    local($FILE);
    local(@FILES) = ();


    opendir(DH, $DIRECTORY) ||
	die "Couldn't open . for reading: $!\n";

    while($FILE = readdir(DH)) {
	next
	    if (($FILE eq ".") || ($FILE eq ".."));

	push(@FILES, $FILE);
    }

    closedir(DH);

    return @FILES;
}

######################################################################
#
# PARSE_REGEX
#
# Convert a unix file-expansion style regex into perl
#
# Arguments: Unix-style regex
# Returns: Perl-style regex
#

sub PARSE_REGEX {
    my $REGEX = shift;

    # Convert '.' to '\.'
    $REGEX =~ s/\./\\\./;

    # Convert '?' to '.'
    $REGEX =~ s/\?/\./;

    # Convert '*' to '.*'
    $REGEX =~ s/\*/\.\*/;

    return $REGEX;
}
    
######################################################################
#
# PASSES_FILTER
#
# Check to see if a file passes the filter.
#
# Arguments: Directory, Filename
# Returns: 1 if passes, 0 if not
#

sub PASSES_FILTER {
    my $DIRNAME = shift;
    my $FILENAME = shift;
    my $FULLNAME = $DIRNAME . "/" . $FILENAME;

    # Must pass regex filter
    return 0
      if ($FILENAME !~ /$FILES_REGEX/);

    # No directories
    return 0
      if (-d $FULLNAME);

    # No binary files
    return 0
      if (-B $FULLNAME);

    return 1;
}
