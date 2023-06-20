#!/usr/bin/perl

use strict;

use lib "../modules";
use IMI_base;
use IM_settings;
use IM_base;


##### Do something before everything else
BEGIN {
  my $action = $ARGV[0];
  my $domain = $ARGV[1];

  # get the env stuff from the config file.
  my $file = "../configs/im.conf";
  open (IN, $file) || die("BEGIN: cannot open $file.");
  my @lines = <IN>;
  close IN;

  foreach my $regel (@lines) {
    chomp $regel;
    my ( $varName, $info ) = split('=', $regel);
    if ( substr($varName, 0, 1) ne "#" ) {
      $ENV{$varName} = $info; 
    }
  }

  $ENV{'IMDomain'} = $domain;
  my $IMbaseDir = $ENV{'IM4_BASEDIR'} || die "Oops, could not find env for IM_BASEDIR";
  $ENV{'PERL5LIB'} = "$IMbaseDir/main/modules";
  our $IMstarterAction = "$action";
}

my $action = $ARGV[0];
my $domain = $ARGV[1];
my $verbose = $ARGV[2];
my ( $progName, $progOption );


##### SUB PROGRAMS
sub logRotate {
  #doc rotate the logfiles, retaining 50 versions
  my $fileName = shift;
  my @nums = ( 1 .. 50 );

  @nums = reverse @nums;

  foreach my $entry (@nums) {
    my $more = $entry + 1;
    my $formatEntry = sprintf("%04d", $entry);
    my $formatMore = sprintf("%04d", $more);
    if ( -f "$fileName.$formatEntry" ) {
      printDebug( 1, " mv -v $fileName.$formatEntry $fileName.$formatMore ");
      # print error to the logs, for better analysis.
      system(" mv $fileName.$formatEntry $fileName.$formatMore 2>&1");
      sleep 1;
    }
  }
  my $formatFirst = sprintf("%04d", 1);
  system(" mv $fileName $fileName.$formatFirst 2>&1 ");
}

