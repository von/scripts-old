#!/usr/bin/perl
######################################################################
#
# globus-build
#
# Build a globus install from a bunch of bundles.
#
# $Id$
#
######################################################################

my @Packages = @ARGV;

my $Flavor = "gcc32dbg";

######################################################################
#
# Determine where to find GPT
#

if (defined($ENV{"GPT_LOCATION"}))
{
  $GPT_location = $ENV{"GPT_LOCATION"};
}
else
{
  $GPT_location = $ENV{"GLOBUS_LOCATION"};
}

if (!defined($GPT_location))
{
  die "Could not fine GPT";
}

######################################################################
#
# Sanity check GLOBUS_LOCATION
#

$Globus_location = $ENV{GLOBUS_LOCATION};

if (!defined(Globus_location))
{
  die "GLOBUS_LOCATION not set";
}

######################################################################

foreach $package (@Packages)
{
  print "Building $package...\n";

  # Determine build options
  $options = undef;

  if (($package =~ /data-management-server/) ||
      ($package =~ /resource-management-server/))
  {
    $options = "-static=1"
  }

  # Determine flavor
  if ($package =~ /information-systems/)
  {
    $flavor = $Flavor . "pthr";
  }
  else
  {
    $flavor = $Flavor;
  }

  my @command = ($GPT_location . "/sbin/gpt-build");
  push(@command, "-install-only");
  push(@command, $package);
  push(@command, $options) if defined($options);
  push(@command, $flavor);

  run_command(@command);

  @command = ($GPT_location . "/sbin/gpt_verify");

  run_command(@command);

  @command = ($Globus_locaiton . "bin/gpt-postinstall");

  run_command(@command);
}

######################################################################

print "Done\n";

exit(0);

#
# End Main Code
#
######################################################################

######################################################################
#
# run_command
#

sub run_coomand
{
  my @command_args = @_;

  print join(' ', @command_args) . "\n";

  my $rc = system(@command_args) >> 8;

  return 1;
}
