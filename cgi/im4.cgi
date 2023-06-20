#!/usr/bin/perl

#doc Main cgi to start all sub tooling. Responsible for security, param checking, error checking, etc...
#BEGIN { $Exporter::Verbose=1 }

# Umbrella script for Sipman and Glimmer
# This scrip will check basic authentication services and menu's.

use lib "./main/modules";
use strict;
use QRE_accessRights;
use Time::HiRes qw(time);

#doc removed cmdline options and replaced them with QUERY_STRING arguments for lighttpd support.
# removed options, moved for lighttpd
#my ($QRDomain, $QRApplication, $QRTool, $QRModule, $QROption1, $QROption2, $QROption3, $QROption4, $QROption5, $QROption6, $QROption7, $QROption8, $QROption9) = @ARGV;

# menu options for lighttpd.
my @cmdArgs = split('\+', $ENV{'QUERY_STRING'});
my ($QRDomain, $QRApplication, $QRTool, $QRModule, $QROption1, $QROption2, $QROption3, $QROption4, $QROption5, $QROption6) = @cmdArgs; # only 10 options supported in the shell

my %timeRef = ();
$timeRef{'startTime'} = time;

my ( $accessDir, $userLevel, $domainDir, $exitCode );
my $firstEntry = "no";
my $appName = "none";
# ---------- Init variables -------
my $version = "0.0001";
# ---------- external readable parameters -------
## Functions
##-------------------------------------------------------

my ( $httpScriptName, $remoteUser );
#

# Find my own cookie (in case others get injected)
my @cookies = split('; ', $ENV{'HTTP_COOKIE'});
my $currCookieKey;
foreach my $entry (@cookies) {
  if ( index($entry, "QRMsession") ne "-1" ) {
    $currCookieKey = $entry;
    last;
  }
}

sub printFileLine {
  my $fileName = shift;
  my $action = shift;
  my $info = shift;
  if ( $action eq "append" ) {
    open( OUT, ">>$fileName" ) || print ("\n<!-- printFileLine, could write $info to $fileName. -->");
  } else {
    open( OUT, ">$fileName" ) || print ("\n<!-- printFileLine, could write $info to $fileName. -->");
  }
  print OUT ("$info");
  close OUT;
}

