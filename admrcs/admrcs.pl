#!/usr/local/bin/perl
######################################################################
#
# admrcs
#
# Basically a simple CVS that allows me to store all the administrative
# files in a replacted root somewhere.
#
# $Id$
#
######################################################################

use Carp;

######################################################################
#
# Our defaults
#

my $repository_env_var = "ADMRCSROOT";

my $repository_path = $ENV{$repository_env_var};

######################################################################
#
# Map commands to functions
#

my %command_functions = (
			 "commit"         => \&command_commit,
			 "diff"           => \&command_diff,
			 "history"        => \&command_history,
			 "help"           => \&command_help,
			 "import"         => \&command_import,
			 "log"            => \&command_log,
			 "init"           => \&command_init,
			 "recall"         => \&command_recall,
			 "tag"            => \&command_tag,
			 "test"           => \&command_test,
			);

my %command_help = (
		    "commit"    => "Commit files into repository",
		    "diff"      => "Show differences between revisions",
		    "history"   => "Show log of all changes",
		    "help"      => "Display help",
		    "import"    => "Add files to repository",
		    "log"       => "Show log of changes to files",
		    "init"      => "Create a new repository",
		    "recall"    => "Retreive a file from repository",
		    "tag"       => "Add synbolic tag to repository files",
		   );

######################################################################
#
# Setup our user interface
#

my $Output = OutputObject->new();

DebugObject->global_debug();

######################################################################
#
# Parse commandline
#

use Getopt::Std;

my $arg_error = 0;
my %args;

getopts("d:", \%args);

$repository_path = $args{d}                if $args{d};

my $command = shift;

if (!defined($command)) {
  $Output->error_message("Missing command");
  $arg_error = 1;

} elsif (!exists($command_functions{$command})) {
  $Output->error_message("Unknown command \"%s\"", $command);
  $arg_error = 1;
}

if ($arg_error) {
  usage();
  exit(1);
}

######################################################################
#
#
#
my $command_function = $command_functions{$command};

if (!defined($repository_path) && ($command ne "help")) {
  $Output->error_message("Repository path not defined. $repository_env_var not set");
  exit(1);
}

my $repository = Repository->new($repository_path);

my $status = &$command_function($repository, $command, @ARGV);

exit($status);

######################################################################
#
# Command functions
#

sub command_commit {
  my $repository = shift;
  my $command = shift;

  local(@ARGV) = @_;

  my %args;
  getopts("m:", \%args);

  my $options = {};

  $options->{message} = $args{m}              if $args{m};

  $repository->commit($options, @ARGV) || return 1;

  return 0;
}


sub command_diff {
  my $repository = shift;
  my $command = shift;

  local(@ARGV) = @_;

  my %args;
  getopts("c", \%args);

  my $options = {};

  $options->{context_diff} = 1          if $args{c};

  return $repository->diff($options, @ARGV);
}

sub command_help {
  my $repository = shift;
  my $command = shift;

  print"
Usage: $0 [<options>] <command>

Commands are:
";
  foreach my $cmd (keys(%command_help)) {
    printf("      %10s   %s\n", $cmd, $command_help{$cmd});
  }

  print "

Options are:
      -d <dir>     Specify repository to use.

For detailed help run:
  perldoc $0
";
}

sub command_history {
  my $repository = shift;
  my $command = shift;

  local(@ARGV) = @_;

  my $options = {};

  my $start_date = shift;
  my $end_date = shift;

  $options->{start_time} = date_to_seconds($start_date) if $start_date;
  $options->{end_time} = date_to_seconds($end_date) if $end_date;

  $repository->history($options) || return 1;

  return 0;
}

sub command_import {
  my $repository = shift;
  my $command = shift;

  local(@ARGV) = @_;

  my %args;
  getopts("m:", \%args);

  my $options = {};

  $options->{message} = $args{m}              if $args{m};

  $repository->import($options, @ARGV) || return 1;

  return 0;
}

sub command_init {
  my $repository = shift;
  my $command = shift;

  my $options = {};

  $repository->init($options) || return 1;

  return 0;
}

sub command_log {
  my $repository = shift;
  my $command = shift;

  local(@ARGV) = @_;

  my $options = {};

  $repository->log($options, @ARGV) || return 1;

  return 0;
}

sub command_recall {
  my $repository = shift;
  my $command = shift;

  local(@ARGV) = @_;

  my %args;
  getopts("r:", \%args);

  my $options = {};

  $options->{revision} = $args{r}             if $args{r};

  $repository->recall($options, @ARGV) || return 1;

  return 0;
}

sub command_tag {
  my $repository = shift;
  my $command = shift;


  local(@ARGV) = @_;

  my %args;
  getopts("fr:", \%args);

  my $options = {};

  $options->{revision} = $args{r}             if $args{r};
  $options->{force} = $args{f}                if $args{f};

  my $tag = shift(@ARGV);

  if (!defined($tag)) {
    $Output->error_message("No tag given");
    return 1;
  }

  $options->{tag} = $tag;

  $repository->tag($options, @ARGV) || return 1;

  return 0;
}


sub command_test {
  my $repository = shift;
  my $command = shift;

  my $date = shift;
  print "DATE: $date\n";

  my $secs = date_to_seconds($date);
  print "SECS: $secs\n";
  print "DATE: " . localtime($secs) . "\n";
  return 0;
}

######################################################################
#
# Support routines
#

sub usage {
  $Output->message("Usage: $0 [<options>] <command> [<options>]");
  $Output->message("      \"$0 help\" for help");
}

