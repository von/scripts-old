#!/usr/local/bin/perl
######################################################################
#
# substitue_cipher
#
# Program to help with breaking substitute ciphers.
#
######################################################################

my $Prompt = ">";

######################################################################

my %Command = (
	       "add"             => \&command_add,
	       "count"           => \&command_count,
	       "exit"            => \&command_exit,
	       "print"           => \&command_print,
	       "quit"            => \&command_exit,
	       "sub"             => \&command_sub,
	       "subs"            => \&command_subs,
	       "unsub"           => \&command_unsub,
	      );

######################################################################
#
# Initialize state
#

my $CipherText = undef;

my %Substitutions = ();

init_substitutions();

my $file = shift;

defined($file) && read_file($file);

######################################################################
#
# Main Loop
#

command: while (1) {
  print $Prompt;
  
  my $command_string = <STDIN>;

  defined($command_string) || exit(0);

  chomp($command_string);

  my @args = split(' ', $command_string);

  my $command = $args[0];
  my $command_function = $Command{$command};

  if (!defined($command_function)) {
    print STDERR "Unknown command \"$command\"\n";
    next command;
  }

  # Remove command from string
  $command_string =~ s/^\s*$command\s+//;

  &$command_function($command, $command_string);

}

# Not reached
exit(0);

######################################################################
#
# Misc functions
#

sub init_substitutions {
  foreach my $letter ('a'..'z') {
    $Substitutions{$letter} = "?";
  }
}

sub read_file {
  my $file = shift;

  print "Reading $file...\n";

  if (!open(FILE, "<$file")) {
    print STDERR "Could not open $file for reading: $!\n";
    return;
  }

  while(<FILE>) {
    $CipherText .= $_;
  }

  close(FILE);
}
    

sub substitute {
  my $text = shift;
  my $sub_text = undef;

  my @chars = split(//, $text);

  foreach my $char (@chars) {
    my $sub = $Substitutions{lc($char)};

    $sub_text .= defined($sub) ? $sub : $char;
  }

  return $sub_text;
}

######################################################################
#
# Command functions
#

sub command_add {
  my $command = shift;
  
  $CipherText .= shift;
}

sub command_count {
  my @chars = split(//, $CipherText);

  my %count;

 char: foreach my $char (@chars) {
    $char = lc($char);

    next char unless $char =~ /[a-z]/;

    $count{$char}++;
  }

  @chars = sort {$count{$b} <=> $count{$a}} keys(%count);

  my $count = 0;

  foreach my $char (@chars) {
    printf("%s => %3d", $char, $count{$char});

    $count++;

    if ($count == 4) {
      print "\n";
      $count = 0;

    } else {
      print "\t";
    }
  }

  print "\n" unless $count == 0;
}


sub command_exit {
  my @args = @_;

  print "Bye\n";
  exit(0);
}

sub command_print {
  my @lines = split(/\n/, $CipherText);

  foreach my $line (@lines) {
    print $line . "\n";
    print substitute($line) . "\n";
    print "\n";
  }
}

sub command_sub {
  my $command = shift;
  my $arg_string = shift;

  my @args = split(' ', $arg_string);

  my @orig_chars = split(//, shift(@args));
  my @sub_chars = split(//, shift(@args));

  if (scalar(@orig_chars) != scalar(@sub_chars)) {
    print "Length mismatch\n";
    return;
  }

 char: foreach my $orig_char (@orig_chars) {
    $sub_char = shift(@sub_chars);

    if (!defined($Substitutions{$orig_char})) {
      print "Unnown character \"$orig_char\"\n";
      return;
    }

    $Substitutions{$orig_char} = $sub_char;
  }
}

sub command_subs {
  my $count = 0;

  foreach my $letter ('a'..'z') {
    print $letter . " => " . $Substitutions{$letter};

    $count++;

    if ($count == 8)  {
      print "\n";
      $count = 0;

    } else {
      print "\t";
    }
  }

  ($count == 0) || print "\n";
}

sub command_unsub {
  my $command = shift;
  my $letters = shift;

  if ($letters eq "*") {
    init_substitutions();

  } else {
    my @letters = split(//, $letters);

  letter: foreach my $letter (@letters) {
      if (!defined($Substitutions{$letter})) {
	print "Unknown character \"$letter\"\n";
	next letter;
      }

      $Substitutions{$letter} = "?";
    }
  }
}
