#!/usr/bin/perl
######################################################################
#
# eudora_alias_parse
#
# Parse eudora aliases and produce unix versions
#
######################################################################

while(<>) {
  if (/^alias (\S+) (.*) <?([^>]+)>?/) {
    my $alias = $1;
    $fullname{$alias} = $2;
    $address{$alias} = $3;
  }

  if (/^note (\S+)/) {
    my $alias = $1;

    if (/<name:([^>]+)>/) {
      $fullname{$alias} = $1;
    }
  }
}

foreach $alias (keys %address) {
  printf("alias %s \"%s <%s>\"\n",
	 $alias,
	 $fullname{$alias},
	 $address{$alias});
}