# date_to_seconds
#
# Given a date string, return seconds since 1970 that it represents.
#
# Arguments: Date string
# Returns: Seconds since 1970, undef on error
sub date_to_seconds {
  my $date = shift || croak("Missing date string arguments");

  use Time::localtime;

  if ($date eq "now") {
    return time();
  }

  # Dash means begining of time
  if ($date eq "-") {
    return 0;
  }

  # Check for "mm/dd/yyyy hh:mm:ss" format
  if (($date =~ /^\s*\d?\d\/\d?\d(\/\d\d\d\d)?\s*$/) ||
      ($date =~ /^\s*\d?\d:\d\d(:\d\d)?\s*$/) ||
      ($date =~ /^\s*\d?\d\/\d?\d(\/\d\d\d\d)?\s+\d?\d:\d\d(:\d\d)?\s*$/)) {

    $time = localtime();

    # Time is midnight by default
    $time->hour(0);
    $time->min(0);
    $time->sec(0);

    # Parse date
    if (($date =~ /(\d?\d)\/(\d?\d)\/(\d\d\d\d)/) ||
	($date =~ /(\d?\d)\/(\d?\d)/)) {

      $time->mon($1 - 1);
      $time->mday($2);
      $time->year($3 - 1900) if defined($3);
    }

    # Parse time

    if (($date =~ /(\d?\d):(\d\d):(\d\d)/) ||
	($date =~ /(\d?\d):(\d\d)/)) {

      $time->hour($1);
      $time->min($2);
      $time->sec($3) if defined($3);
    }

    return tm_to_seconds($time);
  }

  $Output->error_message("Could not parse date/time \"%s\"", $date);
  return undef;
}

# tm_to_seconds()
#
# Given a tm object, return seconds since 1970 that it represents.
#
# Arguments: tm object
# Returns: seconds since 1970, undef on error
sub tm_to_seconds {
  my $tm = shift || croak("Missing tm argument");

  use Time::Local;

  my $seconds = timelocal($tm->sec(), $tm->min(), $tm->hour(),
			  $tm->mday(), $tm->mon(), $tm->year());

  return undef if ($seconds == -1);

  return $seconds;
}

######################################################################
#
# Repository
#
# Object representing a repository. Is really just a front end
# for LocalRepository and RemoteRepository.
#

package Repository;

BEGIN {
  @ISA = ('DebugObject');
}

use Carp;

# get_path()
#
# Arguments: None
# Returns: Path of repository

sub get_path {
  my $self = shift;

  return $self->{_path};
}

# new(path)
#
# Create a new repository object for the repository at the given
# path.

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};

  my $path = shift || croak("Missing path");

  # Eventually will check for remote path here

  return LocalRepository->new($path);
}



# _new_file(path)
#
# Create and return a new RepositoryFile object for the given path.

sub _new_file {
  my $self = shift;
  my $path = shift || croak("Missing path");

  return RepositoryFile->new($path, $self);
}

######################################################################
#
# LocalRepository
#
# Object for representing a repository on the local system.

package LocalRepository;

use Carp;

BEGIN {
  @ISA = ("Repository", "OutputObject");
}

# commit()
#
# commit one or more files into the repository.
#
# Arguments: options, list of filenames
# Returns: 1 on success, 0 on any error

sub commit {
  my $self = shift;

  my $options = shift;

  $self->_check_repository() || return 0;

  my @files = $self->parse_files(@_);

  my $error_occurred = 0;

  foreach my $file (@files) {
    $file->ok_to_commit($options) || ($error_occurred = 1);
  }

  $error_occurred && return 0;

  my @modified_files = $self->modified_files(@files);

  if (scalar(@modified_files) == 0) {
    $self->message("Nothing to do.");
    return 1;
  }

  my $log_text ="Files modified:\n";

 file: foreach my $file (@modified_files) {
    $log_text .= sprintf("%s <%s>\n", $file->name(), $file->get_revision);
  }

  if (!defined($options->{message})) {
    $options->{message} = $self->_get_user_message($log_text) || return 0;
  }

  $self->_log($options, $log_text) || return 0;

 file: foreach my $file (@modified_files) {

    if (!$file->commit($options)) {
      $error_occurred = 1;
      next file;
    }
  }

  my $status = !$error_occurred;

  return $status;
}

# diff()
#
# Diff the given files, sending output to user.
#
# Arguments: options, list of filenames
# Returns: Diff status in scalar context (0 == no differences found,
#          1 == differences found, 2 == error).

sub diff {
  my $self = shift;

  my $options = shift;

  $self->_check_repository() || return 0;

  my @files = $self->parse_files(@_);

  my $found_diffs = 0;
  my $error_occurred = 0;

  foreach my $file (@files) {
    my $status = $file->diff($options);

    ($status == 1)     && ($found_diffs = 1);
    ($status == 2)     && ($error_occurred = 1);
  }

  my $status = ($error_occurred ? 2 : $found_diffs);

  return $status;
}

# history()
#
# Arguments: Options
# Returns: 1 on success, 0 on any error

sub history {
  my $self = shift;
  my $options = shift;

  $self->_check_repository() || return 0;

  my $start_time = $options->{start_time};
  my $end_time = $options->{end_time};

  local(*LOG_FILE);

  my $log_file = $self->{_log_file_name};

  if (!open(LOG_FILE, "<$log_file")) {
    $self->error_message("Could not open log file (%s) for reading: $!",
			 $log_file);
    return 0;
  }

  local($/) = $self->{_log_entry_seperator};

 entry: while(<LOG_FILE>) {
    /Timestamp: (\d+)/;
    my $timestamp = $1;

    next entry if (defined($start_time) && ($start_time > $timestamp));
    next entry if (defined($end_time) && ($end_time < $timestamp));

    $self->message($_);
  }

  close(LOG_FILE);

  return 1;
}

