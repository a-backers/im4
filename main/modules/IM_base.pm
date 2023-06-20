package SIM_base;

#
use strict;
require Exporter;
use SIM_settings;
#use SIM_nodeInfo;
use Net::DNS;
use Net::Syslog;
use CGI qw(param);
use Time::HiRes qw(time);


our @ISA 	= ("Exporter");
our @EXPORT	= qw( catFileLine catFile catFileArray
                      printFileLine touchFile removeOldEntries
                      getClusterMembers tftpFile
                      testUpdFile logUpdFile 
                      dispHostName
                      testNameStrict stripBE testMkDir 
                      updateManType formatIntName shortHostname
                      getIpDir getDevDir getMacDir getLogMacDir
                      getNodeColor printDate getFileDate printDebug testIfIp testBetween testIfMac 
                      getLogMac getMacAddr
                      oidToMac dotFormatted convertMac
		      logLine getDnsPtr getAreccord queryAreccord queryPTRreccord testDnsName make_hex_string longIp
                      calcIpNet convertBinIp testFileAge calcNumUptime
                     );
our @VERSION	= 0.01;			# version number

our %logDestinations = ();
our %ipVendor = ();
our %ipDnsName = ();

# include variabeles to be used over the various modules here.
#
#

#my $ipDatabaseDir = $ENV{'SIM_IPDATAB'};

sub stripBE {
  #doc strip white space from beginning and end.
  my $var = shift;
  $var =~ s/^\s+//;
  $var =~ s/\s+$//;
  return $var;
}

sub getClusterMembers {
  #doc Get the cluster member ip's to forward info to
  my $memberType = shift;
  my @info = catFileArray($SIMparam{'SIMclusterInfo'});
  my @retInfo = ();
  foreach my $line (@info) {
    chomp($line);
    my ( $type, $name, $ipAddr ) = split(' ', $line);
    if (( $type eq "member" ) and ( $name ne $SIMparam{'SIMhostname'} )) {
      push(@retInfo, $ipAddr);
    }
  }
  if (( $memberType eq "slaves" ) and ( $SIMparam{'SIMclusterRole'} eq "master" )) {
    return(@retInfo);
  }
}

sub tftpFile {
  my $file = shift;
  my @clusterMembers = &getClusterMembers;
  if ( ! -f $file ) {
    printDebug(0, "tftpFile: file=$file missing");
  } elsif ( ! -r $file ) {
    printDebug(0, "tftpFile: file=$file not readable");
  } else {
    foreach my $ipAddr (@clusterMembers) {
      open (TFTP, "|$SIMparam{'SIMtftp'} $ipAddr");
      printDebug(0, "tftpFile: uploading $file to $ipAddr\n");
      print TFTP "put $file\n";
      print TFTP "quit\n";
      close (TFTP);
    }    
  }
}
sub getMacAddr {
  # general tool to find the mac addr for an node.
  # updated to find the most recent entry
  my $ipAddr = "$_[0]";
  my $ipDir = getIpDir($ipAddr);
  my $macType;
  my %macFile = ();
  $macFile{'dhcp'} = "dhcpmacaddr.txt";
  $macFile{'snmp'} = "snmpmac.txt";
  $macFile{'arp'} = "arpmac.txt";
  $macFile{'ap'} = "ap-mac";
  $macFile{'netbeui'} = "nbtMac";
  my $max = 0;
  foreach my $key (keys %macFile) {
    my $file = "$ipDir/$macFile{$key}";
    if ( -f $file ) {
      my $updTime = (stat $file)[9];
      if ( $updTime > $max ) {
        $max = $updTime;
        $macType = $key;
      }
    }
  }
  my $macAddr = catFileLine("$ipDir/$macFile{$macType}");
  printDebug(1, "getMacAddr: ipAddr=$ipAddr, macAddr=$macAddr, macType=$macType");
  return( $macAddr, $macType );
}

sub dispHostName {
  # this will display the hostname (based on what is available).
  my $ipAddr = shift;
  my $type = shift;
  my $bgColor = shift;
  my $ipDir = getIpDir($ipAddr);
  my $devName;
  my ( $macAddr, $macType ) = &getMacAddr($ipAddr);
# my ( $macAddr, $macType ) = "";
  my $macDir = &getMacDir($ipAddr);
  my @fileList = ();
  push(@fileList, "$ipDir/manHostname");
  push(@fileList, "$ipDir/hostname.txt");
  if ( $type eq "data" ) {
    # in case of return, the defined hardware name is the prefered hostname
    unshift(@fileList, "$ipDir/hwName");
  } else {
    push(@fileList, "$ipDir/hwName");
  }
  push(@fileList, "$macDir/macName");
  push(@fileList, "$SIMparam{'SIMmacDatab'}/$macAddr/dhcpname.txt");
  push(@fileList, "$ipDir/hostname-cdp");
  push(@fileList, "$SIMparam{'SIMmacDatab'}/$macAddr/acsHostname");
  push(@fileList, "$macDir/nbtHostName");
  push(@fileList, "$ipDir/fortinet-hostname");
  foreach my $entry (@fileList) {
    if ( -f $entry ) {
      $devName = &catFileLine($entry);
      printDebug(1, "dispHostName: found $devName in $entry");
      last;
    }
  }
  if ( $type ne "data" ) {
    if ( -f "$ipDir/vrfName" ) {
      my $vrfName = catFileLine("$ipDir/vrfName");
      if ( $vrfName ne "default" ) {
        $devName = "$devName $vrfName";
      }
    }
  }
  if ( $type eq "return" ) {
    return "<TD STYLE=background-color:$bgColor>$devName</TD>";
  } elsif ( $type eq "data" ) {
    return "$devName";
  } else {
    print("<TD>$devName</TD>");
    return "<TD>$devName</TD>";
  }
}


