#!/usr/bin/perl
######################################################################
#
# eudora_convert.pl
#
# Convert eudora email boxes to unix.
#
######################################################################


convert_dir(shift || ".");

sub convert_dir {
  my $dir = shift;

  print "Converting directory \"$dir\"...\n";

  local(*descmap);

  my $descmap_file = $dir . "/descmap.pce";

  if (! -e $descmap_file) {
    my $uc_filename = $dir . "/DESCMAP.PCE";

    if ( -e $uc_filename ) {
      $descmap_file = $uc_filename;
    }
  }

  if (!open(descmap, "<$descmap_file")) {
    print STDERR "Could not open $descmap_file for reading: $!\n";
    return(0);
  }

 ENTRY: while(<descmap>) {
    # Format is <fullname>,<filename>,[F|M] <Folder or Mailbox>, [Y|N] <unknown>
    my ($fullname, $filename, $type, $unknown) = split(/,/);

    $fullname = $dir . "/" . $fullname;
    $filename = $dir . "/" . $filename;

    print "Renaming $filename to $fullname...\n";

    if (! -e $filename) {
      # Try uppercase
      my $uc_filename = $filename;

      $uc_filename =~ tr/[a-z]/[A-Z]/;

      if (-e $uc_filename) {
	$filename = $uc_filename;
      }
    }

    if (! -e $filename) {
      print STDERR "Coult not find $filename\n";
      next ENTRY;
    }

    if (!rename($filename, $fullname)) {
      print STDERR "Could not rename $filename: $!\n";
      next ENTRY;
    }

    if ($type eq "F") {

      convert_dir($fullname);

    }
  }

  close(descmap);

  return(1);
}

    
