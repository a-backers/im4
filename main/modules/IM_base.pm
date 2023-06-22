package IM_base;

use strict;
require Exporter;

use IM_settings;

our @ISA     = ("Exporter");
our @EXPORT  = qw(
                    printDate printDebug
                 );
our @VERSION = 0.1; 


##### SUB PROGRAMS
sub printDate {
  my $timestamp = shift;
  my $paramType = shift;
  my $type = "default";

  if (  "$paramType" ne "" ) {
    $type = $paramType;
  }

  my ($sec,$min,$hour,$mday,$mon,$jaar,$wday,$yday,$isdst) = localtime($timestamp);
  my @month = qw(dummy Jan Feb Mar Apr May Jun Jul Aug Sep Okt Nov Dec);
  my @z2 = ('00' .. '60');

  $mon++;
  $jaar = $jaar + 1900;

  if ( $type eq "yyyymmdd" ) {
    return("$jaar\-$z2[$mon]\-$z2[$mday]");
  } elsif ( $type eq "hhmmss" ) {
    return("$z2[$hour]\:$z2[$min]\:$z2[$sec]");
  } elsif ( $type eq "logdate" ) {
    return("$jaar\-$z2[$mon]\-$z2[$mday]_$z2[$hour]\:$z2[$min]\:$z2[$sec]");
  } elsif ( $type eq "wday" ) {
    return("$wday");
  } else {
    return("$jaar\-$z2[$mon]\-$z2[$mday] $z2[$hour]\:$z2[$min]\:$z2[$sec]");
  }
}

sub printDebug {
  my $level = shift;
  my $string = shift;
  my $outputType = shift;

  if (( "$level" eq "0" ) or ( "$debugging" eq "yes" )) {
    my $now = time;
    my $dateStr = printDate( $now, "hhmmss" );
    if ( defined $outputType && $outputType eq "html" ) {
      print("$string\n");
    } else {
      print("<BR>   <B>$dateStr: $string</B> ");
    }
  }
}
