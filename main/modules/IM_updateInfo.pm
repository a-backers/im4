package SIM_updateInfo;

#doc Module for updating nodes and reccords in an standardized way
#
require Exporter;
use SIM_settings;
use SIM_base;
use SIM_nodeInfo;

our @ISA 	= ("Exporter");
our @EXPORT	= qw( 
                      testMacEntry addIpNode setManType setRecType setNodeType updField removeIp updHwName modDnsName
                     );
our @VERSION	= 0.01;			# version number

# include variabeles to be used over the various modules here.
#
#

sub modDnsName {
  #doc Change the dns name reccord in the database
  #doc Need to reimplement nsupdate in this module.
  my $ipAddr = shift;
  my $who = shift;
  my $host = shift;
  my $domain = shift;
  my $dnsType = shift;
  my $ipDir = getIpDir($ipAddr);
  my $sourceFile = "$ipDir/dnsname.txt";
  if ( ! -d $ipDir ) {
    printDebug(0, "modDnsName: ipAddr $ipAddr not found.");
  } else {
    my $currVal = catFileLine($sourceFile);
    my $newVal = "$dnsType $host $domain";
    if ( $newVal ne $currVal ) {
      my $hostName = &dispHostName($ipAddr, "data");
      logLine("$ipAddr","dns","Update-node"," DNS info for $ipAddr ($hostName) set by \"$who\" to $newVal ($currVal).");
      printFileLine($sourceFile, "DNS info for $ipAddr ($hostName)", $newVal);
    }
  }
}

sub updHwName {
  #doc Update the hostname with the folowing actions
  #doc run testDnsName, strip the domain part, add the ip node if needed, create the hardware field
  my $ipAddr = shift;
  my $who = shift;
  my $hwName = shift;
  my $ipDir = getIpDir($ipAddr);
  my $sourceFile = "$ipDir/hwName";
  my $currVal = catFileLine($sourceFile);
  if ( $hwName eq "\." ) {
    if ( $currVal ne "" ) {
      unlink $sourceFile;
    }
  } elsif ( $hwName ne "" ) {
    $hwName = testDnsName($hwName); # remove non valid caracters
    my ( $hostPart, $domain ) = split('\.', $hwName);
    if ( $hostPart eq "" ) {
      print("no useable hostname found for $ipAddr.<BR>");
    } else {
      if ( ! -d $ipDir ) {
        &addIpNode( $ipAddr, $who );
      }
      # set hwName
      &updField( $ipAddr, $who, "hwName for $ipAddr changed", $sourceFile, $hostPart );
      # update the ip entry.
      my $longIp = longIp($ipAddr);
      my $ipHwFile = "$SIMparam{'SIMhardwareInfoDir'}/$hostPart/ipInt-$longIp";
      testMkDir("$SIMparam{'SIMhardwareInfoDir'}/$hostPart");
      printFileLine($ipHwFile, "quiet", $ipAddr);
    }
  }
}

sub compareStrings {
  #doc Compare strings and report the caracter where the start to be different.
  my $currVal = shift;
  my $newVal = shift;
  for my $i (0 .. length($currVal)) {
    my $source_base = substr($currVal,$i,1);
    my $str_base    = substr($newVal,$i,1);
    if ($source_base ne $str_base) {
      printDebug(0, "updField: diff $source_base - $str_base at $i.<PRE>o:" . substr($currVal,0,$i) . "<BR>s:$currVal<BR>d:$newVal</PRE>");
    }
  }
}

