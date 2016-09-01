#!/bin/sh

usage() { echo "Usage: $0 [-H host] [-C community] [-o oid ] [-w warning] [-c critical] " 1>&2; exit 1; }

while getopts ":H:C:w:c:o:" o; do
    case "${o}" in
        H)
            host=${OPTARG}
            #((s == 45 || s == 90)) || usage
            ;;
        C)
            comm=${OPTARG}
            ;;
        w)
            warn=${OPTARG}
            ;;
        c)
            cric=${OPTARG}
            ;;
        o)
            oid=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${host}" ] || [ -z "${comm}" ] || [ -z "${warn}" ] || [ -z "${cric}" ] || [ -z "${oid}" ] ;then
    usage
fi


if [ $cric -lt $warn ]
then
   echo "critical must be greater than warning "
   exit 1
fi

var=$(snmpwalk -v2c -c $comm $host $oid)
v1=`echo ${var##*:}`
#echo "OK Temperature used : $v1 C"

if [ $v1 -ge $warn ] && [ $v1 -lt $cric ]
then
   echo "Temperature warning  : $v1"
   exit 1
elif [ $v1 -ge $cric ]
then 
    echo "critical Temperature : $v1"
    exit 2
else
   echo "OK Temperature used : $v1 C"
fi
