#!/bin/bash

# Exit on error.
set -euo pipefail
# Testing
#set -euxo pipefail

echo ""
echo "Let's publish your site using IPFS and Cloudflare..."

if [ -f ./config.sh ]; then
  source ./config.sh
else
  echo ""
  echo "You must have a configuration file 'config.sh' in the publish_sh directory."
  echo "Use config-template.sh to start."
  echo ""
  exit 0
fi

echo `date`

ip=$(curl -s -X GET https://checkip.amazonaws.com --max-time 10)
if [ -z "$ip" ]; then
  echo "Error! Can't get external ip from https://checkip.amazonaws.com."
  echo "Check that you are connected to the Internet."
  exit 0
fi
echo "==> External IP is: $ip"

cloudflare_record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=TXT&name=_dnslink.ipfs.davidfisco.com" \
  -H "Authorization: Bearer $cloudflare_zone_api_token" \
  -H "Content-Type: application/json")
if [[ ${cloudflare_record} == *"\"success\":false"* ]]; then
  echo ${cloudflare_record}
  echo "Error! Can't get davidfisco.com record inforamiton from cloudflare API"
  exit 0
fi

cloudflare_record_id=$(echo $cloudflare_record | jq '.result[0].id' | sed 's/"//g')

echo "Cloudflare Record ID: $cloudflare_record_id"

echo "Building Jekyll site..."
cd ~/_ipfs-site
jekyll build
MY_PIN=$(IPFS_PATH=/mnt/ipfs ipfs add -Q -r _site)
echo "==> IPFS Pin is: $MY_PIN"

final_result=$(curl -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$cloudflare_record_id" \
     -H "Authorization: Bearer $cloudflare_zone_api_token" \
     -H "Content-Type: application/json" \
     --data "{\"type\":\"TXT\",\"name\":\"_dnslink.ipfs.davidfisco.com\",\"content\":\"dnslink=/ipfs/$MY_PIN\",\"ttl\":1,\"proxied\":false}")

echo "Final Result: $final_result"

if test -f "$last_pin_file"; then
    echo "Deleting `cat $last_pin_file`..."
    IPFS_PATH=/mnt/ipfs ipfs pin rm `cat $last_pin_file`
    IPFS_PATH=/mnt/ipfs ipfs repo gc
fi

echo $MY_PIN > $last_pin_file

exit 0