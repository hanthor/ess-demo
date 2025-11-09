#!/bin/bash
# Certificate generation script for ESS Community Demo
# Generates SSL certificates using mkcert for local development

set -euo pipefail

hostnamesFile=$1
outputDirectory=${2:-"./certs"}

# Extract hostnames from YAML config
admin=$(grep -A2 "elementAdmin:" "$hostnamesFile" | grep "host:" | sed "s/.*host: //" | tr -d ' ')
chat=$(grep -A2 "elementWeb:" "$hostnamesFile" | grep "host:" | sed "s/.*host: //" | tr -d ' ')
synapse=$(grep -A2 "synapse:" "$hostnamesFile" | grep "host:" | sed "s/.*host: //" | tr -d ' ')
auth=$(grep -A2 "matrixAuthenticationService:" "$hostnamesFile" | grep "host:" | sed "s/.*host: //" | tr -d ' ')
mrtc=$(grep -A2 "matrixRTC:" "$hostnamesFile" | grep "host:" | sed "s/.*host: //" | tr -d ' ')
servername=$(grep "serverName:" "$hostnamesFile" | sed "s/.*serverName: //" | tr -d ' ')

# Ensure mkcert CA is installed
if ! mkcert -CAROOT >/dev/null 2>&1; then
    echo "Installing mkcert CA..."
    mkcert -install
fi

mkdir -p "$outputDirectory"
cd "$outputDirectory"
mkcert "$servername"
kubectl create secret tls ess-well-known-certificate "--cert=./$servername.pem" "--key=./$servername-key.pem" -n ess

mkcert "$synapse"
kubectl create secret tls ess-matrix-certificate "--cert=./$synapse.pem" "--key=./$synapse-key.pem" -n ess

mkcert "$mrtc"
kubectl create secret tls ess-mrtc-certificate "--cert=./$mrtc.pem" "--key=./$mrtc-key.pem" -n ess

mkcert "$chat"
kubectl create secret tls ess-chat-certificate "--cert=./$chat.pem" "--key=./$chat-key.pem" -n ess

mkcert "$auth"
kubectl create secret tls ess-auth-certificate "--cert=./$auth.pem" "--key=./$auth-key.pem" -n ess

mkcert "$admin"
kubectl create secret tls ess-admin-certificate "--cert=./$admin.pem" "--key=./$admin-key.pem" -n ess
cd -