sub calcHours {
  my $time = $_[0];
  my ( $hour, $min, $sec ) = split(":", $time);
  my $return = $hour * 3600 + $sec;
  $return = $min * 60 + $return;
  return $return;
}

sub calcNumUptime {
  # return the number of secconds ( uptime is returned in hundreds of a seccond.
  my $time = $_[0];
# my $upDays = $time / 8640000;
  my $upDays = $time / 100;
  my $upDayStr = sprintf("%.1f", $upDays);
  return($upDayStr);
}

#sub calcNumUptime {
#  my $time = $_[0];
#  my $return = "error";
#  my @vars = split(' ', $time);
#  if ( $vars[1] eq "" ) {
#    $return = &calcHours($time);
#  } elsif ( $vars[1] eq "days," ) {
#    $return = &calcHours($vars[2]);
#    $return = $vars[0] * 86400 + $return;
#  }
#  return $return;
#}

sub formatIntName {
  my $intName = $_[0];
  my $modIntName = lc $intName;
  $modIntName =~ s#/#-#g;
  $modIntName =~ s#\.#_#g;
  $modIntName =~ s# ##g;
  $modIntName =~ s#:#-#g;
  $modIntName =  testNameStrict($modIntName, "email");
  return $modIntName;
}

sub dotFormatted
{
  # sub to create formatting of numbers
  # found on www.willmaster.com
  my $delimiter = '.'; # replace comma if desired
  my($n,$d) = split /\./,shift,2;
  my @a = ();
  while($n =~ /\d\d\d\d/)
  {
    $n =~ s/(\d\d\d)$//;
    unshift @a,$1;
  }
  unshift @a,$n;
  $n = join $delimiter,@a;
  $n = "$n\.$d" if $d =~ /\d/;
  return $n;
}


sub oidToMac {
  # this sub will convert the oid to an mac
  my $oid = $_[0];
  my ( $mac );
  my @info = split('\.', $oid);
  my $num = 0;
  foreach my $entry (@info) {
    my $hexPart = sprintf("%02x", $entry);
    if ( $num eq 0 ) {
      $mac = $hexPart;
    } else {
      $mac = "$mac:$hexPart";
    }
    $num++;
  }
  return("$mac");
}


sub testFileAge {
  my $file = $_[0];
  if ( -f $file ) {
    my $write_secs = (stat($file))[9];
    my $elapsed = (time) - $write_secs;
    my $daysElapsed = $elapsed / 86400;
    $daysElapsed = sprintf('%.0f', $daysElapsed);
    print(" $daysElapsed ");
    return $daysElapsed;
  }
}

sub testBetween {
  my $ipAddr = "$_[0]";
  my $start = "$_[1]";
  my $stop = "$_[2]";
  my $result = "";
  my @ipTest = split('\.', $ipAddr);
  my @ipStart = split('\.', $start);
  my @ipStop = split('\.', $stop);
  foreach my $item (0 .. 3) {
    printDebug("1", " item=$item ipTest=$ipTest[$item]. ipStart=$ipStart[$item]. ipStop=$ipStop[$item].");
    if (( $ipTest[$item] < $ipStart[$item] ) or ( $ipTest[$item] > $ipStop[$item] )) {
      printDebug("1" , "testBetween: break item=$item ipTest=$ipTest[$item]. ipStart=$ipStart[$item]. ipStop=$ipStop[$item].");
      last;
    } elsif (( $ipTest[$item] > $ipStart[$item] ) or ( $ipTest[$item] < $ipStop[$item] )) {
      printDebug("1" , "testBetween: range item=$item ipTest=$ipTest[$item]. ipStart=$ipStart[$item]. ipStop=$ipStop[$item].");
      $result = "xxxx";
      last;
    } else {
      $result = "x$result";
    }
  }
  return $result;
}

sub getLogMac {
  my $ipAddr = $_[0];
  my $ipDir = getIpDir($ipAddr);
  my ( $logMac, $macType );
  if ( -d $ipDir ) {
    if ( -f "$ipDir/firstmac.txt" ) {
      $logMac = catFileLine("$ipDir/firstmac.txt");
    } else {
      ( $logMac, $macType ) = &getMacAddr($ipAddr);
    }
    return $logMac;
  }
}

sub testIfMac {
  # this sub will test / convert the various mac syntaxes to an Sipman syntax.
  my $testMac = lc($_[0]);
  my $macReturn;
  if ( $testMac =~ /^([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2})$/i) {
    # standard sipman / dhcp mac notation
    return $testMac;
  } elsif ( $testMac =~ /^([0-9a-f]{2})-([0-9a-f]{2})-([0-9a-f]{2})-([0-9a-f]{2})-([0-9a-f]{2})-([0-9a-f]{2})$/i) {
    # cisco acs notation
    my @macArr = split('-', $testMac);
    my $returnMac = join(':', @macArr);
#   print("found $returnMac. ");
    return $returnMac;
  } elsif ( $testMac =~ /^([0-9a-f]{4})[.]([0-9a-f]{4})[.]([0-9a-f]{4})$/i) {
    # mac notation used by cisco
    my @macArr = ();
    $macArr[0] = substr($testMac,0,2);
    $macArr[1] = substr($testMac,2,2);
    $macArr[2] = substr($testMac,5,2);
    $macArr[3] = substr($testMac,7,2);
    $macArr[4] = substr($testMac,10,2);
    $macArr[5] = substr($testMac,12,2);
    my $returnMac = join(':', @macArr);
#   print("returnMac=\"$returnMac\" ");
    return $returnMac;
  } elsif ( $testMac =~ /^([0-9a-f]{12})$/i) {
    my @macArr = ();
    $macArr[0] = substr($testMac,0,2);
    $macArr[1] = substr($testMac,2,2);
    $macArr[2] = substr($testMac,4,2);
    $macArr[3] = substr($testMac,6,2);
    $macArr[4] = substr($testMac,8,2);
    $macArr[5] = substr($testMac,10,2);
    my $returnMac = join(':', @macArr);
    return $returnMac;
  } else {
    return "noMac";
  }
}