sub updField {
  #doc Update and report an variable
  #doc syntax: <ipAddr> <who> <recDescr> <recFile> <newVal>
  my $ipAddr = shift;
  my $who = shift;
  my $recDescr = shift;
  my $recFile = shift;
  my $newVal = &stripBE(shift);
# print("setManType: ipAddr=$ipAddr, who=$who, manType=$manType.<BR>");
  my $currVal = catFileLine($recFile);
  chomp $currVal;
  if ( &testIfIp( $ipAddr ) ne "oke" ) {
    $ipAddr = "127.0.0.1";
  }
# my $testedCurrVal = testNameStrict($currVal, "word");
# my $testedNewVal = testNameStrict($newVal, "word");
  if ( "$ipAddr" eq "" ) {
    printDebug("0", "Oops, no ip adress found.");
  } elsif ( "$who" eq "" ) {
    printDebug("0", "Oops, no source found.");
  } elsif ( "$newVal" eq "" ) {
    printDebug("0", "Oops, no new info found for $recDescr on $ipAddr, use \".\" to remove all data.");
# } elsif ( "$testedCurrVal" ne "$testedNewVal" ) {
  } elsif ( "$currVal" ne "$newVal" ) {
    # if no ip directory exists, create it.
    my $ipDir  = getIpDir($ipAddr);
    if ( ! -d $ipDir ) {
      &addIpNode( $ipAddr, $who );
    }
    logLine("$ipAddr","info","Update-node"," $recDescr set by \"$who\" to \"$newVal\" ($currVal).");
    if ( $newVal eq "\." ) {
      print(" removing reccord.<BR>");
      unlink( $recFile );
    } else {
#     print(" $recFile ");
      printFileLine($recFile, "quiet", $newVal);
    }
  } elsif ( -f $recFile ) {
    # update the time of an file (helpful to remove old data).
    my $now = time;
    utime $now, $now, $recFile;
  }
  #print("<BR>");
}

sub removeIp {
  #doc Remove the complete entry in the ipDatabase.
  my $ipAddr = shift;
  my $who = shift;
  my $ipDir  = getIpDir($ipAddr);
  printDebug("0", "removeIp: Removing node $ipAddr.");
  if ( "$ipAddr" eq "" ) {
    print("Oops, no ip adress found.");
  } elsif ( ! -d $ipDir ) {
    print("Oops, no definitions for $ipAddr found.");
  } elsif ( "$who" eq "" ) {
    print("Oops, no source found.");
  } else {
    print(", log");
    &logLine("$ipAddr","system","Remove-ip-node"," definitions for $ipAddr removed by \"$who\".");
    print(", remove");
    system(" rm -fr $ipDir ");
    if ( ! -d $ipDir ) {
      print(" <B>done.</B>");
    } else {
      print(" <B>oops, could not remove entry $ipAddr.</B>");
    }
  }
}

sub setManType {
  #doc Set the management type for an node
  #doc sysntax: <ipAddr> <who> <manType>
  my $ipAddr = shift;
  my $who = shift;
  my $manType = shift;
# print("setManType: ipAddr=$ipAddr, who=$who, manType=$manType.<BR>");
  my $ipDir  = getIpDir($ipAddr);
  my $manFile = "$ipDir/managementtype.txt";
  my $currType = catFileLine($manFile);
  if ( "$ipAddr" eq "" ) {
    printDebug("0", "Oops, no ip adress found.");
  } elsif ( "$who" eq "" ) {
    printDebug("0", "Oops, no source found.");
  } elsif ( "$manType" eq "" ) {
    printDebug("0", "Oops, no management type found.");
  } elsif ( &testIfIp( $ipAddr ) ne "oke" ) {
    printDebug("0", "Oops, $ipAddr not an valid ip address.");
  } elsif ( $currType ne $manType ) {
    if ( ! -d $ipDir ) {
      &addIpNode( $ipAddr, $who );
    }
#   printFileLine($nodeFile,"nodetype $ipAddr", $nodeType);
    printFileLine($manFile,"quiet", $manType);
    logLine("$ipAddr","system","Update-node"," management type for $ipAddr set by \"$who\" to $manType ($currType).");
  }
}

sub setRecType {
  #doc set the reccordType for an node and log the action
  #doc syntax: <ipAddr> <who> <recType>
  my $ipAddr = shift;
  my $who = shift;
  my $recType = shift;
  my $ipDir  = getIpDir($ipAddr);
  my $recFile = "$ipDir/sipmanrectype.txt";
  my $currType = catFileLine($recFile);
  if ( "$ipAddr" eq "" ) {
    printDebug("0", "Oops, no ip adress found.");
  } elsif ( "$who" eq "" ) {
    printDebug("0", "Oops, no source found.");
  } elsif ( "$recType" eq "" ) {
    printDebug("0", "Oops, no reccord type found.");
  } elsif ( &testIfIp( $ipAddr ) ne "oke" ) {
    printDebug("0", "Oops, $ipAddr not an valid ip address.");
  } elsif ( $recType eq "DEL" ) {
    &removeIp( $ipAddr, $who );
  } elsif ( $currType ne $recType ) {
    if ( ! -d $ipDir ) {
      &addIpNode( $ipAddr, $who );
    }
#   printFileLine($nodeFile,"nodetype $ipAddr", $nodeType);
    printFileLine($recFile,"quiet", $recType);
    logLine("$ipAddr","system","Update-node"," reccordtype for $ipAddr set by \"$who\" to $recType ($currType).");
  }
}

