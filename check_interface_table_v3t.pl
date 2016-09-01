#!/usr/bin/perl
# nagios: -epn

# ------------------------------------------------------------------------
# Program: interfacetable_v3t
# Version: 0.05-1
# Author:  Yannick Charton - tontonitch-pro@yahoo.fr
# License: GPLv3
# Copyright (c) 2009-2013 Yannick Charton (http://www.tontonitch.com)

# COPYRIGHT:
# This software and the additional scripts provided with this software are
# Copyright (c) 2009-2013 Yannick Charton (tontonitch-pro@yahoo.fr)
# (Except where explicitly superseded by other copyright notices)
#
# LICENSE:
# This work is made available to you under the terms of version 3 of
# the GNU General Public License. A copy of that license should have
# been provided with this software.
# If not, see <http://www.gnu.org/licenses/>.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# Nagios and the Nagios logo are registered trademarks of Ethan Galstad.
# ------------------------------------------------------------------------

use strict;
use warnings;

use lib ('/usr/local/interfacetable_v3t/lib');
use Net::SNMP qw(oid_base_match);
use Config::General;
use Data::Dumper;
  $Data::Dumper::Sortkeys = 1;
  $Data::Dumper::Terse = 1;
use Getopt::Long qw(:config no_ignore_case no_ignore_case_always bundling_override);
use Sort::Naturally;
use Time::HiRes qw();
use Encode qw(decode encode);
use GeneralUtils;
use Settings;
use SnmpUtils;



# ========================================================================
# VARIABLES
# ========================================================================

# ------------------------------------------------------------------------
# global variable definitions
# ------------------------------------------------------------------------
use vars qw($TIMEOUT %ERRORS $PROGNAME $REVISION $CONTACT);
$TIMEOUT = 15;
%ERRORS = ('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
$PROGNAME        = $0;
$REVISION        = '0.05-1';
$CONTACT         = 'tontonitch-pro@yahoo.fr';
my %ERRORCODES   = (0=>'OK',1=>'WARNING',2=>'CRITICAL',3=>'UNKNOWN',4=>'DEPENDENT');
my %COLORS       = ('HighLight' => '#81BEF7');
my $UMASK        = "0000";
my $TMPDIR       = File::Spec->tmpdir();          # define cache directory or use /tmp  -- not used yet
my $STARTTIME_HR = Time::HiRes::time();           # time of program start, high res
my $STARTTIME    = sprintf("%.0f",$STARTTIME_HR); # time of program start
my $MAX_PLUGIN_OUTPUT_LENGTH = 8192;              # change it to reflect any change of the corresponding 
                                                  # variable MAX_PLUGIN_OUTPUT_LENGTH in the sources of nagios 
                                                  # (nagios.h) or icinga (icinga.h) 

# ------------------------------------------------------------------------
# OIDs definitions
# Format: hash containing name, [mib], oid, [convertToReadable]
# ------------------------------------------------------------------------

# Standard OIDs
# ------------------------------------------------------------------------
my %oid_sysObjectID     = ( name => "sysObjectID",  mib => "SNMPv2-MIB",  oid => "1.3.6.1.2.1.1.2.0", convertToReadable => {9=>'cisco', 11=>'hp', 35=>'nortel', 789=>'netapp', 1588=>'brocade', 3224=>'netscreen', 3375=>'bigip', 14501=>'bluecoat'} );  # vendor's authoritative identification
# iana enterprise numbers
# 9     -> cisco
# 11    -> hp
# 35    -> nortel
# 789   -> netapp
# 1588  -> brocade
# 3224  -> netscreen
# 3375  -> bigip
# 14501 -> bluecoat

my %oid_sysDescr        = ( name => "sysDescr",     mib => "RFC1213-MIB", oid => "1.3.6.1.2.1.1.1.0" );
my %oid_sysUpTime       = ( name => "sysUpTime",    mib => "RFC1213-MIB", oid => "1.3.6.1.2.1.1.3.0" );
my %oid_sysContact      = ( name => "sysContact",   mib => "RFC1213-MIB", oid => "1.3.6.1.2.1.1.4.0" );
my %oid_sysName         = ( name => "sysName",      mib => "RFC1213-MIB", oid => "1.3.6.1.2.1.1.5.0" );
my %oid_sysLocation     = ( name => "sysLocation",  mib => "RFC1213-MIB", oid => "1.3.6.1.2.1.1.6.0" );

my %oid_ifDescr         = ( name => "ifDescr",       mib => "IF-MIB", oid => "1.3.6.1.2.1.2.2.1.2" );     # + ".<index>"
my %oid_ifType          = ( name => "ifType",        mib => "IF-MIB", oid => "1.3.6.1.2.1.2.2.1.3", convertToReadable => {
   1=>'other',                        2=>'regular1822',                     3=>'hdh1822',                     4=>'ddnX25',
   5=>'rfc877x25',                    6=>'ethernetCsmacd',                  7=>'iso88023Csmacd',              8=>'iso88024TokenBus',
   9=>'iso88025TokenRing',           10=>'iso88026Man',                    11=>'starLan',                    12=>'proteon10Mbit',
  13=>'proteon80Mbit',               14=>'hyperchannel',                   15=>'fddi',                       16=>'lapb', 
  17=>'sdlc',                        18=>'ds1',                            19=>'e1',                         20=>'basicISDN',
  21=>'primaryISDN',                 22=>'propPointToPointSerial',         23=>'ppp',                        24=>'softwareLoopback',
  25=>'eon',                         26=>'ethernet3Mbit',                  27=>'nsip',                       28=>'slip',
  29=>'ultra',                       30=>'ds3',                            31=>'sip',                        32=>'frameRelay',
  33=>'rs232',                       34=>'para',                           35=>'arcnet',                     36=>'arcnetPlus',
  37=>'atm',                         38=>'miox25',                         39=>'sonet',                      40=>'x25ple',
  41=>'iso88022llc',                 42=>'localTalk',                      43=>'smdsDxi',                    44=>'frameRelayService',
  45=>'v35',                         46=>'hssi',                           47=>'hippi',                      48=>'modem',
  49=>'aal5',                        50=>'sonetPath',                      51=>'sonetVT',                    52=>'smdsIcip',
  53=>'propVirtual',                 54=>'propMultiplexor',                55=>'ieee80212',                  56=>'fibreChannel',
  57=>'hippiInterface',              58=>'frameRelayInterconnect',         59=>'aflane8023',                 60=>'aflane8025',
  61=>'cctEmul',                     62=>'fastEther',                      63=>'isdn',                       64=>'v11',
  65=>'v36',                         66=>'g703at64k',                      67=>'g703at2mb',                  68=>'qllc',
  69=>'fastEtherFX',                 70=>'channel',                        71=>'ieee80211',                  72=>'ibm370parChan',
  73=>'escon',                       74=>'dlsw',                           75=>'isdns',                      76=>'isdnu',
  77=>'lapd',                        78=>'ipSwitch',                       79=>'rsrb',                       80=>'atmLogical',
  81=>'ds0',                         82=>'ds0Bundle',                      83=>'bsc',                        84=>'async',
  85=>'cnr',                         86=>'iso88025Dtr',                    87=>'eplrs',                      88=>'arap',
  89=>'propCnls',                    90=>'hostPad',                        91=>'termPad',                    92=>'frameRelayMPI',
  93=>'x213',                        94=>'adsl',                           95=>'radsl',                      96=>'sdsl',
  97=>'vdsl',                        98=>'iso88025CRFPInt',                99=>'myrinet',                   100=>'voiceEM',
 101=>'voiceFXO',                   102=>'voiceFXS',                      103=>'voiceEncap',                104=>'voiceOverIp',
 105=>'atmDxi',                     106=>'atmFuni',                       107=>'atmIma',                    108=>'pppMultilinkBundle',
 109=>'ipOverCdlc',                 110=>'ipOverClaw',                    111=>'stackToStack',              112=>'virtualIpAddress',
 113=>'mpc',                        114=>'ipOverAtm',                     115=>'iso88025Fiber',             116=>'tdlc',
 117=>'gigabitEthernet',            118=>'hdlc',                          119=>'lapf',                      120=>'v37',
 121=>'x25mlp',                     122=>'x25huntGroup',                  123=>'transpHdlc',                124=>'interleave',
 125=>'fast',                       126=>'ip',                            127=>'docsCableMaclayer',         128=>'docsCableDownstream',
 129=>'docsCableUpstream',          130=>'a12MppSwitch',                  131=>'tunnel',                    132=>'coffee',
 133=>'ces',                        134=>'atmSubInterface',               135=>'l2vlan',                    136=>'l3ipvlan',
 137=>'l3ipxvlan',                  138=>'digitalPowerline',              139=>'mediaMailOverIp',           140=>'dtm',
 141=>'dcn',                        142=>'ipForward',                     143=>'msdsl',                     144=>'ieee1394',
 145=>'if-gsn',                     146=>'dvbRccMacLayer',                147=>'dvbRccDownstream',          148=>'dvbRccUpstream',
 149=>'atmVirtual',                 150=>'mplsTunnel',                    151=>'srp',                       152=>'voiceOverAtm',
 153=>'voiceOverFrameRelay',        154=>'idsl',                          155=>'compositeLink',             156=>'ss7SigLink',
 157=>'propWirelessP2P',            158=>'frForward',                     159=>'rfc1483',                   160=>'usb',
 161=>'ieee8023adLag',              162=>'bgppolicyaccounting',           163=>'frf16MfrBundle',            164=>'h323Gatekeeper',
 165=>'h323Proxy',                  166=>'mpls',                          167=>'mfSigLink',                 168=>'hdsl2',
 169=>'shdsl',                      170=>'ds1FDL',                        171=>'pos',                       172=>'dvbAsiIn',
 173=>'dvbAsiOut',                  174=>'plc',                           175=>'nfas',                      176=>'tr008',
 177=>'gr303RDT',                   178=>'gr303IDT',                      179=>'isup',                      180=>'propDocsWirelessMaclayer',
 181=>'propDocsWirelessDownstream', 182=>'propDocsWirelessUpstream',      183=>'hiperlan2',                 184=>'propBWAp2Mp',
 185=>'sonetOverheadChannel',       186=>'digitalWrapperOverheadChannel', 187=>'aal2',                      188=>'radioMAC',
 189=>'atmRadio',                   190=>'imt',                           191=>'mvl',                       192=>'reachDSL',
 193=>'frDlciEndPt',                194=>'atmVciEndPt',                   195=>'opticalChannel',            196=>'opticalTransport',
 197=>'propAtm',                    198=>'voiceOverCable',                199=>'infiniband',                200=>'teLink',
 201=>'q2931',                      202=>'virtualTg',                     203=>'sipTg',                     204=>'sipSig',
 205=>'docsCableUpstreamChannel',   206=>'econet',                        207=>'pon155',                    208=>'pon622',
 209=>'bridge',                     210=>'linegroup',                     211=>'voiceEMFGD',                212=>'voiceFGDEANA',
 213=>'voiceDID',                   214=>'mpegTransport',                 215=>'sixToFour',                 216=>'gtp',
 217=>'pdnEtherLoop1',              218=>'pdnEtherLoop2',                 219=>'opticalChannelGroup',       220=>'homepna',
 221=>'gfp',                        222=>'ciscoISLvlan',                  223=>'actelisMetaLOOP',           224=>'fcipLink',
 225=>'rpr',                        226=>'qam',                           227=>'lmp',                       228=>'cblVectaStar',
 229=>'docsCableMCmtsDownstream',   230=>'adsl2',                         231=>'macSecControlledIF',        232=>'macSecUncontrolledIF',
 233=>'aviciOpticalEther',          234=>'atmbond',                       235=>'voiceFGDOS',                236=>'mocaVersion1',
 237=>'ieee80216WMAN',              238=>'adsl2plus',                     239=>'dvbRcsMacLayer',            240=>'dvbTdm',
 241=>'dvbRcsTdma',                 242=>'x86Laps',                       243=>'wwanPP',                    244=>'wwanPP2',
 245=>'voiceEBS',                   246=>'ifPwType',                      247=>'ilan',                      248=>'pip',
 249=>'aluELP',                     250=>'gpon',                          251=>'vdsl2',                     252=>'capwapDot11Profile',
 253=>'capwapDot11Bss',             254=>'capwapWtpVirtualRadio',         255=>'bits',                      256=>'docsCableUpstreamRfPort',
 257=>'cableDownstreamRfPort',      258=>'vmwareVirtualNic',              259=>'ieee802154',                260=>'otnOdu',
 261=>'otnOtu',                     262=>'ifVfiType',                     263=>'g9981',                     264=>'g9982',
 265=>'g9983',                      266=>'aluEpon',                       267=>'aluEponOnu',                268=>'aluEponPhysicalUni',
 269=>'aluEponLogicalLink',         270=>'aluGponOnu',                    271=>'aluGponPhysicalUni',        272=>'vmwareNicTeam'} );     # + ".<index>"
my %oid_ifName          = ( name => "ifName",        mib => "IF-MIB", oid => "1.3.6.1.2.1.31.1.1.1.1" ); # + ".<index>"
my %oid_ifAlias         = ( name => "ifAlias",       mib => "IF-MIB", oid => "1.3.6.1.2.1.31.1.1.1.18" ); # + ".<index>"
my %oid_ifSpeed         = ( name => "ifSpeed",       mib => "IF-MIB", oid => "1.3.6.1.2.1.2.2.1.5" );     # + ".<index>"
my %oid_ifHighSpeed     = ( name => "ifHighSpeed",   mib => "IF-MIB", oid => "1.3.6.1.2.1.31.1.1.1.15" ); # + ".<index>"
my %oid_ifPhysAddress   = ( name => "ifPhysAddress", mib => "IF-MIB", oid => "1.3.6.1.2.1.2.2.1.6" );     # + ".<index>"
my %oid_ifAdminStatus   = ( name => "ifAdminStatus", mib => "IF-MIB", oid => "1.3.6.1.2.1.2.2.1.7", convertToReadable => {1=>'up', 2=>'down', 3=>'testing', 4=>'unknown', 5=>'dormant', 6=>'notPresent', 7=>'lowerLayerDown'} );     # + ".<index>"
my %oid_ifOperStatus    = ( name => "ifOperStatus",  mib => "IF-MIB", oid => "1.3.6.1.2.1.2.2.1.8", convertToReadable => {1=>'up', 2=>'down', 3=>'testing', 4=>'unknown', 5=>'dormant', 6=>'notPresent', 7=>'lowerLayerDown'} );     # + ".<index>"
#my %oid_ifLastChange    = ( name => "ifLastChange",  mib => "IF-MIB", oid => "1.3.6.1.2.1.2.2.1.9" );     # + ".<index>", not used

my %oid_ifDuplexStatus  = ( name => "dot3StatsDuplexStatus", mib => "EtherLike-MIB", oid => "1.3.6.1.2.1.10.7.2.1.19", convertToReadable => {1=>'unknown', 2=>'half', 3=>'full'});  # + ".<index>"

my %oid_ipAdEntIfIndex   = ( name => "ipAdEntIfIndex",   mib => "IP-MIB", oid => "1.3.6.1.2.1.4.20.1.2" ); # + ".<IP address>"
my %oid_ipAdEntNetMask   = ( name => "ipAdEntNetMask",   mib => "IP-MIB", oid => "1.3.6.1.2.1.4.20.1.3" ); # + ".<index>"
my %oid_ipAddressIfIndex = ( name => "ipAddressIfIndex", mib => "IP-MIB", oid => "1.3.6.1.2.1.4.34.1.3" ); # + ".<IP address>"
my %oid_ipAddressIfIndex_ipv4 = ( name => "ipAddressIfIndex", mib => "IP-MIB", oid => "1.3.6.1.2.1.4.34.1.3.1.4" ); # + ".<IP address>"

my %oid_ifVlanName      = ( name => "entLogicalDescr", mib => "ENTITY-MIB", oid => "1.3.6.1.2.1.47.1.2.1.1.2" ); # + ".<index>"

my %oid_dot1dBasePortIfIndex = ( name => "dot1dBasePortIfIndex", mib => 'BRIDGE-MIB', oid => '1.3.6.1.2.1.17.1.4.1.2' ); # map from dot1base port table to ifindex table
my %oid_dot1dStpPortState    = ( name => "dot1dStpPortState",    mib => 'BRIDGE-MIB', oid => '1.3.6.1.2.1.17.2.15.1.3',
    convertToReadable => {0=>'unknown',1=>'disabled',2=>'blocking',3=>'listening',4=>'learning',5=>'forwarding',6=>'broken'} ); # stp port states

# RFC1213 - Extracts about in/out stats
# ifInOctets:     The total number of octets received on the interface, including framing characters.
# ifInErrors:     The number of inbound packets that contained errors preventing them from being deliverable to a
#                 higher-layer protocol.
# ifInDiscards:   The number of inbound packets which were chosen to be discarded even though no errors had been
#                 detected to prevent their being deliverable to a higher-layer protocol. One possible reason for
#                 discarding such a packet could be to free up buffer space.
# ifOutOctets:    The total number of octets transmitted out of the interface, including framing characters.
# ifOutErrors:    The number of outbound packets that could not be transmitted because of errors.
# ifOutDiscards:  The number of outbound packets which were chosen to be discarded even though no errors had been
#                 detected to prevent their being transmitted. One possible reason for discarding such a packet could
#                 be to free up buffer space.
my %oid_ifInOctets       = ( name => "ifInOctets",       mib => "IF-MIB", oid => '1.3.6.1.2.1.2.2.1.10' );    # + ".<index>"
my %oid_ifInDiscards     = ( name => "ifInDiscards",     mib => "IF-MIB", oid => '1.3.6.1.2.1.2.2.1.13' );    # + ".<index>"
my %oid_ifInErrors       = ( name => "ifInErrors",       mib => "IF-MIB", oid => '1.3.6.1.2.1.2.2.1.14' );    # + ".<index>"
my %oid_ifOutOctets      = ( name => "ifOutOctets",      mib => "IF-MIB", oid => '1.3.6.1.2.1.2.2.1.16' );    # + ".<index>"
my %oid_ifOutDiscards    = ( name => "ifOutDiscards",    mib => "IF-MIB", oid => '1.3.6.1.2.1.2.2.1.19' );    # + ".<index>"
my %oid_ifOutErrors      = ( name => "ifOutErrors",      mib => "IF-MIB", oid => '1.3.6.1.2.1.2.2.1.20' );    # + ".<index>"
my %oid_ifHCInOctets     = ( name => "ifHCInOctets",     mib => "IF-MIB", oid => '1.3.6.1.2.1.31.1.1.1.6' );  # + ".<index>"
my %oid_ifHCOutOctets    = ( name => "ifHCOutOctets",    mib => "IF-MIB", oid => '1.3.6.1.2.1.31.1.1.1.10' ); # + ".<index>"
my %oid_ifInUcastPkts    = ( name => "ifInUcastPkts",    mib => "IF-MIB", oid => '1.3.6.1.2.1.2.2.1.11' );    # + ".<index>"
my %oid_ifOutUcastPkts   = ( name => "ifOutUcastPkts",   mib => "IF-MIB", oid => '1.3.6.1.2.1.2.2.1.17' );    # + ".<index>"
my %oid_ifInNUcastPkts   = ( name => "ifInNUcastPkts",   mib => "IF-MIB", oid => '1.3.6.1.2.1.2.2.1.12' );    # + ".<index>"
my %oid_ifOutNUcastPkts  = ( name => "ifOutNUcastPkts",  mib => "IF-MIB", oid => '1.3.6.1.2.1.2.2.1.18' );    # + ".<index>"
my %oid_ifHCInUcastPkts  = ( name => "ifHCInUcastPkts",  mib => "IF-MIB", oid => '1.3.6.1.2.1.31.1.1.1.7' );  # + ".<index>"
my %oid_ifHCOutUcastPkts = ( name => "ifHCOutUcastPkts", mib => "IF-MIB", oid => '1.3.6.1.2.1.31.1.1.1.11' ); # + ".<index>"
my %oid_ifHCInMulticastPkts  = ( name => "ifHCInMulticastPkts",  mib => "IF-MIB", oid => '1.3.6.1.2.1.31.1.1.1.8' );  # + ".<index>"
my %oid_ifHCInBroadcastPkts  = ( name => "ifHCInBroadcastPkts",  mib => "IF-MIB", oid => '1.3.6.1.2.1.31.1.1.1.9' );  # + ".<index>"
my %oid_ifHCOutMulticastPkts = ( name => "ifHCOutMulticastPkts", mib => "IF-MIB", oid => '1.3.6.1.2.1.31.1.1.1.12' ); # + ".<index>"
my %oid_ifHCOutBroadcastPkts = ( name => "ifHCOutBroadcastPkts", mib => "IF-MIB", oid => '1.3.6.1.2.1.31.1.1.1.13' ); # + ".<index>"

# Cisco specific OIDs
# ------------------------------------------------------------------------
my %oid_cisco_ChassisModel     = ( name => "ChassisModel",         mib => "CISCO-STACK-MIB",           oid => '1.3.6.1.4.1.9.5.1.2.16.0' );     # ex: WS-C3550-48-SMI
my %oid_cisco_ChassisSrNumStr  = ( name => "ChassisSrNumStr",      mib => "CISCO-STACK-MIB",           oid => '1.3.6.1.4.1.9.5.1.2.19.0' );     # ex: CAT0645Z0HB
my %oid_cisco_model            = ( name => "entPhysicalModelName", mib => "ENTITY-MIB",                oid => '1.3.6.1.2.1.47.1.1.1.1.13.1' );  # model. ex: CISCO2811
my %oid_cisco_serial           = ( name => "entPhysicalSerialNum", mib => "ENTITY-MIB",                oid => '1.3.6.1.2.1.47.1.1.1.1.11.1' );  # serial number
my %oid_cisco_vmVlan           = ( name => "vmVlan",               mib => "CISCO-VLAN-MEMBERSHIP-MIB", oid => '1.3.6.1.4.1.9.9.68.1.2.2.1.2' ); # + ".?.<index>"
# NOT USED - my $oid_locIfIntBitsSec = '1.3.6.1.4.1.9.2.2.1.1.6';   # need to append integer for specific interface
# NOT USED - my $oid_locIfOutBitsSec = '1.3.6.1.4.1.9.2.2.1.1.8';   # need to append integer for specific interface
# NOT USED - my $cisco_ports         = '1.3.6.1.4.1.9.5.1.3.1.1.14.1'; # number of ports of the switch

# For use in Cisco CATOS special hacks - NOT USED YET
# my $oid_cisco_port_name_table               = '1.3.6.1.4.1.9.5.1.4.1.1.4';    # table of port names (the ones you set with 'set port name')
# my $oid_cisco_port_ifindex_map              = '1.3.6.1.4.1.9.5.1.4.1.1.11';   # map from cisco port table to normal SNMP ifindex table
# my $oid_cisco_port_linkfaultstatus_table    = '1.3.6.1.4.1.9.5.1.4.1.1.22.';  # see table below for possible codes
# my $oid_cisco_port_operstatus_table         = '1.3.6.1.4.1.9.5.1.4.1.1.6.';   # see table below for possible values
# my $oid_cisco_port_addoperstatus_table      = '1.3.6.1.4.1.9.5.1.4.1.1.23.';  # see table below for possible codes
# my %cisco_port_linkfaultstatus = (1=>'up',2=>'nearEndFault',3=>'nearEndConfigFail',4=>'farEndDisable',5=>'farEndFault',6=>'farEndConfigFail',7=>'otherFailure');
# my %cisco_port_operstatus      = (0=>'operstatus:unknown',1=>'operstatus:other',2=>'operstatus:ok',3=>'operstatus:minorFault',4=>'operstatus:majorFault');
# my %cisco_port_addoperstatus   = (0=>'other',1=>'connected',2=>'standby',3=>'faulty',4=>'notConnected',5=>'inactive',6=>'shutdown',7=>'dripDis',8=>'disable',9=>'monitor',10=>'errdisable',11=>'linkFaulty',12=>'onHook',13=>'offHook',14=>'reflector');

# HP specific OIDs
# ------------------------------------------------------------------------
my %oid_hp_ifVlanPort = ( name => "hpSwitchIgmpPortIndex2", mib => "CONFIG-MIB (HP)", oid => '1.3.6.1.4.1.11.2.14.11.5.1.7.1.15.3.1.2' );   # + ".<index>"
# Or? ifVlan = ".1.3.6.1.4.1.11.2.14.11.5.1.7.1.15.1.1.1 (hpSwitchIgmpVlanIndex)";
#TODO my $oid_hp_ifDuplexStatus      = '.1.3.6.1.4.1.11.2.14.11.5.1.7.1.3.1.1.10';   # + ".<index>"
#TODO my %hp_ifDuplexStatus          = (1=>'HD10',2=>'HD10',3=>'FD10',4=>'FD100',5=>'auto neg');

# Juniper Netscreen specific OIDs (from NETSCREEN-INTERFACE/ZONE/VSYS-MIB)
# ------------------------------------------------------------------------
my %oid_juniper_nsIfIndex   = ( name => "nsIfIndex",    mib => "NETSCREEN-INTERFACE-MIB", oid => '1.3.6.1.4.1.3224.9.1.1.1' );  # + ".<index>"
my %oid_juniper_nsIfName    = ( name => "nsIfName",     mib => "NETSCREEN-INTERFACE-MIB", oid => '1.3.6.1.4.1.3224.9.1.1.2' );  # + ".<index>"
my %oid_juniper_nsIfDescr   = ( name => "nsIfDescr",    mib => "NETSCREEN-INTERFACE-MIB", oid => '1.3.6.1.4.1.3224.9.1.1.22' ); # + ".<index>"
my %oid_juniper_nsIfZone    = ( name => "nsIfZone",     mib => "NETSCREEN-INTERFACE-MIB", oid => '1.3.6.1.4.1.3224.9.1.1.4' );  # + ".<index>"
my %oid_juniper_nsIfVsys    = ( name => "nsIfVsys",     mib => "NETSCREEN-INTERFACE-MIB", oid => '1.3.6.1.4.1.3224.9.1.1.3' );  # + ".<index>"
my %oid_juniper_nsIfStatus  = ( name => "nsIfStatus",   mib => "NETSCREEN-INTERFACE-MIB", oid => '1.3.6.1.4.1.3224.9.1.1.5' );  # + ".<index>"
my %oid_juniper_nsIfIp      = ( name => "nsIfIp",       mib => "NETSCREEN-INTERFACE-MIB", oid => '1.3.6.1.4.1.3224.9.1.1.6' );  # + ".<index>"
my %oid_juniper_nsIfNetmask = ( name => "nsIfNetmask",  mib => "NETSCREEN-INTERFACE-MIB", oid => '1.3.6.1.4.1.3224.9.1.1.7' );  # + ".<index>"
my %oid_juniper_nsIfMode    = ( name => "nsIfMode",     mib => "NETSCREEN-INTERFACE-MIB", oid => '1.3.6.1.4.1.3224.9.1.1.10' ); # + ".<index>"
my %oid_juniper_nsIfMAC     = ( name => "nsIfMAC",      mib => "NETSCREEN-INTERFACE-MIB", oid => '1.3.6.1.4.1.3224.9.1.1.11' ); # + ".<index>"

my %oid_juniper_nsIfMngTelnet     = ( name => "nsIfMngTelnet",     mib => "NETSCREEN-INTERFACE-MIB", oid => '1.3.6.1.4.1.3224.9.1.1.12' ); # + ".<index>"
my %oid_juniper_nsIfMngSCS        = ( name => "nsIfMngSCS",        mib => "NETSCREEN-INTERFACE-MIB", oid => '1.3.6.1.4.1.3224.9.1.1.13' ); # + ".<index>"
my %oid_juniper_nsIfMngWEB        = ( name => "nsIfMngWEB",        mib => "NETSCREEN-INTERFACE-MIB", oid => '1.3.6.1.4.1.3224.9.1.1.14' ); # + ".<index>"
my %oid_juniper_nsIfMngSSL        = ( name => "nsIfMngSSL",        mib => "NETSCREEN-INTERFACE-MIB", oid => '1.3.6.1.4.1.3224.9.1.1.15' ); # + ".<index>"
my %oid_juniper_nsIfMngSNMP       = ( name => "nsIfMngSNMP",       mib => "NETSCREEN-INTERFACE-MIB", oid => '1.3.6.1.4.1.3224.9.1.1.16' ); # + ".<index>"
my %oid_juniper_nsIfMngGlobal     = ( name => "nsIfMngGlobal",     mib => "NETSCREEN-INTERFACE-MIB", oid => '1.3.6.1.4.1.3224.9.1.1.17' ); # + ".<index>"
my %oid_juniper_nsIfMngGlobalPro  = ( name => "nsIfMngGlobalPro",  mib => "NETSCREEN-INTERFACE-MIB", oid => '1.3.6.1.4.1.3224.9.1.1.18' ); # + ".<index>"
my %oid_juniper_nsIfMngPing       = ( name => "nsIfMngPing",       mib => "NETSCREEN-INTERFACE-MIB", oid => '1.3.6.1.4.1.3224.9.1.1.19' ); # + ".<index>"
my %oid_juniper_nsIfMngIdentReset = ( name => "nsIfMngIdentReset", mib => "NETSCREEN-INTERFACE-MIB", oid => '1.3.6.1.4.1.3224.9.1.1.20' ); # + ".<index>"

#NOT USED YET
#my $oid_juniper_nsIfMonPlyDeny      = '1.3.6.1.4.1.3224.9.4.1.3'; # + ".<index>"
#my $oid_juniper_nsIfMonAuthFail     = '1.3.6.1.4.1.3224.9.4.1.4'; # + ".<index>"
#my $oid_juniper_nsIfMonUrlBlock     = '1.3.6.1.4.1.3224.9.4.1.5'; # + ".<index>"
#my $oid_juniper_nsIfMonTrMngQueue   = '1.3.6.1.4.1.3224.9.4.1.6'; # + ".<index>"
#my $oid_juniper_nsIfMonTrMngDrop    = '1.3.6.1.4.1.3224.9.4.1.7'; # + ".<index>"
#my $oid_juniper_nsIfMonEncFail      = '1.3.6.1.4.1.3224.9.4.1.8'; # + ".<index>"
#my $oid_juniper_nsIfMonNoSa         = '1.3.6.1.4.1.3224.9.4.1.9'; # + ".<index>"
#my $oid_juniper_nsIfMonNoSaPly      = '1.3.6.1.4.1.3224.9.4.1.10'; # + ".<index>"
#my $oid_juniper_nsIfMonSaInactive   = '1.3.6.1.4.1.3224.9.4.1.11'; # + ".<index>"
#my $oid_juniper_nsIfMonSaPolicyDeny = '1.3.6.1.4.1.3224.9.4.1.12'; # + ".<index>"

my %oid_juniper_nsZoneCfgId   = ( name => "nsZoneCfgId",   mib => "NETSCREEN-ZONE-MIB", oid => '1.3.6.1.4.1.3224.8.1.1.1.1' ); # + ".<index>"
my %oid_juniper_nsZoneCfgName = ( name => "nsZoneCfgName", mib => "NETSCREEN-ZONE-MIB", oid => '1.3.6.1.4.1.3224.8.1.1.1.2' ); # + ".<index>"
my %oid_juniper_nsZoneCfgType = ( name => "nsZoneCfgType", mib => "NETSCREEN-ZONE-MIB", oid => '1.3.6.1.4.1.3224.8.1.1.1.3' ); # + ".<index>"

my %oid_juniper_nsVsysCfgId   = ( name => "nsVsysCfgId",   mib => "NETSCREEN-VSYS-MIB", oid => '1.3.6.1.4.1.3224.15.1.1.1.1' ); # + ".<index>"
my %oid_juniper_nsVsysCfgName = ( name => "nsVsysCfgName", mib => "NETSCREEN-VSYS-MIB", oid => '1.3.6.1.4.1.3224.15.1.1.1.2' ); # + ".<index>"

my %oid_juniper_nsrpVsdMemberStatus = ( name => "nsrpVsdMemberStatus", mib => "NETSCREEN-NSRP-MIB", oid => '1.3.6.1.4.1.3224.6.2.2.1.3.1', convertToReadable => {0=>'undefined',1=>'init',2=>'master',3=>'primary-backup',4=>'backup',5=>'ineligible',6=>'inoperable'}); # NSRP status

# Netapp specific OIDs (from NETWORK-APPLIANCE-MIB)
# ------------------------------------------------------------------------
my %oid_netapp_productModel     = ( name => "productModel",     mib => "NETWORK-APPLIANCE-MIB", oid => "1.3.6.1.4.1.789.1.1.5.0" );
my %oid_netapp_if64InOctets     = ( name => "if64InOctets",     mib => "NETWORK-APPLIANCE-MIB", oid => "1.3.6.1.4.1.789.1.22.1.2.1.25" ); # + ".<index>"
my %oid_netapp_if64OutOctets    = ( name => "if64OutOctets",    mib => "NETWORK-APPLIANCE-MIB", oid => "1.3.6.1.4.1.789.1.22.1.2.1.31" ); # + ".<index>"
my %oid_netapp_ifHighInOctets   = ( name => "ifHighInOctets",   mib => "NETWORK-APPLIANCE-MIB", oid => "1.3.6.1.4.1.789.1.22.1.2.1.3" );  # + ".<index>"
my %oid_netapp_ifLowInOctets    = ( name => "ifLowInOctets",    mib => "NETWORK-APPLIANCE-MIB", oid => "1.3.6.1.4.1.789.1.22.1.2.1.4" );  # + ".<index>"
my %oid_netapp_ifHighOutOctets  = ( name => "ifHighOutOctets",  mib => "NETWORK-APPLIANCE-MIB", oid => "1.3.6.1.4.1.789.1.22.1.2.1.15" ); # + ".<index>"
my %oid_netapp_ifLowOutOctets   = ( name => "ifLowOutOctets",   mib => "NETWORK-APPLIANCE-MIB", oid => "1.3.6.1.4.1.789.1.22.1.2.1.16" ); # + ".<index>"

# F5 BIG-IP specific OIDs (from F5-BIGIP-SYSTEM-MIB)
# ------------------------------------------------------------------------
my %oid_bigip_sysGeneralHwName    = ( name => "sysGeneralHwName",    mib => "F5-BIGIP-SYSTEM-MIB", oid => "1.3.6.1.4.1.3375.2.1.3.3.1.0" );     # since 9.0.5
my %oid_bigip_sysInterfaceName    = ( name => "sysInterfaceName",    mib => "F5-BIGIP-SYSTEM-MIB", oid => "1.3.6.1.4.1.3375.2.1.2.4.1.2.1.1" ); # + ".<index>" ex: 3.49.46.49
my %oid_bigip_sysInterfaceMacAddr = ( name => "sysInterfaceMacAddr", mib => "F5-BIGIP-SYSTEM-MIB", oid => "1.3.6.1.4.1.3375.2.1.2.4.1.2.1.6" ); # + ".<index>"
my %oid_bigip_sysIfxStatAlias     = ( name => "sysIfxStatAlias",     mib => "F5-BIGIP-SYSTEM-MIB", oid => "1.3.6.1.4.1.3375.2.1.2.4.5.3.1.17" ); # + ".<index>"

my %oid_bigip_sysInterfaceEnabled = ( name => "sysInterfaceEnabled", mib => "F5-BIGIP-SYSTEM-MIB", oid => "1.3.6.1.4.1.3375.2.1.2.4.1.2.1.8", convertToReadable => {0=>'false',1=>'true'}); # + ".<index>"
my %oid_bigip_sysInterfaceStatus  = ( name => "sysInterfaceStatus",  mib => "F5-BIGIP-SYSTEM-MIB", oid => "1.3.6.1.4.1.3375.2.1.2.4.1.2.1.17", convertToReadable => {0=>'up',1=>'down',2=>'disabled',3=>'uninitialized',4=>'loopback',5=>'unpopulated'}); # + ".<index>"
my %oid_bigip_sysIfxStatHighSpeed = ( name => "sysIfxStatHighSpeed", mib => "F5-BIGIP-SYSTEM-MIB", oid => "1.3.6.1.4.1.3375.2.1.2.4.5.3.1.14" ); # + ".<index>"

#my %oid_bigip_sysInterfaceStatBytesIn  = ( name => "sysInterfaceStatBytesIn",  mib => "F5-BIGIP-SYSTEM-MIB", oid => "1.3.6.1.4.1.3375.2.1.2.4.4.3.1.3" ); # + ".<index>"
#my %oid_bigip_sysInterfaceStatBytesOut = ( name => "sysInterfaceStatBytesOut", mib => "F5-BIGIP-SYSTEM-MIB", oid => "1.3.6.1.4.1.3375.2.1.2.4.4.3.1.5" ); # + ".<index>"
my %oid_bigip_sysIfxStatHcInOctets     = ( name => "sysIfxStatHcInOctets",     mib => "F5-BIGIP-SYSTEM-MIB", oid => "1.3.6.1.4.1.3375.2.1.2.4.5.3.1.6" ); # + ".<index>"
my %oid_bigip_sysIfxStatHcOutOctets    = ( name => "sysIfxStatHcOutOctets",    mib => "F5-BIGIP-SYSTEM-MIB", oid => "1.3.6.1.4.1.3375.2.1.2.4.5.3.1.10" ); # + ".<index>"

my %oid_bigip_sysInterfaceStatErrorsIn   = ( name => "sysInterfaceStatErrorsIn",   mib => "F5-BIGIP-SYSTEM-MIB", oid => "1.3.6.1.4.1.3375.2.1.2.4.4.3.1.8" ); # + ".<index>"
my %oid_bigip_sysInterfaceStatErrorsOut  = ( name => "sysInterfaceStatErrorsOut",  mib => "F5-BIGIP-SYSTEM-MIB", oid => "1.3.6.1.4.1.3375.2.1.2.4.4.3.1.9" ); # + ".<index>"
my %oid_bigip_sysInterfaceStatDropsIn    = ( name => "sysInterfaceStatDropsIn",    mib => "F5-BIGIP-SYSTEM-MIB", oid => "1.3.6.1.4.1.3375.2.1.2.4.4.3.1.10" ); # + ".<index>"
my %oid_bigip_sysInterfaceStatDropsOut   = ( name => "sysInterfaceStatDropsOut",   mib => "F5-BIGIP-SYSTEM-MIB", oid => "1.3.6.1.4.1.3375.2.1.2.4.4.3.1.11" ); # + ".<index>"
my %oid_bigip_sysInterfaceStatCollisions = ( name => "sysInterfaceStatCollisions", mib => "F5-BIGIP-SYSTEM-MIB", oid => "1.3.6.1.4.1.3375.2.1.2.4.4.3.1.12" ); # + ".<index>"

my %oid_bigip_sysInterfaceStatPktsIn  = ( name => "sysInterfaceStatPktsIn",  mib => "F5-BIGIP-SYSTEM-MIB", oid => "1.3.6.1.4.1.3375.2.1.2.4.4.3.1.2" ); # + ".<index>"
my %oid_bigip_sysInterfaceStatPktsOut = ( name => "sysInterfaceStatPktsOut", mib => "F5-BIGIP-SYSTEM-MIB", oid => "1.3.6.1.4.1.3375.2.1.2.4.4.3.1.4" ); # + ".<index>"

#my %oid_bigip_sysInterfaceMediaActiveSpeed  = ( name => "sysInterfaceMediaActiveSpeed",  mib => "F5-BIGIP-SYSTEM-MIB", oid => "1.3.6.1.4.1.3375.2.1.2.4.1.2.1.4" ); # + ".<index>"
my %oid_bigip_sysInterfaceMediaActiveDuplex = ( name => "sysInterfaceMediaActiveDuplex", mib => "F5-BIGIP-SYSTEM-MIB", oid => "1.3.6.1.4.1.3375.2.1.2.4.1.2.1.5", convertToReadable => {0=>'none',1=>'half',2=>'full'}); # + ".<index>"

#IP?


# Brocade specific OIDs (from SW-MIB mainly)
# ------------------------------------------------------------------------

my %oid_brocade_model             = ( name => "entPhysicalDescr",     mib => "ENTITY-MIB", oid => "1.3.6.1.2.1.47.1.1.1.1.2.1" );     # model
my %oid_brocade_serial            = ( name => "entPhysicalSerialNum", mib => "ENTITY-MIB", oid => "1.3.6.1.2.1.47.1.1.1.1.11.1" );    # serial number
my %oid_brocade_swFirmwareVersion = ( name => "swFirmwareVersion",    mib => "SW-MIB",     oid => "1.3.6.1.4.1.1588.2.1.1.1.1.6.0" ); # firmware version
#my %oid_brocade_swModel           = ( name => "swModel",              mib => "xxxxxxx",    oid => "1.3.6.1.4.1.1588.2.1.1.1.1.31" );  # Indicates whether the switch is 7500 or 7500E. Unfortunately not available on other models
my %oid_brocade_swBootDate        = ( name => "swBootDate",           mib => "SW-MIB",     oid => "1.3.6.1.4.1.1588.2.1.1.1.1.2.0" ); # boot date
my %oid_brocade_swOperStatus      = ( name => "swOperStatus",         mib => "SW-MIB",     oid => "1.3.6.1.4.1.1588.2.1.1.1.1.7.0", convertToReadable => {1=>'online', 2=>'offline', 3=>'testing', 4=>'faulty'} ); # current operational status of the switch
    # DESCRIPTION    "The current operational status of the switch.
    #    The states are as follow:
    #    o online(1) means the switch is accessible by an external Fibre Channel port;
    #    o offline(2) means the switch is not accessible;
    #    o testing(3) means the switch is in a built-in test mode and is not accessible by an external Fibre Channel port;
    #    o faulty(4) means the switch is not operational."

### swFCport oid sub-tree
my %oid_brocade_swFCPortOpStatus   = ( name => "swFCPortOpStatus",     mib => "SW-MIB", oid => "1.3.6.1.4.1.1588.2.1.1.1.6.2.1.4", convertToReadable => {0=> 'unknown', 1=>'online', 2=>'offline', 3=>'testing', 4=>'faulty'} ); # operational port status
    # DESCRIPTION    "This object identifies the operational status of the port. The online(1) state indicates that user frames
    #    can be passed. The unknown(0) state indicates that likely the port module is physically absent (see swFCPortPhyState)."
my %oid_brocade_swFCPortPhyState   = ( name => "swFCPortPhyState",     mib => "SW-MIB", oid => "1.3.6.1.4.1.1588.2.1.1.1.6.2.1.3", convertToReadable => {1=>'noCard', 2=>'noTransceiver', 3=>'LaserFault', 4=>'noLight', 5=>'noSync', 6=>'inSync', 7=>'portFault', 8=>'diagFault', 9=>'lockRef'} ); # physical port status
    # DESCRIPTION    "This object identifies the physical state of the port:
    #       noCard(1)           no card present in this switch slot;
    #       noTransceiver(2)    no Transceiver module in this port. noGbic(2) was used previously. Transceiver is the generic name for GBIC, SFP etc.;
    #       laserFault(3)       the module is signaling a laser fault (defective Transceiver);
    #       noLight(4)          the module is not receiving light;
    #       noSync(5)           the module is receiving light but is out of sync;
    #       inSync(6)           the module is receiving light and is in sync;
    #       portFault(7)        the port is marked faulty (defective Transceiver, cable or device);
    #       diagFault(8)        the port failed diagnostics (defective G_Port or FL_Port card or motherboard);
    #       lockRef(9)          the port is locking to the reference signal.
    #       validating(10)      Validation is in progress
    #       invalidModule(11)   Invalid SFP
    #       unknown(255)        unknown."
my %oid_brocade_swFCPortLinkState   = ( name => "swFCPortLinkState",   mib => "SW-MIB", oid => "1.3.6.1.4.1.1588.2.1.1.1.6.2.1.6", convertToReadable => {1=>'enabled', 2=>'disabled', 3=>'loopback'} ); # link port state
    # DESCRIPTION    "This object indicates the link state of the port.
    #     The value may be:
    #       enabled(1) - port is allowed to participate in the FC-PH protocol with its attached port (or ports if it is in a FC-AL loop);
    #       disabled(2) - the port is not allowed to participate in the FC-PH protocol with its attached port(s);
    #       loopback(3) - the port may transmit frames through an internal path to verify the health of the transmitter and receiver path.
    #     Note that when the port's link state changes, its operational status (swFCPortOpStatus) will be affected."
my %oid_brocade_swFCPortSpecifier   = ( name => "swFCPortSpecifier",   mib => "SW-MIB", oid => "1.3.6.1.4.1.1588.2.1.1.1.6.2.1.37" );
    # DESCRIPTION "This string indicates the physical port number of the addressed port.
    #     The format of the string is: <slot>/port, where 'slot' being present only for bladed systems."
my %oid_brocade_swFCPortName        = ( name => "swFCPortName",        mib => "SW-MIB", oid => "1.3.6.1.4.1.1588.2.1.1.1.6.2.1.36" ); # port name

my %oid_brocade_swFCPortTxWords     = ( name => "swFCPortTxWords",     mib => "SW-MIB", oid => "1.3.6.1.4.1.1588.2.1.1.1.6.2.1.11" ); # stat_wtx
my %oid_brocade_swFCPortRxWords     = ( name => "swFCPortRxWords",     mib => "SW-MIB", oid => "1.3.6.1.4.1.1588.2.1.1.1.6.2.1.12" ); # stat_wrx
my %oid_brocade_swFCPortTxFrames    = ( name => "swFCPortTxFrames",    mib => "SW-MIB", oid => "1.3.6.1.4.1.1588.2.1.1.1.6.2.1.13" ); # stat_ftx
my %oid_brocade_swFCPortRxFrames    = ( name => "swFCPortRxFrames",    mib => "SW-MIB", oid => "1.3.6.1.4.1.1588.2.1.1.1.6.2.1.14" ); # stat_frx
my %oid_brocade_swFCPortRxEncInFrs  = ( name => "swFCPortRxEncInFrs",  mib => "SW-MIB", oid => "1.3.6.1.4.1.1588.2.1.1.1.6.2.1.21" ); # er_enc_in
my %oid_brocade_swFCPortRxCrcs      = ( name => "swFCPortRxCrcs",      mib => "SW-MIB", oid => "1.3.6.1.4.1.1588.2.1.1.1.6.2.1.22" ); # er_crc
my %oid_brocade_swFCPortRxTruncs    = ( name => "swFCPortRxTruncs",    mib => "SW-MIB", oid => "1.3.6.1.4.1.1588.2.1.1.1.6.2.1.23" ); # er_trunc
my %oid_brocade_swFCPortRxTooLongs  = ( name => "swFCPortRxTooLongs",  mib => "SW-MIB", oid => "1.3.6.1.4.1.1588.2.1.1.1.6.2.1.24" ); # er_toolong
my %oid_brocade_swFCPortRxBadEofs   = ( name => "swFCPortRxBadEofs",   mib => "SW-MIB", oid => "1.3.6.1.4.1.1588.2.1.1.1.6.2.1.25" ); # er_bad_eof
my %oid_brocade_swFCPortRxEncOutFrs = ( name => "swFCPortRxEncOutFrs", mib => "SW-MIB", oid => "1.3.6.1.4.1.1588.2.1.1.1.6.2.1.26" ); # er_enc_out
my %oid_brocade_swFCPortC3Discards  = ( name => "swFCPortC3Discards",  mib => "SW-MIB", oid => "1.3.6.1.4.1.1588.2.1.1.1.6.2.1.28" ); # er_c3_timeout

### swNs oid sub-tree
my %oid_brocade_swNsNodeName = ( name => "swNsNodeName",     mib => "SW-MIB", oid => "1.3.6.1.4.1.1588.2.1.1.1.7.2.1.6" ); # the partner WWN
    # DESCRIPTION "The object identifies the Fibre Channel World_wide Name of the associated node as defined in FC-GS-2."
my %oid_brocade_swNsNodeSymb = ( name => "swNsNodeSymb",     mib => "SW-MIB", oid => "1.3.6.1.4.1.1588.2.1.1.1.7.2.1.7" ); # the partner WWN
    # DESCRIPTION    "The object identifies the contents of a Symbolic Name of the the node associated with the entry. In FC-GS-2,
    #     a Symbolic Name consists of a byte array of 1 through 255 bytes, and the first byte of the array specifies the length
    #     of its 'contents'. This object variable corresponds to the 'contents' of the Symbolic Name, without the first byte (specifying the length)."


# Nortel specific OIDs
# ------------------------------------------------------------------------
my %oid_nortel_model             = ( name => "entPhysicalDescr",     mib => "ENTITY-MIB",     oid => "1.3.6.1.2.1.47.1.1.1.1.2.1" );     # model
my %oid_nortel_serial            = ( name => "entPhysicalSerialNum", mib => "ENTITY-MIB",     oid => "1.3.6.1.2.1.47.1.1.1.1.11.1" );    # serial number
my %oid_nortel_rcVlanPortVlanIds = ( name => "rcVlanPortVlanIds",    mib => "RAPID-CITY-MIB", oid => "1.3.6.1.4.1.2272.1.3.3.1.3" );     # List of VLANs this port is assigned to


# ------------------------------------------------------------------------
# Other global variables
# ------------------------------------------------------------------------
my %ghOptions = ();
my %ghSNMPOptions = ();
my %quadmask2dec = (
    '0.0.0.0'         => 0,  '128.0.0.0'       => 1,  '192.0.0.0'       => 2,
    '224.0.0.0'       => 3,  '240.0.0.0'       => 4,  '248.0.0.0'       => 5,
    '252.0.0.0'       => 6,  '254.0.0.0'       => 7,  '255.0.0.0'       => 8,
    '255.128.0.0'     => 9,  '255.192.0.0'     => 10, '255.224.0.0'     => 11,
    '255.240.0.0'     => 12, '255.248.0.0'     => 13, '255.252.0.0'     => 14,
    '255.254.0.0'     => 15, '255.255.0.0'     => 16, '255.255.128.0'   => 17,
    '255.255.192.0'   => 18, '255.255.224.0'   => 19, '255.255.240.0'   => 20,
    '255.255.248.0'   => 21, '255.255.252.0'   => 22, '255.255.254.0'   => 23,
    '255.255.255.0'   => 24, '255.255.255.128' => 25, '255.255.255.192' => 26,
    '255.255.255.224' => 27, '255.255.255.240' => 28, '255.255.255.248' => 29,
    '255.255.255.252' => 30, '255.255.255.254' => 31, '255.255.255.255' => 32,
);
my %convhex2dec = qw(	0 0 1 1 2 2 3 3 4 4 5 5 6 6 7 7 8 8 9 9 
				                        a 10 b 11 c 12 d 13 e 14 f 15 
				                        A 10 B 11 C 12 D 13 E 14 F 15 );
my %ifTypeDescriptions = (
    1=>'Other types (other)',                                       137=>'Layer 3 Virtual LAN using IPX (l3ipxvlan)',
    2=>'regular1822 (regular1822)',                                 138=>'IP over Power Lines (digitalPowerline)',
    3=>'hdh1822 (hdh1822)',                                         139=>'Multimedia Mail over IP (mediaMailOverIp)',
    4=>'ddnX25 (ddnX25)',                                           140=>'Dynamic syncronous Transfer Mode (dtm)',
    5=>'Rfc877x25 (rfc877x25)',                                     141=>'Data Communications Network (dcn)',
    6=>'Ethernet-like interfaces (ethernetCsmacd)',                 142=>'IP Forwarding Interface (ipForward)',
    7=>'Ethernet-like interfaces (iso88023Csmacd)',                 143=>'Multi-rate Symmetric DSL (msdsl)',
    8=>'Iso88024TokenBus (iso88024TokenBus)',                       144=>'IEEE1394 High Performance Serial Bus (ieee1394)',
    9=>'Iso88025TokenRing (iso88025TokenRing)',                     145=>'HIPPI-6400 (if-gsn)',
    10=>'Iso88026Man (iso88026Man)',                                146=>'DVB-RCC MAC Layer (dvbRccMacLayer)',
    11=>'Ethernet-like interfaces (starLan)',                       147=>'DVB-RCC Downstream Channel (dvbRccDownstream)',
    12=>'Proteon10Mbit (proteon10Mbit)',                            148=>'DVB-RCC Upstream Channel (dvbRccUpstream)',
    13=>'Proteon80Mbit (proteon80Mbit)',                            149=>'ATM Virtual Interface (atmVirtual)',
    14=>'Hyperchannel (hyperchannel)',                              150=>'MPLS Tunnel Virtual Interface (mplsTunnel)',
    15=>'Fddi (fddi)',                                              151=>'Spatial Reuse Protocol (srp)',
    16=>'Lapb (lapb)',                                              152=>'Voice Over ATM (voiceOverAtm)',
    17=>'Sdlc (sdlc)',                                              153=>'Voice Over Frame Relay (voiceOverFrameRelay)',
    18=>'DS1-MIB (ds1)',                                            154=>'Digital Subscriber Loop over ISDN (idsl)',
    19=>'DS1-MIB (e1)',                                             155=>'Avici Composite Link Interface (compositeLink)',
    20=>'BasicISDN (basicISDN)',                                    156=>'SS7 Signaling Link (ss7SigLink)',
    21=>'PrimaryISDN (primaryISDN)',                                157=>'Prop. P2P wireless interface (propWirelessP2P)',
    22=>'Proprietary serial (propPointToPointSerial)',              158=>'Frame Forward Interface (frForward)',
    23=>'ppp (ppp)',                                                159=>'Multiprotocol over ATM AAL5 (rfc1483)',
    24=>'Software Loopback (softwareLoopback)',                     160=>'USB Interface (usb)',
    25=>'CLNP over IP (eon)',                                       161=>'IEEE 802.3ad Link Aggregate (ieee8023adLag)',
    26=>'Ethernet 3Mbit (ethernet3Mbit)',                           162=>'BGP Policy Accounting (bgppolicyaccounting)',
    27=>'XNS over IP (nsip)',                                       163=>'FRF .16 Multilink Frame Relay  (frf16MfrBundle)',
    28=>'Generic SLIP (slip)',                                      164=>'H323 Gatekeeper (h323Gatekeeper)',
    29=>'ULTRA technologies (ultra)',                               165=>'H323 Voice and Video Proxy (h323Proxy)',
    30=>'DS3-MIB (ds3)',                                            166=>'MPLS (mpls)',
    31=>'SMDS, coffee (sip)',                                       167=>'Multi-frequency signaling link (mfSigLink)',
    32=>'DTE only.  (frameRelay)',                                  168=>'High Bit-Rate DSL - 2nd generation (hdsl2)',
    33=>'rs232 (rs232)',                                            169=>'Multirate HDSL2 (shdsl)',
    34=>'Parallel-port (para)',                                     170=>'Facility Data Link 4Kbps on a DS1 (ds1FDL)',
    35=>'Arcnet (arcnet)',                                          171=>'Packet over SONET/SDH Interface (pos)',
    36=>'Arcnet plus (arcnetPlus)',                                 172=>'DVB-ASI Input (dvbAsiIn)',
    37=>'ATM cells (atm)',                                          173=>'DVB-ASI Output (dvbAsiOut)',
    38=>'miox25 (miox25)',                                          174=>'Power Line Communtications (plc)',
    39=>'SONET or SDH  (sonet)',                                    175=>'Non Facility Associated Signaling (nfas)',
    40=>'x25ple (x25ple)',                                          176=>'TR008 (tr008)',
    41=>'iso88022llc (iso88022llc)',                                177=>'Remote Digital Terminal (gr303RDT)',
    42=>'localTalk (localTalk)',                                    178=>'Integrated Digital Terminal (gr303IDT)',
    43=>'smdsDxi (smdsDxi)',                                        179=>'ISUP (isup)',
    44=>'FRNETSERV-MIB (frameRelayService)',                        180=>'Cisco proprietary Maclayer (propDocsWirelessMaclayer)',
    45=>'v35 (v35)',                                                181=>'Cisco proprietary Downstream (propDocsWirelessDownstream)',
    46=>'hssi (hssi)',                                              182=>'Cisco proprietary Upstream (propDocsWirelessUpstream)',
    47=>'hippi (hippi)',                                            183=>'HIPERLAN Type 2 Radio Interface (hiperlan2)',
    48=>'Generic modem (modem)',                                    184=>'IEEE 802.16 WMAN interface (propBWAp2Mp)',
    49=>'AAL5 over ATM (aal5)',                                     185=>'SONET Overhead Channel (sonetOverheadChannel)',
    50=>'sonetPath (sonetPath)',                                    186=>'Digital Wrapper (digitalWrapperOverheadChannel)',
    51=>'sonetVT (sonetVT)',                                        187=>'ATM adaptation layer 2 (aal2)',
    52=>'SMDS InterCarrier Interface (smdsIcip)',                   188=>'MAC layer over radio links (radioMAC)',
    53=>'proprietary virtual/internal (propVirtual)',               189=>'ATM over radio links (atmRadio)',
    54=>'proprietary multiplexing (propMultiplexor)',               190=>'Inter Machine Trunks (imt)',
    55=>'100BaseVG (ieee80212)',                                    191=>'Multiple Virtual Lines DSL (mvl)',
    56=>'Fibre Channel (fibreChannel)',                             192=>'Long Reach DSL (reachDSL)',
    57=>'HIPPI interfaces (hippiInterface)',                        193=>'Frame Relay DLCI End Point (frDlciEndPt)',
    58=>'Frame Relay (frameRelayInterconnect)',                     194=>'ATM VCI End Point (atmVciEndPt)',
    59=>'ATM Emulated LAN for 802.3 (aflane8023)',                  195=>'Optical Channel (opticalChannel)',
    60=>'ATM Emulated LAN for 802.5 (aflane8025)',                  196=>'Optical Transport (opticalTransport)',
    61=>'ATM Emulated circuit (cctEmul)',                           197=>'Proprietary ATM (propAtm)',
    62=>'Ethernet-like interfaces (fastEther)',                     198=>'Voice Over Cable Interface (voiceOverCable)',
    63=>'ISDN and X.25 (isdn)',                                     199=>'Infiniband (infiniband)',
    64=>'CCITT V.11/X.21 (v11)',                                    200=>'TE Link (teLink)',
    65=>'CCITT V.36 (v36)',                                         201=>'Q.2931 (q2931)',
    66=>'CCITT G703 at 64Kbps (g703at64k)',                         202=>'Virtual Trunk Group (virtualTg)',
    67=>'DS1-MIB (g703at2mb)',                                      203=>'SIP Trunk Group (sipTg)',
    68=>'SNA QLLC (qllc)',                                          204=>'SIP Signaling (sipSig)',
    69=>'Ethernet-like interfaces (fastEtherFX)',                   205=>'CATV Upstream Channel (docsCableUpstreamChannel)',
    70=>'channel (channel)',                                        206=>'Acorn Econet (econet)',
    71=>'radio spread spectrum (ieee80211)',                        207=>'FSAN 155Mb Symetrical PON interface (pon155)',
    72=>'IBM System 360/370 OEMI Channel (ibm370parChan)',          208=>'FSAN622Mb Symetrical PON interface (pon622)',
    73=>'IBM Enterprise Systems Connection (escon)',                209=>'Transparent bridge interface (bridge)',
    74=>'Data Link Switching (dlsw)',                               210=>'Interface common to multiple lines    (linegroup)',
    75=>'ISDN S/T interface (isdns)',                               211=>'voice E&M Feature Group D (voiceEMFGD)',
    76=>'ISDN U interface (isdnu)',                                 212=>'voice FGD Exchange Access North American (voiceFGDEANA)',
    77=>'Link Access Protocol D (lapd)',                            213=>'voice Direct Inward Dialing (voiceDID)',
    78=>'IP Switching Objects (ipSwitch)',                          214=>'MPEG transport interface (mpegTransport)',
    79=>'Remote Source Route Bridging (rsrb)',                      215=>'6to4 interface (sixToFour)',
    80=>'ATM Logical Port (atmLogical)',                            216=>'GTP (GPRS Tunneling Protocol) (gtp)',
    81=>'Digital Signal Level 0 (ds0)',                             217=>'Paradyne EtherLoop 1 (pdnEtherLoop1)',
    82=>'group of ds0s on the same ds1 (ds0Bundle)',                218=>'Paradyne EtherLoop 2 (pdnEtherLoop2)',
    83=>'Bisynchronous Protocol (bsc)',                             219=>'Optical Channel Group (opticalChannelGroup)',
    84=>'Asynchronous Protocol (async)',                            220=>'HomePNA ITU-T G.989 (homepna)',
    85=>'Combat Net Radio (cnr)',                                   221=>'Generic Framing Procedure (GFP) (gfp)',
    86=>'ISO 802.5r DTR (iso88025Dtr)',                             222=>'Layer 2 Virtual LAN using Cisco ISL (ciscoISLvlan)',
    87=>'Ext Pos Loc Report Sys (eplrs)',                           223=>'Acteleis proprietary MetaLOOP High Speed Link  (actelisMetaLOOP)',
    88=>'Appletalk Remote Access Protocol (arap)',                  224=>'FCIP Link  (fcipLink)',
    89=>'Proprietary Connectionless Protocol (propCnls)',           225=>'Resilient Packet Ring Interface Type (rpr)',
    90=>'CCITT-ITU X.29 PAD Protocol (hostPad)',                    226=>'RF Qam Interface (qam)',
    91=>'CCITT-ITU X.3 PAD Facility (termPad)',                     227=>'Link Management Protocol (lmp)',
    92=>'Multiproto Interconnect over FR (frameRelayMPI)',          228=>'Cambridge Broadband Networks Limited VectaStar (cblVectaStar)',
    93=>'CCITT-ITU X213 (x213)',                                    229=>'CATV Modular CMTS Downstream Interface (docsCableMCmtsDownstream)',
    94=>'Asymmetric Digital Subscriber Loop (adsl)',                230=>'Asymmetric Digital Subscriber Loop Version 2 (adsl2)',
    95=>'Rate-Adapt. Digital Subscriber Loop (radsl)',              231=>'MACSecControlled  (macSecControlledIF)',
    96=>'Symmetric Digital Subscriber Loop (sdsl)',                 232=>'MACSecUncontrolled (macSecUncontrolledIF)',
    97=>'Very H-Speed Digital Subscrib. Loop (vdsl)',               233=>'Avici Optical Ethernet Aggregate (aviciOpticalEther)',
    98=>'ISO 802.5 CRFP (iso88025CRFPInt)',                         234=>'atmbond (atmbond)',
    99=>'Myricom Myrinet (myrinet)',                                235=>'voice FGD Operator Services (voiceFGDOS)',
    100=>'voice recEive and transMit (voiceEM)',                    236=>'MultiMedia over Coax Alliance (MoCA) Interface (mocaVersion1)',
    101=>'voice Foreign Exchange Office (voiceFXO)',                237=>'IEEE 802.16 WMAN interface (ieee80216WMAN)',
    102=>'voice Foreign Exchange Station (voiceFXS)',               238=>'Asymmetric Digital Subscriber Loop Version 2, Version 2 Plus and all variants (adsl2plus)',
    103=>'voice encapsulation (voiceEncap)',                        239=>'DVB-RCS MAC Layer (dvbRcsMacLayer)',
    104=>'voice over IP encapsulation (voiceOverIp)',               240=>'DVB Satellite TDM (dvbTdm)',
    105=>'ATM DXI (atmDxi)',                                        241=>'DVB-RCS TDMA (dvbRcsTdma)',
    106=>'ATM FUNI (atmFuni)',                                      242=>'LAPS based on ITU-T X.86/Y.1323 (x86Laps)',
    107=>'ATM IMA (atmIma)',                                        243=>'3GPP WWAN (wwanPP)',
    108=>'PPP Multilink Bundle (pppMultilinkBundle)',               244=>'3GPP2 WWAN (wwanPP2)',
    109=>'IBM ipOverCdlc (ipOverCdlc)',                             245=>'voice P-phone EBS physical interface (voiceEBS)',
    110=>'IBM Common Link Access to Workstn (ipOverClaw)',          246=>'Pseudowire interface type (ifPwType)',
    111=>'IBM stackToStack (stackToStack)',                         247=>'Internal LAN on a bridge per IEEE 802.1ap (ilan)',
    112=>'IBM VIPA (virtualIpAddress)',                             248=>'Provider Instance Port on a bridge per IEEE 802.1ah PBB (pip)',
    113=>'IBM multi-protocol channel support (mpc)',                249=>'Alcatel-Lucent Ethernet Link Protection (aluELP)',
    114=>'IBM ipOverAtm (ipOverAtm)',                               250=>'Gigabit-capable passive optical networks (G-PON) (gpon)',
    115=>'ISO 802.5j Fiber Token Ring (iso88025Fiber)',             251=>'Very high speed digital subscriber line Version 2 (vdsl2)',
    116=>'IBM twinaxial data link control (tdlc)',                  252=>'WLAN Profile Interface (capwapDot11Profile)',
    117=>'Ethernet-like interfaces (gigabitEthernet)',              253=>'WLAN BSS Interface (capwapDot11Bss)',
    118=>'HDLC (hdlc)',                                             254=>'WTP Virtual Radio Interface (capwapWtpVirtualRadio)',
    119=>'LAP F (lapf)',                                            255=>'bitsport (bits)',
    120=>'V.37 (v37)',                                              256=>'DOCSIS CATV Upstream RF Port (docsCableUpstreamRfPort)',
    121=>'Multi-Link Protocol (x25mlp)',                            257=>'CATV downstream RF port (cableDownstreamRfPort)',
    122=>'X25 Hunt Group (x25huntGroup)',                           258=>'VMware Virtual Network Interface (vmwareVirtualNic)',
    123=>'Transp HDLC (transpHdlc)',                                259=>'IEEE 802.15.4 WPAN interface (ieee802154)',
    124=>'Interleave channel (interleave)',                         260=>'OTN Optical Data Unit (otnOdu)',
    125=>'Fast channel (fast)',                                     261=>'OTN Optical channel Transport Unit (otnOtu)',
    126=>'IP (for APPN HPR in IP networks) (ip)',                   262=>'VPLS Forwarding Instance Interface Type (ifVfiType)',
    127=>'CATV Mac Layer (docsCableMaclayer)',                      263=>'G.998.1 bonded interface (g9981)',
    128=>'CATV Downstream interface (docsCableDownstream)',         264=>'G.998.2 bonded interface (g9982)',
    129=>'CATV Upstream interface (docsCableUpstream)',             265=>'G.998.3 bonded interface (g9983)',
    130=>'Avalon Parallel Processor (a12MppSwitch)',                266=>'Ethernet Passive Optical Networks (E-PON) (aluEpon)',
    131=>'Encapsulation interface (tunnel)',                        267=>'EPON Optical Network Unit (aluEponOnu)',
    132=>'coffee pot (coffee)',                                     268=>'EPON physical User to Network interface (aluEponPhysicalUni)',
    133=>'Circuit Emulation Service (ces)',                         269=>'The emulation of a point-to-point link over the EPON layer (aluEponLogicalLink)',
    134=>'ATM Sub Interface (atmSubInterface)',                     270=>'GPON Optical Network Unit (aluGponOnu)',
    135=>'Layer 2 Virtual LAN using 802.1Q (l2vlan)',               271=>'GPON physical User to Network interface (aluGponPhysicalUni)',
    136=>'Layer 3 Virtual LAN using IP (l3ipvlan)',                 272=>'VMware NIC Team (vmwareNicTeam)'
);

# ------------------------------------------------------------------------
# Other global initializations
# ------------------------------------------------------------------------

my $grefaAllIndizes;                                 # Sorted array which holds all interface indexes
my $gBasetime;
my $gUsedDelta                       = 0;            # time delta for bandwidth calculations (really used)

my $gInitialRun                      = 0;            # Flag that will be set if there exists no interface information file
my $gNoHistory                       = 0;            # Flag that will be set in case there's no valid historical dataset
my $gDifferenceCounter               = 0;            # Number of changes. This variable is used in the exitcode algorithm
my $gIfLoadWarnCounter               = 0;            # counter for interfaces with warning load. This variable is used in the exitcode algorithm
my $gIfLoadCritCounter               = 0;            # counter for interfaces with critical load. This variable is used in the exitcode algorithm
my $gPktErrWarnCounter               = 0;
my $gPktErrCritCounter               = 0;
my $gPktDiscardWarnCounter           = 0;
my $gPktDiscardCritCounter           = 0;
my $gPktDropWarnCounter              = 0;
my $gPktDropCritCounter              = 0;
my $gNumberOfInterfaces              = 0;            # Total number of interfaces including vlans ...
my $gNumberOfFreeInterfaces          = 0;            # in "Calculate_LastTraffic" counted number of free interfaces
my $gNumberOfFreeUpInterfaces        = 0;            # in "Calculate_LastTraffic" counted number of free interfaces with status AdminUp
my $gNumberOfInterfacesWithoutTrunk  = 0;            # in "Calculate_LastTraffic" counted number of interfaces WITHOUT trunk ports
my $gInterfacesWithoutTrunk          = {};           # in "Calculate_LastTraffic" we use this for counting
my $gNumberOfPerfdataInterfaces      = 0;            # in "Evaluate_Interfaces" counted number of interfaces we collect perfdata for
my $gPerfdata                        = "";           # performancedata

my $gShortCacheTimer                 = 0;            # Short cache timer are calculated by check_options
my $gLongCacheTimer                  = 0;            # Long cache timer are calculated by check_options
my $gText                            = "";           # Plugin Output ...
my $gChangeText;                                     # Contains data of changes in interface properties
my $grefhFile;                                       # Properties from the interface file
my $grefhCurrent;                                    # Properties from current interface states
my $grefhListOfChanges               = undef;        # List all the changes for long plugin output
my $gExitCode                        = $ERRORS{"OK"};
my $gOutputSize                      = 0;
my $refhSNMPResult;                                  # Temp snmp structure result

my $gConfigTableOtherMsgInfo         = "";
my $gConfigTableOtherMsgWarn         = "";
my $gConfigTableOtherMsgCrit         = "";

# ========================================================================
# FUNCTION DECLARATIONS
# ========================================================================
sub check_options();




# OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO
# OOOOOOOOOOOOOOOOOOOOOOOOOOOOO            OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO
# OOOOOOOOOOOOOOOOOOOOOOOOOOOOO    MAIN    OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO
# OOOOOOOOOOOOOOOOOOOOOOOOOOOOO            OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO
# OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO

# Get command line options and adapt default values in %ghOptions
check_options();

# Set the timeout
logger(1, "Set global plugin timeout to ${TIMEOUT}s");
alarm($TIMEOUT);
$SIG{ALRM} = sub {
  ExitPlugin($ERRORS{"UNKNOWN"}, "Plugin timed out (${TIMEOUT}s).\nYou may need to extend the plugin timeout by using the -t option.");
};

# ------------------------------------------------------------------------
# Initializations depending on options
# ------------------------------------------------------------------------

my $gFile =  normalize($ghOptions{'hostdisplay'}).'-Interfacetable';    # create uniq file name without extension
my $gInterfaceInformationFile = "$ghOptions{'statedir'}/$gFile.txt";    # file where we store interface information table

# If --snapshot is set, we dont track changes
$ghOptions{'snapshot'} and $gInitialRun = 1;

# ------------------------------------------------------------------------
# Info table initializations
# ------------------------------------------------------------------------
my $gInfoTableHTML;                                      # Generated HTML code of the Info table
my $grefAoHInfoTableHeader = [                           # Header for the colomns of the Info table
    { Title => 'Name',                           Nodetype => 'ALL',                         Enabled => 1 },
    { Title => 'Uptime',                         Nodetype => 'ALL',                         Enabled => 1 },
    { Title => 'System Information',             Nodetype => 'ALL',                         Enabled => 1 },
    { Title => 'Type',                           Nodetype => 'cisco',                       Enabled => 1 },
    { Title => 'Serial',                         Nodetype => 'cisco,brocade,brocade-nos,nortel',        Enabled => 1 },
    { Title => 'Model',                          Nodetype => 'netapp,bigip,brocade,brocade-nos,nortel', Enabled => 1 },
    { Title => 'Firmware',                       Nodetype => 'brocade,brocade-nos',                     Enabled => 1 },
    { Title => 'Location',                       Nodetype => 'ALL',                         Enabled => 1 },
    { Title => 'Contact',                        Nodetype => 'ALL',                         Enabled => 1 },
    { Title => 'NSRP Status',                    Nodetype => 'netscreen',                   Enabled => 1 },
    { Title => 'Ports',                          Nodetype => 'ALL',                         Enabled => 1 },
    { Title => 'Delta (bandwidth calculations)', Nodetype => 'ALL',                         Enabled => 1 },
];
my $grefAoHInfoTableData;                                # Contents of the Info table (Uptime, SysDescr, ...)

# ------------------------------------------------------------------------
# Interface table initializations
# ------------------------------------------------------------------------
my $gInterfaceTableHTML;                                 # Html code of the interface table
my $grefAoHInterfaceTableHeader = [                      # Header for the cols of the html table
    { Title => 'Index',                Dataname => 'index',           Datatype => 'other',    Tablesort => 'sortable-numeric',            Nodetype => 'standard,cisco,hp,netscreen,netapp,bluecoat,brocade,brocade-nos,nortel', Enabled => 1 },
    { Title => 'Name',                 Dataname => 'ifName',          Datatype => 'other',    Tablesort => 'sortable-text',               Nodetype => 'ALL',                                                        Enabled => 1 },
    { Title => 'Alias',                Dataname => 'ifAlias',         Datatype => 'property', Tablesort => 'sortable-text',               Nodetype => 'ALL',                                                        Enabled => $ghOptions{'alias'} },
    { Title => 'Actions',              Dataname => 'actions',         Datatype => 'other',    Tablesort => '',                            Nodetype => 'ALL',                                                        Enabled => ($ghOptions{'enableperfdata'} or $ghOptions{'ifdetails'}) },
    { Title => 'Enabled',              Dataname => 'ifEnabled',       Datatype => 'property', Tablesort => 'sortable-text',               Nodetype => 'bigip',                                                      Enabled => 1 },
    { Title => 'Status',               Dataname => 'ifStatus',        Datatype => 'property', Tablesort => 'sortable-text',               Nodetype => 'bigip',                                                      Enabled => 1, 
        Tooltip => "The current state of the interface.<br> up - has link and is initialized<br> down - has no link and is initialized<br> disabled - has been forced down<br> uninitialized - has not been initialized<br> loopback - in loopback mode<br> unpopulated - interface not physically populated" },
    { Title => 'Admin status',         Dataname => 'ifAdminStatus',   Datatype => 'property', Tablesort => 'sortable-text',               Nodetype => 'standard,cisco,hp,netscreen,netapp,bluecoat,brocade,brocade-nos,nortel', Enabled => 1,
        Tooltip => '<TABLE><TR><TH>Value</TH><TH>Meaning</TH></TR><TR><TD>up</TD><TD>ready to pass packets</TD></TR><TR><TD>down</TD><TD></TD></TR><TR><TD>testing</TD><TD>in some test mode</TD></TR></TABLE>' },
    { Title => 'Oper status',          Dataname => 'ifOperStatus',    Datatype => 'property', Tablesort => 'sortable-text',               Nodetype => 'standard,cisco,hp,netscreen,netapp,bluecoat,brocade,brocade-nos,nortel', Enabled => 1, 
        Tooltip => '<TABLE><TR><TH>Value</TH><TH>Meaning</TH></TR><TR><TD>up</TD><TD>ready to pass packets</TD></TR><TR><TD>down</TD><TD></TD></TR><TR><TD>testing</TD><TD>in some test mode</TD></TR><TR><TD>unknown</TD><TD>status can not be determined for some reason</TD></TR><TR><TD>dormant</TD><TD></TD></TR><TR><TD>notPresent</TD><TD>some component are missing</TD></TR><TR><TD>lowerLayerDown</TD><TD>down due to state of lower-layer interface(s)</TD></TR></TABLE>' },
    { Title => 'Type',                 Dataname => 'ifType',          Datatype => 'property', Tablesort => 'sortable-text',               Nodetype => 'ALL',                                                        Enabled => $ghOptions{'type'},
        Tooltip => 'The type of interface. <br>Values for ifType are assigned by the Internet Assigned Numbers Authority (IANA), <br>and available in the IANAifType textual convention.' },
    { Title => 'Speed',                Dataname => 'ifSpeedReadable', Datatype => 'property', Tablesort => 'sortable-sortNetworkSpeed',   Nodetype => 'ALL',                                                        Enabled => 1 },
    { Title => 'Duplex',               Dataname => 'ifDuplexStatus',  Datatype => 'property', Tablesort => 'sortable-text',               Nodetype => 'ALL',                                                        Enabled => $ghOptions{'duplex'} },
    { Title => 'Stp',                  Dataname => 'ifStpState',      Datatype => 'property', Tablesort => 'sortable-text',               Nodetype => 'standard,cisco,hp,netscreen,netapp,bluecoat,brocade,brocade-nos,nortel', Enabled => $ghOptions{'stp'} },
    { Title => 'Vlan',                 Dataname => 'ifVlanNames',     Datatype => 'property', Tablesort => 'sortable-numeric',            Nodetype => 'ALL',                                                        Enabled => $ghOptions{'vlan'} },
    { Title => 'Zone',                 Dataname => 'nsIfZone',        Datatype => 'property', Tablesort => 'sortable-text',               Nodetype => 'netscreen',                                                  Enabled => 1 },
    { Title => 'Vsys',                 Dataname => 'nsIfVsys',        Datatype => 'property', Tablesort => 'sortable-text',               Nodetype => 'netscreen',                                                  Enabled => 1 },
    { Title => 'Permitted management', Dataname => 'nsIfMng',         Datatype => 'property', Tablesort => 'sortable-text',               Nodetype => 'netscreen',                                                  Enabled => 1 },
    { Title => 'Load In',              Dataname => 'ifLoadIn',        Datatype => 'load',     Tablesort => 'sortable-numeric',            Nodetype => 'ALL',                                                        Enabled => 1 },
    { Title => 'Load Out',             Dataname => 'ifLoadOut',       Datatype => 'load',     Tablesort => 'sortable-numeric',            Nodetype => 'ALL',                                                        Enabled => 1 },
    { Title => 'IP',                   Dataname => 'ifIpInfo',        Datatype => 'property', Tablesort => 'sortable-sortIPAddress',      Nodetype => 'standard,cisco,hp,netscreen,netapp,bluecoat,brocade,brocade-nos,nortel', Enabled => $ghOptions{'ipinfo'} },
    { Title => 'bpsIn',                Dataname => 'bpsInReadable',   Datatype => 'load',     Tablesort => 'sortable-sortNetworkTraffic', Nodetype => 'ALL',                                                        Enabled => 1 },
    { Title => 'bpsOut',               Dataname => 'bpsOutReadable',  Datatype => 'load',     Tablesort => 'sortable-sortNetworkTraffic', Nodetype => 'ALL',                                                        Enabled => 1 },
    { Title => 'Pkt err/disc',         Dataname => 'pktErrDiscard',   Datatype => 'load',     Tablesort => 'sortable-sortPktErrors',      Nodetype => 'standard,cisco,hp,netscreen,netapp,bluecoat,brocade,brocade-nos,nortel', Enabled => 1, 
        Tooltip => 'Number of error/discard packets per sec.<br>Format:<br>error in / error out / discard in / discard out' },
    { Title => 'Pkt err/drop',         Dataname => 'pktErrDrop',      Datatype => 'load',     Tablesort => 'sortable-sortPktErrors',      Nodetype => 'bigip', Enabled => 1, 
        Tooltip => 'Number of error/drop packets per sec.<br>Format:<br>error in / error out / drop in / drop out' },
    { Title => 'Pkt load',             Dataname => 'pktUcastNUcast',  Datatype => 'load',     Tablesort => 'sortable-sortPktErrors',      Nodetype => 'standard,cisco,hp,netscreen,netapp,bluecoat,brocade,brocade-nos,nortel', Enabled => $ghOptions{'pkt'}, 
        Tooltip => 'Number of unicast/non-unicast packets per sec.<br>Format:<br>Ucast in / Ucast out / NUcast in / NUcast out' },
    { Title => 'Last traffic',         Dataname => 'ifLastTraffic',   Datatype => 'other',    Tablesort => 'sortable-sortDuration',       Nodetype => 'ALL',                                                        Enabled => 1 },
];
my $grefAoHInterfaceTableData;                           # Contents of the interface table (Uptime, OperStatus, ...)

# ------------------------------------------------------------------------
# Configuration table initializations
# ------------------------------------------------------------------------
my $gConfigTableHTML;                   # Generated HTML code of the Config table
my $grefAoHConfigTableHeader = [        # Header for the colomns of the Config table
    { Title => 'Title', Nodetype => 'ALL', Enabled => 1 },
    { Title => 'Value', Nodetype => 'ALL', Enabled => 1 },
];
my $grefAoHConfigTableData;             # Contents of the Config table
$grefAoHConfigTableData->[0]->[0]->{Value} = "Globally excluded interfaces";
$grefAoHConfigTableData->[1]->[0]->{Value} = "Excluded interfaces from traffic tracking";
$grefAoHConfigTableData->[2]->[0]->{Value} = "Excluded interfaces from property tracking";
$grefAoHConfigTableData->[3]->[0]->{Value} = "Interface traffic load thresholds";
$grefAoHConfigTableData->[4]->[0]->{Value} = "Interface packet error/discard thresholds";
$grefAoHConfigTableData->[5]->[0]->{Value} = "Interface property tracked";
$grefAoHConfigTableData->[6]->[0]->{Value} = "Interface property change thresholds";
$grefAoHConfigTableData->[7]->[0]->{Value} = "Bandwidth monitoring capacity";
$grefAoHConfigTableData->[8]->[0]->{Value} = "Other";
#init
$grefAoHConfigTableData->[0]->[1]->{Value} = "";
$grefAoHConfigTableData->[1]->[1]->{Value} = "";
$grefAoHConfigTableData->[2]->[1]->{Value} = "";
$grefAoHConfigTableData->[3]->[1]->{Value} = "";
$grefAoHConfigTableData->[4]->[1]->{Value} = "";
$grefAoHConfigTableData->[5]->[1]->{Value} = "";
$grefAoHConfigTableData->[6]->[1]->{Value} = "";
$grefAoHConfigTableData->[7]->[1]->{Value} = "";
$grefAoHConfigTableData->[8]->[1]->{Value} = "";

# ------------------------------------------------------------------------------
# Check host and snmp service reachability
# ------------------------------------------------------------------------------

# get uptime of the host - no caching !

logger(1, "Check that the target \"$ghOptions{hostquery}\" is reachable via snmp");
eval {
    my %hOptions = ( %ghSNMPOptions, (oids => [ "$oid_sysUpTime{'oid'}" ], cachetimer => 0, outputhashkeyidx => 0, checkempty => 1));
    $refhSNMPResult = GetDataWithSnmp (\%hOptions);
};
ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_sysUpTime ])) if ($@);
$grefhCurrent->{MD}->{Node}->{sysUpTime} = $refhSNMPResult->{$oid_sysUpTime{'oid'}};

# ------------------------------------------------------------------------------
# Automatic vendor identification
# ------------------------------------------------------------------------------
if ($ghOptions{'nodetype-auto'}) {
    # get sysObjectID.0 to identify the vendor
    logger(1, "Automatic vendor identification");
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => [ "$oid_sysObjectID{'oid'}" ], cachetimer => $gLongCacheTimer, outputhashkeyidx => 0, checkempty => 1));
        $refhSNMPResult = GetDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_sysObjectID ])) if ($@);
    
    # keep a trace of the retrieved value
    $grefhCurrent->{MD}->{Node}->{sysObjectID} = $refhSNMPResult->{$oid_sysObjectID{'oid'}};
    
    # try to map the id retrieved to a known vendor id corresponing to a nodetype
    my @identify_array = split ('\.', $refhSNMPResult->{$oid_sysObjectID{'oid'}});
    my $vendor_code = (defined $identify_array[6]) ? $identify_array[6] : -1;
    my $identity = "standard";
    if (defined $oid_sysObjectID{'convertToReadable'}{$vendor_code}) {
        $identity = $oid_sysObjectID{'convertToReadable'}{"$identify_array[6]"};
        logger(1, "  -> vendor code \"$vendor_code\", nodetype \"$identity\" detected");
    } else {
        logger(1, "  -> vendor code \"$vendor_code\", nodetype not identified");
    }
    
    # set the nodetype
    $ghOptions{'nodetype'} = "$identity";
}

# ------------------------------------------------------------------------------
# Read historical data (from state file)
# ------------------------------------------------------------------------------

# read all interfaces and their properties into the hash
$grefhFile = ReadInterfaceInformationFile ("$gInterfaceInformationFile");
logger(5, "Data from files -> grefhFile:".Dumper($grefhFile));

# clean and select a valid historical dataset
$gBasetime = CleanAndSelectHistoricalDataset();
$gNoHistory = 1 unless (defined $gBasetime);

# ------------------------------------------------------------------------------
# Read node related data (from snmp/cache)
# ------------------------------------------------------------------------------

# get sysDescr, sysName and other info for the info table. caching the long parameter
logger(1, "Retrieve target system information");
eval {
    my %hOptions = ( %ghSNMPOptions, (oids => [ "$oid_sysDescr{'oid'}","$oid_sysName{'oid'}","$oid_sysContact{'oid'}","$oid_sysLocation{'oid'}" ], cachetimer => $gLongCacheTimer, outputhashkeyidx => 0, checkempty => 0));
    $refhSNMPResult = GetDataWithSnmp (\%hOptions);
};
ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_sysDescr, \%oid_sysName, \%oid_sysContact, \%oid_sysLocation ])) if ($@);
$grefhCurrent->{MD}->{Node}->{sysDescr} = "$refhSNMPResult->{$oid_sysDescr{'oid'}}";
$grefhCurrent->{MD}->{Node}->{sysName}  = "$refhSNMPResult->{$oid_sysName{'oid'}}";
$grefhCurrent->{MD}->{Node}->{sysContact} = "$refhSNMPResult->{$oid_sysContact{'oid'}}";
$grefhCurrent->{MD}->{Node}->{sysLocation}  = "$refhSNMPResult->{$oid_sysLocation{'oid'}}";
if ($ghOptions{'nodetype'} eq "cisco") {
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => [ "$oid_cisco_ChassisModel{'oid'}","$oid_cisco_ChassisSrNumStr{'oid'}" ], cachetimer => $gLongCacheTimer, outputhashkeyidx => 0, checkempty => 0));
        $refhSNMPResult = GetDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_cisco_ChassisModel, \%oid_cisco_ChassisSrNumStr ])) if ($@);
    if ($refhSNMPResult->{$oid_cisco_ChassisModel{'oid'}} eq "" and $refhSNMPResult->{$oid_cisco_ChassisSrNumStr{'oid'}} eq "") {
        # looking at other info locations
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => [ "$oid_cisco_model{'oid'}","$oid_cisco_serial{'oid'}" ], cachetimer => $gLongCacheTimer, outputhashkeyidx => 0, checkempty => 0));
            $refhSNMPResult = GetDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_cisco_model, \%oid_cisco_serial ])) if ($@);
        $grefhCurrent->{MD}->{Node}->{cisco_type}   = "$refhSNMPResult->{$oid_cisco_model{'oid'}}";
        $grefhCurrent->{MD}->{Node}->{cisco_serial} = "$refhSNMPResult->{$oid_cisco_serial{'oid'}}";
    } else {
        $grefhCurrent->{MD}->{Node}->{cisco_type}   = "$refhSNMPResult->{$oid_cisco_ChassisModel{'oid'}}";
        $grefhCurrent->{MD}->{Node}->{cisco_serial} = "$refhSNMPResult->{$oid_cisco_ChassisSrNumStr{'oid'}}";
    }
}
if ($ghOptions{'nodetype'} eq "netapp") {
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => [ "$oid_netapp_productModel{'oid'}" ], cachetimer => $gLongCacheTimer, outputhashkeyidx => 0, checkempty => 0));
        $refhSNMPResult = GetDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_netapp_productModel ])) if ($@);
    $grefhCurrent->{MD}->{Node}->{netapp_model} = "$refhSNMPResult->{$oid_netapp_productModel{'oid'}}";
}
if ($ghOptions{'nodetype'} eq "bigip") {
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => [ "$oid_bigip_sysGeneralHwName{'oid'}" ], cachetimer => $gLongCacheTimer, outputhashkeyidx => 0, checkempty => 0));
        $refhSNMPResult = GetDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_bigip_sysGeneralHwName ])) if ($@);
    $grefhCurrent->{MD}->{Node}->{bigip_model} = "$refhSNMPResult->{$oid_bigip_sysGeneralHwName{'oid'}}";
}
if ($ghOptions{'nodetype'} eq "brocade" or $ghOptions{'nodetype'} eq "brocade-nos") {
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => [ "$oid_brocade_swFirmwareVersion{'oid'}","$oid_brocade_model{'oid'}","$oid_brocade_serial{'oid'}" ], cachetimer => $gLongCacheTimer, outputhashkeyidx => 0, checkempty => 0));
        $refhSNMPResult = GetDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_brocade_swFirmwareVersion, \%oid_brocade_model, \%oid_brocade_serial ])) if ($@);
    $grefhCurrent->{MD}->{Node}->{brocade_firmware} = "$refhSNMPResult->{$oid_brocade_swFirmwareVersion{'oid'}}";
    $grefhCurrent->{MD}->{Node}->{brocade_model} = "$refhSNMPResult->{$oid_brocade_model{'oid'}}";
    $grefhCurrent->{MD}->{Node}->{brocade_serial} = "$refhSNMPResult->{$oid_brocade_serial{'oid'}}";
}
if ($ghOptions{'nodetype'} eq "nortel") {
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => [ "$oid_nortel_model{'oid'}","$oid_nortel_serial{'oid'}" ], cachetimer => $gLongCacheTimer, outputhashkeyidx => 0, checkempty => 0));
        $refhSNMPResult = GetDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_nortel_model, \%oid_nortel_serial ])) if ($@);
    $grefhCurrent->{MD}->{Node}->{nortel_model} = "$refhSNMPResult->{$oid_nortel_model{'oid'}}";
    $grefhCurrent->{MD}->{Node}->{nortel_serial} = "$refhSNMPResult->{$oid_nortel_serial{'oid'}}";
}
if ($ghOptions{'nodetype'} eq "netscreen") {
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => [ "$oid_juniper_nsrpVsdMemberStatus{'oid'}" ], cachetimer => 0, outputhashkeyidx => 0, checkempty => 0));
        $refhSNMPResult = GetDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_juniper_nsrpVsdMemberStatus ])) if ($@);
    $grefhCurrent->{MD}->{Node}->{netscreen_nsrp} = (defined $oid_juniper_nsrpVsdMemberStatus{'convertToReadable'}{"$refhSNMPResult->{$oid_juniper_nsrpVsdMemberStatus{'oid'}}"})
        ? $oid_juniper_nsrpVsdMemberStatus{'convertToReadable'}{"$refhSNMPResult->{$oid_juniper_nsrpVsdMemberStatus{'oid'}}"} : "";
}

# ------------------------------------------------------------------------------
# Read/collect interface related data (from snmp/cache)
# ------------------------------------------------------------------------------

# +++++ Cisco +++++
if ($ghOptions{'nodetype'} eq "cisco") {
    Get_InterfaceNames (\%oid_ifDescr, \%oid_ifPhysAddress); # Gather interface indexes, descriptions, and mac addresses, to generate unique and reformatted interface names.
    Get_InterfaceType (\%oid_ifType) if ($ghOptions{'type'} or $ghOptions{'table-split'}); # Gather interface types
    Get_AdminStatus (\%oid_ifAdminStatus); # Gather interface administration status
    Get_OperStatus (\%oid_ifOperStatus); # Gather interface operational status
    Get_Speed (\%oid_ifSpeed, \%oid_ifHighSpeed); # Gather interface speed
    Get_Alias (\%oid_ifAlias) if ($ghOptions{'alias'}); # Gather interface alias
    Get_Duplex (\%oid_ifDuplexStatus) if ($ghOptions{'duplex'}); # Gather interface duplex state
    Get_IpInfo (\%oid_ipAdEntIfIndex, \%oid_ipAdEntNetMask) if ($ghOptions{'ipinfo'}); # Gather interface ip addresses and masks
    if ($ghSNMPOptions{'64bits'}) {  # Gather interface traffics (in/out and packet errors/discards)
        Get_Traffic ('64+32', \%oid_ifHCInOctets, \%oid_ifHCOutOctets, \%oid_ifInOctets, \%oid_ifOutOctets);
    } else {
        Get_Traffic ('32', \%oid_ifInOctets, \%oid_ifOutOctets);
    }
    Get_Error_Discard();
    if ($ghOptions{'pkt'}) {  # Gather interface packet traffic
        if ($ghSNMPOptions{'64bits'}) {
            Get_Packets ('64', \%oid_ifHCInUcastPkts, \%oid_ifHCOutUcastPkts, \%oid_ifHCInMulticastPkts, \%oid_ifHCOutMulticastPkts, \%oid_ifHCInBroadcastPkts, \%oid_ifHCOutBroadcastPkts);
        } else {
            Get_Packets ('32', \%oid_ifInUcastPkts, \%oid_ifOutUcastPkts, \%oid_ifInNUcastPkts, \%oid_ifOutNUcastPkts);
        }
    }
    Get_Vlan_Cisco (\%oid_cisco_vmVlan) if ($ghOptions{'vlan'}); # Gather interface vlans
    Get_Stp () if ($ghOptions{'stp'}); # Gather Spanning Tree specific info
}
# +++++ HP +++++
elsif ($ghOptions{'nodetype'} eq "hp") {
    Get_InterfaceNames (\%oid_ifDescr, \%oid_ifPhysAddress); # Gather interface indexes, descriptions, and mac addresses, to generate unique and reformatted interface names.
    Get_InterfaceType (\%oid_ifType) if ($ghOptions{'type'} or $ghOptions{'table-split'}); # Gather interface types
    Get_AdminStatus (\%oid_ifAdminStatus); # Gather interface administration status
    Get_OperStatus (\%oid_ifOperStatus); # Gather interface operational status
    Get_Speed (\%oid_ifSpeed, \%oid_ifHighSpeed); # Gather interface speed
    Get_Alias (\%oid_ifAlias) if ($ghOptions{'alias'}); # Gather interface alias
    Get_Duplex (\%oid_ifDuplexStatus) if ($ghOptions{'duplex'}); # Gather interface duplex state
    Get_IpInfo (\%oid_ipAdEntIfIndex, \%oid_ipAdEntNetMask) if ($ghOptions{'ipinfo'}); # Gather interface ip addresses and masks
    if ($ghSNMPOptions{'64bits'}) {  # Gather interface traffics (in/out and packet errors/discards)
        Get_Traffic ('64', \%oid_ifHCInOctets, \%oid_ifHCOutOctets);
    } else {
        Get_Traffic ('32', \%oid_ifInOctets, \%oid_ifOutOctets);
    }
    Get_Error_Discard();
    Get_Vlan_Hp (\%oid_ifVlanName, \%oid_hp_ifVlanPort) if ($ghOptions{'vlan'}); # Gather interface vlans
    Get_Stp () if ($ghOptions{'stp'}); # Gather Spanning Tree specific info
}
# +++++ Netapp +++++
elsif ($ghOptions{'nodetype'} eq "netapp") {
    Get_InterfaceNames (\%oid_ifDescr, \%oid_ifPhysAddress); # Gather interface indexes, descriptions, and mac addresses, to generate unique and reformatted interface names.
    Get_InterfaceType (\%oid_ifType) if ($ghOptions{'type'} or $ghOptions{'table-split'}); # Gather interface types
    Get_AdminStatus (\%oid_ifAdminStatus); # Gather interface administration status
    Get_OperStatus (\%oid_ifOperStatus); # Gather interface operational status
    Get_Speed (\%oid_ifSpeed, \%oid_ifHighSpeed); # Gather interface speed
    Get_Alias (\%oid_ifAlias) if ($ghOptions{'alias'}); # Gather interface alias
    Get_Duplex (\%oid_ifDuplexStatus) if ($ghOptions{'duplex'}); # Gather interface duplex state
    Get_IpInfo (\%oid_ipAdEntIfIndex, \%oid_ipAdEntNetMask) if ($ghOptions{'ipinfo'}); # Gather interface ip addresses and masks
    if ($ghSNMPOptions{'64bits'}) {
        Get_Traffic ('64', \%oid_netapp_if64InOctets, \%oid_netapp_if64OutOctets);
    } else {
        Get_Traffic ('HighLow', \%oid_netapp_ifHighInOctets, \%oid_netapp_ifLowInOctets, \%oid_netapp_ifHighOutOctets, \%oid_netapp_ifLowOutOctets); # Gather interface traffics (in/out and packet errors/discards)
    }
    Get_Error_Discard();
    Get_Stp () if ($ghOptions{'stp'}); # Gather Spanning Tree specific info
}
# +++++ Netscreen +++++
elsif ($ghOptions{'nodetype'} eq "netscreen") {
    Get_InterfaceNames (\%oid_ifDescr, \%oid_ifPhysAddress); # Gather interface indexes, descriptions, and mac addresses, to generate unique and reformatted interface names.
    Get_InterfaceType (\%oid_ifType) if ($ghOptions{'type'} or $ghOptions{'table-split'}); # Gather interface types
    Get_AdminStatus (\%oid_ifAdminStatus); # Gather interface administration status
    Get_OperStatus_Netscreen (\%oid_ifOperStatus); # Gather interface operational status
    Get_Speed (\%oid_ifSpeed, \%oid_ifHighSpeed); # Gather interface speed
    Get_Alias (\%oid_ifAlias) if ($ghOptions{'alias'}); # Gather interface alias
    Get_Duplex (\%oid_ifDuplexStatus) if ($ghOptions{'duplex'}); # Gather interface duplex state
    Get_IpInfo_Netscreen (\%oid_juniper_nsIfName, \%oid_juniper_nsIfIp, \%oid_juniper_nsIfNetmask) if ($ghOptions{'ipinfo'}); # Gather interface ip addresses and masks
    if ($ghSNMPOptions{'64bits'}) {  # Gather interface traffics (in/out and packet errors/discards)
        Get_Traffic ('64', \%oid_ifHCInOctets, \%oid_ifHCOutOctets);
    } else {
        Get_Traffic ('32', \%oid_ifInOctets, \%oid_ifOutOctets); 
    }
    Get_Error_Discard();
    if ($ghOptions{'pkt'}) {  # Gather interface packet traffic
        if ($ghSNMPOptions{'64bits'}) {
            Get_Packets ('64', \%oid_ifHCInUcastPkts, \%oid_ifHCOutUcastPkts, \%oid_ifHCInMulticastPkts, \%oid_ifHCOutMulticastPkts, \%oid_ifHCInBroadcastPkts, \%oid_ifHCOutBroadcastPkts);
        } else {
            Get_Packets ('32', \%oid_ifInUcastPkts, \%oid_ifOutUcastPkts, \%oid_ifInNUcastPkts, \%oid_ifOutNUcastPkts);
        }
    }
    Get_Stp () if ($ghOptions{'stp'}); # Gather Spanning Tree specific info
    Get_Specific_Netscreen (); # Gather Juniper Netscreen specific info
}
# +++++ F5 BigIp +++++
elsif ($ghOptions{'nodetype'} eq "bigip") {
    Get_InterfaceNames_Bigip (); # Gather interface indexes, descriptions, and mac addresses, to generate unique and reformatted interface names.
#    Get_InterfaceType (\%oid_ifType) if ($ghOptions{'type'} or $ghOptions{'table-split'}); # Gather interface types
    Get_InterfaceEnabled_Bigip (\%oid_bigip_sysInterfaceEnabled); # Gather interface administration status
    Get_InterfaceStatus_Bigip (\%oid_bigip_sysInterfaceStatus); # Gather interface operational status
    Get_Speed (undef, \%oid_bigip_sysIfxStatHighSpeed); # Gather interface speed
    Get_Alias (\%oid_bigip_sysIfxStatAlias) if ($ghOptions{'alias'}); # Gather interface alias
    Get_Duplex (\%oid_bigip_sysInterfaceMediaActiveDuplex) if ($ghOptions{'duplex'}); # Gather interface duplex state
    Get_Traffic ('64', \%oid_bigip_sysIfxStatHcInOctets, \%oid_bigip_sysIfxStatHcOutOctets); # Gather interface traffics (in/out and packet errors/discards)
    Get_Error_Drop_Bigip ();
}
# +++++ BlueCoat +++++
elsif ($ghOptions{'nodetype'} eq "bluecoat") {
    Get_InterfaceNames (\%oid_ifDescr, \%oid_ifPhysAddress); # Gather interface indexes, descriptions, and mac addresses, to generate unique and reformatted interface names.
    Get_InterfaceType (\%oid_ifType) if ($ghOptions{'type'} or $ghOptions{'table-split'}); # Gather interface types
    Get_AdminStatus (\%oid_ifAdminStatus); # Gather interface administration status
    Get_OperStatus (\%oid_ifOperStatus); # Gather interface operational status
    Get_Speed (\%oid_ifSpeed, \%oid_ifHighSpeed); # Gather interface speed
    Get_Alias (\%oid_ifAlias) if ($ghOptions{'alias'}); # Gather interface alias
    Get_Duplex (\%oid_ifDuplexStatus) if ($ghOptions{'duplex'}); # Gather interface duplex state
    Get_IpInfo (\%oid_ipAddressIfIndex_ipv4, \%oid_ipAdEntNetMask) if ($ghOptions{'ipinfo'}); # Gather interface ip addresses and masks
    if ($ghSNMPOptions{'64bits'}) {  # Gather interface traffics (in/out and packet errors/discards)
        Get_Traffic ('64', \%oid_ifHCInOctets, \%oid_ifHCOutOctets);
    } else {
        Get_Traffic ('32', \%oid_ifInOctets, \%oid_ifOutOctets); 
    }
    Get_Error_Discard();
    ###Get_Vlan (); # Gather interface vlans
    Get_Stp () if ($ghOptions{'stp'}); # Gather Spanning Tree specific info
}
# +++++ Brocade +++++
elsif ($ghOptions{'nodetype'} eq "brocade") {
    Get_InterfaceNames (\%oid_ifDescr, \%oid_ifPhysAddress); # Gather interface indexes, descriptions, and mac addresses, to generate unique and reformatted interface names.
    Get_InterfaceType (\%oid_ifType) if ($ghOptions{'type'} or $ghOptions{'table-split'}); # Gather interface types
    Get_AdminStatus (\%oid_ifAdminStatus); # Gather interface administration status
    Get_OperStatus (\%oid_ifOperStatus); # Gather interface operational status
    Get_Speed (\%oid_ifSpeed, \%oid_ifHighSpeed); # Gather interface speed
    Get_Alias_Brocade () if ($ghOptions{'alias'}); # Gather interface alias
    Get_Duplex (\%oid_ifDuplexStatus) if ($ghOptions{'duplex'}); # Gather interface duplex state
    Get_IpInfo (\%oid_ipAdEntIfIndex, \%oid_ipAdEntNetMask) if ($ghOptions{'ipinfo'}); # Gather interface ip addresses and masks
    if ($ghSNMPOptions{'64bits'}) {  # Gather interface traffics (in/out and packet errors/discards)
        Get_Traffic ('64', \%oid_ifHCInOctets, \%oid_ifHCOutOctets);
    } else {
        Get_Traffic ('32', \%oid_ifInOctets, \%oid_ifOutOctets);
    }
    Get_Error_Discard();
    if ($ghOptions{'pkt'}) {  # Gather interface packet traffic
        if ($ghSNMPOptions{'64bits'}) {
            Get_Packets ('64', \%oid_ifHCInUcastPkts, \%oid_ifHCOutUcastPkts, \%oid_ifHCInMulticastPkts, \%oid_ifHCOutMulticastPkts, \%oid_ifHCInBroadcastPkts, \%oid_ifHCOutBroadcastPkts);
        } else {
            Get_Packets ('32', \%oid_ifInUcastPkts, \%oid_ifOutUcastPkts, \%oid_ifInNUcastPkts, \%oid_ifOutNUcastPkts);
        }
    }
    ###Get_Vlan (); # Gather interface vlans
    Get_Stp () if ($ghOptions{'stp'}); # Gather Spanning Tree specific info

}
# +++++ Brocade NOS +++++
elsif ($ghOptions{'nodetype'} eq "brocade-nos") {
    Get_InterfaceNames (\%oid_ifName, \%oid_ifPhysAddress); # Gather interface indexes, descriptions, and mac addresses, to generate unique and reformatted interface names.
    Get_InterfaceType (\%oid_ifType) if ($ghOptions{'type'} or $ghOptions{'table-split'}); # Gather interface types
    Get_AdminStatus (\%oid_ifAdminStatus); # Gather interface administration status
    Get_OperStatus (\%oid_ifOperStatus); # Gather interface operational status
    Get_Speed (\%oid_ifSpeed, \%oid_ifHighSpeed); # Gather interface speed
    Get_Alias_Brocade () if ($ghOptions{'alias'}); # Gather interface alias
    Get_Duplex (\%oid_ifDuplexStatus) if ($ghOptions{'duplex'}); # Gather interface duplex state
    Get_IpInfo (\%oid_ipAdEntIfIndex, \%oid_ipAdEntNetMask) if ($ghOptions{'ipinfo'}); # Gather interface ip addresses and masks
    if ($ghSNMPOptions{'64bits'}) {  # Gather interface traffics (in/out and packet errors/discards)
        Get_Traffic ('64', \%oid_ifHCInOctets, \%oid_ifHCOutOctets);
    } else {
        Get_Traffic ('32', \%oid_ifInOctets, \%oid_ifOutOctets);
    }
    Get_Error_Discard();
    if ($ghOptions{'pkt'}) {  # Gather interface packet traffic
        if ($ghSNMPOptions{'64bits'}) {
            Get_Packets ('64', \%oid_ifHCInUcastPkts, \%oid_ifHCOutUcastPkts, \%oid_ifHCInMulticastPkts, \%oid_ifHCOutMulticastPkts, \%oid_ifHCInBroadcastPkts, \%oid_ifHCOutBroadcastPkts);
        } else {
            Get_Packets ('32', \%oid_ifInUcastPkts, \%oid_ifOutUcastPkts, \%oid_ifInNUcastPkts, \%oid_ifOutNUcastPkts);
        }
    }
    ###Get_Vlan (); # Gather interface vlans
    Get_Stp () if ($ghOptions{'stp'}); # Gather Spanning Tree specific info

}
# +++++ Nortel +++++
elsif ($ghOptions{'nodetype'} eq "nortel") {
    Get_InterfaceNames (\%oid_ifDescr, \%oid_ifPhysAddress); # Gather interface indexes, descriptions, and mac addresses, to generate unique and reformatted interface names.
    Get_InterfaceType (\%oid_ifType) if ($ghOptions{'type'} or $ghOptions{'table-split'}); # Gather interface types
    Get_AdminStatus (\%oid_ifAdminStatus); # Gather interface administration status
    Get_OperStatus (\%oid_ifOperStatus); # Gather interface operational status
    Get_Speed (\%oid_ifSpeed, \%oid_ifHighSpeed); # Gather interface speed
    Get_Alias (\%oid_ifAlias) if ($ghOptions{'alias'}); # Gather interface alias
    Get_Duplex (\%oid_ifDuplexStatus) if ($ghOptions{'duplex'}); # Gather interface duplex state
    Get_IpInfo (\%oid_ipAdEntIfIndex, \%oid_ipAdEntNetMask) if ($ghOptions{'ipinfo'}); # Gather interface ip addresses and masks
    if ($ghSNMPOptions{'64bits'}) {  # Gather interface traffics (in/out and packet errors/discards)
        Get_Traffic ('64', \%oid_ifHCInOctets, \%oid_ifHCOutOctets);
    } else {
        Get_Traffic ('32', \%oid_ifInOctets, \%oid_ifOutOctets);
    }
    Get_Error_Discard();
    if ($ghOptions{'pkt'}) {  # Gather interface packet traffic
        if ($ghSNMPOptions{'64bits'}) {
            Get_Packets ('64', \%oid_ifHCInUcastPkts, \%oid_ifHCOutUcastPkts, \%oid_ifHCInMulticastPkts, \%oid_ifHCOutMulticastPkts, \%oid_ifHCInBroadcastPkts, \%oid_ifHCOutBroadcastPkts);
        } else {
            Get_Packets ('32', \%oid_ifInUcastPkts, \%oid_ifOutUcastPkts, \%oid_ifInNUcastPkts, \%oid_ifOutNUcastPkts);
        }
    }
    Get_Vlan_Nortel (\%oid_nortel_rcVlanPortVlanIds) if ($ghOptions{'vlan'}); # Gather interface vlans
    Get_Stp () if ($ghOptions{'stp'}); # Gather Spanning Tree specific info

}
# +++++ Standard device +++++
else {
    Get_InterfaceNames (\%oid_ifDescr, \%oid_ifPhysAddress); # Gather interface indexes, descriptions, and mac addresses, to generate unique and reformatted interface names.
    Get_InterfaceType (\%oid_ifType) if ($ghOptions{'type'} or $ghOptions{'table-split'}); # Gather interface types
    Get_AdminStatus (\%oid_ifAdminStatus); # Gather interface administration status
    Get_OperStatus (\%oid_ifOperStatus); # Gather interface operational status
    Get_Speed (\%oid_ifSpeed, \%oid_ifHighSpeed); # Gather interface speed
    Get_Alias (\%oid_ifAlias) if ($ghOptions{'alias'}); # Gather interface alias
    Get_Duplex (\%oid_ifDuplexStatus) if ($ghOptions{'duplex'}); # Gather interface duplex state
    Get_IpInfo (\%oid_ipAdEntIfIndex, \%oid_ipAdEntNetMask) if ($ghOptions{'ipinfo'}); # Gather interface ip addresses and masks
    if ($ghSNMPOptions{'64bits'}) {  # Gather interface traffics (in/out and packet errors/discards)
        Get_Traffic ('64', \%oid_ifHCInOctets, \%oid_ifHCOutOctets);
    } else {
        Get_Traffic ('32', \%oid_ifInOctets, \%oid_ifOutOctets);
    }
    Get_Error_Discard();
    if ($ghOptions{'pkt'}) {  # Gather interface packet traffic
        if ($ghSNMPOptions{'64bits'}) {
            Get_Packets ('64', \%oid_ifHCInUcastPkts, \%oid_ifHCOutUcastPkts, \%oid_ifHCInMulticastPkts, \%oid_ifHCOutMulticastPkts, \%oid_ifHCInBroadcastPkts, \%oid_ifHCOutBroadcastPkts);
        } else {
            Get_Packets ('32', \%oid_ifInUcastPkts, \%oid_ifOutUcastPkts, \%oid_ifInNUcastPkts, \%oid_ifOutNUcastPkts);
        }
    }
    Get_Stp () if ($ghOptions{'stp'}); # Gather Spanning Tree specific info
}

logger(5, "Get interface info -> generated hash\ngrefhCurrent:".Dumper($grefhCurrent));

# ------------------------------------------------------------------------------
# Include / Exclude interfaces
# ------------------------------------------------------------------------------

# Save inclusion/exclusion information of each interface in the metadata
# 3 levels of inclusion/exclusion:
#  * global (exclude/include)
#     + globally include/exclude interfaces to be monitored
#     + excluded interfaces are represented by black overlayed rows in the
#       interface table
#     + by default, all the interfaces are included in this tracking. Excluding
#       an interface from that tracking is usually done for the interfaces that
#       we don't want any tracking (e.g. loopback interfaces)
#  * traffic tracking (exclude-traffic/include-traffic)
#     + include/exclude interfaces from traffic tracking
#     + traffic tracking consists in a check of the bandwidth usage of the interface,
#       and the error/discard packets.
#     + excluded interfaces are represented by a dark grey (css dependent)
#       cell style in the interface table
#     + by default, all the interfaces are included in this tracking. Excluding
#       an interface from that tracking is usually done for the interfaces known as
#       problematic (high traffic load) and consequently for which we don't want
#       load tracking
#  * property tracking (exclude-property/include-property)
#     + include/exclude interfaces from property tracking.
#     + property tracking consists in the check of any changes in the properties of
#       an interface, properties specified via the --track-property option.
#     + excluded interfaces are represented by a dark grey (css dependent)
#       cell style in the interface table
#     + by default, only the "operstatus" property is tracked. For the operstatus
#       property, the exclusion of an interface is usually done when the interface can
#       be down for normal reasons (ex: interfaces connected to printers sometime in
#       standby mode)

$grefhCurrent = Evaluate_Interfaces (
    $ghOptions{'exclude'},
    $ghOptions{'include'},
    $ghOptions{'exclude-traffic'},
    $ghOptions{'include-traffic'},
    $ghOptions{'exclude-property'},
    $ghOptions{'include-property'}
    );
#logger(5, "Interface inclusions / exclusions -> generated hash\ngrefhCurrent:".Dumper($grefhCurrent));

# ------------------------------------------------------------------------------
# Create interface information table data
# ------------------------------------------------------------------------------

# sort ifIndex
if ($ghOptions{'default-table-sorting'} eq "name") {
    my $grefaAllIndizesTmp;
    @$grefaAllIndizesTmp = nsort keys (%{$grefhCurrent->{MD}->{Map}->{NameToIndex}});
    foreach (@$grefaAllIndizesTmp) {
        push(@$grefaAllIndizes,$grefhCurrent->{MD}->{Map}->{NameToIndex}->{"$_"});
    }
} else {
    @$grefaAllIndizes = nsort keys (%{$grefhCurrent->{MD}->{Map}->{IndexToName}});
}
logger(5, "Interface information table data -> generated array\ngrefaAllIndizes:".Dumper($grefaAllIndizes));

# some data calculations in case of valid datasets
if (defined $gBasetime) {
    # +++++ F5 BigIp +++++
    if ($ghOptions{'nodetype'} eq "bigip") {
        Calculate_Bps();
        Calculate_Error_Drop_Bigip();
        Calculate_Packets() if ($ghOptions{'pkt'});
    }
    # +++++ All other devices +++++
    else {
        Calculate_Bps();
        Calculate_Error_Discard();
        Calculate_Packets() if ($ghOptions{'pkt'});
    }
} 

# ------------------------------------------------------------------------------
# write interface information file
# ------------------------------------------------------------------------------

# remember the counted interfaces
$grefhCurrent->{MD}->{Node}->{ports} = ${gNumberOfInterfacesWithoutTrunk};
$grefhCurrent->{MD}->{Node}->{freeports} = ${gNumberOfFreeInterfaces};
$grefhCurrent->{MD}->{Node}->{adminupfree} = ${gNumberOfFreeUpInterfaces};

# first run - the hash from the file is empty because we had no file before
# fill it up with all interface intormation and with the index tables
#
# we take a separate field where we remember the last reset
# of the entire file
if (not $grefhFile->{TableReset}) {
    $grefhFile->{TableReset} = scalar localtime time();
    $grefhFile->{If} = $grefhCurrent->{If};
    logger(1, "Initial run -> $grefhFile->{TableReset}");
}

# Fill up the MD tree (MD = MetaData) - here we store all variable
# settings
$grefhFile->{MD} = $grefhCurrent->{MD};

WriteConfigFileNew ("$gInterfaceInformationFile",$grefhFile);

# ------------------------------------------------------------------------------
# STDOUT
# ------------------------------------------------------------------------------

## If there are changes in the table write it to stdout
#if ($gChangeText) {
#    $gText = $gChangeText . "$gNumberOfInterfacesWithoutTrunk interface(s)";
#} else {
#    $gText = "$gNumberOfInterfacesWithoutTrunk interface(s)"
#}

#logger(5, "gInterfacesWithoutTrunk: " . Dumper (%{$gInterfacesWithoutTrunk}));
for my $switchport (keys %{$gInterfacesWithoutTrunk}) {
    if ($gInterfacesWithoutTrunk->{$switchport}) {
        # this port is free
        $gNumberOfFreeInterfaces++
    }
}

logger(1, "---->>> ports: $gNumberOfInterfacesWithoutTrunk, free: $gNumberOfFreeInterfaces");

# ------------------------------------------------------------------------------
# Create host information table data
# ------------------------------------------------------------------------------

my $counterInfoTableData = 0;
$grefAoHInfoTableData->[0]->[$counterInfoTableData++]->{Value} = "$grefhCurrent->{MD}->{Node}->{sysName}";
$grefAoHInfoTableData->[0]->[$counterInfoTableData++]->{Value} = TimeDiff (1,$grefhCurrent->{MD}->{Node}->{sysUpTime} / 100); # start at 1 because else we get "NoData"
$grefAoHInfoTableData->[0]->[$counterInfoTableData++]->{Value} = "$grefhCurrent->{MD}->{Node}->{sysDescr}";
if ($ghOptions{'nodetype'} eq "cisco") {
    $grefAoHInfoTableData->[0]->[$counterInfoTableData++]->{Value} = "$grefhCurrent->{MD}->{Node}->{cisco_type}";
    $grefAoHInfoTableData->[0]->[$counterInfoTableData++]->{Value} = "$grefhCurrent->{MD}->{Node}->{cisco_serial}";
} elsif ($ghOptions{'nodetype'} eq "brocade") {
    $grefAoHInfoTableData->[0]->[$counterInfoTableData++]->{Value} = "$grefhCurrent->{MD}->{Node}->{brocade_serial}";
} elsif ($ghOptions{'nodetype'} eq "nortel") {
    $grefAoHInfoTableData->[0]->[$counterInfoTableData++]->{Value} = "$grefhCurrent->{MD}->{Node}->{nortel_serial}";
}
if ($ghOptions{'nodetype'} eq "netapp") {
    $grefAoHInfoTableData->[0]->[$counterInfoTableData++]->{Value} = "$grefhCurrent->{MD}->{Node}->{netapp_model}";
} elsif ($ghOptions{'nodetype'} eq "bigip") {
    $grefAoHInfoTableData->[0]->[$counterInfoTableData++]->{Value} = "$grefhCurrent->{MD}->{Node}->{bigip_model}";
} elsif ($ghOptions{'nodetype'} eq "brocade") {
    $grefAoHInfoTableData->[0]->[$counterInfoTableData++]->{Value} = "$grefhCurrent->{MD}->{Node}->{brocade_model}";
} elsif ($ghOptions{'nodetype'} eq "nortel") {
    $grefAoHInfoTableData->[0]->[$counterInfoTableData++]->{Value} = "$grefhCurrent->{MD}->{Node}->{nortel_model}";
}
if ($ghOptions{'nodetype'} eq "brocade") {
    $grefAoHInfoTableData->[0]->[$counterInfoTableData++]->{Value} = "$grefhCurrent->{MD}->{Node}->{brocade_firmware}";
}
$grefAoHInfoTableData->[0]->[$counterInfoTableData++]->{Value} = hexToString($grefhCurrent->{MD}->{Node}->{sysLocation});
$grefAoHInfoTableData->[0]->[$counterInfoTableData++]->{Value} = "$grefhCurrent->{MD}->{Node}->{sysContact}";
if ($ghOptions{'nodetype'} eq "netscreen") {
    $grefAoHInfoTableData->[0]->[$counterInfoTableData++]->{Value} = "$grefhCurrent->{MD}->{Node}->{netscreen_nsrp}";
}
$grefAoHInfoTableData->[0]->[$counterInfoTableData]->{Value} = "ports:&nbsp;$gNumberOfInterfacesWithoutTrunk free:&nbsp;$gNumberOfFreeInterfaces";
$grefAoHInfoTableData->[0]->[$counterInfoTableData++]->{Value} .= "<br>AdminUpFree:&nbsp;$gNumberOfFreeUpInterfaces";
if ($gUsedDelta) {
    $grefAoHInfoTableData->[0]->[$counterInfoTableData]->{Value} = "configured: $ghOptions{'delta'}s (+".sprintf("%0.2fs",$ghOptions{'delta'}/3).")<br>used: ${gUsedDelta}s";
} else {
    $grefAoHInfoTableData->[0]->[$counterInfoTableData++]->{Value} = "configured: $ghOptions{'delta'} (+".sprintf("%0.2fs",$ghOptions{'delta'}/3).")<br>used: no data to compare with";
}

# ------------------------------------------------------------------------------
# Update config information table data
# ------------------------------------------------------------------------------

$grefAoHConfigTableData->[3]->[1]->{Value} = "warning at $ghOptions{'warning-load'}%, critical at $ghOptions{'critical-load'}%";
if ($ghOptions{'nodetype'} eq 'bigip') {
    $grefAoHConfigTableData->[4]->[1]->{Value} = "errors: warning at $ghOptions{'warning-pkterr'} pkts/s, critical at $ghOptions{'critical-pkterr'} pkts/s; drop: warning at $ghOptions{'warning-pktdrop'} pkts/s, critical at $ghOptions{'critical-pktdrop'} pkts/s";
} else {
    $grefAoHConfigTableData->[4]->[1]->{Value} = "errors: warning at $ghOptions{'warning-pkterr'} pkts/s, critical at $ghOptions{'critical-pkterr'} pkts/s; discards: warning at $ghOptions{'warning-pktdiscard'} pkts/s, critical at $ghOptions{'critical-pktdiscard'} pkts/s";
}
$grefAoHConfigTableData->[5]->[1]->{Value} = join(", ",@{$ghOptions{'track-property'}});
$grefAoHConfigTableData->[6]->[1]->{Value} = ( $ghOptions{'warning-property'} > 0 )
 ? "warning for $ghOptions{'warning-property'} change(s), " : "no warning threshold, ";
$grefAoHConfigTableData->[6]->[1]->{Value} .= ( $ghOptions{'critical-property'} > 0 )
 ? "critical for $ghOptions{'critical-property'} change(s)" : "no critical threshold";

# Loop through all interfaces
for my $ifName (keys %{$grefhCurrent->{MD}->{If}}) {
    # Denormalize interface name
    my $ifNameReadable = denormalize ($ifName);
    # Update the config table
    if ($grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedTrack} eq "true") {
        $grefAoHConfigTableData->[0]->[1]->{Value} ne "" and $grefAoHConfigTableData->[0]->[1]->{Value} .= ", ";
        $grefAoHConfigTableData->[0]->[1]->{Value} .= "$ifNameReadable";
    } else {
        $grefhCurrent->{MD}->{If}->{$ifName}->{MsgInfo} and $gConfigTableOtherMsgInfo .= $grefhCurrent->{MD}->{If}->{$ifName}->{MsgInfo};
        $grefhCurrent->{MD}->{If}->{$ifName}->{MsgWarn} and $gConfigTableOtherMsgWarn .= $grefhCurrent->{MD}->{If}->{$ifName}->{MsgWarn};
        $grefhCurrent->{MD}->{If}->{$ifName}->{MsgCrit} and $gConfigTableOtherMsgCrit .= $grefhCurrent->{MD}->{If}->{$ifName}->{MsgCrit};
        if ($grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedLoadTrack} eq "true") {
            $grefAoHConfigTableData->[1]->[1]->{Value} ne "" and $grefAoHConfigTableData->[1]->[1]->{Value} .= ", ";
            $grefAoHConfigTableData->[1]->[1]->{Value} .= "$ifNameReadable";
        }
        if ($grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedPropertyTrack} eq "true") {
            $grefAoHConfigTableData->[2]->[1]->{Value} ne "" and $grefAoHConfigTableData->[2]->[1]->{Value} .= ", ";
            $grefAoHConfigTableData->[2]->[1]->{Value} .= "$ifNameReadable";
        }
    }
}
$grefAoHConfigTableData->[0]->[1]->{Value} eq "" and $grefAoHConfigTableData->[0]->[1]->{Value} = "none";
$grefAoHConfigTableData->[1]->[1]->{Value} eq "" and $grefAoHConfigTableData->[1]->[1]->{Value} = "none";
$grefAoHConfigTableData->[2]->[1]->{Value} eq "" and $grefAoHConfigTableData->[2]->[1]->{Value} = "none";
$grefAoHConfigTableData->[8]->[1]->{Value} .= $gConfigTableOtherMsgInfo . $gConfigTableOtherMsgWarn . $gConfigTableOtherMsgCrit;

#
# Generate Html Table
# do not compare ifName and ifIndex because they can change during reboot
# Field list: index,ifName,ifAlias,ifAdminStatus,ifOperStatus,ifSpeedReadable,ifDuplexStatus,ifVlanNames,ifLoadIn,ifLoadOut,ifIpInfo,bpsIn,bpsOut,ifLastTraffic
#

if ($ghOptions{'table-split'}) {

    logger(2, "Interface table data generation: a table per interface type");
    my $InterfaceTypes;
    for my $InterfaceIndex (@$grefaAllIndizes) {
        
        # Get normalized interface name (key for If data structure)
        my $Name = $grefhCurrent->{MD}->{Map}->{IndexToName}->{$InterfaceIndex};
        # Skip the interface if config table enabled and interface excluded
        if ($ghOptions{configtable} and $grefhCurrent->{MD}->{If}->{$Name}->{ExcludedTrack} eq "true") {
            next;
        } else {
            if ($grefhCurrent->{If}->{"$Name"}->{ifType}) {
                my $TypeDescription = $ifTypeDescriptions{$grefhCurrent->{If}->{"$Name"}->{ifTypeNumber}};
                push @{$InterfaceTypes->{"$TypeDescription"}}, $InterfaceIndex;
            }
        }
    }
    
    while ( my ($Type, $Indexes) = each(%{$InterfaceTypes}) ) {
        logger(3, "   * type: \"$Type\", interface indexes: ". join(", ", @{$Indexes}));
        $grefAoHInterfaceTableData->{"$Type"} = GenerateInterfaceTableData ($Indexes, $grefAoHInterfaceTableHeader, $ghOptions{'track-property'});
    }

} else {
    logger(2, "Interface table data generation: a unique table for all interfaces");
    $grefAoHInterfaceTableData->{"Interface information"} = GenerateInterfaceTableData ($grefaAllIndizes, $grefAoHInterfaceTableHeader, $ghOptions{'track-property'});
}

# ------------------------------------------------------------------------------
# Feed the output with warning and error messages, and calculate exit code
# ------------------------------------------------------------------------------

# If current run is the first run we dont compare data
if ( $gInitialRun ) {
    logger(1, "Initial run -> Setting DifferenceCounter to zero.");
    $gDifferenceCounter = 0;
    $gText = "Initial run...";
} elsif ( $gNoHistory ){
    logger(1, "No history -> Setting DifferenceCounter to zero.");
    $gDifferenceCounter = 0;
    $gText = "No valid historical dataset...";
} else {
    # Interface properties
    # $gDifferenceCounter contains the number of changes which were made in the interface configurations
    if ($gDifferenceCounter > 0) {
        logger(1, "Differences: $gDifferenceCounter");
        $gExitCode = $ERRORS{"WARNING"} if ($ghOptions{'warning-property'} and $gDifferenceCounter >= $ghOptions{'warning-property'});
        $gExitCode = $ERRORS{"CRITICAL"} if ($ghOptions{'critical-property'} and $gDifferenceCounter >= $ghOptions{'critical-property'});
        if ($ghOptions{'outputshort'}) {
            $gText .= ", $gDifferenceCounter change(s)";
        } else {
            $gText .= ", $gDifferenceCounter change(s):";
            for my $field ( keys %{$grefhListOfChanges} ) {
                if (not $field =~ /^load|^warning-pkterr$|^critical-pkterr$|^warning-pktdiscard$|^critical-pktdiscard$|^warning-pktdrop$|^critical-pktdrop$/i) {
                    $gText .= " $field - @{$grefhListOfChanges->{$field}}";
                }
            }
        }
    }
    # Load
    if ($gIfLoadWarnCounter > 0 ) {
        $gExitCode = $ERRORS{'WARNING'} if ($gExitCode ne $ERRORS{'CRITICAL'});
        if ($ghOptions{'outputshort'}) {
            $gText .= ", load warning (>$ghOptions{'warning-load'}%): $gIfLoadWarnCounter";
        } else {
            $gText .= ", $gIfLoadWarnCounter warning load(s) (>$ghOptions{'warning-load'}%): @{$grefhListOfChanges->{loadwarning}}";
        }
    }
    if ($gIfLoadCritCounter > 0 ) {
        $gExitCode = $ERRORS{'CRITICAL'};
        if ($ghOptions{'outputshort'}) {
            $gText .= ", load critical (>$ghOptions{'critical-load'}%): $gIfLoadCritCounter";
        } else {
            $gText .= ", $gIfLoadCritCounter critical load(s) (>$ghOptions{'critical-load'}%): @{$grefhListOfChanges->{loadcritical}}";
        }
    }
    # Packet errors
    if ($gPktErrWarnCounter > 0 ) {
        $gExitCode = $ERRORS{'WARNING'} if ($gExitCode ne $ERRORS{'CRITICAL'});
        if ($ghOptions{'outputshort'}) {
            $gText .= ", error pkts/s warning (>$ghOptions{'warning-pkterr'}): $gPktErrWarnCounter";
        } else {
            $gText .= ", $gPktErrWarnCounter warning error pkts/s (>$ghOptions{'warning-pkterr'}): @{$grefhListOfChanges->{'warning-pkterr'}}";
        }
    }
    if ($gPktErrCritCounter > 0 ) {
        $gExitCode = $ERRORS{'CRITICAL'};
        if ($ghOptions{'outputshort'}) {
            $gText .= ", error pkts/s critical (>$ghOptions{'critical-pkterr'}): $gPktErrCritCounter";
        } else {
            $gText .= ", $gPktErrCritCounter critical error pkts/s (>$ghOptions{'critical-pkterr'}): @{$grefhListOfChanges->{'critical-pkterr'}}";
        }
    }
    # Packet discards
    if ($gPktDiscardWarnCounter > 0 ) {
        $gExitCode = $ERRORS{'WARNING'} if ($gExitCode ne $ERRORS{'CRITICAL'});
        if ($ghOptions{'outputshort'}) {
            $gText .= ", discard pkts/s warning (>$ghOptions{'warning-pktdiscard'}): $gPktDiscardWarnCounter";
        } else {
            $gText .= ", $gPktDiscardWarnCounter discard pkts/s (>$ghOptions{'warning-pktdiscard'}): @{$grefhListOfChanges->{'warning-pktdiscard'}}";
        }
    }
    if ($gPktDiscardCritCounter > 0 ) {
        $gExitCode = $ERRORS{'CRITICAL'};
        if ($ghOptions{'outputshort'}) {
            $gText .= ", discard pkts/s critical (>$ghOptions{'critical-pktdiscard'}): $gPktDiscardCritCounter";
        } else {
            $gText .= ", $gPktDiscardCritCounter discard pkts/s (>$ghOptions{'critical-pktdiscard'}): @{$grefhListOfChanges->{'critical-pktdiscard'}}";
        }
    }
    # Packet dropped (bigip)
    if ($gPktDropWarnCounter > 0 ) {
        $gExitCode = $ERRORS{'WARNING'} if ($gExitCode ne $ERRORS{'CRITICAL'});
        if ($ghOptions{'outputshort'}) {
            $gText .= ", drop pkts/s warning (>$ghOptions{'warning-pktdrop'}): $gPktDropWarnCounter";
        } else {
            $gText .= ", $gPktDropWarnCounter drop pkts/s (>$ghOptions{'warning-pktdrop'}): @{$grefhListOfChanges->{'warning-pktdrop'}}";
        }
    }
    if ($gPktDropCritCounter > 0 ) {
        $gExitCode = $ERRORS{'CRITICAL'};
        if ($ghOptions{'outputshort'}) {
            $gText .= ", drop pkts/s critical (>$ghOptions{'critical-pktdrop'}): $gPktDropCritCounter";
        } else {
            $gText .= ", $gPktDropCritCounter drop pkts/s (>$ghOptions{'critical-pktdrop'}): @{$grefhListOfChanges->{'critical-pktdrop'}}";
        }
    }
    if ($gExitCode == $ERRORS{'OK'}) {
        # Build an ok message
        $gText = "$gNumberOfInterfacesWithoutTrunk port(s)";
        $gText .= ", $gNumberOfFreeInterfaces free" if ($gNumberOfFreeInterfaces >= 0);
        $gText .= ", $gNumberOfFreeUpInterfaces AdminUp and free" if ($gNumberOfFreeUpInterfaces >= 0);
        $gText .= ", $gNumberOfPerfdataInterfaces graphed" if ($gNumberOfPerfdataInterfaces >= 0 and $ghOptions{'enableperfdata'});
    }
}

# ------------------------------------------------------------------------------
# Add extra info to the output message
# ------------------------------------------------------------------------------

# Cisco node info
if ($ghOptions{'nodetype'} eq "cisco" and $grefhCurrent->{MD}->{cisco_type} and $grefhCurrent->{MD}->{cisco_serial}) {
    $gText = "$grefhCurrent->{MD}->{cisco_type} ($grefhCurrent->{MD}->{cisco_serial}): ". $gText;
}

# Calculate end time
my $ENDTIME_HR = Time::HiRes::time();
my $RUNTIME_HR = sprintf("%0.2f", ($ENDTIME_HR-$STARTTIME_HR));

# Generate perfdata
if ( $gNumberOfPerfdataInterfaces > 0 and not $gInitialRun and not $gNoHistory and $ghOptions{'enableperfdata'}) {
    Perfdataout();
}

# Output size check
$gText =~ s/^, //; # remove starting comma if any
$gOutputSize += length($gText);
$gOutputSize += length($gPerfdata) + 3 if ($gPerfdata);
if ($gOutputSize > $MAX_PLUGIN_OUTPUT_LENGTH) {
    $grefAoHConfigTableData->[8]->[1]->{Value} .= "<div class=\"critical\">Plugin output length up to the maximum allowed by nagios/icinga core ".
        "($gOutputSize > $MAX_PLUGIN_OUTPUT_LENGTH). Generated performance could have been truncated. One solution is to bypass the nagios/icinga ".
        "core to keep all the performance data (--perfdatadir option). See the documentation for some alternative solutions.</div>";
}
logger(1, "OutputSize=$gOutputSize (output:".length($gText).", perfdata:".length($gPerfdata).") MAX_PLUGIN_OUTPUT_LENGTH=$MAX_PLUGIN_OUTPUT_LENGTH");

# ------------------------------------------------------------------------------
# Create HTML tables
# ------------------------------------------------------------------------------

# Create "small" information table
$gInfoTableHTML = Convert2HtmlTable (1,$grefAoHInfoTableHeader,$grefAoHInfoTableData,"infotable","");

# Create "big" interface table(s)
for my $Type (keys %{$grefAoHInterfaceTableData}) {
    $gInterfaceTableHTML->{"$Type"} = Convert2HtmlTable (1,$grefAoHInterfaceTableHeader,$grefAoHInterfaceTableData->{"$Type"},"interfacetable","#81BEF7");
}

# Create configuration table
logger(5, "Config table:".Dumper($grefAoHConfigTableData));
$gConfigTableHTML = Convert2HtmlTable (2,$grefAoHConfigTableHeader,$grefAoHConfigTableData,"configtable","");

# ------------------------------------------------------------------------------
# Write the Html table and exit this program
# ------------------------------------------------------------------------------

# Write Html Table
WriteHtmlFile ({
    InfoTable       => $gInfoTableHTML,
    InterfaceTable  => $gInterfaceTableHTML,
    ConfigTable     => $gConfigTableHTML,
    Dir             => $ghOptions{'htmltabledir'},
    FileName        => "$ghOptions{'htmltabledir'}/$gFile".'.html'
});

# Print Text and exit with the correct exitcode
ExitPlugin ($gExitCode, $gText);

# This code should never be reached
exit $ERRORS{"UNKNOWN"};

# OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO
# OOOOOOOOOOOOOOOOOOOOOOOOOOO                OOOOOOOOOOOOOOOOOOOOOOOOOOOOO
# OOOOOOOOOOOOOOOOOOOOOOOOOOO    END MAIN    OOOOOOOOOOOOOOOOOOOOOOOOOOOOO
# OOOOOOOOOOOOOOOOOOOOOOOOOOO                OOOOOOOOOOOOOOOOOOOOOOOOOOOOO
# OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO




# oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
#      FUNCTIONS
# oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
# List:
# --- Generic node functions ---
# * Get_InterfaceNames
# * Get_InterfaceType
# * Get_AdminStatus
# * Get_OperStatus
# * Get_Speed
# * Get_Alias
# * Get_Duplex
# * Get_Stp
# * Get_IpInfo
# * Get_Traffic
# * Get_Error_Discard
# * Get_Packets
# * Process_IfCounter
# * Evaluate_Interfaces
# * Calculate_Bps
# * Calculate_Error_Discard
# * Calculate_LastTraffic
# --- Nodetype specific functions ---
# * Get_Vlan_Cisco
# * Get_Vlan_Hp
# * Get_InterfaceNames_Bigip
# * Get_InterfaceEnabled_Bigip
# * Get_InterfaceStatus_Bigip
# * Get_Operstatus_Netscreen
# * Get_IpInfo_Netscreen
# * Get_Specific_Netscreen
# * Get_Alias_Brocade
# --- General functions ---
# * ReadInterfaceInformationFile
# * ReadConfigFileNew
# * WriteConfigFileNew
# * CleanAndSelectHistoricalDataset
# * GenerateInterfaceTableData
# * Convert2HtmlTable
# * WriteHtmlFile
# * Perfdataout
# * TimeDiff
# * Colorcode
# * ExitPlugin
# * add_oid_details
# --- Plugin common functions ---
# * print_usage
# * print_defaults
# * print_help
# * print_revision
# * print_support
# * check_options
# ------------------------------------------------------------------------------


# oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
# GENERIC NODE FUNCTIONS
# oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

# ------------------------------------------------------------------------------
# Get_InterfaceNames
# ------------------------------------------------------------------------------
# Description:
# This function gather interface indexes, descriptions, and mac addresses, to
# generate unique and reformatted interface names. Interface names are the identifiant
# to retrieve any interface related information.
# This function also push to the grefhCurrent hash:
# - Some if info:
#  * name
#  * index
#  * mac address
# - Some map relations:
#  * name to index
#  * index to name
#  * name to description
# ------------------------------------------------------------------------------
# Function call:
#  Get_InterfaceNames();
# Arguments:
#  None
# Output:
#  None
# ------------------------------------------------------------------------------
sub Get_InterfaceNames {

    my $refhOIDIfDescr = shift;
    my $refhOIDIfPhysAddress = shift;
    my $refhSNMPResultIfDescr;
    my $refhSNMPResultIfPhysAddress;
    my $refhIfDescriptionCounts = {};   # For duplicates counting
    my $refhIfPhysAddressCounts = {};   # For duplicates counting
    my $refhIfPhysAddressIndex  = {};   # To map the physical address to the index.
                                        # Used only when appending the mac address to the interface description
    my $Name = "";                      # Name of the interface. Formatted to be unique, based on interface description
                                        # and index / mac address

    # Get info from snmp
    #------------------------------------------

    # get all interface descriptions
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDIfDescr->{'oid'}"], cachetimer => 0, outputhashkeyidx => 0, checkempty => 1));
        $refhSNMPResultIfDescr = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDIfDescr ])) if ($@);

    # get all interface mac addresses
    eval {
        my %hOptions = ($ghOptions{'usemacaddr'}) ? ( %ghSNMPOptions, (oids => ["$refhOIDIfPhysAddress->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1))
            : ( %ghSNMPOptions, (oids => ["$refhOIDIfPhysAddress->{'oid'}"], cachetimer => $gLongCacheTimer, outputhashkeyidx => 1, checkempty => 0));
        $refhSNMPResultIfPhysAddress = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDIfPhysAddress ])) if ($@);

    # Look for duplicate values
    #------------------------------------------

    # Find interface description duplicates
    for my $value ( values %$refhSNMPResultIfDescr ) {
        $refhIfDescriptionCounts->{"$value"} = 0 unless(defined $refhIfDescriptionCounts->{"$value"});
        $refhIfDescriptionCounts->{"$value"}++;
    }

    # Find physical address duplicates
    for my $value ( values %$refhSNMPResultIfPhysAddress ) {
        $refhIfPhysAddressCounts->{"$value"} = 0 unless(defined $refhIfPhysAddressCounts->{"$value"});
        $refhIfPhysAddressCounts->{"$value"}++;
    }

    #
    #------------------------------------------

    # Example of $refhSNMPResultIfDescr
    #    TOADD
    while ( my ($Index,$Desc) = each(%$refhSNMPResultIfDescr) ) {
        $Index =~ s/^\.*$oid_ifDescr{'oid'}\.//g; # remove all but the index
        logger(2, "Index=$Index Descr=\"$Desc\" (long cache: $gLongCacheTimer)");
        my $MacAddr = (defined $refhSNMPResultIfPhysAddress->{$Index}) ? "$refhSNMPResultIfPhysAddress->{$Index}" : "";

        # Interface name formatting
        # -----------------------------------------------------------

        my $Name = "$Desc";
        # 1. check an empty interface description
        # this occurs on some devices (e.g. HP procurve switches)
        if ("$Desc" eq "") {
            # Set the name as "Port $index"
            # read the MAC address of the interface - independend if it has one or not
            $Name = "Port $Index";
            logger(2, "  Interface with index $Index has no description.\nName is set to $Name");
        } else {
            
            # 2. Convert HEX names to ASCII (mod by Enfileyb)
            if ($Name =~ /^0x([a-fA-F0-9]{2})*00$/) {
                chomp($Name);
                # Remove 0x at start and Zero-Byte at end
                $Name =~ s/^0x(.*)00$/$1/;
                # Convert HEX to Char
                $Name = pack("H*",$Name);
                # Because Windows SNMP-service uses different codepages (Win2k3 uses CP125x, Win2k8 uses CP85x) encode 
                # to ascii (there should be no chars, that disturb PNP4Nagios)
                $Name = encode('ascii', $Name);
                # Any Non-Ascii-Chars have been replaced by '?', now replace them with '_' (could be another char).
                $Name =~ s/\?/_/g;
                logger(2, "  Interface with index $Index has HEX-description. Name converted to \"$Name\"");
            }
         
            # 3. append the index to duplicate interface descriptions. Index is better than mac address as in lots of cases the
            # same mac address can be used for multiples interfaces (if there is a mac address...)
            # Example of nodes in that case: Dell Powerconnect Switches 53xx, 54xx, 60xx and 62xx: same interface name 'Ethernet Interface'
            # However, be sure to fix the interface index (see the node type documentation). If not fixed, this could lead to problems
            # where index is changed during reboot and duplicate interface names
            if ($refhIfDescriptionCounts->{"$Name"} > 1) {
                if ($ghOptions{usemacaddr}) {
                    logger(2, "  Duplicate interface description detected. Option \"usemacaddr\" used, checking mac address unicity...");
                    # check if we got a unique MAC Address associated to the interface
                    if ($refhIfPhysAddressCounts->{"$MacAddr"} < 2) {
                        $Name = "$Name ($MacAddr)";
                        logger(2, "  Mac address is unique. Appending the mac address. Name will be now \"$Name\"");
                    } else {
                        # overwise take the index
                        $Name = "$Desc ($Index)";
                        logger(2, "  Mac address is NOT unique. Appending the index. Name will be now \"$Name\"");
                    }
                } else {
                    $Name = "$Desc ($Index)";
                    logger(2, "  Duplicate interface description detected. Appending the index. Name will be now \"$Name\"");
                }
            }

            # 4. Known long of problematic interface names
            if ($Name =~ /^Adaptive Security Appliance '(.*)' interface$/) {
                #Cisco ASA 55xx series
                $Name="$1";
                logger(2, "  Interface name matching Cisco ASA interface pattern, name reduced to \"$Name\"");
            }
            elsif ($Name =~ /^(.*)[,;] Product.*$/) {
                #old AIX interfaces
                $Name="$1";
                logger(2, "  Interface name matching old AIX interface pattern, name reduced to \"$Name\"");
            }
            elsif ($Name =~ /^(.*) Ethernet Layer Intel .* Ethernet$/) {
                #Nokia firewall (Checkpoint IPSO Firewall)
                #Possibilities seem to be:
                # Ethernet Layer Intel 10/100 Ethernet
                # Ethernet Layer Intel Gigabit Ethernet
                $Name="$1";
                logger(2, "  Interface name matching long interface descriptions on a Nokia firewall, name reduced to \"$Name\"");
            }
            elsif ($Name =~ /^Firewall Services Module '(.*)' interface$/) {
                #Firewall Services Module in Cisco Catalyst 6500 Series Switch or Cisco 7600 Internet Router
                $Name="FWSM $1";
                logger(2, "  Interface name matching a Cisco Firewall Services Module interface pattern, name reduced to \"$Name\"");
            }
            elsif ($ghOptions{'nodetype'} eq "brocade-nos") {
                if ($Name =~ /^TenGigabitEthernet (.*)$/) {
                    #Brocade VDX - TenGigabitEthernet interface
                    $Name="TenGigabitEthernet$1";
                    logger(2, "  Interface name matching a Brocade VDX TenGig Interface, renamed to \"$Name\"");
                }
                elsif ($Name =~ /^GigabitEthernet (.*)$/) {
                    #Brocade VDX - GigabitEthernet interface
                    $Name="GigabitEthernet$1";
                    logger(2, "  Interface name matching a Brocade VDX Gig Interface, renamed to \"$Name\"");
                }
                elsif ($Name =~ /^\d(.*)$/) {
                    #Brocade VDX - FCoE interface
                    $Name="FCoE$1";
                    logger(2, "  Interface name matching a Brocade VDX TenGig Interface, renamed to \"$Name\"");
                }
            }
            
            # Detect long name, which may be reduced for a cleaner interface table
            my $name_warning_length = 40;
            if (length($Name) > $name_warning_length) {
                logger(2, "  Interface name quite long! (> $name_warning_length char.). Name: \"$Name\"");
                $grefhCurrent->{MD}->{If}->{$Name}->{MsgInfo} .= "<div class=\"information\">Interface name quite long! (\> $name_warning_length char.). Name: \"$Name\"</div>";
            }
            
            # 5. Known problematic interface
            if ($Name =~ /^FCIP GIGE port .*$/) {
                logger(1, "  Interface \"$Name\" is not supported, due to some inconsistent traffic counters. You may want to exclude them using --exclude '^FCIP GIGE port'");
                $grefhCurrent->{MD}->{If}->{$Name}->{MsgWarn} .= "<div class=\"warning\">Interface \"$Name\" is not supported, due to some inconsistent traffic counters. You may want to exclude them globally using --exclude '^FCIP GIGE port', or only from traffic tracking using --et '^FCIP GIGE port'.</div>";
            }
        }

        logger(2, "  ifName=\"$Name\" (normalized: \"".normalize ($Name)."\")");

        # normalize the interface name and description to not get into trouble
        # with special characters and how Config::General handles blanks
        $Name = normalize ($Name);
        $Desc = normalize ($Desc);

        # create new trees in the MetaData hash & the Interface hash, which
        # store interface index, description and mac address.
        # This is used later for displaying the html table
        $grefhCurrent->{MD}->{Map}->{NameToIndex}->{"$Name"} = "$Index";
        $grefhCurrent->{MD}->{Map}->{NameToDescr}->{"$Name"} = "$Desc";
        $grefhCurrent->{MD}->{Map}->{DescrToName}->{"$Desc"} = "$Name";
        $grefhCurrent->{MD}->{Map}->{IndexToName}->{"$Index"} = "$Name";
        $grefhCurrent->{If}->{$Name}->{index} = "$Index";
        $grefhCurrent->{If}->{$Name}->{ifName} = "$Name";
        $grefhCurrent->{If}->{$Name}->{ifDescr} = "$Desc";
        $grefhCurrent->{If}->{$Name}->{ifMacAddr} = "$MacAddr";

    }
    return 0;
}

# ------------------------------------------------------------------------
# get ifType
# ------------------------------------------------------------------------
sub Get_InterfaceType {

    my $refhOID = shift;
    my $refhSNMPResult;       # Lines returned from snmpwalk storing ifType

    # get all interface types - caching
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOID->{'oid'}"], cachetimer => $gLongCacheTimer, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResult = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOID ])) if ($@);

    # loop through all found interfaces
    for my $ifName (keys %{$grefhCurrent->{If}}) {
        # Extract the index out of the MetaData
        my $Index = $grefhCurrent->{MD}->{Map}->{NameToIndex}->{"$ifName"};
        if (defined $refhSNMPResult->{$Index}) {
            my $Type = $refhSNMPResult->{$Index};
            $grefhCurrent->{If}->{"$ifName"}->{ifTypeNumber} = "$Type";
            $grefhCurrent->{If}->{"$ifName"}->{ifType} = (defined $refhOID->{'convertToReadable'}->{"$Type"})
                ? $refhOID->{'convertToReadable'}->{"$Type"} : $Type;
            logger(2, "Index=$Index ($ifName): Type=".$grefhCurrent->{If}->{"$ifName"}->{ifType});
        } else {
            #$grefhCurrent->{If}->{"$ifName"}->{ifTypeNumber} = undef;
            #$grefhCurrent->{If}->{"$ifName"}->{ifType} = undef;
            logger(2, "Index=$Index ($ifName): Type not found for the interface");
        }
    }
    return 0;
}

# ------------------------------------------------------------------------
# get ifAdminStatus
# ------------------------------------------------------------------------
sub Get_AdminStatus {

    my $refhOID = shift;
    my $refhSNMPResult;       # Lines returned from snmpwalk storing ifAdminStatus

    # get all interface adminstatus - no caching !
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOID->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResult = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOID ])) if ($@);

    # loop through all found interfaces
    for my $ifName (keys %{$grefhCurrent->{If}}) {
        # Extract the index out of the MetaData
        my $Index = $grefhCurrent->{MD}->{Map}->{NameToIndex}->{"$ifName"};
        if (defined $refhSNMPResult->{$Index}) {
            my $AdminStatus = $refhSNMPResult->{$Index};
            # Store ifAdminStatus converted from a digit to "up" or "down"
            $grefhCurrent->{If}->{"$ifName"}->{ifAdminStatusNumber} = "$AdminStatus";
            $grefhCurrent->{If}->{"$ifName"}->{ifAdminStatus} = (defined $refhOID->{'convertToReadable'}->{"$AdminStatus"})
                ? $refhOID->{'convertToReadable'}->{"$AdminStatus"} : $AdminStatus;
            logger(2, "Index=$Index ($ifName): AdminStatus=".$grefhCurrent->{If}->{"$ifName"}->{ifAdminStatus});
        } else {
            #$grefhCurrent->{If}->{"$ifName"}->{ifAdminStatusNumber} = undef;
            #$grefhCurrent->{If}->{"$ifName"}->{ifAdminStatus} = undef;
            logger(2, "Index=$Index ($ifName): AdminStatus not found for the interface");
        }
    }
    return 0;
}

# ------------------------------------------------------------------------
# get ifOperStatus
# ------------------------------------------------------------------------
sub Get_OperStatus {

    my $refhOID = shift;
    my $refhSNMPResult;       # Lines returned from snmpwalk storing ifOperStatus

    # get all interface adminstatus - no caching !
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOID->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResult = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOID ])) if ($@);

    # Example of $refaOperStatusLines
    #    .1.3.6.1.2.1.2.2.1.8.1 up
    #    .1.3.6.1.2.1.2.2.1.8.2 down
    for my $ifName (keys %{$grefhCurrent->{If}}) {
        # Extract the index out of the MetaData
        my $Index = $grefhCurrent->{MD}->{Map}->{NameToIndex}->{"$ifName"};

        if (defined $refhSNMPResult->{$Index}) {
            my $OperStatusNow = $refhSNMPResult->{$Index};
            # Store the oper status as property of the current interface
            $grefhCurrent->{If}->{"$ifName"}->{ifOperStatusNumber} = "$OperStatusNow";
            defined $refhOID->{'convertToReadable'}->{"$OperStatusNow"} and $OperStatusNow = $refhOID->{'convertToReadable'}->{"$OperStatusNow"};
            $grefhCurrent->{If}->{"$ifName"}->{ifOperStatus} = "$OperStatusNow";

            # Retrieve adminstatus for special rules
            my $AdminStatusNow = $grefhCurrent->{If}->{"$ifName"}->{ifAdminStatus};

            #
            # Store a CacheTimer (seconds) where we cache the next
            # reads from the net - we have the following possibilities
            #
            # ifOperStatus:
            #
            # Current state | first state  |  CacheTimer
            # -----------------------------------------
            # up              up              $gShortCacheTimer
            # up              down            0
            # down            down            $gLongCacheTimer
            # down            up              0
            # other           *               0
            # *               other           0
            #
            # One exception to that logic is the "Changed" flag. If this
            # is set we detected a change on an interface property and do not
            # cache !
            #
            my $OperStatusFile = $grefhFile->{If}->{"$ifName"}->{ifOperStatus};
            $OperStatusFile = "" unless ($OperStatusFile);
            # set cache timer for further reads
            if ("$OperStatusNow" eq "up" and "$OperStatusFile" eq "up") {
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{CacheTimer} = $gShortCacheTimer;
            } elsif ("$OperStatusNow" eq "down" and "$OperStatusFile" eq "down") {
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{CacheTimer} = $gLongCacheTimer;
            } else {
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{CacheTimer} = 0;
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText} =
                    "Old = \"$OperStatusFile\", Current = \"$OperStatusNow\" ";
            }
            logger(2, "Index=$Index ($ifName): Operstatus was \"$OperStatusFile\" and is now \"$OperStatusNow\" (cachetimer=".$grefhCurrent->{MD}->{If}->{"$ifName"}->{CacheTimer}.")");

            # remember change time of the interface property
            if ($grefhFile->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeTime}) {
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeTime} =
                    $grefhFile->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeTime}
            } else {
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeTime} = time;
            }

            #
            # Some rules with ifOperStatus
            #
            # Between initial ifOperStatus and current ifOperStatus
            # current ifOperStatus | initial ifOperStatus | action
            # ---------------------------------------------------------------------
            # up                   | *                    | no alarm and update ifOperStatus initial state
            # *                    | empty,down           | no alarm and update ifOperStatus initial state
            #
            # Between current ifOperStatus and current ifAdminStatus
            # current ifOperStatus | current ifAdminStatus | action
            # ---------------------------------------------------------------------
            # down                 | *                     | no alarm and update ifOperStatus initial state
            #

            # track changes of the oper status
            if ("$OperStatusNow" eq "$OperStatusFile") {   # no changes to its first state
                # delete the changed flag and reset the time when it was changed
                if ($grefhFile->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText}) {
                    delete $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText};
                    $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeTime} = time;
                }
            }
            # ifOperstatus has changed to up, no alert
            elsif ("$OperStatusNow" eq "up") {
                # update the state in the status file
                $grefhFile->{If}->{"$ifName"}->{ifOperStatus} = "$OperStatusNow";
                # delete the changed flag and reset the time when it was changed
                if ($grefhFile->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText}) {
                    delete $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText};
                    $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeTime} = time;
                }
                logger(3, "  Operstatus specific rules: ifOperstatus has changed to up, no alert");
            }
            # ifOperstatus has changed from 'empty' or 'down', no alert
            elsif ("$OperStatusFile" eq "" or "$OperStatusFile" eq "down") {
                # update the state in the status file
                $grefhFile->{If}->{"$ifName"}->{ifOperStatus} = "$OperStatusNow";
                # delete the changed flag and reset the time when it was changed
                if ($grefhFile->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText}) {
                    delete $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText};
                    $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeTime} = time;
                }
                logger(3, "  Operstatus specific rules: ifOperstatus has changed from 'empty' or 'down', no alert");
            }
            # ifOperstatus has changed to 'down' and ifAdminstatus is 'down', no alert
            elsif ("$OperStatusNow" eq "down" and "$AdminStatusNow" eq "down") {
                # update the state in the status file
                $grefhFile->{If}->{"$ifName"}->{ifOperStatus} = "$OperStatusNow";
                # delete the changed flag and reset the time when it was changed
                if ($grefhFile->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText}) {
                    delete $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText};
                    $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeTime} = time;
                }
                logger(3, "  Operstatus specific rules: ifOperstatus has changed to 'down' and ifAdminstatus is 'down', no alert");
            }
            # ifOperstatus has changed, alerting
            else {
                # flag if changes already tracked
                if (not $grefhFile->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText}) {
                    $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeTime} = time;
                }

                # remember the change every run of this program, this is useful if the
                # ifOperStatus changes from "up" to "testing" to "down"
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText} =
                    "Old = \"$OperStatusFile\", Current = \"$OperStatusNow\" ";
            }
        } else {
            #$grefhCurrent->{If}->{"$ifName"}->{ifOperStatusNumber} = undef;
            #$grefhCurrent->{If}->{"$ifName"}->{ifOperStatus} = undef;
            logger(2, "Index=$Index ($ifName): OperStatus not found for the interface");
        }

    }
    return 0;
}

# ------------------------------------------------------------------------
# walk through each interface and read ifSpeed
# ------------------------------------------------------------------------
sub Get_Speed {

    my $refhSNMPResultIfSpeed;       # Lines returned from snmpwalk storing ifSpeed
    my $refhSNMPResultIfHighSpeed;   # Lines returned from snmpwalk storing ifHighSpeed

    my $refhOIDIfSpeed = shift;
    my $refhOIDIfHighSpeed = shift;

    # get ifSpeed table (units of bits per second)
    if (defined $refhOIDIfSpeed) {
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDIfSpeed->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 0));
            $refhSNMPResultIfSpeed = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDIfSpeed ])) if ($@);
    }

    # get ifHighSpeed table (units of 1,000,000 bits per second)
    if (defined $refhOIDIfHighSpeed) {
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDIfHighSpeed->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 0));
            $refhSNMPResultIfHighSpeed = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDIfHighSpeed ])) if ($@);
    }

    for my $ifName (keys %{$grefhCurrent->{If}}) {
        # Extract the index out of the MetaData
        my $Index = $grefhCurrent->{MD}->{Map}->{NameToIndex}->{"$ifName"};

        if (defined $refhSNMPResultIfSpeed->{$Index}) {
            my $IfSpeed = $refhSNMPResultIfSpeed->{$Index};
            # Get the speed in normal or highperf speed counters
            if ($IfSpeed and $IfSpeed ne ""){
                if ($IfSpeed >= 4294967294) {
                    # Too high for this counter (cf IF-MIB)
                    # get ifHighSpeed table (units of 1,000,000 bits per second)
                    if (defined $refhSNMPResultIfHighSpeed->{"$Index"} and $refhSNMPResultIfHighSpeed->{"$Index"} ne "" and $refhSNMPResultIfHighSpeed->{"$Index"} != 0) {
                        $IfSpeed = $refhSNMPResultIfHighSpeed->{"$Index"} * 1000000;
                    } else {
                        logger(1, " $ifName($Index) -> interface speed exceeding standard counter ($oid_ifSpeed{'oid'}.$Index: $IfSpeed). ".
                            "No high speed counter available, so the speed should be incorrect.");
                        $grefhCurrent->{MD}->{If}->{$ifName}->{MsgCrit} .= "<div class=\"critical\">".denormalize($ifName)." ($Index): interface speed exceeding standard counter. No high speed counter available, so the speed should be incorrect.</div>";
                    }
                } elsif ($IfSpeed == 3705032704 and $ghOptions{'nodetype'} eq 'cisco') {
                    # At least for a problem with Cisco NX-OS, which has an ifSpeed limit/max of 3705032704 for some 8G interfaces
                    # Forcing to take the ifHighSpeed instead
                    logger(1, " $ifName($Index) -> interface speed matching a situation where ifSpeed limit is 3705032704. Forcing the use of ifHighSpeed instead.");
                    if (defined $refhSNMPResultIfHighSpeed->{"$Index"} and $refhSNMPResultIfHighSpeed->{"$Index"} ne "" and $refhSNMPResultIfHighSpeed->{"$Index"} != 0) {
                        $IfSpeed = $refhSNMPResultIfHighSpeed->{"$Index"} * 1000000;
                    } else {
                        logger(1, " $ifName($Index) -> interface speed exceeding standard counter ($oid_ifSpeed{'oid'}.$Index: $IfSpeed). ".
                            "No high speed counter available, so the speed should be incorrect.");
                        $grefhCurrent->{MD}->{If}->{$ifName}->{MsgCrit} .= "<div class=\"critical\">".denormalize($ifName)." ($Index): interface speed exceeding standard counter. No high speed counter available, so the speed should be incorrect.</div>";
                    }
                } elsif ($IfSpeed == 1410065408 and $ghOptions{'nodetype'} eq 'netapp') {
                    # Problem with 10 gigabit interfaces on Netapp, forcing the speed (workaround)
                    logger(1, " $ifName($Index) -> interface speed matching a situation where speed is incorrect and should be ".
                        "10Gbps ($oid_ifSpeed{'oid'}.$Index: $IfSpeed). Forcing the speed.");
                    $grefhCurrent->{MD}->{If}->{$ifName}->{MsgCrit} .= "<div class=\"warning\">".denormalize($ifName)." ($Index): interface speed matching a situation ".
                        "where speed is incorrect and should be 10Gbps. Forcing the speed.</div>";
                    $IfSpeed = 10000000000;
                }
            } else {
                if (defined $refhSNMPResultIfHighSpeed->{"$Index"} and $refhSNMPResultIfHighSpeed->{"$Index"} ne "" and $refhSNMPResultIfHighSpeed->{"$Index"} != 0) {
                    $IfSpeed = $refhSNMPResultIfHighSpeed->{"$Index"} * 1000000;
                    logger(2, " $ifName($Index) -> no standard speed counter but high speed counter available");
                } else {
                    $IfSpeed = -1;
                }
            }
            # Recommendation in case Gigabit detected
            if ($IfSpeed >= 1000000000 and not $ghSNMPOptions{'64bits'} and not $ghOptions{'nodetype'} eq 'netapp') {
                logger(1, " $ifName($Index) -> not using highperf mib (--64bits): interface load calculation could be wrong for interface $ifName($Index) !!!");
                $grefhCurrent->{MD}->{If}->{$ifName}->{MsgWarn} .= "<div class=\"warning\">".denormalize($ifName)." ($Index): use of 32-bit counters not recommended with high speed interfaces like. If possible, consider the use of highperf mib (--64bits).</div>";
            }
            # Store ifSpeed in a machine and human readable format
            $grefhCurrent->{If}->{"$ifName"}->{ifSpeed} = $IfSpeed;
            if ($IfSpeed > 0) {
                $grefhCurrent->{If}->{"$ifName"}->{ifSpeedReadable} = format_volume_decimal ($IfSpeed,"bit");
                logger(2, "Index=$Index ($ifName): Speed=".$grefhCurrent->{If}->{"$ifName"}->{ifSpeedReadable});
            } else {
                logger(2, "Index=$Index ($ifName): Speed not applicable");
            }
        } elsif (defined $refhSNMPResultIfHighSpeed->{"$Index"} and $refhSNMPResultIfHighSpeed->{"$Index"} ne "" and $refhSNMPResultIfHighSpeed->{"$Index"} != 0) {
            # Get the speed from highperf speed counters
            my $IfSpeed = $refhSNMPResultIfHighSpeed->{"$Index"} * 1000000;
            logger(2, " $ifName($Index) -> no standard speed counter but high speed counter available");
            # Recommendation in case Gigabit detected
            if ($IfSpeed >= 1000000000 and not $ghSNMPOptions{'64bits'} and not $ghOptions{'nodetype'} eq 'netapp') {
                logger(1, " $ifName($Index) -> not using highperf mib (--64bits): interface load calculation could be wrong for interface $ifName($Index) !!!");
                $grefhCurrent->{MD}->{If}->{$ifName}->{MsgWarn} .= "<div class=\"warning\">".denormalize($ifName)." ($Index): use of 32-bit counters not recommended with high speed interfaces. If possible, consider the use of highperf mib (--64bits).</div>";
            }
            # Store ifSpeed in a machine and human readable format
            $grefhCurrent->{If}->{"$ifName"}->{ifSpeed} = $IfSpeed;
            if ($IfSpeed > 0) {
                $grefhCurrent->{If}->{"$ifName"}->{ifSpeedReadable} = format_volume_decimal ($IfSpeed,"bit");
                logger(2, "Index=$Index ($ifName): Speed=".$grefhCurrent->{If}->{"$ifName"}->{ifSpeedReadable});
            } else {
                logger(2, "Index=$Index ($ifName): Speed not applicable");
            }
        } else {
            #$grefhCurrent->{If}->{"$ifName"}->{ifSpeed} = undef;
            #$grefhCurrent->{If}->{"$ifName"}->{ifSpeedReadable} = undef;
            logger(2, "Index=$Index ($ifName): Speed not found");
        }
    }

    return 0;
}

# ------------------------------------------------------------------------
# walk through each interface and read ifAlias
# ------------------------------------------------------------------------
sub Get_Alias {

    my $refhOIDIfAlias = shift;
    my $refhSNMPResult;  # Lines returned from snmpwalk storing interface aliases

    # get ifAlias table - returned result can be empty
    eval {
        my %hOptions = ($ghOptions{'alias-matching'}) ? ( %ghSNMPOptions, (oids => ["$refhOIDIfAlias->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 0))
            : ( %ghSNMPOptions, (oids => ["$refhOIDIfAlias->{'oid'}"], cachetimer => $gLongCacheTimer, outputhashkeyidx => 1, checkempty => 0));
        $refhSNMPResult = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDIfAlias ])) if ($@);

    for my $ifName (keys %{$grefhCurrent->{If}}) {
        # Extract the index out of the MetaData
        my $Index = $grefhCurrent->{MD}->{Map}->{NameToIndex}->{"$ifName"};

        if (defined $refhSNMPResult->{$Index}) {
            my $Alias = "$refhSNMPResult->{$Index}";
            # Store ifAlias normalized to not get into trouble with special chars
            $grefhCurrent->{If}->{"$ifName"}->{ifAlias} = normalize ($Alias);
            logger(2, "Index=$Index ($ifName): Alias=\"".$grefhCurrent->{If}->{"$ifName"}->{ifAlias}."\"");
        } else {
            #$grefhCurrent->{If}->{"$ifName"}->{ifAlias} = undef;
            logger(2, "Index=$Index ($ifName): Alias not found for the interface");
        }
    }

    return 0;
}

# ------------------------------------------------------------------------
# walk through each interface and read ifDuplexStatus
# ------------------------------------------------------------------------
sub Get_Duplex {

    my $refhOID = shift;
    my $refhSNMPResult;  # Lines returned from snmpwalk storing interface aliases

    # get ifDuplexStatus table
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOID->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 0));
        $refhSNMPResult = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOID ])) if ($@);

    for my $ifName (keys %{$grefhCurrent->{If}}) {
        # Extract the index out of the MetaData
        my $Index = $grefhCurrent->{MD}->{Map}->{NameToIndex}->{"$ifName"};
        if (defined $refhSNMPResult->{$Index}) {
            # Store ifDuplexStatus converted from a digit to string
            $grefhCurrent->{If}->{"$ifName"}->{ifDuplexStatus} = (defined $refhOID->{'convertToReadable'}{"$refhSNMPResult->{$Index}"})
                ? $refhOID->{'convertToReadable'}{"$refhSNMPResult->{$Index}"} : $refhSNMPResult->{$Index};
            logger(2, "Index=$Index ($ifName): ifDuplexStatus=" . $grefhCurrent->{If}->{"$ifName"}->{ifDuplexStatus});
        } else {
            #$grefhCurrent->{If}->{"$ifName"}->{ifDuplexStatus} = undef;
            logger(2, "Index=$Index ($ifName): ifDuplexStatus not found for the interface");
        }
    }

    return 0;
}

# ------------------------------------------------------------------------
# get Spanning Tree
# ------------------------------------------------------------------------
sub Get_Stp {

    my $refhSNMPResultStpIfIndexMap;  # Lines returned from snmpwalk storing stp port->ifindex map table
    my $refhSNMPResultStpPortState;   # Lines returned from snmpwalk storing stp port states

    # get map table: stp port->ifindex
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$oid_dot1dBasePortIfIndex{oid}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResultStpIfIndexMap = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_dot1dBasePortIfIndex ])) if ($@);

    while ( my ($Idx1,$Idx2) = each(%$refhSNMPResultStpIfIndexMap) ) {
        $grefhCurrent->{MD}->{Map}->{dot1dBridge}->{StpIndexToIndex}->{"$Idx1"} = $Idx2;
        $grefhCurrent->{MD}->{Map}->{dot1dBridge}->{IndexToStpIndex}->{"$Idx2"} = $Idx1;
        $grefhCurrent->{MD}->{Map}->{dot1dBridge}->{NameToStpIndex}->{"$grefhCurrent->{MD}->{Map}->{IndexToName}->{$Idx2}"} = $Idx1;
        $grefhCurrent->{MD}->{Map}->{dot1dBridge}->{StpIndexToName}->{"$Idx1"} = "$grefhCurrent->{MD}->{Map}->{IndexToName}->{$Idx2}";
    }

    # get stp port state info
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$oid_dot1dStpPortState{oid}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResultStpPortState = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_dot1dStpPortState ])) if ($@);

    for my $ifName (keys %{$grefhCurrent->{If}}) {
        # Extract the index out of the MetaData
        if (defined $grefhCurrent->{MD}->{Map}->{dot1dBridge}->{NameToStpIndex}->{"$ifName"}) {
            my $StpIndex = $grefhCurrent->{MD}->{Map}->{dot1dBridge}->{NameToStpIndex}->{"$ifName"};
            if (defined $refhSNMPResultStpPortState->{$StpIndex}) {
                my $Portstate = $refhSNMPResultStpPortState->{$StpIndex};
                defined $oid_dot1dStpPortState{'convertToReadable'}{"$Portstate"} and $Portstate = $oid_dot1dStpPortState{'convertToReadable'}{"$Portstate"};
                logger(2, "IfName=\"$ifName\", StpIndex=\"$StpIndex\", StpPortstate=\"$Portstate\"");

                # Store the Portstate as property of the current interface
                $grefhCurrent->{If}->{"$ifName"}->{ifStpState} = "$Portstate";
            } else {
                $grefhCurrent->{If}->{"$ifName"}->{ifStpState} = '';
                logger(2, "IfName=\"$ifName\", StpIndex=\"$StpIndex\", StpPortstate not found for the interface");
            }
        } else {
            $grefhCurrent->{If}->{"$ifName"}->{ifStpState} = '';
            logger(2, "IfName=\"$ifName\", StpIndex not found for the interface");
        }
    }

    return 0;

}

# ------------------------------------------------------------------------------
# Get_IpInfo
# ------------------------------------------------------------------------------
# Description:
# This function extract ip addresses out of snmpwalk lines
# This function also push to the grefhCurrent hash:
# - Some if info:
#  * name
#  * index
#  * mac address
# ------------------------------------------------------------------------------
# Function call:
#  Get_IpInfo();
# Arguments:
#  None
# Output:
#  None
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------
# extract ip addresses out of snmpwalk lines
#
# # snmpwalk -Oqn -c public -v 1 router IP-MIB::ipAdEntIfIndex
# .1.3.6.1.2.1.4.20.1.2.172.31.92.91 15
# .1.3.6.1.2.1.4.20.1.2.172.31.92.97 15
# .1.3.6.1.2.1.4.20.1.2.172.31.99.76 15
# .1.3.6.1.2.1.4.20.1.2.193.83.153.254 29
# .1.3.6.1.2.1.4.20.1.2.193.154.197.192 14
#
# # snmpwalk -Oqn -v 1 -c public router IP-MIB::ipAdEntNetMask
# .1.3.6.1.2.1.4.20.1.3.172.31.92.91 255.255.255.255
# .1.3.6.1.2.1.4.20.1.3.172.31.92.97 255.255.255.255
#
# ------------------------------------------------------------------------
sub Get_IpInfo {

    my $refhOIDip = shift;
    my $refhOIDnetmask = shift;
    my $refhSNMPResultIpAddr;    # Lines returned from snmpwalk storing ip addresses
    my $refhSNMPResultNetMask;   # Lines returned from snmpwalk storing physical addresses

    # Get info from snmp/cache
    #------------------------------------------

    # get all interface ip info - resulting table can be empty
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDip->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 0));
        $refhSNMPResultIpAddr = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDip ])) if ($@);

    # store all ip information in the hash to avoid reading the netmask
    # again in the next run
    {
      local $Data::Dumper::Indent = 0;
      $grefhCurrent->{MD}->{CachedInfo}->{IpInfo} = Dumper($refhSNMPResultIpAddr);
    }

    # get the subnet masks with caching 0 only if the ip addresses
    # have changed - resulting table can be empty
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDnetmask->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 0));
        (defined $grefhFile->{MD}->{CachedInfo}->{IpInfo} and $grefhCurrent->{MD}->{CachedInfo}->{IpInfo} eq $grefhFile->{MD}->{CachedInfo}->{IpInfo})
            and $hOptions{cachetimer} = $gLongCacheTimer;
        $refhSNMPResultNetMask = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDnetmask ])) if ($@);


    # Get info from snmp/cache
    #------------------------------------------

    # Example of refhSNMPResultIpAddr info:
    #  172.31.99.76 15
    #  193.83.153.254 29
    while ( my ($IpAddress,$Index) = each(%$refhSNMPResultIpAddr) ) {

        # Check that the index match a known interface. skip if not
        next unless (defined $grefhCurrent->{MD}->{Map}->{IndexToName}->{"$Index"});
        
        # Be sure that it's only an ip (ipv4)
        $IpAddress =~ s/^.*\(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\)$/$1/;
        
        # Example of refhSNMPResultNetMask info:
        #  10.1.1.4 255.255.0.0
        #  10.2.1.4 255.255.0.0
        #  172.30.1.4 255.255.0.0

        my $NetMask = (defined $refhSNMPResultNetMask->{"${IpAddress}"}) ? $refhSNMPResultNetMask->{"${IpAddress}"} : "";
        $NetMask = $quadmask2dec{"$NetMask"} if (defined $quadmask2dec{"$NetMask"});
        # get the interface ifName stored before from the index table
        my $ifName = $grefhCurrent->{MD}->{Map}->{IndexToName}->{"$Index"};
        logger(2, "IpAddress \"$IpAddress\" with Netmask \"$NetMask\": mapped to interface \"$ifName\" (idx:$Index)");

        # separate multiple IP Adresses with a blank
        # blank is good because the WEB browser can break lines
        $grefhCurrent->{If}->{"$ifName"}->{ifIpInfo} .= " " if ($grefhCurrent->{If}->{"$ifName"}->{ifIpInfo});

        # now we have finished with the puzzle of getting ip and subnet mask
        # add IpInfo as property to the interface
        my $IpInfo = "$IpAddress";
        $IpInfo .= "/$NetMask" if ($NetMask);
        $grefhCurrent->{If}->{"$ifName"}->{ifIpInfo} .= $IpInfo;

        # check if the IP address has changed to its first run
        my $FirstIpInfo = $grefhFile->{If}->{"$ifName"}->{ifIpInfo};
        $FirstIpInfo = "" unless ($FirstIpInfo);

        # disable caching of this interface if ip information has changed
        if ("$IpInfo" ne "$FirstIpInfo") {
            $grefhCurrent->{MD}->{If}->{"$ifName"}->{CacheTimer} = 0;
            $grefhCurrent->{MD}->{If}->{"$ifName"}->{CacheTimerComment} =
                "caching is disabled because of first or current IpInfo";
        }
    }

    return 0;
}

# ------------------------------------------------------------------------------
# Get_Traffic
# ------------------------------------------------------------------------------
# Description: gather interface traffic in/out
# ------------------------------------------------------------------------------
# Function call:
#  Get_Traffic();
# Arguments:
#  None
# Output:
#  None
# ------------------------------------------------------------------------------
sub Get_Traffic {
    my $counterType = shift;

    if ("$counterType" eq "32") {
        my $refhOIDoctetsIn = shift;
        my $refhOIDoctetsOut = shift;
        my $refhSNMPResultOctetsIn;   # Lines returned from snmpwalk storing ifOctetsIn
        my $refhSNMPResultOctetsOut;  # Lines returned from snmpwalk storing ifOctetsIn

        # get all interface in/out traffic octet counters - no caching !
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDoctetsIn->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultOctetsIn = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDoctetsIn ])) if ($@);
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDoctetsOut->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultOctetsOut = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDoctetsOut ])) if ($@);

        # traffic monitoring capacity advice
        # based on rfc2233 for Ethernet (http://www.ietf.org/rfc/rfc2233.txt)
        $grefAoHConfigTableData->[7]->[1]->{Value} .= "Using 32-bit counters, with delta $ghOptions{'delta'}. " .
            "Can monitor a bandwidth of ".format_volume_decimal((60*57*10*10**6)/($ghOptions{'delta'}*4/3),"bps")." maximum. " .
            "If not enough, consider decreasing delta";
        # old calculation
        #$grefAoHConfigTableData->[7]->[1]->{Value} .= "Using 32-bit counters, with delta $ghOptions{'delta'}. " .
        #    "Can monitor a bandwidth of ".format_volume_decimal((2**32-1 )/($ghOptions{'delta'}*4/3),"bps")." maximum. " .
        #    "If not enough, consider decreasing delta or use 64-bit counters (--64bits)";

        # post-processing interface octet counters
        Process_IfCounter ($refhSNMPResultOctetsIn, "OctetsIn", "32");
        Process_IfCounter ($refhSNMPResultOctetsOut, "OctetsOut", "32");

    } elsif ("$counterType" eq "64") {
        my $refhOIDoctetsIn = shift;
        my $refhOIDoctetsOut = shift;
        my $refhSNMPResultOctetsIn;   # Lines returned from snmpwalk storing ifXOctetsIn
        my $refhSNMPResultOctetsOut;  # Lines returned from snmpwalk storing ifXOctetsIn

        # get all interface in/out traffic octet counters - no caching !
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDoctetsIn->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultOctetsIn = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDoctetsIn ])) if ($@);
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDoctetsOut->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultOctetsOut = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDoctetsOut ])) if ($@);

        # traffic monitoring capacity advice
        # based on rfc2233 for Ethernet (http://www.ietf.org/rfc/rfc2233.txt)
        $grefAoHConfigTableData->[7]->[1]->{Value} .= "Using 64-bit counters, with delta $ghOptions{'delta'}. " .
            "Can monitor a bandwidth of ".format_volume_decimal((60*30*81*10**12)/($ghOptions{'delta'}*4/3),"bps")." maximum. " .
            "If not enough, consider decreasing delta";
        # old calculation
        #$grefAoHConfigTableData->[7]->[1]->{Value} .= "Using 64-bit counters, with delta $ghOptions{'delta'}. " .
        #    "Can monitor a bandwidth of ".format_volume_decimal((2**64-1 )/($ghOptions{'delta'}*4/3),"bps")." maximum. " .
        #    "If not enough, consider decreasing delta";
        
        # post-processing interface octet counters
        Process_IfCounter ($refhSNMPResultOctetsIn, "OctetsIn", "64");
        Process_IfCounter ($refhSNMPResultOctetsOut, "OctetsOut", "64");

    } elsif ("$counterType" eq "HighLow") {
        # 64-bit unsigned integer for In/Out octet counters, splitted in 2 objects (Low and High)
        # get all interface in/out traffic octet counters (Low and High counters) - no caching !
        my $refhOIDoctetsInHigh = shift;
        my $refhOIDoctetsInLow = shift;
        my $refhOIDoctetsOutHigh = shift;
        my $refhOIDoctetsOutLow = shift;
        my $refhSNMPResultOctetsIn;
        my $refhSNMPResultOctetsOut;
        my $refhSNMPResultOctetsInHigh;
        my $refhSNMPResultOctetsInLow;
        my $refhSNMPResultOctetsOutHigh;
        my $refhSNMPResultOctetsOutLow;

        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDoctetsInHigh->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultOctetsInHigh = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDoctetsInHigh ])) if ($@);
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDoctetsInLow->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultOctetsInLow = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDoctetsInLow ])) if ($@);
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDoctetsOutHigh->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultOctetsOutHigh = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDoctetsOutHigh ])) if ($@);
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDoctetsOutLow->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultOctetsOutLow = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDoctetsOutLow ])) if ($@);

        # build a hashs gathering low+high in octet counters
        foreach my $key (keys %$refhSNMPResultOctetsInLow) {
            $key =~ s/^\.*$refhOIDoctetsInLow->{'oid'}\.//g; # remove all but the index
            $refhSNMPResultOctetsIn->{"$key"} = $refhSNMPResultOctetsInLow->{"$refhOIDoctetsInLow->{'oid'}.$key"};
            if (defined $refhSNMPResultOctetsInHigh->{"$refhOIDoctetsInHigh->{'oid'}.$key"} and $refhSNMPResultOctetsInHigh->{"$refhOIDoctetsInHigh->{'oid'}.$key"} > 0) {
                $refhSNMPResultOctetsIn->{"$key"} += $refhSNMPResultOctetsInHigh->{"$refhOIDoctetsInHigh->{'oid'}.$key"}<<32;
            }
        }

        # build a hashs gathering low+high out octet counters
        foreach my $key (keys %$refhSNMPResultOctetsOutLow) {
            $key =~ s/^\.*$refhOIDoctetsOutLow->{'oid'}\.//g; # remove all but the index
            $refhSNMPResultOctetsOut->{"$key"} = $refhSNMPResultOctetsOutLow->{"$refhOIDoctetsOutLow->{'oid'}.$key"};
            if (defined $refhSNMPResultOctetsOutHigh->{"$refhOIDoctetsOutLow->{'oid'}.$key"} and $refhSNMPResultOctetsOutHigh->{"$refhOIDoctetsOutLow->{'oid'}.$key"} > 0) {
                $refhSNMPResultOctetsOut->{"$key"} += $refhSNMPResultOctetsOutHigh->{"$refhOIDoctetsOutLow->{'oid'}.$key"}<<32;
            }
        }

        # traffic monitoring capacity advice
        # based on rfc2233 for Ethernet (http://www.ietf.org/rfc/rfc2233.txt)
        $grefAoHConfigTableData->[7]->[1]->{Value} .= "Using 32-bit low and high counters, with delta $ghOptions{'delta'}. " .
            "Can monitor a bandwidth of ".format_volume_decimal((60*30*81*10**12)/($ghOptions{'delta'}*4/3),"bps")." maximum. " .
            "If not enough, consider decreasing delta";
        # old calculation
        #$grefAoHConfigTableData->[7]->[1]->{Value} .= "Using 32-bit low and high counters, with delta $ghOptions{'delta'}. " .
        #    "Can monitor a bandwidth of ".format_volume_decimal((2**(32+32)-1 )/($ghOptions{'delta'}*4/3),"bps")." maximum. " .
        #    "If not enough, consider decreasing delta";
        
        # post-processing interface octet counters
        Process_IfCounter ($refhSNMPResultOctetsIn, "OctetsIn", "64");
        Process_IfCounter ($refhSNMPResultOctetsOut, "OctetsOut", "64");

    } elsif ("$counterType" eq "64+32") {
        my $refhOIDoctetsIn64 = shift;
        my $refhOIDoctetsOut64 = shift;
        my $refhSNMPResultOctetsIn64;   # Lines returned from snmpwalk storing ifXOctetsIn
        my $refhSNMPResultOctetsOut64;  # Lines returned from snmpwalk storing ifXOctetsIn
        
        my $refhOIDoctetsIn32 = shift;
        my $refhOIDoctetsOut32 = shift;
        my $refhSNMPResultOctetsIn32;   # Lines returned from snmpwalk storing ifOctetsIn
        my $refhSNMPResultOctetsOut32;  # Lines returned from snmpwalk storing ifOctetsIn
        my $refhSNMPResultOctetsIn32Filtered;
        my $refhSNMPResultOctetsOut32Filtered;

        ### Start by retrieving the 64-bit counters
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDoctetsIn64->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultOctetsIn64 = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDoctetsIn64 ])) if ($@);
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDoctetsOut64->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultOctetsOut64 = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDoctetsOut64 ])) if ($@);

        # traffic monitoring capacity advice
        # based on rfc2233 for Ethernet (http://www.ietf.org/rfc/rfc2233.txt)
        $grefAoHConfigTableData->[7]->[1]->{Value} .= "Using 64-bit counters, with delta $ghOptions{'delta'}. " .
            "Can monitor a bandwidth of ".format_volume_decimal((60*30*81*10**12)/($ghOptions{'delta'}*4/3),"bps")." maximum. " .
            "If not enough, consider decreasing delta";
        # old calculation
        #$grefAoHConfigTableData->[7]->[1]->{Value} .= "Using 64-bit counters, with delta $ghOptions{'delta'}. " .
        #    "Can monitor a bandwidth of ".format_volume_decimal((2**64-1 )/($ghOptions{'delta'}*4/3),"bps")." maximum. " .
        #    "If not enough, consider decreasing delta";
        
        # post-processing interface octet counters
        Process_IfCounter ($refhSNMPResultOctetsIn64, "OctetsIn", "64");
        Process_IfCounter ($refhSNMPResultOctetsOut64, "OctetsOut", "64");
        
        ### Then retrieve the 32bit counters if needed
        # loop through all found interfaces
        my @aListIfLowSpeedNoCounter;
        my @aListIfLowSpeedCounter32Idx;
        my @aListIfLowSpeedCounter32Name;
        for my $ifName (keys %{$grefhCurrent->{If}}) {
            # Extract the index out of the MetaData
            my $Index = $grefhCurrent->{MD}->{Map}->{NameToIndex}->{"$ifName"};
            if (not defined $refhSNMPResultOctetsIn64->{$Index} and defined $grefhCurrent->{If}->{"$ifName"}->{ifSpeed} 
              and $grefhCurrent->{If}->{"$ifName"}->{ifSpeed} <= 20000000) {
                push(@aListIfLowSpeedNoCounter, $Index);
            }
        }
        if (@aListIfLowSpeedNoCounter){
            # get all interface in/out traffic octet counters - no caching !
            eval {
                my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDoctetsIn32->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
                $refhSNMPResultOctetsIn32 = GetTableDataWithSnmp (\%hOptions);
            };
            ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDoctetsIn32 ])) if ($@);
            eval {
                my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDoctetsOut32->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
                $refhSNMPResultOctetsOut32 = GetTableDataWithSnmp (\%hOptions);
            };
            ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDoctetsOut32 ])) if ($@);
            
            for my $idx (@aListIfLowSpeedNoCounter) {
                if (defined $refhSNMPResultOctetsIn32->{$idx} and defined $refhSNMPResultOctetsOut32->{$idx} ){
                    $refhSNMPResultOctetsIn32Filtered->{$idx} = $refhSNMPResultOctetsIn32->{$idx};
                    $refhSNMPResultOctetsOut32Filtered->{$idx} = $refhSNMPResultOctetsOut32->{$idx};
                    push(@aListIfLowSpeedCounter32Idx, $idx);
                    my $Name = denormalize($grefhCurrent->{MD}->{Map}->{IndexToName}->{"$idx"});
                    push(@aListIfLowSpeedCounter32Name, $Name);
                    $grefhCurrent->{MD}->{If}->{"$Name"}->{MsgInfo} .= "<div class=\"information\">".
                        "Interface \"$Name\": no 64-bit counter but 32-bit counter found for this low speed interface (<20Mbps). Using it.</div>";
                }
            }
            if (@aListIfLowSpeedCounter32Idx){
                # traffic monitoring capacity advice
                # based on rfc2233 for Ethernet (http://www.ietf.org/rfc/rfc2233.txt)
                $grefAoHConfigTableData->[7]->[1]->{Value} .= "<br>Moreover, using 32-bit counters for the following low speed interfaces as no 64-bit " .
                    "counters where found: " . join(', ',@aListIfLowSpeedCounter32Name) . ". For there interfaces, with delta $ghOptions{'delta'}, the plugin " .
                    "can monitor a bandwidth of ".format_volume_decimal((60*57*10*10**6)/($ghOptions{'delta'}*4/3),"bps")." maximum. " .
                    "If not enough, consider decreasing delta";
                ## logger(2, "IfName=\"$ifName\", StpIndex=\"$StpIndex\", StpPortstate not found for the interface");
                # post-processing interface octet counters
                Process_IfCounter ($refhSNMPResultOctetsIn32Filtered, "OctetsIn", "32");
                Process_IfCounter ($refhSNMPResultOctetsOut32Filtered, "OctetsOut", "32");
            }
        }
    }

    return 0;
}

# ------------------------------------------------------------------------------
# Get_Error_Discard
# ------------------------------------------------------------------------------
# Description: gather interface packet errors/discards
# ------------------------------------------------------------------------------
# Function call:
#  Get_Error_Discard();
# Arguments:
#  None
# Output:
#  None
# ------------------------------------------------------------------------------
sub Get_Error_Discard {
    my $refhSNMPResultInErrors;    # Lines returned from snmpwalk storing ifPktsInErr
    my $refhSNMPResultOutErrors;   # Lines returned from snmpwalk storing ifPktsOutErr
    my $refhSNMPResultInDiscards;  # Lines returned from snmpwalk storing ifPktsInDiscard
    my $refhSNMPResultOutDiscard;  # Lines returned from snmpwalk storing ifPktsOutDiscard

    # Get info from snmp/cache
    #------------------------------------------

    # get all interface in/out packet error/discarded octet counters - no caching !
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$oid_ifInErrors{oid}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResultInErrors = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_ifInErrors ])) if ($@);
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$oid_ifOutErrors{oid}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResultOutErrors = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_ifOutErrors ])) if ($@);
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$oid_ifInDiscards{oid}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResultInDiscards = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_ifInDiscards ])) if ($@);
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$oid_ifOutDiscards{oid}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResultOutDiscard = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_ifOutDiscards ])) if ($@);

    # post-processing interface octet counters
    #------------------------------------------

    Process_IfCounter ($refhSNMPResultInErrors, "PktsInErr", "32");
    Process_IfCounter ($refhSNMPResultOutErrors, "PktsOutErr", "32");
    Process_IfCounter ($refhSNMPResultInDiscards, "PktsInDiscard", "32");
    Process_IfCounter ($refhSNMPResultOutDiscard, "PktsOutDiscard", "32");

    return 0;
}

# ------------------------------------------------------------------------------
# Get_Packets
# ------------------------------------------------------------------------------
# Description: gather interface packets in/out
# ------------------------------------------------------------------------------
# Function call:
#  Get_Packets();
# Arguments:
#  None
# Output:
#  None
# ------------------------------------------------------------------------------
sub Get_Packets {
    my $counterType = shift;

    my $refhSNMPResultPktsInUcast;     # Lines returned from snmpwalk storing Ucast Pkts In
    my $refhSNMPResultPktsOutUcast;    # Lines returned from snmpwalk storing Ucast Pkts Out
    my $refhSNMPResultPktsInNUcast;    # Lines returned from snmpwalk storing NUcast Pkts In
    my $refhSNMPResultPktsOutNUcast;   # Lines returned from snmpwalk storing NUcast Pkts Out

    if ("$counterType" eq "64") {
        my $refhOidUCastIn = shift;
        my $refhOidUCastOut = shift;
        my $refhOidMulticastIn = shift;
        my $refhOidMulticastOut = shift;
        my $refhOidBroadcastIn = shift;
        my $refhOidBroadcastOut = shift;

        my $refhSNMPResultMulticastPktIn;    # Lines returned from snmpwalk storing Multicast Pkts In
        my $refhSNMPResultMulticastPktOut;   # Lines returned from snmpwalk storing Multicast Pkts Out
        my $refhSNMPResultBroadcastPktIn;    # Lines returned from snmpwalk storing Broadcast Pkts In
        my $refhSNMPResultBroadcastPktOut;   # Lines returned from snmpwalk storing Broadcast Pkts Out

        # get all interface in/out traffic octet counters - no caching !
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOidUCastIn->{oid}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultPktsInUcast = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOidUCastIn ])) if ($@);
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOidUCastOut->{oid}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultPktsOutUcast = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOidUCastOut ])) if ($@);
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOidMulticastIn->{oid}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultMulticastPktIn = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOidMulticastIn ])) if ($@);
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOidMulticastOut->{oid}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultMulticastPktOut = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOidMulticastOut ])) if ($@);
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOidBroadcastIn->{oid}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultBroadcastPktIn = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOidBroadcastIn ])) if ($@);
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOidBroadcastOut->{oid}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultBroadcastPktOut = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOidBroadcastOut ])) if ($@);

        foreach my $key (keys %$refhSNMPResultMulticastPktIn) {
            $key =~ s/^\.*$refhOidMulticastIn->{'oid'}\.//g; # remove all but the index
            $refhSNMPResultPktsInNUcast->{"$key"} = $refhSNMPResultMulticastPktIn->{"$key"};
            $refhSNMPResultPktsInNUcast->{"$key"} += $refhSNMPResultBroadcastPktIn->{"$key"} if (defined $refhSNMPResultBroadcastPktIn->{"$key"});
        }
        foreach my $key (keys %$refhSNMPResultMulticastPktOut) {
            $key =~ s/^\.*$refhOidMulticastOut->{'oid'}\.//g; # remove all but the index
            $refhSNMPResultPktsOutNUcast->{"$key"} = $refhSNMPResultMulticastPktOut->{"$key"};
            $refhSNMPResultPktsOutNUcast->{"$key"} += $refhSNMPResultBroadcastPktOut->{"$key"} if (defined $refhSNMPResultBroadcastPktOut->{"$key"});
        }

        # post-processing interface pkts counters
        #------------------------------------------
    
        Process_IfCounter ($refhSNMPResultPktsInUcast, "PktsInUcast", "64");
        Process_IfCounter ($refhSNMPResultPktsOutUcast, "PktsOutUcast", "64");
        Process_IfCounter ($refhSNMPResultPktsInNUcast, "PktsInNUcast", "64");
        Process_IfCounter ($refhSNMPResultPktsOutNUcast, "PktsOutNUcast", "64");

    } elsif ("$counterType" eq "32") {
        my $refhOidUCastIn = shift;
        my $refhOidUCastOut = shift;
        my $refhOidNUCastIn = shift;
        my $refhOidNUCastOut = shift;

        # get all interface in/out traffic octet counters - no caching !
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOidUCastIn->{oid}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultPktsInUcast = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOidUCastIn ])) if ($@);
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOidUCastOut->{oid}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultPktsOutUcast = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOidUCastOut ])) if ($@);
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOidNUCastIn->{oid}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultPktsInNUcast = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOidNUCastIn ])) if ($@);
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOidNUCastOut->{oid}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultPktsOutNUcast = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOidNUCastOut ])) if ($@);

        # post-processing interface pkts counters
        #------------------------------------------
    
        Process_IfCounter ($refhSNMPResultPktsInUcast, "PktsInUcast", "32");
        Process_IfCounter ($refhSNMPResultPktsOutUcast, "PktsOutUcast", "32");
        Process_IfCounter ($refhSNMPResultPktsInNUcast, "PktsInNUcast", "32");
        Process_IfCounter ($refhSNMPResultPktsOutNUcast, "PktsOutNUcast", "32");
    }

    return 0;
}

# ------------------------------------------------------------------------------
# Process_IfCounter
# ------------------------------------------------------------------------------
# Description: process interface counter by storing it in historical dataset
# and in current interface stats
# ------------------------------------------------------------------------------
# Function call:
#  Process_IfCounter();
# Arguments:
#  None
# Output:
#  None
# ------------------------------------------------------------------------------
sub Process_IfCounter {

    my $refhCounter = shift;
    my $WhatCounter = shift;
    my $TypeCounter = shift;
    
    # check if the counter is back to 0 after 2^32 / 2^64.
    # First set the modulus depending on highperf counters or not
    my $overfl_mod = ($ghSNMPOptions{'64bits'} and "$TypeCounter" ne "32") ? 18446744073709551616 : 4294967296;

    # Example of $refhCounter
    #    .1.3.6.1.2.1.2.2.1.10.2 2510821601
    #    .1.3.6.1.2.1.2.2.1.10.3 0
    for my $ifName (keys %{$grefhCurrent->{If}}) {
        # Extract the index out of the MetaData
        my $Index = $grefhCurrent->{MD}->{Map}->{NameToIndex}->{"$ifName"};
        if (defined $refhCounter->{$Index}) {
            # Store the counter value of the current interface
            $grefhCurrent->{MD}->{IfCounters}->{"$ifName"}->{"$WhatCounter"} = $refhCounter->{$Index};
            $grefhFile->{History}->{$STARTTIME}->{IfCounters}->{"$ifName"}->{"$WhatCounter"} = $refhCounter->{$Index};
            logger(2, "Index=$Index ($ifName): $WhatCounter counter is \"$refhCounter->{$Index}\"");
            if ($gBasetime and defined $grefhFile->{History}->{$gBasetime}->{IfCounters}->{"$ifName"}->{"$WhatCounter"}){
                my $overfl = ($grefhFile->{History}->{$STARTTIME}->{IfCounters}->{"$ifName"}->{"$WhatCounter"} >=
                    $grefhFile->{History}->{$gBasetime}->{IfCounters}->{"$ifName"}->{"$WhatCounter"} ) ? 0 : $overfl_mod;
                logger(2, " Counter wrap detected, historical value is ".
                    $grefhFile->{History}->{$gBasetime}->{IfCounters}->{"$ifName"}->{"$WhatCounter"}) if ($overfl);
                $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{"$WhatCounter"} = sprintf("%0.2f",
                    ($grefhFile->{History}->{$STARTTIME}->{IfCounters}->{"$ifName"}->{"$WhatCounter"} -
                    $grefhFile->{History}->{$gBasetime}->{IfCounters}->{"$ifName"}->{"$WhatCounter"} + $overfl) / $gUsedDelta);
                logger(2, " Valid historical data found, $WhatCounter per second statistic is \"".$grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{"$WhatCounter"}."\"");
            }
        } else {
            #$grefhCurrent->{MD}->{IfCounters}->{"$ifName"}->{"$WhatCounter"} = undef;
            logger(2, "Index=$Index ($ifName): $WhatCounter not found for the interface");
        }
    }

    return 0;
}

# ------------------------------------------------------------------------
# Evaluate_Interfaces
# ------------------------------------------------------------------------
# This function includes or excludes interfaces from:
#  * interface traffic load tracking
#  * interface property(ies) change tracking
#
# Interface traffic load tracking:
# All interfaces which are excluded using -e or --exclude will be
# excluded from traffic measurement (main check). Property(ies) tracking is
# implicitely disabled on such an interface.
#
# Interface property(ies) change tracking
# All the interfaces which are included in the traffic load tracking are
# automatically added to the interface properti(es) tracking list.
#
#   Indicated must be the interface name (ifDescr)
#   -e "3COM Etherlink PCI"
#
#   It is possible to exclude all interfaces
#   -e "ALL"
#
#   It is possible to exclude all interfaces but include one
#   -e "ALL" -i "3COM Etherlink PCI"
#
# It isnt neccessary to include ALL. By default, all the interfaces are
# included.
#
# The interface information file will be altered as follows:
#
# <MD>
#    <If>
#        <3COMQ20EtherlinkQ20PCI>
#            CacheTimer               3600
#            ExcludedLoadTrack        false
#            ExcludedPropertyTrack    true
#            ifOperStatusChangeTime   1151586678
#        </3COMQ20EtherlinkQ20PCI>
#    </If>
# </MD>
#
# ------------------------------------------------------------------------
sub Evaluate_Interfaces {

    my $ExcludeTrackList = shift;
    my $IncludeTrackList = shift;
    my $ExcludeLoadTrackList = shift;
    my $IncludeLoadTrackList = shift;
    my $ExcludePropertyTrackList = shift;
    my $IncludePropertyTrackList = shift;

    if (defined $ExcludeTrackList) { logger(2, "ExcludeTrackList: " . join(", ",@{$ExcludeTrackList})); }
    if (defined $IncludeTrackList) { logger(2, "IncludeTrackList: " . join(", ",@{$IncludeTrackList})); }
    if (defined $ExcludeLoadTrackList) { logger(2, "ExcludeLoadTrackList: " . join(", ",@{$ExcludeLoadTrackList})); }
    if (defined $IncludeLoadTrackList) { logger(2, "IncludeLoadTrackList: " . join(", ",@{$IncludeLoadTrackList})); }
    if (defined $ExcludePropertyTrackList) { logger(2, "ExcludePropertyTrackList: " . join(", ",@{$ExcludePropertyTrackList})); }
    if (defined $IncludePropertyTrackList) { logger(2, "IncludePropertyTrackList: " . join(", ",@{$IncludePropertyTrackList})); }

    # Loop through all interfaces
    for my $ifName (keys %{$grefhCurrent->{MD}->{If}}) {

        # Denormalize interface name and alias
        my $ifNameReadable = denormalize ($ifName);
        my $ifAliasReadable = "";
        if ($ghOptions{'alias'}) {
           $ifAliasReadable = denormalize ($grefhCurrent->{If}->{"$ifName"}->{ifAlias});
        }

        #----- Includes or excludes interfaces from all tracking -----#

        # By default, don't exclude the interface
        $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedTrack} = "false";
        $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedLoadTrack} = "false";
        $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedPropertyTrack} = "false";

        # Exclude "temporary interfaces"
        # After a reboot of a node, the description of some interfaces seems to have the following format for
        # a short duration: <ifDescr>_0x<MAC address>
        # Don't know yet if this is related to the script logic of if this is really what is returned by
        # the snmp request. Nothing about that in the RFC (RFC1213)... Need some tests.
        # Anyway, skipping these interfaces...
        if ("$ifNameReadable" =~ /_0x/) {
            logger(1, "-- exclude \"temporary interface\" \"$ifNameReadable\"");
            $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedTrack} = "true";
            next;
        }

        # Process the interface exclusion list
        for my $ExcludeString (@$ExcludeTrackList) {
            if ($ghOptions{regexp}) {
                if ($ghOptions{'alias'} and $ghOptions{'alias-matching'}) {
                    if ("${ifNameReadable}" =~ /$ExcludeString/i or "${ifAliasReadable}" =~ /$ExcludeString/i or "$ExcludeString" eq "ALL") {
                        logger(1, "-- exclude ($ExcludeString) interface \"$ifNameReadable\" (Alias: \"$ifAliasReadable\") globally");
                        $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedTrack} = "true";
                    }
                } else {
                    if ("${ifNameReadable}" =~ /$ExcludeString/i or "$ExcludeString" eq "ALL") {
                        logger(1, "-- exclude ($ExcludeString) interface \"$ifNameReadable\" globally");
                        $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedTrack} = "true";
                    }
                }
            } else {
                if ($ghOptions{'alias'} and $ghOptions{'alias-matching'}) {
                    if ("${ifNameReadable}" eq "$ExcludeString" or "${ifAliasReadable}" eq "$ExcludeString" or "$ExcludeString" eq "ALL") {
                        logger(1, "-- exclude ($ExcludeString) interface \"$ifNameReadable\" (Alias: \"$ifAliasReadable\") globally");
                        $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedTrack} = "true";
                    }
                } else {
                    if ("${ifNameReadable}" eq "$ExcludeString" or "$ExcludeString" eq "ALL") {
                        logger(1, "-- exclude ($ExcludeString) interface \"$ifNameReadable\" globally");
                        $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedTrack} = "true";
                    }
                }
            }
        }

        # Process the interface inclusion list
        # Inclusions are done after exclusions to be able to include a
        # subset of a group of interfaces which were excluded previously
        for my $IncludeString (@$IncludeTrackList) {
            if ($ghOptions{regexp}) {
                if ($ghOptions{'alias'} and $ghOptions{'alias-matching'}) {
                    if ("${ifNameReadable}" =~ /$IncludeString/i or "${ifAliasReadable}" =~ /$IncludeString/i or "$IncludeString" eq "ALL") {
                        logger(1, "++ include ($IncludeString) interface \"$ifNameReadable\" (Alias: \"$ifAliasReadable\") globally");
                        $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedTrack} = "false";
                    }
                } else {
                    if ("${ifNameReadable}" =~ /$IncludeString/i or "$IncludeString" eq "ALL") {
                        logger(1, "++ include ($IncludeString) interface \"$ifNameReadable\" globally");
                        $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedTrack} = "false";
                    }
                }
            } else {
                if ($ghOptions{'alias'} and $ghOptions{'alias-matching'}) {
                    if ("${ifNameReadable}" eq "$IncludeString" or "${ifAliasReadable}" eq "$IncludeString" or "$IncludeString" eq "ALL") {
                        logger(1, "++ include ($IncludeString) interface \"$ifNameReadable\" (Alias: \"$ifAliasReadable\") globally");
                        $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedTrack} = "false";
                    }
                } else {
                    if ("${ifNameReadable}" eq "$IncludeString" or "$IncludeString" eq "ALL") {
                        logger(1, "++ include ($IncludeString) interface \"$ifNameReadable\" globally");
                        $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedTrack} = "false";
                    }
                }
            }
        }

        # Update the counter if needed
        if ($grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedTrack} eq "false") {
            $gNumberOfPerfdataInterfaces++;
        }

        #----- Includes or excludes interfaces from traffic load tracking -----#

        # For the interfaces included (for which the traffic load is tracked), enable property(ies)
        # tracking depending on the exclude and/or include property tracking port list
        if ($grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedTrack} eq "false") {

            # Process the interface exclusion list
            for my $ExcludeString (@$ExcludeLoadTrackList) {
                if ($ghOptions{regexp}) {
                    if ($ghOptions{'alias'} and $ghOptions{'alias-matching'}) {
                        if ("${ifNameReadable}" =~ /$ExcludeString/i or "${ifAliasReadable}" =~ /$ExcludeString/i or "$ExcludeString" eq "ALL") {
                            logger(1, "-- exclude ($ExcludeString) interface \"$ifNameReadable\" (Alias: \"$ifAliasReadable\") from traffic load tracking");
                            $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedLoadTrack} = "true";
                        }
                    } else {
                        if ("${ifNameReadable}" =~ /$ExcludeString/i or "$ExcludeString" eq "ALL") {
                            logger(1, "-- exclude ($ExcludeString) interface \"$ifNameReadable\" from traffic load tracking");
                            $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedLoadTrack} = "true";
                        }
                    }
                } else {
                    if ($ghOptions{'alias'} and $ghOptions{'alias-matching'}) {
                        if ("${ifNameReadable}" eq "$ExcludeString" or "${ifAliasReadable}" eq "$ExcludeString" or "$ExcludeString" eq "ALL") {
                            logger(1, "-- exclude ($ExcludeString) interface \"$ifNameReadable\" (Alias: \"$ifAliasReadable\") from traffic load tracking");
                            $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedLoadTrack} = "true";
                        }
                    } else {
                        if ("${ifNameReadable}" eq "$ExcludeString" or "$ExcludeString" eq "ALL") {
                            logger(1, "-- exclude ($ExcludeString) interface \"$ifNameReadable\" from traffic load tracking");
                            $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedLoadTrack} = "true";
                        }
                    }
                }
            }

            # Process the interface inclusion list
            # Inclusions are done after exclusions to be able to include a
            # subset of a group of interfaces which were excluded previously
            for my $IncludeString (@$IncludeLoadTrackList) {
                if ($ghOptions{regexp}) {
                    if ($ghOptions{'alias'} and $ghOptions{'alias-matching'}) {
                        if ("${ifNameReadable}" =~ /$IncludeString/i or "${ifAliasReadable}" =~ /$IncludeString/i or "$IncludeString" eq "ALL") {
                            logger(1, "++ include ($IncludeString) interface \"$ifNameReadable\" (Alias: \"$ifAliasReadable\") from traffic load tracking");
                            $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedLoadTrack} = "false";
                        }
                    } else {
                        if ("${ifNameReadable}" =~ /$IncludeString/i or "$IncludeString" eq "ALL") {
                            logger(1, "++ include ($IncludeString) interface \"$ifNameReadable\" from traffic load tracking");
                            $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedLoadTrack} = "false";
                        }
                    }
                } else {
                    if ($ghOptions{'alias'} and $ghOptions{'alias-matching'}) {
                        if ("${ifNameReadable}" eq "$IncludeString" or "${ifAliasReadable}" eq "$IncludeString" or "$IncludeString" eq "ALL") {
                            logger(1, "++ include ($IncludeString) interface \"$ifNameReadable\" (Alias: \"$ifAliasReadable\") from traffic load tracking");
                            $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedLoadTrack} = "false";
                        }
                    } else {
                        if ("${ifNameReadable}" eq "$IncludeString" or "$IncludeString" eq "ALL") {
                            logger(1, "++ include ($IncludeString) interface \"$ifNameReadable\" from traffic load tracking");
                            $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedLoadTrack} = "false";
                        }
                    }
                }
            }
        } else {
            $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedLoadTrack} = "true";
        }

        #----- Includes or excludes interfaces from property change tracking -----#

        # For the interfaces included (for which the traffic load is tracked), enable property(ies)
        # tracking depending on the exclude and/or include property tracking port list
        if ($grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedTrack} eq "false") {

            # Process the interface exclusion list
            for my $ExcludeString (@$ExcludePropertyTrackList) {
                if ($ghOptions{regexp}) {
                    if ($ghOptions{'alias'} and $ghOptions{'alias-matching'}) {
                        if ("${ifNameReadable}" =~ /$ExcludeString/i or "${ifAliasReadable}" =~ /$ExcludeString/i or "$ExcludeString" eq "ALL") {
                            logger(1, "-- exclude ($ExcludeString) interface \"$ifNameReadable\" (Alias: \"$ifAliasReadable\") from property change tracking");
                            $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedPropertyTrack} = "true";
                        }
                    } else {
                        if ("${ifNameReadable}" =~ /$ExcludeString/i or "$ExcludeString" eq "ALL") {
                            logger(1, "-- exclude ($ExcludeString) interface \"$ifNameReadable\" from property change tracking");
                            $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedPropertyTrack} = "true";
                        }
                    }
                } else {
                    if ($ghOptions{'alias'} and $ghOptions{'alias-matching'}) {
                        if ("${ifNameReadable}" eq "$ExcludeString" or "${ifAliasReadable}" eq "$ExcludeString" or "$ExcludeString" eq "ALL") {
                            logger(1, "-- exclude ($ExcludeString) interface \"$ifNameReadable\" (Alias: \"$ifAliasReadable\") from property change tracking");
                            $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedPropertyTrack} = "true";
                        }
                    } else {
                        if ("${ifNameReadable}" eq "$ExcludeString" or "$ExcludeString" eq "ALL") {
                            logger(1, "-- exclude ($ExcludeString) interface \"$ifNameReadable\" from property change tracking");
                            $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedPropertyTrack} = "true";
                        }
                    }
                }
            }

            # Process the interface inclusion list
            # Inclusions are done after exclusions to be able to include a
            # subset of a group of interfaces which were excluded previously
            for my $IncludeString (@$IncludePropertyTrackList) {
                if ($ghOptions{regexp}) {
                    if ($ghOptions{'alias'} and $ghOptions{'alias-matching'}) {
                        if ("${ifNameReadable}" =~ /$IncludeString/i or "${ifAliasReadable}" =~ /$IncludeString/i or "$IncludeString" eq "ALL") {
                            logger(1, "++ include ($IncludeString) interface \"$ifNameReadable\" (Alias: \"$ifAliasReadable\") from property change tracking");
                            $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedPropertyTrack} = "false";
                        }
                    } else {
                        if ("${ifNameReadable}" =~ /$IncludeString/i or "$IncludeString" eq "ALL") {
                            logger(1, "++ include ($IncludeString) interface \"$ifNameReadable\" from property change tracking");
                            $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedPropertyTrack} = "false";
                        }
                    }
                } else {
                    if ($ghOptions{'alias'} and $ghOptions{'alias-matching'}) {
                        if ("${ifNameReadable}" eq "$IncludeString" or "${ifAliasReadable}" eq "$IncludeString" or "$IncludeString" eq "ALL") {
                            logger(1, "++ include ($IncludeString) interface \"$ifNameReadable\" (Alias: \"$ifAliasReadable\") from property change tracking");
                            $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedPropertyTrack} = "false";
                        }
                    } else {
                        if ("${ifNameReadable}" eq "$IncludeString" or "$IncludeString" eq "ALL") {
                            logger(1, "++ include ($IncludeString) interface \"$ifNameReadable\" from property change tracking");
                            $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedPropertyTrack} = "false";
                        }
                    }
                }
            }
        } else {
            $grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedPropertyTrack} = "true";
        }

    } # for each interface
    return $grefhCurrent;
}

# ------------------------------------------------------------------------
# Calculate_Bps
# ------------------------------------------------------------------------
# Description: calculate rate / bandwidth usage within a specified period
# ------------------------------------------------------------------------
sub Calculate_Bps {

    # $grefaAllIndizes is a indexed and sorted list of all interfaces
    logger(2, "x"x50);
    logger(2, "Load calculations");
    for my $Index (@$grefaAllIndizes) {

        # Get normalized interface name (key for If data structure)
        my $ifName = $grefhCurrent->{MD}->{Map}->{IndexToName}->{$Index};
        logger(2, " ifName: $ifName (index: $Index)");

        # Skip interface if excluded
        if ($grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedTrack} eq "true") {
            logger(2, "  -> excluded interface, skipping");
            next;
        }

        # Skip interface if no load stats
        if (not defined $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{OctetsIn}
            or not defined $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{OctetsOut}) {
                logger(2, "  -> no load statistics, skipping");
                next;
        }

        # ---------- Bandwidth calculation -----------

        my $bpsIn  = $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{OctetsIn} * 8;
        my $bpsOut = $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{OctetsOut} * 8;

        # bandwidth usage in percent of (configured/negotiated) interface speed
        $grefhCurrent->{If}->{$ifName}->{ifLoadExceedIfSpeed} = "false";
        if (defined $grefhCurrent->{If}->{$ifName}->{ifSpeed} and $grefhCurrent->{If}->{$ifName}->{ifSpeed} > 0) {
            my $ifLoadIn  = 100 * $bpsIn  / $grefhCurrent->{If}->{$ifName}->{ifSpeed};
            my $ifLoadOut = 100 * $bpsOut / $grefhCurrent->{If}->{$ifName}->{ifSpeed};
            $grefhCurrent->{If}->{$ifName}->{ifLoadIn}  = sprintf("%.2f", $ifLoadIn);
            $grefhCurrent->{If}->{$ifName}->{ifLoadOut} = sprintf("%.2f", $ifLoadOut);

            # Check abnormal load compared to interface speed
            if ($grefhCurrent->{If}->{$ifName}->{ifLoadIn} > 115 or $grefhCurrent->{If}->{$ifName}->{ifLoadOut} > 115) {
                logger(2, "  -> load exceeds 115% of the interface speed, related alerts and perfdata disabled");
                $grefhCurrent->{If}->{$ifName}->{ifLoadExceedIfSpeed} = "true";
            }

            # check interface utilization in percent
            if ($grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedLoadTrack} eq "false") {
                if ($ifLoadIn > 0 or $ifLoadOut > 0) {
                    if ($grefhCurrent->{If}->{$ifName}->{ifLoadExceedIfSpeed} eq "false") {
                        # just traffic light color codes for the lame
                        if ($ghOptions{'critical-load'} > 0 and ($ifLoadIn > $ghOptions{'critical-load'} or $ifLoadOut > $ghOptions{'critical-load'})) {
                            if ( defined $grefhCurrent->{If}->{$ifName}->{"ifAlias"} and $grefhCurrent->{If}->{$ifName}->{"ifAlias"} ne "" ) {
                                push @{$grefhListOfChanges->{loadcritical}}, trim(denormalize($ifName))." (".trim(denormalize($grefhCurrent->{If}->{$ifName}->{"ifAlias"})).")";
                            } else {
                                push @{$grefhListOfChanges->{loadcritical}}, trim(denormalize($ifName));
                            }
                            $gIfLoadCritCounter++;
                        } elsif ($ghOptions{'warning-load'} > 0 and ($ifLoadIn > $ghOptions{'warning-load'} or $ifLoadOut > $ghOptions{'warning-load'})) {
                            if ( defined $grefhCurrent->{If}->{$ifName}->{"ifAlias"} and $grefhCurrent->{If}->{$ifName}->{"ifAlias"} ne "" ) {
                                push @{$grefhListOfChanges->{loadwarning}}, trim(denormalize($ifName))." (".trim(denormalize($grefhCurrent->{If}->{$ifName}->{"ifAlias"})).")";
                            } else {
                                push @{$grefhListOfChanges->{loadwarning}}, trim(denormalize($ifName));
                            }
                            $gIfLoadWarnCounter++;
                        }
                    } else {
                        logger(2, "  -> interface load exceeds interface speed, load will be ignored");
                    }
                    $grefhCurrent->{If}->{$ifName}->{ifLoadInOutOfRange} = Colorcode($ifLoadIn, $ghOptions{'warning-load'}, $ghOptions{'critical-load'});
                    $grefhCurrent->{If}->{$ifName}->{ifLoadOutOutOfRange} = Colorcode($ifLoadOut, $ghOptions{'warning-load'}, $ghOptions{'critical-load'});
                }
            }
            
            # Calculate warn, crit & max limits
            $grefhCurrent->{If}->{$ifName}->{bpsWarn} = sprintf("%.0f", $grefhCurrent->{If}->{$ifName}->{ifSpeed} * $ghOptions{'warning-load'} / 100);
            $grefhCurrent->{If}->{$ifName}->{bpsCrit} = sprintf("%.0f", $grefhCurrent->{If}->{$ifName}->{ifSpeed} * $ghOptions{'critical-load'} / 100);
            $grefhCurrent->{If}->{$ifName}->{bpsMax} = sprintf("%.0f", $grefhCurrent->{If}->{$ifName}->{ifSpeed});

        } else {
            $grefhCurrent->{If}->{$ifName}->{ifLoadIn} = 0;
            $grefhCurrent->{If}->{$ifName}->{ifLoadOut} = 0;
            
            # Calculate warn, crit & max limits
            $grefhCurrent->{If}->{$ifName}->{bpsWarn} = '';
            $grefhCurrent->{If}->{$ifName}->{bpsCrit} = '';
            $grefhCurrent->{If}->{$ifName}->{bpsMax} = '';
        }
        logger(2, "  -> speed=".$grefhCurrent->{If}->{$ifName}->{ifSpeed}.", ".
            "loadin=".$grefhCurrent->{If}->{$ifName}->{ifLoadIn}.", ".
            "loadout=".$grefhCurrent->{If}->{$ifName}->{ifLoadOut});

        #print OUT "BandwidthUsageIn=${bpsIn}bps;0;0;0;$grefhCurrent->{If}->{$ifName}->{ifSpeed} ";
        #print OUT "BandwidthUsageOut=${bpsOut}bps;0;0;0;$grefhCurrent->{If}->{$ifName}->{ifSpeed} ";

        $grefhCurrent->{If}->{$ifName}->{bpsIn} = sprintf("%.2f", $bpsIn);
        $grefhCurrent->{If}->{$ifName}->{bpsOut} = sprintf("%.2f", $bpsOut);

        my $SpeedUnitIn='';
        my $SpeedUnitOut='';
        my $bpsInReadable=$bpsIn;
        my $bpsOutReadable=$bpsOut;
        if ($ghOptions{human}) {
            # human readable bandwidth usage in (G/M/K)bits per second
            $SpeedUnitIn=' bps';
            if ($bpsInReadable > 1000000000) {        # in Gbit/s = 1000000000 bit/s
                  $bpsInReadable = $bpsInReadable / 1000000000;
                  $SpeedUnitIn=' Gbps';
            } elsif ($bpsInReadable > 1000000) {      # in Mbit/s = 1000000 bit/s
                  $bpsInReadable = $bpsInReadable / 1000000;
                  $SpeedUnitIn=' Mbps';
            } elsif ($bpsInReadable > 1000) {         # in Kbits = 1000 bit/s
                  $bpsInReadable = $bpsInReadable / 1000;
                  $SpeedUnitIn=' Kbps';
            }

            $SpeedUnitOut=' bps';
            if ($bpsOutReadable > 1000000000) {       # in Gbit/s = 1000000000 bit/s
                  $bpsOutReadable = $bpsOutReadable / 1000000000;
                  $SpeedUnitOut=' Gbps';
            } elsif ($bpsOutReadable > 1000000) {     # in Mbit/s = 1000000 bit/s
                  $bpsOutReadable = $bpsOutReadable / 1000000;
                  $SpeedUnitOut=' Mbps';
            } elsif ($bpsOutReadable > 1000) {        # in Kbit/s = 1000 bit/s
                  $bpsOutReadable = $bpsOutReadable / 1000;
                  $SpeedUnitOut=' Kbps';
            }

            $grefhCurrent->{If}->{$ifName}->{bpsInReadable} = sprintf("%.2f$SpeedUnitIn", $bpsInReadable);
            $grefhCurrent->{If}->{$ifName}->{bpsOutReadable} = sprintf("%.2f$SpeedUnitOut", $bpsOutReadable);
        }

        # ---------- Last traffic calculation -----------

        # remember last traffic time
        if ($bpsIn > 0 or $bpsOut > 0) { # there is traffic now, remember it
            $grefhCurrent->{MD}->{If}->{$ifName}->{LastTraffic} = $STARTTIME;
            #logger(1, "setze neuen wert!!! LastTraffic: ", $STARTTIME);
        } elsif (not defined $grefhFile->{MD}->{If}->{$ifName}->{LastTraffic}) {
            #if ($gInitialRun) {
            #    # initialize on the first run
            #    $grefhCurrent->{MD}->{If}->{$ifName}->{LastTraffic} = $STARTTIME;
            #} else {
                $grefhCurrent->{MD}->{If}->{$ifName}->{LastTraffic} = 0;
            #}
            #logger(1, "grefhCurrent->{MD}->{If}->{$ifName}->{LastTraffic}: not defined");
        } else { # no traffic now, dont forget the old value
            $grefhCurrent->{MD}->{If}->{$ifName}->{LastTraffic} = $grefhFile->{MD}->{If}->{$ifName}->{LastTraffic};
            #$grefhCurrent->{MD}->{If}->{$ifName}->{LastTraffic} = $STARTTIME;
            #logger(1, "merke alten wert!!! LastTraffic: ", $grefhFile->{MD}->{If}->{$ifName}->{LastTraffic});
        }
        # Set LastTrafficInfo to this Format "0d 0h 43m" and compare the critical and warning levels for "unused interface"
        ($grefhCurrent->{If}->{$ifName}->{ifLastTraffic}, my $LastTrafficStatus) =
            TimeDiff ($grefhCurrent->{MD}->{If}->{$ifName}->{LastTraffic}, $STARTTIME,
                $ghOptions{lasttrafficwarn}, $ghOptions{lasttrafficcrit});

        # ---------- Last traffic calculation -----------

        # ifUsage variable:
        #   * -1  -> interface used, unknown last traffic
        #   * 0   -> interface used, last traffic is < crit duration
        #   * 1   -> interface unused, last traffic is >= crit duration

        logger(2, "Last traffic calculation");
        if ($LastTrafficStatus == $ERRORS{'CRITICAL'}) {
            logger(2, "  -> interface unused, last traffic is >= crit duration");
            # this means "no traffic seen during the last LastTrafficCrit seconds"
            $grefhCurrent->{If}->{$ifName}->{ifLastTrafficOutOfRange} = "red";
            $grefhCurrent->{If}->{$ifName}->{ifUsage} = 1; # interface unused
        } elsif ($LastTrafficStatus == $ERRORS{'WARNING'}) {
            logger(2, "  -> interface used, last traffic is < crit duration");
            # this means "no traffic seen during the last LastTrafficWarn seconds"
            $grefhCurrent->{If}->{$ifName}->{ifLastTrafficOutOfRange} = "yellow";
            $grefhCurrent->{If}->{$ifName}->{ifUsage} = 0; # interface used
        } elsif ($LastTrafficStatus == $ERRORS{'UNKNOWN'}) {
            logger(2, "  -> interface used, unknown last traffic");
            # this means "no traffic seen during the last LastTrafficWarn seconds"
            $grefhCurrent->{If}->{$ifName}->{ifLastTrafficOutOfRange} = "orange";
            $grefhCurrent->{If}->{$ifName}->{ifUsage} = -1; # interface unused
        } else {
            logger(2, "  -> interface used, last traffic is < crit duration");
            # this means "there is traffic on the interface during the last LastTrafficWarn seconds"
            $grefhCurrent->{If}->{$ifName}->{ifUsage} = 0; # interface used
        }
        Calculate_LastTraffic ($ifName, $grefhCurrent->{If}->{$ifName}->{ifUsage});

    }
    logger(2, "x"x50);
    #logger(5, "grefhCurrent: " . Dumper ($grefhCurrent));
    #logger(5, "grefhFile: " . Dumper ($grefhFile));
    #logger(5, "grefhCurrent: " . Dumper ($grefhCurrent->{If}));
    #logger(5, "grefhFile: " . Dumper ($grefhFile->{If}));

    return 0;
}

# ------------------------------------------------------------------------
# Calculate_Error_Discard
# ------------------------------------------------------------------------
# Description: evaluate packet errors and discards within a specified period
# ------------------------------------------------------------------------
sub Calculate_Error_Discard {
    
    # $grefaAllIndizes is a indexed and sorted list of all interfaces
    logger(2, "x"x50);
    logger(2, "Packet errors and discards calculations");
    for my $Index (@$grefaAllIndizes) {

        # Get normalized interface name (key for If data structure)
        my $ifName = $grefhCurrent->{MD}->{Map}->{IndexToName}->{$Index};
        logger(2, " ifName: $ifName (index: $Index)");

        # Skip interface if excluded
        if ($grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedTrack} eq "true") {
            logger(2, "  -> excluded interface, skipping");
            next;
        }

        # Skip interface if no pkts stats
        if (not defined $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsInErr}
            or not defined $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsOutErr}
            or not defined $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsInDiscard}
            or not defined $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsOutDiscard}) {
                logger(2, "  -> no pkts statistics, skipping");
                next;
        }
        
        # ---------- Bandwidth calculation -----------
        
        my $ppsErrIn      = $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsInErr};
        my $ppsErrOut     = $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsOutErr};
        my $ppsDiscardIn  = $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsInDiscard};
        my $ppsDiscardOut = $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsOutDiscard};

        # compare against thresholds
        my $pwarn = 0;
        my $pcrit = 0;
        if ($grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedLoadTrack} eq "false" and ($ppsErrIn > 0 or $ppsErrOut > 0)) {
            # just traffic light color codes for the lame
            if ($ghOptions{'critical-pkterr'} >= 0 and ($ppsErrIn > $ghOptions{'critical-pkterr'} or $ppsErrOut > $ghOptions{'critical-pkterr'})) {
                if ( defined $grefhCurrent->{If}->{$ifName}->{"ifAlias"} and $grefhCurrent->{If}->{$ifName}->{"ifAlias"} ne "" ) {
                    push @{$grefhListOfChanges->{'critical-pkterr'}}, trim(denormalize($ifName))." (".trim(denormalize($grefhCurrent->{If}->{$ifName}->{"ifAlias"})).")";
                } else {
                    push @{$grefhListOfChanges->{'critical-pkterr'}}, trim(denormalize($ifName));
                }
                $gPktErrCritCounter++;
                $pcrit++;
            } elsif ($ghOptions{'warning-pkterr'} >= 0 and ($ppsErrIn > $ghOptions{'warning-pkterr'} or $ppsErrOut > $ghOptions{'warning-pkterr'})) {
                if ( defined $grefhCurrent->{If}->{$ifName}->{"ifAlias"} and $grefhCurrent->{If}->{$ifName}->{"ifAlias"} ne "" ) {
                    push @{$grefhListOfChanges->{'warning-pkterr'}}, trim(denormalize($ifName))." (".trim(denormalize($grefhCurrent->{If}->{$ifName}->{"ifAlias"})).")";
                } else {
                    push @{$grefhListOfChanges->{'warning-pkterr'}}, trim(denormalize($ifName));
                }
                $gPktErrWarnCounter++;
                $pwarn++;
            }
        }
        if ($grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedLoadTrack} eq "false" and ($ppsDiscardIn > 0 or $ppsDiscardOut > 0)) {
            # just traffic light color codes for the lame
            if ($ghOptions{'critical-pktdiscard'} >= 0 and ($ppsDiscardIn > $ghOptions{'critical-pktdiscard'} or $ppsDiscardOut > $ghOptions{'critical-pktdiscard'})) {
                if ( defined $grefhCurrent->{If}->{$ifName}->{"ifAlias"} and $grefhCurrent->{If}->{$ifName}->{"ifAlias"} ne "" ) {
                    push @{$grefhListOfChanges->{'critical-pktdiscard'}}, trim(denormalize($ifName))." (".trim(denormalize($grefhCurrent->{If}->{$ifName}->{"ifAlias"})).")";
                } else {
                    push @{$grefhListOfChanges->{'critical-pktdiscard'}}, trim(denormalize($ifName));
                }
                $gPktDiscardCritCounter++;
                $pcrit++;
            } elsif ($ghOptions{'warning-pktdiscard'} >= 0 and ($ppsDiscardIn > $ghOptions{'warning-pktdiscard'} or $ppsDiscardOut > $ghOptions{'warning-pktdiscard'})) {
                if ( defined $grefhCurrent->{If}->{$ifName}->{"ifAlias"} and $grefhCurrent->{If}->{$ifName}->{"ifAlias"} ne "" ) {
                    push @{$grefhListOfChanges->{'warning-pktdiscard'}}, trim(denormalize($ifName))." (".trim(denormalize($grefhCurrent->{If}->{$ifName}->{"ifAlias"})).")";
                } else {
                    push @{$grefhListOfChanges->{'warning-pktdiscard'}}, trim(denormalize($ifName));
                }
                $gPktDiscardWarnCounter++;
                $pwarn++;
            }
        }
        # totals field
        $grefhCurrent->{If}->{$ifName}->{pktErrDiscard} = sprintf("%.1f/%.1f/%.1f/%.1f", $ppsErrIn, $ppsErrOut, $ppsDiscardIn, $ppsDiscardOut);
        if ($pcrit > 0) {
            $grefhCurrent->{If}->{$ifName}->{pktErrDiscardOutOfRange} = 'red';
        } elsif ($pwarn > 0) {
            $grefhCurrent->{If}->{$ifName}->{pktErrDiscardOutOfRange} = 'yellow';
        }
    }
    logger(2, "x"x50);

    return 0;
}

# ------------------------------------------------------------------------
# Calculate_Packets
# ------------------------------------------------------------------------
# Description: evaluate packet load within a specified period
# ------------------------------------------------------------------------
sub Calculate_Packets {
    
    # $grefaAllIndizes is a indexed and sorted list of all interfaces
    logger(2, "x"x50);
    logger(2, "Packet load calculations");
    for my $Index (@$grefaAllIndizes) {

        # Get normalized interface name (key for If data structure)
        my $ifName = $grefhCurrent->{MD}->{Map}->{IndexToName}->{$Index};
        logger(2, " ifName: $ifName (index: $Index)");

        # Skip interface if excluded
        if ($grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedTrack} eq "true") {
            logger(2, "  -> excluded interface, skipping");
            next;
        }

        # Skip interface if no pkts stats
        if (not defined $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsInUcast}
            or not defined $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsOutUcast}
            or not defined $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsInNUcast}
            or not defined $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsOutNUcast}) {
                logger(2, "  -> no pkts statistics, skipping");
                next;
        }
        
        # ---------- Bandwidth calculation -----------
        
        my $ppsUcastIn   = $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsInUcast};
        my $ppsUcastOut  = $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsOutUcast};
        my $ppsNUcastIn  = $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsInNUcast};
        my $ppsNUcastOut = $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsOutNUcast};

        # totals field
        $grefhCurrent->{If}->{$ifName}->{pktUcastNUcast} = sprintf("%.0f/%.0f/%.0f/%.0f", $ppsUcastIn, $ppsUcastOut, $ppsNUcastIn, $ppsNUcastOut);

    }
    logger(2, "x"x50);

    return 0;
}

# ------------------------------------------------------------------------
# Calculate_LastTraffic
# ------------------------------------------------------------------------
#  * arg 1: name (ifName) of the interface
#  * arg 2: free???
#     . -1  -> interface used, unknown last traffic
#     . 0   -> interface used, last traffic is < crit duration
#     . 1   -> interface unused, last traffic is >= crit duration
# ------------------------------------------------------------------------
sub Calculate_LastTraffic {
    my ($ifName, $free) = @_;

    if ($grefhCurrent->{If}->{"$ifName"}->{ifSpeed}) {
        # Interface has a speed property, that can be a physical interface

        if ($ifName =~ /Ethernet(\d+)Q2F(\d+)Q2F(\d+)/) {
            # we look for ethernet ports (and decide if it is a stacked switch), x/x/x format
            if (not defined $gInterfacesWithoutTrunk->{"$1/$2/$3"}) {
                $gInterfacesWithoutTrunk->{"$1/$2/$3"} = $free;
                $gNumberOfInterfacesWithoutTrunk++;
                # look for free ports with admin status up
                if ($free and defined $grefhCurrent->{If}->{"$ifName"}->{ifAdminStatus} and $grefhCurrent->{If}->{"$ifName"}->{ifAdminStatus} eq 'up') {
                    $grefhCurrent->{If}->{$ifName}->{ifLastTrafficOutOfRange} = "yellow";
                    $gNumberOfFreeUpInterfaces++;
                }
                if ($free and defined $grefhCurrent->{If}->{"$ifName"}->{ifEnabled} and $grefhCurrent->{If}->{"$ifName"}->{ifEnabled} eq 'true') {
                    $grefhCurrent->{If}->{$ifName}->{ifLastTrafficOutOfRange} = "yellow";
                    $gNumberOfFreeUpInterfaces++;
                }
            }
        } elsif ($ifName =~ /Ethernet(\d+)Q2F(\d+)/) {
            # we look for ethernet ports (and decide if it is a stacked switch), x/x format
            if (not defined $gInterfacesWithoutTrunk->{"$1/$2"}) {
                $gInterfacesWithoutTrunk->{"$1/$2"} = $free;
                $gNumberOfInterfacesWithoutTrunk++;
                # look for free ports with admin status up
                if ($free and defined $grefhCurrent->{If}->{"$ifName"}->{ifAdminStatus} and $grefhCurrent->{If}->{"$ifName"}->{ifAdminStatus} eq 'up') {
                    $grefhCurrent->{If}->{$ifName}->{ifLastTrafficOutOfRange} = "yellow";
                    $gNumberOfFreeUpInterfaces++;
                }
                if ($free and defined $grefhCurrent->{If}->{"$ifName"}->{ifEnabled} and $grefhCurrent->{If}->{"$ifName"}->{ifEnabled} eq 'true') {
                    $grefhCurrent->{If}->{$ifName}->{ifLastTrafficOutOfRange} = "yellow";
                    $gNumberOfFreeUpInterfaces++;
                }
            }
        } elsif (not $ifName =~ /^vif|Loopback|^lo/i) {
            # we look for all interfaces having speed property but not looking like a virtual interface
            if (not defined $gInterfacesWithoutTrunk->{"$ifName"}) {
                $gInterfacesWithoutTrunk->{"$ifName"} = $free;
                $gNumberOfInterfacesWithoutTrunk++;
                # look for free ports with admin status up
                if ($free and defined $grefhCurrent->{If}->{"$ifName"}->{ifAdminStatus} and $grefhCurrent->{If}->{"$ifName"}->{ifAdminStatus} eq 'up') {
                    $grefhCurrent->{If}->{$ifName}->{ifLastTrafficOutOfRange} = "yellow";
                    $gNumberOfFreeUpInterfaces++;
                }
                if ($free and defined $grefhCurrent->{If}->{"$ifName"}->{ifEnabled} and $grefhCurrent->{If}->{"$ifName"}->{ifEnabled} eq 'true') {
                    $grefhCurrent->{If}->{$ifName}->{ifLastTrafficOutOfRange} = "yellow";
                    $gNumberOfFreeUpInterfaces++;
                }
            }
        }
    }
    logger(1, "ifName: $ifName\tFreeUp: $gNumberOfFreeUpInterfaces\tWithoutTrunk: $gNumberOfInterfacesWithoutTrunk\tSpeed: ".
        $grefhCurrent->{If}->{"$ifName"}->{ifSpeed});
}


# oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
# NODETYPE SPECIFIC FUNCTIONS
# oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

# ------------------------------------------------------------------------
# Get_Vlan_Cisco
# ------------------------------------------------------------------------
# Description: walk through each interface and read vlan info
# ------------------------------------------------------------------------
sub Get_Vlan_Cisco {

    my $refhOID = shift;
    my $refhSNMPResult;

    # get if vlan table
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOID->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 0));
        $refhSNMPResult = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOID ])) if ($@);

    # Get info from snmp/cache
    #------------------------------------------

    # Example of refhSNMPResult info:
    #  172.31.99.76 15
    #  193.83.153.254 29
    while ( my ($Index,$Vlan) = each(%$refhSNMPResult) ) {

        #Check that the index match a known interface. skip if not
        next unless (defined $grefhCurrent->{MD}->{Map}->{IndexToName}->{"$Index"});

        # get the interface ifName stored before from the index table
        my $ifName = $grefhCurrent->{MD}->{Map}->{IndexToName}->{"$Index"};
        logger(2, "IfName=\"$ifName\", Vlan=\"$Vlan\"");
        
        # separate multiple IP Adresses with a blank
        # blank is good because the WEB browser can break lines
        $grefhCurrent->{If}->{"$ifName"}->{ifVlanNames} .= ", " if ($grefhCurrent->{If}->{"$ifName"}->{ifVlanNames});

        # add the vlan as property of the interface
        $grefhCurrent->{If}->{"$ifName"}->{ifVlanNames} .= $Vlan;
    }
    return 0;
}

# ------------------------------------------------------------------------
# Get_Vlan_Hp
# ------------------------------------------------------------------------
# Description: walk through each interface and read vlan info
# ------------------------------------------------------------------------
sub Get_Vlan_Hp {

    my $refhOIDVlanName = shift;#oid_ifVlanName
    my $refhOIDPVlanPort = shift;#oid_hp_ifVlanPort
    my $refhSNMPResultVlanName;
    my $refhSNMPResultHPVlanPort;

    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDVlanName->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 0));
        $refhSNMPResultVlanName = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDVlanName ])) if ($@);

    foreach my $idx ( keys %$refhSNMPResultVlanName ) {
        chomp($refhSNMPResultVlanName->{$idx});
        $refhSNMPResultVlanName->{$idx} =~ tr/"<>/'../; #"
    }

    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDPVlanPort->{'oid'}"], cachetimer => 0, outputhashkeyidx => 0, checkempty => 0));
        $refhSNMPResultHPVlanPort = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDPVlanPort ])) if ($@);

    if (defined $refhSNMPResultHPVlanPort and %$refhSNMPResultHPVlanPort) {
        foreach my $oid ( keys %$refhSNMPResultHPVlanPort ) {
            chomp($refhSNMPResultHPVlanPort->{$oid});
            my @oids = split('\.', $oid);
            my $vlan = $oids[-2];
            
            # store ifVlanNames
            if((defined $grefhCurrent->{MD}->{Map}->{IndexToName}->{$refhSNMPResultHPVlanPort->{$oid}})
              and ( $grefhCurrent->{MD}->{Map}->{IndexToName}->{$refhSNMPResultHPVlanPort->{$oid}} ne '')) {
                my $ifName = $grefhCurrent->{MD}->{Map}->{IndexToName}->{$refhSNMPResultHPVlanPort->{$oid}};
                $grefhCurrent->{If}->{"$ifName"}->{ifVlanNames} = '' unless (defined $grefhCurrent->{If}->{"$ifName"}->{ifVlanNames});
                $grefhCurrent->{If}->{"$ifName"}->{ifVlanNames} .= $refhSNMPResultVlanName->{"$vlan"}. " ";
                logger(2, "IfName=\"$ifName\", Vlan=\"".$grefhCurrent->{If}->{"$ifName"}->{ifVlanNames}."\"");
            }
        }
    }

    return 0;
}

# ------------------------------------------------------------------------
# Get_Vlan_Nortel
# ------------------------------------------------------------------------
# Description: walk through each interface and read vlan info
# ------------------------------------------------------------------------
sub Get_Vlan_Nortel {

    my $refhOID = shift;
    my $refhSNMPResult;       # Lines returned from snmpwalk storing ifAdminStatus

    # get all interface adminstatus - no caching !
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOID->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 0));
        $refhSNMPResult = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOID ])) if ($@);
    # Example (to verify)
    #   1 => "00 01 00 04 00 05 00 06 00 0C",
    #   2 => "00 01 00 0C",
    #   3 => "00 01 00 02 00 05 00 06 00 07 00 08 00 0B 00 0C",
    
    # loop through all found interfaces
    for my $ifName (keys %{$grefhCurrent->{If}}) {
        # Extract the index out of the MetaData
        my $Index = $grefhCurrent->{MD}->{Map}->{NameToIndex}->{"$ifName"};
        if (defined $refhSNMPResult->{$Index}) {
            my @VlanIdsArray = split(' ', $refhSNMPResult->{$Index});
            # Convert HEX-String to number
            my $VlanIdsString = "";
            for my $i (0 .. $#VlanIdsArray) {
                $VlanIdsString .= ', ' if ($VlanIdsString);
                my $num = 0;
                map { $num *= 16; $num += $convhex2dec{$_}; } split //, "${VlanIdsArray[$i]}${VlanIdsArray[++$i]}";
                $VlanIdsString .= "$num";
            }
            # Store the vlan list
            $grefhCurrent->{If}->{"$ifName"}->{ifVlanNames} = "$VlanIdsString";
            logger(2, "Index=$Index ($ifName): VlanIds=\"$VlanIdsString\"");
        } else {
            #$grefhCurrent->{If}->{"$ifName"}->{ifVlanNames} = undef;
            logger(2, "Index=$Index ($ifName): VlanIds not found for the interface");
        }
    }
    return 0;
}

# ------------------------------------------------------------------------------
# Get_InterfaceNames_Bigip
# ------------------------------------------------------------------------------
# Description:
# This function gather interface indexes, descriptions, and mac addresses, to
# generate unique and reformatted interface names. Interface names are the identifiant
# to retrieve any interface related information.
# This function also push to the grefhCurrent hash:
# - Some if info:
#  * name
#  * index
#  * mac address
# - Some map relations:
#  * name to index
#  * index to name
#  * name to description
# ------------------------------------------------------------------------------
# Function call:
#  Get_InterfaceNames_Bigip();
# Arguments:
#  None
# Output:
#  None
# ------------------------------------------------------------------------------
sub Get_InterfaceNames_Bigip {

    my $refhSNMPResultIfDescr;
    my $refhSNMPResultIfPhysAddress;
    my $refhIfDescriptionCounts = {};   # For duplicates counting
    my $refhIfPhysAddressCounts = {};   # For duplicates counting
    my $refhIfPhysAddressIndex  = {};   # To map the physical address to the index.
                                        # Used only when appending the mac address to the interface description
    my $Name = "";                      # Name of the interface. Formatted to be unique, based on interface description
                                        # and index / mac address

    # Get info from snmp
    #------------------------------------------

    # get all interface descriptions
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$oid_bigip_sysInterfaceName{'oid'}"], cachetimer => 0, outputhashkeyidx => 0, checkempty => 1));
        $refhSNMPResultIfDescr = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_bigip_sysInterfaceName ])) if ($@);

    # get all interface mac addresses
    my %hOptions = ($ghOptions{'usemacaddr'}) ? ( %ghSNMPOptions, (oids => ["$oid_bigip_sysInterfaceMacAddr{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 0))
        : ( %ghSNMPOptions, (oids => ["$oid_bigip_sysInterfaceMacAddr{'oid'}"], cachetimer => $gLongCacheTimer, outputhashkeyidx => 1, checkempty => 0));
    $refhSNMPResultIfPhysAddress = GetTableDataWithSnmp (\%hOptions);

    # Look for duplicate values
    #------------------------------------------

    # Find interface description duplicates
    for my $value ( values %$refhSNMPResultIfDescr ) {
        $refhIfDescriptionCounts->{"$value"} = 0 unless(defined $refhIfDescriptionCounts->{"$value"});
        $refhIfDescriptionCounts->{"$value"}++;
    }

    # Find physical address duplicates
    for my $value ( values %$refhSNMPResultIfPhysAddress ) {
        $refhIfPhysAddressCounts->{"$value"} = 0 unless(defined $refhIfPhysAddressCounts->{"$value"});
        $refhIfPhysAddressCounts->{"$value"}++;
    }

    #
    #------------------------------------------

    # Example of $refhSNMPResultIfDescr
    #    TOADD
    while ( my ($Index,$Desc) = each(%$refhSNMPResultIfDescr) ) {
        $Index =~ s/^\.*$oid_bigip_sysInterfaceName{'oid'}\.//g; # remove all but the index
        logger(2, "Index=$Index Descr=\"$Desc\" (long cache: $gLongCacheTimer)");
        my $MacAddr = (defined $refhSNMPResultIfPhysAddress->{$Index}) ? "$refhSNMPResultIfPhysAddress->{$Index}" : "";

        # Interface name formatting
        # -----------------------------------------------------------

        my $Name = "$Desc";
        # 1. check an empty interface description
        # this occurs on some devices (e.g. HP procurve switches)
        if ("$Desc" eq "") {
            # Set the name as "Port $index"
            # read the MAC address of the interface - independend if it has one or not
            $Name = "Port $Index";
            logger(2, "  Interface with index $Index has no description.\nName is set to $Name");
        } else {

            # 2. append the index to duplicate interface descriptions. Index is better than mac address as in lots of cases the
            # same mac address can be used for multiples interfaces (if there is a mac address...)
            # Example of nodes in that case: Dell Powerconnect Switches 53xx, 54xx, 60xx and 62xx: same interface name 'Ethernet Interface'
            # However, be sure to fix the interface index (see the node type documentation). If not fixed, this could lead to problems
            # where index is changed during reboot and duplicate interface names
            if ($refhIfDescriptionCounts->{"$Name"} > 1) {
                if ($ghOptions{usemacaddr}) {
                    logger(2, "  Duplicate interface description detected. Option \"usemacaddr\" used, checking mac address unicity...");
                    # check if we got a unique MAC Address associated to the interface
                    if ($refhIfPhysAddressCounts->{"$MacAddr"} < 2) {
                        $Name = "$Name ($MacAddr)";
                        logger(2, "  Mac address is unique. Appending the mac address. Name will be now \"$Name\"");
                    } else {
                        # overwise take the index
                        $Name = "$Desc ($Index)";
                        logger(2, "  Mac address is NOT unique. Appending the index. Name will be now \"$Name\"");
                    }
                } else {
                    $Name = "$Desc ($Index)";
                    logger(2, "  Duplicate interface description detected. Appending the index. Name will be now \"$Name\"");
                }
            }

            # 3. Known long of problematic interface names
            # Detect long name, which may be reduced for a cleaner interface table
            my $name_warning_length = 40;
            if (length($Name) > $name_warning_length) {
                logger(2, "  Interface name quite long! (> $name_warning_length char.). Name: \"$Name\"");
                $grefhCurrent->{MD}->{If}->{$Name}->{MsgWarn} .= "<div class=\"warning\">Interface name quite long! (\> $name_warning_length char.). Name: \"$Name\"";
                #$grefAoHConfigTableData->[8]->[1]->{Value} .= "<div class=\"warning\">Interface name quite long! (\> $name_warning_length char.). Name: \"$Name\"<br>";
            }
        }

        logger(2, "  ifName=\"$Name\" (normalized: \"".normalize ($Name)."\")");

        # normalize the interface name and description to not get into trouble
        # with special characters and how Config::General handles blanks
        $Name = normalize ($Name);
        $Desc = normalize ($Desc);

        # create new trees in the MetaData hash & the Interface hash, which
        # store interface index, description and mac address.
        # This is used later for displaying the html table
        $grefhCurrent->{MD}->{Map}->{NameToIndex}->{"$Name"} = "$Index";
        $grefhCurrent->{MD}->{Map}->{NameToDescr}->{"$Name"} = "$Desc";
        $grefhCurrent->{MD}->{Map}->{DescrToName}->{"$Desc"} = "$Name";
        $grefhCurrent->{MD}->{Map}->{IndexToName}->{"$Index"} = "$Name";
        $grefhCurrent->{If}->{$Name}->{index} = "$Index";
        $grefhCurrent->{If}->{$Name}->{ifName} = "$Name";
        $grefhCurrent->{If}->{$Name}->{ifDescr} = "$Desc";
        $grefhCurrent->{If}->{$Name}->{ifMacAddr} = "$MacAddr";

    }
    return 0;
}

# ------------------------------------------------------------------------
# Get_InterfaceEnabled_Bigip
# ------------------------------------------------------------------------
# BIGIP : get ifEnabled
# ------------------------------------------------------------------------
sub Get_InterfaceEnabled_Bigip {

    my $refhOID = shift;;
    my $refhSNMPResult;    # Lines returned from snmpwalk storing sysInterfaceEnabled

    # get all interface enabled info - no caching !
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOID->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResult = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOID ])) if ($@);

    # loop through all found interfaces
    for my $ifName (keys %{$grefhCurrent->{If}}) {
        # Extract the index out of the MetaData
        my $Index = $grefhCurrent->{MD}->{Map}->{NameToIndex}->{"$ifName"};
        if (defined $refhSNMPResult->{$Index}) {
            my $InterfaceEnabled = $refhSNMPResult->{$Index};
            # Store ifEnabled converted from a digit to "true" or "false"
            $grefhCurrent->{If}->{"$ifName"}->{ifEnabledNumber} = "$InterfaceEnabled";
            $grefhCurrent->{If}->{"$ifName"}->{ifEnabled} = (defined $refhOID->{'convertToReadable'}->{"$InterfaceEnabled"})
                ? $refhOID->{'convertToReadable'}->{"$InterfaceEnabled"} : "$InterfaceEnabled";
            logger(2, "Index=$Index ($ifName): InterfaceEnabled=".$grefhCurrent->{If}->{"$ifName"}->{ifEnabled});
        } else {
            #$grefhCurrent->{If}->{"$ifName"}->{ifEnabledNumber} = undef;
            #$grefhCurrent->{If}->{"$ifName"}->{ifEnabled} = undef;
            logger(2, "Index=$Index ($ifName): InterfaceEnabled not found for the interface");
        }
    }
    return 0;
}

# ------------------------------------------------------------------------
# Get_InterfaceStatus_Bigip
# ------------------------------------------------------------------------
# BIGIP : get ifStatus
# ------------------------------------------------------------------------
sub Get_InterfaceStatus_Bigip {

    my $refhOID = shift;
    my $refhSNMPResult;    # Lines returned from snmpwalk storing Interface Status

    # get all interface status - no caching !
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOID->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResult = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOID ])) if ($@);

    # Example TODO
    for my $ifName (keys %{$grefhCurrent->{If}}) {
        # Extract the index out of the MetaData
        my $Index = $grefhCurrent->{MD}->{Map}->{NameToIndex}->{"$ifName"};

        if (defined $refhSNMPResult->{$Index}) {
            my $ifStatusNow = $refhSNMPResult->{$Index};
            # Store the oper status as property of the current interface
            $grefhCurrent->{If}->{"$ifName"}->{ifStatusNumber} = "$ifStatusNow";
            defined $refhOID->{'convertToReadable'}->{"$ifStatusNow"} and $ifStatusNow = $refhOID->{'convertToReadable'}->{"$ifStatusNow"};
            $grefhCurrent->{If}->{"$ifName"}->{ifStatus} = "$ifStatusNow";

            # Retrieve interface enabled state for special rules
            my $ifEnabledNow = $grefhCurrent->{If}->{"$ifName"}->{ifEnabled};

            #
            # Store a CacheTimer (seconds) where we cache the next
            # reads from the net - we have the following possibilities
            #
            # InterfaceStatus:
            #
            # Current state | first state  |  CacheTimer
            # -----------------------------------------
            # up              up              $gShortCacheTimer
            # up              down            0
            # down            down            $gLongCacheTimer
            # down            up              0
            # other           *               0
            # *               other           0
            #
            # One exception to that logic is the "Changed" flag. If this
            # is set we detected a change on an interface property and do not
            # cache !
            #
            my $ifStatusFile = $grefhFile->{If}->{"$ifName"}->{ifStatus};
            $ifStatusFile = "" unless ($ifStatusFile);
            # set cache timer for further reads
            if ("$ifStatusNow" eq "up" and "$ifStatusFile" eq "up") {
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{CacheTimer} = $gShortCacheTimer;
            } elsif ("$ifStatusNow" eq "down" and "$ifStatusFile" eq "down") {
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{CacheTimer} = $gLongCacheTimer;
            } else {
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{CacheTimer} = 0;
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifStatusChangeText} =
                    "Old = \"$ifStatusFile\", Current = \"$ifStatusNow\" ";
            }
            logger(2, "Index=$Index ($ifName): InterfaceStatus was \"$ifStatusFile\" and is now \"$ifStatusNow\" (cachetimer=".$grefhCurrent->{MD}->{If}->{"$ifName"}->{CacheTimer}.")");

            # remember change time of the interface property
            if ($grefhFile->{MD}->{If}->{"$ifName"}->{ifStatusChangeTime}) {
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifStatusChangeTime} =
                    $grefhFile->{MD}->{If}->{"$ifName"}->{ifStatusChangeTime}
            } else {
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifStatusChangeTime} = time;
            }

            #
            # Some rules with ifStatus
            #
            # Between initial ifStatus and current ifStatus
            # current ifStatus | initial ifStatus | action
            # ---------------------------------------------------------------------
            # up                   | *                    | no alarm and update ifStatus initial state
            # *                    | empty                | no alarm and update ifStatus initial state
            #
            # Between current ifOperStatus and current ifAdminStatus
            # current ifOperStatus | current ifAdminStatus | action
            # ---------------------------------------------------------------------
            # down,disabled        | false                 | no alarm and update ifOperStatus initial state
            #

            # track changes of the interface status
            if ("$ifStatusNow" eq "$ifStatusFile") {   # no changes to its first state
                # delete the changed flag and reset the time when it was changed
                if ($grefhFile->{MD}->{If}->{"$ifName"}->{ifStatusChangeText}) {
                    delete $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifStatusChangeText};
                    $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifStatusChangeTime} = time;
                }
            }
            # ifStatus has changed to up, no alert
            elsif ("$ifStatusNow" eq "up") {
                # update the state in the status file
                $grefhFile->{If}->{"$ifName"}->{ifStatus} = "$ifStatusNow";
                # delete the changed flag and reset the time when it was changed
                if ($grefhFile->{MD}->{If}->{"$ifName"}->{ifStatusChangeText}) {
                    delete $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifStatusChangeText};
                    $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifStatusChangeTime} = time;
                }
                logger(3, "  InterfaceStatus specific rules: ifStatus has changed to up, no alert");
            }
            # ifStatus has changed from 'empty', no alert
            elsif ("$ifStatusFile" eq "") {
                # update the state in the status file
                $grefhFile->{If}->{"$ifName"}->{ifStatus} = "$ifStatusNow";
                # delete the changed flag and reset the time when it was changed
                if ($grefhFile->{MD}->{If}->{"$ifName"}->{ifStatusChangeText}) {
                    delete $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifStatusChangeText};
                    $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifStatusChangeTime} = time;
                }
                logger(3, "  InterfaceStatus specific rules: ifStatus has changed from 'empty', no alert");
            }
            # ifStatus has changed to 'down' or 'disabled' and ifEnabled is 'false', no alert
            elsif (("$ifStatusNow" eq "down" or "$ifStatusNow" eq "disabled") and "$ifEnabledNow" eq "false") {
                # update the state in the status file
                $grefhFile->{If}->{"$ifName"}->{ifStatus} = "$ifStatusNow";
                # delete the changed flag and reset the time when it was changed
                if ($grefhFile->{MD}->{If}->{"$ifName"}->{ifStatusChangeText}) {
                    delete $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifStatusChangeText};
                    $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifStatusChangeTime} = time;
                }
                logger(3, "  InterfaceStatus specific rules: ifStatus has changed to 'down' or 'disabled' and ifEnabled is 'false', no alert");
            }
            # ifStatus has changed, alerting
            else {
                # flag if changes already tracked
                if (not $grefhFile->{MD}->{If}->{"$ifName"}->{ifStatusChangeText}) {
                    $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifStatusChangeTime} = time;
                }

                # remember the change every run of this program, this is useful if the
                # ifStatus changes from "up" to "testing" to "down"
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifStatusChangeText} =
                    "Old = \"$ifStatusFile\", Current = \"$ifStatusNow\" ";
            }
        } else {
            #$grefhCurrent->{If}->{"$ifName"}->{ifStatusNumber} = undef;
            #$grefhCurrent->{If}->{"$ifName"}->{ifStatus} = undef;
            logger(2, "Index=$Index ($ifName): InterfaceStatus not found for the interface");
        }

    }
    return 0;
}

# ------------------------------------------------------------------------------
# Get_Error_Drop_Bigip
# ------------------------------------------------------------------------------
# Description: gather interface packet errors/drop
# ------------------------------------------------------------------------------
# Function call:
#  Get_Error_Drop_Bigip();
# Arguments:
#  None
# Output:
#  None
# ------------------------------------------------------------------------------
sub Get_Error_Drop_Bigip {
    my $refhSNMPResultInErrors;    # Lines returned from snmpwalk storing sysInterfaceStatErrorsIn
    my $refhSNMPResultOutErrors;   # Lines returned from snmpwalk storing sysInterfaceStatErrorsOut
    my $refhSNMPResultInDrops;     # Lines returned from snmpwalk storing sysInterfaceStatDropsIn
    my $refhSNMPResultOutDrops;    # Lines returned from snmpwalk storing sysInterfaceStatDropsOut

    # Get info from snmp/cache
    #------------------------------------------

    # get all interface in/out packet error/discarded octet counters - no caching !
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$oid_bigip_sysInterfaceStatErrorsIn{oid}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResultInErrors = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_ifInErrors ])) if ($@);
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$oid_bigip_sysInterfaceStatErrorsOut{oid}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResultOutErrors = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_ifOutErrors ])) if ($@);
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$oid_bigip_sysInterfaceStatDropsIn{oid}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResultInDrops = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_ifInDiscards ])) if ($@);
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$oid_bigip_sysInterfaceStatDropsOut{oid}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResultOutDrops = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_ifOutDiscards ])) if ($@);

    # post-processing interface octet counters
    #------------------------------------------

    Process_IfCounter ($refhSNMPResultInErrors, "PktsInErr", "64");
    Process_IfCounter ($refhSNMPResultOutErrors, "PktsOutErr", "64");
    Process_IfCounter ($refhSNMPResultInDrops, "PktsInDrop", "64");
    Process_IfCounter ($refhSNMPResultOutDrops, "PktsOutDrop", "64");

    return 0;
}

# ------------------------------------------------------------------------
# Calculate_Error_Drop_Bigip
# ------------------------------------------------------------------------
# Description: evaluate packet errors and drops within a specified period
# ------------------------------------------------------------------------
sub Calculate_Error_Drop_Bigip {
    
    # $grefaAllIndizes is a indexed and sorted list of all interfaces
    logger(2, "x"x50);
    logger(2, "Packet errors and drops calculations");
    for my $Index (@$grefaAllIndizes) {

        # Get normalized interface name (key for If data structure)
        my $ifName = $grefhCurrent->{MD}->{Map}->{IndexToName}->{$Index};
        logger(2, " ifName: $ifName (index: $Index)");

        # Skip interface if excluded
        if ($grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedTrack} eq "true") {
            logger(2, "  -> excluded interface, skipping");
            next;
        }

        # Skip interface if no pkts stats
        if (not defined $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsInErr}
            or not defined $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsOutErr}
            or not defined $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsInDrop}
            or not defined $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsOutDrop}) {
                logger(2, "  -> no pkts statistics, skipping");
                next;
        }
        
        # ---------- Bandwidth calculation -----------
        
        my $ppsErrIn   = $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsInErr};
        my $ppsErrOut  = $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsOutErr};
        my $ppsDropIn  = $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsInDrop};
        my $ppsDropOut = $grefhCurrent->{MD}->{IfStats}->{"$ifName"}->{PktsOutDrop};

        # compare against thresholds
        my $pwarn = 0;
        my $pcrit = 0;
        if ($grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedLoadTrack} eq "false" and ($ppsErrIn > 0 or $ppsErrOut > 0)) {
            # just traffic light color codes for the lame
            if ($ghOptions{'critical-pkterr'} >= 0 and ($ppsErrIn > $ghOptions{'critical-pkterr'} or $ppsErrOut > $ghOptions{'critical-pkterr'})) {
                if ( defined $grefhCurrent->{If}->{$ifName}->{"ifAlias"} and $grefhCurrent->{If}->{$ifName}->{"ifAlias"} ne "" ) {
                    push @{$grefhListOfChanges->{'critical-pkterr'}}, trim(denormalize($ifName))." (".trim(denormalize($grefhCurrent->{If}->{$ifName}->{"ifAlias"})).")";
                } else {
                    push @{$grefhListOfChanges->{'critical-pkterr'}}, trim(denormalize($ifName));
                }
                $gPktErrCritCounter++;
                $pcrit++;
            } elsif ($ghOptions{'warning-pkterr'} >= 0 and ($ppsErrIn > $ghOptions{'warning-pkterr'} or $ppsErrOut > $ghOptions{'warning-pkterr'})) {
                if ( defined $grefhCurrent->{If}->{$ifName}->{"ifAlias"} and $grefhCurrent->{If}->{$ifName}->{"ifAlias"} ne "" ) {
                    push @{$grefhListOfChanges->{'warning-pkterr'}}, trim(denormalize($ifName))." (".trim(denormalize($grefhCurrent->{If}->{$ifName}->{"ifAlias"})).")";
                } else {
                    push @{$grefhListOfChanges->{'warning-pkterr'}}, trim(denormalize($ifName));
                }
                $gPktErrWarnCounter++;
                $pwarn++;
            }
        }
        if ($grefhCurrent->{MD}->{If}->{$ifName}->{ExcludedLoadTrack} eq "false" and ($ppsDropIn > 0 or $ppsDropOut > 0)) {
            # just traffic light color codes for the lame
            if ($ghOptions{'critical-pktdrop'} >= 0 and ($ppsDropIn > $ghOptions{'critical-pktdrop'} or $ppsDropOut > $ghOptions{'critical-pktdrop'})) {
                if ( defined $grefhCurrent->{If}->{$ifName}->{"ifAlias"} and $grefhCurrent->{If}->{$ifName}->{"ifAlias"} ne "" ) {
                    push @{$grefhListOfChanges->{'critical-pktdrop'}}, trim(denormalize($ifName))." (".trim(denormalize($grefhCurrent->{If}->{$ifName}->{"ifAlias"})).")";
                } else {
                    push @{$grefhListOfChanges->{'critical-pktdrop'}}, trim(denormalize($ifName));
                }
                $gPktDropCritCounter++;
                $pcrit++;
            } elsif ($ghOptions{'warning-pktdrop'} >= 0 and ($ppsDropIn > $ghOptions{'warning-pktdrop'} or $ppsDropOut > $ghOptions{'warning-pktdrop'})) {
                if ( defined $grefhCurrent->{If}->{$ifName}->{"ifAlias"} and $grefhCurrent->{If}->{$ifName}->{"ifAlias"} ne "" ) {
                    push @{$grefhListOfChanges->{'warning-pktdrop'}}, trim(denormalize($ifName))." (".trim(denormalize($grefhCurrent->{If}->{$ifName}->{"ifAlias"})).")";
                } else {
                    push @{$grefhListOfChanges->{'warning-pktdrop'}}, trim(denormalize($ifName));
                }
                $gPktDropWarnCounter++;
                $pwarn++;
            }
        }
        # totals field
        $grefhCurrent->{If}->{$ifName}->{pktErrDrop} = sprintf("%.1f/%.1f/%.1f/%.1f", $ppsErrIn, $ppsErrOut, $ppsDropIn, $ppsDropOut);
        if ($pcrit > 0) {
            $grefhCurrent->{If}->{$ifName}->{pktErrDropOutOfRange} = 'red';
        } elsif ($pwarn > 0) {
            $grefhCurrent->{If}->{$ifName}->{pktErrDropOutOfRange} = 'yellow';
        }
    }
    logger(2, "x"x50);

    return 0;
}

# ------------------------------------------------------------------------
# get Operational Status on Netscreen
# ------------------------------------------------------------------------
sub Get_OperStatus_Netscreen {

    my $refhOIDOperStatus = shift;
    my $refhSNMPResultOperStatus;       # Lines returned from snmpwalk storing ifOperStatus
    my $NSRPStatus = "$grefhCurrent->{MD}->{Node}->{netscreen_nsrp}"; # result of snmpget on nsrpVsdMemberStatus

    # get all interface oper status - no caching !
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDOperStatus->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResultOperStatus = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDOperStatus ])) if ($@);

    # Example of $refaOperStatusLines
    #    .1.3.6.1.2.1.2.2.1.8.1 up
    #    .1.3.6.1.2.1.2.2.1.8.2 down
    for my $ifName (keys %{$grefhCurrent->{If}}) {
        # Extract the index out of the MetaData
        my $Index = $grefhCurrent->{MD}->{Map}->{NameToIndex}->{"$ifName"};

        if (defined $refhSNMPResultOperStatus->{$Index}) {
            my $OperStatusNow = $refhSNMPResultOperStatus->{$Index};
            # Store the oper status as property of the current interface
            $grefhCurrent->{If}->{"$ifName"}->{ifOperStatusNumber} = "$OperStatusNow";
            defined $refhOIDOperStatus->{'convertToReadable'}->{"$OperStatusNow"} and $OperStatusNow = $refhOIDOperStatus->{'convertToReadable'}->{"$OperStatusNow"};
            $grefhCurrent->{If}->{"$ifName"}->{ifOperStatus} = "$OperStatusNow";

            # Retrieve adminstatus for special rules
            my $AdminStatusNow = $grefhCurrent->{If}->{"$ifName"}->{ifAdminStatus};

            #
            # Store a CacheTimer (seconds) where we cache the next
            # reads from the net - we have the following possibilities
            #
            # ifOperStatus:
            #
            # Current state | first state  |  CacheTimer
            # -----------------------------------------
            # up              up              $gShortCacheTimer
            # up              down            0
            # down            down            $gLongCacheTimer
            # down            up              0
            # other           *               0
            # *               other           0
            #
            # One exception to that logic is the "Changed" flag. If this
            # is set we detected a change on an interface property and do not
            # cache !
            #
            my $OperStatusFile = $grefhFile->{If}->{"$ifName"}->{ifOperStatus};
            $OperStatusFile = "" unless ($OperStatusFile);
            # set cache timer for further reads
            if ("$OperStatusNow" eq "up" and "$OperStatusFile" eq "up") {
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{CacheTimer} = $gShortCacheTimer;
            } elsif ("$OperStatusNow" eq "down" and "$OperStatusFile" eq "down") {
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{CacheTimer} = $gLongCacheTimer;
            } else {
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{CacheTimer} = 0;
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText} =
                    "Old = \"$OperStatusFile\", Current = \"$OperStatusNow\" ";
            }
            logger(2, "Index=$Index ($ifName): Operstatus was \"$OperStatusFile\" and is now \"$OperStatusNow\" (cachetimer=".$grefhCurrent->{MD}->{If}->{"$ifName"}->{CacheTimer}.")");

            # remember change time of the interface property
            if ($grefhFile->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeTime}) {
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeTime} =
                    $grefhFile->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeTime}
            } else {
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeTime} = time;
            }

            #
            # Some rules with ifOperStatus
            #
            # Between initial ifOperStatus and current ifOperStatus
            # current ifOperStatus | initial ifOperStatus | action
            # ---------------------------------------------------------------------
            # up                   | *                    | no alarm and update ifOperStatus initial state
            # *                    | empty,down           | no alarm and update ifOperStatus initial state
            #
            # Between current ifOperStatus and current ifAdminStatus
            # current ifOperStatus | current ifAdminStatus | action
            # ---------------------------------------------------------------------
            # down                 | *                     | no alarm and update ifOperStatus initial state
            #

            # track changes of the oper status
            if ("$OperStatusNow" eq "$OperStatusFile") {   # no changes to its first state
                # delete the changed flag and reset the time when it was changed
                if ($grefhFile->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText}) {
                    delete $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText};
                    $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeTime} = time;
                }
            }
            # ifOperstatus has changed to up, no alert
            elsif ("$OperStatusNow" eq "up") {
                # update the state in the status file
                $grefhFile->{If}->{"$ifName"}->{ifOperStatus} = "$OperStatusNow";
                # delete the changed flag and reset the time when it was changed
                if ($grefhFile->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText}) {
                    delete $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText};
                    $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeTime} = time;
                }
                logger(3, "  Operstatus specific rules: ifOperstatus has changed to up, no alert");
            }
            # ifOperstatus has changed from 'empty' or 'down', no alert
            elsif ("$OperStatusFile" eq "" or "$OperStatusFile" eq "down") {
                # update the state in the status file
                $grefhFile->{If}->{"$ifName"}->{ifOperStatus} = "$OperStatusNow";
                # delete the changed flag and reset the time when it was changed
                if ($grefhFile->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText}) {
                    delete $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText};
                    $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeTime} = time;
                }
                logger(3, "  Operstatus specific rules: ifOperstatus has changed from 'empty' or 'down', no alert");
            }
            # ifOperstatus has changed to 'down' and ifAdminstatus is 'down', no alert
            elsif ("$OperStatusNow" eq "down" and "$AdminStatusNow" eq "down") {
                # update the state in the status file
                $grefhFile->{If}->{"$ifName"}->{ifOperStatus} = "$OperStatusNow";
                # delete the changed flag and reset the time when it was changed
                if ($grefhFile->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText}) {
                    delete $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText};
                    $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeTime} = time;
                }
                logger(3, "  Operstatus specific rules: ifOperstatus has changed to 'down' and ifAdminstatus is 'down', no alert");
            }
            # ifOperstatus has changed but the node is not the master of the NSRP cluster, no alert
            elsif ("$NSRPStatus" ne "master" or "$NSRPStatus" ne "") {
                # update the state in the status file
                $grefhFile->{If}->{"$ifName"}->{ifOperStatus} = "$OperStatusNow";
                # delete the changed flag and reset the time when it was changed
                if ($grefhFile->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText}) {
                    delete $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText};
                    $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeTime} = time;
                }
                logger(3, "  Operstatus specific rules: ifOperstatus has changed but the node is not the master of the NSRP cluster, no alert");
            }
            # ifOperstatus has changed, alerting
            else {
                # flag if changes already tracked
                if (not $grefhFile->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText}) {
                    $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeTime} = time;
                }

                # remember the change every run of this program, this is useful if the
                # ifOperStatus changes from "up" to "testing" to "down"
                $grefhCurrent->{MD}->{If}->{"$ifName"}->{ifOperStatusChangeText} =
                    "Old = \"$OperStatusFile\", Current = \"$OperStatusNow\" ";
            }
        } else {
            #$grefhCurrent->{If}->{"$ifName"}->{ifOperStatusNumber} = undef;
            #$grefhCurrent->{If}->{"$ifName"}->{ifOperStatus} = undef;
            logger(2, "Index=$Index ($ifName): OperStatus not found for the interface");
        }

    }
    return 0;
}

# ------------------------------------------------------------------------
# Get_IpInfo_Netscreen
# ------------------------------------------------------------------------
sub Get_IpInfo_Netscreen {
    my $refhOIDIfName = shift;
    my $refhOIDIfIp = shift;
    my $refhOIDIfNetmask = shift;
    my $refhSNMPResultIfName;       # Lines returned from snmpwalk storing interface name and index from netscreen specific mib
    my $refhSNMPResultIfIp;         # Lines returned from snmpwalk storing ip addresses
    my $refhSNMPResultIfNetmask;    # Lines returned from snmpwalk storing physical addresses

    # Get info from snmp/cache
    #------------------------------------------

    # if not already done, get map table: get netscreen interface name and build a map table with the standard interface description
    if (not defined $grefhCurrent->{MD}->{Map}->{Netscreen}) {
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDIfName->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultIfName = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDIfName ])) if ($@);

        while ( my ($Idx,$Name) = each(%$refhSNMPResultIfName) ) {
            $Name = normalize ($Name);
            if (defined $grefhCurrent->{MD}->{Map}->{DescrToName}->{"$Name"}) {
                $grefhCurrent->{MD}->{Map}->{Netscreen}->{NameToNsIfIndex}->{"$Name"} = $Idx;
                $grefhCurrent->{MD}->{Map}->{Netscreen}->{NsIfIndexToName}->{$Idx} = "$Name";
            }
        }
    }

    # get all interface ip info - resulting table can be empty
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDIfIp->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 0));
        $refhSNMPResultIfIp = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDIfIp ])) if ($@);

    # Example of refhSNMPResultIfIp content:
    #  '0' => '192.168.254.38',
    #  '1' => '192.168.254.41',
    #  '10' => '10.208.1.1',
    #  '13' => '0.0.0.0',

    # store all ip information in the hash to avoid reading the netmask
    # again in the next run
    {
      local $Data::Dumper::Indent = 0;
      $grefhCurrent->{MD}->{CachedInfo}->{IpInfo} = Dumper($refhSNMPResultIfIp);
    }

    # get the subnet masks with caching 0 only if the ip addresses
    # have changed
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$refhOIDIfNetmask->{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 0));
        (defined $grefhFile->{MD}->{CachedInfo}->{IpInfo} and $grefhCurrent->{MD}->{CachedInfo}->{IpInfo} eq $grefhFile->{MD}->{CachedInfo}->{IpInfo})
            and $hOptions{cachetimer} = $gLongCacheTimer;
        $refhSNMPResultIfNetmask = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ $refhOIDIfNetmask ])) if ($@);

    # Example of refhSNMPResultIfNetmask content:
    #  '0' => '255.255.255.252',
    #  '1' => '255.255.255.252',
    #  '10' => '255.255.255.0',
    #  '13' => '0.0.0.0',

    for my $ifName (keys %{$grefhCurrent->{If}}) {
        # Extract the index out of the MetaData
        if (defined $grefhCurrent->{MD}->{Map}->{Netscreen}->{NameToNsIfIndex}->{"$ifName"}) {
            my $NsIfIndex = $grefhCurrent->{MD}->{Map}->{Netscreen}->{NameToNsIfIndex}->{"$ifName"};
            if (defined $refhSNMPResultIfIp->{$NsIfIndex}) {
                my $IpAddress = $refhSNMPResultIfIp->{$NsIfIndex};
                my $NetMask = (defined $refhSNMPResultIfNetmask->{$NsIfIndex}) ? $refhSNMPResultIfNetmask->{$NsIfIndex} : "";
                logger(2, "IfName=\"$ifName\", NsIfIndex=\"$NsIfIndex\", IpAddress=\"$IpAddress\", Netmask=\"$NetMask\"");

                $NetMask = $quadmask2dec{"$NetMask"} if (defined $quadmask2dec{"$NetMask"});
                my $IpInfo = "$IpAddress";
                $IpInfo .= "/$NetMask" if ($NetMask);

                # add IpInfo as property to the interface
                $grefhCurrent->{If}->{"$ifName"}->{ifIpInfo} = "$IpInfo";

                # check if the IP address has changed to its first run
                my $FirstIpInfo = $grefhFile->{If}->{"$ifName"}->{ifIpInfo};
                $FirstIpInfo = "" unless ($FirstIpInfo);

                # disable caching of this interface if ip information has changed
                if ("$IpInfo" ne "$FirstIpInfo") {
                    $grefhCurrent->{MD}->{If}->{"$ifName"}->{CacheTimer} = 0;
                    $grefhCurrent->{MD}->{If}->{"$ifName"}->{CacheTimerComment} =
                        "caching is disabled because of first or current IpInfo";
                }

            } else {
                $grefhCurrent->{If}->{"$ifName"}->{ifIpInfo} = '';
                logger(2, "IfName=\"$ifName\", NsIfIndex=\"$NsIfIndex\", IpAddress not found for the interface");
            }
        } else {
            $grefhCurrent->{If}->{"$ifName"}->{ifIpInfo} = '';
            logger(2, "IfName=\"$ifName\", NsIfIndex not found for the interface");
        }
    }

    return 0;
}

# ------------------------------------------------------------------------
# Get_Specific_Netscreen
# ------------------------------------------------------------------------
sub Get_Specific_Netscreen {
    my $refhSNMPResultNsIfName;
    my $refhSNMPResultNsZoneCfgName;
    my $refhSNMPResultNsIfZone;
    my $refhSNMPResultNsVsysCfgName;
    my $refhSNMPResultNsIfVsys;
    my $refhSNMPResultNsIfMng;

    # Get info from snmp/cache
    #------------------------------------------

    # if not already done, get map table: get netscreen interface name and build a map table with the standard interface description
    if (not defined $grefhCurrent->{MD}->{Map}->{Netscreen}) {
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$oid_juniper_nsIfName{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultNsIfName = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_juniper_nsIfName ])) if ($@);

        while ( my ($Idx,$Name) = each(%$refhSNMPResultNsIfName) ) {
            $Name = normalize ($Name);
            if (defined $grefhCurrent->{MD}->{Map}->{DescrToName}->{"$Name"}) {
                $grefhCurrent->{MD}->{Map}->{Netscreen}->{NameToNsIfIndex}->{"$Name"} = $Idx;
                $grefhCurrent->{MD}->{Map}->{Netscreen}->{NsIfIndexToName}->{$Idx} = "$Name";
            }
        }
    }

    # Zones
    ## get netscreen zone id and name
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$oid_juniper_nsZoneCfgName{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResultNsZoneCfgName = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_juniper_nsZoneCfgName ])) if ($@);
    # Example of content of $refhSNMPResultNsZoneCfgName:
    #  '0' => 'Null',
    #  '1' => 'Untrust',
    #  '10' => 'Global',
    #  '1000' => 'VPN_END_POINT',
          
    ## get netscreen zone id for all interfaces
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$oid_juniper_nsIfZone{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResultNsIfZone = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_juniper_nsIfZone ])) if ($@);
    # Example of content of $refhSNMPResultNsIfZone:
    #  '0' => 2,
    #  '1' => 1004,
    #  '10' => 1006,
    #  '11' => 1007,
    #  '12' => 3,   
    
    for my $ifName (keys %{$grefhCurrent->{If}}) {
        # Extract the index out of the MetaData
        if (defined $grefhCurrent->{MD}->{Map}->{Netscreen}->{NameToNsIfIndex}->{"$ifName"}) {
            my $NsIfIndex = $grefhCurrent->{MD}->{Map}->{Netscreen}->{NameToNsIfIndex}->{"$ifName"};
            if (defined $refhSNMPResultNsZoneCfgName->{"$refhSNMPResultNsIfZone->{$NsIfIndex}"}) {
                # add property to the interface
                $grefhCurrent->{If}->{"$ifName"}->{nsIfZone} = $refhSNMPResultNsZoneCfgName->{"$refhSNMPResultNsIfZone->{$NsIfIndex}"};
                logger(2, "IfName=\"$ifName\", NsIfIndex=\"$NsIfIndex\", Zone=\"".$refhSNMPResultNsZoneCfgName->{"$refhSNMPResultNsIfZone->{$NsIfIndex}"}."\"");
            } else {
                $grefhCurrent->{If}->{"$ifName"}->{nsIfZone} = '';
                logger(2, "IfName=\"$ifName\", NsIfIndex=\"$NsIfIndex\", Zone not found for the interface");
            }
        } else {
            $grefhCurrent->{If}->{"$ifName"}->{nsIfZone} = '';
            logger(2, "IfName=\"$ifName\", NsIfIndex not found for the interface");
        }
    }

    # Vsys
    ## get netscreen vsys id and name
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$oid_juniper_nsVsysCfgName{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResultNsVsysCfgName = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_juniper_nsVsysCfgName ])) if ($@);
    # Example of content of $refhSNMPResultNsVsysCfgName:
    #  '0' => 'Root'

    ## get netscreen vsys id for all interfaces
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$oid_juniper_nsIfVsys{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResultNsIfVsys = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_juniper_nsIfVsys ])) if ($@);
    # Example of content of $refhSNMPResultNsIfVsys:
    #  '0' => 0,
    #  '1' => 0,
    #  '10' => 0,
    #  '11' => 0,

    for my $ifName (keys %{$grefhCurrent->{If}}) {
        # Extract the index out of the MetaData
        if (defined $grefhCurrent->{MD}->{Map}->{Netscreen}->{NameToNsIfIndex}->{"$ifName"}) {
            my $NsIfIndex = $grefhCurrent->{MD}->{Map}->{Netscreen}->{NameToNsIfIndex}->{"$ifName"};
            if (defined $refhSNMPResultNsVsysCfgName->{"$refhSNMPResultNsIfVsys->{$NsIfIndex}"}) {
                # add property to the interface
                $grefhCurrent->{If}->{"$ifName"}->{nsIfVsys} = $refhSNMPResultNsVsysCfgName->{"$refhSNMPResultNsIfVsys->{$NsIfIndex}"};
                logger(2, "IfName=\"$ifName\", NsIfIndex=\"$NsIfIndex\", Vsys=\"".$refhSNMPResultNsVsysCfgName->{"$refhSNMPResultNsIfVsys->{$NsIfIndex}"}."\"");
            } else {
                $grefhCurrent->{If}->{"$ifName"}->{nsIfVsys} = '';
                logger(2, "IfName=\"$ifName\", NsIfIndex=\"$NsIfIndex\", Vsys not found for the interface");
            }
        } else {
            $grefhCurrent->{If}->{"$ifName"}->{nsIfVsys} = '';
            logger(2, "IfName=\"$ifName\", NsIfIndex not found for the interface");
        }
    }

    # Management protocols
    # get permitted management protocols from : Telnet, SCS, WEB, SSL, SNMP, Global, GlobalPro, Ping, IdentReset
    eval {
        my %hOptions = ( %ghSNMPOptions, (oids => ["$oid_juniper_nsIfMngTelnet{'oid'}","$oid_juniper_nsIfMngSCS{'oid'}","$oid_juniper_nsIfMngWEB{'oid'}",
            "$oid_juniper_nsIfMngSSL{'oid'}","$oid_juniper_nsIfMngSNMP{'oid'}","$oid_juniper_nsIfMngGlobal{'oid'}","$oid_juniper_nsIfMngGlobalPro{'oid'}",
            "$oid_juniper_nsIfMngPing{'oid'}","$oid_juniper_nsIfMngIdentReset{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
        $refhSNMPResultNsIfMng = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_juniper_nsIfMngTelnet, \%oid_juniper_nsIfMngSCS, \%oid_juniper_nsIfMngWEB, 
            \%oid_juniper_nsIfMngSSL, \%oid_juniper_nsIfMngSNMP, \%oid_juniper_nsIfMngGlobal, \%oid_juniper_nsIfMngGlobalPro, 
            \%oid_juniper_nsIfMngPing, \%oid_juniper_nsIfMngIdentReset ])) if ($@);
    # Example of content of $refhSNMPResultNsIfMng:
    #  '0' => '1|1|1|1|1|0|1|1|0',
    #  '1' => '0|0|0|0|0|0|0|1|0',
    #  '10' => '0|0|0|0|0|0|0|1|0',
    #  '11' => '0|0|0|0|0|0|0|1|0',
    #  '12' => '0|0|0|0|0|0|0|1|0',

    for my $ifName (keys %{$grefhCurrent->{If}}) {
        # Extract the index out of the MetaData
        if (defined $grefhCurrent->{MD}->{Map}->{Netscreen}->{NameToNsIfIndex}->{"$ifName"}) {
            my $NsIfIndex = $grefhCurrent->{MD}->{Map}->{Netscreen}->{NameToNsIfIndex}->{"$ifName"};
            if (defined $refhSNMPResultNsIfMng->{"$NsIfIndex"}) {
                my @MngProtoNumeric = split ('\|', $refhSNMPResultNsIfMng->{"$NsIfIndex"});
                my @MngProtoString = ('Telnet', 'SCS', 'WEB', 'SSL', 'SNMP', 'Global', 'GlobalPro', 'Ping', 'IdentReset');
                my $MngProtocols = '';
                for my $i (0 .. $#MngProtoNumeric) {
                    if ($MngProtoNumeric[$i]) {
                        $MngProtocols .= ', ' if ($MngProtocols);
                        $MngProtocols .= "$MngProtoString[$i]";
                    }
                }
                # add property to the interface
                $grefhCurrent->{If}->{"$ifName"}->{nsIfMng} = $MngProtocols;
                logger(2, "IfName=\"$ifName\", NsIfIndex=\"$NsIfIndex\", IfMng=\"$MngProtocols\"");
            } else {
                $grefhCurrent->{If}->{"$ifName"}->{nsIfMng} = '';
                logger(2, "IfName=\"$ifName\", NsIfIndex=\"$NsIfIndex\", IfMng not found for the interface");
            }
        } else {
            $grefhCurrent->{If}->{"$ifName"}->{nsIfMng} = '';
            logger(2, "IfName=\"$ifName\", NsIfIndex not found for the interface");
        }
    }
    return 0;
}


# ------------------------------------------------------------------------
# Get_Alias_Brocade
# ------------------------------------------------------------------------
# walk through each interface and read PortNames
# ------------------------------------------------------------------------
sub Get_Alias_Brocade {

    #my $refhOIDFCPortSpecifier = shift; # %oid_brocade_swFCPortSpecifier
    #my $refhOIDFCPortName      = shift; # %oid_brocade_swFCPortName
    my $refhSNMPResultFCPortSpecifier;   # Lines returned from snmpwalk storing FC Port Specifier
    my $refhSNMPResultFCPortName;        # Lines returned from snmpwalk storing FC Port Names

    # Get info from snmp/cache
    #------------------------------------------

    # if not already done, get map table: get brocade port specifier and build a map table with the standard interface description and index
    if (not defined $grefhCurrent->{MD}->{Map}->{Brocade}) {
        eval {
            my %hOptions = ( %ghSNMPOptions, (oids => ["$oid_brocade_swFCPortSpecifier{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 1));
            $refhSNMPResultFCPortSpecifier = GetTableDataWithSnmp (\%hOptions);
        };
        ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_brocade_swFCPortSpecifier ])) if ($@);

        while ( my ($Idx,$Port) = each(%$refhSNMPResultFCPortSpecifier) ) {
            $Port = "0/" . $Port if (not $Port =~ m/[0-9]+\/[0-9]+/);
            my $Name = normalize ("FC port " . $Port);
            if (defined $grefhCurrent->{MD}->{Map}->{DescrToName}->{"$Name"}) {
                $grefhCurrent->{MD}->{Map}->{Brocade}->{NameToFCPortIndex}->{"$Name"} = $Idx;
                $grefhCurrent->{MD}->{Map}->{Brocade}->{FCPortIndexToName}->{$Idx} = "$Name";
            }
        }
    }

    # get FC PortName table (~ Alias)
    eval {
        my %hOptions = ($ghOptions{'alias-matching'}) ? ( %ghSNMPOptions, (oids => ["$oid_brocade_swFCPortName{'oid'}"], cachetimer => 0, outputhashkeyidx => 1, checkempty => 0))
            : ( %ghSNMPOptions, (oids => ["$oid_brocade_swFCPortName{'oid'}"], cachetimer => $gLongCacheTimer, outputhashkeyidx => 1, checkempty => 0));
        $refhSNMPResultFCPortName = GetTableDataWithSnmp (\%hOptions);
    };
    ExitPlugin($ERRORS{"UNKNOWN"}, add_oid_details($@->message(), [ \%oid_brocade_swFCPortName ])) if ($@);

    for my $ifName (keys %{$grefhCurrent->{If}}) {
        # Extract the index out of the MetaData
        if (defined $grefhCurrent->{MD}->{Map}->{Brocade}->{NameToFCPortIndex}->{"$ifName"}) {
            my $FCPortIndex = $grefhCurrent->{MD}->{Map}->{Brocade}->{NameToFCPortIndex}->{"$ifName"};
            if (defined $refhSNMPResultFCPortName->{$FCPortIndex}) {
                # add property to the interface
                $grefhCurrent->{If}->{"$ifName"}->{ifAlias} = $refhSNMPResultFCPortName->{$FCPortIndex};
                logger(2, "IfName=\"$ifName\", FCPortIndex=\"$FCPortIndex\", FCPortName(Alias)=\"".$refhSNMPResultFCPortName->{$FCPortIndex}."\"");
            } else {
                $grefhCurrent->{If}->{"$ifName"}->{ifAlias} = '';
                logger(2, "IfName=\"$ifName\", FCPortIndex=\"$FCPortIndex\", FCPortName(Alias) not found for the interface");
            }
        } else {
            $grefhCurrent->{If}->{"$ifName"}->{ifAlias} = '';
            logger(2, "IfName=\"$ifName\", FCPortIndex not found for the interface");
        }
    }
    
    return 0;
}


# oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
# GENERAL FUNCTIONS
# oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

# ------------------------------------------------------------------------------
# ReadInterfaceInformationFile
# ------------------------------------------------------------------------------
# Description:
# Read all interfaces and its properties into the hash $grefhFile
# ------------------------------------------------------------------------------
sub ReadInterfaceInformationFile {

    my $InterfaceInformationFile = shift;
    my $grefhFile;

    # read all properties from the state file - store into $grefhFile
    if (-r "$InterfaceInformationFile") {
        logger(1, "Found a readable state file \"$InterfaceInformationFile\"");
        $grefhFile = ReadConfigFileNew ("$InterfaceInformationFile");

        # check that the state file is not an old formated file, generated by a previous version
        # of the plugin
        if (not $grefhFile->{Version} or $grefhFile->{Version} ne "$REVISION" ) {
            unlink ("$InterfaceInformationFile");   # delete the old file
            for (keys %$grefhFile) { delete $grefhFile->{$_}; }  # purge the $grefhFile hash
            logger(1, "Found a state file generated by another version of the plugin. Reinitialize the state file and the interface table now");
            WriteConfigFileNew ("$InterfaceInformationFile",$grefhCurrent);
            $gInitialRun = 1;
        } elsif ($grefhCurrent->{MD}->{Node}->{sysUpTime} < $grefhFile->{MD}->{Node}->{sysUpTime}) {
            # check if the node has just rebooted
            logger(1, "The node has been restarted (sysUpTime retrieved is smaller than the one in the state file). Any cache timers are disactivated for that run");
            $gShortCacheTimer = 0;
            $gLongCacheTimer  = 0;
            logger(1, "The node has been restarted (sysUpTime retrieved is smaller than the one in the state file). Purging the counters from history as not usable anymore");
            delete $grefhFile->{History};  # purge the History part in $grefhFile hash
        }

        # detect if the user has just changed between using the 64bits option or not.
        # In case of change, purge the history datasets as they are not correct anymore
        $grefhCurrent->{MD}->{CachedInfo}->{'64bits'} = $ghSNMPOptions{'64bits'};
        if (defined $grefhFile->{MD}->{CachedInfo}->{'64bits'} and $ghSNMPOptions{'64bits'} != $grefhFile->{MD}->{CachedInfo}->{'64bits'}) {
            logger(1, "Detected a change in the use of the --64bits option. Purging the counters from history as not usable anymore");
            delete $grefhFile->{History};  # purge the History part in $grefhFile hash
        }
        # detect if the user has just changed the node type.
        # In case of change, purge the history datasets as they can be not correct anymore
        $grefhCurrent->{MD}->{CachedInfo}->{'nodetype'} = $ghOptions{'nodetype'};
        if (defined $grefhFile->{MD}->{CachedInfo}->{'nodetype'} and $ghOptions{'nodetype'} ne $grefhFile->{MD}->{CachedInfo}->{'nodetype'}) {
            logger(1, "Detected a change in the use of the --nodetype option (".$grefhFile->{MD}->{CachedInfo}->{'nodetype'}." to ".$ghOptions{'nodetype'}."). Purging the counters from history as can be not usable anymore");
            delete $grefhFile->{History};  # purge the History part in $grefhFile hash
        }

    } else {
        # the file with interface information was not found - this is the first
        # run of the program or it was deleted before.
        # Create a new one and store the sysUptime immediately
        logger(1, "No readable state file \"$InterfaceInformationFile\" found, creating a new one");
        WriteConfigFileNew ("$InterfaceInformationFile",$grefhCurrent);
        $gInitialRun = 1;
    }
    return $grefhFile;
}

# ------------------------------------------------------------------------------
# ReadConfigFileNew
# ------------------------------------------------------------------------------
# Description:
# Read config file with the perl Config::General Module
#
#   http://search.cpan.org/search?query=Config%3A%3AGeneral&mode=all
#
# ------------------------------------------------------------------------------
sub ReadConfigFileNew {

    my $ConfigFile = shift;
    logger(2, "Reading config file: $ConfigFile");

    my $refoConfig; # object definition for the config
    my $refhConfig; # hash reference returned

    # return undef if file is not readable
    unless (-r "$ConfigFile") {
        logger(2, "Config file \"$ConfigFile\" not readable");
        return $refhConfig;
    }

    # Initialize ConfigFile Read Process (create object)
    eval {
        $refoConfig = new Config::General (
            -ConfigFile             => "$ConfigFile",
            -UseApacheInclude       => "false",
            -MergeDuplicateBlocks   => "false",
            -InterPolateVars        => "false",
            -SplitPolicy            => 'equalsign'
        );
    };
    if($@) {
        # it's not successfull so remove the bad config file and try again.
        logger(1, "CONFIG READ FAIL: create new one ($ConfigFile).");
        unlink "$ConfigFile";
        return $refhConfig;
    }

    # Read Config File
    %$refhConfig = $refoConfig->getall;

    # return reference
    return $refhConfig;
}

# ------------------------------------------------------------------------------
# WriteConfigFileNew
# ------------------------------------------------------------------------------
# Description:
# --- write a hash reference to a file
# --- see ReadConfigFileNew ---------
#
# $gFile = full qulified filename with path
# $refhStruct = hash reference
# ------------------------------------------------------------------------------
sub WriteConfigFileNew {
    my $ConfigFile   =   shift;
    my $refhStruct   =   shift;
    logger(3, "File to write: $ConfigFile");

    use File::Basename;

    my $refoConfig; # object definition for the config
    my $Directory = dirname ($ConfigFile);

    # Initialize ConfigFile Read Process (create object)
    $refoConfig = new Config::General (
        -ConfigPath             => "$Directory",
        -UseApacheInclude       => "false",
        -MergeDuplicateBlocks   => "false",
        -InterPolateVars        => "false",
        -SplitPolicy            => 'equalsign'
    );

    # Write Config File
    if (not -w "$Directory") {
        ExitPlugin($ERRORS{"UNKNOWN"}, "Unable to write to directory $Directory $!\n");
    }
    if (-e "$ConfigFile" and not -w "$ConfigFile") {
        ExitPlugin($ERRORS{"UNKNOWN"}, "Unable to write to existing file $ConfigFile $!\n");
    }

    umask "$UMASK";
    $refhStruct->{Version} = $REVISION;
    $refoConfig->save_file("$ConfigFile", $refhStruct);
    logger(1, "Wrote interface data to file: $ConfigFile");

    return 0;
}

# ------------------------------------------------------------------------
# CleanAndSelectHistoricalDataset
# ------------------------------------------------------------------------
# clean outdated historical data statistics and select the one eligible
# for bandwitdh calculation
# ------------------------------------------------------------------------
sub CleanAndSelectHistoricalDataset {
    my $firsttime = undef;

    # loop through all historical perfdata
    logger(1, "Clean/select historical datasets");
    for my $time (sort keys %{$grefhFile->{History}}) {
        if (($STARTTIME - ($ghOptions{'delta'} + $ghOptions{'delta'} / 3)) > $time) {
            # delete anything older than starttime - (delta + a bit buffer)
            # so we keep a sliding window following us
            delete $grefhFile->{History}->{$time};
            logger(1, " outdated perfdata cleanup: $time");
        } elsif ($time < $STARTTIME) {
            # chose the oldest dataset to compare with
            $firsttime = $time;
            $gUsedDelta = $STARTTIME - $firsttime;
            logger(1, " now ($STARTTIME) - comparetimestamp ($time) = used delta ($gUsedDelta)");
            last;
        }
    }
    
    if (not defined $firsttime) {
        # no dataset (left) to compare with
        # no further calculations if we run for the first time.
        logger(1, " no dataset (left) to compare with, bandwitdh calculations will not be done");
    }
    
    return $firsttime;
}

# ------------------------------------------------------------------------
# GenerateInterfaceTableData
# ------------------------------------------------------------------------
# Compare data from refhFile and refhCurrent and create the csv data for
# html table.
# ------------------------------------------------------------------------
sub GenerateInterfaceTableData {

    my $refaIndizes                 = shift;
    my $refAoHInterfaceTableHeader  = shift;
    my $refaToCompare               = shift;            # Array of fields which should be included from change tracking
    my $iLineCounter                = 0;                # Fluss Variable (ah geh ;-) )
    my $refaContentForHtmlTable;                        # This is the final data structure which we pass to Convert2HtmlTable

    my $grefaInterfaceTableFields;
    foreach my $Cell ( @$grefAoHInterfaceTableHeader ) {
        if (($Cell->{'Nodetype'} eq 'ALL' or $Cell->{'Nodetype'} =~ m/$ghOptions{nodetype}/) and $Cell->{'Enabled'}) {
            push(@$grefaInterfaceTableFields,$Cell->{'Dataname'});
        }
    }

    # Print a header for debug information
    logger(2, "x"x50);

    # Print tracking info
    logger(5, "Available fields:".Dumper($refAoHInterfaceTableHeader));
    logger(5, "Tracked fields:".Dumper($refaToCompare));

    # $refaIndizes is a indexed and sorted list of interfaces
    for my $InterfaceIndex (@$refaIndizes) {

        # Current field ID
        my $iFieldCounter = 0;

        # Get normalized interface name (key for If data structure)
        my $Name = $grefhCurrent->{MD}->{Map}->{IndexToName}->{$InterfaceIndex};

        # Skip the interface if config table enabled
        if ($ghOptions{configtable} and $grefhCurrent->{MD}->{If}->{$Name}->{ExcludedTrack} eq "true") {
            next;
        }

        # This is the If datastructure from the interface information file
        my $refhInterFaceDataFile     = $grefhFile->{If}->{$Name};

        # This is the current measured If datastructure
        my $refhInterFaceDataCurrent  = $grefhCurrent->{If}->{$Name};

        # This variable used for exittext
        $gNumberOfInterfaces++;

        foreach my $Header ( @$refAoHInterfaceTableHeader ) {
            next if (($Header->{'Nodetype'} ne 'ALL' and not $Header->{'Nodetype'} =~ m/$ghOptions{nodetype}/) or not $Header->{'Enabled'});

            my $ChangeTime;
            my $LastChangeInfo          = "";
            #my $CellColor;
            my $CellBackgroundColor;
            my $CellStyle;
            my $CellContent;
            my $CurrentFieldContent     = "";
            my $FileFieldContent        = "";
            my $FieldType               = ""; # 'property' or 'load'

            if (defined $refhInterFaceDataCurrent->{"$Header->{Dataname}"}) {
                # This is used to calculate the id (used for displaying the html table)
                $CurrentFieldContent  = $refhInterFaceDataCurrent->{"$Header->{Dataname}"};
                # Delete the first and last "blank"
                $CurrentFieldContent =~ s/^ //;
                $CurrentFieldContent =~ s/ $//;
            }
            if (defined $refhInterFaceDataFile->{"$Header->{Dataname}"}) {
                $FileFieldContent = $refhInterFaceDataFile->{"$Header->{Dataname}"};
                # Delete the first and last "blank"
                $FileFieldContent =~ s/^ //;
                $FileFieldContent =~ s/ $//;
            }

            # Flag if the current status of this field should be compared with the
            # "snapshoted" status.
            my $CompareThisField = grep (/$Header->{Dataname}/i, @$refaToCompare);

            # some fields have a change time property in the interface information file.
            # if the change time exists we store this and write into html table
            $ChangeTime = $grefhFile->{MD}->{If}->{$Name}->{$Header->{Dataname}."ChangeTime"};

            # If interface is excluded or this is the initial run we don't lookup for
            # data changes
            if ($gInitialRun)  {
                $CompareThisField = 0;
                $CellStyle = "cellInitialRun";
            } elsif ($grefhCurrent->{MD}->{If}->{$Name}->{ExcludedTrack} eq "true") {
                $CompareThisField = 0;
                $CellStyle = "cellExcluded";
            } elsif (($grefhCurrent->{MD}->{If}->{$Name}->{ExcludedLoadTrack} eq "true") && ( $Header->{'Datatype'} eq "load" )) {
                $CompareThisField = 0;
                $CellStyle = "cellNotTracked";
            } elsif (($grefhCurrent->{MD}->{If}->{$Name}->{ExcludedPropertyTrack} eq "true") && ( $Header->{'Datatype'} eq "property" ) && ($CompareThisField == 1)) {
                $CompareThisField = 0;
                $CellStyle = "cellNotTracked";
            } elsif (defined $grefhCurrent->{If}->{$Name}->{$Header->{Dataname}."OutOfRange"}) {
                $CellBackgroundColor = $grefhCurrent->{If}->{$Name}->{$Header->{Dataname}."OutOfRange"};
            }

            # Set LastChangeInfo to this Format "(since 0d 0h 43m)"
            if ( defined $ChangeTime and $ghOptions{trackduration} ) {
                $ChangeTime = TimeDiff ("$ChangeTime",time());
                $LastChangeInfo = "(since $ChangeTime)";
            }

            if ( $CompareThisField  ) {
                logger(2, "Compare \"".denormalize($Name)."($Header->{Dataname})\" now=\"$CurrentFieldContent\" file=\"$FileFieldContent\"");
                if ( $CurrentFieldContent eq $FileFieldContent ) {
                    # Field content has NOT changed
                    $CellContent = denormalize ( $CurrentFieldContent );
                    $CellStyle = "cellTrackedOk";
                } else {
                    # Field content has changed ...
                    $CellContent = "now: " . denormalize( $CurrentFieldContent ) . "$LastChangeInfo was: " . denormalize ( $FileFieldContent );
                    if ($ghOptions{verbose} or $ghOptions{'warning-property'} > 0 or $ghOptions{'critical-property'} > 0) {
                        $gChangeText .= "(" . denormalize ($Name) .
                            ") $Header->{Dataname} now <b>$CurrentFieldContent</b> (was: <b>$FileFieldContent</b>)<br>";
                    }
                    $CellStyle = "cellTrackedChange";
                    $gDifferenceCounter++;

                    # Update the list of changes
                    if ( defined $refhInterFaceDataCurrent->{"ifAlias"} and $refhInterFaceDataCurrent->{"ifAlias"} ne "" ) {
                        push @{$grefhListOfChanges->{"$Header->{Dataname}"}}, trim(denormalize($Name))." (".trim(denormalize($refhInterFaceDataCurrent->{"ifAlias"})).")";
                    } else {
                        push @{$grefhListOfChanges->{"$Header->{Dataname}"}}, trim(denormalize($Name));
                    }
                }
            } else {
                # Filed will not be compared, just write the current field - value in the table.
                logger(2, "Not comparing $Header->{Dataname} on interface ".denormalize($Name));
                $CellContent = denormalize( $CurrentFieldContent );
            }

            # Actions field
            if (grep (/$Header->{Dataname}/i, "Actions")) {
                # Graphing solution link - one link per line/interface/port
                if ($grefhCurrent->{MD}->{If}->{$Name}->{ExcludedTrack} eq "false"
                    and defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{OctetsIn}
                    and $ghOptions{'enableperfdata'}) {
                        #my $servicename = 'Port' . sprintf("%03d", $InterfaceIndex);
                        my $servicename = "If_" . trim(denormalize($Name));
                        $servicename =~ s/#//g;
                        $servicename =~ s/[: ]/_/g;
                        $servicename =~ s/[()'"]//g;
                        $servicename =~ s/,/./g;
                        if ($ghOptions{'grapher'} eq  "pnp4nagios") {
                            $CellContent .= '<a class=\'tips\' ' .
                                'href="' . $ghOptions{'grapherurl'} . '/index.php/graph?host=' . $ghOptions{'hostdisplay'} . '&srv=' . $servicename . '" ' .
                                'rel="' . $ghOptions{'grapherurl'} . '/index.php/popup?host=' . $ghOptions{'hostdisplay'} . '&srv=' . $servicename . '">' .
                                '<img src="../img/chart.png" alt="Trends" /></a>';
                        } elsif ($ghOptions{'grapher'} eq  "nagiosgrapher") {
                            $CellContent .= '<a href="' .
                                #$ghOptions{'grapherurl'} . '/graphs.cgi?host=' . $ghOptions{'hostdisplay'} . '&srv=' . $servicename . 
                                #'&page_act=[1]+Interface+traffic' .
                                $ghOptions{'grapherurl'} . '/graphs.cgi?host=' . $ghOptions{'hostdisplay'} . '&srv=' . $servicename . '">' .
                                '<img src="../img/chart.png" alt="Trends" /></a>';
                        } elsif ($ghOptions{'grapher'} eq  "netwaysgrapherv2") {
                            $CellContent .= '<a href="' .
                                $ghOptions{'grapherurl'} . '/graphs.cgi?host=' . $ghOptions{'hostdisplay'} . '&srv=' . $servicename . '">' .
                                '<img src="../img/chart.png" alt="Trends" /></a>';
                        } elsif ($ghOptions{'grapher'} eq  "ingraph") {
                            if ($ghOptions{'nodetype'} eq  "bigip") {
                                $CellContent .= '<a href="' .
                                    $ghOptions{'grapherurl'} . '/?host=' . $ghOptions{'hostdisplay'} . '&service=' . $servicename . '::check_interface_table_port_bigip">' .
                                    '<img src="../img/chart.png" alt="Trends" /></a>';
                            } else {
                                $CellContent .= '<a href="' .
                                    $ghOptions{'grapherurl'} . '/?host=' . $ghOptions{'hostdisplay'} . '&service=' . $servicename . '::check_interface_table_port">' .
                                    '<img src="../img/chart.png" alt="Trends" /></a>';
                            }
                        }
                }
                # Retrieve detailed interface info via snmp link
                if ($ghOptions{'ifdetails'} and $grefhCurrent->{MD}->{If}->{$Name}->{ExcludedTrack} eq "false") {
                    $CellContent .= '<a href="xxxxxxxxxxxx.cgi?' .
                        'host=' . $ghOptions{'hostquery'} .
                        '&ifindex=' . $InterfaceIndex . '">' .
                        '<img src="../img/binocular.png" alt="Details" /></a>';
                }
            }

            # Write an empty cell content if CellContent is empty
            # This is for visual purposes
            not $CellContent and $CellContent = '&nbsp';

            # Store cell content in table
            $refaContentForHtmlTable->[ $iLineCounter ]->[ $iFieldCounter ]->{"Value"} = "$CellContent";

            # Change font color
            #  defined $CellColor and
            #  $refaContentForHtmlTable->[ $iLineCounter ]->[ $iFieldCounter ]->{Font} =
            #  $CellColor;
            # Change background color
            defined $CellBackgroundColor and
              $refaContentForHtmlTable->[ $iLineCounter ]->[ $iFieldCounter ]->{Background} = $CellBackgroundColor;
            # Change cell style
            defined $CellStyle and
              $refaContentForHtmlTable->[ $iLineCounter ]->[ $iFieldCounter ]->{Style} = $CellStyle;

            $iFieldCounter++;
        } # for Header

        $iLineCounter++;
    } # for $InterfaceIndex

    # Print a footer for debug information
    logger(5, " List of changes -> generated hash of array\ngrefhListOfChanges:".Dumper ($grefhListOfChanges));
    logger(2, "x"x50);

    return $refaContentForHtmlTable;
}

# ------------------------------------------------------------------------------
# Convert2HtmlTable
# ------------------------------------------------------------------------------
# Description: This function generates a html table
# Function call:
#  $gHtml = Convert2HtmlTable ($tableType, $refAoHHeader,$refAoAoHLines,$cssClass);
# Arguments:
#  0 : number representing the properties of the table to generate:
#       1 : enable header line
#       2 : enable first column
#      exemple: 3 = header line and first column enabled
#      default is 1.
#  1 : ref to an AoH. Each hash correspond to a header of the table
#        * Link
#        * Tip
#  2 : ref to an AoAoH. Each subarray corresponds to an interface
#      (a table row) and contains a hash for each column
#      hash keys can be:
#        * InterfaceGraphURL
#        * Background
#        * Style
#        * Value
#  3 : css class to use for the table
#      available ones are: infotable, interfacetable
# Output:
#  0 : string containing all the html code corresponding to a table
# ------------------------------------------------------------------------------
# Exemple 1: InfoTable
#  Toput
# ------------------------------------------------------------------------------
# Exemple 2: InterfaceTable
#  Toput
#
# ------------------------------------------------------------------------------
sub Convert2HtmlTable {
    my $tableType  = shift;       # Type of table to generate
    my $refAoHHeader = shift;     # Header contains the HTML table header as array
    my $refAoAoHLines  = shift;   # Reference to array of table lines
    my $cssClass   = shift;       # Css class to use for the table
    my $highlightColor = shift;   # Color used to highlight. Disactivated if no color

    my $refaProperties;           # List of properties from each line
    my $HTML;                     # HTML Content back to the caller
    my $HTMLTable;                # HTML Table code only

    my $headerLineEnabled = $tableType%2;
    my $firstColumnEnabled = int($tableType/2);

    logger(3, "x"x50);
    logger(5, "refAoHHeader: " . Dumper ($refAoHHeader));
    logger(5, "refAoAoHLines: " . Dumper ($refAoAoHLines));

    if ($#$refAoAoHLines >= 0) {

        # ------------------------------------------------------------------
        # Build HTML format and table header
        $HTML .= '<table';
        $HTML .= " class=\"$cssClass no-arrow\"";
        if ($highlightColor ne "") {
            $HTML .= ' onMouseOver="javascript:trackTableHighlight(event, ' . "'" . $highlightColor . "'" . ');" onMouseOut="javascript:highlightTableRow(0);"';
        }
        $HTML .= '>'."\n";

        if ($headerLineEnabled) {
            # ------------------------------------------------------------------
            # Build html table title header
            $HTMLTable .= "<tr";
            my $trTagclose = '>';
            foreach my $Cell ( @$refAoHHeader ) {
                if (($Cell->{'Nodetype'} eq 'ALL' or $Cell->{'Nodetype'} =~ m/$ghOptions{nodetype}/) and $Cell->{'Enabled'}) {
                    my $Title;
                    my $SpecialCellFormat = "";

                    $HTMLTable .= $trTagclose;
                    $trTagclose = '';

                    # Sorting
                    if ( defined $Cell->{'Tablesort'} and $Cell->{'Tablesort'} ne '') {
                        $SpecialCellFormat .= " class=\"$Cell->{'Tablesort'}\"";
                    }

                    # if we got a title write into cell
                    if ( defined $Cell->{Title} and  $Cell->{Title} ne " ") {
                        $Title = $Cell->{Title};
                    } else {
                    # otherwise print the error
                        $Title = "ERROR: No name!";
                    }

                    # if a link is indicated
                    if ( defined $Cell->{Link} ) {
                        $Title = '<a href="' . $Cell->{Link} . '">' . $Title . '</a>';
                    }

                    # Tooltip
                    if ( defined $Cell->{Tooltip} and $ghOptions{'tips'}) {
                        #$HTMLTable .= ' onclick="DoNav(\''.$Cell->{InterfaceGraphURL}. '\');"';
                        $Title .= "<img height=14 width=14 style=\"float: right;\" src=\"../img/information-button.png\" " .
                            "onmouseout=\"UnTip()\" onmouseover=\"Tip('<i>$Cell->{Tooltip}</i>')\">"
                    }

                    # finally build the table line;
                    $HTMLTable .= "\n" . '<th' . $SpecialCellFormat . '>' . $Title . '</th>';
                }
            }
            $HTMLTable .= "</tr>";
        }

        # ------------------------------------------------------------------
        # Build html table content
        foreach my $Line ( @$refAoAoHLines ) {
            logger(5, "Line: " . Dumper ($Line));
            # start table line
            $HTMLTable .= "<tr";
            my $trTagclose = '>';

            my $cellCounter = 0;
            foreach my $Cell ( @$Line ) {

                $cellCounter += 1;
                my $Value;
                my $SpecialCellFormat      = "";
                #my $SpecialTextFormatHead  = "";
                #my $SpecialTextFormatFoot  = "";

                if ( defined $Cell->{InterfaceGraphURL} ) {
                    if($ghOptions{'enableperfdata'} and $ghOptions{'grapher'} ne "nagiosgrapher" ){         # thd
                        $HTMLTable .= ' onclick="DoNav(\''.$Cell->{InterfaceGraphURL}. '\');" >';
                    }
                    $trTagclose = '';
                }
                $HTMLTable .= $trTagclose;
                $trTagclose = '';
                #logger(1, "HTMLTable: $HTMLTable \nCell: $Cell->{InterfaceGraphURL}");
                # if background is defined
                if ( defined $Cell->{Background} ) {
                    $SpecialCellFormat .= ' bgcolor="'.$Cell->{Background}.'"';
                }

                # if first column enabled
                if ( $firstColumnEnabled and $cellCounter == 1 ) {
                    defined $Cell->{Style} ? $Cell->{Style} = "cellFirstColumn " . $Cell->{Style} : $Cell->{Style} = "cellFirstColumn";
                }

                # if style is defined
                if ( defined $Cell->{Style} ) {
                    $SpecialCellFormat .= ' class="'.$Cell->{Style}.'"';
                }

                # if a special font is indicated
                #if ( defined $Cell->{Font} ) {
                #    $SpecialTextFormatHead .= $Cell->{Font};
                #    $SpecialTextFormatFoot .= '</font>';
                #}

                # if we got a value write into cell
                if ( defined $Cell->{Value} and  $Cell->{Value} ne " ") {
                    $Value = $Cell->{Value};
                } else {
                # otherwise create a empty cell
                    $Value = "&nbsp;";
                }

                # if a link is indicated
                if ( defined $Cell->{Link} ) {
                    $Value = '<a href="' . $Cell->{Link} . '">' . $Value . '</a>';
                }

                # finally build the table line;
                $HTMLTable .= "\n" . '<td ' .
                    $SpecialCellFormat . '>' .
                    #$SpecialTextFormatHead .
                    $Value .
                    #$SpecialTextFormatFoot .
                    '</td>';
            }
            # end table line
            $HTMLTable .= "</tr>";
        }
        $HTMLTable .= "</table>";
        $HTML .= "$HTMLTable</td></tr><br>";
    } else {
        $HTML.='<a href=JavaScript:history.back();>No data to display</a>'."\n";
    }
    logger(3, "Geneated HTML: $HTML");
    logger(3, "x"x50);

    return $HTML;
}

# ------------------------------------------------------------------------
# WriteHtmlFile
# ------------------------------------------------------------------------
# Description: create interface table html table file. this file will be
# visible on the browser
#
# WriteHtmlFile ({
#    InfoTable           => $gInfoTableHTML,
#    InterfaceTable      => $gInterfaceTableHTML,
#    ConfigTable         => $gConfigTableHTML,
#    Dir                 => $ghOptions{'htmltabledir'},
#    FileName            => $ghOptions{'htmltabledir'}/$gFile".'.html'
# });
#
# ------------------------------------------------------------------------
sub WriteHtmlFile {

    my $refhStruct = shift;

    umask "$UMASK";

                not -d $refhStruct->{Dir} and MyMkdir($refhStruct->{Dir});

    open (OUT,">$refhStruct->{FileName}") or die "cannot $refhStruct->{FileName} $!";
        # -- Header --
        print OUT '<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
    <title>Interfacetable_v3t - ' . $grefhCurrent->{MD}->{Node}->{sysName} . '</title>
    <link rel="stylesheet" type="text/css" href="../css/' . $ghOptions{'css'} . '.css">
    <link rel="stylesheet" type="text/css" href="../css/button.css">
    <script type="text/javascript" src="../js/functions.js"></script>
    <script type="text/javascript" src="../js/tablesort.js"></script>
    <script type="text/javascript" src="../js/customsort.js"></script>';
        if ( $ghOptions{'enableperfdata'} and $ghOptions{'grapher'} eq  "pnp4nagios" ) {
            print OUT '    <script src="/pnp4nagios/media/js/jquery-min.js" type="text/javascript"></script>
    <script src="/pnp4nagios/media/js/jquery.cluetip.js" type="text/javascript"></script>
    <script type="text/javascript">
    jQuery.noConflict();
    jQuery(document).ready(function() {
    jQuery(\'a.tips\').cluetip({ajaxCache: false, dropShadow: false,showTitle: false });
    });
    </script>';
        }
        print OUT '  </head>
<body>
  <script type="text/javascript" src="../js/wz_tooltip.js"></script>';
        # -- Body header --
        print OUT '<div width=98% align=center>';
        print OUT '    <div id="header">
        <div class="buttons">
            <a href="' . $ghOptions{htmltableurl} . '/index.php">
                <img src="../img/house.png" alt="node selector"/>
                node selector
            </a>
        </div>
        <div>';
        print OUT '
        ' , $ghOptions{'hostdisplay'} , ' updated: ' , scalar localtime $ENDTIME_HR , ' (' , sprintf("%.2f", $RUNTIME_HR) , ' sec.)';
        print OUT '
            <span class="button2">';
        while ( my ($key, $value) = each(%{$ghOptions{'accessmethod'}}) ) {
            if ($key =~ /^http$|^https$/) {
                print OUT '<a class="accessmethod" href=" ' . $value . '" target="_blank">' . $key . '</a>';
            } else {
                print OUT '<a class="accessmethod" href=" ' . $value . '">' . $key . '</a>';
            }
        }
        print OUT '
            </span>
        </div>
    </div>
    <br>';

        # -- Tables --
        print OUT '    <div id="info">
        <a name="topinfotable" class="title">Node information</a>' .
        $refhStruct->{InfoTable} . '
    </div>
    <br>';
        print OUT '    <div id="interface">';
        my $i = 0;
        for my $InterfaceTableTitle ( keys %{$refhStruct->{InterfaceTable}} ) {
            print OUT '        <a name="topinterfacetable'.$i.'" class="title">'.$InterfaceTableTitle.'</a>' .
            $refhStruct->{InterfaceTable}->{"$InterfaceTableTitle"} .
        '<div id="toplink">
            <a href="#topinterfacetable'.$i.'">Back to top</a>
        </div>';
            $i++;
        }
        print OUT '    </div>
    <br>';
        if ( $ghOptions{configtable} ) {
        print OUT '    <div id="config">
        <a name="topconfigtable" class="title">Configuration information</a>' .
        $refhStruct->{ConfigTable} . '
    </div>
    <br>';
        }
        # -- Body footer --
        print OUT '
        <div class="buttons">
        <a class="green" href="javascript:history.back();">
            <img src="../img/arrow_left.png" alt="back"/>
            back
        </a>
        <a class="red" href="' . $ghOptions{reseturl} . '/InterfaceTableReset_v3t.cgi?Command=rm&What=' . $gInterfaceInformationFile . '">
            <img src="../img/arrow_refresh.png" alt="reset table"/>
            reset table
        </a>
    </div>
    <div id="footer">
        interfacetable_v3t ' . $REVISION . '
    </div>
</div>
<br>
</body>
</html>';
    close (OUT);
    logger(1, "HTML table file created: $refhStruct->{FileName}");
    return 0;
}

# ------------------------------------------------------------------------
# Perfdataout
# --------------------------------------------------------------------
# Description: write performance data
# Grapher: pnp4nagios, nagiosgrapher, netwaysgrapherv2, ingraph
# Format:
#    * full : generated performance data include plugin related stats,
#             interface status, interface load stats, and packet error stats
#    * loadonly : generated performance data include plugin related stats,
#                 interface status, and interface load stats
#    * globalonly : generated performance data include only plugin related stats
# ------------------------------------------------------------------------
sub Perfdataout {

    #------  Pnp4nagios, Netwaysgrapherv2, ingraph  ------#
    if (( $ghOptions{'grapher'} eq  "pnp4nagios" ) || ( $ghOptions{'grapher'} eq  "ingraph" )) {

        # plugin related stats
        $gPerfdata .= "Interface_global::check_interface_table_global::".
            "time=${RUNTIME_HR}s;;;; ".
            "uptime=$grefhCurrent->{MD}->{Node}->{sysUpTime}s;;;; ".
            "watched=${gNumberOfPerfdataInterfaces};;;; ".
            "useddelta=${gUsedDelta}s;;;; ".
            "ports=${gNumberOfInterfacesWithoutTrunk};;;; ".
            "freeports=${gNumberOfFreeInterfaces};;;; ".
            "adminupfree=${gNumberOfFreeUpInterfaces};;;; ";

        # interface status, and interface load stats
        unless ($ghOptions{'perfdataformat'} eq 'globalonly') {

            # $grefaAllIndizes is a indexed and sorted list of all interfaces
            for my $InterfaceIndex (@$grefaAllIndizes) {
                # Get normalized interface name (key for If data structure)
                my $Name = $grefhCurrent->{MD}->{Map}->{IndexToName}->{$InterfaceIndex};
                
                # using portperfunit "bit" : bit counters
                if ($ghOptions{'portperfunit'} eq "bit") {
                    if ($grefhCurrent->{MD}->{If}->{$Name}->{ExcludedTrack} eq "false"
                      and defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{OctetsIn}
                      and $grefhCurrent->{If}->{$Name}->{ifLoadExceedIfSpeed} eq "false") {
                        my $port = sprintf("%s", $InterfaceIndex);
                        my $servicename = "If_" . trim(denormalize($Name));
                        $servicename =~ s/#//g;
                        $servicename =~ s/[: ]/_/g;
                        $servicename =~ s/[()'"]//g;
                        $servicename =~ s/,/./g;
                        my $perfdata = "";
                        #Add interface status if available
                        if ($ghOptions{'nodetype'} eq 'bigip' and defined $grefhCurrent->{If}->{$Name}->{ifStatus}) {
                            $perfdata .= "${servicename}::check_interface_table_port_bigip::" . # servicename::plugin
                                "Status=$grefhCurrent->{If}->{$Name}->{ifStatusNumber};;;0; " .
                                "BitsIn=". $grefhCurrent->{MD}->{IfCounters}->{$Name}->{OctetsIn}*8 ."c;;;0; " .
                                "BitsOut=". $grefhCurrent->{MD}->{IfCounters}->{$Name}->{OctetsOut}*8 ."c;;;0; ";
                            #Add pkt errors/drops if available and wanted
                            unless ($ghOptions{'perfdataformat'} eq 'loadonly') {
                                $perfdata .= "PktsInErr=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInErr}c;;;0; "
                                    if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInErr});
                                $perfdata .= "PktsOutErr=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutErr}c;;;0; "
                                    if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutErr});
                                $perfdata .= "PktsInDrop=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInDrop}c;;;0; "
                                    if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInDrop});
                                $perfdata .= "PktsOutDrop=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutDrop}c;;;0; "
                                    if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutDrop});
                            }
                        } elsif (defined $grefhCurrent->{If}->{$Name}->{ifOperStatus}) {
                            $perfdata .= "${servicename}::check_interface_table_port::" . # servicename::plugin
                                "OperStatus=$grefhCurrent->{If}->{$Name}->{ifOperStatusNumber};;;0; " .
                                "BitsIn=". $grefhCurrent->{MD}->{IfCounters}->{$Name}->{OctetsIn}*8 ."c;;;0; " .
                                "BitsOut=". $grefhCurrent->{MD}->{IfCounters}->{$Name}->{OctetsOut}*8 ."c;;;0; ";
                            #Add pkt errors/discards if available and wanted
                            unless ($ghOptions{'perfdataformat'} eq 'loadonly') {
                                $perfdata .= "PktsInErr=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInErr}c;;;0; "
                                    if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInErr});
                                $perfdata .= "PktsOutErr=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutErr}c;;;0; "
                                    if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutErr});
                                $perfdata .= "PktsInDiscard=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInDiscard}c;;;0; "
                                    if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInDiscard});
                                $perfdata .= "PktsOutDiscard=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutDiscard}c;;;0; "
                                    if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutDiscard});
                                if ($ghOptions{'pkt'}) {
                                    $perfdata .= "PktsInUcast=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInUcast}c;;;0; "
                                        if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInUcast});
                                    $perfdata .= "PktsOutUcast=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutUcast}c;;;0; "
                                        if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutUcast});
                                    $perfdata .= "PktsInNUcast=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInNUcast}c;;;0; "
                                        if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInNUcast});
                                    $perfdata .= "PktsOutNUcast=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutNUcast}c;;;0; "
                                        if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutNUcast});
                                }
                            }
                        }

                        logger(2, "collected perfdata: $Name\t$perfdata");
                        $gPerfdata .= "$perfdata";
                    }
                # using portperfunit "bps" : calculated bit per second
                } elsif ($ghOptions{'portperfunit'} eq "bps") {
                    if ($grefhCurrent->{MD}->{If}->{$Name}->{ExcludedTrack} eq "false"
                      and defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{OctetsIn}
                      and defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{OctetsOut}
                      and $grefhCurrent->{If}->{$Name}->{ifLoadExceedIfSpeed} eq "false") {
                        my $port = sprintf("%s", $InterfaceIndex);
                        my $servicename = "If_" . trim(denormalize($Name));
                        $servicename =~ s/#//g;
                        $servicename =~ s/[: ]/_/g;
                        $servicename =~ s/[()'"]//g;
                        $servicename =~ s/,/./g;
                        my $perfdata = "";
                        #Add interface status if available
                        if ($ghOptions{'nodetype'} eq 'bigip' and defined $grefhCurrent->{If}->{$Name}->{ifStatus}) {
                            $perfdata .= "${servicename}::check_interface_table_port_bigip::" . # servicename::plugin
                                "Status=$grefhCurrent->{If}->{$Name}->{ifStatusNumber};;;0; ";
                            my ($warning_bps, $critical_bps, $maximum_bps) = ('','','');
                            unless ($ghOptions{'perfdatathreshold'} eq 'globalonly') {
                                $warning_bps = ($grefhCurrent->{If}->{$Name}->{bpsWarn}) ? $grefhCurrent->{If}->{$Name}->{bpsWarn} : '';
                                $critical_bps = ($grefhCurrent->{If}->{$Name}->{bpsCrit}) ? $grefhCurrent->{If}->{$Name}->{bpsCrit} : '';
                                $maximum_bps = ($grefhCurrent->{If}->{$Name}->{bpsMax}) ? $grefhCurrent->{If}->{$Name}->{bpsMax} : '';
                            }
                            $perfdata .= "BpsIn=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{OctetsIn}*8 .";$warning_bps;$critical_bps;0;$maximum_bps ";
                            $perfdata .= "BpsOut=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{OctetsOut}*8 .";$warning_bps;$critical_bps;0;$maximum_bps ";
                            #Add pkt errors/discards if available and wanted
                            unless ($ghOptions{'perfdataformat'} eq 'loadonly') {
                                my ($warning_pkterr, $critical_pkterr, $warning_pktdrop, $critical_pktdrop) = ('','','','');
                                if ($ghOptions{'perfdatathreshold'} eq 'full') {
                                    $warning_pkterr = ($ghOptions{'warning-pkterr'} >= 0) ? $ghOptions{'warning-pkterr'} : '';
                                    $critical_pkterr = ($ghOptions{'critical-pkterr'} >= 0) ? $ghOptions{'critical-pkterr'} : '';
                                    $warning_pktdrop = ($ghOptions{'warning-pktdrop'} >= 0) ? $ghOptions{'warning-pktdrop'} : '';
                                    $critical_pktdrop = ($ghOptions{'critical-pktdrop'} >= 0) ? $ghOptions{'critical-pktdrop'} : '';
                                }
                                $perfdata .= "PpsInErr=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInErr}*1 .";$warning_pkterr;$critical_pkterr;0; " 
                                    if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInErr});
                                $perfdata .= "PpsOutErr=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutErr}*1 .";$warning_pkterr;$critical_pkterr;0; " 
                                    if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutErr});
                                $perfdata .= "PpsInDrop=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInDrop}*1 .";$warning_pktdrop;$critical_pktdrop;0; " 
                                    if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInDrop});
                                $perfdata .= "PpsOutDrop=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutDrop}*1 .";$warning_pktdrop;$critical_pktdrop;0; " 
                                    if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutDrop});
                            }
                        } elsif (defined $grefhCurrent->{If}->{$Name}->{ifOperStatus}) {
                            $perfdata .= "${servicename}::check_interface_table_port::" . # servicename::plugin
                                "OperStatus=$grefhCurrent->{If}->{$Name}->{ifOperStatusNumber};;;0; ";
                            my ($warning_bps, $critical_bps, $maximum_bps) = ('','','');
                            unless ($ghOptions{'perfdatathreshold'} eq 'globalonly') {
                                $warning_bps = ($grefhCurrent->{If}->{$Name}->{bpsWarn}) ? $grefhCurrent->{If}->{$Name}->{bpsWarn} : '';
                                $critical_bps = ($grefhCurrent->{If}->{$Name}->{bpsCrit}) ? $grefhCurrent->{If}->{$Name}->{bpsCrit} : '';
                                $maximum_bps = ($grefhCurrent->{If}->{$Name}->{bpsMax}) ? $grefhCurrent->{If}->{$Name}->{bpsMax} : '';
                            }
                            $perfdata .= "BpsIn=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{OctetsIn}*8 .";$warning_bps;$critical_bps;0;$maximum_bps ";
                            $perfdata .= "BpsOut=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{OctetsOut}*8 .";$warning_bps;$critical_bps;0;$maximum_bps ";
                            #Add pkt errors/discards if available and wanted
                            unless ($ghOptions{'perfdataformat'} eq 'loadonly') {
                                my ($warning_pkterr, $critical_pkterr, $warning_pktdiscard, $critical_pktdiscard) = ('','','','');
                                if ($ghOptions{'perfdatathreshold'} eq 'full') {
                                    $warning_pkterr = ($ghOptions{'warning-pkterr'} >= 0) ? $ghOptions{'warning-pkterr'} : '';
                                    $critical_pkterr = ($ghOptions{'critical-pkterr'} >= 0) ? $ghOptions{'critical-pkterr'} : '';
                                    $warning_pktdiscard = ($ghOptions{'warning-pktdiscard'} >= 0) ? $ghOptions{'warning-pktdiscard'} : '';
                                    $critical_pktdiscard = ($ghOptions{'critical-pktdiscard'} >= 0) ? $ghOptions{'critical-pktdiscard'} : '';
                                }
                                $perfdata .= "PpsInErr=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInErr}*1 .";$warning_pkterr;$critical_pkterr;0; " 
                                    if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInErr});
                                $perfdata .= "PpsOutErr=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutErr}*1 .";$warning_pkterr;$critical_pkterr;0; " 
                                    if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutErr});
                                $perfdata .= "PpsInDiscard=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInDiscard}*1 .";$warning_pktdiscard;$critical_pktdiscard;0; " 
                                    if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInDiscard});
                                $perfdata .= "PpsOutDiscard=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutDiscard}*1 .";$warning_pktdiscard;$critical_pktdiscard;0; " 
                                    if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutDiscard});
                                if ($ghOptions{'pkt'}) {
                                    $perfdata .= "PpsInUcast=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInUcast}*1 .";;;0; "
                                        if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInUcast});
                                    $perfdata .= "PpsOutUcast=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutUcast}*1 .";;;0; "
                                        if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutUcast});
                                    $perfdata .= "PpsInNUcast=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInNUcast}*1 .";;;0; "
                                        if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInNUcast});
                                    $perfdata .= "PpsOutNUcast=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutNUcast}*1 .";;;0; "
                                        if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutNUcast});
                                }
                            }
                        }

                        logger(2, "collected perfdata: $Name\t$perfdata");
                        $gPerfdata .= "$perfdata";
                    }
                }
            }
        }
        # write perfdata to a spoolfile in perfdatadir instead of in plugin output
        if($ghOptions{'perfdatadir'}) {
            if(!defined($ghOptions{perfdataservicedesc})) {
                ExitPlugin($ERRORS{"UNKNOWN"}, "please specify --perfdataservicedesc when you want to use --perfdatadir to output perfdata.");
            }
            # PNP Data example: (without the linebreaks)
            # DATATYPE::SERVICEPERFDATA\t
            # TIMET::$TIMET$\t
            # HOSTNAME::$HOSTNAME$\t                       -| this relies on getting the same hostname as in Icinga from -H or -h
            # SERVICEDESC::$SERVICEDESC$\t
            # SERVICEPERFDATA::$SERVICEPERFDATA$\t
            # SERVICECHECKCOMMAND::$SERVICECHECKCOMMAND$\t -| not needed (interfacetables uses own templates)
            # HOSTSTATE::$HOSTSTATE$\t                     -|
            # HOSTSTATETYPE::$HOSTSTATETYPE$\t              | not available here
            # SERVICESTATE::$SERVICESTATE$\t                | so its skipped
            # SERVICESTATETYPE::$SERVICESTATETYPE$         -|

            # build the output
            my $lPerfoutput;
            $lPerfoutput .= "DATATYPE::SERVICEPERFDATA\tTIMET::$STARTTIME";
            $lPerfoutput .= "\tHOSTNAME::".$ghOptions{'hostdisplay'};
            $lPerfoutput .= "\tSERVICEDESC::".$ghOptions{perfdataservicedesc};
            $lPerfoutput .= "\tSERVICEPERFDATA::".$gPerfdata;
            $lPerfoutput .= "\n";

            # delete the perfdata so it is not printed to Nagios/Icinga
            $gPerfdata = "";

            # flush to spoolfile
            my $filename = $ghOptions{perfdatadir} . "/interfacetables_v3t.$STARTTIME";
            umask "$UMASK";
            open (OUT,">>$filename") or die "cannot open $filename $!";
            flock (OUT, 2) or die "cannot flock $filename ($!)"; # get exclusive lock;
            print OUT $lPerfoutput;
            close(OUT);
        }

    #------  Nagiosgrapher  ------#
    } elsif ( $ghOptions{'grapher'} eq  "nagiosgrapher" ) {

        # Set the perfdata file
        my $filename = $ghOptions{perfdatadir} . "/service-perfdata.$STARTTIME";
        umask "$UMASK";
        open (OUT,">>$filename") or die "cannot open $filename $!";
        flock (OUT, 2) or die "cannot flock $filename ($!)"; # get exclusive lock;

        # plugin related stats
        print OUT "$grefhCurrent->{MD}->{Node}->{sysName}\t";  # hostname
        print OUT "Interface_global";                  # servicename
        print OUT "\t\t";                              # pluginoutput
        print OUT "time=${RUNTIME_HR}s;;;; ";            # performancedata
        print OUT "uptime=$grefhCurrent->{MD}->{Node}->{sysUpTime}s;;;; ";
        print OUT "watched=${gNumberOfPerfdataInterfaces};;;; ";
        print OUT "useddelta=${gUsedDelta}s;;;; ";
        print OUT "ports=${gNumberOfInterfacesWithoutTrunk};;;; ";
        print OUT "freeports=${gNumberOfFreeInterfaces};;;; ";
        print OUT "adminupfree=${gNumberOfFreeUpInterfaces};;;; ";
        print OUT "\t$STARTTIME\n";                    # unix timestamp

        # interface status, and interface load stats
        unless ($ghOptions{'perfdataformat'} eq 'globalonly') {

            # $grefaAllIndizes is a indexed and sorted list of all interfaces
            for my $InterfaceIndex (@$grefaAllIndizes) {
                # Get normalized interface name (key for If data structure)
                my $Name = $grefhCurrent->{MD}->{Map}->{IndexToName}->{$InterfaceIndex};
                    
                if ($ghOptions{'portperfunit'} eq "bit") {
                    if ($grefhCurrent->{MD}->{If}->{$Name}->{ExcludedTrack} eq "false"
                      and defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{OctetsIn}
                      and defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{OctetsOut}
                      and $grefhCurrent->{If}->{$Name}->{ifLoadExceedIfSpeed} eq "false") {
                        my $servicename = "If_" . trim(denormalize($Name));
                        $servicename =~ s/#//g;
                        $servicename =~ s/[: ]/_/g;
                        $servicename =~ s/[()'"]//g;
                        $servicename =~ s/,/./g;
                        my $perfdata = "";
                        #Add interface status if available
                        if ($ghOptions{'nodetype'} eq 'bigip' and defined $grefhCurrent->{If}->{$Name}->{ifStatus}) {
                            $perfdata .= "${servicename}::check_interface_table_port_bigip::" . # servicename::plugin
                                "Status=$grefhCurrent->{If}->{$Name}->{ifStatusNumber};;;0; " .
                                "BitsIn=". $grefhCurrent->{MD}->{IfCounters}->{$Name}->{OctetsIn}*8 ."c;;;0; " .
                                "BitsOut=". $grefhCurrent->{MD}->{IfCounters}->{$Name}->{OctetsOut}*8 ."c;;;0; ";
                            #Add pkt errors/discards if available and wanted
                            unless ($ghOptions{'perfdataformat'} eq 'loadonly') {
                                $perfdata .= "PktsInErr=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInErr}c;;;0; "
                                    if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInErr});
                                $perfdata .= "PktsOutErr=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutErr}c;;;0; "
                                    if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutErr});
                                $perfdata .= "PktsInDrop=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInDrop}c;;;0; "
                                    if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInDrop});
                                $perfdata .= "PktsOutDrop=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutDrop}c;;;0; "
                                    if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutDrop});
                            }
                        } elsif (defined $grefhCurrent->{If}->{$Name}->{ifOperStatus}) {
                            $perfdata .= "${servicename}::check_interface_table_port::" . # servicename::plugin
                                "OperStatus=$grefhCurrent->{If}->{$Name}->{ifOperStatusNumber};;;0; " .
                                "BitsIn=". $grefhCurrent->{MD}->{IfCounters}->{$Name}->{OctetsIn}*8 ."c;;;0; " .
                                "BitsOut=". $grefhCurrent->{MD}->{IfCounters}->{$Name}->{OctetsOut}*8 ."c;;;0; ";
                            #Add pkt errors/discards if available and wanted
                            unless ($ghOptions{'perfdataformat'} eq 'loadonly') {
                                $perfdata .= "PktsInErr=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInErr}c;;;0; "
                                    if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInErr});
                                $perfdata .= "PktsOutErr=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutErr}c;;;0; "
                                    if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutErr});
                                $perfdata .= "PktsInDiscard=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInDiscard}c;;;0; "
                                    if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInDiscard});
                                $perfdata .= "PktsOutDiscard=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutDiscard}c;;;0; "
                                    if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutDiscard});
                                if ($ghOptions{'pkt'}) {
                                    $perfdata .= "PktsInUcast=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInUcast}c;;;0; "
                                        if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInUcast});
                                    $perfdata .= "PktsOutUcast=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutUcast}c;;;0; "
                                        if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutUcast});
                                    $perfdata .= "PktsInNUcast=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInNUcast}c;;;0; "
                                        if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsInNUcast});
                                    $perfdata .= "PktsOutNUcast=$grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutNUcast}c;;;0; "
                                        if (defined $grefhCurrent->{MD}->{IfCounters}->{$Name}->{PktsOutNUcast});
                                }
                            }
                        }

                        # Print into perfdata output file
                        logger(2, "collected perfdata: $Name\t$perfdata");
                        print OUT "$grefhCurrent->{MD}->{Node}->{sysName}\t";  # hostname
                        print OUT "$servicename";                      # servicename
                        print OUT "\t\t";                              # pluginoutput
                        if ($ghOptions{'alias'} and $grefhFile->{If}->{$Name}->{ifAlias} ne '') {
                            print OUT ' ' . trim(denormalize($grefhFile->{If}->{$Name}->{ifAlias}));
                        }
                        print OUT "$perfdata";                         # performancedata
                        print OUT "\t$STARTTIME\n";                    # unix timestamp
                    }
                    
                } elsif ($ghOptions{'portperfunit'} eq "bps") {
                    if ($grefhCurrent->{MD}->{If}->{$Name}->{ExcludedTrack} eq "false"
                      and defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{OctetsIn}
                      and defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{OctetsOut}
                      and $grefhCurrent->{If}->{$Name}->{ifLoadExceedIfSpeed} eq "false") {
                        my $servicename = "If_" . trim(denormalize($Name));
                        $servicename =~ s/#//g;
                        $servicename =~ s/[: ]/_/g;
                        $servicename =~ s/[()'"]//g;
                        $servicename =~ s/,/./g;
                        my $perfdata = "";
                        #Add interface status if available
                        if ($ghOptions{'nodetype'} eq 'bigip' and defined $grefhCurrent->{If}->{$Name}->{ifStatus}) {
                            $perfdata .= "${servicename}::check_interface_table_port_bigip::" . # servicename::plugin
                                "Status=$grefhCurrent->{If}->{$Name}->{ifStatusNumber};;;0; ";
                            my ($warning_bps, $critical_bps, $maximum_bps) = ('','','');
                            unless ($ghOptions{'perfdatathreshold'} eq 'globalonly') {
                                $warning_bps = ($grefhCurrent->{If}->{$Name}->{bpsWarn}) ? $grefhCurrent->{If}->{$Name}->{bpsWarn} : '';
                                $critical_bps = ($grefhCurrent->{If}->{$Name}->{bpsCrit}) ? $grefhCurrent->{If}->{$Name}->{bpsCrit} : '';
                                $maximum_bps = ($grefhCurrent->{If}->{$Name}->{bpsMax}) ? $grefhCurrent->{If}->{$Name}->{bpsMax} : '';
                            }
                            $perfdata .= "BpsIn=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{OctetsIn}*8 .";$warning_bps;$critical_bps;0;$maximum_bps ";
                            $perfdata .= "BpsOut=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{OctetsOut}*8 .";$warning_bps;$critical_bps;0;$maximum_bps ";
                            #Add pkt errors/discards if available and wanted
                            unless ($ghOptions{'perfdataformat'} eq 'loadonly') {
                                my ($warning_pkterr, $critical_pkterr, $warning_pktdrop, $critical_pktdrop) = ('','','','');
                                if ($ghOptions{'perfdatathreshold'} eq 'full') {
                                    $warning_pkterr = ($ghOptions{'warning-pkterr'} >= 0) ? $ghOptions{'warning-pkterr'} : '';
                                    $critical_pkterr = ($ghOptions{'critical-pkterr'} >= 0) ? $ghOptions{'critical-pkterr'} : '';
                                    $warning_pktdrop = ($ghOptions{'warning-pktdrop'} >= 0) ? $ghOptions{'warning-pktdrop'} : '';
                                    $critical_pktdrop = ($ghOptions{'critical-pktdrop'} >= 0) ? $ghOptions{'critical-pktdrop'} : '';
                                }
                                $perfdata .= "PpsInErr=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInErr}*1 .";$warning_pkterr;$critical_pkterr;0; " 
                                    if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInErr});
                                $perfdata .= "PpsOutErr=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutErr}*1 .";$warning_pkterr;$critical_pkterr;0; " 
                                    if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutErr});
                                $perfdata .= "PpsInDrop=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInDrop}*1 .";$warning_pktdrop;$critical_pktdrop;0; " 
                                    if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInDrop});
                                $perfdata .= "PpsOutDrop=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutDrop}*1 .";$warning_pktdrop;$critical_pktdrop;0; " 
                                    if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutDrop});
                            }
                        } elsif (defined $grefhCurrent->{If}->{$Name}->{ifOperStatus}) {
                            $perfdata .= "${servicename}::check_interface_table_port::" . # servicename::plugin
                                "OperStatus=$grefhCurrent->{If}->{$Name}->{ifOperStatusNumber};;;0; ";
                            my ($warning_bps, $critical_bps, $maximum_bps) = ('','','');
                            unless ($ghOptions{'perfdatathreshold'} eq 'globalonly') {
                                $warning_bps = ($grefhCurrent->{If}->{$Name}->{bpsWarn}) ? $grefhCurrent->{If}->{$Name}->{bpsWarn} : '';
                                $critical_bps = ($grefhCurrent->{If}->{$Name}->{bpsCrit}) ? $grefhCurrent->{If}->{$Name}->{bpsCrit} : '';
                                $maximum_bps = ($grefhCurrent->{If}->{$Name}->{bpsMax}) ? $grefhCurrent->{If}->{$Name}->{bpsMax} : '';
                            }
                            $perfdata .= "BpsIn=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{OctetsIn}*8 .";$warning_bps;$critical_bps;0;$maximum_bps ";
                            $perfdata .= "BpsOut=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{OctetsOut}*8 .";$warning_bps;$critical_bps;0;$maximum_bps ";
                            #Add pkt errors/discards if available and wanted
                            unless ($ghOptions{'perfdataformat'} eq 'loadonly') {
                                my ($warning_pkterr, $critical_pkterr, $warning_pktdiscard, $critical_pktdiscard) = ('','','','');
                                if ($ghOptions{'perfdatathreshold'} eq 'full') {
                                    $warning_pkterr = ($ghOptions{'warning-pkterr'} >= 0) ? $ghOptions{'warning-pkterr'} : '';
                                    $critical_pkterr = ($ghOptions{'critical-pkterr'} >= 0) ? $ghOptions{'critical-pkterr'} : '';
                                    $warning_pktdiscard = ($ghOptions{'warning-pktdiscard'} >= 0) ? $ghOptions{'warning-pktdiscard'} : '';
                                    $critical_pktdiscard = ($ghOptions{'critical-pktdiscard'} >= 0) ? $ghOptions{'critical-pktdiscard'} : '';
                                }
                                $perfdata .= "PpsInErr=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInErr}*1 .";$warning_pkterr;$critical_pkterr;0; " 
                                    if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInErr});
                                $perfdata .= "PpsOutErr=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutErr}*1 .";$warning_pkterr;$critical_pkterr;0; " 
                                    if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutErr});
                                $perfdata .= "PpsInDiscard=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInDiscard}*1 .";$warning_pktdiscard;$critical_pktdiscard;0; " 
                                    if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInDiscard});
                                $perfdata .= "PpsOutDiscard=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutDiscard}*1 .";$warning_pktdiscard;$critical_pktdiscard;0; "
                                    if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutDiscard});
                                if ($ghOptions{'pkt'}) {
                                    $perfdata .= "PpsInUcast=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInUcast}*1 .";;;0; "
                                        if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInUcast});
                                    $perfdata .= "PpsOutUcast=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutUcast}*1 .";;;0; "
                                        if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutUcast});
                                    $perfdata .= "PpsInNUcast=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInNUcast}*1 .";;;0; "
                                        if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsInNUcast});
                                    $perfdata .= "PpsOutNUcast=". $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutNUcast}*1 .";;;0; "
                                        if (defined $grefhCurrent->{MD}->{IfStats}->{$Name}->{PktsOutNUcast});
                                }
                            }
                        }

                        # Print into perfdata output file
                        logger(2, "collected perfdata: $Name\t$perfdata");
                        print OUT "$grefhCurrent->{MD}->{Node}->{sysName}\t";  # hostname
                        print OUT "$servicename";                      # servicename
                        print OUT "\t\t";                              # pluginoutput
                        if ($ghOptions{'alias'} and $grefhFile->{If}->{$Name}->{ifAlias} ne '') {
                            print OUT ' ' . trim(denormalize($grefhFile->{If}->{$Name}->{ifAlias}));
                        }
                        print OUT "$perfdata";                         # performancedata
                        print OUT "\t$STARTTIME\n";                    # unix timestamp
                    }
                }
            } # for $InterfaceIndex
        }

        # close the perfdata output file
        close (OUT);
    }
    return 0;
}

# ------------------------------------------------------------------------
# TimeDiff
# ------------------------------------------------------------------------
# Description: calculate time diff of unix epoch seconds and return it in
# a readable format
#
# my $x = TimeDiff ("1150100854","1150234567");
# print $x;   # $x equals to 1d 13h 8m
#
# ------------------------------------------------------------------------
sub TimeDiff {
    my ($StartTime, $EndTime, $warn, $crit) = @_;

    my $Days  = 0;
    my $Hours = 0;
    my $Min   = 0;
    my $Status   = $ERRORS{'UNKNOWN'};
    my $TimeDiff = $EndTime - $StartTime;

    my $Rest;

    my $String = "(NoData)"; # default text (unknown/error)

    # check start not 0
    if ($StartTime == 0) {
        return wantarray ? ('(NoData)', $ERRORS{'UNKNOWN'}) : '(NoData)';
    }

    # check start must be before end
    if ($EndTime < $StartTime) {
        return wantarray ? ('(NoData)', $ERRORS{'UNKNOWN'}) : '(NoData)';
    }

    # check if there is no traffic for $crit or $warn seconds
    if (defined $warn and defined $crit) {
        if ($TimeDiff > $crit) {
            $Status = $ERRORS{'CRITICAL'};
        } elsif ($TimeDiff > $warn) {
            $Status = $ERRORS{'WARNING'};
        } else {
            $Status = $ERRORS{'OK'};
        }
    } else {
        $Status = $ERRORS{'OK'};
    }

    $Days = int ($TimeDiff / 86400);
    $Rest = $TimeDiff - ($Days * 86400);

    if ($Rest < 0) {
        $Days = 0;
        $Hours = int ($TimeDiff / 3600);
    } else {
        $Hours = int ($Rest / 3600);
    }

    $Rest = $Rest - ($Hours * 3600);

    if ($Rest < 0) {
        $Hours = 0;
        $Min = int ($TimeDiff / 60);
    } else {
        $Min = int ($Rest / 60);
    }

    #logger(1, "warn: $warn, crit: $crit, diff: $TimeDiff, status: $Status");
    return wantarray ? ("${Days}d ${Hours}h ${Min}m", $Status) : "${Days}d ${Hours}h ${Min}m";
}

# ------------------------------------------------------------------------
# Colorcode
# ------------------------------------------------------------------------
# Description: colorcode function to give a html color code between green
# and red for a given percent value
# ------------------------------------------------------------------------
sub Colorcode {
    my $current = shift;
    my $warning = shift;
    my $critical = shift;
    my $colorcode;

    # just traffic light color codes for the lame
    if ($current < $warning) {            # green / ok
        $colorcode = 'green';
    } elsif ($current < $critical) {       # yellow / warn
        $colorcode = 'yellow';
    } else {                          # red / crit
        $colorcode = 'red';
    }

    if ($ghOptions{'ifloadgradient'}) {
        # its cool to have a gradient from green over yellow to red representing the percent value
        # the gradient goes from
        #   #00FF00 (green) at 0 % over
        #   #FFFF00 (yellow) at $warn % to
        #   #FF0000 (red) at $crit % and over

        # first adjust the percent value according to the given warning and critical levels
        my $green  = 255;
        my $red    = 0;
        if ($current > 0) {
            if (($current <= $warning) && ($current < $critical)) {
                $green  = 255;
                $red    = $current * 255 / $warning;
            } elsif ($current <= $critical) {
                $green  = 255 - ( $current * 255 / $critical );
                $red    = 255;
            } elsif ($current > $critical) {
                $green  = 0;
                $red    = 255;
            }
        }
        $colorcode = sprintf "%2.2x%2.2x%2.2x", $red, $green, 0;
        logger(3, " colorcode: $colorcode, current: $current, red: $red, green: $green");
    }
    return $colorcode;
}


# ------------------------------------------------------------------------------
# ExitPlugin
# ------------------------------------------------------------------------------
# Description: print correct output text and exit this plugin now
# ------------------------------------------------------------------------------
sub ExitPlugin {

    my $code = shift;
    my $output = shift;
    my $htmltablefile = $ghOptions{'htmltabledir'} . "/" . $gFile . ".html";
    chomp($output);
    
    # Append errorcode string prefix to text
    if (defined $ERRORCODES{"$code"}) {
        $output = $ERRORCODES{"$code"}." - ".$output;
    } else {
        $output = "UNKNOWN - ".$output;
    }

    # Append html table link to text
    if (-e $htmltablefile) {
        $output = $output.' <a href=' . $ghOptions{'htmltableurl'} . "/" . $gFile . ".html" . ' target='.$ghOptions{'htmltablelinktarget'}.'>[details]</a>';
    }

    print $output;

    # Append performance data
    print " | $gPerfdata" if ($ghOptions{'enableperfdata'} and $gBasetime and $gPerfdata);
    print "\n";

    # Troubleshooting
    #print "grefhCurrent: \n".Dumper($grefhCurrent);
    #print "\n";
    
    exit $code;
}

# ------------------------------------------------------------------------------
# add_oid_details
# ------------------------------------------------------------------------------
# Description: check a string and add the object name and the mib corresponding 
# to an oid if this one is found
# ------------------------------------------------------------------------------
sub add_oid_details {
    my $message = shift;
    my $refaohOID = shift;
    foreach my $refhOID (@{$refaohOID}) {
        $message =~ s/(\"+$refhOID->{'oid'}\"+)/$1 ($refhOID->{'name'}, mib $refhOID->{'mib'})/g;
    }
    return $message;
}


# oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
# PLUGIN COMMON FUNCTIONS
# oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

# ------------------------------------------------------------------------
# print_usage, print_defaults, print_help, print_revision, print_support
# ------------------------------------------------------------------------
# Description: various functions reporting plugin information & usages
# ------------------------------------------------------------------------
sub print_usage () {
  print <<EOUS;

  Usage:

    * basic usage:
      $PROGNAME [-vvvvv] -H <hostname/IP> [-h <host alias>] [-2] [-C <community string>]
        [--exclude <globally excluded interface list>] [--include <globally included interface list>]
        [--warning <warning load prct>,<warning pkterr/s>,<warning pktdiscard/s>]
        [--critical <critical load prct>,<critical pkterr/s>,<critical pktdiscard/s>]
        [--track-property <tracked property list>] [--include-property <property tracking interface inclusion list>]
        [--exclude-property <property tracking interface exclusion list>] [--warning-property <warning property change counter>]
        [--critical-property <critical property change counter>] [-r] [-f]

    * advanced usage:
      $PROGNAME [-vvvvv] [-t <timeout>] -H <hostname/IP> [-h <host alias>] [-2] [-C <community string>]
        [--domain <transport domain>] [-P <port>] [--nodetype <type>]
        [-e <globally excluded interface list>] [-i <globally included interface list>]
        [--et <traffic tracking interface exclusion list>] [--it <traffic tracking interface inclusion list>]
        [--wt <warning load prct>,<warning pkterr/s>,<warning pktdiscard/s>]
        [--ct <critical load prct>,<critical pkterr/s>,<critical pktdiscard/s>]
        [--tp <property list>] [--ip <property tracking interface inclusion list>] [--ep <property tracking interface exclusion list>]
        [--wp <warning property change counter>] [--cp <critical property change counter>] [-r] [-f]
        [--cachedir <caching directory>] [--statedir <state files directory>] [--(no)duplex] [--(no)stp]
        [--(no)vlan] [--accessmethod <method>[:<target>]] [--htmltabledir <system path to html interface tables>]
        [--htmltableurl <url to html interface tables>] [--htmltablelinktarget <target window>] [-d <delta>] [--ifs <separator>]
        [--cache <cache retention time>] [--reseturl <url to reset cgi>] [--(no)ifloadgradient]
        [--(no)human] [--(no)snapshot] [-g <grapher solution>] [--grapherurl <url to grapher>]
        [--portperfunit <unit>] [--perfdataformat <format>] [--perfdatathreshold <format>] [--outputshort]
        [--snmp-timeout <timeout>] [--snmp-retries <number of retries>]
        [--(no)configtable] [--(no)unixsnmp] [--debugfile=/path/to/file.debug]
        [--(no)pkt] [--(no)type]

    * other usages:
      $PROGNAME [--help | -?]
      $PROGNAME [--version | -V]
      $PROGNAME [--showdefaults | -D]

  General options:
    -?, --help
        Show this help page
    -V, --version
        Plugin version
    -v, --verbose
        Verbose mode. Can be specified multiple times to increase the verbosity (max 3 times).
    -D, --showdefaults
        Print the option default values
    --debugfile=/path/to/file.debug
        Print the debug (verbosity) to a debug file. The standard output is still used for the plugin output.

  Plugin common options:
    -H, --hostquery (required)
        Specifies the remote host to poll.
    -h, --hostdisplay (optional)
        Specifies the hostname to display in the HTML link.
        If omitted, it takes the value of
         * NAGIOS_HOSTNAME evironment variable in case environment macros are enabled in
           nagios.cfg/icinga.cfg
         * or if not the value of the hostquery variable (-H, --hostquery)
    -r, --regexp (optional)
        Interface names and property names for some other options will be interpreted as
        regular expressions.
    --outputshort (optional)
        Reduce the verbosity of the plugin output. If used, the plugin only returns
        general counts (nb ports, nb changes,...). This is close to the way the
        previous versions of the plugin was working.
        In this version of the plugin, by default the plugin returns
         + general counts (nb ports, nb changes,...)
         + what changes has been detected
         + what interface(s) suffer(s) from high load.

  Global interface inclusions/exclusions
    -e, --exclude (optional)
        * Comma separated list of interfaces globally excluded from the monitoring.
          Excluding an interface from that tracking is usually done for the interfaces that
          we don't want any tracking. For exemple:
           + virtual interfaces
           + loopback interfaces
        * Excluded interfaces are represented by black overlayed rows in the interface table
        * Excluding an interface globally will also exclude it from any tracking (traffic and
          property tracking).
    -i, --include (optional)
        * Comma separated list of interfaces globally included in the monitoring.
        * By default, all the interfaces are included.
        * There are some cases where you need to include an interface which is part
          of a group of previously excluded interfaces.
    --alias-matching (optional)
        Allow you to specify alias in addition to interface names as inclusion/exclusion 
        arguments (for global, traffic and property inclusion/exclusion).
        
  Traffic checks (load & packet errors/discards)
    --et, --exclude-traffic (optional)
        * Comma separated list of interfaces excluded from traffic checks
          (load & packet errors/discards). Can be used to exclude:
           + interfaces known as problematic (high traffic load)
        * Excluded interfaces are represented by a dark grey (css dependent)
          cell style in the interface table
    --it, --include-traffic (optional)
        * Comma separated list of interfaces included for traffic checks
          (load & packet errors/discards).
        * By default, all the interfaces are included.
        * There are some case where you need to include an interface which is part
          of a group of previously excluded interfaces.
    --wt, --warning-traffic, --warning (optional)
        * Interface traffic load percentage leading to a warning alert
        * Format:
           --warning-traffic <load%>,<pkterr/s>,<pktdiscard/s>
           ex: --warning-traffic 70,100,100
    --ct, --critical-traffic, --critical (optional)
        * Interface traffic load percentage leading to a critical alert
        * Format:
           --critical-traffic <load%>,<pkterr/s>,<pktdiscard/s>
           ex: --critical-traffic 95,1000,1000
    --(no)pkt (optional)
        Add unicast/non-unicast pkt stats for each interface. No tracking, just for statistics 
        and graphs

  Property checks (interface property changes)
    --tp, --track-property (optional)
        List of tracked properties. Values can be:
          Standard:
            * 'ifAlias'            : the interface alias
            * 'ifType'             : the type of the interface (as specified by the IANA)
            * 'ifAdminStatus'      : the administrative status of the interface
            * 'ifOperStatus'       : the operational status of the interface
            * 'ifSpeedReadable'    : the speed of the interface
            * 'ifStpState'         : the Spanning Tree state of the interface
            * 'ifDuplexStatus'     : the operation mode of the interface (duplex mode)
            * 'ifVlanNames'        : the vlan on which the interface was associated
            * 'ifIpInfo'           : the ip configuration for the interface
          Netscreen specific:
            * 'nsIfZone'           : the security zone name an interface belongs to
            * 'nsIfVsys'           : the virtual system name an interface belongs to
            * 'nsIfMng'            : the management protocols permitted on the interface
        Default is 'ifOperStatus' only
        Exemple: --tp='ifOperStatus,nsIfMng'
    --ep, --exclude-property (optional)
        * Comma separated list of interfaces excluded from the property tracking.
        * For the 'ifOperStatus' property, the exclusion of an interface is usually
          done when the interface can be down for normal reasons (ex: interfaces
          connected to printers sometime in standby mode)
        * Excluded interfaces are represented by a dark grey (css dependent)
          cell style in the interface table
    --ip, --include-property (optional)
        * Comma separated list of interfaces included in the property tracking.
        * By default, all the interfaces that are tracked are included.
        * There are some case where you need to include an interface which is part
          of a group of previously excluded interfaces.
    --wp, --warning-property (optional)
        Number of property changes before leading to a warning alert
    --cp, --critical-property (optional)
        Number of property changes before leading to a critical alert

  Snmp options:
    -C, --community (required)
        Specifies the snmp v1/v2c community string.
    -2, --v2c
        Use snmp v2c
    -l, --login=LOGIN ; -x, --passwd=PASSWD
        Login and auth password for snmpv3 authentication
        If no priv password exists, implies AuthNoPriv
    -X, --privpass=PASSWD
        Priv password for snmpv3 (AuthPriv protocol)
    -L, --protocols=<authproto>,<privproto>
        <authproto> : Authentication protocol (md5|sha : default md5)
        <privproto> : Priv protocole (des|aes : default des)
    --domain
        SNMP transport domain. Can be: udp (default), tcp, udp6, tcp6.
        Specifying a transport domain also change the default port according
        to that selected transport domain. Use --port to overwrite the port.
    --contextname
        Context name for the snmp requests (snmpv3 only)
    -P, --port=PORT
        SNMP port (Default 161)
    --64bits
        Use SNMP 64-bits counters. Use it when your target device support it, to be able to 
        monitor high (>=1Gbps) bandwidth usage.
    --max-repetitions=integer
        Available only for snmp v2c/v3. Increasing this value may enhance snmp query performances
        by gathering more results at one time. Setting it to 1 would disable the use of get-bulk.
    --snmp-timeout
        Define the Transport Layer timeout for the snmp queries (default is 2s). Value can be from
        1 to 60. Note: multiply it by the snmp-retries+1 value to calculate the complete timeout.
    --snmp-retries
        Define the number of times to retry sending a SNMP message (default is 2). Value can be
        from 0 to 20.
    --(no)unixsnmp
        Use unix snmp utilities for snmp requests (table/bulk requests), in place of perl bindings
        Default is to use perl bindings

  Graphing options:
    -f, --enableperfdata (optional)
        Enable port performance data, default is port perfdata disabled
    --perfdataformat (optional)
        Define which performance data will be generated.
        Can be:
         * full : generated performance data include plugin related stats,
                  interface status, interface load stats, and packet error stats
         * loadonly : generated performance data include plugin related stats,
                      interface status, and interface load stats
         * globalonly : generated performance data include only plugin related stats
        Default is full.
        'loadonly' should be used in case of too many interfaces and consequently too much performance
        data which cannot fit in the nagios plugin output buffer. By default, its size is 8k and
        can be extended by modifying MAX_PLUGIN_OUTPUT_LENGTH in the nagios sources.
    --perfdatathreshold (optional)
        Define which thresholds are printed in the generated performance data.
        Can be:
         * full : thresholds in the generated performance data are generated for include plugin 
                  related stats, interface load stats, and packet error stats
         * loadonly : thresholds in the generated performance data include plugin related stats 
                  and interface load stats
         * globalonly : thresholds in the generated performance data include only plugin related stats
        Default is full.
        'loadonly' or 'globalonly' could be used in case of a too long plugin output producing problems 
        with nagios/icinga's buffers.
    --perfdatadir (optional)
        When specified, the performance data are also written directly to a file, in the specified
        location. Please use the same hostname as in Icinga/Nagios for -H or -h.
    --perfdataservicedesc (optional)
        Specify additional parameters for output performance data to PNP
        (only used when using --perfdatadir and --grapher pnp4nagios). Optional in case environment
        macros are enabled in nagios.cfg/icinga.cfg
    -g, --grapher (optional)
        Specify the used graphing solution.
        Can be pnp4nagios, nagiosgrapher, netwaysgrapherv2 or ingraph.
    --grapherurl (optional)
        Graphing system url. Default values are:
        Ex: /pnp4nagios
    --portperfunit (optional)
        In/out traffic in perfdata could be reported in bits (counters) or in bps (calculated value).
        Using bps avoid abnormal load values to be plotted on the graphs.
        !!! WARNING !!!
        switching from one mode to the other require the change of the Data Source Type (DST) in the rrd 
        files already generated by pnp4nagios (or similar action for the other graphing solutions)
        !!! WARNING !!!
        Possible values: bit or bps (default)

  Other options:
    --cachedir (optional)
        Sets the directory where snmp responses are cached.
    --statedir (optional)
        Sets the directory where the interface states are stored.
    --nodetype (optional)
        Specify the node type, for specific information to be printed / specific oids to be used
        Possible nodetypes are: standard (default), cisco, hp, netscreen, netapp, bigip, bluecoat, brocade, brocade-nos, nortel.
    --(no)duplex (optional)
        Add the duplex mode property for each interface in the interface table.
    --(no)stp (optional)
        Add the stp state property for each interface in the interface table.
        BE AWARE that it based on the dot1base mib, which is incomplete in specific cases:
         * Cisco device using pvst / multiple vlan stp
    --(no)vlan (optional)
        Add the vlan attribution property for each interface in the interface table.
         This option is available only for the following nodetypes: cisco, hp, nortel
    --(no)ipinfo (optional)
        Add the ip information for each interface in the interface table.
    --(no)alias (optional)
        Add the alias information for each interface in the interface table.
    --accessmethod (optional)
        Access method for a shortcut to the host in the HTML page.
        Format is : <method>[:<target>]
        Where method can be: ssh, telnet, http or https.
        Ex: --accessmethod="http:http://my_netapp_fas/na_admin"
        Can be called multiple times for multiple shortcuts.
    --htmltabledir (optional)
        Specifies the directory in the file system where HTML interface table are stored.
    --htmltableurl (optional)
        Specifies the URL by which the interface table are accessible.
    --htmltablelinktarget (optional)
        Specifies the windows or the frame where the [details] link will load the generated html page.
        Possible values are: _blank, _self, _parent, _top, or a frame name. Default is _self. For
        exemple, can be set to _blank to open the details view in a new window.
    --delta | -d (optional)
        Set the delta used for interface throuput calculation. In seconds.
    --ifs (optional)
        Input field separator. The specified separator is used for all options allowing
        a list to be specified.
    --cache (optional)
        Define the retention time of the cached data. In seconds.
    --reseturl (optional)
        Specifies the URL to the tablereset program.
    --(no)ifloadgradient (optional)
        Enable color gradient from green over yellow to red for the load percentage
        representation. Default is enabled.
    --(no)human (optional)
        Translate bandwidth usage in human readable format (G/M/K bps). Default is enabled.
    --(no)snapshot (optional)
        Force the plugin to run like if it was the first launch. Cached data will be
        ignored. Default is enabled.
    --timeout | -t (optional)
        Define the global timeout limit of the plugin. By default, the nagios plugin
        global timeout is taken (default is 15s)
    --css (optional)
        Define the css stylesheet used by the generated html files.
        Can be: classic, icinga, icinga-alternate1 or nagiosxi
    --config (optional)
        Specify a config file to load.
    --(no)configtable
        Enable/disable configuration table on the generated HTML page. Also, if enabled, the
        globally excluded interfaces are not shown in the interface table anymore (interesting in
        case of lots of excluded interfaces)
        Enabled by default.
    --(no)tips
        Enable/disable the tips in the generated html tables
    --default-table-sorting (optional)
        Default table sorting, can be index (default) or name.
    --table-split (optional)
        Generate multiple interface tables, one per interface type.
    --(no)type (optional)
        Add the interface type for each interface.

  Notes:
    - For options --exclude, --include, --exclude-traffic, --include-traffic, --track-property,
      --exclude-property, --include-property and --accessmethod:
       * These options can be used multiple times, the lists of interfaces/properties
         will be concatenated.
       * The separator can be changed using the --ifs option.

EOUS

}
sub print_defaults () {
  print "\nDefault option values:\n";
  print "----------------------\n\n";
  print "General options:\n\n";
  print Dumper(\%ghOptions);
  print "\nSnmp options:\n\n";
  print Dumper(\%ghSNMPOptions);
}
sub print_help () {
  print "Copyright (c) 2009-2013 Yannick Charton\n\n";
  print "\n";
  print "  Check various statistics of network interfaces \n";
  print "\n";
  print_usage();
  print_support();
}
sub print_revision ($$) {
  my $commandName = shift;
  my $pluginRevision = shift;
  $pluginRevision =~ s/^\$Revision: //;
  $pluginRevision =~ s/ \$\s*$//;
  print "$commandName ($pluginRevision)\n";
  print "This nagios plugin comes with ABSOLUTELY NO WARRANTY. You may redistribute\ncopies of this plugin under the terms of the GNU General Public License version 3 (GPLv3).\n";
}
sub print_support () {
  my $support='Send email to tontonitch-pro@yahoo.fr if you have questions\nregarding the use of this plugin. \nPlease include version information with all correspondence (when possible,\nuse output from the -V option of the plugin itself).\n';
  $support =~ s/@/\@/g;
  $support =~ s/\\n/\n/g;
  print $support;
}

# ------------------------------------------------------------------------
# command line options processing
# ------------------------------------------------------------------------
sub check_options () {
    my %commandline = ();
    my %configfile = ();
    my @params = (
        #------- general options --------#
        'help|?',
        'verbose|v+',
        'debugfile=s',                          # debug file
        'showdefaults|D',                       # print all option default values
        #--- plugin specific options ----#
        'hostquery|H=s',
        'hostdisplay|h=s',
        'statedir=s',                           # interface table state directory
        'accessmethod=s@',                      # access method for the link to the host in the HTML page
        'htmltabledir=s',                       # interface table HTML directory
        'htmltableurl=s',                       # interface table URL location
        'htmltablelinktarget=s',                # interface table link target attribute for the plugin output
        'alias!',                               # add alias info for each interface
        'alias-matching!',                      # interface exclusion/inclusion also check against ifAlias (not only ifDescr)
        'exclude|e=s@',                         # list of interfaces globally excluded
        'include|i=s@',                         # list of interfaces globally included
        'delta|d=i',                            # interface throuput delta in seconds
        'ifs=s',                                # input field separator
        'usemacaddr',                           # use mac address (if unique) instead of index when reformatting duplicate interface description
        'cache=s',                              # cache timer
        'reseturl=s',                           # URL to tablereset program
        'ipinfo!',                              # Add ip/netmask info for each interface
        'duplex!',                              # Add Duplex mode info for each interface
        'stp!',                                 # Add Spanning Tree Protocol info for each interface
        'vlan!',                                # Add vlan attribution info for each interface
        'type!',                                # Add interface type for each interface
        'pkt!',                                 # Add unicast/non-unicast pkt stats for each interface
        'nodetype=s',                           # Specify the node type, for specific information to be printed / specific oids to be used
                                                #  Valid nodetypes are: standard (default), cisco, hp, netscreen, netapp, bigip, bluecoat, brocade, brocade-nos, nortel.
        'ifloadgradient!',                      # color gradient from green over yellow to red representing the load percentage
        'human!',                               # translate bandwidth usage in human readable format (G/M/K bps)
        'snapshot!',
        'version|V',
        'regexp|r',
        'timeout|t=i',                          # global plugin timeout
        'outputshort',                          # the plugin only returns general counts (nb ports, nb changes,...).
                                                # By default, the plugin returns general counts (nb ports, nb changes,...)
                                                # + what changes has been detected
        #------ traffic tracking --------#
        'exclude-traffic|et=s@',                # list of interfaces excluded from the load tracking
        'include-traffic|it=s@',                # list of interfaces included in the load tracking
        'warning-traffic|warning|wt=s',
        'critical-traffic|critical|ct=s',
        #------ property tracking -------#
        'track-property|tp=s@',                 # list of tracked properties
        'exclude-property|ep=s@',               # list of interfaces excluded from the property tracking
        'include-property|ip=s@',               # list of interfaces included in the property tracking
        'warning-property|wp=i',
        'critical-property|cp=i',
        #------- performance data -------#
        'enableperfdata|f',                     # enable port performance data, default is port perfdata disabled
        'portperfunit=s',                       # bit|bps: in/out traffic in perfdata could be reported in bits or in bps
        'perfdataformat=s',                     # define which performance data will be generated.
        'perfdatathreshold=s',                  # define which thresholds should be printed in the generated performance data.
        'perfdatadir=s',                        # where to write perfdata files directly for netways nagios grapher v1
        'perfdataservicedesc=s',                # servicedescription in Nagios/Icinga so that PNP uses the correct name for its files
        'grapher|g=s',                          # graphing system. Can be pnp4nagios, nagiosgrapher, netwaysgrapherv2 or ingraph
        'grapherurl=s',                         # graphing system url. By default, this is adapted for pnp4nagios standard install: /pnp4nagios
        #-------- SNMP related ----------#
        'host=s',                               # SNMP host target
        'domain=s',                             # SNMP transport domain
        'port|P=i',                             # SNMP port
        'community|C=s',                        # Specifies the snmp v1/v2c community string.
        'v2c|2',                                # Use snmp v2c
        'login|l=s',                            # Login for snmpv3 authentication
        'passwd|x=s',                           # Password for snmpv3 authentication
        'privpass|X=s',                         # Priv password for snmpv3 (AuthPriv protocol)
        'protocols|L=s',                        # Format: <authproto>,<privproto>;
        'contextname=s',                        # context name for snmp requests
        'snmp-timeout=i',                       # timeout for snmp requests
        'snmp-retries=i',                       # retries for snmp requests
        '64bits',                               # Use 64-bits counters
        'max-repetitions=i',                    # Max-repetitions tells the get-bulk command to attempt up to M get-next operations to retrieve the remaining objects.
        'cachedir=s',                           # caching directory
        'unixsnmp!',                            # Use unix snmp utilities in some cases, in place of perl bindings
        #------- other features ---------#
        'config=s',                             # Configuration file
        'css=s',                                # Used css stylesheet
        'ifdetails',                            # Link to query interface info - not yet functional
        'configtable!',                         # Enable or not the configuration table
        'tips!',                                # Enable or not the tips
        'default-table-sorting=s',              # Default table sorting, can be index (default) or name
        'table-split!',                         # Generate multiple interface tables, one per interface type (~ifType)
        #------- deprecated options ---------#
        'cisco',                                # replaced by --nodetype=cisco
        );

    # gathering commandline options
    if (! GetOptions(\%commandline, @params)) {
        print_help();
        exit $ERRORS{UNKNOWN};
    }
    # deprecated options
    if (exists $commandline{cisco}) {
        print "Option \"--cisco\" is deprecated. Use \"--nodetype=cisco\" instead.\n";
        exit $ERRORS{UNKNOWN};
    }

    #====== Configuration hashes ======#
    # Default values: general options
    %ghOptions = (
        #------- general options --------#
        'help'                      => 0,
        'verbose'                   => 0,
        'debugfile'                 => "",
        'showdefaults'              => 0,
        #--- plugin specific options ----#
        'hostquery'                 => '',
        'hostdisplay'               => '',
        'statedir'                  => "/tmp/.ifState",
        'accessmethod'              => undef,
        'htmltabledir'              => "/usr/local/interfacetable_v3t/share/tables",
        'htmltableurl'              => "/interfacetable_v3t/tables",
        'htmltablelinktarget'       => "_self",
        'alias'                     => 0,
        'alias-matching'            => 0,
        'exclude'                   => undef,
        'include'                   => undef,
        'delta'                     => 600,
        'ifs'                       => ',',
        'usemacaddr'                => 0,
        'cache'                     => 3600,
        'reseturl'                  => "/interfacetable_v3t/cgi-bin",
        'ipinfo'                    => 1,
        'duplex'                    => 0,
        'stp'                       => 0,
        'vlan'                      => 0,
        'type'                      => 0,
        'pkt'                       => 0,
        'nodetype'                  => "standard",
        'ifloadgradient'            => 1,
        'human'                     => 1,
        'snapshot'                  => 0,
        'regexp'                    => 0,
        'timeout'                   => $TIMEOUT,
        'outputshort'               => 0,
        #------ traffic tracking --------#
        'exclude-traffic'           => undef,
        'include-traffic'           => undef,
        'warning-traffic'           => "101,1000,1000",
        'critical-traffic'          => "101,5000,5000",
        #------ property tracking -------#
        'track-property'            => ['ifOperStatus','ifStatus'],     # can be compared: ifAdminStatus, ifOperStatus, ifSpeedReadable, ifDuplexStatus, ifVlanNames, ifIpInfo
        'exclude-property'          => undef,
        'include-property'          => undef,
        'warning-property'          => 0,
        'critical-property'         => 0,
        #------- performance data -------#
        'enableperfdata'            => 0,
        'portperfunit'              => "bps",
        'perfdataformat',           => "full",
        'perfdatathreshold',        => "full",
        'perfdatadir',              => undef,
        'perfdataservicedesc',      => undef,
        'grapher'                   => "pnp4nagios",
        'grapherurl'                => "/pnp4nagios",
        #------- other features ---------#
        'config'                    => '',
        'css'                       => "icinga",             # Used css stylesheet. Can be classic, icinga or nagiosxi.
        'ifdetails'                 => 0,
        'configtable'               => 1,
        'tips'                      => 1,
        'default-table-sorting'     => "index",              # Default table sorting, can be index (default) or name
        'table-split'               => 0,
    );
    # Default values: snmp options
    %ghSNMPOptions = (
        'host'                      => "localhost",
        'domain'                    => "udp",
        'port'                      => 161,
        'community'                 => "public",
        'version'                   => "1",         # 1, 2c, 3
        'login'                     => "",
        'passwd'                    => "",
        'privpass'                  => "",
        'authproto'                 => "md5",       # md5, sha
        'privproto'                 => "des",       # des, aes
        'contextname'               => "",
        'timeout'                   => 2,
        'retries'                   => 2,
        '64bits'                    => 0,
        'max-repetitions'           => undef,
        'cachedir'                  => "/tmp/.ifCache",
        'unixsnmp'                  => 0
    );

    # process config file first, as command line options overwrite them
    if (exists $commandline{'config'}) {
        parseConfigFile("$commandline{'config'}", \%configfile);
        foreach my $key (keys %configfile) {
            if (exists $ghOptions{$key}) {
                $ghOptions{$key} = "$configfile{$key}";
            }
        }
    }

    ### mandatory commandline options: hostquery
    # applying commandline options

    #------- general options --------#
    if (exists $commandline{verbose}) {
        $ghOptions{'verbose'} = $commandline{verbose};
        setLoglevel($commandline{verbose});
    }
    if (exists $commandline{debugfile}) {
        $ghOptions{'debugfile'} = $commandline{debugfile};
        setLogdest($commandline{debugfile});
    }
    if (exists $commandline{version}) {
        print_revision($PROGNAME, $REVISION);
        exit $ERRORS{OK};
    }
    if (exists $commandline{help}) {
        print_help();
        exit $ERRORS{OK};
    }
    if (exists $commandline{showdefaults}) {
        print_defaults();
        exit $ERRORS{OK};
    }

    #--- plugin specific options ----#
    if (exists $commandline{ifs}) {
        $ghOptions{'ifs'} = "$commandline{ifs}";
    }
    if (exists $commandline{usemacaddr}) {
        $ghOptions{'usemacaddr'} = "$commandline{usemacaddr}";
    }
    if (! exists $commandline{'hostquery'}) {
        print "host to query not defined (-H)\n";
        print_help();
        exit $ERRORS{UNKNOWN};
    } else {
        $ghOptions{'hostquery'} = "$commandline{hostquery}";
        $ghSNMPOptions{'host'} = "$commandline{hostquery}";
    }
    if (exists $commandline{hostdisplay}) {
        $ghOptions{'hostdisplay'} = "$commandline{hostdisplay}";
    } elsif (defined $ENV{'NAGIOS_HOSTNAME'} and $ENV{'NAGIOS_HOSTNAME'} ne "") {
        $ghOptions{'hostdisplay'} = $ENV{'NAGIOS_HOSTNAME'};
    } elsif (defined $ENV{'ICINGA_HOSTNAME'} and $ENV{'ICINGA_HOSTNAME'} ne "") {
        $ghOptions{'hostdisplay'} = $ENV{'ICINGA_HOSTNAME'};
    } else {
        $ghOptions{'hostdisplay'} = "$commandline{hostquery}";
    }
    if (exists $commandline{statedir}) {
        $ghOptions{'statedir'} = "$commandline{statedir}";
    }
    $ghOptions{'statedir'} = "$ghOptions{'statedir'}/$commandline{hostquery}";
    -d "$ghOptions{'statedir'}" or MyMkdir ("$ghOptions{'statedir'}");

    # accessmethod(s)
    if (exists $commandline{'accessmethod'}) {
        my @tmparray = split("$ghOptions{ifs}", join("$ghOptions{ifs}",@{$commandline{'accessmethod'}}));
        my %tmphash = ();
        for (@tmparray) {
            my ($method,$target) = split /:/,$_,2;
            if ($method =~ /^ssh$|^telnet$|^http$|^https$/) {
                $tmphash{"$method"} = ($target) ? "$target" : "$method://$ghOptions{'hostquery'}";
            } else {
                print "Specified accessmethod \"$method\" (in \"$_\") is not valid. Valid accessmethods are: ssh, telnet, http and https.\n";
                exit $ERRORS{"UNKNOWN"};
            }
        }
        $ghOptions{'accessmethod'} = \%tmphash;
    }

    # organizing global interface exclusion/inclusion
    if (exists $commandline{'exclude'}) {
        my @tmparray = split("$ghOptions{ifs}", join("$ghOptions{ifs}",@{$commandline{'exclude'}}));
        $ghOptions{'exclude'} = \@tmparray;
    }
    if (exists $commandline{'include'}) {
        my @tmparray = split("$ghOptions{ifs}", join("$ghOptions{ifs}",@{$commandline{'include'}}));
        $ghOptions{'include'} = \@tmparray;
    }
    if (exists $commandline{'alias'}) {
        $ghOptions{'alias'} = $commandline{'alias'};
    }
    if (exists $commandline{'alias-matching'}) {
        $ghOptions{'alias-matching'} = $commandline{'alias-matching'};
        $ghOptions{'alias'} = $commandline{'alias-matching'};
    }
    if (exists $commandline{regexp}) {
        $ghOptions{'regexp'} = $commandline{regexp};
    }
    if (exists $commandline{htmltabledir}) {
        $ghOptions{'htmltabledir'} = "$commandline{htmltabledir}";
    }
    if (exists $commandline{htmltableurl}) {
        $ghOptions{'htmltableurl'} = "$commandline{htmltableurl}";
    }
    if (exists $commandline{htmltablelinktarget}) {
        $ghOptions{'htmltablelinktarget'} = "$commandline{htmltablelinktarget}";
    }
    if (exists $commandline{delta}) {
        $ghOptions{'delta'} = "$commandline{delta}";
    }
    if (exists $commandline{cache}) {
        $ghOptions{'cache'} = "$commandline{cache}";
    }
    # ------------------------------------------------------------------------
    # extract two cache timers out of the commandline --cache option
    #
    # Examples:
    #   --cache 150              $gShortCacheTimer = 150 and $Long... = 300
    #   --cache 3600,86400       $gShortCacheTimer = 3600 and $Long...= 86400
    #
    # ------------------------------------------------------------------------
    # only one number entered
    if ($ghOptions{'cache'} =~ /^\d+$/) {
        $gShortCacheTimer = $ghOptions{'cache'};
        $gLongCacheTimer  = 2*$gShortCacheTimer;
    # two numbers entered - separated with a comma
    } elsif ($ghOptions{'cache'} =~ /^\d+$ghOptions{'ifs'}\d+$/) {
        ($gShortCacheTimer,$gLongCacheTimer) = split (/$ghOptions{'ifs'}/,$ghOptions{'cache'});
    } else {
        print "Wrong cache timer specified\n";
        exit $ERRORS{"UNKNOWN"};
    }
    logger(1, "Set ShortCacheTimer = $gShortCacheTimer and LongCacheTimer = $gLongCacheTimer");
    if (exists $commandline{reseturl}) {
        $ghOptions{'reseturl'} = "$commandline{reseturl}";
    }
    if (exists $commandline{ifloadgradient}) {
        $ghOptions{'ifloadgradient'} = $commandline{ifloadgradient};
    }
    if (exists $commandline{human}) {
        $ghOptions{'human'} = $commandline{human};
    }
    if (exists $commandline{nodetype}) {
        if ($commandline{nodetype} =~ /^standard$|^cisco$|^hp$|^netscreen$|^netapp$|^bigip$|^bluecoat$|^brocade$|^brocade-nos$|^nortel$/i) {
            $ghOptions{'nodetype'} = $commandline{nodetype};
        } else {
            print "Specified nodetype \"$commandline{nodetype}\" is not valid. Valid nodetypes are: standard (default), cisco, hp, netscreen, netapp, bigip, bluecoat, brocade, brocade-nos, nortel.\n";
            exit $ERRORS{"UNKNOWN"};
        }
    }
    if (exists $commandline{ipinfo}) {
        $ghOptions{'ipinfo'} = $commandline{ipinfo};
    }
    if (exists $commandline{duplex}) {
        $ghOptions{'duplex'} = $commandline{duplex};
    }
    if (exists $commandline{stp}) {
        $ghOptions{'stp'} = $commandline{stp};
    }
    if (exists $commandline{vlan}) {
        if ($ghOptions{nodetype} =~ /^cisco$|^hp$|^nortel$/i) {
            $ghOptions{'vlan'} = $commandline{vlan};
        } else {
            print "Option \"--vlan\" not supported for the nodetype \"$ghOptions{nodetype}\".\n";
            exit $ERRORS{"UNKNOWN"};
        }
    }
    if (exists $commandline{'type'}) {
        if ($ghOptions{nodetype} =~ /^standard$|^cisco$|^hp$|^netscreen$|^netapp$|^bluecoat$|^brocade$|^brocade-nos$|^nortel$/i) {
            $ghOptions{'type'} = $commandline{'type'};
        } else {
            print "Option \"--type\" not supported for the nodetype \"$ghOptions{nodetype}\".\n";
            exit $ERRORS{"UNKNOWN"};
        }
    }
    if (exists $commandline{pkt}) {
        $ghOptions{'pkt'} = $commandline{pkt};
    }
    if (exists $commandline{snapshot}) {
        $ghOptions{'snapshot'} = $commandline{snapshot};
    }
    if (exists $commandline{timeout}) {
        $ghOptions{'timeout'} = $commandline{timeout};
        $TIMEOUT = $ghOptions{'timeout'};
    }
    if (exists $commandline{outputshort}) {
        $ghOptions{'outputshort'} = 1;
    }

    #------ property tracking -------#
    # organizing tracked fields
    if (exists $commandline{'track-property'}) {
        my @tmparray = split("$ghOptions{ifs}", join("$ghOptions{ifs}",@{$commandline{'track-property'}}));
        $ghOptions{'track-property'} = \@tmparray;
    }
    # organizing excluded/included interfaces for property(ies) tracking
    if (exists $commandline{'exclude-property'}) {
        my @tmparray = split("$ghOptions{ifs}", join("$ghOptions{ifs}",@{$commandline{'exclude-property'}}));
        $ghOptions{'exclude-property'} = \@tmparray;
    }
    if (exists $commandline{'include-property'}) {
        my @tmparray = split("$ghOptions{ifs}", join("$ghOptions{ifs}",@{$commandline{'include-property'}}));
        $ghOptions{'include-property'} = \@tmparray;
    }
    if (exists $commandline{'warning-property'}) {
        $ghOptions{'warning-property'} = $commandline{'warning-property'};
    }
    if (exists $commandline{'critical-property'}) {
        $ghOptions{'critical-property'} = $commandline{'critical-property'};
    }

    #------ traffic tracking -------#
    # organizing excluded/included interfaces for traffic tracking
    if (exists $commandline{'exclude-traffic'}) {
        my @tmparray = split("$ghOptions{ifs}", join("$ghOptions{ifs}",@{$commandline{'exclude-traffic'}}));
        $ghOptions{'exclude-traffic'} = \@tmparray;
    }
    if (exists $commandline{'include-traffic'}) {
        my @tmparray = split("$ghOptions{ifs}", join("$ghOptions{ifs}",@{$commandline{'include-traffic'}}));
        $ghOptions{'include-traffic'} = \@tmparray;
    }
    if (exists $commandline{'warning-traffic'}) {
        $ghOptions{'warning-traffic'} = "$commandline{'warning-traffic'}";
    }
    my @tmparray2=split(/,/,$ghOptions{'warning-traffic'});
    if ($#tmparray2 != 2) {
        print "3 warning levels needed! (i.e. --warning-traffic 101,0,0)\n";
        exit $ERRORS{"UNKNOWN"};
    }
    $ghOptions{'warning-load'} = $tmparray2[0];
    $ghOptions{'warning-load'} =~ s/%$//;
    $ghOptions{'warning-pkterr'} = $tmparray2[1];
    if ($ghOptions{'nodetype'} eq 'bigip') {
        $ghOptions{'warning-pktdrop'} = $tmparray2[2];    
    } else {
        $ghOptions{'warning-pktdiscard'} = $tmparray2[2];
    }
    if (exists $commandline{'critical-traffic'}) {
        $ghOptions{'critical-traffic'} = "$commandline{'critical-traffic'}";
    }
    my @tmparray3=split(/,/,$ghOptions{'critical-traffic'});
    if ($#tmparray3 != 2) {
        print "3 critical levels needed! (i.e. --critical-traffic 101,0,0)\n";
        exit $ERRORS{"UNKNOWN"};
    }
    $ghOptions{'critical-load'} = $tmparray3[0];
    $ghOptions{'critical-load'} =~ s/%$//;
    $ghOptions{'critical-pkterr'} = $tmparray3[1];
    if ($ghOptions{'nodetype'} eq 'bigip') {
        $ghOptions{'critical-pktdrop'} = $tmparray3[2];    
    } else {
        $ghOptions{'critical-pktdiscard'} = $tmparray3[2];
    }
    
    #------- performance data -------#
    if (exists $commandline{grapher}) {
        if ($commandline{grapher} =~ /^pnp4nagios$|^nagiosgrapher$|^netwaysgrapherv2$|^ingraph$/i) {
            $ghOptions{'grapher'} = "$commandline{grapher}";
            if ($ghOptions{'grapher'} eq "pnp4nagios") {
                $ghOptions{'grapherurl'} = "/pnp4nagios";
            } elsif ($ghOptions{'grapher'} eq "ingraph") {
                $ghOptions{'grapherurl'} = "/ingraph";
            }
        } else {
            print "Specified grapher solution \"$commandline{grapher}\" is not valid. Valid graphers are: pnp4nagios, nagiosgrapher, netwaysgrapherv2, ingraph.\n";
            exit $ERRORS{"UNKNOWN"};
        }
    }
    if (exists $commandline{grapherurl}) {
        $ghOptions{'grapherurl'} = "$commandline{grapherurl}";
    }
    if (exists $commandline{enableperfdata}) {
        $ghOptions{'enableperfdata'} = 1;
    }
    if (exists $commandline{portperfunit}) {
        if ($commandline{portperfunit} =~ /^bit$|^bps$/i) {
            $ghOptions{'portperfunit'} = "$commandline{portperfunit}";
        } else {
            print "Specified performance data unit \"$commandline{portperfunit}\" is not valid. Valid units are: bit, bps.\n";
            exit $ERRORS{"UNKNOWN"};
        }
    }
    if (exists $commandline{perfdataformat}) {
        if ($commandline{perfdataformat} =~ /^full$|^loadonly$|^globalonly$/i) {
            $ghOptions{'perfdataformat'} = "$commandline{perfdataformat}";
        } else {
            print "Specified performance data format \"$commandline{perfdataformat}\" is not valid. Valid formats are: full, loadonly, globalonly.\n";
            exit $ERRORS{"UNKNOWN"};
        }
    }
    if (exists $commandline{perfdatathreshold}) {
        if ($commandline{perfdatathreshold} =~ /^full$|^loadonly$|^globalonly$/i) {
            $ghOptions{'perfdatathreshold'} = "$commandline{perfdatathreshold}";
        } else {
            print "Specified thresholds keyword \"$commandline{perfdatathreshold}\" is not valid. Valid formats are: full, loadonly, globalonly.\n";
            exit $ERRORS{"UNKNOWN"};
        }
    }
    if (exists $commandline{perfdatadir}) {
        $ghOptions{'perfdatadir'} = "$commandline{perfdatadir}";
    }
    if (exists $commandline{perfdataservicedesc}) {
        $ghOptions{'perfdataservicedesc'} = "$commandline{perfdataservicedesc}";
    } elsif (defined $ENV{'NAGIOS_SERVICEDESC'} and $ENV{'NAGIOS_SERVICEDESC'} ne "") {
        $ghOptions{'perfdataservicedesc'} = $ENV{'NAGIOS_SERVICEDESC'};
    }  elsif (defined $ENV{'ICINGA_SERVICEDESC'} and $ENV{'ICINGA_SERVICEDESC'} ne "") {
        $ghOptions{'perfdataservicedesc'} = $ENV{'ICINGA_SERVICEDESC'};
    }
    if ($ghOptions{'enableperfdata'} and $ghOptions{'grapher'} eq "nagiosgrapher" and not defined $ghOptions{'perfdatadir'}) {
        print "As you use nagiosgrapher as the grapher solution, you need to specify a perfdatadir\n";
        exit $ERRORS{"UNKNOWN"};
    }

    #------- other features ---------#
    if (exists $commandline{css}) {
        $ghOptions{'css'} = "$commandline{css}";
    }
    if (! -e "$ghOptions{'htmltabledir'}/../css/$ghOptions{'css'}.css") {
        print "Could not find the css file: $ghOptions{'htmltabledir'}/../css/$ghOptions{'css'}.css\n";
        exit $ERRORS{"UNKNOWN"};
    }
    if (exists $commandline{ifdetails}) {
        $ghOptions{'ifdetails'} = 1;
    }
    if (exists $commandline{configtable}) {
        $ghOptions{'configtable'} = $commandline{configtable};
    }
    if (exists $commandline{tips}) {
        $ghOptions{'tips'} = $commandline{tips};
    }
    if (exists $commandline{'default-table-sorting'}) {
        if ($commandline{'default-table-sorting'} =~ /^index$|^name$/i) {
            $ghOptions{'default-table-sorting'} = "$commandline{'default-table-sorting'}";
        } else {
            print "Specified sorting method \"$commandline{'default-table-sorting'}\" is not valid. Valid sorting method are: index, name.\n";
            exit $ERRORS{"UNKNOWN"};
        }
    }
    if (exists $commandline{'table-split'}) {
        if ($ghOptions{nodetype} =~ /^standard$|^cisco$|^hp$|^netscreen$|^netapp$|^bluecoat$|^brocade$|^brocade-nos$|^nortel$/i) {
            $ghOptions{'table-split'} = $commandline{'table-split'};
        } else {
            print "Option \"--table-split\" not supported for the nodetype \"$ghOptions{nodetype}\".\n";
            exit $ERRORS{"UNKNOWN"};
        }
    }

    #-------- SNMP related ----------#
    if ((exists $commandline{'login'} || exists $commandline{'passwd'}) && (exists $commandline{'community'} || exists $commandline{'v2c'})) {
        print "Can't mix snmp v1,2c,3 protocols!\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"};
    }
    if (exists $commandline{v2c}) {
        $ghSNMPOptions{'version'} = "2";
    } elsif (exists $commandline{login}) {
        $ghSNMPOptions{'version'} = "3";
    } else {
        $ghSNMPOptions{'version'} = "1";
    }
    if (exists $commandline{'max-repetitions'}) {
        $ghSNMPOptions{'max-repetitions'} = $commandline{'max-repetitions'};
    }
    if (exists $commandline{domain}) {
        if ($commandline{domain} =~ /^udp$|^tcp$|^udp6$|^tcp6$/i) {
            $ghSNMPOptions{'domain'} = "$commandline{domain}";
            if ($commandline{domain} eq "udp") {
                $ghSNMPOptions{'port'} = 161;
            } elsif ($commandline{domain} eq "tcp") {
                $ghSNMPOptions{'port'} = 1161;
            } elsif ($commandline{domain} eq "udp6") {
                $ghSNMPOptions{'port'} = 10161;
            } elsif ($commandline{domain} eq "tcp6") {
                $ghSNMPOptions{'port'} = 1611;
            }
        } else {
            print "Specified transport domain \"$commandline{domain}\" is not valid. Valid domains are: udp, tcp, udp6, tcp6.\n";
            exit $ERRORS{"UNKNOWN"};
        }
    }
    if (exists $commandline{port}) {
        $ghSNMPOptions{'port'} = "$commandline{port}";
    }
    if (exists $commandline{community}) {
        $ghSNMPOptions{'community'} = "$commandline{community}";
    }
    if (exists $commandline{login}) {
        $ghSNMPOptions{'login'} = "$commandline{login}";
    }
    if (exists $commandline{passwd}) {
        $ghSNMPOptions{'passwd'} = "$commandline{passwd}";
    }
    if (exists $commandline{privpass}) {
        $ghSNMPOptions{'privpass'} = "$commandline{privpass}";
    }
    if (exists $commandline{'protocols'}) {
        if (!exists $commandline{'login'}) {
            print "Put snmp V3 login info with protocols!\n";
            print_usage();
            exit $ERRORS{"UNKNOWN"};
        }
        my @v3proto=split(/,/,$commandline{'protocols'});
        if ((defined ($v3proto[0])) && ($v3proto[0] ne "")) {
            $ghSNMPOptions{'authproto'} = $v3proto[0];
        }
        if (defined ($v3proto[1])) {
            $ghSNMPOptions{'privproto'} = $v3proto[1];
        }
        if ((defined ($v3proto[1])) && (!exists $commandline{'privpass'})) {
            print "Put snmp V3 priv login info with priv protocols!\n";
            print_usage();
            exit $ERRORS{"UNKNOWN"};
        }
    }
    if (exists $commandline{'contextname'}) {
        if (!exists $commandline{'login'}) {
            print "Put snmp V3 login info with context name!\n";
            print_usage();
            exit $ERRORS{"UNKNOWN"};
        }
        $ghSNMPOptions{'contextname'} = "$commandline{'contextname'}";
    }
    if (exists $commandline{'snmp-timeout'}) {
        $ghSNMPOptions{'timeout'} = "$commandline{'snmp-timeout'}";
    }
    if (exists $commandline{'snmp-retries'}) {
        $ghSNMPOptions{'retries'} = "$commandline{'snmp-retries'}";
    }
    if (exists $commandline{'64bits'}) {
        $ghSNMPOptions{'64bits'} = 1;
    }
    # Check snmpv2c or v3 with 64-bit counters
    if ( $ghSNMPOptions{'64bits'} && $ghSNMPOptions{'version'} == 1) {
        print "Can't get 64-bit counters with snmp version 1\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"};
    }
    if ($ghSNMPOptions{'64bits'}) {
        if (eval "require bigint") {
            use bigint;
        } else {
            print "Need bigint module for 64-bit counters\n";
            print_usage();
            exit $ERRORS{"UNKNOWN"};
        }
    } else {
        if ($ghOptions{'nodetype'} eq 'bigip') {
            print "No 32-bit counters for this nodetype. Please use the --64bits option\n";
            exit $ERRORS{"UNKNOWN"};
        }
    }
    if (exists $commandline{'cachedir'}) {
        $ghSNMPOptions{'cachedir'} = "$commandline{'cachedir'}";
    }
    if (exists $commandline{'unixsnmp'}) {
        $ghSNMPOptions{'unixsnmp'} = $commandline{'unixsnmp'};
    }

    # print the options in command line, and the resulting full option hash
    logger(5, "commandline: \n".Dumper(\%commandline));
    logger(5, "general options: \n".Dumper(\%ghOptions));
    logger(5, "snmp options: \n".Dumper(\%ghSNMPOptions));
}

__END__

# vi: set ts=4 sw=4 expandtab :
