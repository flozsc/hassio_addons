#!/bin/bash
# Hass.io Amazon Route53 Dynamic DNS plugin.
# Keiran Sweet <keiran@gmail.com>
#
# This plugin allows you to update a record in Route53 to point to your discovered IP
# address. By default, we determine the IP address from ipify in the config.json,
# however you can set this to any HTTP/HTTPS endpoint of your choice if required.
#
# For full configuration information, please see the README.md
#

# Source in some helper functions that make handling JSON easier in bash
source /usr/lib/hassio-addons/base.sh

#
# Pull in the required values from the config.json file
#
export AWS_SECRET_ACCESS_KEY=$(hass.config.get 'AWS_SECRET_ACCESS_KEY')
export AWS_ACCESS_KEY_ID=$(hass.config.get 'AWS_ACCESS_KEY_ID')
export AWS_HOSTED_ZONE_ID=$(hass.config.get 'AWS_HOSTED_ZONE_ID')
export SITE=$(hass.config.get 'site')
export EMAIL=$(hass.config.get 'email')
export CADDYPATH=/share/caddy/

if [ ! -d "$CADDYPATH" ]; then
  mkdir $CADDYPATH
fi

# Functions used for the addon.

# Debugging message wrapper used to echo values only if debug is set to true
# function debug_message {
#     if [ $DEBUG == 'true' ]; then
#       echo "$(date) DEBUG : $1"
#     fi
# }

# Create / Update the Record in Route53 if/when required
# Indentation is a little off because bash's heredoc support doesnt like indentation..
#
function create_caddyfile {
    echo "$(date) INFO : Creating Caddyfile for ${SITE}"

    rm -f /tmp/Caddyfile

cat << ENDOFCREATEJSON > /tmp/Caddyfile
  ${SITE} {
      proxy / homeassistant:8123 {
          websocket
          transparent
      }

      tls ${EMAIL} {
          dns route53
      }
  }
ENDOFCREATEJSON

}


#
# Main Program body - This is where the action happens
#

# If debug is true, dump the runtime data first.
# debug_message "-------------------------------------------"
# debug_message "Dumping Debugging data"
# debug_message "Got AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}"
# debug_message "Got AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY}"
# debug_message "Got AWS_HOSTED_ZONE_ID: ${AWS_HOSTED_ZONE_ID}"
# debug_message "-------------------------------------------"

create_caddyfile

caddy -conf /tmp/Caddyfile -log stdout -agree
