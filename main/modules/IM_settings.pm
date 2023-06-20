package IM_settings;

use strict;
require Exporter;

# Settings module for shared perl settings.
our @ISA     = ("Exporter");
our @EXPORT  = qw(
                    %IMparam
                 );
our @VERSION = 0.1; 

##### Exported environment settings
our %IMparam = ();

$IMparam{'IMmanDomain'} = $ENV{'IMDomain'};

if ( $ENV{'IM_BASEDIR'} ) { 
  $IMparam{'IMbaseDir'} = $ENV{'IM_BASEDIR'}; 
} else {
  printDebug(0, "IMbaseDir not set, exiting");
  exit;
}

$IMparam{'IMmainDir' = "$IMparam{'IMbaseDir'}/main";
$IMparam{'IMmainConfigDir'} = "$IMparam{'IMmainDir'}/configs";
$IMparam{'IMsystemDir'} = "$IMparam{'IMbaseDir'}/system";
$IMparam{'IMsystemConfigDir'} = "$IMparam{'IMsystemDir'}/cmdb/configs";
$IMparam{'IMsharedDir'} = "$IMparam{'IMbaseDir'}/shared";
$IMparam{'IMsharedConfDir'} = "$IMparam{'SMsharedDir'}/cmdb/configs";


##### MAIN EXIT
1;
