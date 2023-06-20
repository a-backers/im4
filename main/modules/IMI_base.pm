package IMI_base;

use strict;
#use IM_base;
#use IM_settings;
require Exporter;

our @ISA 	= ("Exporter");
our @EXPORT	= qw( runCmd getFileLocation %locationCache exitOk
                  getDir readReccord writeReccord
              );
our @VERSION	= 0.1;			# version number

# keep this on top for error handling
BEGIN { 
    #doc Simple error handler, dumps data in readable format
    #future versions will only do this for developers.
    use CGI::Carp qw(fatalsToBrowser set_message);
    sub handle_errors { 
        my $msg = shift; 
        print("<CENTER><P><P><TABLE><TR BGCOLOR=yellow><TD>");
        my $me = $ENV{'REMOTE_USER'} ? $ENV{'REMOTE_USER'} : "UNKNOWN"; 

        # dump a simple message... 
        print "<h1>Sorry, you found an bug.</h1>\n"; 
        print "Something whent wrong when running $0 " . join(' ', @ARGV) . "\n"; 
        print("<HR><PRE>$msg</PRE><HR>");
        print "Please bug your developper to fix the problem\n"; 
        my $dummy = shift(@ARGV);
        my $argList = join('\+', @ARGV);
        system(" $ENV{'QR_BUGTOOL'} autoBug $argList none cgiError: bug found in $0 subDetails: $msg");
        print "</TD></TR></TABLE>>\n"; 
    } 
    set_message(\&handle_errors);
}

sub exitOk {
  print("\n<!-- exitOk -->\n");
  exit(5);
#  exit($ENV{'IM4_EXITOK'});
}

sub runCmd {
  #doc Run external programms and report an error if it exits with an error.
  my $progName = shift;
  my $exitCode = "-";
  system(" $progName 2>&1 ");
  $exitCode = $? >> 8;
  if ( $exitCode ne $ENV{'IM4_EXITOK'} ) {
    print("<BR><B>runCmd: progName=$progName, exitCode=$exitCode</B>");
    &logLine("127.0.0.2","system","scriptError", "Program $progName ($ENV{'REMOTE_USER'}) exited with exitCode $exitCode");
    # report the bug to the bug tool
    system(" $ENV{'QR_BUGTOOL'} autoBug $progName none auto $ENV{'REMOTE_USER'}, runCmd: $progName exited with exitCode $exitCode");
    exit;
  }
}

# read / write file location info
our %locationCache = ();
# add this later to specify the 
# my @dbLocList = &catFileArray($SIMparam{'SIMmainDatabaseInfo'});

sub getDir {
  #doc get directory for ip based entries (for the reporter).
  #doc syntax: <source> <index>
  my $source = shift;
  my $index = shift;
  my $sourceDir;
  if ( defined $locationCache{"$source $index"} ) {
    $sourceDir = $locationCache{"$source $index"};
  } elsif ( $source eq "ip" ) {
    $sourceDir = &getIpDir($index);
  } elsif ( $source eq "hw" ) {
    my $ipDir = &getIpDir($index);
    if ( -f "$ipDir/hwName" ) {
      my $hwName = catFileLine("$ipDir/hwName");
      $sourceDir = "$SIMparam{'SIMhardwareInfoDir'}/$hwName";
    }
  } elsif ( $source eq "fmac" ) {
    $sourceDir = &getLogMacDir($index);
  } elsif ( $source eq "mac" ) {
    my ( $macAddr, $magType ) = &getMacAddr( $index );
    $sourceDir = "$SIMparam{'SIMmacDatab'}/$macAddr";;
  } elsif ( $source eq "dev" ) {
    $sourceDir = &getDevDir($index);
  } elsif ( $source eq "importedDev" ) {
    my $ipDir = getIpDir($index);
    my $hostname;
    if ( -f "$ipDir/hostname.txt" ) {
      $hostname = catFileLine("$ipDir/hostname.txt");
    } elsif ( -f "$ipDir/hwName" ) {
      $hostname = catFileLine("$ipDir/hwName");
    }
    if ( $hostname ne "" ) {
      my ( $shortName, $dummy ) = split('\.', $hostname);
      $sourceDir = "$SIMparam{'SIMdeviceCmdb'}/$shortName";
    }
  } elsif ( $source eq "oid" ) {
    my $ipDir = &getIpDir($index);
    my $oidFile = "$ipDir/snmpoid.txt";
    if ( -f $oidFile ) {
      my $oidInfo = catFileLine($oidFile);
      my ( $oidId, $oidNum ) = split(' ', $oidInfo);
      $sourceDir = "$SIMparam{'SIMoidDir'}/.$oidNum";
    }
  } elsif ( $source eq "logMsg" ) {
    $sourceDir = "$SIMparam{'QRIlogMessages'}/$index";
  }
  $locationCache{"$source $index"} = $sourceDir;
  return($sourceDir);
}

