#!/usr/bin/perl

use strict;

BEGIN {
  my $action = $ARGV[0];
  my $domain = $ARGV[1];

  # get the env stuff from the config file.
  my $file = "../configs/im.conf";
  open (IN, $file) || die("BEGIN: cannot open $file.");
  my @lines = <IN>;
  close IN;

  foreach my $regel (@lines) {
    chomp $regel;
    my ( $varName, $info ) = split('=', $regel);
    if ( substr($varName, 0, 1) ne "#" ) {
      $ENV{$varName} = $info;
    }
  }
  
  $ENV{'IMDomain'} = $domain;
  my $IMbaseDir = $ENV{'IM4_BASEDIR'} || die "Oops, could not find env for IM_BASEDIR";
  $ENV{'PERL5LIB'} = "$IMbaseDir/main/modules";
  our $IMstarterAction = "$action";

  print("ENV: $ENV{'IMDomain'}\n");
  print("ENV: $ENV{'IM4_BASEDIR'}\n");
  print("ENV: $ENV{'IM4_HELPDIR'}\n");
  print("ENV: $ENV{'PERL5LIB'}\n");
}

0;
