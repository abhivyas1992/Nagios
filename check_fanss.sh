#!/bin/sh
IFS=$'\n'
usage() { echo "Usage: $0 [ -v Version ][-H host] [-C community] [-o OID ]" 1>&2; exit 3; }

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

if [ -z "${host}" ] || [ -z "${comm}" ] || [ -z "${ver}" ] || [ -z "${oid}" ]  ;then
    usage
fi

var=`snmpwalk -v$ver -c $comm $host $oid 2>&1`
#echo "var =$var"
count=0
fans_good=0
fans_bad=0
fans_unknown=0
for line in `echo "$var"` ; do 
	v1=`echo -n ${line##* }`
	count=`expr $count + 1`
	if [ $v1 -eq 1 ]
	then
		fans_good=`expr $fans_good + 1`
	elif [ $v1 -eq 2 ]
	then	
		fans_string+="Fan Number $count "
		fans_bad=`expr $fans_bad + 1`
	else
		fans_unknown_string+="Fan Number $count "
		fans_unknown=`expr $fans_unknown + 1`
	fi
#echo "fan$count=$v1  "
done 

if [ $count -eq $fans_good ] 
then
	echo "Fans:ok $count fans are running all good"
	exit 0
else
	if [ -z "${fans_unknown_string}" ] ;then
		echo $fans_string "are(is) in bad state"
		exit 1
	elif [ -z "${fans_string}" ] ;then
		echo $fans_unknown_string "are(is) in unknown state"
		exit 1	
	else
		echo $fans_string "are(is) in bad state"$fans_unknown_string "are(is) in unknown state"
		exit 1	
	fi		
fi
#echo "$fans_bad fans are running bad"
#echo "$fans_unknown fans are unknown state
