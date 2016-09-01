#!/usr/bin/perl -w
  ############################## check_snmp_load #################
! my $Version='1.13';
  # Date : Oct 12 2007
  # Author  : Patrick Proy ( patrick at proy.org)
  # Help : http://nagios.manubulon.com/
  # Licence : GPL - http://www.fsf.org/licenses/gpl.txt
  # Contributors : F. Lacroix and many others !!!
 # $Id: check_snmp_load1.pl 206 2010-07-05 10:00:21Z happyman $ add support for HUAWEI
  #################################################################
  #
  # Help : ./check_snmp_load.pl -h
***************
*** 84,91 ****
my $hpux_load_5_min="1.3.6.1.4.1.11.2.3.1.1.4.0";
my $hpux_load_15_min="1.3.6.1.4.1.11.2.3.1.1.5.0";

  # valid values
! my @valid_types = ("stand","netsc","netsl","as400","cisco","cata","nsc","fg","bc","nokia","hp","lp","hpux");
  # CPU OID array
  my %cpu_oid = ("netsc",$ns_cpu_idle,"as400",$as400_cpu,"bc",$bluecoat_cpu,"nokia",$nokia_cpu,"hp",$procurve_cpu,"lp",$linkproof_cpu,"fg",$fortigate_cpu);

--- 85,98 ----
! my $hpux_load_5_min="1.3.6.1.4.1.11.2.3.1.1.4.0";
! my $hpux_load_15_min="1.3.6.1.4.1.11.2.3.1.1.5.0";

 # Huawei cpu/load

my $huawei_cpu_5m = "1.3.6.1.4.1.2011.6.3.4.1.4.0.1.0"; # Huawei CPU load (5min %)
my $huawei_cpu_1m = "1.3.6.1.4.1.2011.6.3.4.1.3.0.1.0"; # Huawei CPU load (1min %)
my $huawei_cpu_5s = "1.3.6.1.4.1.2011.6.3.4.1.2.0.1.0"; # Huawei CPU load (5sec %)

  # valid values
! my @valid_types = ("stand","netsc","netsl","as400","cisco","cata","nsc","fg","bc","nokia","hp","lp","hpux","huawei");
  # CPU OID array
  my %cpu_oid = ("netsc",$ns_cpu_idle,"as400",$as400_cpu,"bc",$bluecoat_cpu,"nokia",$nokia_cpu,"hp",$procurve_cpu,"lp",$linkproof_cpu,"fg",$fortigate_cpu);

***************
*** 98,104 ****
  my $o_help=   undef;          # wan't some help ?
  my $o_verb=   undef;          # verbose mode
  my $o_version=        undef;          # print version
! # check type  : stand | netsc |  netsl | as400 | cisco | cata | nsc | fg | bc | nokia | hp | lp  | hpux
  my $o_check_type= "stand";
  # End compatibility
  my $o_warn=   undef;          # warning level
--- 105,111 ----
  my $o_help=   undef;          # wan't some help ?
  my $o_verb=   undef;          # verbose mode
  my $o_version=        undef;          # print version
! # check type  : stand | netsc |  netsl | as400 | cisco | cata | nsc | fg | bc | nokia | hp | lp  | hpux | huawei
  my $o_check_type= "stand";
  # End compatibility
  my $o_warn=   undef;          # warning level
***************
*** 121,127 ****
  sub p_version { print "check_snmp_load version : $Version\n"; }

  sub print_usage {
!     print "Usage: $0 [-v] -H  -C  [-2] | (-l login -x passwd [-X pass -L ,])  [-p ] -w  -c  -T=[stand|netsl|netsc|as400|cisco|cata|nsc|fg|bc|nokia|hp|lp|hpux] [-f] [-t ] [-V]\n";
  }

  sub isnnum { # Return true if arg is not a number
--- 128,134 ----
  sub p_version { print "check_snmp_load version : $Version\n"; }

  sub print_usage {
!     print "Usage: $0 [-v] -H  -C  [-2] | (-l login -x passwd [-X pass -L ,])  [-p ] -w  -c  -T=[stand|netsl|netsc|as400|cisco|cata|nsc|fg|bc|nokia|hp|lp|hpux|huawei] [-f] [-t ] [-V]\n";
  }

  sub isnnum { # Return true if arg is not a number
***************
*** 244,250 ****
      $o_crit =~ s/\%//g;
      # Check for multiple warning and crit in case of -L
        if (($o_check_type eq "netsl") || ($o_check_type eq "cisco") || ($o_check_type eq "cata") ||
!               ($o_check_type eq "nsc") || ($o_check_type eq "hpux")) {
                @o_warnL=split(/,/ , $o_warn);
                @o_critL=split(/,/ , $o_crit);
                if (($#o_warnL != 2) || ($#o_critL != 2))
--- 251,257 ----
      $o_crit =~ s/\%//g;
      # Check for multiple warning and crit in case of -L
        if (($o_check_type eq "netsl") || ($o_check_type eq "cisco") || ($o_check_type eq "cata") ||
!               ($o_check_type eq "nsc") || ($o_check_type eq "hpux")|| ($o_check_type eq "huawei")) {
                @o_warnL=split(/,/ , $o_warn);
                @o_critL=split(/,/ , $o_crit);
                if (($#o_warnL != 2) || ($#o_critL != 2))
***************
*** 460,465 ****
--- 467,527 ----

  exit $exit_val;
  }
+ ## Huawei
+
+ if ($o_check_type eq "huawei") {
+ my @oidlists = ($huawei_cpu_5m, $huawei_cpu_1m, $huawei_cpu_5s);
+ my $resultat = (Net::SNMP->VERSION < 4) ?
+           $session->get_request(@oidlists)
+         : $session->get_request(-varbindlist => \@oidlists);
+
+ if (!defined($resultat)) {
+    printf("ERROR: Description table : %s.\n", $session->error);
+    $session->close;
+    exit $ERRORS{"UNKNOWN"};
+ }
+
+ $session->close;
+
+ if (!defined ($$resultat{$huawei_cpu_5s})) {
+   print "No CPU information : UNKNOWN\n";
+   exit $ERRORS{"UNKNOWN"};
+ }
+
+ my @load = undef;
+
+ $load[0]=$$resultat{$huawei_cpu_5s};
+ $load[1]=$$resultat{$huawei_cpu_1m};
+ $load[2]=$$resultat{$huawei_cpu_5m};
+
+ print "CPU : $load[0] $load[1] $load[2] :";
+
+ $exit_val=$ERRORS{"OK"};
+ for (my $i=0;$i<3;$i++) {
+   if ( $load[$i] > $o_critL[$i] ) {
+    print " $load[$i] > $o_critL[$i] : CRITICAL";
+    $exit_val=$ERRORS{"CRITICAL"};
+   }
+   if ( $load[$i] > $o_warnL[$i] ) {
+      # output warn error only if no critical was found
+      if ($exit_val eq $ERRORS{"OK"}) {
+        print " $load[$i] > $o_warnL[$i] : WARNING";
+        $exit_val=$ERRORS{"WARNING"};
+      }
+   }
+ }
+ print " OK" if ($exit_val eq $ERRORS{"OK"});
+ if (defined($o_perf)) {
+    print " | load_5_sec=$load[0]%;$o_warnL[0];$o_critL[0] ";
+    print "load_1_min=$load[1]%;$o_warnL[1];$o_critL[1] ";
+    print "load_5_min=$load[2]%;$o_warnL[2];$o_critL[2]\n";
+ } else {
+  print "\n";
+ }
+
+ exit $exit_val;
+ }
+ ## end of Huawei

