#!/usr/local/bin/perl
######################################################################
#
# myfetchmail
#
# Run fetchmail for each mail server and report results.
#
######################################################################

######################################################################
#
# vt100 escape codes
#

$VT100_cursor_home = "\033[H";
$VT100_clear_screen = "\033[2J";

######################################################################
#
# Mail servers and how frequently (in minutes) they should
# be checked.
# XXX This should eventually be in a configuration file.
#

my %Servers = (
	       "ncsa" =>       {
				"pop_host"         => "pop.ncsa.uiuc.edu",
				"interval"         => 0,
				"krb5_cache"       => "/tmp/krb5cc_9887",
			       },
	       "mallorn" =>    {
				"pop_host"         => "pop.mallorn.com",
				"interval"         => 0,
				"krb5_cache"       => "/tmp/krb5cc_vwelch_mallorn",
			       },
	       "mcs" =>        {
				"pop_host"         => "imap.mcs.anl.gov",
				"interval"         => 0,
				},
	      );

my %Configurations = (
		      "work" => {
				 "servers"         => [
						       "mcs",
						      ],
				},
		      "personal" => {
				     "servers"     => [ "mallorn" ],
				    },
		      "all" => {
				"servers"          => [
							"mcs",
							"mallorn"
						      ],
			       },
		     );

######################################################################
#
# Strings for fetchmail return codes
#

my @Fetchmail_RC_Strings = (
			    'Success',
			    'No email',
			    'Error opening socket',
			    'Authentication failed',
			    'Protocol error',
			    'Syntax error in arguments',
			    'Bad permission on run control file',
			    'Server error',
			    'Client exclusion error: fetchmail already running?',
			    'Lock busy',
			    'SMTP port open or transaction failed',
			    'Internal error',
			   );

######################################################################
#
# Global variables
#

%Folder_Hash = ();
%Folder_Count = ();

$Lock_Filename = undef;

######################################################################
#
# Set up signals
#

$SIG{QUIT} = \&handle_sig_quit;
$SIG{INT} = \&handle_sig_int;

######################################################################
#
# Parse commandline arguments
#

use Getopt::Std;

# Defaults
my %Options = (
	       # Configuration
	       "c"       => "all",
	       # Deaemon mode, how often to run?
	       "d"       => undef,
	       # Force check even if interval has not expired
	       "f"       => 0,
	       # Flush
	       "F"       => 0,
	       # Quiet
	       "q"       => 0,
	      );

getopts('c:d:fFq', \%Options);

my $configuration = $Configurations{$Options{c}};

defined($configuration) ||
  die "Unknown configuration \"$Options{c}\"";

my $servers = $configuration->{"servers"};

######################################################################

my $ask_for_keypress = 0;

check: do {

  clear_screen() if $Options{d};

  get_lock();

  # Remove previous log file
  $procmail_log = $ENV{HOME} . "/Mail/procmail.log";
  unlink($procmail_log);

  foreach $mail_server (@$servers) {
    do_server($mail_server) || ($ask_for_keypress = 1);
  }

  if (-e $procmail_log) {
    parse_procmail_log($procmail_log);
    $ask_for_keypress = 1;
  } else {
    print "No mail.\n";
  }

  print "\n";
  display_mail_stats();

  release_lock();

  sleep($Options{d}) if $Options{d};

} while ($Options{d});

# If we want to ask for a keypress return non-zero and mutt
# will ask for a keypress.
exit($ask_for_keypress);

######################################################################

sub do_server {
  my $server_name = shift;

  my $server = $Servers{$server_name};

  my $pop_host = $server->{pop_host};

  my $check_time = $server->{interval};

  $Options{q} or print("Checking $pop_host...\n");

  my $tag_file = "/tmp/myfetchmail-" . $pop_host . "-" . $<;

  $Options{F} || check_file_age($tag_file, $check_time) || return 1;

  my @cmd_args;

  push(@cmd_args, "fetchmail");

  # Flush?
  push(@cmd_args, "-F") if $Options{F};

  # If we're running as a daemon, run silently
  push(@cmd_args, "-s") if $Options{d};

  push(@cmd_args, $pop_host);

  my $attempts = 0;
  my $return_code = 0;

  # Use specified kerberos credentials
  $ENV{KRB5CCNAME} = $server->{krb5_cache} if exists($server->{krb5_cache});

 attempt: while ($attempts < 3) {
    my $rc = system(@cmd_args) >> 8;

    if ($rc == 0) {
      # Successfull email download
      $return_code = 1;
      touch($tag_file);
      last attempt;

    } elsif ($rc == 1) {
      # No email to download
      $return_code = 1;
      touch($tag_file);
      last attempt;

    } elsif ($rc == 8) {
      # Another fetchmail running, wait and try again
      print "Another fetchmail running. Waiting...\n";
      sleep(5);
      next attempt;

    } elsif ($rc == 9) {
      # Server responded lock busy, wait and try again
      print "Server respoded with busy lockfile. Waiting...\n";
      sleep(5);
      next attempt;

    } else {
      # Some other error
      print $Fetchmail_RC_Strings[$rc] . "\n";
      last attempt;
    }
  } continue {

    $attempts++;
  }

  return $return_code;

}
######################################################################