sub getFileLocation {
  #doc module die de lokatie van files in de db opzoekt en cached.
  #doc te gebruiken door de andere lees / schrijf tools.
  my $type = shift; # read or write
  my $db = shift;
  my $page = shift;
  my $reccord = shift;
  my $returnPath = ();
  my $recName = "$db $page";
  my $location = "fs";
  if ( $locationCache{$recName} ne "" ) {
    # cache seems oke :-)
#   printDebug(0, "getFileLocation: return locationCache{$recName} = $locationCache{$recName}");
    $returnPath = "$locationCache{$recName}/$reccord";
  } else {
    if ( $location eq "fs" ) {
      my $returnDir = &getDir($db, $page);
      if ( $type eq "write" ) { 
        # create the directory for the write, once so we donot have to check over and over.
        &testMkDir($returnDir);
      }
      $returnPath = "$returnDir/$reccord";
#     printDebug(0, "getFileLocation: getDir($db, $page), returnPath=$returnPath");
    }
  }
  if ( $returnPath eq "" ) {
    &logLine("127.0.0.2","system","Syntax","getDir: db=$db missing when searching for $db;$reccord in $page");
    &printDebug(0, "getFileLocation: no returnPath for ($db, $page, $reccord), exiting");
    exit;
  } elsif (( $location eq "fs" ) and ( $type eq "write" )) {
    # create the directory for the write, once so we donot have to check over and over.
    &testMkDir($locationCache{$recName});
  }
  return($location, $returnPath);
}

sub readReccord {
  #doc read data from an file. based on the options return the first line (default), an array or an <BR> string. 
  #doc syntax: recInfo, page, options ......
  #doc options: array = return all lines, altern = return value, multi = read multiple files, recList = return the filenames
  my $recInfo = shift; # recInfo used to investigate where used, easyer.
  my $page = shift;
  my ( $db, $reccord ) = split(';', $recInfo);
  my $returnType = "first";
  my $altern;
  foreach my $option (@_) {
    my ( $type, $value ) = split('=', $option);
    if ( $type eq "array" ) {
      # return all lines
      $returnType = "array";
    } elsif ( $type eq "multi" ) {
      # read all files
      $returnType = "multi";
    } elsif ( $type eq "recList" ) {
      # return the reccordlist, eg for ifExist
      $returnType = "recList";
    } elsif ( $type eq "altern" ) {
      # return the default value, if nothing defined.
      $altern = $value;
    }
  }
  my ( $pathType, $pathLocation ) = &getFileLocation("read", $db, $page, $reccord);
  my @return = ();
# printDebug(0, "readReccord: returnType=$returnType");
  if ( $pathType eq "fs" ) {
    my @fileList = $pathLocation;
    if (( $returnType eq "multi" ) or ($returnType eq "recList" )) {
      @fileList = <$pathLocation*>;
    }
    if ( $returnType eq "recList" ) {
      @return = @fileList;
    } else {
      foreach my $fileEntry (@fileList) {
#       printDebug(0, "readReccord: fileEntry=$fileEntry");
        if ( -f $fileEntry ) {
          open ( IN, $fileEntry ) || die "readReccord: cannot open $pathLocation in $pathType.";
          my @data = <IN>;
          close(IN);
          push(@return, @data);
        }
      }
    }
  }
  if ( $altern ne "" ) {
    if ( $return[0] eq "" ) {
      $return[0] = $altern;
    }
  }
  if ( $returnType eq "first" ) {
    chomp($return[0]);
    return($return[0]);
  } else {
    return(@return);
  }
}

sub writeReccord {
  #doc New write tool to replace printFileLine
  #doc syntax: page, options, @reccords, page is db;reccord
  my $recInfo = shift; # recInfo used to investigate where used, easyer.
  my $page = shift;
  my $options = shift;
  my @reccords = @_; # the rest are reccords
  my ( $db, $reccord ) = split(';', $recInfo);
  my @optionList = split(':', $options);
  my %optionItems = ();
  foreach my $entry (@optionList) {
    my ( $option, $info ) = split('=', $entry);
    if ( $info eq "" ) { $info = "defined"; }
    $optionItems{$option} = $info;
  }
  my ( $pathType, $pathLocation ) = &getFileLocation("write", $db, $page, $reccord);
  my $print = "no";
  if ( $pathType eq "fs" ) {
    if ( $optionItems{'append'} eq "defined" ) {
      $print = "append";
      open ( OUT, ">>$pathLocation") || &logDie("printFileLine: cannot append $pathLocation: $!");
    } else {
      my $currInfo = &readReccord($recInfo, $page);
      if ( $currInfo ne $reccords[0] ) {
        $print = "yes";
        open ( OUT, ">$pathLocation") || &logDie("printFileLine: cannot open $pathLocation for writing: $!");
      }
    }
    if ( $print ne "no" ) {
      print OUT @reccords;
      close(OUT);
    }
  }
}

1;