sub removeOldEntries {
  #doc Remove old files / reccords based on a search string
  #doc syntax removeOldEntries( searchStr, ageSecs );
  #doc   searchStr, start of the string (* will be appended).
  #doc   agesecs can also be 10d, to represent days.
  my $searchStr = "$_[0]";
  my $ageSecs = "$_[1]";
  if ( "$ageSecs" eq "" ) { $ageSecs = 300; }
  if ( substr($ageSecs, -1) eq "d" ) {
    my $days = substr($ageSecs, 0, -1);
    $ageSecs = $days * 86400;
    printDebug("0", "removeOldEntries: $days days = $ageSecs secconds for *searchStr.");
  }
  my @fileList = <$searchStr*>;
  my $now = time;
  foreach my $entry (@fileList) {
    my $time = (stat $entry)[9];
    my $elapsed = $now - $time;
    if ( "$elapsed" > "$ageSecs" ) {
      if ( -f $entry ) {
        printDebug("0", "removeOldEntries: Removing old entry $entry");
        unlink $entry;
      }
    }
  }
}


sub touchFile {
  #doc equivalent for the unix touch command
  #doc will create / update timestamps of an file.
  #doc syntax touchFile(file)
  my $file = "$_[0]";
  if ( ! -f $file ) {
    open(FH,">$file") or &logDie("Can't create $file: $!");
    close(FH);
  } else {
    my $now = time;
    utime $now, $now, $file;
  }
}


sub convertBinIp {
  my $input = shift;
  # convert bin ip returned from cdp-neighbours to an real ip.
  #my $str = unpack "H*", shift @_;
# my $str = unpack "H*", shift @_;
# $str =~ s/(..)/ $1/g;
  my $hex1 = substr($input, -8, 2);
  my $hex2 = substr($input, -6, 2);
  my $hex3 = substr($input, -4, 2);
  my $hex4 = substr($input, -2, 2);
# my ( $hex1, $hex2, $hex3, $hex4 ) = split(' ', $str);;
  my $oct1 = hex($hex1);
  my $oct2 = hex($hex2);
  my $oct3 = hex($hex3);
  my $oct4 = hex($hex4);
  return "$oct1.$oct2.$oct3.$oct4";
}

sub calcIpNet {
  my $ipAddr = "$_[0]";
  my $netMask = "$_[1]";
  my $option = "$_[2]";

  my @addrarr=split(/\./,$ipAddr);
  my ( $ipaddress ) = unpack( "N", pack( "C4",@addrarr ) );
  my @maskarr=split(/\./,$netMask);
  my ( $netmask ) = unpack( "N", pack( "C4",@maskarr ) );

  # Calculate network address by logical AND operation of addr & netmask
  # and convert network address to IP address format
  my $netadd = ( $ipaddress & $netmask );
  my @netarr=unpack( "C4", pack( "N",$netadd ) );
  my $netaddress=join(".",@netarr);

  # Calculate broadcase address by inverting the netmask
  # and do a logical or with network address
  my $bcast = ( $ipaddress & $netmask ) + ( ~ $netmask );
  my @bcastarr=unpack( "C4", pack( "N",$bcast ) ) ;
  my $broadcast=join(".",@bcastarr);
  if ( $option eq "broadcast" ) {
    return $broadcast;
  } else {
    return $netaddress;
  }
}


sub longIp {
  my $ipAddr = "$_[0]";
  my ( $ip1, $ip2, $ip3, $ip4 ) = split('\.', $ipAddr);
  my $longIp = sprintf("%03d.%03d.%03d.%03d", $ip1, $ip2, $ip3, $ip4);
  return $longIp;
}

sub convertMac {
  # convert macs returned by the snmp tool.
  my $oidMac = $_[0];
  if ( $oidMac ne "" ) {
    my $returnMac = substr($oidMac, -12, 2) . ":" . substr($oidMac, -10, 2) . ":" . substr($oidMac, -8, 2) . ":" . 
                    substr($oidMac, -6, 2) . ":" . substr($oidMac, -4, 2) . ":" . substr($oidMac, -2, 2);
#   my $returnMac = substr($oidMac, 2, 2) . ":" . substr($oidMac, 4, 2) . ":" . substr($oidMac, 6, 2) . ":" . 
#                   substr($oidMac, 8, 2) . ":" . substr($oidMac, 10, 2) . ":" . substr($oidMac, 12, 2);
    # make sure we return an real mac.
    if ( length($returnMac) eq 17 ) {
      return($returnMac);
    }
  }
}

sub make_hex_string {
   # will be replaced, was userd to convert stuff from SNMP_util
   my $str = unpack "H*", shift @_;
   $str =~ s/(..)/:$1/g;
   $str =~ s/^://;
   $str;
}


sub testDnsName {
  my $input = "$_[0]";
  my @skipList = split(' ', $SIMparam{'SIMskipDnsNames'});
  foreach my $name (@skipList) {
    if ( "$name" eq "$input" ) {
      $input = "";
      last;
    }
  }
  $input =~ tr/A-Z/a-z/;
  $input =~ s/_/-/g;
  $input =~ s/[^a-z0-9\.\-]//g;
  return $input;
}

