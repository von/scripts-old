#!/usr/bin/env perl
######################################################################
#
# cvs-make-patch
#
# Make a patch from a cvs repository
#
# $Id$
#
######################################################################
#
# Defaults
#

%Configuration = (
		  cvs              => "cvs",
		  cvs_opts         => "",

		  # -kk     Ignore differences in RCS keyword values
		  rdiff_opts       => "-kk",

		  strip_module_name_from_index => 1,
		 );

######################################################################

use Time::localtime;

$date = ctime();

######################################################################
#
# Set $Myname equal to basename of this script

$0 =~ /.*\/([^\/]+)$/;

$Myname = $1;

######################################################################

my $date_rev_count = 0;
my $arg_error = 0;

# Parse options. We write our own function here because we need to
# be able to handle multiple occurances of '-r' and '-D' which
# the perl modules don't seem to.

argument: while ($ARGV[0] =~ /^-(\w+)/) {
  my $arg = $1;
  shift;

  if ($arg eq "d") {
    # -d <cvsroot>
    my $cvsroot = shift;

    if (!defined($cvsroot)) {
      error_msg("-d requires value");
      $arg_error++;
      last;
    }

    $Configuration{cvs_opts} .= " -d $cvsroot";

    next argument;
  }

  if (($arg eq "r") || ($arg eq "D")) {
    # -r <revision>
    # -D <date>
    my $value = shift;

    if (!defined($value)) {
      error_msg("-$ARG requires value");
      $arg_error = 1;
      last;
    }

    if ($date_rev_count == 2) {
      error_msg("Can't specify more than two dates/revisions");
      $arg_error = 1;
      next argument;
    }

    $date_rev_count++;
      
    $Configuration{rdiff_opts} .= " -$arg \"$value\"";

    next argument;
  }

  error_msg("Unknown argument: -$arg");
  $arg_error = 1;
}

if ($date_rev_count == 0) {
  error_msg("Must specify at least one date/revision");
  $arg_error = 1;
}

$module = shift;

if (!defined($module)) {
  error_msg("Must specify module name");
  $arg_error = 1;
}

if ($arg_error) {
  usage();
  exit(1);
}
 
######################################################################
#
# Main Code
#

$cmd = $Configuration{cvs};
$cmd .= " " . $Configuration{cvs_opts};
$cmd .= " rdiff";
$cmd .= " " . $Configuration{rdiff_opts};
$cmd .= " " . $module;

if (!open(CVS, "$cmd | ")) {
  error_msg("Error executing $cmd");
  exit(1);
}

print "Patch command: $cmd\n";
print "Date: $date\n";
print "\n";

while(<CVS>) {
  if (/^Index:/ && $Configuration{strip_module_name_from_index}) {
    s/$module\///;
  }

  print;
}

close(CVS);

exit(0);


#
# End of Main Code
#
###################################################################### 




######################################################################
#
# error_msg - print an error message
#
# Arguments: Argument to printf
# Returns: Nothing

sub error_msg {
  my $format = shift;

  chomp($format);

  my $message = sprintf($format, @_);

  print STDERR "$Myname: $message\n";
}

######################################################################
#
# usage - print Usage
#

sub usage {
  print "
Usage: $Myname [<options>] <module>

Options are:
     -d <cvsroot>                Specify CVS root directory.
     -D <date>                   Specify Date (may appear 0, 1 or 2 times).
     -r <revision>               Specify revision (may appear 0, 1, or 2 times).

Must specify at least one of -r and -D.
";
}


__END__

######################################################################
#
# POD documentation
#

=head1 NAME

cvs-make-patch

=head1 SYNOPSIS

cvs-make-patch <options> module

cvs-make-patch makes a patch with the differences between two
point in a cvs repository.

=head1 DESCRIPTION

cvs-make-patch does an rdiff between the two indicated points of
the indicated repository. It does some minor massaging to make
the output more palatable to patch.

=head1 COMMANDLINE ARGUMENTS

cvs-make-release accepts the following commandline options:

=over 4

=item -d <cvsroot>

=item -D <date>    As with cvs rdiff.

=item -r <tag>     As with cvs rdiff.

=back

=head1 SEE ALSO

cvs(1)

=head1 AUTHOR

Von Welch <vwelch@ncsa.uiuc.edu>

=cut