sub setNodeType {
  #doc Set the nodeType for an node and report the action
  #doc syntax: <ipAddr> <who> <nodeType>
  my $ipAddr = shift;
  my $who = shift;
  my $nodeType = shift;
  my $ipDir  = getIpDir($ipAddr);
  my $nodeFile = "$ipDir/nodetype.txt";
  my $currType = catFileLine($nodeFile);
  if ( "$ipAddr" eq "" ) { 
    printDebug("0", "Oops, no ip adress found.");
  } elsif ( "$who" eq "" ) { 
    printDebug("0", "Oops, no source found.");
  } elsif ( &testIfIp( $ipAddr ) ne "oke" ) {
    printDebug("0", "Oops, $ipAddr not an valid ip address.");
  } elsif (( $currType ne $nodeType ) and ( $nodeType ne "" )) { 
#   printFileLine($nodeFile,"nodetype $ipAddr", $nodeType);
    if ( ! -d $ipDir ) {
      &addIpNode( $ipAddr, $who );
    }
    printFileLine($nodeFile,"quiet", $nodeType);
    logLine("$ipAddr","system","Update-node"," nodetype for $ipAddr set by \"$who\" to $nodeType ($currType).");
  }
}

sub addIpNode {
  #doc Add an ip node and set ip to New and Confirmed
  #doc syntax: <ipAddr> <who>
  my $ipAddr = shift;
  my $who = shift;
  my $ipDir  = getIpDir($ipAddr);
  if ( ! -d $ipDir ) {
    system(" mkdir -p $ipDir ");
    logLine("$ipAddr","new","Node-added","$ipAddr added to the database by \"$who\".");
    # node type to new
    setNodeType( $ipAddr, "addIpNode", "New" );
    updateNodeStatus($ipAddr, "addIpNode", "Confirmed");
  }
}

sub testMacEntry {
  #doc Test if an mac address is an valid mac adres we want to have in the database
  #doc Skip stuff like broadcast, hsrp adresses etc..
  #doc syntax: <ipAddr> <macAddr> <logUser>
  my $ipAddr = shift;
  my $macAddr = shift;
  my $logUser = shift;
  my $ipDir  = getIpDir($ipAddr);
  # ( substr($macAddr, 0, 14) eq '00:00:0c:07:ac' ) or # hsrp mac's nolonger skipped, usefull in debugging
  if (( $macAddr eq '00:00:00:00:00:00' ) or ( $macAddr eq '00:00:20:00:00:00' ) or ( $macAddr eq '00:00:21:00:00:00' ) or
      ( $macAddr eq 'ff:ff:ff:ff:ff:ff' ) or
      ( substr($macAddr, 0, 14) eq '00:07:b4:00:01' ) or
      ( substr($macAddr, 0, 11) eq '00:07:b4:01' )) {
    # skip some types of mac adresses.
    printDebug("0", "Skipping mac $macAddr.");
  } elsif (( "$ipAddr" eq "0.0.0.0" ) or ( substr($ipAddr, 0, 3) eq "127" )) {
    # skip some types of ip adresses
    printDebug("0", "Skipping ipAddr $ipAddr.");
  } else {
    if ( ! -d $ipDir ) {
      addIpNode( $ipAddr, "testMacEntry" );
    }
    my $longIp = longIp($ipAddr);
    # always update the mac entries, to find the most recent entry
    &updField($ipAddr, "$logUser", "arp mac changed for $ipAddr,", "$ipDir/arpmac.txt", "$macAddr");
#   if ( "$currMac" ne "$macAddr" ) {
#     printDebug("0", "Updating $ipAddr with mac $macAddr.");
#     printFileLine("$ipDir/arpmac.txt","ipMac:$ipAddr","$macAddr");
#   }
    my $macDir = "$SIMparam{'SIMmacDatab'}/$macAddr";
    if ( ! -d $macDir ) {
      printDebug("0", "Creating macDir for $ipAddr with mac $macAddr.");
      mkdir $macDir;
    }
    printFileLine("$macDir/arp-ipaddr-$longIp.txt","arp-mac-$ipAddr",$ipAddr);
  }
}

1;
