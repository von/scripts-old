#!/usr/local/bin/perl
######################################################################
#
# Backup to my PCMCIA harddrive
#
######################################################################
#
# Configuration

$CygwinRoot = "C:/cygwin";

######################################################################
#
# Figure out which drive is the PCMCIA harddrive, which should be
# the same one that this script is.

if ($0 =~ /^(\w:)/) {
  $Prefix = $1;
} else {
  $Prefix = ".";
}

######################################################################
#
# Build list of directories to backup

@BackupDirs = ();

# Home directory
$Home = $ENV{HOME} || die "HOME not defined.";
push(@BackupDirs, $Home . "/My Documents");

push(@BackupDirs, $Home . "/Mail");

push(@BackupDirs, $Home . "/.xemacs");
push(@BackupDirs, $Home . "/develop");

push(@BackupDirs, $Home . "/.bbdb");
push(@BackupDirs, $Home . "/.profile");

# Outlook data
push(@BackupDirs,
     $Home . "/Local Settings/Application Data/Microsoft/Outlook");

# Putty Configuration
# XXX If I add another registry backup, make a function for this
print("Exporting PUTTY configuration from registry\n");
my $putty_reg = $Prefix . "/putty.reg";
system("regedit /e $putty_reg HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY");
push(@BackupDirs, $putty_reg);

######################################################################
#
# Stuff to exclude

@ExcludeFiles = ();

push(@ExcludeFiles, "*.tmp");

# Eudora cruft
push(@ExcludeFiles, $HOME . "/My Documents/Personal Email/Embedded/*");
push(@ExcludeFiles, "Trash.mbx");
push(@ExcludeFiles, "Trash.toc");

# Development stuff
push(@ExcludeFiles, $HOME . "/develop/*");

# I don't need OLD stuff
push(@ExcludeFiles, "OLD/*");

# MSWord tmp files
push(@ExcludeFiles, "~$*.doc");

# Emacs backups
push(@ExcludeFiles, "*~");
push(@ExcludeFiles, "#*#");

# Web browser caches (XXX May be too broad)
push(@ExcludeFiles, "Cache/*");

# Skip all my pictures as they take too long
push(@ExcludeFiles, $HOME . "/My Documents/My Pictures/*");

# Misc
push(@ExcludeFiles, "/Config/Personal Web Browser Profile");



######################################################################

# Name of backup file
$TarFile = $Prefix . "\\backup.tar";
$OldTarFile = $Prefix . "\\backup-old.tar";

######################################################################
#
# If TarFile exists, move it to OldTarFile (overwriting it)

if ( -e $TarFile ) {
  # Delete OldTarFile if it exists
  if ( -e $OldTarFile)
  {
    unlink $OldTarFile;
  }

  rename($TarFile, $OldTarFile) ||
    die "Raname of $TarFile to $OldTarFile failed: $!";
}

######################################################################
#
# Do backup

@ARG = ($CygwinRoot . "/bin/tar");
push(@ARG, "-c"); # create
push(@ARG, "-v"); # verbose mode
push(@ARG, "-f", cygwin_path($TarFile));

foreach my $ExcludeFile (@ExcludeFiles)
{
  push(@ARG, "--exclude=\"" . cygwin_path($ExcludeFile) . "\"");
}

foreach my $BackupDir (@BackupDirs)
{
  push(@ARG, "\"" . cygwin_path($BackupDir) . "\"");
}

print join(' ', @ARG) . "\n";

system(@ARG);

print "Done.\n";

sleep(10);

exit(0);

######################################################################
#
# cygwin_path
#
# Convert a windows path to a cygwin path.

sub cygwin_path {
  my $path = shift;
  $path =~ s|(\w):|/cygdrive/$1|;
  $path =~ s|\\|/|g;
  return $path;
}