sub getDnsPtr {
  # return a single IpName
  my $ipAddr = "$_[0]";
  my $inaddrSrvList = "$_[1]";
  my @nameServers;
  printDebug( "0", "getDnsPtr: ipAddr: $ipAddr, inaddrSrvList: $inaddrSrvList.");
  if ( "$inaddrSrvList" ne "" ) {
    # use the not default nameservers if specified.
    my @inaddrServers = split(' ', $inaddrSrvList);
    foreach my $entry (@inaddrServers) {
      my $test = testIfIp( $entry );
      if ( "$test" eq "oke" ) {
        push(@nameServers, $entry);
      } else {
        printDebug( "0", "getDnsPtr: $entry not a nameserver.");
      }
    }
  }
  foreach my $entry (@nameServers) {
    printDebug(0, "getDnsPtr: ns:$entry. ");
  }
  if ( "$nameServers[0]" eq "" ) {
    @nameServers = split(' ', $SIMparam{'SIMsystemDnsServers'});
  }
  if ( "$nameServers[0]" ne "" ) {
    my $res = Net::DNS::Resolver->new(
      nameservers => [ @nameServers ],
      recurse     => 0,
      debug       => 0,
    );
    my $answer = $res->search($ipAddr);
    if ($answer) {
      foreach my $rr ($answer->answer) {
        printDebug( "1", "getDnsPtr: $rr->type, answer: $rr->ptrdname.");
        next unless $rr->type eq "PTR";
        my $answer = $rr->ptrdname;
        return $answer;
        last;
      }
    } else {
      print"getDnsPtr: query failed: ", $res->errorstring, "\n";
      printDebug(0, "getDnsPtr: verify with nslookup nameServer = $nameServers[0], query = $ipAddr\n");
      my @info = `nslookup $ipAddr $nameServers[0]`;
      foreach my $line (@info) {
        chomp $line;
        my ( $arpa, $name, $is, $result ) = split(' ', $line);
        printDebug(1, "getDnsPtr: nslookup line ($is $name) $line.");
        if ( "$is $name" eq "= name" ) {
          printDebug(0, "getDnsPtr: nslookup result = $result");
          return $result;
        }
      }
    }
  } else {
    printDebug( "0", "getDnsPtr: no useable nameservers defined.");
  }
}

sub queryPTRreccord {
  my $ipAddr = shift;
  my $nameServers = shift;
  chomp($nameServers);
  my @dnsServers = split(' ', $nameServers);
  my $ares = Net::DNS::Resolver->new( 
                  nameservers => [@dnsServers],
              );
# my $answer = $ares->search($ipAddr, "PTR");
# my $answer = $ares->search($ipAddr, 'PTR');
  my $answer = $ares->query($ipAddr, 'PTR');
  my $return;
  if ($answer) {
    my $num = 0;
    foreach my $rr ($answer->answer) {
      next unless $rr->type eq "PTR";
      my $result = $rr->ptrdname;
      printDebug(1, "<TR><TD COLSPAN=10>queryPTRreccord: result=$result </TD></TR>", "html");
      $num++;
      if ( $return ne "" ) {
        $return .= "<BR>";
      }
      if ( $num eq 3 ) {
        $return .= "<SPAN TITLE=\"$result";
      } else {
        $return = "$return $result";
      }
    }
    if ( $num > 3 ) {
      $return .= "\"> more </SPAN>";
    }
  } else {
    printDebug(1, "<TR><TD COLSPAN=10>queryPTRreccord: ipAddr=$ipAddr, nameServers=$nameServers, no answer</TD></TR>", "html");
  }
# printDebug(0, "<TR><TD COLSPAN=10> queryAreccord: dnsName=$dnsName, nameServers=$nameServers, return=$return </TD></TR>", "html");
  $return =~ s/^\s+//;
  return($return);
}


sub queryAreccord {
  my $dnsName = "$_[0]";
  my $nameServers = "$_[1]";
  my @dnsServers = ();
  push(@dnsServers, $nameServers);
  my $ares = Net::DNS::Resolver->new( nameservers => [@dnsServers], );
  my $answer = $ares->query($dnsName);
  my $return;
  if ($answer) {
    foreach my $rr ($answer->answer) {
      next unless $rr->type eq "A";
      my $result = $rr->address;
#     printDebug(0, "<TR><TD COLSPAN=10> result=$result </TD></TR>", "html");
      $return = "$return $result";
    }
  }
# printDebug(0, "<TR><TD COLSPAN=10> queryAreccord: dnsName=$dnsName, nameServers=$nameServers, return=$return </TD></TR>", "html");
  $return =~ s/^\s+//;
  return($return);
}


sub getAreccord {
  my $dnsName = "$_[0]";
  my $inaddrSrvList = "$_[1]";
  my $testIpAddr = "$_[2]";
# $dnsName = "$dnsName.";
  if ( "$inaddrSrvList" eq "" ) { $inaddrSrvList = "127.0.0.1"; }
  my $return = "";
  my $nameServers;
  if ( "$inaddrSrvList" ne "" ) {
    my @inaddrServers = split(' ', $inaddrSrvList);
    foreach my $entry (@inaddrServers) {
      my $test = testIfIp( $entry );
      if ( "$test" eq "oke" ) {
#       print("serverIp: $entry ");
        if ( $nameServers eq "" ) {
          $nameServers = $entry;
        } else {
          $nameServers = "$nameServers $entry";
        }
      }
    }
    if ( "$nameServers" ne "" ) {
#     printDebug( "0", "getAreccord: nameServers: $nameServers.");
    }
  }
# my $ares = Net::DNS::Resolver->new( nameservers => [qw($nameServers)], );
  # problems resolving A reccords with dns servers defined.
  my $ares = Net::DNS::Resolver->new;
  my $answer = $ares->search($dnsName);
  if ($answer) {
    foreach my $rr ($answer->answer) {
      next unless $rr->type eq "A";
      my $result = $rr->address;
#     printDebug( "0", "getAreccord: result = $result.");
      if ( "$result" eq "$testIpAddr" ) {
        $return = "oke";
	last;
      } else {
        $return = $result;
      }
#     print("result: $result ");
    }
# } else {
#   print "query failed: ", $ares->errorstring, "\n";
  }
  return $return;
}

