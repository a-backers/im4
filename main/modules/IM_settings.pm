package IM_settings;

use strict;

require Exporter;

# Settings module for shared perl settings.
our @ISA     = ("Exporter");
our @EXPORT  = qw(
                    $debugging
                    %IMparam
                 );
our @VERSION = 0.1; 


##### Exported environment settings
our %IMparam = ();
our $debugging;
