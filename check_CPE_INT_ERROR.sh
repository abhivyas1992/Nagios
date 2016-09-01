#!/bin/bash

usage() { echo "Usage: $0 [-v version ] [-H host] [-C community] [-o oid ]  [-t time (sec)] " 1>&2; exit 1; }

while getopts ":H:C:w:c:o:v:t:" o; do
    case "${o}" in
        H)
            host=${OPTARG}
            #((s == 45 || s == 90)) || usage
            ;;
        C)
            comm=${OPTARG}
            ;;
        v)
            ver=${OPTARG}
            ;;
        t)
            time=${OPTARG}
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

if [ -z "${host}" ] || [ -z "${comm}" ]  || [ -z "${oid}" ]  || [ -z "${ver}" ] || [ -z "${time}" ]  ;then
    usage
fi



var=$(snmpget -v$ver -c $comm $host $oid)
result1=`echo ${var##*:}`
b=$((time))
sleep $b
var=$(snmpget -v$ver -c $comm $host $oid)
result2=`echo ${var##*:}`
#if [  -f /tmp/interface_value ];then
#	value=$(cat /tmp/interface_value)
#else
#	value=0
#fi

if [ $result2 -gt $result1 ];then
	a=$((result2 - result1))
	myvar=`echo $a/$b  |bc -l`
	printf "WARNING : packet error rate increased by %0.2f per second\n" $myvar
        exit 1
elif [ $result2 -lt $result1 ];then
	a=$((result1 - result2))
	myvar=`echo $a/$b  |bc -l`
        printf "packet error rate decreased by %0.2f per second\n" $myvar
else
	printf "packet error rate is %0.2f per second \n"$myvar
fi