# import()
#
# Import one or more files into the repository.
#
# Arguments: Options, list of files
# Returns: 1 on success, 0 on any error

sub import {
  my $self = shift;

  my $options = shift;

  $self->_check_repository() || return 0;

  my @files = $self->parse_files(@_);

  my $error_occurred = 0;

  foreach my $file (@files) {
    $file->ok_to_import($options) || ($error_occurred = 1);
  }

  $error_occurred && return 0;

  my $log_text ="Files imported:\n";

 file: foreach my $file (@files) {
    $log_text .= sprintf("%s\n", $file->name());
  }

  if (!defined($options->{message})) {
    $options->{message} = $self->_get_user_message($log_text) || return 0;
  }

  $self->_log($options, $log_text) || return 0;

  foreach my $file (@files) {
    if ($file->import($options)) {
      $self->message("%s successfully imported.", $file->name());
    } else {
      $error_occurred = 1;
    }
  }

  my $status = !$error_occurred;

  return $status;
}

# init()
#
# Initialize repository.
#
# Arguments: None
# Returns: 1 on success, 0 on error

sub init {
  my $self = shift;

  # Create repository if it doesn't exist
  if (! -d $self->{_path}) {
    if (!mkdir($self->{_path}, 0777)) {
      $self->error_message("Could not create directory %s: %s",
			   $self->{_path}, $!);
      return 0;
    }

    $self->message("Repository %s created.", $self->{_path});

  } else {
    $self->message("Repository %s already exists.", $self->{_path});
}

  return 1;
}

# log()
#
# Show logs for given files.
#
# Arguments: options, list of filesnames
# Returns: 1 on success, 0 on any error

sub log {
  my $self = shift;
  my $options = shift;

  $self->_check_repository() || return 0;

  my @files = $self->parse_files(@_);

  my $error_occurred = 0;

 file: foreach my $file (@files) {

    if (!$file->log($options)) {
      $error_occurred = 1;
      next file;
    }
  }

  my $status = !$error_occurred;

  return $status;
}

# modified_files()
#
# Arguments: List of RepositoryFiles
# Returns: List of mofified RepositoryFiles

sub modified_files {
  my $self = shift;

  my @files = ();

  foreach my $file (@_) {
    push(@files, $file) if $file->modified();
  }

  return @files;
}

# new(path)
#
# Create a new LocalRepository object for the given path.

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};

  $self->{_path} = shift || croak("Missing path");

  use File::Spec;

  $self->{_log_file_name} = File::Spec->catfile($self->{_path}, "ADMRCS-LOG");
  $self->{_log_entry_seperator} = "-" x 70 . "\n";

  bless($self, $class);
  return $self;
}

# parse_files()
#
# Arguments: List of filenames supplied by the user.
# Returns: List of RepositoryFile objects

sub parse_files {
  my $self = shift;

  my @files = ();

  foreach my $file (@_) {
    push(@files, $self->_new_file($file));
  }

  return @files;
}

# recall()
#
# Arguments: options, list of files
# Returns: 1 on success, 0 on error

sub recall {
  my $self = shift;

  my $options = shift;

  $self->_check_repository() || return 0;

  my @files = $self->parse_files(@_);

  my $error_occurred = 0;

 file: foreach my $file (@files) {

    $file->recall($options) || ($error_occurred = 1);
  }

  my $status = !$error_occurred;

  return $status;
}

# tag()
#
# Arguments: options, list of files
# Returns: 1 on success, 0 on error

sub tag {
  my $self = shift;

  my $options = shift;

  $self->_check_repository() || return 0;

  my @files = $self->parse_files(@_);

  my $error_occurred = 0;

 file: foreach my $file (@files) {

    $file->tag($options) || ($error_occurred = 1);
  }

  my $status = !$error_occurred;

  return $status;
}

# _check_repository()
#
# Arguments: None
# Returns: 1 if repository ok, 0 otherwise
sub _check_repository {
  my $self = shift;

  my $path = $self->{_path};

  if (! -d $path) {
    $self->error_message("Repository %s does not exist. Create with init.",
			 $path);
    return 0;
  }

  if (! -w $path) {
    $self->error_message("Don't have permissions for repository %s.", $path);
    return 0;
  }

  return 1;
}

# _get_user_message()
#
# Allow the user to supply a log message.
#
# Arguments: Comments
# Returns: message on success, undef on error or aborted edit.

