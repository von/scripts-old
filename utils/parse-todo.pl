#!/usr/local/bin/perl
######################################################################
#
# todo-parse.pl
#
# Parse a email todo file and print to stdout.
#
######################################################################

$source = $ENV{"HOME"} . "/.todo-do";

######################################################################

open(TODO_FILE, "<$source") ||
  die "Could not open $source for reading: $!";

$category = undef;
$item = undef;
@items = ();

line: while(<TODO_FILE>) {
  if (/^-\*- mode:/) {
    # Opening mode line, ignore
    next line;
  }

  if (/^\*\/\* ---------------------------------------------------------------------------/) {
    # Category seperator, ignore
    next line;
  }

  if (/^\*\/\* --- (.*)/) {
    # New category
    $category = $1;
    next line;
  }

  if (/^\*\/\* (\d\d\d\d-\d\d-\d\d \d\d:\d\d) (\w+): (.*)/) {
    # New item
    push(@items, $item) if defined($item);
    $item = {};
    $item->{category} = $category;
    $item->{date} = $1;
    $item->{user} = $2;
    $item->{title} = $3;
    next line;
  }

  if (/--- End/) {
    # End of category
    push(@items, $item) if defined($item);
    $item = undef;
    next line;
  }

  # Else continuation of current item
  if (!defined($item)) {
    die "Parse error at line $.";
  }

  $item->{data} .= $_;
}

while (defined($item = shift(@items))) {
  printf("%-15s %s\n", $item->{category}, $item->{title});
}
