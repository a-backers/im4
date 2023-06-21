package IMI_base;

use strict;
use IM_base;
use IM_settings;
require Exporter;

our @ISA     = ("Exporter");
our @EXPORT	 = qw( 
                    exitOk
                 );
our @VERSION = 0.1;

sub exitOk {
  print("\n<!-- exitOk -->\n");
  exit(5);
#  exit($ENV{'IM4_EXITOK'});
}

##### MAIN EXIT
1;