sub _get_user_message {
  my $self = shift;
  my $comments = shift;

  local(*TMP_FILE);

  my $tmp_file_name = "/tmp/admrcs.$$";

  if (!open(TMP_FILE, ">$tmp_file_name")) {
    $self->error_message("Could not open %s for writing: $!",
			 $tmp_file_name);
    return undef;
  }

  print TMP_FILE "ADMRCS:
ADMRCS: Enter comments for log. All lines starting with \"ADMRCS:\" will be
ADMRCS: removed.
ADMRCS:
";

  {
    local($/) = undef;
    $comments = "ADMRCS: " . $comments;
    $comments =~ s/\n/\nADMRCS: /g;
    print TMP_FILE $comments;
  }

  close(TMP_FILE);

  use File::stat;

  my $before_edit_stat = stat($tmp_file_name);

  if (!defined($before_edit_stat)) {
    $self->error_message("Could not stat $tmp_file_name: $!");
    return undef;
  }

  my $editor = $ENV{EDITOR} || "vi";

  my $cmd = $editor . " " . $tmp_file_name;

  system($cmd);

  my $after_edit_stat = stat($tmp_file_name);

  if (!defined($after_edit_stat)) {
    $self->error_message("Could not stat $tmp_file_name: $!");
    return undef;
  }

  # Was file altered?
  if ($before_edit_stat->mtime == $after_edit_stat->mtime) {
    # No, abort
    $self->error_message("Aborted.");
    unlink($tmp_file_name);
    return undef;
  }

  # Read tmp file contents
  if (!open(TMP_FILE, "<$tmp_file_name")) {
    $self->error_message("Could not open %s for reading: $!",
			 $tmp_file_name);
    return undef;
  }

  my $message = "";

 line: while(<TMP_FILE>) {
    next line if /^ADMRCS:/;

    $message .= $_;
  }

  close(TMP_FILE);

  unlink($tmp_file_name);

  return $message;
}


# _log()
#
# Make a log entry.
#
# Arguments: options, Log text
# Returns: 1 on success, 0 on error

sub _log {
  my $self = shift;
  my $options = shift;
  my $log_text = shift;

  local(*LOG_FILE);

  my $message = $options->{message};

  # Now append to log file
  my $log_file = $self->{_log_file_name};

  if (!open(LOG_FILE, ">>$log_file")) {
    $self->error_message("Could not open log file (%s) for writing: $!",
			 $log_file);
    return 0;
  }

  print LOG_FILE $self->{_log_entry_seperator};

  my $timestamp = time();
  my $date = localtime();
  my $username = getpwuid($<);

  use Sys::Hostname;
  my $hostname = hostname();

  print LOG_FILE "
User: $username
Timestamp: $timestamp
Date: $date

$log_text

$message

";


  close(LOG_FILE);

  return 1;
}


######################################################################
#
# RepositoryFile
#
# Virtual parent object for LocalRepositoryFile and
# RemoteRepositoryFile.

package RepositoryFile;

use Carp;

BEGIN {
  @ISA = ('DebugObject');
}

# commit()
#
# Arguments: Hash of message
# Returns: 1 on success, 0 on error

sub commit {
  my $self = shift;

  $self->_debug("Commiting %s", $self->{_path});

  my $options = shift || croak("Missing options");
  defined($options->{message}) || croak("Missing message");

  return $self->_error("Nothing known about file \"%s\"", $self->{_path})
    unless $self->_exists_in_repository();

  $self->_lock() || return 0;
  $self->_checkin($options) || return 0;

  return 1;
}

# diff()
#
# Arguments: Options
# Returns: diff status (0 == no diffs, 1 == differences, 2 == error).

sub diff {
  my $self = shift;
  my $options = shift || {};

  if (!$self->_exists_in_repository()) {
    $self->_error("Nothing known about file \"%s\"", $self->{_path});
    return 2;
  }

  my @cmd_args;
  my $binary = $self->{_binaries}->{rcsdiff};
  push(@cmd_args, $binary);
  # Suppress extra output
  push(@cmd_args, "-q");
  push(@cmd_args, "-c") if $options->{context_diff};
  push(@cmd_args, $self->_rcs_file());
  push(@cmd_args, $self->get_working_filename());

  my $process = Process->new(@cmd_args);

  my $diff_status = $process->run();

  return $diff_status;
}

# get_revision
#
# Arguments: None
# Returns: Revision of file in repository
sub get_revision {
  my $self = shift;

  if (!$self->_exists_in_repository()) {
    $self->_error("Nothing known about file \"%s\"", $self->{_path});
    return 2;
  }

  my @cmd_args;
  my $binary = $self->{_binaries}->{rlog};
  push(@cmd_args, $binary);
  # Print limited information
  push(@cmd_args, "-h");
  push(@cmd_args, $self->_rcs_file());

  my $process = Process->new(@cmd_args);

  my $process_fd = $process->run_with_output_pipe();

  my $revision = undef;

  while (<$process_fd>) {
    if (/^head: (\d+\.\d+)/) {
      $revision = $1;
      last;
    }
  }

  $process->close();

  return $revision;
}

# get_working_filename
#
# Return the working filename of this file object. If not explicitly
# set, this will be the initial path.
#
# Arguments: None
# Returns: Working filename

sub get_working_filename {
  my $self = shift;

  return $self->{_working_filename} || $self->{_path};
}

# import()
#
# Arguments: options
# Returns: 1 on success, 0 on error
sub import {
  my $self = shift;
  my $options = shift;

  return $self->_error("File \"%s\" already in repository.", $self->{_path})
    if $self->_exists_in_repository();

  my $rcs_file = $self->_rcs_file();

  use File::Basename;
  use File::Path;

  # Make file's path in repository
  my $directory = dirname($rcs_file);

  if (! -d $directory) {
    mkpath(dirname($rcs_file), 0, 0777) or
      return $self->_error("Failed creating directory path %s",
			   dirname($rcs_file));
  }

  $self->_checkin($options) || return 0;

  return 1;
}