sub runProg {
  #doc Test howmany versions are already running and start the program if allowed
  #doc syntax: <action> <progName> <progOption> <maxProg> <verbose>
  my $action = shift;
  my $progName = shift;
  my $progOption = shift;
  my $maxProg = shift;
  my $verbose = shift;
  my $logdir = "$IMparam{'IMlogDir'}/pl-$action";
  my $logfile = "$logdir/$action";

  chomp($IMparam{'IMhostname'});
  my $tmpLog = "$logfile.0000.$IMparam{'IMhostname'}.$$";
  if ( -f $tmpLog ) {
    unlink $tmpLog;
  }

  my @paramInfo = &catFileArray($IMparam{'QRIsipmanStarterCfg'});
  printDebug(0, "runProg: paramInfo = $#paramInfo, action=$action");
  foreach my $line (@paramInfo) {
    chomp($line);
    my ( $type, $actName, $value ) = split(' ', $line);
    if ( $type eq "maxProc") {
      if ( $action eq $actName ) {
        $maxProg = $value;
      }
    }
  }

  printDebug( 0, "progName:$progName, progOption:$progOption, maxProg:$maxProg");
  my $testName = $progName;
  if ( $progOption ne "" ) {
    # we need to test the options also to allow for multiple options to use the same program
    # eg fastPoller and responsePoller.
    $testName = "$progName $progOption";
  }
  
# old test based on ps info, does not work in an docker / multi server environment
# my @currPs = `ps -ef | grep \"$testName\" | grep -v $IMparam{'QRIrunCmd'} | grep -v grep `;
# my $currRunning = @currPs;

  # count the number of loggfiles that are no older than 5 min
  my $testTime = time - 300;
  my @currLogs = <$logfile.0000.*>;
  my $currRunning = 0;
  foreach my $entry (@currLogs) {
    if ( (stat $entry)[9] > $testTime ) {
      $currRunning++;
    } else {
      printDebug(0, "runProg: removing old log $entry");
      unlink($entry);
    }
  }
  my $startTime = time;
  &testMkDir($IMparam{'IMlogDir'});
  if ( ! -d $IMparam{'IMlogDir'} ) {
    die("oops no IMlogDir found ($IMparam{'IMlogDir'})");
  } elsif ( ! -d $logdir ) {
    mkdir "$logdir";
    if ( ! -d $logdir ) {
      logLine("127.0.0.1", "system","STARTER-noDir", "Cannot creat logdir while starting $action (logdir=$logdir).");
      printFileLine($tmpLog, "append", "Cannot creat logdir while starting $action (logdir=$logdir).\n");
    }
  }
  printDebug( 0, "currRunning:$currRunning");
  my $logInfo = ("
      Program name:      $progName
      Program options:   $progOption
      Running processes: $currRunning, max: $maxProg
      TmpLog:            $tmpLog
      Logfile:           $logfile
          \n");
  &printFileLine($tmpLog, "append", $logInfo);
  if ( $currRunning <= $maxProg ) {
    print("Logging to $tmpLog<PRE>");
    my $niceCmd = "nice -6";
    $ENV{'QUERY_STRING'} = "QResponse+Sipman+extra+starter+pl+$action";
    if ( "$verbose" eq "verbose" ) {
      print("  $niceCmd  $IMparam{'QRIrunCmd'} $progName $progOption\n");
      system(" $niceCmd  $IMparam{'QRIrunCmd'} $progName $progOption | tee -a $tmpLog 2>&1 ");
#     system(" $niceCmd  $progName $progOption | tee -a $tmpLog 2>&1 ");
    } else {
      system(" $niceCmd $IMparam{'QRIrunCmd'} $progName $progOption >> $tmpLog 2>&1");
#     system(" $niceCmd $progName $progOption >> $tmpLog 2>&1");
    }
    print("</PRE>");
    # donot test the exit of nice :-(
#   my $exitCode = $? >> 8;
#   if ( $exitCode ne $ENV{'QR_EXITOK'} ) {
#     system(" $ENV{'QR_BUGTOOL'} autoBug Sipman+extra+starter+pl+$action $tmpLog auto script=$IMparam{'QRIrunCmd'} $progName $progOption");
#   } else {
#     printDebug(0, "runProg: exit oke");
#   }
  } else {
    &printFileLine($tmpLog, "append", "Skipping this run. Running processes:\n");
    my $num = 1;
    foreach my $entry (@currLogs) {
      &printFileLine($tmpLog, "append", "    $num: $entry\n");
      $num++;
    }
  }
  my $elapsed = time - $startTime;
  printFileLine($tmpLog, "append", "<HR>This program took $elapsed secconds to finish.");
  if ( -f $logfile ) {
    logRotate $logfile;
  }
  system(" mv $tmpLog $logfile ");
}


##### MAIN PROGRAM
#printDebug( 0, "env:\n");
#system(" env ");
printDebug( 0, "im4-starter.pl action:\"$action\" domain:\"$domain\" verbose:\"$verbose\" IMmanDomain:\"$IMparam{'IMmanDomain'}\".");

$ENV{'REMOTE_USER'} = "starter-$action";
$ENV{'USERLEVEL'} = "6";

##### DO WE HAVE SOMETHING TO DO
if ( "$action" eq "" ) {
  print("im4-starter.pl <action> <domain> <verbose>\n");
} elsif ( "$domain" eq "" ) {
  printDebug(0, "Main: domain not defined");

##### TEST ENV COMMAND
} elsif ( "$action" eq "testEnv" ) {
  print("<PRE>");
  foreach my $k (sort keys %IMparam) {
    my $v = $IMparam{$k};
    print("$k =&gt; $v\n");
  }
  print("</PRE>");

##### REGULAR COMMANDS
} elsif ( "$action" eq "compressLogFiles" ) {
  runProg( $action,  $IMparam{'QRIcompressFiles'}, "", "0", $verbose );
} elsif ( "$action" eq "snmpTrapd" ) {
  runProg( $action,  $IMparam{'IMrestartSnmpTrapd'}, "", "4", $verbose );
} elsif ( "$action" eq "readExchangeInfo" ) {
  runProg( $action,  $IMparam{'IMreadExchangeInfo'}, "", "0", $verbose );
} elsif ( "$action" eq "generate-named" ) {
  runProg( $action,  $IMparam{'IMgenerateNamed'}, "", "0", $verbose );
} elsif ( "$action" eq "discover" ) {
  runProg( $action,  $IMparam{'IMdiscoverNodes'}, "", "0", $verbose );
} elsif ( "$action" eq "importGateways" ) {
  runProg( $action,  $IMparam{'IMimportGateways'}, "", "0", $verbose );
} elsif ( "$action" eq "testNodeStatusAll" ) {
  runProg( $action,  $IMparam{'QRItestNodeStatusAll'}, "", "0", $verbose );
} elsif ( "$action" eq "copyRun" ) {
  runProg( $action,  $IMparam{'IMrunRemoteExec'}, "copyRun all", "0", $verbose );
} elsif ( "$action" eq "importArp" ) {
  runProg( $action,  $IMparam{'IMgetArpTool'}, $IMparam{'IMimportArpPath'}, "0", $verbose );
} elsif ( "$action" eq "retestInfo" ) {
  runProg( $action,  $IMparam{'IMimportSnmpTool'}, "retestInfo", "80", $verbose );
} elsif ( "$action" eq "readDhcpLog" ) {
  runProg( $action,  $IMparam{'IMreadDhcpLogTool'}, "", "20", $verbose );
} elsif ( "$action" eq "importSnmpInfo" ) {
  runProg( $action,  $IMparam{'IMimportSnmpTool'}, "", "100", $verbose );
} elsif ( "$action" eq "pollIndex" ) {
  runProg( $action,  $IMparam{'IMpollDeviceTool'}, "", "0", $verbose );
} elsif ( "$action" eq "responsePoller" ) {
  runProg( $action,  $IMparam{'IMavailPoller'}, "responsePoller", "249", $verbose );
} elsif ( "$action" eq "quickPoller" ) {
  runProg( $action,  $IMparam{'IMquickPoller'}, "", "19", $verbose );
} elsif ( "$action" eq "fastPoller" ) {
  runProg( $action,  $IMparam{'IMavailPoller'}, "fastPoller", "399", $verbose );
} elsif ( "$action" eq "pollUrls" ) {
  runProg( $action,  $IMparam{'IMpollUrls'}, "", "0", $verbose );
} elsif ( "$action" eq "getSplatArp" ) {
  runProg( $action,  $IMparam{'IMsplatArpWrapper'}, "", "0", $verbose );
} elsif ( "$action" eq "restartNetflow" ) {
  runProg( $action,  $IMparam{'IMrestartNetflow'}, "", "2", $verbose );
} elsif ( "$action" eq "sendMailAllerts" ) {
  runProg( $action,  $IMparam{'IMsendMailAllertsTool'}, "", "0", $verbose );
} elsif ( "$action" eq "splitSyslog" ) {
  runProg( $action,  $IMparam{'IMrestartSplitSyslog'}, "", "4", $verbose );
} elsif ( "$action" eq "testHwInfo" ) {
  runProg( $action,  $IMparam{'IMtestHwInfo'}, "", "0", $verbose );
} elsif ( "$action" eq "cleanOldData" ) {
  runProg( $action,  $IMparam{'IMcleanOldData'}, "", "0", $verbose );
} elsif ( "$action" eq "killOldProgs" ) {
  runProg( $action,  $IMparam{'IMkillOldProgs'}, "", "0", $verbose );
} elsif ( "$action" eq "mailIPDatabase" ) {
  runProg( $action,  $IMparam{'IMrunBatch'}, "mailIPDatabase", "0", $verbose );
} elsif ( "$action" eq "mailCurrDevConfigs" ) {
  runProg( $action,  $IMparam{'IMrunBatch'}, "mailDir IMdevConfigCurrent", "0", $verbose );
} elsif ( "$action" eq "cleanIpDatabase" ) {
  runProg( $action,  $IMparam{'IMrunBatch'}, "cleanIpDatabase", "0", $verbose );
} elsif ( "$action" eq "mailSipmanCode" ) {
  runProg( $action,  $IMparam{'IMrunBatch'}, "mailSipmanCode", "0", $verbose );
} elsif ( "$action" eq "checkpointParser" ) {
  runProg( $action,  $IMparam{'IMcheckpointParser'}, "", "0", $verbose );
} elsif ( "$action" eq "importBrocadeInfo" ) {
  runProg( $action,  $IMparam{'IMimportBrocadeInfo'}, "", "0", $verbose );
} elsif ( "$action" eq "ciscoAcsLogReader" ) {
  runProg( $action,  $IMparam{'IMciscoAcsLogRestarter'}, "", "0", $verbose );
} elsif ( "$action" eq "rotateLogFiles" ) {
  runProg( $action,  $IMparam{'IMrotateLogFiles'}, "", "0", $verbose );
} elsif ( "$action" eq "rotateSyslog" ) {
  runProg( $action,  $IMparam{'IMrotateSyslog'}, "", "0", $verbose );
} elsif ( "$action" eq "systemLogReader" ) {
  runProg( $action,  $IMparam{'IMrotateSystemLogReader'}, "", "4", $verbose );
} elsif ( "$action" eq "ciscoLogReader" ) {
  runProg( $action,  $IMparam{'IMrotateCiscoLogReader'}, "", "4", $verbose );
} elsif ( "$action" eq "checkpointLogReader" ) {
  runProg( $action,  $IMparam{'IMrotateCheckpointLogReader'}, "", "4", $verbose );
} elsif ( "$action" eq "rrdPoller" ) {
# runProg( $action,  $IMparam{'IMrrdPoller'}, "", "20", $verbose );
  runProg( $action,  $IMparam{'IMavailPoller'}, "rrdPoller", "25", $verbose );
} elsif ( "$action" eq "runCommands" ) {
  runProg( $action,  $IMparam{'IMrunCommands'}, "", "0", $verbose );
} elsif ( "$action" eq "saveConfigs" ) {
  runProg( $action,  $IMparam{'IMsaveTftpConfigs'}, "", "0", $verbose );
} elsif ( "$action" eq "runCron" ) {
  runProg( $action,  $IMparam{'IMrunCron'}, "", "120", $verbose );
} elsif ( "$action" eq "importFromCmdb" ) {
  runProg( $action,  $IMparam{'IMimportFromCmdb'}, "", "0", $verbose );
} elsif ( "$action" eq "switchInfo" ) {
  runProg( $action,  $IMparam{'IMswitchinfo'}, "", "0", $verbose );
} elsif ( "$action" eq "importDnsReccords" ) {
  runProg( $action,  $IMparam{'IMimportDnsReccords'}, "", "0", $verbose );
} elsif ( "$action" eq "makeTars" ) {
  runProg( $action,  $IMparam{'IMmakeTars'}, "", "0", $verbose );
} elsif ( "$action" eq "testFileage" ) {
  runProg( $action,  $IMparam{'QRItestFileAge'}, "", "0", $verbose );
} elsif ( "$action" eq "generateUrls" ) {
  runProg( $action,  $IMparam{'IMgenerateUrls'}, "", "0", $verbose );
} elsif ( "$action" eq "makeSearchIndex" ) {
  runProg( $action,  $IMparam{'QRImakeSearchIndex'}, "", "0", $verbose );
} else {
  print("Oops, action $action not found");
}

&exitOk();
