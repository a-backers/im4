package IM_settings;

use strict;
require Exporter;

# Settings module for shared perl settings.
our @ISA        = ("Exporter");
our @EXPORT     = qw(
                    $IM_MonDevices $IM_CiscoPwds $IM_TftpBootDir
		                $IM_beep $IM_History $manDomain
		                $httpScriptName $remoteUser $userLevel $ipDatabaseDir $macDatabaseDir $imPtrDir $sharedConfDir $graphDir
                    $debugging
		                $switchInfoDir $deviceDir $oidHelpDir $im4Starter
		                $snmpStrings $inaddrSrvList $dnsCache $confRrdTool $searchIndexFile
                    %errorColor %errorAllert %errorLevel %IMparam %nodeColor %nodePollType %nodeDnsType %nodeManType %nodeDescription
                    %colorCode
                  );
our @VERSION    = 0.1;                 # version number


# exported environment settings.
our $httpScriptName = "undefined"; if ( $ENV{'QR_CGI'} ) { $httpScriptName = $ENV{'QR_CGI'}; }
our $remoteUser = "noUser"; if ( $ENV{'REMOTE_USER'} ) { $remoteUser = $ENV{'REMOTE_USER'}; }
our $userLevel = $ENV{'USERLEVEL'};
our %IMparam = ();


