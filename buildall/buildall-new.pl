#!/usr/local/bin/perl -w

parse_configuration_file(shift, \%conf);

dump_configuration(\%conf);

######################################################################
######################################################################
#
# Configuration file parsing routines
#

######################################################################
#
# parse_configuration_file
#
# Arguments: Filename, Reference to hash
# Returns: 1 on success, 0 on error

sub parse_configuration_file {
  my %parsing_functions = (
			   MainBody     => [
					    \&parse_comments,
					    \&parse_escaped_crs,
					    \&parse_architecture_start,
					    \&parse_variable,
					    \&parse_rule_start,
					    \&parse_ignore_blank_line,
					   ],
			   Architecture => [
					    \&parse_comments,
					    \&parse_escaped_crs,
					    \&parse_variable,
					    \&parse_architecture_start,
					    \&parse_architecture_end,
					    \&parse_rule_start,
					    \&parse_ignore_blank_line,
					   ],
			   SkipRule     => [
					    \&parse_comments,
					    \&parse_escaped_crs,
					    \&parse_rule_end,
					    \&parse_ignore_line,
					   ],
			   Rule         => [
					    \&parse_comments,
					    \&parse_escaped_crs,
					    \&parse_rule_end,
					    \&parse_rule_line,
					   ],
			  );

  

  my $state = {
	       # May be any of the keys of %parsing_functions above
	       parsing        => "MainBody",
	      };

  # Check and check arguments
  $state->{filename} = shift;
  $state->{configuration_ref} = shift;
  defined($state->{filename}) || die "Filename undefined";
  defined($state->{configuration_ref}) || die "Configuration hash undefined";
  ref($state->{configuration_ref}) eq "HASH" || die "Not a hash reference";

  if ($state->{filename} eq "-") {
    # A filename of "-" means to use STDIN
    $state->{descriptor_ref} = \*STDIN;
    $state->{filename} = "STDIN";

  } else {
    # Open the file given by the user
    local(*FILE);

    if (!open(FILE, "<$state->{filename}")) {
      print STDERR "Could not open $state->{filename} for reading: $!";
      return 0;
    }

    $state->{descriptor_ref} = *FILE;
  }

  my $descriptor_ref = $state->{descriptor_ref};

 line: while(<$descriptor_ref>) {
    my $matched = 0;

    $state->{current_line} = $_;
    $state->{current_line_number} = $.;

    # Remember if the line was blank to start with. It might become
    # blank later after removing comments and the like
    $state->{nonblank} = (/^\s*$/ ? 0 : 1);

    exists($parsing_functions{$state->{parsing}}) ||
      die "Bad state: $state->{parsing}";

    my $functions = $parsing_functions{$state->{parsing}};

  function: foreach my $function (@$functions) {
      if (&$function($state) == 1) {
	$matched = 1;
	last function;
      }
    }

    if (!$matched) {
      parse_error($state, "could not parse line");
    }
  }

  close($state->{descriptor_ref});
}

######################################################################
#
# parse_error
#
# Display a parsing error to the user.
#
# Arguments: Reference to state, Format, [format arguments]
# Returns: Nothing

sub parse_error {
  my $state = shift;
  (ref($state) eq "HASH") || die "Bad state reference";
  
  my $format = shift;
  defined($format) || die "format undefined";

  chomp($format);
  $format = "PARSE ERROR: $format";
  $format .= " at $state->{filename} line $state->{current_line_number}\n";

  my $string = sprintf($format, @_);

  print STDERR $string;
}
    


######################################################################
#
# dump_configuration
#
# Arguments: Configuration refererence, [descriptor reference]
# Returns: Nothing

sub dump_configuration {
  # Get and check arguments
  my $configuration_ref = shift;
  my $descriptor_ref = shift || \*STDOUT;

  defined($configuration_ref) || die "Configuration reference undefined";
  ref($configuration_ref) eq "HASH" || die "Bad configuration reference";

  my $old_descriptor = select $descriptor_ref;

  my $variables_ref = $configuration_ref->{variables};
  my @variables = keys(%$variables_ref);
  foreach my $variable (@variables) {
    print $variable . "=" . $variables_ref->{$variable} . "\n";
  }

  my $rules_ref = $configuration_ref->{rules};
  my @rules = keys(%$rules_ref);
  foreach my $rule (@rules) {
    my $rule_ref = $rules_ref->{$rule};
    my $dependencies_ref = $rule_ref->{dependencies};
    print $rule . ": " . join(' ', @$dependencies_ref) . "\n";
    print $rule_ref->{command} if defined($rule_ref->{command});
    print "\n";
  }

  my $arch_refs = $configuration_ref->{architectures};
  if (defined($arch_refs)) {
  arch: foreach my $arch (keys(%$arch_refs)) {
      my $arch_ref = $arch_refs->{$arch};

      print "\n$arch:\n";

      dump_configuration($arch_ref);
    }
  }

  select($old_descriptor);
}
  
