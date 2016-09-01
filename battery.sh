#!/bin/sh

usage() { echo "Usage: $0 [ -v Version ][-H host] [-C community] [-o oid ] " 1>&2; exit 1; }

while getopts ":H:C:w:c:o:v:" o; do
    case "${o}" in
        H)
            host=${OPTARG}
            #((s == 45 || s == 90)) || usage
            ;;
        C)
            comm=${OPTARG}
            ;;
        o)
            oid=${OPTARG}
            ;;
        v)
            ver=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${host}" ] || [ -z "${comm}" ] || [ -z "${ver}" ] || [ -z "${oid}" ] ;then
    usage
    exit 3
fi

var=$(snmpget -v$ver -c $comm $host $oid 2>&1)
check=$?
if [ $check -gt 0 ]
then
	echo "UNKNOWN "
	echo $var
	exit 3
fi
v1=`echo ${var##*:}`

echo "battery remaining=$v1%"
if [ $v1 -le 30 ]
then
	echo "Critical"
	exit 1
elif [ $v1 -le 50 ]
then
	echo "warning"
	exit 2
fi	
#exit $?