# log()
#
# Arguments: options
# Returns: 1 on success, 0 on error
sub log {
  my $self = shift;
  my $options = shift || {};

  if (!$self->_exists_in_repository()) {
    $self->_error("Nothing known about file \"%s\"", $self->{_path});
    return 0;
  }

  my @cmd_args;
  my $binary = $self->{_binaries}->{rlog};
  push(@cmd_args, $binary);
  push(@cmd_args, $self->_rcs_file());

  my $process = Process->new(@cmd_args);

  $process->run() && return 0;

  return 1;
}

# modified()
#
# Arguments: None
# Returns: 1 if file locally modified, 0 otherwise

sub modified {
  my $self = shift;

  my @cmd_args;
  my $binary = $self->{_binaries}->{rcsdiff};
  push(@cmd_args, $binary);
  push(@cmd_args, $self->_rcs_file());
  push(@cmd_args, $self->get_working_filename());

  my $process = Process->new(@cmd_args);

  my $status = $process->run_with_no_output();

  if ($status == 2) {
    # Error, punt
    $status = 0;
  }

  $self->_debug("%s modified status is %d", $self->{_path}, $status);

  return $status;
}

# name()
#
# Arguments: None
# Returns: Filename

sub name {
  my $self = shift;

  return $self->{_path};
}

# new()
#
# Arguments: Path of file, Repository object
# Returns: Object

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};

  my $path = shift || croak("Missing path");
  my $repository = shift || croak("Missing repository object");

  use File::Spec;
  use Cwd;

  # Get a clean absolute pathname
  $path = File::Spec->catfile(getcwd(), $path)
    unless File::Spec->file_name_is_absolute($path);
  $path = File::Spec->canonpath($path);

  $self->{_path} = $path;

  $self->{_repository} = $repository;
  $self->{_binaries} = {
			ci              => "ci",
			cp              => "cp",
			co              => "co",
			cat             => "cat",
			rcs             => "rcs",
			rcsdiff         => "rcsdiff",
			rlog            => "rlog",
		       };
  $self->{_rcs_suffix} = ",v";

  bless($self, $class);
  return $self;
}

# ok_to_commit()
#
# Check to make sure file is ok to commit.
#
# Arguments: options
# Returns: 1 if ok, 0 otherwise

sub ok_to_commit {
  my $self = shift;

  my $working_file = $self->get_working_filename();
  my $rcs_file = $self->_rcs_file();

  if (!$self->_exists_in_repository()) {
    $self->_error("%s doesn't exist in repository. import first",
		  $self->name());
    return 0;
  }

  if (! -w $working_file ) {
    $self->_wrror("Don't have permissions on %s", $self->name());
    return 0;
  }

  return 1;
}

# ok_to_import()
#
# Check to make sure file is ok to import.
#
# Arguments: options
# Returns: 1 if ok, 0 otherwise

sub ok_to_import {
  my $self = shift;

  my $working_file = $self->get_working_filename();
  my $rcs_file = $self->_rcs_file();

  if ($self->_exists_in_repository()) {
    $self->_error("%s already exists in repository", $self->name());
    return 0;
  }

  if (! -w $working_file ) {
    $self->_error("Don't have permissions on %s", $self->name());
    return 0;
  }

  return 1;
}

# recall()
#
# Recall a file from the repository.
#
# Arguments: options
# Returns: 1 on success, 0 on error

sub recall {
  my $self = shift;
  my $options = shift || {};

  $self->_checkout($options) || return 0;
  return 1;
}

# set_working_filename(path)
#
# Set the name of the working file to be something other than
# the default. An undefined value sets it to the default.
#
# Arguments: Path to working file or undef
# Returns: Nothing

sub set_working_filename {
  my $self = shift;

  # Undefined means to use default
  $self->{_working_filename} = shift;
}

# tag()
#
# Arguments: options
# Returns: 1 on success, 0 on error

sub tag {
  my $self = shift;
  my $options = shift || {};

  my $rcs_file = $self->_rcs_file();

  # Remember file permissions so we can reset them after rcs changes
  # them
  use File::stat;

  my $stat_info = stat($rcs_file);

  my @cmd_args;
  my $binary = $self->{_binaries}->{rcs};
  push(@cmd_args, $binary);

  my $arg;
  $arg = ($options->{force} ? "-N" : "-n");
  $arg .= $options->{tag} . ":";
  $arg .= $options->{revision} if $options->{revision};

  push(@cmd_args, $arg);

  push(@cmd_args, $self->_rcs_file());

  my $process = Process->new(@cmd_args);

  my $rcs_status = $process->run();

  my $status;

  if ($rcs_status == 0) {
    # Success
    $status = 1;

  } else {
    $status = 0;
    $self->_error("Error tagging file %s", $self->{_path});
  }

  # Restore permissions on file
  chmod($stat_info->mode, $rcs_file) ||
    return $self->_error("Error setting permissions on %s", $rcs_file);

  return $status;
}


# _checkin()
#
# Arguments: options
# Returns: 1 on success, 0 on error

