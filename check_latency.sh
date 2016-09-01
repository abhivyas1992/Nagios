#!/bin/bash
#Check Latency as Passive Check
#Testing Nagios Latency

#declare States
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

#get Latency
LATENCY=`/opt/itcockpit/nagios/bin/nagiostats | grep "Active Service Latency"|cut -f3 -d'/' | awk '{print $1}' | tr -d '\n'`;

while test -n "$1"; do
    case "$1" in
        --help)
            show_help
	    echo " "
	    show_whatsnew
            exit $STATE_OK
           ;;
       -w)
            if [ -z $2 ];
	    then
		   echo CRITICAL - Warning Threshold missing 
		   exit $STATUS_CRITICAL
	    fi
	    WARN=$2.000
            shift
            ;;
	-c)
            if [ -z $2 ];
	    then
		   echo CRITICAL - Warning Threshold missing 
		   exit $STATUS_CRITICAL
	    fi
	    CRIT=$2.000
            shift
            ;;

        *)
            echo "Unknown argument: $1"
            exit $STATE_UNKNOWN
            ;;
    esac
    shift
done


if [ "$LATENCY" < "$WARN" ]; then
	NAGSTAT=$STATE_OK
	NAGRES="OK"
fi;
if [ "$LATENCY" > "$WARN" ]; then
	if [ "$LATENCY" < "$CRIT" ];then
		NAGSTAT=$STATE_WARNING
		NAGRES="WARNING"
	fi;
fi;
#if [ $LATENCY > $CRIT ]; then
#	NAGSTAT=$STATE_CRITICAL
#	NAGRES="CRITICAL"
#fi;


echo "$NAGRES Nagios Latency: $LATENCY Sekunden|Latency=$LATENCY;$WARN;$CRIT;;";
exit $NAGSTAT
