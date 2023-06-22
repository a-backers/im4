#!/usr/bin/perl

use strict;

BEGIN {
  my $action = $ARGV[0];
  my $domain = $ARGV[1];

  print("BEGIN: Read CONF file\n");
  # get the env stuff from the config file.
  my $file = "../configs/im.conf";
  open (IN, $file) || die("BEGIN: cannot open $file.");
  my @lines = <IN>;
  close IN;

  print("BEGIN: Fill env; in loop\n");
  foreach my $regel (@lines) {
    chomp $regel;
    my ( $varName, $info ) = split('=', $regel);
    if ( substr($varName, 0, 1) ne "#" ) {
      $ENV{$varName} = $info;
    }
  }
  

  $ENV{'IMDomain'} = "TEST-AB";

  print("ENV: $ENV{'IMDomain'}\n");
  print("ENV: $ENV{'HOSTNAME'}\n");
  print("ENV: $ENV{'IM4_BASEDIR'}\n");
  print("ENV: $ENV{'IM4_HELPDIR'}\n");
}

0;
