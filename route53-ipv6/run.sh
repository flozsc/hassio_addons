#!/usr/bin/env bashio
# Hass.io Add-on AWS Route53 Dynamic DNS for IPv6.
# Florian Zschetzsche <flozsc@outlook.com>
# based on Keiran Sweet's <keiran@gmail.com> original version for A records.
#
# This plugin allows you to update a record in Route53 to point to your discovered IP
# address. By default, we determine the IP address from v6.ipv6-test.com,
# however you can set this to any HTTP/HTTPS endpoint of your choice in
# config.json if required.
#
# For full configuration information, please see the README.md
#

#
# Pull in the required values from the config.json file
#
export AWS_SECRET_ACCESS_KEY=$(bashio::config 'AWS_SECRET_ACCESS_KEY')
export AWS_DEFAULT_REGION=$(bashio::config 'AWS_REGION')
export AWS_REGION=$(bashio::config 'AWS_REGION')
export AWS_ACCESS_KEY_ID=$(bashio::config 'AWS_ACCESS_KEY_ID')
export RECORDNAME=$(bashio::config 'RECORDNAME')
export TIMEOUT=$(bashio::config 'TIMEOUT')
export ZONEID=$(bashio::config 'ZONEID')
export IPURL=$(bashio::config 'IPURL')

# Functions used for the addon.

# Create / Update the Record in Route53 if/when required
# Indentation is a little off because bash's heredoc support doesnt like indentation..
#
function update_record {
    bashio::log.info "Updating / Creating the AAAA record for ${RECORDNAME} in Zone ${ZONEID}"

    rm -f /tmp/createjson.tmp

cat << ENDOFCREATEJSON > /tmp/createjson.tmp
    {
        "Comment": "Home Assistant ",
        "Changes": [
            {
                "Action": "UPSERT",
                "ResourceRecordSet": {
                    "Name": "${RECORDNAME}",
                    "Type": "AAAA",
                    "TTL": 300,
                    "ResourceRecords": [
                        {
                            "Value": "${IPADDRESS}"
                        }
                    ]
                }
            }
        ]
    }
ENDOFCREATEJSON

    aws route53 change-resource-record-sets --hosted-zone-id ${ZONEID} --change-batch file:///tmp/createjson.tmp

}

# Evaluate the current state of the record, and then update if required.
function evaluate_record {

    export RECORDADDRESS=$(aws route53  test-dns-answer --hosted-zone-id ${ZONEID} --record-type AAAA --record-name ${RECORDNAME} | jq '.RecordData[0]' | sed -e 's/"//g')

    if [[  $IPADDRESS =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]]; then

      bashio::log.debug "Received a valid IP address from the remote service - OK to proceed checking values"

      if [ $IPADDRESS == $RECORDADDRESS ]; then
        bashio::log.debug "The Addresses match - nothing to do ($IPADDRESS is the same as $RECORDADDRESS)"
      else
        bashio::log.info "The Addresses don't match ($IPADDRESS is not the same as $RECORDADDRESS) - Updating record"
        update_record
      fi
    else
      bashio::log.warning "The IP Address string received from the remote service was not a valid IP address (${IPADDRESS})- unable to check and update the DNS record"
    fi

}


#
# Main Program body - This is where the action happens
#

# If debug is true, dump the runtime data first.
bashio::log.debug "-------------------------------------------"
bashio::log.debug "Dumping Debugging data"
bashio::log.debug "Got AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}"
bashio::log.debug "Got AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY}"
bashio::log.debug "Got AWS_DEFAULT_REGION: ${AWS_DEFAULT_REGION}"
bashio::log.debug "Got TIMEOUT: ${TIMEOUT}"
bashio::log.debug "Got IPURL: ${IPURL}"
bashio::log.debug "Got TIMEOUT: ${TIMEOUT}"
bashio::log.debug "Got RECORDNAME: ${RECORDNAME}"
bashio::log.debug "Got ZONEID: ${ZONEID}"
bashio::log.debug "-------------------------------------------"


while true
do

    bashio::log.debug "Executing main program body"
    export IPADDRESS=$(curl -6 -s ${IPURL})
    bashio::log.debug "Got ${IPADDRESS}"

    export RESPONSECODE=$(aws route53  test-dns-answer --hosted-zone-id ${ZONEID} --record-type AAAA --record-name ${RECORDNAME} | jq '.ResponseCode')
    bashio::log.debug "Got ${RESPONSECODE}"

    case $RESPONSECODE in

        '"NXDOMAIN"')
            bashio::log.info "Got NXDOMAIN (${RESPONSECODE}) - Creating new AAAA Record"
            update_record
        ;;

        '"NOERROR"')
            bashio::log.debug "Got NOERROR (${RESPONSECODE}) - Continue to ensure IP address is correct in record"
            evaluate_record
        ;;

        *)
            bashio::log.info "Got ${RESPONSECODE} that was not NXDOMAIN or NOERROR - CANNOT CONTINUE"
            exit 1
        ;;

    esac
    bashio::log.debug "Sleeping for ${TIMEOUT} seconds"
    sleep $TIMEOUT
done