sub printEntry2 {
  #doc print menu items, incorporated here to limit the stuff we need to include
  # compare opt1 to var1 to display
  my $name = shift;
  my $description = shift;
  my $opt1 = shift;
  my $var1 = shift;
  my $varRest = shift;
  my $type = shift;
  my $separator = shift;
  my $color = shift;
  my $alternative = shift;
  my $reqLevel = testLevel("$var1+$varRest");
  print("<!-- name: $name, var1: $var1, reqLevel: $reqLevel, userLevel: $userLevel -->\n");
  if ( "$reqLevel" > "$userLevel" ) {
    if ( $alternative ne "" ) {
      # allow to print the text if no update access is possible.
      if ( "$type" eq "line" ) {
        print(" $separator $alternative\n");
      } elsif ( "$type" eq "table" ) {
        print("<TR><TD>$alternative</TD><TD>$description</TD></TR>\n");
      }
    }
  } else {
    if ( "$type" eq "line" ) {
      if ( "$firstEntry" eq "yes" ) {
        $separator = "";
        $firstEntry = "no";
      }
      if ( "$opt1" eq "$var1" ) { $color = "red"; }
      print(" $separator <A HREF=$httpScriptName?$var1+$varRest TITLE=\"$description\"><FONT COLOR=$color>$name</FONT></A>\n");
#     Display level (for debugging)
#     print("<FONT COLOR=$color>($reqLevel)</FONT>");
    } elsif ( "$type" eq "table" ) {
      print("<TR><TD><A HREF=$httpScriptName?$var1+$varRest><FONT COLOR=blue>$name</FONT></A></TD>
                 <TD>$description</TD></TR>\n");
    } elsif ( "$type" eq "link" ) {
      if ( "$opt1" eq "$var1" ) { $color = "red"; }
      print("<LI><A HREF=$httpScriptName?$var1+$varRest TITLE=\"$description\"><FONT COLOR=$color>$name</FONT></A>\n");
    } else {
      print("name=$name, description=$description, opt1=$opt1, var1=$var1, varRest=$varRest, type=$type, separator=$separator, color=$color<BR>");
    }
  }
}

#


sub printHeader {
  #doc The html header
  my $info = shift;
  my $headerOptions = shift;
  # the first few lines without spaces
  print ("HTTP/1.0 200 OK\r\n");
  if ( $info eq "api" ) {
    print ("Content-Type: text/plain\r\n");
  } else {
    if ( $currCookieKey eq "" ) {
      my $random = int(rand(10000000));
#     $ENV{'HTTP_COOKIE'} = "QRMsession=$random";
      $currCookieKey = "QRMsession=$random";
    }
    print ("Content-Type: text/html\r
Pragma: nocache\r
\r
<HTML>\r
  <HEAD>
    <link rel=stylesheet type=\"text/css\" href=/QR/main/css/themes/g4/theme.glimmer.css>
    <link rel=stylesheet type=\"text/css\" href=/QR/main/css/themes/g4/glimmermenu.css>
    <link rel=stylesheet type=\"text/css\" href=/QR/main/css/themes/SIM/stylesheet.txt>
    <meta http-equiv=\"Set-Cookie\" content=\"$currCookieKey\">
    <LINK REL=icon HREF=/QR/main/gifs/favicon.ico type=\"image/x-icon\">
         ");
  my $browser = $ENV{'HTTP_USER_AGENT'};
  # tijdelijk loggen users
  if ( $browser =~ /Trident|MSIE/) {
    print("<meta http-equiv=\"X-UA-Compatible\" content=\"IE=edge,chrome=1\" />");
  }
  
  my $hostName = `/bin/hostname`;
  print("
    <TITLE>
    QR $hostName $info
    </TITLE>
    $headerOptions
         ");
#   &logoutFunction;
  print("
    </HEAD>
    <BODY STYLE=\"background: url(/QR/main/backgrounds/worldmap-blue.jpg) no-repeat center center fixed; -webkit-background-size: cover; -moz-background-size: cover; -o-background-size: cover; background-size: cover;\">
       ");
  }
}

sub logoutFunction2 {
print("<SCRIPT type=\"text/javascript\">
    function logout(to_url) {                                                                                                                                                                                     
      console.log(\"Logging out\");                                                                                                                                                                               
      // For IE                                                                                                                                                                                                   
      document.execCommand(\"ClearAuthenticationCache\");                                                                                                                                                         
                                                                                                                                                                                                                  
      var out = window.location.href.replace(/:\/\//, '://log:out@');                                                                                                                                             
      jQuery.get(out).error(function() {                                                                                                                                                                          
          window.location = to_url;                                                                                                                                                                               
      });                                                                                                                                                                                                         
    }                                                                                                                                                                                                             
         </SCRIPT>"); 
}

sub logoutFunction {                                                                                                                                                                                              
  print("<script type=\"text/javascript\">
  function logout() {
    var xmlhttp;
    if (window.XMLHttpRequest) {
          xmlhttp = new XMLHttpRequest();
    }
    // code for IE
    else if (window.ActiveXObject) {
      xmlhttp=new ActiveXObject(\"Microsoft.XMLHTTP\");
    }
    if (window.ActiveXObject) {
      // IE clear HTTP Authentication
      document.execCommand(\"ClearAuthenticationCache\");
      window.location.href='/index.html';
    } else {
        xmlhttp.open(\"GET\", '/QR/main/css/themes/SIM/stylesheet.txt', true, \"logout\", \"logout\");
        xmlhttp.send(\"\");
        xmlhttp.onreadystatechange = function() {
            if (xmlhttp.readyState == 4) {window.location.href='/index.html';}
        }
    }
    return false;
  }
  <A/script>");
}

sub closeTable {
  print ("
  </FONT>
  </TD></TR></TABLE>
         ");
}
  
sub printFooter {
  my $tool = shift;
  my $dummy = shift(@cmdArgs);
  my $url = join('+', @cmdArgs);
  my $elapsed = time - $timeRef{'startTime'};
  my $loadMod = $timeRef{'startMain'} - $timeRef{'startTime'};
  my $dLoadMod = sprintf('%.3f', $loadMod);
  my $headTime = $timeRef{'afterHead'} - $timeRef{'startMain'};
  my $dHeadTime = sprintf('%.3f', $headTime);
  my $menuTime = $timeRef{'afterMenus'} - $timeRef{'afterHead'};
  my $dMenuTime = sprintf('%.3f', $menuTime);
  my $appTime = time - $timeRef{'afterMenus'};
  my $dAppTime = sprintf('%.3f', $appTime);
  my $version = &catFile("$ENV{'IM4_MAINDIR'}/configs/version");
  my ($sec,$min,$hour,$mday,$mon,$jaar,$wday,$yday,$isdst) = localtime(time);
  my @z2 = ('00' .. '60');
  $mon++;
  $jaar = $jaar + 1900;
  my $time = ("$z2[$mday]-$z2[$mon]\-$jaar $z2[$hour]\:$z2[$min]\:$z2[$sec]");
  my $textColor = "#FFFFFF";
  if ( $exitCode ne "5" ) { 
    $textColor = "yellow";
    system(" $ENV{'IM4_BUGTOOL'} autoBug $url none runPlugin: $appName by $ENV{'REMOTE_USER'}");
  }
  if ( $tool eq "api" ) {
    print("\n# Done. load: $dLoadMod / head: $dHeadTime, total: " . substr($elapsed, 0, 5) . " secs at $time.");
  } else {
#       <FONT SIZE=-1>
#       </FONT>
    print("
    <div style=\"height: 25px;\"></div>
    <FOOTER>
      <DIV ALIGN=center>
        <FONT SIZE=-1>
          (c) 2015 <A HREF=www.qresponse.net><FONT COLOR=#FFFFFF>QResponse.net</FONT></A>, All rights reserved &nbsp; version: $version &nbsp;
          <FONT COLOR=$textColor>
          load: $dLoadMod /
          head: $dHeadTime /
          menu: $dMenuTime /
          app: $appName $dAppTime, &nbsp;
          total: " . substr($elapsed, 0, 5) . " secs.
          $time
        </FONT>
      </DIV>
    </FOOTER>
    </BODY></HTML>
    ");
  }
}

sub setEnv {
  my $file = $_[0];
  open (IN, $file) || die("setEnv: cannot open $file.");
  my @lines = <IN>;
  close IN;
  foreach my $regel (@lines) {
    chomp $regel;
    my ( $varName, $info ) = split('=', $regel);
    if ( substr($varName, 0, 1) ne "#" ) {
      $ENV{$varName} = $info;
    }
  }
}

sub setBase {
  &setEnv("/var/im4/main/configs/im.conf");
  $httpScriptName = $ENV{'SCRIPT_NAME'};
  if ( $httpScriptName eq "" ) { $httpScriptName = "no-http"; $ENV{'SCRIPT_NAME'} = "no-http"; }
  $remoteUser = $ENV{'REMOTE_USER'};
  if ( $remoteUser eq "" ) { $remoteUser = "no-User"; $ENV{'REMOTE_USER'} = "no-User"; }
}

sub getDomain {
  # get the user domain and access level.
  my $baseDomain = $_[0];
  $domainDir = $ENV{'IM_DATADIR'};
  my $passwdDir = $ENV{'PASSWD_DIR'};
  my $returnDomain;
  if ( $baseDomain eq "" ) {
    $baseDomain = "none";
  }
  my $groupName = catFile("$passwdDir/users/$remoteUser/group");
  printFileLine("$passwdDir/users/$remoteUser/lastIP", "quiet", "$ENV{'REMOTE_ADDR'} $ENV{'HTTP_USER_AGENT'}");
  if (( -f "$passwdDir/groups/$groupName/accessLevel-$baseDomain") and ( -d "$domainDir/$baseDomain")) {
    $ENV{'USERLEVEL'} = catFile("$passwdDir/groups/$groupName/accessLevel-$baseDomain");
    $returnDomain = $baseDomain;
#   print("<!-- returnDomain: $returnDomain accessLevel-$baseDomain -->");
  } elsif (( -f "$passwdDir/groups/$groupName/accessLevel-all") and ( -d "$domainDir/$baseDomain")) {
    $ENV{'USERLEVEL'} = catFile("$passwdDir/groups/$groupName/accessLevel-all");
    $returnDomain = $baseDomain;
#   print("<!-- returnDomain: $returnDomain accessLevel-all -->");
  } elsif ( ! -d $domainDir ) {
    print("<!-- no SIM_DATADIR found -->");
  } else {
    chdir $domainDir;
    my @domainList = <*>;
    foreach my $entry (@domainList) {
      my $testFile = ("$passwdDir/groups/$groupName/accessLevel-$entry");
      if ( -f $testFile ) {
        $returnDomain = $entry;
        $ENV{'USERLEVEL'} = catFile("$testFile");
        last;
      }
    }
    if ( $returnDomain eq "" ) {
      $returnDomain = $domainList[0];
      $ENV{'USERLEVEL'} = catFile("$passwdDir/groups/$groupName/accessLevel-all");
    }
  }
  $userLevel = $ENV{'USERLEVEL'};
  return($returnDomain);
}

sub printMenuCgi {
  #doc Print an dynamic menu line based on the url path sofar
  #doc syntax: <level> <baseLink> <currURL> <menuName> <menuType>
  my $level = shift;
  my $baseLink = shift;
  my $currURL = shift;
  my $menuName = shift;
  my $menuType = shift;
  my $returnVal = "";
# print("printMenuCgi: level=$level, baseLink=$baseLink, currURL=$currURL, menuName=$menuName, menuType=$menuType");
  if ( $menuType eq "" ) { $menuType = "line"; }
  if ( $menuName eq "" ) {
    print("printMenuCgi: menuName empty");
  } elsif ( ! -f "$ENV{'QR_MENUDIR'}/$menuName" ) {
    print("printMenuCgi: menuName=$menuName missing ($ENV{'QR_MENUDIR'}/$menuName).");
#   system(" env ");
  } else {
    open(IN, "$ENV{'QR_MENUDIR'}/$menuName" );
    my @info = <IN>;
    close IN;
    my %baseInfo;
    my $backMenu = "QR_L${level}_BACK";
#   my $sepMenu  = "QR_L${level}_SEP";
    my $linkMenu = "QR_L${level}_LINK";
    my $textMenu = "QR_L${level}_TEXT";
    if ( $menuType eq "link" ) { $linkMenu = "QR_L1_LINK"; }
    if (( $level ne 1 ) and ($menuType ne "link" )) {
      print("</TD></TR><TR BGCOLOR=$ENV{$backMenu}><TD>");
    }
#   print("backMenu: $backMenu");
#   system(" env | grep BACK ");
    my $space = " &nbsp; ";
    foreach my $line (@info) {
      chomp $line;
      my ( $type, $var1, $var2, $var3, $var4, $var5 ) = split(' ', $line, 6);
      if ( $type eq "basedir" ) {
        $baseInfo{$var1} = $var2;
      } elsif ( $type eq "sep" ) {
        if ( $menuType eq "link" ) {
          print("<LI>&nbsp; $var1 $var2 $var3 $var4 $var5</LI>");
        } else {
          print(" &nbsp; <B>$var1 $var2 $var3 $var4 $var5</B>  &nbsp; ");
        }
        $space = "";
      } elsif ( $type eq "name" ) {
        if ( $menuType eq "line" ) {
          $var1 = "$var1:";
          $var1 = "<B>$var1</B>";
          print("&nbsp; <FONT COLOR=$textMenu>$var1</FONT> ");
          $space = "";
        }
      } elsif ( $type eq "menu" ) {
        my $dispColor = $ENV{$linkMenu};
        if ( $var1 eq "QRDomain" ) {
          if ( $var1 ne "" ) {
            $var1 = "$QRDomain";
          } else {
            # if no domain is specified, simply print QR
            $var1 = "QResponse";
          }
          $dispColor = "#0080FF";
        }
        if ( $level < 2 ) {
          $var1 = "<B>$var1</B>";
        }
#       printEntry2("$var1", "$var2 $var3 $var4 $var5", "$baseLink+$currURL", "$baseLink+$var2", "", $menuType, "$space", "$dispColor", "$var1");
        # hide entry if not allowed
        printEntry2("$var1", "$var2 $var3 $var4 $var5", "$baseLink+$currURL", "$baseLink+$var2", "", $menuType, "$space", "$dispColor", "");
        $space = " &nbsp; ";
        if ( $menuType eq "link" ) {
          print("<UL>\n");
          my $subMenu = "$menuName+$var2";
          my $newLevel = $level + 1;
          if ( $menuName eq "MainMenu" ) {
            $subMenu = $var2;
          }
          if ( -f "$ENV{'QR_MENUDIR'}/$subMenu" ) {
            printMenuCgi( $newLevel, "$QRDomain+$subMenu", "$subMenu", $subMenu, $menuType);
          }
          print("</UL></LI>");
        }
      } elsif ( $type eq "exe" ) {
        if ( -x "$baseInfo{$var3}/$var4" ) {
          if ( $level < 2 ) {
            $var1 = "<B>$var1</B>";
          }
#       print("<BR>= $baseLink+$currURL $baseLink+$var2 =");
#         printEntry2("$var1", "$var5", "$baseLink+$currURL", "$baseLink+$var2", "", $menuType, "$space", "$ENV{$linkMenu}", "$var1");
          # hide entry if not allowed
          printEntry2("$var1", "$var5", "$baseLink+$currURL", "$baseLink+$var2", "", $menuType, "$space", "$ENV{$linkMenu}", "");
#         print("</LI>");
          $space = " &nbsp; ";
        }
      } elsif ( $type eq "form" ) {
        if ( $menuType ne "link" ) {
          print(" &nbsp; <FORM style=\"display:inline;\" method=post Action=$httpScriptName?$baseLink+$var2>$var5</FORM>\n");
        }
      } elsif (( $type eq "hide" ) and ( $var2 eq "thisMenu" )) {
        $returnVal = $var2;
#       print(" exe=$var3/$var4, returnVal=$returnVal ");
      }
    }
  }
  return($returnVal);
}

sub testAndExecute {
  my $url = $_[0];
  my $menu = $_[1];
  my $menuEntry = $_[2];
  my ( $domain, $application, $tool, $v1, $v2, $v3, $v4, $v5, $v6, $v7 ) = split('\+', $url);
  if ( $menu eq "" ) {
    # allow direct tools from the main menu.
    $menu = "MainMenu";
  }
  if ( $menuEntry eq "" ) {
    &printMessage("Select.", "Select an option above");
  } elsif ( ! -f "$ENV{'QR_MENUDIR'}/$menu") {
    print("Error.", "Sorry, menu $menu not found."); 
  } else { 
    open(IN, "$ENV{'QR_MENUDIR'}/$menu");
    my @info = <IN>;
    close IN;
    my %baseInfo;
    my $testExe = "no";
    foreach my $entry (@info) {
      chomp $entry;
      my ( $type, $menu, $ttool, $dir, $exe ) = split(' ', $entry);
#     print("testAndExecute: type $type, entry $entry, ttool $ttool, exe $baseInfo{$dir}/$exe.<BR>");
      if ( $type eq "basedir" ) {
        $baseInfo{$menu} = $ttool;
#       &printMessage("Debug", "baseInfo for $menu = $ttool");
      } elsif ((( $type eq "exe" ) or ( $type eq "hide" ) or ( $type eq "form" )) and (( $menuEntry eq $ttool ) or ( $ttool eq "any" ))) {
        $appName = $exe;
        if ( -x "$baseInfo{$dir}/$exe" ) {
          system(" $baseInfo{$dir}/$exe $domain $application $tool $v1 $v2 $v3 $v4 $v5 $v6 $v7 2>&1 ");
          $exitCode = $? >> 8;
#         if ( $exitCode ne "5" ) {
#           print("<TABLE><TR BGCOLOR=yellow><TD>Oops, error code = $exitCode, bug your develloper to fix this.</TD></TR></TABLE>");
#         }
        } else {
          &printMessage("Test and execute.", "Tool $baseInfo{$dir}/$exe not found in $dir.\n");
        }
        $testExe = "yes";
        last;
#     } else {
#       print("$entry<BR>");
      }
    }
    if ( $testExe eq "no" ) {
#     &setEnv($application);
      print("<P><CENTER><DIV CLASS='list'><DIV CLASS='listhead'>Oops.</DIV>
           <DIV CLASS='listwrap'>
             <H2>Nothing sensible found in the menu $menu for \"$menuEntry\".</H2>
           </DIV></DIV>");
    }
  }
}

sub printDate {
  my $timestamp = "$_[0]";
  my $paramType = "$_[1]";
  my $type = "default";
  if (  "$paramType" ne "" ) {
    $type = $paramType;
  }
  my ($sec,$min,$hour,$mday,$mon,$jaar,$wday,$yday,$isdst) = localtime($timestamp);
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

sub printMessage {
  my $head = shift;
  my $msg = shift;
  print("<P><CENTER>
           <DIV CLASS='list'><DIV CLASS='listhead'>$head</DIV>
           <DIV CLASS='listwrap'>
           <H2>$msg</H2>");
  print("</DIV></DIV>");
}

sub testInputVars {
  #doc test the input parameters
  my $result = "oke";
  my $num = 0;
  foreach my $entry (@_) {
    $num++;
#   print(" entry=$entry");
    if ( &testNameStrict($entry) ne $entry ) {
      $result = "Invalid input in variable $num.";
      last;
    } elsif ( length($entry) > 140 ) {
      $result = "Variable $num to long (" . length($entry) . ").";
      last;
#   } else {
#     &printMessage("Debug", "entry=$entry.");
    }
  }
  return($result);
}

sub testNameStrict {                                                                                                                                                                                              
  #doc stripped version for cgi
  my ($testname) = shift;                                                                                                                                                                                         
  #doc testing based on email syntax, but may be altered.
  $testname =~ tr#a-zA-Z0-9[\@][\.][\-][\_][\:][\;]#A#cds;
  return("$testname");
}

sub test2FactAuth {
  #doc Test is we have two factor authentication for this user and if it is still valid.
  my $return = "oke";
  my $authType = &catFile("$ENV{'SIM_USERSETTINGSDIR'}/twoFactorAuth-$ENV{'REMOTE_USER'}");
# print("authType=$authType");
  if ( $authType eq "Google authenticator" ) {
    my $testFile = "$ENV{'SIM_USERSETTINGSDIR'}/authSession-$ENV{'REMOTE_USER'}-$ENV{'REMOTE_ADDR'}";
#   print("test2FactAuth: testFile=$testFile");
    my $updTime = (stat($testFile))[9];
    my $elapsed = time - $updTime;
    my $sessionInfo = &catFile($testFile);
    my ( $oldIpAddr, $longTimer ,$cookie ) = split(' ', $sessionInfo);
    my ( $dummy, $sessionKey ) = split('=', $currCookieKey);
    if ( $ENV{'REMOTE_ADDR'} eq "127.0.0.1" ) {
      utime(time, time, $testFile);
    } elsif ( ! -f $testFile ) {
      $return = "No session info found for $ENV{'REMOTE_ADDR'}.";
    } elsif ( $cookie ne $currCookieKey ) {
      $return = "No valid session detected, $currCookieKey, was $cookie, $sessionInfo.";
    } elsif ( $elapsed > 1800 ) {
      if ( time > $longTimer ) {
        $return = "Last activity $elapsed secconds ago on $ENV{'REMOTE_ADDR'}.";
      } else {
        utime(time, time, $testFile);
      }
    } else {
      utime(time, time, $testFile);
    }
  }
# print(", return=$return");
  return($return);
}


# ------------------------------------- Main ---------------------------------------
$timeRef{'startMain'} = time;
&setBase;
# set the default exit code.
$exitCode = $ENV{'QR_EXITOK'};

$accessDir = "none";
if ( -d "$domainDir/$QRDomain/cmdb/accessrights" ) {
  $accessDir = "$domainDir/$QRDomain/cmdb/accessrights";
} else {
  $accessDir = "$ENV{'SIM_SHAREDDIR'}/cmdb/accessrights";
}
$ENV{'QRAccessDir'} = $accessDir;

# get user level and domain.
$QRDomain = &getDomain($QRDomain);
#$QRDomain = &getDomain;
$ENV{'QRDomain'} = $QRDomain;
$ENV{'QRAppName'} = $QRApplication;

# Get the default action for an subdomain
if (( $QRApplication ne "" ) and ( $QRTool eq "" )) {
  my $groupName = catFile("$ENV{'PASSWD_DIR'}/users/$remoteUser/group");
# print("<!-- $ENV{'PASSWD_DIR'}/groups/$groupName/defaultAction-$QRApplication -->");
  if ( -f "$ENV{'PASSWD_DIR'}/groups/$groupName/defaultAction-$QRApplication" ) {
    my $urlInfo = catFile("$ENV{'PASSWD_DIR'}/groups/$groupName/defaultAction-$QRApplication");
#   print("<!-- urlInfo: $urlInfo -->");
    ($QRApplication, $QRTool, $QRModule, $QROption1, $QROption2) = split('\+', $urlInfo);
  }
}

my $appLevel = &testLevel("$QRDomain+$QRApplication+$QRTool+$QRModule+$QROption1+$QROption2");
if ( $QRApplication eq "" ) {
  # the default level must be one, the tool will filter the possible options/
  $appLevel = 1;
}
# test for header options
my $options = "$QRApplication+$QRTool+$QRModule+$QROption1+$QROption2";
$options =~ s/\++$//;
my $headerOpts;
if ( -f "$ENV{'QR_HEADEROPTS'}/$options" ) {
  open(IN, "$ENV{'QR_HEADEROPTS'}/$options") || die ("Could not read $ENV{'QR_HEADEROPTS'}/$options.");
  my @info = <IN>;
  $headerOpts = join("\n", @info);
  close IN;
}
if ( $QRTool eq "api" ) {
  &printHeader("api","");
} else {
  &printHeader("$userLevel/$appLevel $QRDomain", $headerOpts);
}
$timeRef{'afterHead'} = time;
if ( $QRTool ne "api" ) {
  my $time = printDate( time, "hhmmss"); 
  my $dispStartTime = printDate( $timeRef{'startTime'},  "hhmmss"); 
  print("\n<!-- timer: startTime=$dispStartTime, now=$time -->");
}

#print("blablablabla dummy to be displayed behind menu");
 print("\'");

# test if the password is expired (and the user is locally defined)
if ( -f "$ENV{'SIM_USERSETTINGSDIR'}/pwdUpdTime-$ENV{'REMOTE_USER'}" ) {
  my $expireTime = catFile("$ENV{'SIM_USERSETTINGSDIR'}/pwdUpdTime-$ENV{'REMOTE_USER'}");
  my $testTime = time;
  if ( $QRTool ne "api" ) {
    print("<!-- expireTime: $expireTime, time: $testTime -->");
  }
  if ( $expireTime < time ) {
    $QRApplication = "QResponse";
    $QRTool = "userSettings";
  }
}
#print("<!-- QRDomain: $QRDomain, QRApplication: $QRApplication, USERLEVEL: $ENV{'USERLEVEL'} -->");
#print("$ENV{'QR_HEADEROPTS'}/$options $headerOpts");
if ( $QRTool eq "api" ) {
  &testAndExecute("$QRDomain+$QRApplication+$QRTool+$QRModule+$QROption1+$QROption2+$QROption3+$QROption4+$QROption5+$QROption6", "$QRApplication", "$QRTool");    
} else {
  print("<TABLE WIDTH=100% BORDER=0 CELLSPACING=0><TR BGCOLOR=$ENV{'QR_L1_BACK'}> <TD>\n");

#print("<FONT COLOR=$ENV{'QR_L1_BACK'}></FONT>");


  if (( $QRApplication ne "" ) and ( "$QRApplication+$QRTool" ne "QResponse+setAccessRights" )) {
    my $dispAccess = catFile("$ENV{'SIM_USERSETTINGSDIR'}/simAccessSettings-$ENV{'REMOTE_USER'}");
    if ( $dispAccess eq "yes" ) {
      my $testLevel = testLevel("$QRDomain+QResponse+setAccessRights");
      if ( $userLevel >= $testLevel ) {
#       print("</TD></TR><TR BGCOLOR=orange><TD> QRApplication=$QRApplication, QRTool=$QRTool, dispAccess=$dispAccess, userLevel=$userLevel, testLevel=$testLevel.");
        print("</TD></TR><TR BGCOLOR=yellow><TD>");
        &testAndExecute("$QRDomain+QResponse+displayAccessRights+$QRDomain+$QRApplication+$QRTool+$QRModule+$QROption1+$QROption2+$QROption3+$QROption4+$QROption5+$QROption6", "QResponse", "displayAccessRights");
        print("</TD></TR><TR BGCOLOR=$ENV{'QR_L1_BACK'}> <TD>\n");
      }
    }
  }
  print("<DIV><NAV><DIV>
         <UL>");
# printEntry2("<B>$QRDomain</B>", "QResponse menu", "$QRDomain+$QRApplication", "$QRDomain+QResponse", "", "link", " &nbsp; ", "#2E64FE", "");
  printMenuCgi( 1, $QRDomain, $QRApplication, "MainMenu", "link" );
  # dummy rule to display the first menu rule.
  
  # Logout url
# print("<LI><A href='javascript:logout(\"/somewhere-in-the-universe\")' TITLE='Log out'><FONT COLOR=#AAAAAA><B>Log out</B></FONT></A>\n");
# print("<LI><A HREF=# onclick=\"logout(\"/index.html\");\"><FONT COLOR=#AAAAAA><B>Log out</B></FONT></A>\n");
  print("</DIV></NAV></DIV>");
#       <TR><TD ALIGN=right> <A HREF=http://www.qresponse.net><FONT COLOR=#2E64FE><B>$QRDomain</B></FONT></A> &nbsp;</TD></TR>");


  my @urlOptions = ($QRApplication, $QRTool, $QRModule, $QROption1, $QROption2);

  my $menuLevel = 2;
  my ($menuName, $lastMenu, $lastEntry);
  foreach my $menuEntry (@urlOptions) {
#   print("<FONT COLOR=#888888> $menuEntry </FONT>"); # Deze regel zorgt ervoor dat de menu regel achter de blauwe balk komt.
    if ( $menuName eq "" ) {
      $menuName = $menuEntry;
    } else { 
      $menuName = "$menuName+$menuEntry";
    }
    if ( -f "$ENV{'QR_MENUDIR'}/$menuName" ) {
      $lastEntry = &printMenuCgi( $menuLevel, "$QRDomain+$menuName", $urlOptions[$menuLevel - 1], $menuName);
#     print(" lastEntry=$lastEntry ");
      $lastMenu = $menuName;
      $menuLevel++;
    } else {
      if ( $menuEntry ne "" ) {
        $lastEntry = $menuEntry;
        last;
      }
    }
  }
  &closeTable;
# print("menuLevel=$menuLevel, menuName=$menuName, lastMenu=$lastMenu, lastEntry=$lastEntry.");
  $timeRef{'afterMenus'} = time;
  my $testResult = &testInputVars(@cmdArgs);
  my $reauthReason = &test2FactAuth(@cmdArgs);
  if ( $testResult ne "oke" ) {
    &printMessage("Input validation error", "$testResult");
  } elsif ( $reauthReason ne "oke" ) {
#   print("updater");
#   print("test2FactAuth failed: reauthReason=$reauthReason");
    system(" $ENV{'QR_UPDATER'} reAuth $reauthReason ");
    $exitCode = $? >> 8;
  } elsif ( $lastEntry eq "" ) {
    &printMessage("Select.", "Please select an option above.");
  } else {
    my $testLevel = testLevel("$QRDomain+$QRApplication+$QRTool+$QRModule+$QROption1");
    if ( $userLevel < $testLevel ) {
      &printMessage("Sorry.","<H2>Sorry, no access allowed ($userLevel/$testLevel).</H2>");
    } else {
      my $time = printDate( time, "hhmmss"); print("\n<!-- timer: $time -->");
#     print("testAndExecute: $QRDomain+$QRApplication+$QRTool+$QRModule+$QROption1+$QROption2+$QROption3+$QROption4+$QROption5+$QROption6");
      &testAndExecute("$QRDomain+$QRApplication+$QRTool+$QRModule+$QROption1+$QROption2+$QROption3+$QROption4+$QROption5+$QROption6", $lastMenu, $lastEntry);    
    }
  }
# print(" remoteUser: \"$remoteUser\", httpScriptName: \"$httpScriptName\", QRDomain: \"$QRDomain\" ($ENV{'USERLEVEL'})");

}
&printFooter($QRTool);
