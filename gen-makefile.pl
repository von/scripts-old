#!/usr/local/bin/perl
######################################################################
#
# gen-makefile
#
# Build makefile for script maintainence.
#
######################################################################

use File::Basename;

######################################################################

$makefile = "Makefile";

$makefile_header = "makefile_header";

$modules = "modules";

my @suffix_list = ( ".sh", ".pl" );

######################################################################
#
# For use in Makefile
#

$install = "\$(INSTALL_EXEC)";

$rm = "\$(RM)";

$install_dir = "\$(INSTALL_DIR)";

######################################################################
#
# Prepend makefile_header


open(MAKEFILE, ">$makefile") ||
  die "Couldn't open $makefile for writing: $!";

select MAKEFILE;

open(MAKEFILE_HEADER, $makefile_header) ||
  die "Couldn't open $makefile_header for readinge: $!";

while(<MAKEFILE_HEADER>) {
  print;
}

close(MAKEFILE_HEADER);

######################################################################
#
# Now open and parse the modules file
#
open(MODULES, $modules) ||
  die "Couldn't open $modules for reading: $!";

line: while(<MODULES>) {
  # Remove comments
  s/#.*$//;

  # Ignore blank lines
  /^\s*$/ && next line;

  # Concatenate lines with escaped carriage returns
  if (s/\\$//) {
    s/\n//;
    $_ .= <MODULES>;
    redo unless eof();
  }

  # Format should be "<module>: <files>"
  if (/\s*(\S+)\s*:\s*(.*)\s*$/) {
    my $module = $1;
    my @files = split(/[\s,]+/, $2);

    my $source_files = undef;
    my $installed_files = undef;

    print <<EOF;
######################################################################
#
# $module
#

EOF

    # Now write out rule for installing each file
    foreach my $file (@files) {
      my $basename = basename($file, @suffix_list);
      my $dest = "\$(INSTALL_DIR)/$basename";
      my $src = "$module/$file";
      my $file_install_rule = $basename . "-install";
      my $file_uninstall_rule = $basename . "-uninstall";

      print <<EOF;
install :: $file_install_rule

uninstall :: $file_uninstall_rule

$file_install_rule : $dest

$file_uninstall_rule :
\t$rm $dest

$dest : $src
\t$install $src $dest

EOF
    }

    next line;
  }

  print STDERR "Failed to parse line $. of $modules\n";
}

close(MODULES);

######################################################################
#
# Done
#

close(MAKEFILE);

exit(0);
