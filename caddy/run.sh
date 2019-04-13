#!/usr/bin/env bashio
# Hass.io Add-on Caddy with Let's Encrypt Route53 DNS challenge
# Florian Zschetzsche <flozsc@outlook.com>
#
# This add-on allows you to setup a Caddy proxy server to your Home Assistant
# instance, using Let's Encrypt's Route53 DNS challenge method.
#
# For full configuration information, please see the README.md
#

#
# Pull in the required values from the config.json file
#
export AWS_SECRET_ACCESS_KEY=$(bashio::config 'AWS_SECRET_ACCESS_KEY')
export AWS_ACCESS_KEY_ID=$(bashio::config 'AWS_ACCESS_KEY_ID')
export AWS_HOSTED_ZONE_ID=$(bashio::config 'AWS_HOSTED_ZONE_ID')
export SITE=$(bashio::config 'site')
export EMAIL=$(bashio::config 'email')
export CADDYPATH=/share/caddy/

if [ ! -d "$CADDYPATH" ]; then
  mkdir $CADDYPATH
fi


# Create Caddyfile based on add-on configuration

function create_caddyfile {
    bashio::log.info "Creating Caddyfile for ${SITE}"

    # Delete a possibly existing file first
    rm -f /tmp/Caddyfile

cat << ENDOFCADDYFILE > /tmp/Caddyfile
  ${SITE} {
      proxy / homeassistant:8123 {
          websocket
          transparent
      }

      tls ${EMAIL} {
          dns route53
      }
  }
ENDOFCADDYFILE

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
