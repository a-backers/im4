package IM_settings;

use strict;
use IM_base;

require Exporter;

# Settings module for shared perl settings.
our @ISA     = ("Exporter");
our @EXPORT  = qw(
                    $httpScriptName $remoteUser $userLevel
                    $debugging
                    %IMparam
                 );
our @VERSION = 0.1; 


##### Exported environment settings
# exported environment settings.
our $httpScriptName = "undefined";
if ( $ENV{'IM4_CGI'} ) {
  $httpScriptName = $ENV{'IM4_CGI'};
}
our $remoteUser = "noUser";
if ( $ENV{'REMOTE_USER'} ) {
  $remoteUser = $ENV{'REMOTE_USER'};
}
our $userLevel = $ENV{'USERLEVEL'};
our %IMparam = ();
our $debugging;

$IMparam{'IMmanDomain'} = $ENV{'IM4_MANDOMAIN'};
if ( $IMparam{'IMmanDomain'} eq "" ) {
  $IMparam{'IMmanDomain'} = $ENV{'IMDomain'};
}
if ( $ENV{'IM4_BASEDIR'} ) { 
  $IMparam{'IMbaseDir'} = $ENV{'IM4_BASEDIR'}; 
} else {
  printDebug(0, "IMbaseDir not set, exiting");
  exit;
}
$IMparam{'IMmainDir' = "$IMparam{'IMbaseDir'}/main";
$IMparam{'IMmainConfigDir'} = "$IMparam{'IMmainDir'}/configs";
$IMparam{'IMsystemDir'} = "$IMparam{'IMbaseDir'}/system";
$IMparam{'IMsystemConfigDir'} = "$IMparam{'IMsystemDir'}/cmdb/configs";
$IMparam{'IMsharedDir'} = "$IMparam{'IMbaseDir'}/shared";
$IMparam{'IMsharedConfDir'} = "$IMparam{'IMsharedDir'}/cmdb/configs";
if (( $IMparam{'IMmanDomain'} eq "" ) or ( ! -d "$IMparam{'IMbaseDir'}/data/$IMparam{'IMmanDomain'}" )) {
  print("IM_settings: sorry, IMmanDomain not found ($IMparam{'IMmanDomain'}).");
  exit;
} 
$IMparam{'IMhostname'} = `/bin/hostname`;
$IMparam{'IMdataDir'} = "$IMparam{'IMbaseDir'}/data/$IMparam{'IMmanDomain'}";
$IMparam{'IMdataConfDir'} = "$IMparam{'IMdataDir'}/cmdb/configs";
$IMparam{'IMsystemDnsServers'} = "system";




##### MAIN EXIT
1;
