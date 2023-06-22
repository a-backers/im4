#!/usr/bin/perl

use strict;

use lib "../modules";
use IM_base;
use IM_settings;

BEGIN {
  my $action = $ARGV[0];
  my $domain = $ARGV[1];
  my $verbose = $ARGV[2];

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
}

my $action = $ARGV[0];
my $domain = $ARGV[1];
my $verbose = $ARGV[2];
my ( $progName, $progOption );


##### SUB PROGRAMS
sub logRotate {
  #doc rotate the logfiles, retaining 50 versions
  my $fileName = shift;
  my @nums = ( 1 .. 50 );

  @nums = reverse @nums;

  foreach my $entry (@nums) {
    my $more = $entry + 1;
    my $formatEntry = sprintf("%04d", $entry);
    my $formatMore = sprintf("%04d", $more);
    if ( -f "$fileName.$formatEntry" ) {
      printDebug( 1, " mv -v $fileName.$formatEntry $fileName.$formatMore ");
      # print error to the logs, for better analysis.
      system(" mv $fileName.$formatEntry $fileName.$formatMore 2>&1");
      sleep 1;
    }
  }
  my $formatFirst = sprintf("%04d", 1);
  system(" mv $fileName $fileName.$formatFirst 2>&1 ");
}



##### MAIN PROGRAM
printDebug( 0, "im4-starter.pl action:\"$action\" domain:\"$domain\" verbose:\"$verbose\" IMmanDomain:\"$IMparam{'IMmanDomain'}\".");

$ENV{'REMOTE_USER'} = "starter-$action";
$ENV{'USERLEVEL'} = "6";

##### DO WE HAVE SOMETHING TO DO
if ( "$action" eq "" ) {
  print("im4-starter.pl <action> <domain> <verbose>\n");
} elsif ( "$domain" eq "" ) {
  printDebug(0, "Main: domain not defined");

##### TEST ENV COMMAND
} elsif ( "$action" eq "testEnv" ) {
  print("<PRE>");
  foreach my $k (sort keys %IMparam) {
    my $v = $IMparam{$k};
    print("$k => $v\n");
  }
  print("</PRE>");
} else {
  print("Oops, action $action not found");
}

#&exitOk();
0;
