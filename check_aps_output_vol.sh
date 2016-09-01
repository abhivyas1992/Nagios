#!/bin/sh

usage() { echo "Usage: $0 [ -v Version ][-H host] [-C community]" 1>&2; exit 3; }

while getopts ":H:C:w:c:o:v:" o; do
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
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${host}" ] || [ -z "${comm}" ] || [ -z "${ver}" ]  ;then
    usage
fi

var=$(snmpget -v$ver -c $comm $host 1.3.6.1.4.1.318.1.1.1.4.2.1.0 2>&1)
v1=`echo ${var##*:}`

echo "output voltage=$v1 V "
