#!/usr/bin/env perl
######################################################################
#
# Backup to my PCMCIA harddrive
#
# $Id$
#
######################################################################
#
# Configuration


######################################################################
#
# Find our Home directory
#

$Home = $ENV{HOME} || die "HOME not defined.";

######################################################################
#
# Find the backup volume

my $backup_path = undef;

my @potential_paths =
    (
     "/Volumes/USB Drive/",
     "/Volumes/FIRE&FORGET/"
    );

foreach my $path (@potential_paths)
{
    if ( -d $path )
    {
	$backup_path = $path;
	last;
    }
}

if (!defined($backup_path))
{
    print STDERR "Could not find backup volume.\n";
    exit(1);
}

my $Prefix = $backup_path;

######################################################################

# Name of log file
$LogFile = $Home . "/backup.log";

if (-e $LogFile)
{
    unlink $LogFile
}

# Redirect STDOUT to tee, puting it both to the screen and the log file
if (!open(STDOUT, "| /usr/bin/tee -a \"$LogFile\""))
{
    die "Could not direct STDOUT: $!";
}

if (!open(STDERR, ">&STDOUT"))
{
    die "Could not direct STDERR: $!";
}

print "Writing backup log to " . $LogFile . "\n";

######################################################################

$date_string = localtime();
print "Backup date: " . $date_string . "\n";

print "Backing up to volume " . $backup_path . "\n";

######################################################################
#
# Build list of directories to backup

@BackupDirs = ();

push(@BackupDirs, $Home . "/Documents/");
push(@BackupDirs, $Home . "/Library/Keychains/");
push(@BackupDirs, $Home . "/Library/Preferences/");
push(@BackupDirs, $Home . "/Library/Mail/");
push(@BackupDirs, $Home . "/creds/");
push(@BackupDirs, $Home . "/homestuff/");
push(@BackupDirs, $Home . "/lib/");
push(@BackupDirs, $Home . "/mail/");
push(@BackupDirs, $Home . "/scripts/");
push(@BackupDirs, $Home . "/.globus/");
push(@BackupDirs, $Home . "/develop/scripts/");
push(@BackupDirs, $Home . "/Pictures");

print "Backing up: " . join(' ', @BackupDirs) . "\n";

######################################################################
#
# Stuff to exclude

@ExcludeFiles = ();

push(@ExcludeFiles, "*.tmp");

# I don't need OLD stuff
push(@ExcludeFiles, "OLD/*");

# MSWord tmp files
push(@ExcludeFiles, "~\$*.doc");

# Emacs backups
push(@ExcludeFiles, "*~");
push(@ExcludeFiles, "#*#");

# Directories to skip.
#
# Use single quotes (') here around strings so that '@' characters are
# not interpreted as arrays.
push(@ExcludeFiles, $Home . '/mail/spam/*');
push(@ExcludeFiles, $Home . '/mail/procmail-logs/*');
push(@ExcludeFiles, $Home . '/Documents/Microsoft User Data/*');
push(@ExcludeFiles, $Home . '/Library/Mail/POP-vwelch@localhost:11110/Junk.mbox/*');
push(@ExcludeFiles, $Home . '/Library/Mail/Mailboxes/ncsa-security-reports.mbox/*');
push(@ExcludeFiles, $Home . '/Library/Mail/Mailboxes/ncsa-security-reports.mbox/Messages/*');
push(@ExcludeFiles, $Home . '/Library/Mail/POP-vwelch@localhost:11110/Deleted Messages.mbox/*');
push(@ExcludeFiles, $Home . '/Library/Mail/POP-vwelch@localhost:11110/Junk.mbox/*');
push(@ExcludeFiles, $Home . '/Library/Mail/Bundles/*');
push(@ExcludeFiles, $Home . '/Library/Mail/Bundles (Disabled)/*');
push(@ExcludeFiles, $Home . '/Library/Preferences/PokerAcademyPro/*');
push(@ExcludeFiles, $Home . '/Library/Preferences/PokerAcademyProDemo/*');

my $ExcludeFile = $Prefix . "/backup-excludes";

if (!open(EXCLUDES, ">$ExcludeFile"))
{
    die "Could not open $ExcludeFile: $!";
}

foreach my $exclude (@ExcludeFiles)
{
    print EXCLUDES $exclude . "\n";
}

close(EXCLUDES);

print "Excluding: " . join(" ", @ExcludeFiles) . "\n";

######################################################################

# Name of backup file
$TarFile = $Prefix . "/backup.tar";
$OldTarFile = $Prefix . "/backup-old.tar";

print "Backup file: $TarFile\n";

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

@ARG = ("tar");
push(@ARG, "-c"); # create
push(@ARG, "-v"); # verbose mode
push(@ARG, "-f", $TarFile);

# Ignore leading "/" in exclude patterns
push(@ARG, "--no-anchored");

push(@ARG, "--exclude-from", $ExcludeFile);

foreach my $BackupDir (@BackupDirs)
{
  push(@ARG, $BackupDir);
}

print join(' ', @ARG) . "\n";

system(@ARG);

$date_string = localtime();
print "Done: " . $date_string . "\n";

sleep(10);

exit(0);

