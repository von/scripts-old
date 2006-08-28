#!/usr/bin/env perl
######################################################################
#
# cvs-files
#
# Show the state of file relative to CVS.
#
# $Id$
#
######################################################################
#
# Options
#

# Recurse directory tree?
$Recurse = 0;

# CVS binary
$CVS = "cvs";

# What are we displaying. Is a bitwise or of Flags below
$Showing = 0x00;

# Number of columns of output
$Columns = 78;

# Files to be ignored
$Ignored_Files_Regex = "(\.o|~)\$";

######################################################################
#
# Constants
#

# Flags to indicate what we are showing
%Flags = (
	  current          => 0x01,
	  older            => 0x02,
	  newer            => 0x04,
	  unknown          => 0x08,
	  all              => 0xff,
	 );


$DefaultShowing = $Flags{older} | $Flags{newer};

######################################################################
#
# Lists of files we're found
#

# Current with CVS
@Current = ();

# Newer than cvs
@Newer = ();

# Older than cvs
@Older = ();

# Files not in CVS
@Unknown = ();

######################################################################
#
# Parse commandline options
#

use Getopt::Std;

my %opt;

getopts('anoru', \%opt);

my $directory = shift || ".";

$opt{a} && ($Showing |= $Flags{all});

$opt{n} && ($Showing |= $Flags{newer});

$opt{o} && ($Showing |= $Flags{older});

$opt{r} && ($Recurse = 1);

$opt{u} && ($Showing |= $Flags{unknown});

# If not request, show default
($Showing == 0) && ($Showing = $DefaultShowing);

######################################################################

do_dir($directory);

my $indentation = " " x 4;

if ($Showing & $Flags{newer}) {
  print "Needs commiting:\n";
  print_list($indentation, @Newer);
}

if ($Showing & $Flags{older}) {
  print "Needs updating:\n";
  print_list($indentation, @Older);
}

if ($Showing & $Flags{unknown}) {
  print "Unknown files:\n";
  print_list($indentation, @Unknown);
}

if ($Showing & $Flags{current}) {
  print "Up-to-date:\n";
  print_list($indentation, @Current);
}

exit(0);


######################################################################
#
# Do a directory, can be call recursively
#
# Arguments: Directory path
# Returns: Nothing

sub do_dir {
  my $path = shift;

  # Determine CVSROOT
  my $cvsroot_file = $path . "/CVS/Root";

  if ( ! -r $cvsroot_file) {
    # Apparently now a cvs directory
    return;
  }

  my $cvsroot = `cat $cvsroot_file`;

  chomp($cvsroot);

  # Subdirectories to be processed
  my @subdirs = ();

  # Files to check
  my @files = ();

  if (!opendir(DH, $path)) {
    warn "Could not open directory $path for reading: $!";
    return;
  }

  my $file;

 file: while(defined($file = readdir(DH))) {
    ($file eq ".") && next file;
    ($file eq "..") && next file;

    my $full_path = $path . "/" . $file;

    if (-d $full_path) {
      push(@subdirs, $full_path);
      next file;
    }

    if ($file =~ /$Ignored_Files_Regex/) {
      next;
    }

    push(@files, $full_path);
  }

  my $command = "$CVS -d $cvsroot status " . join(' ', @files);

  open(CVS, "$command 2>&1 |") ||
      die "Could not execute $CVS: $!";


  cvsline: while(<CVS>) {
    my $status = undef;

    if (/File: ([^\s]+)\s+Status:\s+(.+)$/) {
      my $file = $1;
      my $status = $2;

      my $full_path = $path . "/" . $file;

      if ($status eq "Up-to-date") {
	push(@Current, $full_path);

      } elsif (($status eq "Locally Modified") ||
	       ($status eq "Locally Added")) {
	push(@Newer, $full_path);

      } elsif ($status eq "Unknown") {
	push (@Unknown, $full_path);

      } elsif ($status eq "Needs Patch") {
	push(@Older, $full_path);

      } elsif ($status eq "Needs Merge") {
	# XXX Treat as both older and newer for now
	push(@Newer, $full_path);
	push(@Older, $full_path);

      } else {
	print STDERR "Unrecognized status \"$status\" for $full_path\n";
      }
    }
  }

  close(CVS);

  if ($Recurse) {
    foreach my $dir (@subdirs) {
      do_dir($dir);
    }
  }

  return;
}


######################################################################
#
# print_list
#
# Print a list of files with given indentation staying under
# the column width specified by $Columns.
#
# Arguments: Indentation, List of files
# Returns: Nothing

sub print_list {
  my $indentation = shift || "";

  my $column = 0;

  # State needed for handling really long filenames that exceed our
  # max width
  my $need_new_line = 0;
  my $new_line = 1;

  print $indentation;
  $column += length($indentation);

  while (my $file = shift) {
    # Do we need a new line for this filename?
    if (!$new_line && (length($file) + $column > $Columns)) {
      $need_new_line = 1;
    }

    if ($need_new_line == 1) {
      print "\n$indentation";
      $column = length($indentation);
      $need_new_line = 0;
      $new_line = 1;
    }

    if (!$new_line) {
      print " ";
      $column++;
    }

    print $file;
    $column += length($file);
    $new_line = 0;
  }

  print "\n";
}

__END__

######################################################################
#
# POD documentation
#

=head1 NAME

cvs-files

=head1 SYNOPSIS

cvs-file <options> [<directory>]

cvs-files reports on files and their status in terms of cvs.

=head1 DESCRIPTION

cvs-files reports on files and their status in terms of cvs. It
lists files as being newer that cvs (locally modified), older
than cvs (needs update), or unknown to cvs. By default files that
are unknown to cvs are not shown.

A directory may be given on the commandline, otherwise the current
directory is checked.

=head1 COMMANDLINE ARGUMENTS

The following options are recognized:

=over 4

=item -a Show all files

=item -n Show newer files

=item -o Show older files

=item -r Recurse subdirectories

=item -u Show unknown files

=back

=head1 SEE ALSO

cvs(1)

=head1 AUTHOR

Von Welch <vwelch@ncsa.uiuc.edu>

=cut