sub check_file_age {
  my $filename = shift;
  my $check_age = shift;  # In minutes

  # Always check if check age is undefined or zero
  defined($check_age) || return(1);
  ($check_age == 0) && return(1);

  # If the file doesn't exist, always exit
  -e $filename || return(1);

  my $file_age = time() - (stat(_))[9];   # In seconds

  return ($file_age > $check_age * 60);
}

sub touch {
  my $filename = shift;

  system("touch $filename");
}

######################################################################

sub parse_procmail_log {
  my $log_file = shift;

  # The format of the procmail log file seems to be three lines per
  # message:
  # From <from> <date in human readable format>
  #  Subject: <subject>
  #   Folder: <folder>                     <size in bytes>

  if (!open(LOG_FILE, "<$log_file")) {
    print STDERR "Could not open procmail log ($log_file) for reading: $!\n";
    return;
  }

  my $message = undef;

 line: while (<LOG_FILE>) {
    # procmail errors
    /^procmail:/ && print(STDERR $_) && next line;

    if (/^\s*From\s+(\S+)\s+(.*)$/)
    {
      # Start of a new message
      $message = {
		  "from"  => $1,
		  "date"  => $2
		 };

      next line;
    }
    elsif (/^\s*Subject: (.*)/)
    {
      my $subject = $1;

      # Remove response prefix from subjects
      $subject =~ s/R[eE]:\s*//;

      # Remove any preceding or trailing whitespace from subject
      $subject =~ s/^\s*//g;
      $subject =~ s/\s*$//g;

      # Replace a blank subject with "No Subject"
      ($subject =~ /^\s*$/) && ($subject = "No Subject");

      $message->{subject} = $subject;
      next line;
    }
    elsif (/^\s*Folder: (.+)\s+(\d+)\s*$/)
    {
      my $folder = $1;
      my $size = $2;

      # Remove trailing whitespace from folder
      $folder =~ s/\s*$//;

      # Got ahead and process this message
      my $subject = $message->{subject} || "No subject";
	
      my $subject_hash_ref =
	defined($Folder_Hash{$folder}) ?
	  $Folder_Hash{$folder} :
	    ($Folder_Hash{$folder} = {});

      $$subject_hash_ref{$subject}++;
      $Folder_Count{$folder}++;

      $message->{folder} = $folder;
      $message->{size} = $size;
      next line;
    }

    print STDERR "Failed to parse line $. of procmail log\n\t$_";
    next line;
  }

  close(LOG_FILE);
}

sub display_mail_stats {
  foreach my $folder (keys %Folder_Hash) {
    printf(" %4d %s:\n", $Folder_Count{$folder}, $folder);

    my $subject_hash_ref = $Folder_Hash{$folder};

    foreach my $subject (keys %$subject_hash_ref) {
      printf("   %4d %s\n", $$subject_hash_ref{$subject}, $subject);
    }
  }
}

sub clear_email_stats {
  %Folder_Hash = ();
  %Folder_Count = ();
}

######################################################################
#
# Signal handlers
#

sub handle_sig_quit {
  clear_email_stats();
  clear_screen();
}

sub handle_sig_int {
  release_lock();
  exit(0);
}

######################################################################
#
# Output manipulation functions
#

sub clear_screen {
  print $VT100_clear_screen;
  print $VT100_cursor_home;
}

######################################################################
#
# Lock file routines
#

sub get_lock {

  use IO::File;

  $Lock_Filename = "/tmp/myfetchmail-lock-" . $<;

  while ( -f $Lock_Filename) {
    print "Waiting on lock file $Lock_Filename...\n";
    sleep(5);
  }

  my $lock_file = IO::File->new($Lock_Filename, O_CREAT|O_EXCL, 0700);

  defined($lock_file) || die "Could not create lock file $Lock_Filename: $!";

  # Force close
  undef($lock_file);
}

sub release_lock {
  defined($Lock_Filename) || return;

  unlink($Lock_Filename) ||
    die "Could not unlink lock file $Lock_Filename: $!";

  $Lock_Filename = undef;
}