sub _checkin {
  my $self = shift;
  my $options = shift || {};

  my $message = $options->{message} || "";

  my $working_file = $self->get_working_filename();
  my $rcs_file = $self->_rcs_file();

  return $self->_error("File %s does not exist", $working_file)
    unless -f $working_file;

  return $self->_error("Don't have permissions for %s", $working_file)
    unless -w $working_file;

  use File::stat;

  my $stat_info = stat($working_file);

  my @cmd_args;
  my $binary = $self->{_binaries}->{ci};
  push(@cmd_args, $binary);

  # Keep a checked out copy of the file
  push(@cmd_args, "-u");

  # Use both -m and -t- in case this is an import
  push(@cmd_args, "-m$message");
  push(@cmd_args, "-t-$message");

  # Force checking even if this isn't different from current version
  push(@cmd_args, "-f");

  push(@cmd_args, $rcs_file);
  push(@cmd_args, $working_file);

  my $process = Process->new(@cmd_args);

  my $checkin_status = $process->run();

  my $status;

  return $self->_error("Error checking in file %s", $self->{_path})
    unless ($checkin_status == 0);

  # Restore file mode
  chmod($stat_info->mode, $working_file) ||
    return $self->_error("Error setting permissions on %s", $working_file);

  # And set file mode of rcs file to match
  chmod($stat_info->mode, $rcs_file) ||
    return $self->_error("Error setting permissions on %s", $rcs_file);

  return 1;
}


# _checkout()
#
# Arguments: options
# Returns: 1 on success, 0 on error

sub _checkout {
  my $self = shift;
  my $options = shift || {};

  my $working_file = $self->get_working_filename();
  my $rcs_file = $self->_rcs_file();

  my @cmd_args;
  my $binary = $self->{_binaries}->{co};
  push(@cmd_args, $binary);

  # Unlocked checkout
  push(@cmd_args, "-u" . $options->{revision});

  push(@cmd_args, $rcs_file);
  push(@cmd_args, $working_file);

  my $process = Process->new(@cmd_args);

  my $checkout_status = $process->run();

  my $status;

  return $self->_error("Error checking out file %s", $self->{_path})
    unless ($checkout_status == 0);

  # Set file mode
  use File::stat;

  my $stat_info = stat($rcs_file);

  chmod($stat_info->mode, $working_file) ||
    return $self->_error("Error setting permissions on %s", $working_file);

  return 1;
}

# _error()
#
# Arguments: Arguments to printf()
# Returns: 0

sub _error() {
  my $self = shift;
  my $format = shift || return;

  chomp($format);
  $format .= "\n";

  my $message = sprintf($format, @_);

  print STDERR $message;

  return 0;
}


#
# _exists_in_repository()
#
# Arguments: None
# Returns: 1 if file is in repository, 0 otherwise

sub _exists_in_repository {
  my $self = shift;

  -e $self->_rcs_file() || return 0;

  return 1;
}

# _lock()
#
# Arguments: None
# Returns: 1 on success, 0 on error

sub _lock {
  my $self = shift;

  my @cmd_args;
  my $binary = $self->{_binaries}->{rcs};
  push(@cmd_args, $binary);

  push(@cmd_args, "-l");

  push(@cmd_args, $self->_rcs_file());

  my $process = Process->new(@cmd_args);

  my $rcs_status = $process->run();

  my $status;

  if ($rcs_status == 0) {
    # Success
    $status = 1;

  } else {
    $status = 0;
    $self->_error("Error locking file %s", $self->{_path});
  }

  return $status;
}

#
# _make_working_copy()
#
# Arguments: None
# Returns: 1 on success, 0 on error

sub _make_working_copy {
  my $self = shift;

  use File::Basename;
  use File::Spec;

  my $working_filename = File::Spec->catfile(dirname($self->_rcs_file()),
					     basename($self->{_path}));

  my @cmd_args;
  push(@cmd_args, $self->{_binaries}->{cp});
  push(@cmd_args, $self->{_path});
  push(@cmd_args, $working_filename);

  my $process = Process->new(@cmd_args);

  my $status = $process->run();

  return $self->_error("Error copying file")
      unless ($status == 0);

  $self->{_working_filename} = $working_filename;

  return 1;
}


# _rcs_file()
#
# Arguments: None
# Returns: Name of repository rcs file associated with this file object.

sub _rcs_file {
  use File::Spec;

  my $self = shift;

  return File::Spec->catfile($self->{_repository}->get_path(),
			     $self->{_path} . $self->{_rcs_suffix});
}


######################################################################
#
# DebugObject
#
# Virtual object with debug functions.

package DebugObject;

BEGIN {
  my $global_debug = 0;
}

# global_debug()
#
# Arguments: 1 == turn on debugging, 0 == turn off debugging
# Returns: Nothing

sub global_debug {
  my $self = shift;
  my $value = shift;

  defined($value) || ($value = 1);

  $global_debug = $value;
}


# set_debug()
#
# Arguments: Turn on debugging for an object
# Returns: Error string or undef if no error has occurred.

sub set_debug {
  my $self = shift;

  $self->{_debug} = 1;
}

# _debug()
#
# Print a debugging message if we are debugging.
#
# Arguments: Arguments to sprintf
# Returns: Nothing

sub _debug {
  my $self = shift;
  my $format = shift || return;

  return unless ($self->{_debug} || $global_debug);

  chomp($format);

  $format .= "\n";

  my $message = sprintf($format, @_);

  print(STDERR $message);
}

######################################################################
#
# ErrorObject
#
# Virtual object with error functions.

package ErrorObject;

# get_error()
#
# Arguments: None
# Returns: Error string or undef if no error has occurred.

sub get_error {
  my $self = shift;

  return $self->{_error};
}

# _error()
#
# Set an error state.
#
# Arguments: Arguments to sprintf
# Returns: 0 (so can be used like; return $self->error("String");)

sub _error {
  my $self = shift;
  my $format = shift || return;

  $self->{_error} = sprintf($format, @_);

  return 0;
}

######################################################################
#
# OutputObject
#
# Object to handle output to user.

package OutputObject;

use Carp;

