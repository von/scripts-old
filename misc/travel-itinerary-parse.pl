#!/usr/bin/perl -w
######################################################################
#
#
# travel-itinerary-parse
#
# Parse a travel itinerary and spit out readable form.
#
######################################################################

use Carp;
use Time::Local;
use POSIX qw(strftime);

######################################################################

$State = undef;

$Event = undef;

@Events = ();

######################################################################
#
# State Definitions
#

$State{"Default"} =
  {
   parse_funcs    => [
		      \&parse_date,
		      \&air_event_start,
		      \&car_event_start,
		      \&hotel_event_start,
		     ],
  };

$State{"AirEvent"} =
  {
   parse_funcs   => [
		     \&parse_date,
		     \&air_event_start,
		     \&parse_from,
		     \&parse_to,
		     \&parse_departs,
		     ],
   exit_funcs    => [
		     \&event_push
		     ],
};

$State{"CarEvent"} =
  {
   parse_funcs   => [
		     \&parse_date,
		     \&parse_car_co,
		     \&parse_drop_off,
		     \&parse_confirmation_no,
		     \&parse_rate,
		     ],
   exit_funcs    => [
		     \&event_push
		     ],
};

$State{"HotelEvent"} =
  {
   parse_funcs   => [
		     \&parse_date,
		     \&parse_confirmation_no,
		     \&parse_address,
		     \&parse_rate,
		     \&parse_check_out,
		     ],
   exit_funcs    => [
		     \&event_push
		     ],
};

######################################################################
#
# Output modes
#

$Output_modes{full} =
{
 Air => \&print_air_event,
 Car => \&print_car_event,
 Hotel => \&print_hotel_event,
};

######################################################################
#
# Initialize
#

change_state("Default");

$Output_mode = "full";

######################################################################
#
# Parsing engine
#

line: while(<>) {
  my $funcs = $State{$State}{parse_funcs};

  foreach my $func (@$funcs) {
    if (&$func()) {
      next line;
    }
  }
}

# Change state to default to close out anything pending with current state
change_state("Default");

######################################################################
#
# Dump events
#


foreach $event (@Events) {
  my $func = $Output_modes{$Output_mode}->{$event->{type}};

  if (defined($func)) {

    printf("%s: %s\n",
	   $event->{type},
	   date_to_string($event->{date}));

    &$func($event);
    printf("\n");
  }
}

######################################################################

exit(0);

#
# End of main code
#
######################################################################

######################################################################
######################################################################
#
# Functions
#

######################################################################
#
# change_state(new_state)
#
# Inputs:
#    new_state - state we are entering.
# Outputs:
#    None

sub change_state {
  my $new_state = shift ||
    croak "Missing argument";

  if (!defined($State{$new_state})) {
    croak "Unknown state \"$new_state\"";
  }

  debug("Changing state to $new_state");

  # Call exit functions for current state
  if (defined($State)) {
    my $exit_funcs = $State{$State}{"exit_funcs"};

    if (defined($exit_funcs)) {
      foreach my $func (@$exit_funcs) {
	&$func();
      }
    }
  }

  # Enter new state and call enter functions
  $State = $new_state;

  my $enter_funcs = $State{$State}{"enter_funcs"};

  if (defined($enter_funcs)) {
    foreach my $func (@$enter_funcs) {
      &$func();
    }
  }
}

######################################################################
#
# debug
#
# Print a debug message.
#
# Inputs:
#    message - message to print
# Outputs:
#    None

sub debug {
  return 0;
  my $message = shift || "Blank debug message";

  # XXX logic here
  chomp($message);

  print $message . "\n";
}

######################################################################
#
# Parsing functions
#

sub skip_blank_lines {
  if (/^\s*$/) {
    return 1;
  }

  return 0;
}

sub parse_date {
  if (/^\s*(\d\d)\s*(\S\S\S)\s*(\d\d)/) {

    $Date = date_parse();

    debug("New date is $Date");

    change_state("Default");

    return 1;
  }

  return 0;
}