######################################################################
#
# Parsing routines
#
# Each of these routines gets passes the current state which it
# may modify. It then returns 1 if parsing is complete or 0 if
# it should continue.


#
# Remove any comments

sub parse_comments {
  my $state = shift;

  $state->{current_line} =~ s/#.*$//;

  return 0;
}

#
# Deal with backslash-escaped carriage returns

sub parse_escaped_crs {
  my $state = shift;

  while ($state->{current_line} =~ /\\$/) {
    # Remove backslash and any whitespace and replace with a single space
    $state->{current_line} =~ s/\s*\\$/ /;
    chomp($state->{current_line});
    my $descriptor_ref = $state->{descriptor_ref};

    # Get the next line and remove any preceding whitespace
    # XXX
    $state->{current_line} .= <$descriptor_ref>;
  }

  return 0;
}

#
# Handle setting of variables

sub parse_variable {
  my $state = shift;

  ($state->{current_line} =~ /^\s*(\w+)\s*=\s*(.*)$/) || return 0;

  my $variable = $1;
  my $value = $2;

  my $variables_ref;

  if ($state->{parsing} eq "MainBody") {
    $variables_ref = 
      $state->{configuration_ref}->{variables} ||
	($state->{configuration_ref}->{variables} = {});

  } elsif ($state->{parsing} eq "Architecture") {
    $variables_ref = 
      $state->{architecture_ref}->{variables} ||
	($state->{architecture_ref}->{variables} = {});

  } else {
    die "Bad state: $state->{parsing}";
  }

  $variables_ref->{$variable} = $value;

  return 1;
}

#
# Handle rules

sub parse_rule_start {
  my $state = shift;

  ($state->{current_line} =~ /^\s*(\w+)(::?)\s*(.*)$/) || return 0;

  my $rule = $1;
  my $colons = $2;
  my @dependencies = split(' ', $3);

  # Can have architecture-specific rules yet
  if ($state->{parsing} eq "Architecture") {
    parse_error($state, "Architecture-specific rules not allowed");
    $state->{parsing} = "SkipRule";
    return 1;
  }

  my $rules_ref =
    $state->{configuration_ref}->{rules} ||
      ($state->{configuration_ref}->{rules} = {});
  my $rule_ref;
 

  if ($colons eq ":") {
    # Single colon means to set the rule

    # Make sure rule wasn't already set
    if (defined($rules_ref->{$rule})) {
      parse_error($state, "Rule \"%s\" already defined", $rule);
      $state->{parsing} = "SkipRule";
      return 1;
    }

    $rule_ref = $rules_ref->{$rule} = {};
    $rule_ref->{command} = undef;
    $rule_ref->{dependencies} = \@dependencies;

  } else {
    # Double colon means to append to existing rule
    $rule_ref = $rules_ref->{$rule} || ($rules_ref->{$rule} = {});
    $rule_ref->{dependencies} = [@$rule_ref->{dependencies},
				 @dependencies];
  }

  $state->{parsing} = "Rule";
  $state->{rule_ref} = $rule_ref;

  return 1;
}

sub parse_rule_line {
  my $state = shift;

  my $rule_ref = $state->{rule_ref};

  # Remove preceding whitespace
  $state->{current_line} =~ s/^\s*//;

  $rule_ref->{command} .= $state->{current_line};

  return 1;
}

sub parse_rule_end {
  my $state = shift;

  ($state->{current_line} =~ /^\s*$/) || return 0;

  $state->{parsing} = "MainBody";

  return 1;
}

#
# Handle architecture-specific code

sub parse_architecture_start {
  my $state = shift;

  ($state->{current_line} =~ /^(\w+)\s*=\s*\{\s*$/) || return 0;

  if ($state->{parsing} ne "MainBody") {
    parse_error($state,
		"Architecture-specify blocks only allowed in main body");
    return 1;
  }

  my $architecture = $1;

  my $arch_refs =
    $state->{configuration_ref}->{architectures} ||
      ($state->{configuration_ref}->{architectures} = {});

  my $arch_ref =
    $arch_refs->{$architecture} || ($arch_refs->{$architecture} = {});

  $state->{parsing} = "Architecture";
  $state->{architecture_ref} = $arch_ref;

  return 1;
}

sub parse_architecture_end {
  my $state = shift;

  ($state->{current_line} =~ /^\s*\}\s*$/) || return 0;

  if ($state->{parsing} eq "Architecture") {
    $state->{parsing} = "MainBody";

  } else {
    parse_error($state, "unmatched closing bracket");
  }

  return 1;
}


# Ignore blank lines in main body

sub parse_ignore_blank_line {
  my $state = shift;

  ($state->{current_line} =~ /^\s*$/) && return 1;

  return 0;
}

# Ignore all lines (for skipping over stuff)

sub parse_ignore_line {
  my $state = shift;

  return 1;
}

