#!/bin/bash

# Plugin to send SMS through Nagios useing API 
# Written by Sharafraz Khan (khan.sharafraz@gmail.com)
# Last Modified: 30-APR-2015



#Change Below parameter according to your environment
user=
pass=
SID=

# ---------------------------------------
# Do not modify anything below this line
# ---------------------------------------
function usage
{
if [ ! "$#" -eq 2 ]; then
 echo "ERROR 2 arguments required, $# provided"
 echo "-------------------------------------------------"
 echo "Usage: bash $0 full_phone_number text_message"
 echo "Example: send_sms.sh -C <Mobile Number> -M <Message>"
 echo "-------------------------------------------------"
 exit 1
fi
}

while getopts "C:M:" o; do
        case "$o" in
        C )
                MOBILE="$OPTARG"
                ;;
        M )
                MESSAGE="$OPTARG"
                ;;

        * )
                usage
                ;;
        esac
done

str="$MESSAGE"
mess=`echo ${str// /%20}`

#RESPONSE=`curl -x http://90.0.1.16:8002/ "http://login.arihantsms.com/vendorsms/pushsms.aspx?user=$user&password=$pass&msisdn=$MOBILE&sid=$SID&fl=0&gwid=2&msg=$mess" 2>&1`
RESPONSE=`curl --data-urlencode "user=$user" --data-urlencode "password=$pass" --data-urlencode "sender=$SID" --data-urlencode "SMSText=$MESSAGE" --data-urlencode "GSM=$MOBILE" "http://" 2>&1`
#$RESPONSE