sub air_event_start {
  if (/^\s*Air\s+/i) {
    change_state("AirEvent");

    new_event();

    $Event->{type} = "Air";

    if (/(American Airlines|United Airlines)/i) {
      $Event->{carrier} = $1;
    }

    if ((/Flight\#\s*(\d+)/) ||
        (/FLT:(\d+)/)) {
      $Event->{flight} = $1;
    }

    return 1;
  }

  return 0;
}

sub car_event_start {
  if (/^Car/) {
    change_state("CarEvent");

    new_event();

    $Event->{type} = "Car";

    if (/Pick Up City: (.*)/) {
      $Event->{city} = strip_whitespace($1);
    }

    return 1;
  }

  return 0;
}

sub hotel_event_start {
  if (/^Hotel/) {
    change_state("HotelEvent");

    new_event();

    $Event->{type} = "Hotel";

    if (/^Hotel\s+(.*)Phone:(.*)/) {
      $Event->{name} = strip_whitespace($1);
      $Event->{phone} = $2;
    }

    return 1;
  }

  return 0;
}

sub parse_from {
  if (/(From:|LV)\s*([^\d]*)/) {
    $Event->{from} = strip_whitespace($2);
    my $time = time_parse();
    $Event->{time} = $time if defined($time);
    return 1;
  }

  return 0;
}

sub parse_to {
  if (/(To:|AR )\s*([^\d]*)/) {
    $Event->{to} = strip_whitespace($2);

    $Event->{eta} = time_parse();

    return 1;
  }

  return 0;
}

sub parse_departs {
  if (/(DEPARTS|DEPART:).*(TERMINAL \d+)/) {
    $Event->{departs} = strip_whitespace($2);
    return 1;
  }

  return 0;
}

sub parse_car_co {
  if (/(National Car Rental)/) {
    $Event->{company} = $1;
  }
  return 0;
}

sub parse_drop_off {
  if (/Drop Off:/) {
    $Event->{drop_off} = date_parse();
  }
  return 0;
}

sub parse_confirmation_no {
  if (/Confirmation\#:\s*(\d+)/) {
    $Event->{confirm_no} = $1;
  }
  return 0;
}

sub parse_address {
  if (/\s+(.*)\s+,\s+Fax:(.*)/) {
    $Event->{address} = strip_whitespace($1);
    $Event->{fax} = $2;
  }
  return 0;
}

sub parse_rate {
  if (/Rate: (\d+.\d\d)USD/) {
    $Event->{rate} = $1;
  }
  return 0;
}

sub parse_check_out {
  if (/Check Out:/) {
    $Event->{check_out} = date_parse();
  }

  return 0;
}

sub event_push {
  push(@Events, $Event);
}

######################################################################
#
# Print Events
#

sub print_air_event {
  my $event = shift;

  printf("%s (Flight# %d) %s
From: %s %s
Arriving %s at %s
",
	 (defined($event->{carrier}) ?
	  $event->{carrier} : "Unknown"),
	 (defined($event->{flight}) ?
	  $event->{flight} : "Unknown"),
	 time_to_string($event->{time}),
	 (defined($event->{from}) ?
	  $event->{from}: "Unknown"),
	 (defined($event->{departs}) ?
	  sprintf("(Departs %s)", $event->{departs}) :
	  ""),
	 (defined($event->{to}) ?
	  $event->{to} : "Unknown"),
	 time_to_string($event->{eta}));
}

sub print_car_event {
  my $event = shift;

  printf("%s (Confirmation# %d)
City: %s
Rate: \$%.2f Drop off: %s
",
	 $event->{company},
	 $event->{confirm_no},
	 $event->{city},
	 $event->{rate},
	 date_to_string($event->{drop_off}));
}

sub print_hotel_event {
  my $event = shift;

  printf("%s (Phone: %s)
%s
Rate: \$%.2f Confirmatoin# %d
Check out: %s
",
	 $event->{name},
	 $event->{phone},
	 $event->{address},
	 $event->{rate},
	 $event->{confirm_no},
	 date_to_string($event->{check_out}));
}

######################################################################
#
# Supporting functions
#

sub date_parse {
  my $months = {
		"Jan"         => 0,
		"Feb"         => 1,
		"Mar"         => 2,
		"Apr"         => 3,
		"May"         => 4,
		"Jun"         => 5,
		"Jul"         => 6,
		"Aug"         => 7,
		"Sep"         => 8,
		"Oct"         => 9,
		"Nov"         => 10,
		"Dec"         => 11,
		};

  # Set defaults
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = gmtime();

  # Zero everything, but save the year
  $mday = 0;
  $mon = 0;
  $sec = 0;
  $min = 0;
  $hours = 0;

  # 01Aug02
  if (/(\d\d)\s*(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dev)\s*(\d\d)?/i)
  {
    $mday = $1;
    $mon = $months->{ucfirst(lc($2))};
    if (defined($3)) {
      $year = 2000 + $3;
    }
  } else {
    return 0;
  }

  my $date = timegm($sec, $min, $hours, $mday, $mon, $year);

  return $date;
}

sub time_parse {
  my $sec = 0;
  my $min = 0;
  my $hours = 0;

  # Time
  if (/(\d\d):(\d\d)(\S\S)/ ||
      /(\d\d)(\d\d)(\S)/ ||
      /\s(\d)(\d\d)(\S)/) {
    $hours = $1;
    $min = $2;
    my $ampm = $3;

    # Convert to 24 hour time
    if (($ampm eq "pm") ||
	($ampm eq "P")) {
      if ($hours != 12) {
	$hours += 12;
      }
    } elsif (($ampm eq "am") ||
	     ($ampm eq "A")) {
      if ($hours == 12) {
	$hours = 0;
      }
    } elsif ($ampm eq "N") {
      # Noon, hours are fine
    } else {
      # No indication given...
    }
  }

  my $time = ((($hours * 60) + $min) * 60) + $sec;

  return $time;
}

sub strip_whitespace {
  my $string = shift;

  $string =~ s/^\s+//;
  $string =~ s/\s+$//;

  return $string;
}

sub timedate_to_string {
  my $timestamp = shift;

  return "Undefined date and time" if !defined($timestamp);

  return "" . gmtime($timestamp);
}

sub date_to_string {
  my $timestamp = shift;

  return "Undefined date" if !defined($timestamp);

  return strftime("%a %b %d %Y", gmtime($timestamp));
}

sub time_to_string {
  my $timestamp = shift;

  return "Undefined time" if !defined($timestamp);

  return strftime("%I:%M %p", gmtime($timestamp));
}

sub new_event {
  $Event = {date => $Date};

  return $Event;
}