# error_message()
#
# Arguments: Arguments to sprintf()
# Returns: Nothing

sub error_message {
  my $self = shift;
  my $format = shift || croak("Missing format");

  # Append \n if misssing
  $format .= "\n" unless $format =~ /\n$/;

  my $message = sprintf($format, @_);

  printf(STDERR $message);
}

# message()
#
# Arguments: Arguments to sprintf()
# Returns: Nothing

sub message {
  my $self = shift;
  my $format = shift || croak("Missing format");

  # Append \n if misssing
  $format .= "\n" unless $format =~ /\n$/;

  my $message = sprintf($format, @_);

  printf(STDOUT $message);
}

# new()
#
# Arguments: None
# Returns: UserInterface object

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};

  bless($self, $class);
  return $self;
}

######################################################################
#
# Process
#
# An object for processes we run.

package Process;

use Carp;

# close()
#
# Close any pipes open the the given process and return it's status.
#
# Arguments: None
# Returns: Exit status

sub close {
  my $self = shift;

  croak("Process not running") unless defined($self->{_fd});

  close($self->{_fd});

  $self->{_exit_code} = $?;

  $self->{_fd} = undef;

  return ($self->{_exit_code} >> 8);
}

# new(args)
#
# Create a new process object. Does not execute process.
#
# Arguments: Arguments as to exec()
# Returns: Process object

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};

  my @args = @_;

  croak("Missing arguments") unless $#args > 0;

  my $ref = \@args;
  $self->{_args} = $ref;

  bless($self, $class);
  return $self;
}

# run
#
# Run the process and return it's status.
#
# Arguments: None
# Returns: Status

sub run {
  my $self = shift;

  my $status = system(@{$self->{_args}});

  $status >>= 8;

  return $status;
}

# run_with_no_output()
#
# Run the process discarding all output.
#
# Arguments: None
# Returns: Status

sub run_with_no_output {
  my $self = shift;

  my $pid = fork();

  defined($pid) or die "fork() failed: $!";

  if (!$pid) {
    # Child
    open(STDOUT, ">/dev/null") or die "Redirect of STDOUT failed: $!";
    open(STDERR, ">/dev/null") or die "Redirect of STDERR failed: $!";

    exec(@{$self->{_args}});

    die "Exec of ${$self->{_args}}[0] failed: $!";
  }

  # Parent
  wait;

  my $status = $? >>= 8;

  return $status;
}

# run_with_output_pipe()
#
# Run the process returning a pipe which will return the output
# (both STDOUT and STDERR) of the proces.
#
# Arguments: None
# Returns: Filehandle reference

sub run_with_output_pipe() {
  my $self = shift;

  local(*FD);
  if (!open(FD, "-|")) {
    open(STDERR, ">&STDOUT") || die "Can't dup stdout: $!";

    exec(@{$self->{_args}});

    die "Can't execute $self->{_args}->[0]: $!";
  }

  $self->{_fd} = *FD{IO};
  return $self->{_fd};
}

#
# End of Code
#
######################################################################

__END__

=head1 admrcs

admrcs - A script for doing system administration version control

=head1 Synopsis

B<admrcs> is a script for doing version control on files commonly
used for system administration. It allows you to put files into
a repository, commit changes to files, views changes and restore
previous versions of files.

=head1 Overview

The first step to using B<admrcs> is to create a repository, for
this exmaple we will call it F</usr/local/admrcs> but it can be
anything you want. Create the repository using the I<init> command:

  $ admrcs -d /usr/local/admrcs init
  Repository /usr/local/admrcs created.

Now you want to set the I<ADMRCSROOT> environment variable to point
at your newly created repository:

  $ setenv ADMRCSROOT /usr/local/admrcs

Now you are ready to import some files into your repository to be
tracked. You do this using the import command:

  $ admrcs import /etc/inetd.conf

At this point you should find yourself in an editor, either B<vi> or
whatever is specified by your I<EDITOR> environment variable. You
should enter a description of the files you are importing. Note that
you must enter some text or the import will be aborted. All lines starting
with I<ADMRCS:> are ignored.

Now you can edit F</etc/inetd.conf> and make any changes you want. At
any point you can use B<admrcs diff> to determine any differences
between your working versoin of F</etc/inetd.conf> and what is in
the repository:

  $ admrcs diff /etc/inetd.conf
  30c30
  <ftp  stream  tcp     nowait  root    /usr/sbin/tcpd /usr/local/sbin/wuftpd-gsi -l
  ---
  >#ftp  stream  tcp     nowait  root    /usr/sbin/tcpd /usr/local/sbin/wuftpd-gsi -l

When you are happy with your changes you can commit them to the repository:

  $ admrcs commit /etc/inetd.conf

Again you will be put into the editor to enter a description of your changes.

At any time you can recall the latest version of a file committed to the
repository using B<admrcs recall>:

  $ admrcs recall /etc/inetd.conf

Or even a previous version using C<-r E<lt>versionE<gt>>:

  $ admrcs recall -r 1.1 /etc/inetd.conf

The B<amdrcs log> command allows you to view all the changes made to a
particular file:

  $ admrcs log /etc/inetd.conf
  RCS file: /usr/local/amdrcs/etc/inetd.conf,v
  Working file: /etc/inetd.conf
  head: 1.2
  branch:
  locks: strict
  access list:
  symbolic names:
  keyword substitution: kv
  total revisions: 1;     selected revisions: 1
  description:
  My system's inetd.conf file.
  ----------------------------
  revision 1.2
  date: 2000/11/04 16:08:47;  author: vwelch;  state: Exp;  lines: +1 -1
  commented out ftp service
  ----------------------------
  revision 1.1
  date: 2000/11/04 02:46:31;  author: vwelch;  state: Exp;
  My system's inetd.conf file
  ======================================================================

