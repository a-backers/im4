#!/usr/bin/perl

use strict;

BEGIN {
  $ENV{'IMDomain'} = "TEST-AB";

  print("ENV: $ENV{'IMDomain'}\n");
  print("ENV: $ENV{'HOSTNAME'}\n");
}

0;
