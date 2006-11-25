#!/usr/bin/env perl
######################################################################
#
# cvs-move
#
# Change the cvs root and repository of a checked out repository.
#
# $Id$
#
######################################################################

require 5.001;

$New_Root = shift;

$New_Repository = shift;

if (!defined($New_Root)) {
    print STDERR "Need to supply name of new CVS root.\n";
    exit 1;
}

$Repository_Root = ".";

do_directory($Repository_Root);

exit 0;


######################################################################

sub do_directory {
    my $dir = shift;

    print "Working in $dir\n";

    my $cvs_dir = $dir . "/CVS";

    my $root_file = $cvs_dir . "/Root";
    my $repository_file = $cvs_dir . "/Repository";

    if ( -e $root_file && -e $repository_file ) {
	system("echo $New_Root > $root_file");

	if (defined($New_Repository)) {
	  # The new repository name is the name of the new repository
	  # root, plus the path of this subdirectory from the base of
	  # the checkout.

	  # Get path to this subdirectory from base of checkout
	  my $suffix = $dir;
	  $suffix =~ s/$Repository_Root//;

	  # And append to root to get Repository name
	  my $repository = $New_Repository . $suffix;

	  system("echo $repository > $repository_file");
	}
    }

    my @subdirs = ();

    if (!opendir(DH, $dir)) {
	print STDERR "Could not open directory $dir for reading: $!\n";
	return 1;
    }

    while (defined($subdir = readdir(DH))) {
	if (($subdir eq ".") ||
	    ($subdir eq "..") ||
	    ($subdir eq "CVS")) {
	    next;
	}

	$subdir = $dir . "/" . $subdir;

	if ( ! -d $subdir) {
	    next;
	}

	push(@subdirs, $subdir);
    }

    closedir(DH);

    foreach $subdir (@subdirs) {
	do_directory($subdir);
    }

    return 0;
}