# duplicate routine, can be removed if redundant
sub testIfIp2 {
  #Test if an ip address looks like one. 
  my $ipAddr = shift;
  my $testIpAddr = $ipAddr;
  $testIpAddr =~ tr#0-9[\.]#A#cds;
# print("ip=$testIpAddr");
  my ( $ip1, $ip2, $ip3, $ip4, $rest ) = split('\.', $testIpAddr);
# print("ip1=$ip1, ip2=$ip2, ip3=$ip3, ip4=$ip4, ");
  if ( "$rest" ne "" ) {
    return "Oops, to many dots.";
  } elsif ( $ipAddr eq "0.0.0.0" ) {
    return "skip all zero";
  } elsif ( "$ip4" eq "" ) {
    return "not four parts";
   } elsif (( "$ip1" < "0" ) or ( "$ip1" > "223" )) {
    return "ip1";
   } elsif (( "$ip2" < "0" ) or ( "$ip2" > "255" )) {
    return "ip2";
   } elsif (( "$ip3" < "0" ) or ( "$ip3" > "255" )) {
    return "ip3";
   } elsif (( "$ip4" < "0" ) or ( "$ip4" > "255" )) {
    return "ip4";
   } elsif ( "$ipAddr" eq "$testIpAddr" ) {
    return "oke";
   } else {
    return "problem with $ipAddr ($testIpAddr)";
   }
}

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

sub updateManType {
  #doc Update the management type
  #doc syntax: <ipAddr> <name> <manType>
  my $ipAddr = shift;
  my $name = shift;
  my $manType = shift;
  my $ipDir = getIpDir( $ipAddr );
  my $oldManType = catFileLine("$ipDir/managementtype.txt");
  if ( $manType ne $oldManType ) {
    my $statusDate = printDate( time, "logdate" );
    logLine("$ipAddr","system","Mod-manType","$ipAddr changed managementType to $manType by $name ($oldManType).");
    printFileLine("$ipDir/managementtype.txt", "managementType $ipAddr", "$manType");
  }
}


