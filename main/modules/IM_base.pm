package IM_base;

use strict;
use IM_settings;
require Exporter;

# Settings module for shared perl settings.
our @ISA     = ("Exporter");
our @EXPORT  = qw(
                    printDebug
                 );
our @VERSION = 0.1; 



sub printDebug {
  #doc Print informational messages, for debugging or progress indication
  #doc syntax: <level> <string> <outputType>
  my $level = shift;
  my $string = shift;
  my $outputType = shift;

  if (( "$level" eq "0" ) or ( "$debugging" eq "yes" )) {
    my $now = time;
    my $dateStr = printDate( $now, "hhmmss" );
    if ( defined $outputType && $outputType eq "html" ) {
      print("$string");
    } else {
      print("<BR>   <B>$dateStr: $string</B> ");
    }
  }
}

##### MAIN EXIT
1;