$IMparam{'IMmanDomain'} = $ENV{'IM_MANDOMAIN'};
if ( $IMparam{'IMmanDomain'} eq "" ) {
  $IMparam{'IMmanDomain'} = $ENV{'QRDomain'};
}
if ( $ENV{'IM_BASEDIR'} ) { 
  $IMparam{'IMbaseDir'} = $ENV{'IM_BASEDIR'}; 
} elsif ( -d "/var/im4" ) {
  $IMparam{'IMbaseDir'} = "/var/im4";
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
if (( $IMparam{'IMmanDomain'} eq "" ) or ( ! -d "$IMparam{'IMbaseDir'}/data/$IMparam{'IMmanDomain'}" )) {
  print("IM_settings: sorry, IMmanDomain not found ($IMparam{'IMmanDomain'}).");
  exit;
} 
$IMparam{'IMhostname'} = `/bin/hostname`;
$IMparam{'IMdataDir'} = "$IMparam{'IMbaseDir'}/data/$IMparam{'IMmanDomain'}";
$IMparam{'IMdataConfDir'} = "$IMparam{'IMdataDir'}/cmdb/configs";
$IMparam{'IMsystemDnsServers'} = "system"; # default setting dns servers

# set default dns servers

if ( -r "/etc/resolv.conf" ) {
  open ( RESO, "/etc/resolv.conf");
  my @lines = <RESO>;
  close RESO;
  foreach my $line (@lines) {
    my ( $type, $info ) = split(' ', $line);
    if ( $type eq "nameserver" ) {
      if ( $IMparam{'IMsystemDnsServers'} eq "system" ) {
        $IMparam{'IMsystemDnsServers'} = $info;
      } else {
        $IMparam{'IMsystemDnsServers'} = "$IMparam{'IMsystemDnsServers'} $info";
      }
    }
  }
} else {
  # if nothing is defined in resolv.conf, set it to 127.0.0.1.
  $IMparam{'IMsystemDnsServers'} = "127.0.0.1";
}



my @fileList = ();
push @fileList, "$IMparam{'IMmainConfigDir'}/settings2.conf\n";
if ( -f "$IMparam{'IMsystemConfigDir'}/settings2.conf" ) {
  push @fileList, "$IMparam{'IMsystemConfigDir'}/settings2.conf\n";
}
if ( -f "$IMparam{'IMsharedConfDir'}/settings2.conf" ) {
  push @fileList, "$IMparam{'IMsharedConfDir'}/settings2.conf\n";
}
if ( -f "$IMparam{'IMdataConfDir'}/settings2.conf" ) {
  # dont try to read this file if no management domain is set.
  push @fileList, "$IMparam{'IMdataConfDir'}/settings2.conf\n";
}
foreach my $entry (@fileList) {
  chomp($entry);
  open( CONF, $entry ) || print"Oops configfile $entry not found.";
  my @fileContent = <CONF>;
  foreach my $line (@fileContent) {
    chomp($line);
    my ( $varName, $varType, $varData ) = split(' ', $line, 3);
    if ( "$line" eq "" ) {
      my $dummy;
    } elsif ( "$varName" eq "" ) {
      my $dummy;
    } elsif ( substr($varName,0,1) eq "#" ) {
      my $dummy;
#   } elsif ( defined $varType && $varType eq "path" ) {
    } elsif (( defined $varType ) && (( $varType eq "path" ) or ( $varType eq "dir" ) or ( $varType eq "file" ) or ( $varType eq "bin" ))) {
      my ( $basePath, $rest ) = split(' ', $varData);
      $IMparam{$varName} = "$IMparam{$basePath}/$rest";
#     print(" $varName=$IMparam{$varName} ");
    } elsif (( defined $varType ) && (( $varType eq "var" ) or ( $varType eq "ebin" ) or ( $varType eq "edir" ))) {
      # split of the comment
      if (defined $varData) {
        my @varInfo = split(" # ", $varData);
        $IMparam{$varName} = $varInfo[0];
      }
    }
  }
}

# adapt the hostip to the local ip in case of eg docker (needed to test the load of the host system.
$IMparam{'QRIhostIp'} = "127.0.0.1";
if ( -f "$IMparam{'IMsystemConfigDir'}/localHostIP" ) {
  open(IN, "$IMparam{'IMsystemConfigDir'}/localHostIP");
  my $outPut = <IN>;
  close IN;
  chomp $outPut;
  $IMparam{'QRIhostIp'} = $outPut;
}

our $settingsDir = $IMparam{'IMdataConfDir'};
our $ipDatabaseDir = $IMparam{'IMipDatabase'};
our $imPtrDir = $IMparam{'IMptrDir'};
our $macDatabaseDir = $IMparam{'IMmacDatab'};
our $sharedConfDir = $IMparam{'IMsharedConfDir'};
our $snmpStrings = $IMparam{'IMsnmpStrings'};
our $inaddrSrvList = $IMparam{'IMinaddrSrvList'};
our $dnsCache = $IMparam{'IMnamedCache'};
our $debugging;
if ( -f "$IMparam{'IMsettingsDir'}/imShowDebug-$remoteUser" ) {
  $debugging = "yes";
} else {
  $debugging = "$IMparam{'IMsettingsDir'}/imShowDebug-$remoteUser not found";
}

# errorInfo
my $errInfoFile = "$IMparam{'IMerrorTypes'}";
our %errorColor = ();
our %errorAllert = ();
our %errorLevel = ();
if ( -r $errInfoFile ) {
  open( ERRINFO, $errInfoFile );
  my @lines = <ERRINFO>;
  foreach my $entry (@lines) {
    chomp $entry;
    my ( $test, $type, $color, $level, $allert ) = split(' ', $entry);
    if ( "$test" eq "error" ) {
      $errorColor{$type} = $color;
      $errorAllert{$type} = $allert;
      $errorLevel{$type} = $level;
    }
  }
} else {
  print("Oops, could not read errInfoFile: $IMparam{'IMerrorTypes'}.");
}

# color codes used for displaying logging, nodes, etc...
our %colorCode = ();
# replace the default color file with the user specific file
my $colorFile = "$IMparam{'QRmainColorDefs'}/default";
if ( -f $colorFile ) {
  open(INFO, $colorFile) || die "Could not open colorFile = $colorFile\n";
  my @lines = <INFO>;
  close(INFO);
  foreach my $line (@lines) {
    chomp($line);
    my ( $type, $cat, $name, $code ) = split(' ', $line);
    if ( $type eq "color" ) {
      $colorCode{"$cat.$name"} = $code;
    }
  }
}

our %nodeColor = ();
our %nodePollType = ();
our %nodeDnsType = ();
our %nodeManType = ();
our %nodeDescription = ();
if ( -f $IMparam{'IMnodeTypes'} ) {
  open(INFO, $IMparam{'IMnodeTypes'}) || die "Cannot open $IMparam{'IMnodeTypes'}";
  my @lines = <INFO>;
  close(INFO);
  foreach my $regel (@lines) {
    chomp $regel;
    my ( $prefix, $type, $color, $critical, $pollType, $dnsType, $description ) = split(' ', $regel, 7);
    if ( "$regel" eq "" ) {
      my $dummy = "";
    } elsif ( "$prefix" eq "nodeType" ) {
      $nodeColor{$type} = $color;
      $nodePollType{$type} = $pollType;
      $nodeDnsType{$type} = $dnsType;
      $nodeManType{$type} = $critical;
      $nodeDescription{$type} = $description;
    }
  }
}



# Various references to external filenames.
# needs to be integrated in the IMparam stuff.
our $IM_TftpBootDir = "$settingsDir/tftpBootDir";

our $IM_MonDevices = "$settingsDir/mon-devicelist";
our $IM_CiscoPwds = "$settingsDir/runCiscoTelnetPwds";
our $IM_History = "$settingsDir/testCmdHistory";
our $IM_beep = "/QR/main/sounds/BEEP1B.WAV";


if ( -f "$IMparam{'IMsettingsDir'}/lessColors-$remoteUser" ) {
  $IMparam{'IMdisplaylessColors'} = "yes";
}

# cron jobs (set, depending whether an specific version is set, or the general version needs to be run).
if ( -f "$IMparam{'IMsharedConfDir'}/cronJobs" ) {
  $IMparam{'IMcronJobs'} = "$IMparam{'IMsharedConfDir'}/cronJobs";
} else {
  $IMparam{'IMcronJobs'} = "$IMparam{'IMmainConfigDir'}/cronJobs";
}

# end.
1;
