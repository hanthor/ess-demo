#!/bin/bash

set -euo pipefail

hostnamesFile=$1
outputDirectory=$2

admin=$(cat $hostnamesFile | grep "elementAdmin": -A2 | grep "host:" | sed "s/.*host: //")
chat=$(cat $hostnamesFile | grep "elementWeb": -A2 | grep "host:" | sed "s/.*host: //")
synapse=$(cat $hostnamesFile | grep "synapse": -A2 | grep "host:" | sed "s/.*host: //")
auth=$(cat $hostnamesFile | grep "matrixAuthenticationService": -A2 | grep "host:" | sed "s/.*host: //")
mrtc=$(cat $hostnamesFile | grep "matrixRTC": -A2 | grep "host:" | sed "s/.*host: //")
servername=$(cat $hostnamesFile | grep "serverName": | sed "s/.*serverName: //")

mkcert -install

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
