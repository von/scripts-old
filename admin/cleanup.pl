#!/usr/local/bin/perl
######################################################################
#
# cleanup
#
# Clean up a directory tree, removing all the old files.
#
# $Id$
#
######################################################################
#
# Constants
#

$DO_NOT_DELETE_FILE = "DO_NOT_DELETE";

# Age to delete at (in days)
$ACCESS_AGE = 7;

$VERBOSE_LEVEL = 3;

$DO_DELETE = 1;

######################################################################
#
# Process arguments
# 

use Getopt::Std;

getopts("nv:");

$VERBOSE_LEVEL = $opt_v
    if $opt_v;

$DO_DELETE = 0
    if $opt_n;

$STARTING_DIR = shift;

$STARTING_DIR = "."
    if (!defined($STARTING_DIR));

######################################################################

DO_DIR($STARTING_DIR);

exit(0);

######################################################################
#
# DO_DIR
#
# Clean out a directory, recursing to any underneath
#

sub DO_DIR {

    my $DIR = shift;

    die "\$DIR not defined"
	if !defined($DIR);

    LOG(4, "Checking directory $DIR\n");

    if (!chdir $DIR) {
	LOG(1, "Couldn't CD to $DIR: $!\n");
	return 1;
    }

    if ( defined($DO_NOT_DELETE_FILE) && -e $DO_NOT_DELETE_FILE ) {
	LOG(3, "Skipping directory $DIR\n");
	return 1;
    }

    my @FILES = directory();

    my $NUM_FILES = $#FILES + 1;

    if ($NUM_FILES == 0) {
	return 0;
    }

    my $FILE;

    #
    # Check all the non-directories
    #
    foreach $FILE ( @FILES ) {
	
	my $FILENAME = $DIR . "/" . $FILE;

	# Skip directories until later
	if (-d $FILE) {
	    next;
	}

	# Skip unix pipes
	if (-p $FILE) {
	    LOG(6, "Skipping $FILENAME - is a pipe\n");
	    next;
	}

	LOG(6, "Checking file $FILENAME\n");


	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
            $atime,$mtime,$ctime,$blksize,$blocks) = stat($FILE);

	my $LAST_ACCESS = SECS_TO_DAYS(time() - $atime);

	LOG(8,
	    sprintf("Last access: %6d days\n",
 		    $LAST_ACCESS)
	    );

	my $REMOVE = 0;

	if ($LAST_ACCESS > $ACCESS_AGE) {
	    LOG(3, "$FILENAME access age ($LAST_ACCESS days) is over limit\n");
	    $REMOVE++;
	}

	if ($REMOVE && $DO_DELETE) {
	    LOG(2, "Removing $FILENAME\n");
	    if (!unlink $FILE) {
		LOG(1, "Could not delete $FILENAME: $!\n");
	    } else {
		$NUM_FILES--;
	    }
	}
    }

    #
    # Check all the directories
    #
    foreach $FILE ( @FILES ) {
	if (! -d $FILE) {
	    next;
	}

	my $FILENAME = $DIR . "/" . $FILE;

	my $REMOVE = 0;

	if (DO_DIR($FILENAME) == 0) {
	    # Directory is empty
	    LOG(2, "Directory $FILENAME is empty.\n");
	    $REMOVE++;
	}

	if (!chdir($DIR)) {
	    LOG(1, "Couldn't CD up to $DIR: $!\n");
	    LOG(1, "Aborting\n");
	    exit(1);
	}

	if ($REMOVE && $DO_DELETE) {
	    LOG(2, "Removing directory $FILENAME\n");
	    if (!rmdir $FILE) {
		LOG(1, "Could not rmdir $FILENAME: $!\n");
	    } else {
		$NUM_FILES--;
	    }
	}
    }

    return $NUM_FILES;
}
	
	
######################################################################
#
# LOG
#
# Log something depending on VERBOSE_LEVEl
#

sub LOG {
    my $LEVEL = shift;

    if ($LEVEL <= $VERBOSE_LEVEL) {
	print @_;
    }
}



######################################################################
#
# directory
#
# Return a list of all files in the current directory, excluding
# "." and ".."
#

sub directory {
    my $DH;
    
    my $FILE;
    my @FILES = ();

    opendir(DH, ".") ||
	die "Couldn't open . for reading: $!\n";

    while(defined($FILE = readdir(DH)) && $FILE) {
	next
	    if (($FILE eq ".") || ($FILE eq ".."));

	push(@FILES, $FILE);
    }

    closedir(DH);

    return @FILES;
}

######################################################################
#
# SECS_TO_DAYS
#
# Convert seconds to days.
#

sub SECS_TO_DAYS {
    my $SECS = shift;

    return int($SECS / (60 * 60 * 24));
}