=head1 Options

Currently B<admrcs> acceptiosn the following options before the command:

=over 4

=item -d E<lt>admrcs repository pathE<gt>

Specify the repository directory to use. This overrides the I<ADMRCSROOT>
environment variable.

=back

=head1 Commands

B<admrcs> accepts the following commands, which are covered in subsequent
sections: I<commit>, I<diff>, I<history>, I<help>, I<import>, I<log>,
I<init>, I<recall>, I<tag>

=head2 commit [E<lt>optionsE<gt>] E<lt>Files...E<gt>

The I<commit> command commits any changes to the repository.
Your editor (as indicated by the the I<EDITOR> environment variable)
will be run allowing you to enter a message describing your changes.

The I<commit> command currently accepts the following options:

=over 4

=item -m E<lt>messageE<gt>

Specify the message to accompany the commit instead of being prompted
for it via the editor.

=back

=head2 diff [E<lt>optionsE<gt>] E<lt>Files...E<gt>

The I<diff> command displays the differences between the current
version of a file and the latest commited version of file in the
repository.

The I<diff> command takes the following options:

=over 4

=item -c

Display a context diff.

=back

=head2 help

The I<help> command displays some basic help with B<admrcs>.

=head2 history [E<lt>start timeE<gt> [E<lt>end timeE<gt>]]

The history command display the log messages for all changes committed
to the repository for all files. If E<lt>start timeE<gt> is not given
then all enteries back to the begining of time are displayed. If
E<lt>end timeE<gt> is not given, then all message until the current
time are displayed.

The format for times show one of the following:

=over 4

=item C<->

A dash may be used for the E<lt>start timeE<gt> to indicate the begining of
time.

=item C<now>

The string C<now> may be used to indicate the current time.

=item A date and/or time string

A date string should look like C<mm/dd> or C<mm/dd/yyyy>. A time
string must be specified in 24 hour time and should look like C<hh:mm>
or C<hh:mm:ss>. You may have one or the other or both. If no date is
specified the current date is used. If no time is specified, the start
of the specified date is used (12 midnight).

Some examples of legal dates are: "C<4/1/2000>", "C<7/4>", "C<6/5
14:23>", "C<1:34>"

=back

=head2 import [E<lt>optionsE<gt>] E<lt>Files...E<gt>

The I<import> command imports new files into the repository.
Your editor (as indicated by the the I<EDITOR> environment variable)
will be run allowing you to enter a message describing the files.

The I<import> command currently accepts the following options:

=over 4

=item -m E<lt>messageE<gt>

Specify the description to accompany the files instead of being prompted
for it via the editor.

=back

=head2 init

The I<init> command initializes a new admrcs repository. It should be used
once per repository. Using the init command on an existing repository
results in an error.

=head2 log E<lt>Files...E<gt>

The I<log> command displays the commit log for the specified files.

=head2 recall [E<lt>optionsE<gt>] E<lt>Files...E<gt>

The I<recall> command allows you do recall files out of the repository.
The files being recalled will not be overwritten can cannot exist.

The I<recall> command accepts the following options:

=over 4

=item -r E<lt>versionE<gt>

Specify a specific version of the file to recall. E<lt>versionE<gt> can
be a numeric version, e.g. C<1.2>, or a symbolic tag as assigned by
the I<tag> command.

=back

=head2 tag [E<lt>optionsE<gt>] E<lt>Files...E<gt>

The I<tag> command allows to assign a symbolic tag to files in the
repository.  You can use to to tie a group of files together that have
potentially different version numbers and then referr to them using
the tag.

The I<tag> command accepts the following options:

=over 4

=item -f

Normally if you try to assign a symbolic tag to a file that already has
the tag assigned, you will get an error. Using the C<-f> option overrides
this behvior and will forcably move the symbolic tag on the file.

=item -r E<lt>versionE<gt>

Specify a specifyc version of the file to tag. Normally the latest
commited version is taged. E<lt>versionE<gt> can be a numeric version,
e.g. C<1.2>, or a symbolic tag as assigned by a previous I<tag> command.

=back

=head1 Environment

The following environment variables are recognized by B<admrcs>:

=over 4

=item ADMRCSROOT

This variable specifie the path to the repository to use. It can
be overriden using the C<-d> command line option.

=item EDITOR

This variable specifies the editor to use for entering I<commit> and
I<import> messages. If not set, C<vi> is used by default.

=back

=head1 Diagnostics

B<admrcs> returns 0 on success, 1 on error. The exception to this is
the I<diff> command which returns 2 on error, 1 if differences were
found, and 0 otherwise.

=head1 Author

Von Welch E<lt>vwelch@vwelch.comE<gt>

B<admrcs> is free software, you may do with it what you please as
long as you give me some credit :-)

=head1 ToDo

=over 4

=item *

Allow specifying one or two versions with the diff command. Need to
figure out how to allow user to specifiy two versions since getopts()
doesn't allow one to have two -r options.

=item *

Allow looking for changes by a specific user with history and log commands.

=item *

Allow specifying date range with log command.

=item *

Allow specifying version range with log command.

=item *

Allow specifying target filename with recall command.

=item *

Allow specifying a date to recall and diff.

=item *

Allow making just a log entery without change to files.

=back
