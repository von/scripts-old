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
    # Format is <fullname>,<filename>,
    #   [S|F|M] <System Mailbox, Folder or Mailbox>, [Y|N] <unknown>

    my ($fullname, $filename, $type, $unknown) = split(/,/);

    $fullname = $dir . "/" . $fullname;
    $filename = $dir . "/" . $filename;

    # changes spaces to dashes
    $fullname =~ s/\s+/-/g;

    if(($type eq "M") ||
       ($type eq "S"))
    {
      my $mailbox = find_file($filename);

      if (!defined($mailbox)) {
	print STDERR "Coult not find $filename\n";
	next ENTRY;
      }

      print "Converting $mailbox to $fullname...\n";

      if (!convert_file($mailbox, $fullname)) {
	next ENTRY;
      }

      unlink($mailbox);

    } elsif ($type eq "F") {

      my $folder = find_file($filename);

      if (!defined($folder)) {
	print STDERR "Could not find $filename\n";
	next ENTRY;
      }

      print "Renaming $folder to $fullname...\n";

      if (!rename($folder, $fullname)) {
	print STDERR "Could not rename $filename: $!\n";
	next ENTRY;
      }

      convert_dir($fullname);

    } else {
      print STDERR "Unknown type \"$type\" for $filename\n";
    }
  }

  close(descmap);

  return(1);
}

sub find_file {
  my $filename = shift;

  if (! -e $filename) {
    # Try uppercase
    my $uc_filename = $filename;

    $uc_filename =~ tr/[a-z]/[A-Z]/;

    if (-e $uc_filename) {
      $filename = $uc_filename;
    }
  }

  if (! -e $filename) {
    return undef;
  }

  return $filename;
}

sub convert_file {
  my $eudora_name = shift;
  my $unix_name = shift;

  if (!open(IN, "<$eudora_name")) {
    print STDERR "Could not open $eudora_name for reading: $!";
    return 0;
  }

  if (!open(OUT, ">$unix_name")) {
    print STDERR "Could not open $unix_name for writing: $!";
    return 0;
  }

  line: while(<IN>) {

      # Convert CR-LF to LF
      s/\x0d\x0a/\x0a/g;

      # XXX Really what I want to do here is maintain state if the
      # previous line was blank, and if no and I encounter a "From "
      # then add a blank line.

      # At some point Eudora started putting <x-flowed> stuff in the
      # body, which is ok, but now there is no blank line before the
      # from, so strip out the x-flowed stuff and make sure we have
      # a blank line.

      # Strip <x-flowed>
      if (/^\<x-flowed\>\s+$/) {
	next line;
      }

      # Replace </x-flowed> with blank line to delimit From
      if (/^\<\/x-flowed\>\s+$/) {
	print OUT "\n";
	next line;
      }

      # When Eudora converts an attachment it puts in a line saying it
      # did, but doesn't leave a blank line before the from, so add it.
      if (/^Attachment Converted:/) {
	print OUT;
	print "\n";
	next line;
      }

      print OUT;
    }

  close(IN);
  close(OUT);
  return 1;
}
