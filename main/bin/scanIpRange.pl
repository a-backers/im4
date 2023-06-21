#!/usr/bin/perl

use strict;

use lib "../modules";
use IM_settings;
use IM_base;
use IM_updateInfo;

sub scanRange {
  while (<STDIN>) {
    printDebug(0, "scanRange: $_");
    my $ipDir = getIpDir($_);
    if ( -d $ipDir ) {
      print(", already defined.");
    } else {
      print(", new<BR>");
      &addIpNode($_, "scanRange-$remoteUser");
    }
#   my $ipDir =
  }
}


##### MAIN PROGRAM
&scanRange;
