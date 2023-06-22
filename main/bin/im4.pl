#!/usr/bin/perl

use strict;

BEGIN {
  my $action = $ARGV[0];
  my $domain = $ARGV[1];

  print("BEGIN: Read CONF file");
  # get the env stuff from the config file.
  my $file = "../configs/im.conf";
  open (IN, $file) || die("BEGIN: cannot open $file.");
  my @lines = <IN>;
  close IN;

  $ENV{'IMDomain'} = "TEST-AB";

  print("ENV: $ENV{'IMDomain'}\n");
  print("ENV: $ENV{'HOSTNAME'}\n");
}

0;