sub printDate {
  #doc Return the date in various formats, based on the input time.
  #doc syntax: <timestamp> <option>
  #doc options: yyyymmdd, hhmmss, logdate, wday
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

sub getFileDate {
  #doc Return the formatted date from an file or directory, uses printdate to format the time
  #doc syntax: file format
  my $file = shift;
  my $format = shift;
  my $updTime = (stat $file)[9];
  my $return = &printDate($updTime, $format);
  return $return;
}

sub catFileArray {
  #doc Read an file and put the lines in an array
  #doc syntax <filename>
  my $fileName = shift;
  my $option = shift;
  if ( -r $fileName ) {
    open(IN, $fileName) || die "catFileArray: error opening $fileName, $!";
    my @info = <IN>;
    close IN;
    return(@info);
  } elsif ( $option eq "testIfExist" ) {
    print("<H2>Oops, file \"$fileName\" missing.</H2>");
    exit;
  }
}

sub catFileLine {
  #doc Read a file line and return it as an variable
  #doc alternatively, output the alternative
  #doc syntax <filename> <alternative>
  my $outPut = "";
  my ($file) = shift;
  my ($altern) = shift;
  chomp($file);
  if ( -f $file ) {
    if ( -r $file ) {
      open FH, $file;
      $outPut = <FH>;
      close FH;
      chomp($outPut);  # remove the newline
    }
  }
  if ( "$outPut" eq "" ) {
    $outPut = $altern;
  }
  return $outPut;
}

sub catFile {
  #doc return all data from a file
  #doc syntax <file> <return|...>, return will add <BR> as an delimiter.
  my $file = "$_[0]";
  my $return = "$_[1]";
  open(INFO, $file);
  my @lines = <INFO>;
  close(INFO);
  if ( $return eq "return" ) {
    my $info = join('<BR>', @lines);
    return $info;
  } else {
    print @lines;
  }
}

sub testMkDir {
  #doc Create an directory and check if it has been created
  #doc syntax: <dirName>
  my $dirName = shift;
  printDebug(1, "testMkDir: creating $dirName.");
  if ( $dirName eq "" ) {
    print("testMkDir: no dir specified, exiting....");
    exit;
  } elsif ( !-d $dirName ) {
    # this should work for most cases.
    mkdir($dirName);
  } else {
    # update the time to help track if an dir is still used.
    my $now = time;
    utime $now, $now, $dirName;
  }
  if ( ! -d $dirName ) {
    printDebug(0, "testMkDir: perl mkdir did not work for $dirName, using shell version. ");
    sleep(1);
    system "mkdir -p $dirName";
    if ( ! -d $dirName ) {
      print("Oops, could not create dir $dirName, exiting....");
      logLine("127.0.0.1","system","FILESYSTEM-error","could not create $dirName ($remoteUser).");
      exit;
    } else {
      print(" created.");
    }
  }
}

sub printFileLine {
  #doc Base routine to create, update, append files (reccords). Tests if the output page exists. If this needs not to be true, use noTest.
  #doc syntax: <file> <varName> <data>
  my $file = shift;
  my $varName = shift;
  my $rest = shift;
  chomp $file;
  my $oldVal = catFileLine($file);
  if (( -f $file ) and ( $oldVal eq $rest )) {
    # update the access time (= touch), if a file is unchanged.
    my $now = time;
    if ( $varName ne "noTouch" ) {
      utime $now, $now, $file;
    }
  } else {
    if ( "$rest" eq "" ) {
      # remove file if it exists (don't display message if it doesn't.).
      if ( -f $file ) {
        unlink ($file);
        print("$varName is verwijderd, oud:$oldVal<BR>");
      }
    } elsif ( "$varName" eq "append" ) {
#     print("writing to $file<BR>.");
      open(OUT, ">>$file") || &logDie("printFileLine: cannot append $file: $!");
      print OUT $rest;
      close(OUT);
    } else {
      if (( "$varName" ne "quiet" ) and ( $varName ne "noTouch" ) and ( $varName ne "noTest" )) {
        if ( ! -f $file ) {
          print("$varName is created, new:$rest<BR>");
        } else {
          print("$varName is changed, old:$oldVal new:$rest<BR>");
        }
      }
      if (open(OUT, ">$file")) {
        print OUT $rest;
        close(OUT);
      } else {
        &printDebug(0, "printFileLine: could not create $file for writing.");
        if ( $varName ne "noTest" ) {
          &logLine("127.0.0.1", "system","FILESYSTEM-error","printFileLine: could not create $file for writing.");
          print(", do exit(2)");
          exit(2);
        }
      }
    }
  }
}

sub logDie {
  #doc an alternative for exit, will logg an line first before exiting with code 2.
  #doc syntax: <msg>
  my $msg = $_[0];
  logLine("127.0.0.1","system","EXIT-error","$msg ($ENV{'REMOTE_USER'})");
  printDebug(0, "logDie: $msg");
  exit 2;
}

sub logUpdFile {
  #doc Test if an file needs to be updated, or removed and log the update if needed
  #doc syntax: <fileName> <descr> <newVal> <ipAddr> <logUser>
  my $fileName = shift;
  my $descr = shift;
  my $newVal = shift;
  my $ipAddr = shift;
  my $logUser = shift;
  if ( $ipAddr eq "" ) {
    $ipAddr = "127.0.0.1";
  }
  my $oldVal = catFileLine($fileName);
# printDebug( 0, "testUpdFile: testing $httpParam.");
  if ( $newVal eq "\." ) {
    print("<BR>Removing $oldVal from $descr.\n");
    unlink($fileName);
    logLine("$ipAddr","info","Remove-field","$descr removed by $logUser ($oldVal).");
    # set the return value
    $oldVal = "";
  } elsif ( $newVal ne "" ) {
    if ( $oldVal eq $newVal ) {
      utime(time, time, $fileName);
    } else {
      printFileLine ("$fileName", "$descr", "$newVal");
      logLine("$ipAddr","info","Update-field","$descr updated to $newVal by $logUser ($oldVal).");
      # set the return value
      $oldVal = $newVal;
    }
  }
  return $oldVal;
}

sub testUpdFile {
  #doc Read the cgi parameter and update the file if needed.
  #doc will be the right place for cgi input checking.
  #doc syntax: <fileName> <httpParam> <descr> <ipAddr>
  my $fileName = shift;
  my $httpParam = shift;
  my $descr = shift;
  my $ipAddr = shift;
  if ( $ipAddr eq "" ) {
    $ipAddr = "127.0.0.1";
  }
# my $oldVal = catFileLine "$fileName";
  # replaced to allow simple input for multiline files.
  my @oldArr = catFileArray($fileName);
  my $oldVal = join('', @oldArr);
  my $newVal = param("$httpParam");
# printDebug( 0, "testUpdFile: testing $httpParam.");
  if ( $newVal eq "\." ) {
    print("<BR>Removing $oldVal from $descr.\n");
    unlink($fileName);
    logLine("$ipAddr","info","Remove-field","$descr removed by $remoteUser ($oldVal).");
    # set the return value
    $oldVal = "";
   } elsif ( $newVal ne "" ) {
    # touch the file, to know it is checked.
    utime( time, time, $fileName);
    if ( $oldVal ne $newVal ) {
      printFileLine ("$fileName", "$descr", "$newVal");
      logLine("$ipAddr","info","Update-field","$descr updated to $newVal by $remoteUser ($oldVal).");
      # set the return value
      $oldVal = $newVal;
    }
  }
  return $oldVal;
}

sub testNameStrict {
  #doc Remove invalid characters from strings
  #doc options: num, word, email, default
  my ($testname) = shift;
  my ($type) = shift;
  if ( "$type" eq "yyyymmdd" ) {
    $testname =~ tr#0-9#A#cds;
    my $length = length("$testname");
    if ( "$length" eq "8" ) {
      my $yyyy = substr($testname,0,4);
      my $mm = substr($testname,4,2);
      my $dd = substr($testname,6,2);
      #$mm = $mm * 1;
      if (( "$yyyy" lt "2000" ) or ( "$yyyy" gt "2020" )) {
        print("Oops, geen geldig jaar gevonden ($yyyy)");
        $testname = "";
      } elsif (( "$mm" lt "0" ) or ( "$mm" gt "13" )) {
        print("Oops, geen geldige maand gevonden ($mm)");
        $testname = "";
      } elsif (( "$dd" le "0" ) or ( "$dd" gt "31" )) {
        print("Oops, geen geldige dag gevonden ($dd)");
        $testname = "";
      }
    } else {
      $testname = "";
    }
  } elsif ( "$type" eq "num" ) {
    $testname =~ tr#0-9#A#cds;
  } elsif ( "$type" eq "index" ) { # for index matching of strings
    $testname =~ tr#a-zA-Z0-9[\.][\xE0][\xE8][\xEC][\xF2][\xF9]##cd;
  } elsif ( "$type" eq "word" ) {
    $testname =~ tr#a-zA-Z[\xE0][\xE8][\xEC][\xF2][\xF9]##cd;
  } elsif ( "$type" eq "email" ) {
    $testname =~ tr#a-zA-Z0-9[\@][\.][\-][\_]#A#cds;
  } else {
    #print ("testname=$testname");
    $testname =~ tr#a-zA-Z0-9#A#cds;
  }
  return $testname;
}

sub getMacDir {
  #doc Get the mac directory based on the ipAddr or hostname (from the devDir)
  #doc syntax: <input>
  my $input = shift;
  if ( &testIfIp($input) ne "oke" ) {
    # hostnames are also allowed.
    my $ipFile = "$SIMparam{'SIMdeviceDir'}/all/$input/ipaddr";
    $input = catFileLine($ipFile);
  }
  my ( $macAddr, $macType ) = &getMacAddr($input);
  printDebug(1, "getMacDir: input=$input, macAddr=$macAddr");
  if ( $macAddr ne "" ) {
    my $macDir = "$SIMparam{'SIMmacDatab'}/$macAddr";
    return $macDir;
  }
}

sub getLogMacDir {
  # allow input of dev name or ip address
  # new sub to get the logMacDir
  my $input = $_[0];
  if ( &testIfIp($input) ne "oke" ) {
    # hostnames are also allowed.
    my $ipFile = "$SIMparam{'SIMdeviceDir'}/all/$input/ipaddr";
    $input = catFileLine($ipFile);
  }
  my $macAddr = getLogMac($input);
  if ( $macAddr ne "" ) {
    my $macDir = "$SIMparam{'SIMmacDatab'}/$macAddr";
    return $macDir;
  }
}


sub getIpDir {
  #doc Return the ip directory
  #doc syntax: <ipAddr>
  my $workDir = shift;
  $workDir =~ s#\.#/#g;
  chomp $workDir;
  $workDir = "$ipDatabaseDir/$workDir";
# printDebug(0, "getIpDir: workDir=$workDir");
  return $workDir;
}

sub shortHostname {
  #doc Get the hostname from an full domainname
  #doc syntax: <testName>
  my $testName = shift;
  $testName = lc($testName);
  my ( $shortName, $dummy ) = split('\.', $testName);
  if ( $shortName eq "" ) {
    $shortName = "none";
  }
  return($shortName);
}
sub getDevDir {
  #doc Get the device dir based on the hostname.txt, if not use the shortName or create one based on the ip.
  #doc syntax: ipAddr, shortName
  my $ipAddr = shift;
  my $shortName = shift;
  if ( $shortName eq "" ) {
    $shortName = "none";
  }
  my $dummy;
  my $ipDir = getIpDir($ipAddr);
  if ( -f "$ipDir/hostname.txt" ) {
    my $hostname = catFileLine("$ipDir/hostname.txt");
    ( $shortName, $dummy ) = split('\.', $hostname);
  }
  #changet
  if ( $shortName eq "none" ) {
    $shortName = $ipAddr;
    $shortName =~ s/\./-/g;
  }
  return( "$SIMparam{'SIMdeviceDir'}/all/$shortName");
}

sub getNodeColor {
  my $ipAddr = "$_[0]";
  my $ipDir = getIpDir( $ipAddr );
  my %ipColor = ();
  $ipColor{ 'Up' } = '#99EE99';
  $ipColor{ 'Down' } = '#FF6600';
  $ipColor{ 'Unmanaged' } = '#33FFFF';
  $ipColor{ 'Confirmed' } = '#DDA0DD';
  $ipColor{ 'New' } = 'yellow';
  my $pollStatus = catFileLine("$ipDir/pollStatus");
  return $ipColor{ $pollStatus};
}

sub testIfIp {
  my $ipAddr = $_[0];
  my $num = ""; if ( defined $_[1] ) { $num = $_[1]; }
  my $range = ""; if ( defined $_[2] ) { $range = $_[2]; }
  
  my $startMin = 1; my $startMax = 223;
  if ( $range eq "all" ) {
    $startMin = 0;  $startMax = 255;
  }
  if ( $num eq "" ) {
    $num = 4;
  }
  my $testIpAddr = $ipAddr;
  $testIpAddr =~ tr#0-9[\.]#A#cds;
# print("ip=$testIpAddr");
  my ( $ip1, $ip2, $ip3, $ip4, $rest ) = split('\.', $testIpAddr);
  if ( $num eq "3" ) {
    # option for scan subnets, etc...
    $testIpAddr = "$ip1.$ip2.$ip3";
  }
# print("ip1=$ip1, ip2=$ip2, ip3=$ip3, ip4=$ip4, ");
  if ( "$rest" ne "" ) {
    return "Oops, to many dots.";
  } elsif ( "$ip4" eq "" ) {
    return "not four parts";
   } elsif (( "$ip1" < "$startMin" ) or ( "$ip1" > "$startMax" )) {
    return "ip1";
   } elsif (( "$ip2" < "0" ) or ( "$ip2" > "255" )) {
    return "ip2";
   } elsif (( "$ip3" < "0" ) or ( "$ip3" > "255" )) {
    return "ip3";
   } elsif ((( "$ip4" < "0" ) or ( "$ip4" > "255" )) and ( $num eq "4" )) {
    return "ip4";
   } elsif ( "$ipAddr" eq "$testIpAddr" ) {
    return "oke";
   } else {
    return "problem with $ipAddr ($testIpAddr)";
   }
}

sub oldLogLine {
  #doc Log info if needed to the device, node and central level.
  #doc syntax: <ipAddr> <errorType> <errorName> <errorMessage> <errorOutput>
  my $ipAddr = shift;
  my $errorType = shift;
  my $errorName = shift;
  my $errorMessage = shift;
  my ( $logDevName, $logMacAddr );
  my $errorOutput = shift;    # messages it the default, syslog infoDir is an option.
  #remoteUser
  my ($dnsName);
  my $ipDir = getIpDir( $ipAddr );
  if ( ! defined $ipDnsName{$ipAddr} ) {
    if ( -f "$ipDir/dnsname.txt" ) {
      my $info = catFileLine("$ipDir/dnsname.txt");
      my ( $type, $hostname, $domain ) = split(' ', $info);
      $ipDnsName{$ipAddr} = "$hostname.$domain";
    } else {
      $ipDnsName{$ipAddr} = $ipAddr;
    }
  }
  my $nowdate = printDate( time, "default" );
  my $errMessage = "$nowdate $ipAddr $ipDnsName{$ipAddr} $errorType $errorName, $errorMessage\n";
  if ( defined $errorOutput ) {
    $errMessage = "$nowdate $errorOutput $ipAddr $errorType $errorName $errorMessage\n";
  }
  my $dispMessage = $errMessage;
  chomp $dispMessage;
  printDebug(1, "logLine: dispMessage=$dispMessage");
  if ((( -d $ipDir ) and ( "$ipAddr" ne "" )) and ( $errorOutput eq "" )) {
    # print the error to the ip log.
    printFileLine("$ipDir/messages","append","$errMessage");
    my $logMac = &getLogMac($ipAddr);
    if ( "$logMac" ne "" ) {
      $logMacAddr = $logMac;
      # print the error to the mac log.
      if ( -d "$macDatabaseDir/$logMac" ) {
        printFileLine("$macDatabaseDir/$logMac/messages","append","$errMessage");
      }
    }
  }
  if ( ! -d $SIMparam{'SIMmessagesDir'} ) {
    printDebug(0, "logLine: SIMmessagesDir=$SIMparam{'SIMmessagesDir'} missing.");
  } else {
    my $dayStr = &printDate( time, "yyyymmdd" );
    # print the error to the general log file
    my $nodeType;
    my $logDestinations = "other";
    if ( $logDestinations{$ipAddr} eq "" ) {
      my $devDir = &getDevDir($ipAddr);
      $logDestinations{$ipAddr} = catFileLine("$devDir/logDestinations");
      # for the host reccords use the owners, need to look if we can integrate both files.
      if ( $logDestinations{$ipAddr} eq "" ) {
        $logDestinations{$ipAddr} = catFileLine("$devDir/owners", "other");
      }
      printDebug(1, "logLine: logDestination $ipAddr = $logDestinations{$ipAddr}");
    }
    if ( $ipVendor{$ipAddr} eq "" ) {
      my $nodeType = catFileLine("$ipDir/nodetype.txt", "undefined");
      $ipVendor{$ipAddr} = catFileLine("$ipDir/vendor", "$nodeType");
      printDebug(1, "logLine: ipVendor $ipAddr = $ipVendor{$ipAddr}");
    }
    my @logGroups = split(' ', $logDestinations{$ipAddr});
    printDebug("1", "errorType=$errorType, errorAllert=$errorAllert{$errorType} nodeManType=$nodeManType{$nodeType}  ");
#   foreach my $key (keys %errorAllert) { print(" $key:$errorAllert{$errorType} "); }
    foreach my $entry (@logGroups) {
      printFileLine("$SIMparam{'SIMmessagesDir'}/$entry-_-$ipVendor{$ipAddr}-_-$dayStr","append","$errMessage");
      if (( "$errorType" eq "note" ) or ( "$errorType" eq "hwChange" )) {
        printFileLine("$SIMparam{'SIMmessagesDir'}/$entry-_-info-_-$dayStr","append","$errMessage");
      }
      if (( "$errorAllert{$errorType}" eq "error" ) or ( "$errorAllert{$errorType}" eq "email" ) or ( "$errorAllert{$errorType}" eq "sms" )) {
        # print special error messages to the error logfile (for the monitor page).
        printFileLine("$SIMparam{'SIMmessagesDir'}/$entry-_-error-_-$dayStr","append","$errMessage");
        if (( "$errorAllert{$errorType}" eq "email" ) or ( "$errorAllert{$errorType}" eq "sms" )) {
          my ( $date, $time, $ipAddr, $dnsName, $type, $message ) = split(' ', $errMessage, 6);
	  printFileLine("$SIMparam{'SIMtmpDir'}/syslogAction-_-$entry-_-$errorAllert{$errorType}-$dnsName","append","($errorAllert{$errorType}) $dnsName $date $time $message");
        }
      }
    }
  }
  # forward error tot syslog
  my ( $facility, $level, $syslogServers ) = split(' ', $SIMparam{'SIMsipman2syslog'});
  if ( $syslogServers ne "" ) {
    my @syslogDestinations = split(':', $syslogServers);
    my $logDevName = &dispHostName($ipAddr, "data");
    $errorMessage =~ s/\\\"//g;
    my $s=new Net::Syslog(Facility=>$facility,Priority=>$level, SyslogPort=>'514');
    foreach my $entry (@syslogDestinations) {
#     printFileLine("/tmp/sipmanSyslogMsg.log", "append", "errorMessage=$errorName, $errorMessage, ipAddr=$ipAddr logDevName=$logDevName, logMacAddr=$logMacAddr., Name=Sipman, SyslogHost=$entry\n");
      $s->send("$errorName, $errorMessage, ipAddr=$ipAddr logDevName=$logDevName, logMacAddr=$logMacAddr.", Name=>"sipmanInfo", SyslogHost=>$entry);
    }
  }
}

sub logLine {
  #doc Log info if needed to the device, node and central level.
  #doc syntax: <ipAddr> <errorType> <errorName> <errorMessage> <errorOutput>
  my $ipAddr = shift;
  my $errorType = shift;
  my $errorName = shift;
  my $errorMessage = shift;

  if ( $errorMessage ne "" ) {
    $errorMessage =~ s/\\\"//g;
#   my $s=new Net::Syslog(Facility=>$facility,Priority=>$level, SyslogPort=>'514');
#   $s->send("$errorName, $errorMessage, ipAddr=$ipAddr logDevName=$logDevName, logMacAddr=$logMacAddr.", Name=>"sipmanInfo", SyslogHost=>$entry);
    my $timeStr = &printDate(time);
    my $hostName = "-";
    &printFileLine("$SIMparam{'QRIsystemSyslog'}/qresponse.log", "append", "$timeStr $hostName $ipAddr $errorName: $errorMessage\n");
  }
}

1;
