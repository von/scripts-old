#!/usr/local/bin/perl
######################################################################
#
# mykinit
#
#
######################################################################

use File::stat;

######################################################################

# My external @home address
my $nat_address = "c794543-a.chmpgn1.il.home.com";

# Jen's @home address
my $jms_nat_address = "65.10.202.54";

my @extra_addresses = (
		       $nat_address,
		       $jms_nat_address,
		      );

######################################################################

my @Principals = ("vwelch\@MALLORN.COM");

my %Principals_info =
  (
   "vwelch\@NCSA.EDU"      => {
			       "cache"        => "/tmp/krb5cc_$<",
			       "forwardable"  => 1,
			       },
   "vwelch\@MALLORN.COM"   => {
			       "cache"        => "/tmp/krb5cc_vwelch_mallorn",
			       },
  );

######################################################################

my %Binaries = (
		"kinit"          => "kinit",
		"klist"          => "klist",
	       );

######################################################################
#
# Parse commandline options
#

use Getopt::Std;

my %opts;

getopts('AE:f', \%opts);

# XXX check for both A and E

######################################################################

principal: foreach my $principal (@Principals) {
  my $info = $Principals_info{$principal};

  !$opts{f} && creds_exist($info->{cache}) && next principal;

  my @cmd;

  push(@cmd, $Binaries{kinit});
  push(@cmd, "-c", $info->{cache});
  push(@cmd, "-f") if $info->{forwardable};

  if (defined($opts{A})) {
    push(@cmd, "-A");
  } else {
    my @extra_addrs = @extra_addresses;
    push(@extra_addrs, $opts{E})
      if defined($opts{E});
    push(@extra_addrs, @{$info->{extra_addr}})
      if defined($info->{extra_addr});

    push(@cmd, "-E", join(",", @extra_addrs))
      if @extra_addrs;
  }

  push(@cmd, "-l", "25h");
  push(@cmd, $principal);

  print join(' ', @cmd) . "\n";

  my $try = 0;

 attempt: while ($try < 3) {
    my $rc = system(@cmd);

    last attempt if ($rc == 0);

    $try++;

  } continue {
    print "Retrying...\n";
  }
    ;
}

######################################################################

sub creds_exist {
  my $cache = shift;

  my @cmd;

  push(@cmd, $Binaries{klist});
  push(@cmd, "-s");
  push(@cmd, "-c", $cache);

  my $rc = system(@cmd) >> 8;

  return ($rc == 0);
}
